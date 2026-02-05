#!/usr/bin/env python3
"""
Dropbox Asset Audit Script
Compares COMPLETE_SOFTWARE_MANIFEST.md against Dropbox folder contents

Usage:
    DROPBOX_TOKEN and DROPBOX_FOLDER must be set in .env file
    python scripts/audit_dropbox_assets.py

Output:
    - First line: JSON report
    - Subsequent lines: Human summary (on stderr)
    - File: audit_report.json
"""

import os
import sys
import json
import hashlib
import re
import time
from typing import Dict, List, Set, Optional, Tuple
from dataclasses import dataclass, asdict
from datetime import datetime
from urllib.parse import urljoin
import asyncio
import aiohttp
from pathlib import Path

# Configuration
MAX_CONCURRENT_DOWNLOADS = 4
MAX_FILE_SIZE_FOR_CHECKSUM = 5 * 1024 * 1024 * 1024  # 5GB
RATE_LIMIT_BACKOFF_BASE = 2  # exponential backoff
MAX_RETRIES = 3
DROPBOX_API_BASE = "https://api.dropboxapi.com/2"
DROPBOX_CONTENT_BASE = "https://content.dropboxapi.com/2"

# Data structures
@dataclass
class DropboxFile:
    path: str
    name: str
    size: int
    modified: str
    id: str
    sha256: Optional[str] = None

@dataclass
class ManifestEntry:
    category: str
    name: str
    expected_size: Optional[str] = None  # e.g., "6.5GB"

@dataclass
class AuditReport:
    summary: Dict
    missing: List[Dict]
    extra: List[Dict]
    size_mismatches: List[Dict]
    checksum_mismatches: List[Dict]
    mapping: Dict[str, List[Dict]]
    notes: List[str]


class DropboxClient:
    """Dropbox API client with retry logic and rate limit handling"""

    def __init__(self, token: str):
        self.token = token
        self.session = None

    async def __aenter__(self):
        self.session = aiohttp.ClientSession(
            headers={"Authorization": f"Bearer {self.token}"}
        )
        return self

    async def __aexit__(self, *args):
        if self.session:
            await self.session.close()

    async def _api_call(self, endpoint: str, data: Dict, retries=0) -> Dict:
        """Make Dropbox API call with retry logic"""
        url = urljoin(DROPBOX_API_BASE, endpoint)
        try:
            async with self.session.post(url, json=data, timeout=aiohttp.ClientTimeout(total=60)) as resp:
                if resp.status == 429:  # Rate limit
                    retry_after = int(resp.headers.get('Retry-After', 60))
                    if retries < MAX_RETRIES:
                        print(f"Rate limited, waiting {retry_after}s...", file=sys.stderr)
                        await asyncio.sleep(retry_after)
                        return await self._api_call(endpoint, data, retries+1)
                    raise Exception(f"Rate limit exceeded after {MAX_RETRIES} retries")

                if resp.status != 200:
                    error_text = await resp.text()
                    try:
                        error_json = json.loads(error_text)
                        error_msg = error_json.get('error_summary', error_text)
                    except:
                        error_msg = error_text
                    raise Exception(f"Dropbox API error ({resp.status}): {error_msg}")

                return await resp.json()
        except asyncio.TimeoutError:
            if retries < MAX_RETRIES:
                wait_time = RATE_LIMIT_BACKOFF_BASE ** retries
                print(f"Timeout, retrying in {wait_time}s...", file=sys.stderr)
                await asyncio.sleep(wait_time)
                return await self._api_call(endpoint, data, retries+1)
            raise

    async def list_folder_recursive(self, path: str) -> List[DropboxFile]:
        """Recursively list all files in folder with pagination"""
        files = []

        # Initial request
        print(f"Listing folder: {path}", file=sys.stderr)
        data = {"path": path, "recursive": True, "limit": 2000}
        result = await self._api_call("/files/list_folder", data)

        for entry in result.get('entries', []):
            if entry.get('.tag') == 'file':
                files.append(DropboxFile(
                    path=entry['path_display'],
                    name=entry['name'],
                    size=entry['size'],
                    modified=entry.get('server_modified', ''),
                    id=entry['id']
                ))

        # Handle pagination
        page = 1
        while result.get('has_more'):
            page += 1
            print(f"Fetching page {page}...", file=sys.stderr)
            result = await self._api_call(
                "/files/list_folder/continue",
                {"cursor": result['cursor']}
            )
            for entry in result.get('entries', []):
                if entry.get('.tag') == 'file':
                    files.append(DropboxFile(
                        path=entry['path_display'],
                        name=entry['name'],
                        size=entry['size'],
                        modified=entry.get('server_modified', ''),
                        id=entry['id']
                    ))

        return files

    async def download_file(self, path: str) -> bytes:
        """Download file content"""
        url = urljoin(DROPBOX_CONTENT_BASE, "/files/download")
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Dropbox-API-Arg": json.dumps({"path": path})
        }

        async with self.session.post(url, headers=headers, timeout=aiohttp.ClientTimeout(total=300)) as resp:
            if resp.status != 200:
                error_text = await resp.text()
                raise Exception(f"Download failed ({resp.status}): {error_text}")
            return await resp.read()


