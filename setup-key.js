#!/usr/bin/env node
/**
 * Simple one-time setup: create SSH key and register with Vast.ai.
 * Uses VASTAI_API_KEY from .env - no manual steps.
 */
require('dotenv').config({ path: require('path').join(__dirname, '.env') });

const vastai = require('./lib/vastai-ssh');

async function main() {
  console.log('');
  console.log('========================================');
  console.log('  AI Kings - SSH Key Setup');
  console.log('========================================');
  console.log('');

  const apiKey = process.env.VASTAI_API_KEY;
  if (!apiKey) {
    console.error('ERROR: VASTAI_API_KEY not found in .env file.');
    console.error('Add it to your .env file and try again.');
    process.exit(1);
  }

  try {
    console.log('Step 1: Creating SSH key...');
    const keyPath = vastai.getKey();
    console.log('   OK - Key at:', keyPath);
    console.log('');

    console.log('Step 2: Registering key with Vast.ai...');
    const ok = await vastai.registerKey(apiKey);
    if (ok) {
      console.log('   OK - Key registered!');
    } else {
      console.log('   (Key may already be registered - that is fine)');
    }
    console.log('');
    console.log('========================================');
    console.log('  DONE! You can now use OPEN-COMFY.bat');
    console.log('========================================');
    console.log('');
    process.exit(0);
  } catch (err) {
    console.error('');
    console.error('ERROR:', err.message);
    process.exit(1);
  }
}

main();
