#!/usr/bin/env python3
"""
Regenerates the multi-resolution Linux hicolor icon set from the master 512x512 icon.
Preserves crisp retro pixel art using Nearest-Neighbor downsampling.
"""

import os
from pathlib import Path
from PIL import Image

def main():
    repo_root = Path(__file__).resolve().parent.parent
    master_icon_path = repo_root / "assets" / "icons" / "imgcrunch.png"

    if not master_icon_path.exists():
        print(f"Error: Master icon not found at {master_icon_path}")
        return 1

    print(f"Loading master icon from: {master_icon_path}")
    img = Image.open(master_icon_path)

    sizes = [16, 24, 32, 48, 64, 128, 256, 512]
    for s in sizes:
        dest_dir = repo_root / "assets" / "icons" / "hicolor" / f"{s}x{s}" / "apps"
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest_file = dest_dir / "imgcrunch.png"

        resized = img.resize((s, s), Image.Resampling.NEAREST)
        resized.save(dest_file, "PNG")
        print(f"  ✓ {s}x{s} -> {dest_file.relative_to(repo_root)}")

    print("Icon set regeneration complete!")
    return 0

if __name__ == "__main__":
    exit(main())