class ManifestParser:
    """Parse COMPLETE_SOFTWARE_MANIFEST.md to extract expected assets"""

    CATEGORIES = {
        "checkpoints": ["## 🎭 AI MODELS - CHECKPOINTS", "Image Generation Models", "Video Generation Models"],
        "loras": ["## 🎨 AI MODELS - LORAS", "General LoRAs", "Fetish LoRAs", "Scat LoRAs"],
        "vaes": ["## 🎨 AI MODELS - VAES"],
        "text_encoders": ["## 📝 AI MODELS - TEXT ENCODERS"],
        "video_wan": ["## 🎬 AI MODELS - VIDEO (WAN)", "Wan Diffusion Models", "Wan LoRAs", "Wan Text Encoders", "Wan VAEs"],
        "video_ltx": ["## 🎥 AI MODELS - VIDEO (LTX-2)", "LTX Diffusion Models", "LTX LoRAs"],
        "flux": ["## ⚡ AI MODELS - FLUX", "FLUX Diffusion Models", "FLUX Text Encoders"],
        "animatediff": ["## 🎬 AI MODELS - ANIMATEDIFF"],
        "upscalers": ["## 🔍 AI MODELS - UPSCALERS"],
        "controlnet": ["## 🎮 AI MODELS - CONTROLNET"],
        "detection": ["## 🔎 AI MODELS - DETECTION MODELS"],
        "rife": ["## 🎞️ AI MODELS - FRAME INTERPOLATION"]
    }

    def __init__(self, manifest_path: str):
        self.manifest_path = manifest_path

    def parse(self) -> List[ManifestEntry]:
        """Parse manifest and return list of expected files"""
        with open(self.manifest_path, 'r', encoding='utf-8') as f:
            content = f.read()

        entries = []
        current_category = None

        lines = content.split('\n')
        for i, line in enumerate(lines):
            # Detect category headers
            for cat_key, cat_patterns in self.CATEGORIES.items():
                for pattern in cat_patterns:
                    if pattern in line:
                        current_category = cat_key
                        break

            # Parse markdown table rows
            if current_category and '|' in line and not line.startswith('|---'):
                parts = [p.strip() for p in line.split('|')]
                if len(parts) >= 3:
                    # Extract model name (usually in backticks or plain text)
                    name = parts[1].strip('`').strip()
                    size = parts[2] if len(parts) > 2 else None

                    # Filter out header rows and empty names
                    if name and name.lower() not in ['model', 'package', 'name', 'size', 'type', 'source', 'purpose', 'precision', 'category']:
                        entries.append(ManifestEntry(
                            category=current_category,
                            name=name,
                            expected_size=size
                        ))

        print(f"Parsed {len(entries)} expected assets from manifest", file=sys.stderr)
        return entries

    @staticmethod
    def normalize_name(name: str) -> str:
        """Normalize filename for comparison"""
        # Remove backticks, quotes, extra whitespace
        name = name.strip('`').strip('"').strip("'").strip()
        # Handle case-insensitive comparison
        return name.lower()


class ContentSafetyChecker:
    """Check for potentially illegal content based on filenames"""

    ILLEGAL_PATTERNS = [
        r'\b(child|minor|kid|teen|young|underage)\b',
        r'\b(csam|cp)\b',
        r'\b(non[_-]?consent|rape|assault)\b',
    ]

    @staticmethod
    def is_safe(filename: str, path: str) -> Tuple[bool, Optional[str]]:
        """Check if file should be flagged for manual review"""
        combined = f"{filename} {path}".lower()

        for pattern in ContentSafetyChecker.ILLEGAL_PATTERNS:
            if re.search(pattern, combined, re.IGNORECASE):
                return False, f"Matched illegal content pattern: {pattern}"

        return True, None


