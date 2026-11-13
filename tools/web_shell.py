"""The web game's loading page (the Web export's custom HTML shell): the painted bay, the logo and a progress bar, all
inside one small page, so something nice shows at once instead of a blank screen and then an 800 KB splash picture.

    python tools/web_shell.py        -> assets/web/shell.html (export_presets.cfg, Web: html/custom_html_shell)

Run it again when the bay painting or the logo changes. assets/web has a .gdignore: none of it goes into the game's pck.
The page keeps Godot's own loader logic (the $GODOT_* placeholders, the service worker retry, the error notice).
"""
import base64
import io
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "web", "shell.html")

LINES = ["Waking up the captain", "Untangling the line", "Bribing the gulls", "Polishing the Derby Cup",
         "Counting the fish (there are a lot)", "Teaching the crabs to walk sideways", "Inflating the pufferfish",
         "Hiding Gerald's moustache", "Warming up the Reel it in! net"]


def data_uri(im, fmt, **kw):
    b = io.BytesIO()
    im.save(b, fmt, **kw)
    return "data:image/%s;base64,%s" % (fmt.lower(), base64.b64encode(b.getvalue()).decode())


def main():
    bay = Image.open(os.path.join(ROOT, "assets", "launcher", "launcher_bg.jpg")).convert("RGB").resize((960, 540), Image.LANCZOS)
    logo = Image.open(os.path.join(ROOT, "assets", "brand", "logo.png")).convert("RGBA")
    logo = logo.resize((440, round(440 * logo.height / logo.width)), Image.LANCZOS)
    page = PAGE.replace("%BAY%", data_uri(bay, "JPEG", quality=60, optimize=True, progressive=True))
    page = page.replace("%LOGO%", data_uri(logo, "WEBP", quality=88, method=6))
    page = page.replace("%LINES%", "[" + ", ".join('"%s"' % s for s in LINES) + "]")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(page)
    gi = os.path.join(os.path.dirname(OUT), ".gdignore")
    if not os.path.exists(gi):
        open(gi, "w").close()
    print("wrote", OUT, "%.0f KB" % (os.path.getsize(OUT) / 1024))


