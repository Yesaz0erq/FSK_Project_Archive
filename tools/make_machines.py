"""Build articulated 3D field models and orthographic codex art from their shared sources."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Path to the Godot 4.7 executable")
    parser.add_argument("machines", nargs="*", help="Machine IDs; omit to rebuild the catalog")
    args = parser.parse_args()
    engine = args.godot or shutil.which("godot") or shutil.which("godot4")
    if engine is None and os.name == "nt":
        steam = Path(os.environ.get("ProgramFiles(x86)", "C:/Program Files (x86)"))
        candidate = steam / "Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
        if candidate.is_file():
            engine = str(candidate)
    if engine is None:
        parser.error("Provide the Godot executable with --godot")
    subprocess.run([engine, "--headless", "--path", str(ROOT), "--script",
                    "res://tools/machine_models/build_volumes.gd"], check=True)
    command = [engine, "--path", str(ROOT), "--disable-vsync", "--resolution", "360x320",
               "res://tools/machine_models/bake.tscn"]
    if args.machines:
        command.extend(["--", *args.machines])
    subprocess.run(command, check=True)
    subprocess.run([engine, "--headless", "--editor", "--path", str(ROOT), "--import"], check=True)


if __name__ == "__main__":
    main()
