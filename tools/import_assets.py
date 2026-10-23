#!/usr/bin/env python3
"""Import the exact 176 source images verified against the user-supplied ZIP."""
from __future__ import annotations

import hashlib
import io
import json
from pathlib import Path
import time
import urllib.request
import zipfile

from PIL import Image

COMMIT = "06f7c1ca965a7628671676c8d9a7efd3997bb5e7"
PREFIX = f"moomoo-clone-{COMMIT}/client/public/img/"
EXPECTED_INPUT_HASH = "49d8e6c29c0c2aee1dbdafcc67517bc6f36d0d7d0bd1c6a3902e3feb9e6c9e44"
EXPECTED_FILES = 176
EXPECTED_CONVERTED = 8
EXCLUDED = {
    "animals/boar_1.png",
    "animals/crab_1.png",
    "animals/yeti_1.png",
    "hats/hat_59.png",
    "hats/hat_60.png",
    "hats/hat_61.png",
}
OUTPUT = Path("assets/img")


def download() -> bytes:
    urls = (
        f"https://codeload.github.com/al007ex/moomoo-clone/zip/{COMMIT}",
        f"https://github.com/al007ex/moomoo-clone/archive/{COMMIT}.zip",
    )
    errors = []
    for url in urls:
        for attempt in range(3):
            try:
                request = urllib.request.Request(url, headers={"User-Agent": "ToonRoyale-Assets/1.0"})
                with urllib.request.urlopen(request, timeout=90) as response:
                    result = response.read()
                if not zipfile.is_zipfile(io.BytesIO(result)):
                    raise ValueError("Source is not a ZIP archive")
                return result
            except Exception as error:
                errors.append(f"{url}: {error}")
                time.sleep(attempt + 1)
    raise RuntimeError("Unable to download pinned image source:\n" + "\n".join(errors))


def read_source(archive: zipfile.ZipFile) -> dict[str, bytes]:
    source = {}
    for filename in archive.namelist():
        if not filename.startswith(PREFIX) or filename.endswith("/"):
            continue
        relative = filename[len(PREFIX):]
        if not relative.endswith(".png") or relative in EXCLUDED:
            continue
        if not all(part and part not in {".", ".."} for part in Path(relative).parts):
            raise ValueError(f"Unsafe source path: {relative}")
        source[relative] = archive.read(filename)
    if len(source) != EXPECTED_FILES:
        raise ValueError(f"Expected {EXPECTED_FILES} images; found {len(source)}")
    return source


def aggregate_hash(source: dict[str, bytes]) -> str:
    digest = hashlib.sha256()
    for name in sorted(source):
        data = source[name]
        digest.update(name.encode("utf-8") + b"\0" + len(data).to_bytes(8, "big") + data)
    return digest.hexdigest()


def convert(source: dict[str, bytes]) -> None:
    digest = aggregate_hash(source)
    if digest != EXPECTED_INPUT_HASH:
        raise ValueError(f"Source does not match the provided ZIP: {digest}")
    manifest = []
    converted = 0
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name in sorted(source):
        data = source[name]
        with Image.open(io.BytesIO(data)) as image:
            fmt = image.format
            image.load()
            rgba = image.convert("RGBA")
            if fmt == "WEBP":
                buffer = io.BytesIO()
                rgba.save(buffer, format="PNG", optimize=True)
                output = buffer.getvalue()
                converted += 1
            elif fmt == "PNG" and data.startswith(b"\x89PNG\r\n\x1a\n"):
                output = data
            else:
                raise ValueError(f"Unsupported image format for {name}: {fmt}")
        with Image.open(io.BytesIO(output)) as verification:
            verification.load()
            if verification.format != "PNG":
                raise ValueError(f"Not really PNG: {name}")
            if verification.convert("RGBA").tobytes() != rgba.tobytes():
                raise ValueError(f"Pixel or transparency mismatch: {name}")
        destination = OUTPUT / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(output)
        manifest.append({
            "path": name,
            "original_format": fmt,
            "png_sha256": hashlib.sha256(output).hexdigest(),
        })
        print(f"{'CONVERTED' if fmt == 'WEBP' else 'VALID'} {name}")
    if converted != EXPECTED_CONVERTED:
        raise ValueError(f"Expected {EXPECTED_CONVERTED} converted images; found {converted}")
    Path("asset-manifest.json").write_text(
        json.dumps({
            "source_commit": COMMIT,
            "original_archive_sha256": EXPECTED_INPUT_HASH,
            "images": len(source),
            "webp_converted": converted,
            "files": manifest,
        }, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"PASS: {len(source)} real PNG images, including {converted} lossless conversions")


if __name__ == "__main__":
    with zipfile.ZipFile(io.BytesIO(download())) as archive:
        convert(read_source(archive))
