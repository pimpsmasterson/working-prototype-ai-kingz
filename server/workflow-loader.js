// server/workflow-loader.js - Template-based workflow loader
// Loads and hydrates ComfyUI workflow templates from JSON files

const fs = require('fs');
const path = require('path');

// Template mappings (template name -> file path)
const templateMap = {
  'fetish_image_lora': path.join(__dirname, '..', 'scripts', 'workflows', 'nsfw_lora_image_workflow.json'),
  'nsfw_video_animatediff': path.join(__dirname, '..', 'scripts', 'workflows', 'nsfw_video_workflow.json'),
  'nsfw_image_pony': path.join(__dirname, '..', 'scripts', 'workflows', 'nsfw_ultimate_image_workflow.json'),
  'sfw_image_dreamshaper': path.join(__dirname, '..', 'scripts', 'workflows', 'nsfw_cinema_production_workflow.json'), // fallback
  // Add more mappings as needed
};

/**
 * Check if a template exists
 * @param {string} templateName - Name of the template
 * @returns {boolean} - True if template exists
 */
function hasTemplate(templateName) {
  return templateMap.hasOwnProperty(templateName) && fs.existsSync(templateMap[templateName]);
}

/**
 * Load and hydrate a workflow template with parameters
 * @param {string} templateName - Name of the template
 * @param {Object} params - Parameters to inject into the template
 * @returns {Object} - Hydrated workflow JSON
 */
function hydrateTemplate(templateName, params = {}) {
  if (!hasTemplate(templateName)) {
    throw new Error(`Template '${templateName}' not found`);
  }

  const templatePath = templateMap[templateName];
  const templateJson = fs.readFileSync(templatePath, 'utf8');
  let workflow = JSON.parse(templateJson);

  // Simple string replacement for common parameters
  // This is a basic implementation - may need enhancement based on actual template structure
  const replacements = {
    '{{prompt}}': params.prompt || 'beautiful fantasy',
    '{{negativePrompt}}': params.negativePrompt || 'ugly, deformed',
    '{{width}}': params.width || 512,
    '{{height}}': params.height || 768,
    '{{steps}}': params.steps || 25,
    '{{cfgScale}}': params.cfgScale || 7,
    '{{seed}}': params.seed || Math.floor(Math.random() * 1000000000),
    '{{checkpoint}}': params.checkpoint || 'ponyDiffusionV6XL.safetensors',
    '{{loraName}}': params.loraName || 'pony_realism_v2.1.safetensors',
    '{{loraStrength}}': params.loraStrength || 0.8,
    // Add more as needed
  };

  // Convert workflow to string, replace, parse back
  let workflowStr = JSON.stringify(workflow);
  for (const [placeholder, value] of Object.entries(replacements)) {
    workflowStr = workflowStr.replace(new RegExp(placeholder, 'g'), value);
  }

  return JSON.parse(workflowStr);
}

module.exports = {
  hasTemplate,
  hydrateTemplate,
  templateMap
};