class AuditEngine:
    """Core audit logic"""

    def __init__(self, client: DropboxClient, manifest_entries: List[ManifestEntry]):
        self.client = client
        self.manifest_entries = manifest_entries
        self.dropbox_files: List[DropboxFile] = []
        self.report = AuditReport(
            summary={},
            missing=[],
            extra=[],
            size_mismatches=[],
            checksum_mismatches=[],
            mapping={},
            notes=[]
        )

    async def run_audit(self, folder_path: str):
        """Execute full audit"""
        # Step 1: List Dropbox files
        print("Fetching Dropbox file list...", file=sys.stderr)
        self.dropbox_files = await self.client.list_folder_recursive(folder_path)
        print(f"Found {len(self.dropbox_files)} files in Dropbox", file=sys.stderr)

        # Step 2: Build name mapping
        dropbox_by_name = {}
        for df in self.dropbox_files:
            name_lower = df.name.lower()
            if name_lower not in dropbox_by_name:
                dropbox_by_name[name_lower] = []
            dropbox_by_name[name_lower].append(df)

        # Step 3: Match manifest entries
        manifest_by_name = {}
        for entry in self.manifest_entries:
            name_lower = ManifestParser.normalize_name(entry.name)
            manifest_by_name[name_lower] = entry

        matched_files = set()

        # Step 4: Process matches
        print("Matching manifest entries to Dropbox files...", file=sys.stderr)
        for manifest_name, entry in manifest_by_name.items():
            if manifest_name in dropbox_by_name:
                matches = dropbox_by_name[manifest_name]
                matched_files.update(df.path for df in matches)

                # Record matches
                self.report.mapping[entry.name] = [
                    {
                        "path": df.path,
                        "size": df.size,
                        "modified": df.modified,
                        "sha256_or_null": None
                    }
                    for df in matches
                ]

                # Check size mismatches
                for df in matches:
                    expected_size = self._parse_size(entry.expected_size)
                    if expected_size and abs(df.size - expected_size) > expected_size * 0.05:  # 5% tolerance
                        self.report.size_mismatches.append({
                            "name": entry.name,
                            "expected_size": expected_size,
                            "found_size": df.size,
                            "paths": [m.path for m in matches]
                        })
            else:
                # Missing file
                self.report.missing.append({
                    "category": entry.category,
                    "name": entry.name
                })

        # Step 5: Find extra files
        for df in self.dropbox_files:
            if df.path not in matched_files:
                self.report.extra.append({
                    "path": df.path,
                    "size": df.size,
                    "modified": df.modified
                })

        # Step 6: Compute checksums
        await self._compute_checksums()

        # Step 7: Generate summary
        self.report.summary = {
            "total_manifested": len(self.manifest_entries),
            "total_found": len(self.dropbox_files),
            "missing_count": len(self.report.missing),
            "extra_count": len(self.report.extra),
            "size_mismatch_count": len(self.report.size_mismatches),
            "checksum_mismatch_count": len(self.report.checksum_mismatches)
        }

    async def _compute_checksums(self):
        """Compute SHA-256 for files ≤5GB"""
        tasks = []
        semaphore = asyncio.Semaphore(MAX_CONCURRENT_DOWNLOADS)

        for manifest_name, matches in self.report.mapping.items():
            for match in matches:
                # Find corresponding DropboxFile
                df = next((f for f in self.dropbox_files if f.path == match["path"]), None)
                if not df:
                    continue

                # Safety check
                is_safe, reason = ContentSafetyChecker.is_safe(df.name, df.path)
                if not is_safe:
                    self.report.notes.append(f"FLAGGED for review: {df.path} - {reason}")
                    continue

                # Size check
                if df.size > MAX_FILE_SIZE_FOR_CHECKSUM:
                    match["sha256_or_null"] = None
                    self.report.notes.append(f"Skipped checksum (>5GB): {df.name}")
                else:
                    tasks.append(self._compute_single_checksum(df, match, semaphore))

        if tasks:
            print(f"Computing checksums for {len(tasks)} files (max 4 concurrent)...", file=sys.stderr)
            results = await asyncio.gather(*tasks, return_exceptions=True)
            errors = [r for r in results if isinstance(r, Exception)]
            if errors:
                print(f"Checksum errors: {len(errors)} failed", file=sys.stderr)

    async def _compute_single_checksum(self, df: DropboxFile, match: Dict, semaphore):
        """Compute checksum for a single file"""
        async with semaphore:
            try:
                print(f"Downloading {df.name} ({df.size/1024/1024:.1f}MB)...", file=sys.stderr)
                content = await self.client.download_file(df.path)
                sha256 = hashlib.sha256(content).hexdigest()
                match["sha256_or_null"] = sha256
                print(f"✓ {df.name}: {sha256[:16]}...", file=sys.stderr)
            except Exception as e:
                error_msg = f"Checksum failed for {df.path}: {str(e)}"
                self.report.notes.append(error_msg)
                print(f"✗ {error_msg}", file=sys.stderr)

    @staticmethod
    def _parse_size(size_str: Optional[str]) -> Optional[int]:
        """Parse size string like '6.5GB' to bytes"""
        if not size_str:
            return None
        match = re.search(r'(\d+(?:\.\d+)?)\s*(GB|MB|KB|TB)', size_str, re.IGNORECASE)
        if not match:
            return None
        value, unit = float(match.group(1)), match.group(2).upper()
        multipliers = {'KB': 1024, 'MB': 1024**2, 'GB': 1024**3, 'TB': 1024**4}
        return int(value * multipliers.get(unit, 1))


