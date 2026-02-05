#!/usr/bin/env node
/**
 * Validate ComfyUI workflow JSON files: ensure every link is defined and
 * connects existing nodes, and every link id referenced in nodes exists in links.
 * Supports both formats: links as array of [id, srcNode, srcSlot, tgtNode, tgtSlot, type]
 * and nodes with inputs[].link / outputs[].links.
 */

const fs = require('fs');
const path = require('path');

const WORKFLOWS_DIR = path.join(__dirname, 'workflows');

function getLinkIdsFromNode(node) {
  const ids = new Set();
  const inputs = node.inputs || [];
  const outputs = node.outputs || [];
  for (const inp of inputs) {
    if (inp.link != null) ids.add(inp.link);
  }
  for (const out of outputs) {
    const links = out.links;
    if (Array.isArray(links)) links.forEach(id => ids.add(id));
    else if (links != null) ids.add(links);
  }
  return ids;
}

function validateWorkflow(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8');
  let wf;
  try {
    wf = JSON.parse(raw);
  } catch (e) {
    return { ok: false, errors: [`Invalid JSON: ${e.message}`] };
  }

  const errors = [];
  const nodes = wf.nodes;
  const links = wf.links;

  if (!Array.isArray(nodes)) {
    return { ok: true, skipped: true, reason: 'no nodes array' };
  }
  if (!Array.isArray(links)) {
    return { ok: true, skipped: true, reason: 'no links array' };
  }

  const nodeIds = new Set(nodes.map(n => n.id));
  const linkIdsReferencedInNodes = new Set();
  const linkIdToLink = new Map();

  for (const link of links) {
    if (!Array.isArray(link) || link.length < 5) {
      errors.push(`Invalid link entry: ${JSON.stringify(link)}`);
      continue;
    }
    const [lid, srcNode, srcSlot, tgtNode, tgtSlot, type] = link;
    linkIdToLink.set(lid, { lid, srcNode, srcSlot, tgtNode, tgtSlot, type });
    if (!nodeIds.has(srcNode)) errors.push(`Link ${lid}: source node ${srcNode} not found`);
    if (!nodeIds.has(tgtNode)) errors.push(`Link ${lid}: target node ${tgtNode} not found`);
  }

  for (const node of nodes) {
    const refs = getLinkIdsFromNode(node);
    refs.forEach(id => linkIdsReferencedInNodes.add(id));
    for (const id of refs) {
      if (!linkIdToLink.has(id)) errors.push(`Node ${node.id} (${node.type}): references link ${id} which is not in links array`);
    }
  }

  for (const [lid, link] of linkIdToLink) {
    const { srcNode, srcSlot, tgtNode, tgtSlot } = link;
    const srcNodeObj = nodes.find(n => n.id === srcNode);
    const tgtNodeObj = nodes.find(n => n.id === tgtNode);
    if (srcNodeObj && tgtNodeObj) {
      const srcOut = (srcNodeObj.outputs || []).find(o => (o.links || []).includes(lid) || o.link === lid);
      const tgtIn = (tgtNodeObj.inputs || []).find(i => i.link === lid);
      if (!srcOut && !(srcNodeObj.outputs || []).some(o => Array.isArray(o.links) && o.links.includes(lid))) {
        const hasInOutput = (srcNodeObj.outputs || []).some(o => Array.isArray(o.links) && o.links.includes(lid));
        if (!hasInOutput) errors.push(`Link ${lid}: not referenced in source node ${srcNode} outputs`);
      }
      if (!tgtIn && !(tgtNodeObj.inputs || []).some(i => i.link === lid)) {
        errors.push(`Link ${lid}: not referenced in target node ${tgtNode} inputs`);
      }
    }
  }

  return {
    ok: errors.length === 0,
    errors,
    nodeCount: nodes.length,
    linkCount: links.length,
    linkIdsInLinks: linkIdToLink.size,
    linkIdsInNodes: linkIdsReferencedInNodes.size
  };
}

function main() {
  const files = fs.readdirSync(WORKFLOWS_DIR).filter(f => f.endsWith('.json'));
  let totalOk = 0;
  let totalSkipped = 0;
  let totalFail = 0;

  console.log('Validating workflow links in', WORKFLOWS_DIR, '\n');

  for (const file of files.sort()) {
    const filePath = path.join(WORKFLOWS_DIR, file);
    const result = validateWorkflow(filePath);
    if (result.skipped) {
      console.log(`⏭️  ${file}: skipped (${result.reason})`);
      totalSkipped++;
      continue;
    }
    if (result.ok) {
      console.log(`✅ ${file}: ${result.nodeCount} nodes, ${result.linkCount} links — all connected`);
      totalOk++;
    } else {
      console.log(`❌ ${file}: ${result.nodeCount} nodes, ${result.linkCount} links`);
      result.errors.forEach(e => console.log(`   - ${e}`));
      totalFail++;
    }
  }

  console.log('\n--- Summary ---');
  console.log(`OK: ${totalOk}, Skipped: ${totalSkipped}, Failed: ${totalFail}`);
  process.exit(totalFail > 0 ? 1 : 0);
}

main();
