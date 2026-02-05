# AI Agent Prompt: Verify All Provision Script Download Links

**Copy everything below the line into your AI agent. You must output the full verification result for every link in chat.**

---

You are a link-verification agent. Your task is to **test every URL below** and report the result in chat.

**Rules:**
1. For each URL, perform an HTTP HEAD request (or GET with no body / range request) to check accessibility.
2. Report for **every** URL: the exact URL (or a short id), the HTTP status code, and whether the resource is downloadable (e.g. 200 = OK, 302/307 = redirect that leads to a file, 401/403 = auth required, 404 = not found, other = describe).
3. If you get a redirect (302/307), follow it once and report the final status (or “redirects to downloadable” if the target returns 200).
4. Optionally report `Content-Length` when available (in bytes or MB).
5. **Output the full results in chat** in a single consolidated report: one line per URL (or a clear table), no truncation. Every URL below must appear in your output with its verification result.

**URLs to verify (test each one):**

**CHECKPOINTS (primary and fallback):**
1. https://www.dropbox.com/scl/fi/dd7aiju5petevb6nalinr/pmXL_v1.safetensors?rlkey=p4ukouvdd2o912ilcfbi6cqk3&dl=1
2. https://huggingface.co/stablediffusionapi/dreamshaper-8/resolve/main/dreamshaper_8.safetensors
3. https://civitai.com/api/download/models/128641
4. https://civitai.com/api/download/models/119057?type=Model&format=SafeTensor&size=pruned&fp=fp16
5. https://civitai.com/api/download/models/122606
6. https://civitai.com/api/download/models/914390?type=Model&format=SafeTensor&size=pruned&fp=fp16
7. https://www.dropbox.com/scl/fi/hy476rxzeacsx8g3aodj0/pony_realism_v2.2.safetensors?rlkey=09k5sba46pqoptdu7h1tu03b4&dl=1
8. https://civitai.com/api/download/models/290640?type=Model&format=SafeTensor&size=pruned&fp=fp16
9. https://www.dropbox.com/scl/fi/okhdb2r3i43l7f8hv07li/wai_illustrious_sdxl.safetensors?rlkey=t7r11yjr61ecdm0vrsgrkztc8&dl=1
10. https://www.dropbox.com/scl/fi/eq3qqc5rnwod3ac1xfisp/Rajii-Artist-Style-V2-Illustrious.safetensors?rlkey=cvfjam45wbmye89g2mvj245lz&dl=1
11. https://www.dropbox.com/scl/fi/6af8pzucgqyr0dy78eh6q/DR34MJOB_I2V_14b_LowNoise.safetensors?rlkey=pgnys4h98h343ibaro0fgwhqv&dl=1
12. https://www.dropbox.com/scl/fi/8280uj9myxuf2376d13jt/pornmasterPro_noobV6.safetensors?rlkey=lmduqq3jxusts1fqqexuqz72w&dl=1
13. https://www.dropbox.com/scl/fi/5whxkdo39m4w2oimcffx2/expressiveh_hentai.safetensors?rlkey=5ejkyjvethd1r7fn121x7cvs1&dl=1
14. https://www.dropbox.com/scl/fi/9drclw495plki15ynlmst/fondled.safetensors?rlkey=vh5efbuy0er4338xrkivilpnb&dl=1
15. https://www.dropbox.com/scl/fi/hp8t53h5ylrhkphnq4cyu/wan_dr34ml4y_all_in_one.safetensors?rlkey=9bq4clb4gmiz4rp6i8g69fl9u&dl=1
16. https://www.dropbox.com/scl/fi/ym112crqb6d7sdkqz5s9j/wan_dr34mjob.safetensors?rlkey=eqzd371f86g6tsof0fcecfn8n&dl=1
17. https://www.dropbox.com/scl/fi/0g4btjch885ij3kiauffm/twerk.safetensors?rlkey=8yqxhqpvs1osat76ynxadwkh8&dl=1
18. https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors
19. https://www.dropbox.com/scl/fi/3qygk64xe2ui2ey74neto/sdxl_vae.safetensors?rlkey=xzsllv3hq5w1qx81h9b2xryq8&dl=1
20. https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors?download=true
21. https://huggingface.co/stabilityai/stable-diffusion-xl-refiner-1.0/resolve/main/sd_xl_refiner_1.0.safetensors?download=true
22. https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-distilled.safetensors

