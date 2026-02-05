#!/usr/bin/env node
/**
 * Dropbox Manifest Verification Script
 * Compares files in Dropbox against COMPLETE_SOFTWARE_MANIFEST.md
 */

const fs = require('fs');
const path = require('path');
const fetch = require('node-fetch');

const DROPBOX_TOKEN = process.env.DROPBOX_TOKEN;
const DROPBOX_FOLDER = process.env.DROPBOX_FOLDER || '/workspace/pornmaster100';
const MANIFEST_PATH = 'docs/COMPLETE_SOFTWARE_MANIFEST.md';

if (!DROPBOX_TOKEN) {
  console.error('❌ DROPBOX_TOKEN environment variable not set');
  process.exit(1);
}

// Dropbox API helper
async function dropboxAPI(endpoint, body) {
  const res = await fetch('https://api.dropboxapi.com/2' + endpoint, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${DROPBOX_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(body)
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Dropbox API error (${res.status}): ${text.substring(0, 500)}`);
  }

  return res.json();
}

// List all files recursively
async function listAllFiles(folderPath) {
  console.log(`📂 Listing files in: ${folderPath}`);
  const files = [];
  
  let result = await dropboxAPI('/files/list_folder', {
    path: folderPath,
    recursive: true,
    limit: 2000
  });

  files.push(...result.entries.filter(e => e['.tag'] === 'file'));

  let page = 1;
  while (result.has_more) {
    page++;
    console.log(`   Fetching page ${page}...`);
    result = await dropboxAPI('/files/list_folder/continue', {
      cursor: result.cursor
    });
    files.push(...result.entries.filter(e => e['.tag'] === 'file'));
  }

  return files;
}

// Parse manifest for expected model files
function parseManifest() {
  const content = fs.readFileSync(MANIFEST_PATH, 'utf-8');
  const lines = content.split('\n');
  
  const models = {
    checkpoints: [],
    loras: [],
    vaes: [],
    upscalers: [],
    controlnet: [],
    detection: [],
    rife: [],
    text_encoders: [],
    animatediff: [],
    video_wan: [],
    video_ltx: [],
    flux: []
  };

  let currentCategory = null;

  for (const line of lines) {
    // Detect category headers
    if (line.includes('## 🎭 AI MODELS - CHECKPOINTS') || line.includes('Image Generation Models')) {
      currentCategory = 'checkpoints';
    } else if (line.includes('## 🎨 AI MODELS - LORAS') || line.includes('General LoRAs') || line.includes('Fetish LoRAs')) {
      currentCategory = 'loras';
    } else if (line.includes('## 🎨 AI MODELS - VAES')) {
      currentCategory = 'vaes';
    } else if (line.includes('## 🔍 AI MODELS - UPSCALERS')) {
      currentCategory = 'upscalers';
    } else if (line.includes('## 🎮 AI MODELS - CONTROLNET')) {
      currentCategory = 'controlnet';
    } else if (line.includes('## 🔎 AI MODELS - DETECTION')) {
      currentCategory = 'detection';
    } else if (line.includes('## 🎞️ AI MODELS - FRAME INTERPOLATION')) {
      currentCategory = 'rife';
    } else if (line.includes('## 📝 AI MODELS - TEXT ENCODERS')) {
      currentCategory = 'text_encoders';
    } else if (line.includes('## 🎬 AI MODELS - ANIMATEDIFF')) {
      currentCategory = 'animatediff';
    } else if (line.includes('## 🎬 AI MODELS - VIDEO (WAN)')) {
      currentCategory = 'video_wan';
    } else if (line.includes('## 🎥 AI MODELS - VIDEO (LTX-2)')) {
      currentCategory = 'video_ltx';
    } else if (line.includes('## ⚡ AI MODELS - FLUX')) {
      currentCategory = 'flux';
    }

    // Parse table rows (markdown format: | name | size | ... |)
    if (currentCategory && line.includes('|') && !line.startsWith('|---')) {
      const parts = line.split('|').map(p => p.trim()).filter(p => p);
      if (parts.length >= 2) {
        // Extract model name (remove backticks, brackets, etc.)
        let name = parts[0].replace(/`/g, '').replace(/\[/g, '').replace(/\]/g, '').trim();
        
        // Skip header rows
        if (name && !['Model', 'Package', 'Name', 'File', 'Type', 'Size', 'Source', 'Purpose'].includes(name)) {
          // Extract size if available
          let size = parts.length >= 2 ? parts[1] : null;
          
          models[currentCategory].push({ name, size, category: currentCategory });
        }
      }
    }
  }

  return models;
}

// Normalize filename for comparison
function normalizeName(name) {
  return name.toLowerCase()
    .replace(/\s+/g, '_')
    .replace(/[^\w\-\.]/g, '')
    .trim();
}

