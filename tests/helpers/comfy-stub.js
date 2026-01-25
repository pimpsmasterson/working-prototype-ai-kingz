const express = require('express');
const bodyParser = require('body-parser');

// Simple ComfyUI stub server for test usage
function createComfyStub(options = {}) {
  const app = express();
  app.use(bodyParser.json());

  let nextPromptId = 1;

  // Store prompt -> immediate completed responses for simple E2E
  app.post('/prompt', (req, res) => {
    const promptId = `prompt_${nextPromptId++}`;

    // Save the workflow for inspection (optional)
    app._lastPrompt = { id: promptId, workflow: req.body.prompt };

    // Respond with prompt_id
    res.json({ prompt_id: promptId });
  });

  // history returns a completed result referencing an image or video
  app.get('/history/:id', (req, res) => {
    const id = req.params.id;
    // If the last prompt id matches, return completed with an image output
    const workflow = app._lastPrompt && app._lastPrompt.id === id ? app._lastPrompt.workflow : null;

    // Default completed response structure expected by generation-handler
    const outputs = {};

    if (workflow && typeof workflow === 'object') {
      // Try to detect video nodes by presence of AnimateDiffLoader or VHS_VideoCombine in node classes
      const isVideo = Object.values(workflow).some(n => n.class_type && (n.class_type === 'AnimateDiffLoader' || n.class_type === 'VHS_VideoCombine'));

      if (isVideo) {
        outputs['video_node'] = { gifs: [{ filename: 'output_video.mp4', subfolder: '', type: 'output' }] };
      } else {
        outputs['image_node'] = { images: [{ filename: 'output_image.png', subfolder: '', type: 'output' }] };
      }
    } else {
      // Fallback: return image
      outputs['image_node'] = { images: [{ filename: 'output_image.png', subfolder: '', type: 'output' }] };
    }

    const payload = {};
    payload[id] = { status: { completed: true }, outputs };

    res.json(payload);
  });

  // view returns binary content; we'll return a small PNG or MP4 placeholder buffer
  app.get('/view', (req, res) => {
    const type = req.query.type || 'output';
    const filename = req.query.filename || 'output_image.png';

    if (filename.endsWith('.mp4')) {
      // Minimal MP4 header (not valid for playback but fine for tests)
      const buf = Buffer.from('000000186674797069736f6d00000200', 'hex');
      res.setHeader('Content-Type', 'video/mp4');
      res.send(buf);
    } else {
      // Minimal PNG header
      const pngHeader = Buffer.from('89504e470d0a1a0a0000000d49484452', 'hex');
      res.setHeader('Content-Type', 'image/png');
      res.send(pngHeader);
    }
  });

  return app;
}

module.exports = { createComfyStub };
