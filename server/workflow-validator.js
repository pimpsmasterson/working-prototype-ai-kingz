// server/workflow-validator.js - Workflow validation utilities

/**
 * Validate a workflow against available models
 * @param {Object} workflow - The workflow JSON
 * @param {Object} modelInventory - Available models inventory
 * @returns {Object} - Validation result {valid: boolean, errors: []}
 */
function validateWorkflow(workflow, modelInventory) {
  const errors = [];

  // Basic validation - check if workflow has nodes
  if (!workflow || typeof workflow !== 'object') {
    errors.push('Invalid workflow: not an object');
    return { valid: false, errors };
  }

  // Check for required models in checkpoints
  const checkpoints = [];
  Object.values(workflow).forEach(node => {
    if (node.class_type === 'CheckpointLoaderSimple' && node.inputs?.ckpt_name) {
      checkpoints.push(node.inputs.ckpt_name);
    }
  });

  // If modelInventory provided, validate checkpoints exist
  if (modelInventory && modelInventory.checkpoints) {
    checkpoints.forEach(checkpoint => {
      if (!modelInventory.checkpoints.includes(checkpoint)) {
        errors.push(`Checkpoint '${checkpoint}' not found in model inventory`);
      }
    });
  }

  return {
    valid: errors.length === 0,
    errors
  };
}

/**
 * Throw a validation error
 * @param {Object} validation - Validation result from validateWorkflow
 */
function throwValidationError(validation) {
  if (!validation.valid) {
    const error = new Error(`Workflow validation failed: ${validation.errors.join(', ')}`);
    error.validationErrors = validation.errors;
    throw error;
  }
}

module.exports = {
  validateWorkflow,
  throwValidationError
};