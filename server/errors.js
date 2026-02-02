// server/errors.js - Centralized error handling for AI Kings generation system

/**
 * Error codes for different types of failures
 */
const ErrorCodes = {
  NO_GPU_AVAILABLE: 'NO_GPU_AVAILABLE',
  CHECKPOINT_NOT_FOUND: 'CHECKPOINT_NOT_FOUND',
  LORA_NOT_FOUND: 'LORA_NOT_FOUND',
  WORKFLOW_VALIDATION_FAILED: 'WORKFLOW_VALIDATION_FAILED',
  COMFYUI_EXECUTION_FAILED: 'COMFYUI_EXECUTION_FAILED',
  NETWORK_ERROR: 'NETWORK_ERROR',
  TIMEOUT_ERROR: 'TIMEOUT_ERROR',
  UNKNOWN_ERROR: 'UNKNOWN_ERROR'
};

/**
 * Base generation error class
 */
class GenerationError extends Error {
  constructor(message, code = ErrorCodes.UNKNOWN_ERROR, details = {}) {
    super(message);
    this.name = 'GenerationError';
    this.code = code;
    this.details = details;
  }
}

/**
 * No GPU available error
 */
class NoGPUAvailableError extends GenerationError {
  constructor(message = 'No GPU instances available for generation') {
    super(message, ErrorCodes.NO_GPU_AVAILABLE);
  }
}

/**
 * Checkpoint model not found error
 */
class CheckpointNotFoundError extends GenerationError {
  constructor(checkpointName, message = null) {
    super(message || `Checkpoint model '${checkpointName}' not found`, ErrorCodes.CHECKPOINT_NOT_FOUND, { checkpointName });
  }
}

/**
 * LoRA model not found error
 */
class LoraNotFoundError extends GenerationError {
  constructor(loraName, message = null) {
    super(message || `LoRA model '${loraName}' not found`, ErrorCodes.LORA_NOT_FOUND, { loraName });
  }
}

/**
 * Workflow validation error
 */
class WorkflowValidationError extends GenerationError {
  constructor(validationErrors, message = null) {
    super(message || `Workflow validation failed: ${validationErrors.join(', ')}`, ErrorCodes.WORKFLOW_VALIDATION_FAILED, { validationErrors });
  }
}

/**
 * ComfyUI execution error
 */
class ComfyUIExecutionError extends GenerationError {
  constructor(message, details = {}) {
    super(message, ErrorCodes.COMFYUI_EXECUTION_FAILED, details);
  }
}

/**
 * Check if an error is a generation error
 * @param {Error} error - The error to check
 * @returns {boolean} - True if it's a generation error
 */
function isGenerationError(error) {
  return error instanceof GenerationError;
}

/**
 * Convert an error to a response object
 * @param {Error} error - The error to convert
 * @returns {Object} - Response object with success, error, and details
 */
function errorToResponse(error) {
  if (isGenerationError(error)) {
    return {
      success: false,
      error: error.code,
      message: error.message,
      details: error.details
    };
  }

  // Generic error
  return {
    success: false,
    error: ErrorCodes.UNKNOWN_ERROR,
    message: error.message || 'An unknown error occurred',
    details: {}
  };
}

module.exports = {
  ErrorCodes,
  GenerationError,
  NoGPUAvailableError,
  CheckpointNotFoundError,
  LoraNotFoundError,
  WorkflowValidationError,
  ComfyUIExecutionError,
  isGenerationError,
  errorToResponse
};