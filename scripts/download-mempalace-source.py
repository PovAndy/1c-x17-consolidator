#!/usr/bin/env python3
from __future__ import annotations

import shutil
import tarfile
import tempfile
from pathlib import Path
from urllib.request import urlopen


URL = "https://codeload.github.com/milla-jovovich/mempalace/tar.gz/refs/heads/main"


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    vendor_dir = repo_root / "context" / "mempalace" / "vendor"
    vendor_dir.mkdir(parents=True, exist_ok=True)
    archive_path = vendor_dir / "mempalace-main.tar.gz"
    extract_dir = vendor_dir / "mempalace-main"

    with urlopen(URL, timeout=60) as response, archive_path.open("wb") as fh:
        shutil.copyfileobj(response, fh)

    if extract_dir.exists():
        shutil.rmtree(extract_dir)
    extract_dir.mkdir(parents=True, exist_ok=True)

    with tarfile.open(archive_path, "r:gz") as tar:
        tar.extractall(extract_dir)

    print(f"Downloaded: {archive_path}")
    print(f"Extracted : {extract_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
