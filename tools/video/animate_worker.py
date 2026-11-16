"""Runs on the Colab machine: tools/video/animate.py uploads it and starts it there.

Turns each painting into a few seconds of animation with the open Wan 2.2 image-to-video model (Apache 2.0, about
120 GB, downloaded to the machine the first time). Reads /content/jobs.json, a list of
{"name", "image", "prompt", "area", "frames", "steps", "seed"}; the images are in /content/in. Writes
/content/out/<name>.mp4 (16 frames a second, next to lossless) and a line for every step to /content/worker.log, which
ends with ALL DONE or WORKER FAILED.
"""
import inspect
import json
import os
import subprocess
import time
import traceback

LOG = "/content/worker.log"
MODEL = "Wan-AI/Wan2.2-I2V-A14B-Diffusers"
LIGHTNING = "lightx2v/Wan2.2-Lightning"            # Apache 2.0; a job with "lightning" uses it
LIGHTNING_FILE = "Wan2.2-I2V-A14B-4steps-lora-rank64-Seko-V1/%s_noise_model.safetensors"
NEGATIVE = ("still picture, frozen, no motion, blurry details, subtitles, text, letters, watermark, worst quality, low quality, "
            "JPEG artifacts, ugly, deformed, extra fingers, badly drawn hands, badly drawn face, malformed limbs, fused fingers, "
            "extra arms, extra characters, flicker, morphing, camera shake")


def log(msg):
    with open(LOG, "a") as f:
        f.write("%s %s\n" % (time.strftime("%H:%M:%S"), msg))


def save(frames, path):
    """frames: (n, h, w, 3) floats from 0 to 1 -> an mp4 that loses next to nothing"""
    import numpy as np
    a = (np.clip(frames, 0.0, 1.0) * 255.0 + 0.5).astype("uint8")
    _n, h, w, _c = a.shape
    p = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (w, h), "-r", "16",
                          "-i", "-", "-c:v", "libx264", "-preset", "medium", "-crf", "10", "-pix_fmt", "yuv420p", path], stdin=subprocess.PIPE)
    p.stdin.write(a.tobytes())
    p.stdin.close()
    if p.wait() != 0:
        raise RuntimeError("ffmpeg failed on " + path)


def main():
    import numpy as np
    import torch
    from diffusers import WanImageToVideoPipeline
    from PIL import Image
    jobs = json.load(open("/content/jobs.json"))
    log("loading the model (the first time, it is downloaded)")
    pipe = WanImageToVideoPipeline.from_pretrained(MODEL, torch_dtype=torch.bfloat16)
    if any(j.get("lightning") for j in jobs):      # the Lightning add-on: 4 steps instead of 40, one pass each instead of two
        log("loading the Lightning add-on")
        pipe.load_lora_weights(LIGHTNING, weight_name=LIGHTNING_FILE % "high", adapter_name="fast")
        pipe.load_lora_weights(LIGHTNING, weight_name=LIGHTNING_FILE % "low", adapter_name="fast_2", load_into_transformer_2=True)
        try:
            pipe.set_adapters(["fast", "fast_2"], adapter_weights=[1.0, 1.0])
        except Exception as e:                     # (each is on already, in its own half of the model)
            log("set_adapters: %s" % e)
    pipe.enable_model_cpu_offload()                # one big part on the graphics card at a time
    two = "guidance_scale_2" in inspect.signature(pipe.__call__).parameters
    log("model ready, %d jobs" % len(jobs))
    os.makedirs("/content/out", exist_ok=True)
    mod = pipe.vae_scale_factor_spatial * pipe.transformer.config.patch_size[1]
    for job in jobs:
        out = "/content/out/%s.mp4" % job["name"]
        if os.path.exists(out):
            continue
        image = Image.open("/content/in/" + job["image"]).convert("RGB")
        area, steps = float(job.get("area", 1152 * 768)), int(job.get("steps", 40))
        while True:
            ratio = image.height / image.width
            h = int(round(np.sqrt(area * ratio))) // mod * mod
            w = int(round(np.sqrt(area / ratio))) // mod * mod
            t0 = time.time()

            def step(_pipe, i, _t, kw, name=job["name"], t0=t0):
                log("%s step %d/%d  %.0f s" % (name, i + 1, steps, time.time() - t0))
                return kw
            try:
                frames = pipe(image=image.resize((w, h), Image.LANCZOS), prompt=job["prompt"], negative_prompt=NEGATIVE, height=h, width=w,
                              num_frames=int(job.get("frames", 81)), guidance_scale=float(job.get("guidance", 3.5)),
                              num_inference_steps=steps, generator=torch.Generator(device="cuda").manual_seed(int(job.get("seed", 0))),
                              output_type="np", callback_on_step_end=step,
                              **({"guidance_scale_2": float(job.get("guidance", 3.5))} if two else {})).frames[0]
                break
            except torch.OutOfMemoryError:
                log("%s: out of memory at %dx%d, trying smaller" % (job["name"], w, h))
                torch.cuda.empty_cache()
                area *= 0.7
                if area < 400 * 600:
                    raise
        save(frames, out + ".part.mp4")
        os.replace(out + ".part.mp4", out)
        log("done %s %dx%d in %.0f s" % (job["name"], w, h, time.time() - t0))
    log("ALL DONE")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        log("WORKER FAILED\n" + traceback.format_exc()[-1800:])
