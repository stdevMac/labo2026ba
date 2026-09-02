#!/usr/bin/env python3
"""Walk shipped notebooks: BUCKET/DATASET must survive rm() before later uses."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NOTEBOOKS = [
    ROOT / "arboles" / "z102_FinalTrain.ipynb",
    ROOT / "zero2hero" / "zero2hero_01.ipynb",
]

RM_ALL = re.compile(
    r"rm\(\s*list\s*=\s*ls\(\s*(?:all\.names\s*=\s*TRUE)?\s*\)\s*\)",
    re.IGNORECASE,
)
RM_KEEPS_ENV = re.compile(
    r"""rm\(\s*list\s*=\s*setdiff\(\s*ls\([^)]*\)\s*,\s*c\(\s*["']BUCKET["']\s*,\s*["']DATASET["']\s*\)\s*\)\s*\)""",
    re.IGNORECASE,
)
USES_ENV = re.compile(r"\b(BUCKET|DATASET)\b")
ASSIGNS_BUCKET = re.compile(r"\bBUCKET\s*<-\s*")
ASSIGNS_DATASET = re.compile(r"\bDATASET\s*<-\s*")


def cell_source(cell: dict) -> str:
    src = cell.get("source", "")
    if isinstance(src, list):
        return "".join(src)
    return src or ""


def is_r_code(cell: dict, src: str) -> bool:
    if cell.get("cell_type") != "code":
        return False
    stripped = src.lstrip()
    if stripped.startswith("%%"):
        return False
    if "from google.colab" in src or "google.colab" in src:
        return False
    return True


def walk(path: Path) -> list[str]:
    nb = json.loads(path.read_text())
    defined: set[str] = set()
    errors: list[str] = []
    for i, cell in enumerate(nb.get("cells", [])):
        src = cell_source(cell)
        if not is_r_code(cell, src):
            continue
        loc = f"{path.relative_to(ROOT)} cell {i} id={cell.get('metadata', {}).get('id', '')}"
        if RM_ALL.search(src) and not RM_KEEPS_ENV.search(src):
            defined.clear()
        if ASSIGNS_BUCKET.search(src):
            defined.add("BUCKET")
        if ASSIGNS_DATASET.search(src):
            defined.add("DATASET")
        if "file.path(BUCKET" in src or "fread(DATASET)" in src or "read.csv(DATASET)" in src:
            missing = [n for n in ("BUCKET", "DATASET") if n not in defined]
            if missing:
                errors.append(f"{loc}: uses {missing} but they are not live after rm")
        elif USES_ENV.search(src) and "BUCKET <-" not in src and "DATASET <-" not in src:
            missing = [n for n in ("BUCKET", "DATASET") if n in USES_ENV.findall(src) and n not in defined]
            if missing:
                errors.append(f"{loc}: uses {missing} but they are not live after rm")
    return errors


def main() -> int:
    failed = False
    for path in NOTEBOOKS:
        if not path.is_file():
            print(f"missing {path}", file=sys.stderr)
            return 1
        errs = walk(path)
        if errs:
            failed = True
            for e in errs:
                print(e, file=sys.stderr)
        else:
            print(f"ok {path.relative_to(ROOT)}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
