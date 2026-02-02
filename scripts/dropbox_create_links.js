#!/usr/bin/env node
// scripts/dropbox_create_links.js
// Usage:
//   DROPBOX_TOKEN=sl.TOKEN node scripts/dropbox_create_links.js --list /FolderPath
//   DROPBOX_TOKEN=sl.TOKEN node scripts/dropbox_create_links.js --find /FolderPath
//   DROPBOX_TOKEN=sl.TOKEN node scripts/dropbox_create_links.js /FolderPath   # create links for files in that folder
//
// Options:
//   --list   : list immediate children (folders/files) of a path and print paths
//   --find   : recursively find candidate model files (by extension) and print their paths
//   (no flag) : create shared links for files in the specified folder and write data/dropbox_links.txt

const fs = require('fs');
const fetch = require('node-fetch');

const token = process.env.DROPBOX_TOKEN;
if (!token) {
  console.error('Set DROPBOX_TOKEN env var (must include files.metadata.read, files.content.read, sharing.write scopes)');
  process.exit(1);
}

const argv = process.argv.slice(2);
if (argv.length === 0) {
  console.error('Provide a path (e.g. /Models) and optionally --list or --find');
  console.error('Usage: DROPBOX_TOKEN=... node scripts/dropbox_create_links.js --list /FolderPath');
  process.exit(1);
}

let mode = 'create';
let folder = argv[0];
if (argv[0] === '--list' || argv[0] === '--find') {
  mode = argv[0].substring(2);
  folder = argv[1] || '';
}

if (!folder) {
  console.error('Folder path required (e.g. / and then inspect children).');
  process.exit(1);
}

async function api(endpoint, body) {
  const res = await fetch('https://api.dropboxapi.com/2' + endpoint, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(body)
  });
  if (!res.ok) {
    const json = await res.json().catch(() => ({}));
    const err = json.error_summary || JSON.stringify(json);
    const e = new Error('Dropbox API error: ' + err);
    e.json = json;
    throw e;
  }
  return res.json();
}

async function listFolder(p, recursive = false) {
  const out = [];
  let cursor = null;
  try {
    let res = await api('/files/list_folder', { path: p, recursive });
    out.push(...res.entries);
    while (res.has_more) {
      res = await api('/files/list_folder/continue', { cursor: res.cursor });
      out.push(...res.entries);
    }
  } catch (err) {
    throw err;
  }
  return out;
}

function humanEntries(entries) {
  return entries.map(e => ({ name: e.name, path: e.path_display, tag: e['.tag'] }));
}

function isModelFile(name) {
  const exts = ['.safetensors', '.ckpt', '.pth', '.pt', '.bin', '.msgpack'];
  const n = name.toLowerCase();
  return exts.some(ext => n.endsWith(ext));
}

(async () => {
  try {
    if (mode === 'list') {
      const entries = await listFolder(folder, false);
      const simple = humanEntries(entries);
      console.log('Entries in', folder);
      simple.forEach(s => console.log(`${s.tag}\t${s.path}`));
      process.exit(0);
    }

    if (mode === 'find') {
      const entries = await listFolder(folder, true);
      const files = entries.filter(e => e['.tag'] === 'file' && isModelFile(e.name));
      if (!files.length) {
        console.log('No model files found under', folder);
        process.exit(0);
      }
      console.log('Found model files:');
      files.forEach(f => console.log(f.path_display));
      process.exit(0);
    }

    // create mode: list immediate files and create links for files only (not folders)
    const entries = await listFolder(folder, false);
    const files = entries.filter(e => e['.tag'] === 'file');
    if (!files.length) {
      console.log('No files found in', folder, '- try --list to view children or --find to search recursively');
      process.exit(0);
    }

    console.log('Creating shared links for', files.length, 'files in', folder);

    const outLines = [];
    for (const e of files) {
      const path = e.path_display;
      let url = null;
      try {
        const created = await api('/sharing/create_shared_link_with_settings', { path, settings: { requested_visibility: 'public' } });
        url = created.url;
      } catch (err) {
        // If missing scope, show a helpful message
        if (err.json && err.json.error && err.json.error['.tag'] === 'missing_scope') {
          console.error('Dropbox token missing required scope:', err.json.error.required_scope || JSON.stringify(err.json.error));
          console.error('Ensure your token has: files.metadata.read, files.content.read, sharing.write');
          process.exit(1);
        }
        // fallback: try list_shared_links
        try {
          const listLinks = await api('/sharing/list_shared_links', { path, direct_only: true });
          if (listLinks && listLinks.links && listLinks.links.length) url = listLinks.links[0].url;
        } catch (err2) {
          console.error('Failed to create or list link for', path, err2 && err2.message ? err2.message : err2);
          continue;
        }
      }
      if (!url) continue;
      // Normalize to direct-download (dl=1). Use URL parsing to handle both ?dl=0 and &dl=0 cases.
      let direct = url;
      try {
        const u = new URL(url);
        u.searchParams.set('dl', '1');
        direct = u.toString();
      } catch (e) {
        // Fallback for unexpected URL formats
        direct = url.replace(/([?&])dl=0/, '$1dl=1').replace(/([?&])dl=1.*$/, '$1dl=1');
      }
      outLines.push(`${direct}|${e.name}`);
      console.log(`Added: ${e.name}`);
    }
    if (!outLines.length) {
      console.log('No downloadable files generated');
      process.exit(0);
    }
    fs.mkdirSync('data', { recursive: true });
    fs.writeFileSync('data/dropbox_links.txt', outLines.join('\n') + '\n');
    console.log('Wrote data/dropbox_links.txt with', outLines.length, 'entries');
  } catch (err) {
    if (err.json && err.json.error_summary && err.json.error_summary.includes('missing_scope')) {
      console.error('Error: Dropbox token missing required scope. Ensure token has scopes: files.metadata.read, files.content.read, sharing.write');
    } else {
      console.error('Error:', err && err.message ? err.message : err);
    }
    process.exit(1);
  }
})();