async def main():
    """Main entry point"""
    # Load environment variables
    try:
        from dotenv import load_dotenv
        load_dotenv()
    except ImportError:
        print("Warning: python-dotenv not installed, reading from environment only", file=sys.stderr)

    # CRITICAL: Validate environment variables (never log token value)
    token = os.getenv('DROPBOX_TOKEN')
    folder = os.getenv('DROPBOX_FOLDER')

    if not token:
        print("ERROR: DROPBOX_TOKEN environment variable not set", file=sys.stderr)
        print("CONFIRM: Will read DROPBOX_TOKEN and DROPBOX_FOLDER", file=sys.stderr)
        sys.exit(1)

    if not folder:
        print("ERROR: DROPBOX_FOLDER environment variable not set", file=sys.stderr)
        print(f"CONFIRM: Will read DROPBOX_TOKEN (present) and DROPBOX_FOLDER (missing)", file=sys.stderr)
        sys.exit(1)

    print(f"CONFIRM: Environment variables loaded - DROPBOX_TOKEN and DROPBOX_FOLDER={folder}", file=sys.stderr)

    # Parse manifest
    manifest_path = "docs/COMPLETE_SOFTWARE_MANIFEST.md"
    if not os.path.exists(manifest_path):
        print(f"ERROR: Manifest not found at {manifest_path}", file=sys.stderr)
        sys.exit(1)

    parser = ManifestParser(manifest_path)
    entries = parser.parse()

    if not entries:
        print("ERROR: No entries found in manifest", file=sys.stderr)
        sys.exit(1)

    # Run audit
    try:
        async with DropboxClient(token) as client:
            engine = AuditEngine(client, entries)
            await engine.run_audit(folder)
    except Exception as e:
        print(f"ERROR during audit: {str(e)}", file=sys.stderr)
        sys.exit(1)

    # Output JSON (FIRST LINE MUST BE JSON)
    report_dict = asdict(engine.report)
    print(json.dumps(report_dict))

    # Human summary (after JSON, on stderr)
    print("\n=== AUDIT SUMMARY ===", file=sys.stderr)
    print(f"Missing: {engine.report.summary['missing_count']}", file=sys.stderr)
    print(f"Extras: {engine.report.summary['extra_count']}", file=sys.stderr)
    print(f"Size mismatches: {engine.report.summary['size_mismatch_count']}", file=sys.stderr)
    print(f"Checksum mismatches: {engine.report.summary['checksum_mismatch_count']}", file=sys.stderr)
    print(f"\nRemediation: Review missing files and consider downloading from sources listed in manifest.", file=sys.stderr)

    # Save to file
    try:
        with open('audit_report.json', 'w') as f:
            json.dump(report_dict, f, indent=2)
        print(f"\nDetailed report saved to: audit_report.json", file=sys.stderr)
    except Exception as e:
        print(f"Warning: Could not save report file: {e}", file=sys.stderr)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n\nAudit interrupted by user", file=sys.stderr)
        sys.exit(130)
    except Exception as e:
        print(f"\nFATAL ERROR: {str(e)}", file=sys.stderr)
        sys.exit(1)