PAGE = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0">
<title>$GODOT_PROJECT_NAME</title>
<meta name="description" content="fosh&fish: a cosy fishing game. Cast, catch, collect and sail through seven biomes.">
<meta name="theme-color" content="#2a8fa0">
<style>
html, body, #canvas { margin: 0; padding: 0; border: 0; }
body { color: #fff; background: #2a8fa0; overflow: hidden; touch-action: none; font-family: "Fredoka", "Nunito", "Segoe UI", system-ui, sans-serif; }
#canvas { display: block; }
#canvas:focus { outline: none; }
#status { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center;
  background: #2a8fa0 url("%BAY%") center / cover no-repeat; transition: opacity .45s ease; z-index: 2; }
#status::before { content: ""; position: absolute; inset: 0; background: linear-gradient(180deg, rgba(16,48,58,.15) 0%, rgba(16,48,58,.0) 35%, rgba(16,48,58,.55) 100%); }
#status.gone { opacity: 0; pointer-events: none; }
#box { position: relative; display: flex; flex-direction: column; align-items: center; gap: 14px; width: min(86vw, 460px); margin-top: -4vh; }
@media (min-aspect-ratio: 4/3) { #box { margin-left: 38vw; } }   /* wide screens: over the open water, clear of the captain (where the title screen has its logo) */
#logo { width: min(64vw, 330px); height: auto; max-height: 42vh; object-fit: contain; filter: drop-shadow(0 6px 14px rgba(0,0,0,.28)); animation: bob 3.2s ease-in-out infinite; }
@keyframes bob { 0%, 100% { transform: translateY(0) rotate(-1deg); } 50% { transform: translateY(-8px) rotate(1deg); } }
#bar { width: 100%; height: 16px; border-radius: 99px; background: rgba(16,48,58,.55); border: 2px solid #ffd75e; overflow: hidden;
  box-shadow: 0 4px 14px rgba(0,0,0,.25); }
#fill { height: 100%; width: 0%; border-radius: 99px; background: linear-gradient(90deg, #ffd75e, #ffb03a); transition: width .25s ease; }
#bar.wait #fill { width: 30%; animation: slide 1.4s ease-in-out infinite; }
@keyframes slide { 0% { transform: translateX(-110%); } 100% { transform: translateX(360%); } }
#line { font-size: 17px; font-weight: 600; text-shadow: 0 2px 6px rgba(0,0,0,.45); text-align: center; min-height: 1.3em; }
#size { font-size: 13px; opacity: .85; text-shadow: 0 1px 4px rgba(0,0,0,.5); min-height: 1.2em; }
#status-notice { display: none; max-width: 520px; margin: 0 1.5rem; padding: 1rem 1.2rem; border-radius: 14px; background: #fff8ec;
  color: #2b3a40; font-size: 15px; line-height: 1.4; text-align: center; box-shadow: 0 8px 24px rgba(0,0,0,.3); }
</style>
$GODOT_HEAD_INCLUDE
</head>
<body>
<canvas id="canvas">Your browser does not support the canvas tag.</canvas>
<noscript>fosh&fish needs JavaScript to run.</noscript>
<div id="status">
  <div id="box">
    <img id="logo" src="%LOGO%" alt="fosh&fish">
    <div id="bar" class="wait"><div id="fill"></div></div>
    <div id="line">Getting the boat ready</div>
    <div id="size"></div>
    <div id="status-notice"></div>
  </div>
</div>
<script src="$GODOT_URL"></script>
<script>
const GODOT_CONFIG = $GODOT_CONFIG;
const GODOT_THREADS_ENABLED = $GODOT_THREADS_ENABLED;
const engine = new Engine(GODOT_CONFIG);

(function () {
	const status = document.getElementById('status');
	const bar = document.getElementById('bar');
	const fill = document.getElementById('fill');
	const line = document.getElementById('line');
	const size = document.getElementById('size');
	const notice = document.getElementById('status-notice');
	const lines = %LINES%;
	let k = Math.floor(Math.random() * lines.length);
	let done = false;
	const ticker = setInterval(function () {
		if (done) return;
		k = (k + 1) % lines.length;
		line.textContent = lines[k] + '…';
	}, 2600);

	function fail(err) {
		console.error(err);
		done = true;
		clearInterval(ticker);
		bar.style.display = 'none';
		size.textContent = '';
		line.textContent = 'The game couldn’t start';
		notice.textContent = (err instanceof Error ? err.message : (typeof err === 'string' ? err : 'An unknown error occurred.'))
			+ '\nTry reloading the page, or another browser.';
		notice.style.whiteSpace = 'pre-line';
		notice.style.display = 'block';
	}

	const missing = Engine.getMissingFeatures({ threads: GODOT_THREADS_ENABLED });
	if (missing.length !== 0) {
		if (GODOT_CONFIG['serviceWorker'] && GODOT_CONFIG['ensureCrossOriginIsolationHeaders'] && 'serviceWorker' in navigator) {
			let reg;
			try {
				reg = navigator.serviceWorker.getRegistration();
			} catch (err) {
				reg = Promise.reject(new Error('Service worker registration failed.'));
			}
			Promise.race([
				reg.then((r) => (r != null ? Promise.reject(new Error('Service worker already exists.')) : r)).then(() => engine.installServiceWorker()),
				new Promise((resolve) => { setTimeout(() => resolve(), 2000); }),
			]).then(() => { window.location.reload(); }).catch((err) => { console.error('Error while registering service worker:', err); });
		} else {
			fail('Your browser is missing what the game needs to run:\n' + missing.join('\n'));
		}
		return;
	}
	engine.startGame({
		'onProgress': function (current, total) {
			if (current > 0 && total > 0) {
				bar.classList.remove('wait');
				const p = Math.min(100, Math.round(current / total * 100));
				fill.style.width = p + '%';
				size.textContent = p + '%  ·  ' + Math.round(current / 1e6) + ' / ' + Math.round(total / 1e6) + ' MB'
					+ (p >= 100 ? '  ·  starting' : '');
			} else {
				bar.classList.add('wait');
			}
		},
	}).then(() => {
		done = true;
		clearInterval(ticker);
		status.classList.add('gone');
		setTimeout(() => status.remove(), 600);
	}, fail);
}());
</script>
</body>
</html>
"""

if __name__ == "__main__":
    main()
