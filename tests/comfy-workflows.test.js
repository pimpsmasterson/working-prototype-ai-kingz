const assert = require('assert');
const cw = require('../server/comfy-workflows');

describe('Comfy Workflows', function() {
  it('buildWorkflow returns image workflow by default', function() {
    const wf = cw.buildWorkflow({}, 'image');
    assert.ok(wf['7']);
    assert.strictEqual(wf['7'].class_type, 'SaveImage');
  });

  it('buildWorkflow returns video workflow when type=video', function() {
    const wf = cw.buildWorkflow({}, 'video');
    assert.ok(wf['8']);
    assert.strictEqual(wf['8'].class_type, 'VHS_VideoCombine');
  });

  it('allows overriding parameters', function() {
    const wf = cw.buildWorkflow({ width: 1024, height: 768, checkpoint: 'custom.ckpt' }, 'image');
    assert.strictEqual(wf['5'].inputs.width, 1024);
    assert.strictEqual(wf['1'].inputs.ckpt_name, 'custom.ckpt');
  });
});