**LORAS:**
23. https://huggingface.co/LyliaEngine/ponyRealism_v21MainVAE/resolve/main/ponyRealism_v21MainVAE.safetensors
24. https://civitai.com/api/download/models/152309
25. https://huggingface.co/Lightricks/LTX-2-19b-LoRA-Camera-Control-Dolly-Left/resolve/main/ltx-2-19b-lora-camera-control-dolly-left.safetensors
26. https://huggingface.co/JollyIm/Defecation/resolve/main/defecation_v1.safetensors
27. https://files.catbox.moe/wmshk3.safetensors
28. https://files.catbox.moe/88e51n.rar
29. https://files.catbox.moe/9qixqa.safetensors
30. https://files.catbox.moe/yz5c9g.safetensors
31. https://files.catbox.moe/tlt57h.safetensors
32. https://files.catbox.moe/odmswn.safetensors
33. https://files.catbox.moe/z71ic0.safetensors
34. https://files.catbox.moe/mxbbg2.safetensors
35. https://huggingface.co/BlackHat404/scatmodels/resolve/main/Soiling-V1.safetensors
36. https://huggingface.co/BlackHat404/scatmodels/resolve/main/turtleheading-V1.safetensors
37. https://huggingface.co/BlackHat404/scatmodels/resolve/main/poop_squatV2.safetensors
38. https://huggingface.co/BlackHat404/scatmodels/resolve/main/Poop_SquatV3.safetensors
39. https://huggingface.co/BlackHat404/scatmodels/resolve/main/HyperDump.safetensors
40. https://huggingface.co/BlackHat404/scatmodels/resolve/main/HyperDumpPlus.safetensors

**WAN DIFFUSION & CLIP:**
41. https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_t2v_1.3B_fp16.safetensors
42. https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors
43. https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors
44. https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors
45. https://civitai.com/api/download/models/2567309?type=Model&format=SafeTensor&size=pruned&fp=fp8
46. https://civitai.com/api/download/models/915814?type=Model&format=SafeTensor&size=pruned&fp=fp16
47. https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn.safetensors
48. https://huggingface.co/Comfy-Org/LTX-2/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors

**WAN LORAS:**
49. https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors
50. https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors
51. https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors
52. https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors

**TEXT ENCODERS & VAES:**
53. https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors
54. https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan2.1_vae.safetensors
55. https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors
56. https://huggingface.co/Comfy-Org/Lumina_Image_2.0_Repackaged/resolve/main/split_files/vae/ae.safetensors
57. https://civitai.com/api/download/models/105924

**ANIMATEDIFF:**
58. https://huggingface.co/guoyww/animatediff/resolve/main/mm_sdxl_v10_beta.ckpt
59. https://huggingface.co/guoyww/animatediff/resolve/main/mm_sd_v15_v2.ckpt

**UPSCALE:**
60. https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth
61. https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth
62. https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-spatial-upscaler-x2-1.0.safetensors

**CONTROLNET & DETECTORS:**
63. https://huggingface.co/thibaud/controlnet-openpose-sdxl-1.0/resolve/main/OpenPoseXL2.safetensors
64. https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt
65. https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8n.pt
66. https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth

**RIFE:**
67. https://huggingface.co/r3gm/RIFE/resolve/main/RIFEv4.26_0921.zip

**FLUX:**
68. https://huggingface.co/Comfy-Org/FLUX.1-Krea-dev_ComfyUI/resolve/main/split_files/diffusion_models/flux1-krea-dev_fp8_scaled.safetensors
69. https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors
70. https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors

**LTX-2:**
71. https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-dev-fp8.safetensors
72. https://huggingface.co/Lightricks/LTX-2-19b-LoRA-Camera-Control-Dolly-Left/resolve/main/ltx-2-19b-lora-camera-control-dolly-left.safetensors
73. https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-distilled-lora-384.safetensors

**End of URL list. Total: 73 URLs.**

Output format requirement: For each URL 1–73, print one line (or table row) with: index, status code, downloadable (yes/no), and optional size. Example:
`1. [URL short] → 200 OK, downloadable, 6.5GB`
or
`1. 302 → redirects to file, downloadable`
Do not omit any URL. Full output in chat.
