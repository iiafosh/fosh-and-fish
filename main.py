"""
Virtual Fisher 2099 - Main Launcher.
Run `python main.py` to start the game server and open the 2D/3D web client!
Options:
  --port PORT       Specify port (default: 8080)
  --no-browser      Do not open the browser automatically
  --cli             Launch the terminal Discord-style bot interface instead
"""

import sys
import time
import argparse
import webbrowser
import threading

# Ensure UTF-8 output on Windows consoles
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

from server import run_server


def main():
    parser = argparse.ArgumentParser(description="Virtual Fisher 2099 Launcher")
    parser.add_argument("--port", type=int, default=8080, help="Port to host the game on (default 8080)")
    parser.add_argument("--no-browser", action="store_true", help="Don't open browser automatically")
    parser.add_argument("--cli", action="store_true", help="Launch in Discord-style CLI mode")
    args = parser.parse_args()

    if args.cli:
        from cli import run_cli
        run_cli()
        return

    url = f"http://localhost:{args.port}"
    print(f"\n==================================================")
    print(f"  🐟 VIRTUAL FISHER 2099 (vfish.fosh) 🎮")
    print(f"  A Futuristic 2D/3D Fishing RPG powered by Jev API")
    print(f"==================================================")
    print(f"-> Starting server on {url} ...")

    if not args.no_browser:
        def open_browser():
            time.sleep(1.2)
            try:
                print(f"-> Launching web client: {url}")
                webbrowser.open(url)
            except Exception as e:
                print(f"Could not open browser: {e}")

        threading.Thread(target=open_browser, daemon=True).start()

    run_server(port=args.port)


if __name__ == "__main__":
    main()