// Main audit
async function main() {
  console.log('╔═══════════════════════════════════════════════════════╗');
  console.log('║   DROPBOX MANIFEST VERIFICATION                       ║');
  console.log('╚═══════════════════════════════════════════════════════╝\n');

  // Step 1: Parse manifest
  console.log('📋 Parsing manifest...');
  const expectedModels = parseManifest();
  const totalExpected = Object.values(expectedModels).reduce((sum, cat) => sum + cat.length, 0);
  console.log(`   Found ${totalExpected} expected models in manifest\n`);

  // Step 2: List Dropbox files
  console.log('☁️  Fetching Dropbox files...');
  const dropboxFiles = await listAllFiles(DROPBOX_FOLDER);
  console.log(`   Found ${dropboxFiles.length} total files in Dropbox\n`);

  // Step 3: Build filename lookup
  const dropboxByName = new Map();
  dropboxFiles.forEach(file => {
    const filename = file.name;
    const normalized = normalizeName(filename);
    
    if (!dropboxByName.has(normalized)) {
      dropboxByName.set(normalized, []);
    }
    dropboxByName.get(normalized).push({
      path: file.path_display,
      size: file.size,
      sizeMB: (file.size / 1024 / 1024).toFixed(1) + 'MB'
    });
  });

  // Step 4: Compare
  console.log('🔍 Comparing manifest vs Dropbox...\n');
  
  const results = {
    found: [],
    missing: [],
    extra: []
  };

  // Check each expected model
  for (const [category, models] of Object.entries(expectedModels)) {
    for (const model of models) {
      const normalized = normalizeName(model.name);
      const found = dropboxByName.get(normalized);
      
      if (found) {
        results.found.push({
          category,
          name: model.name,
          expectedSize: model.size,
          foundPaths: found
        });
        dropboxByName.delete(normalized); // Remove from map
      } else {
        results.missing.push({
          category,
          name: model.name,
          expectedSize: model.size
        });
      }
    }
  }

  // Remaining files are "extra" (not in manifest)
  dropboxByName.forEach((files, normalized) => {
    files.forEach(file => {
      // Only flag model files as extra (skip logs, configs, etc.)
      if (file.path.match(/\.(safetensors|ckpt|pth|pt|bin|msgpack)$/i)) {
        results.extra.push(file);
      }
    });
  });

  // Step 5: Report
  console.log('╔═══════════════════════════════════════════════════════╗');
  console.log('║   AUDIT RESULTS                                       ║');
  console.log('╚═══════════════════════════════════════════════════════╝\n');

  console.log(`✅ Found: ${results.found.length}/${totalExpected} models`);
  console.log(`❌ Missing: ${results.missing.length} models`);
  console.log(`➕ Extra: ${results.extra.length} files (not in manifest)\n`);

  // Show missing files
  if (results.missing.length > 0) {
    console.log('❌ MISSING FILES:\n');
    results.missing.forEach(m => {
      console.log(`   [${m.category}] ${m.name} (${m.expectedSize || 'unknown size'})`);
    });
    console.log('');
  }

  // Show sample of found files
  if (results.found.length > 0) {
    console.log('✅ SAMPLE OF FOUND FILES (first 20):\n');
    results.found.slice(0, 20).forEach(f => {
      const paths = f.foundPaths.map(p => `${p.path} (${p.sizeMB})`).join(', ');
      console.log(`   [${f.category}] ${f.name}`);
      console.log(`      → ${paths}`);
    });
    if (results.found.length > 20) {
      console.log(`   ... and ${results.found.length - 20} more`);
    }
    console.log('');
  }

  // Show extra files
  if (results.extra.length > 0) {
    console.log('➕ EXTRA FILES (not in manifest, first 30):\n');
    results.extra.slice(0, 30).forEach(f => {
      console.log(`   ${f.path} (${f.sizeMB})`);
    });
    if (results.extra.length > 30) {
      console.log(`   ... and ${results.extra.length - 30} more`);
    }
    console.log('');
  }

  // Summary verdict
  console.log('╔═══════════════════════════════════════════════════════╗');
  console.log('║   VERDICT                                             ║');
  console.log('╚═══════════════════════════════════════════════════════╝\n');

  if (results.missing.length === 0) {
    console.log('✅ ALL MANIFEST FILES PRESENT IN DROPBOX');
    console.log('   Ready to provision new instance from this backup\n');
  } else {
    console.log('⚠️  SOME FILES MISSING FROM DROPBOX');
    console.log(`   ${results.missing.length} files need to be uploaded before provisioning\n`);
  }

  // Write detailed report
  const reportPath = 'data/dropbox_audit_report.json';
  fs.mkdirSync('data', { recursive: true });
  fs.writeFileSync(reportPath, JSON.stringify(results, null, 2));
  console.log(`📄 Detailed report saved to: ${reportPath}\n`);

  process.exit(results.missing.length === 0 ? 0 : 1);
}

main().catch(err => {
  console.error('\n❌ ERROR:', err.message);
  process.exit(1);
});
