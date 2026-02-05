# Workflow Links Audit

## Validator

Run from project root:

```bash
node scripts/validate-workflow-links.js
```

This checks every ComfyUI workflow in `scripts/workflows/` that has a `nodes` and `links` array: each link must connect existing node IDs, and every link ID referenced in node inputs/outputs must appear in the `links` array with matching source/target.

## Status (after fixes)

- **21 workflows**: All links connected and consistent.
- **1 skipped**: `nsfw_2d_3d_motion_ultimate_workflow.json` (no `nodes` array; different format).
- **5 workflows** still have link mismatches (see below). They were exported with duplicate or out-of-sync link IDs and need manual sync in ComfyUI or by editing the JSON.

## Workflows still needing link sync

These use multi-LoRA stacks and have **node output/input link IDs that are not in the `links` array**, or **links in the array that no node references**. Fix by either re-exporting from ComfyUI or by aligning node `inputs[].link` / `outputs[].links` with the `links` array and adding any missing link entries.

1. **nsfw_pony_hyperdump_cunnilingus_sexmachine_dreamlay_dreamjob_fetish_master_workflow.json**
2. **nsfw_pony_hyperdump_soiling_turtleheading_scat_master_workflow.json**
3. **nsfw_pony_multiple_fetish_stacked_master_workflow.json**
4. **nsfw_sdxl_realism_hyperdump_cunnilingus_master_workflow.json**
5. **nsfw_sdxl_soiling_turtleheading_poopsquat_scat_master_workflow.json**

## Fixes applied in this pass

- **nsfw_cinema_production_workflow.json**: Added missing link `7` (CONTEXT_OPTIONS) and `context_options` input on KSamplerAdvanced.
- **nsfw_ltx_video_workflow.json**: Aligned CLIP wiring (link 4 from text encoder to negative prompt node), node 2 outputs, and link array.
- **nsfw_ltx_camera_control_hyperdump_scat_video_workflow.json**: Trimmed redundant link IDs from node outputs so every referenced link exists in the array.
- **nsfw_sdxl_fetish_workflow.json**: Resolved duplicate link IDs (VAE 19), aligned CLIP chain (99→2→3→4→5/6), and removed duplicate link 9.
- **nsfw_wan22_dr34ml4y_dr34mjob_fetish_video_master_workflow.json**: Removed duplicate link 5 to node 6; trimmed node 3 outputs to match array.

## Server / loader

- **workflow-loader.js** `templateMap` currently points to 4 workflows used by the API. Other workflow files are available on disk for reference or future templates.
- **workflow-validator.js** validates checkpoint names against model inventory; it does not validate node/link consistency (use `scripts/validate-workflow-links.js` for that).
