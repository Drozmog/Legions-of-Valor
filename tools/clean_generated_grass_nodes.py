from __future__ import annotations

import re
from pathlib import Path

SCENE_PATH = Path("battlefield/battlefield_3d.tscn")
BACKUP_PATH = SCENE_PATH.with_suffix(".tscn.before_grass_cleanup.bak")

GENERATED_GRASS_RE = re.compile(r'^\[node name="generated_grass_')


def split_godot_sections(text: str) -> list[str]:
    """Split a Godot text scene/resource into section blocks.

    Godot .tscn files are mostly INI-like sections. Generated grass instance
    nodes are self-contained sections, so removing their whole section safely
    strips editor-saved grass without touching the scatter nodes themselves.
    """
    blocks: list[list[str]] = []
    current: list[str] = []

    for line in text.splitlines(keepends=True):
        if line.startswith("[") and current:
            blocks.append(current)
            current = []
        current.append(line)

    if current:
        blocks.append(current)

    return ["".join(block) for block in blocks]


def main() -> None:
    if not SCENE_PATH.exists():
        raise SystemExit(f"Scene not found: {SCENE_PATH}")

    original = SCENE_PATH.read_text(encoding="utf-8")
    blocks = split_godot_sections(original)

    kept: list[str] = []
    removed = 0

    for block in blocks:
        first_line = block.splitlines()[0] if block else ""
        if GENERATED_GRASS_RE.match(first_line):
            removed += 1
            continue
        kept.append(block)

    if removed == 0:
        print("No generated_grass_* scene nodes found. Nothing changed.")
        return

    if not BACKUP_PATH.exists():
        BACKUP_PATH.write_text(original, encoding="utf-8")

    cleaned = "".join(kept)
    SCENE_PATH.write_text(cleaned, encoding="utf-8")

    print(f"Removed {removed} generated grass scene node(s).")
    print(f"Backup written to: {BACKUP_PATH}")
    print("Open Godot, verify the battlefield, then save the scene once.")


if __name__ == "__main__":
    main()
