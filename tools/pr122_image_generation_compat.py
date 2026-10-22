#!/usr/bin/env python3
"""PR122 hero source-generation recovery, using the documented Images API only.

Dry-run is the default. An actual (billable) API call requires BOTH --execute
and --confirm-billing and a configured OPENAI_API_KEY. This is an optional
alternative to a broken Work image-tool adapter, not a repair of that adapter.
No source images or base64 are printed to the chat/terminal.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

SOURCE = Path("docs/remake/pr122-hero-parallel/evidence/next-unique-20261022/image-tool-failure.json")
ENDPOINT = "https://api.openai.com/v1/images/generations"
TASK_SIZES = {
    "run": "1536x2048",
    "attack": "1536x2048",
    "support": "1536x2048",
    "death": "1024x1536",
}
SUPPORTED_MODELS = {
    "gpt-image-2",
    "gpt-image-2.5-flare",
    "gpt-image-2.5-sunburst",
}
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def validate_size(size: str) -> None:
    match = re.fullmatch(r"([1-9][0-9]*)x([1-9][0-9]*)", size)
    if match is None:
        raise ValueError("size must be WIDTHxHEIGHT")
    width, height = (int(part) for part in match.groups())
    if width % 16 or height % 16:
        raise ValueError("width and height must be divisible by 16")
    if width > 3840 or height > 3840 or width * height > 3840 * 2160:
        raise ValueError("size exceeds documented maximum")
    if not (1 / 3 <= width / height <= 3):
        raise ValueError("aspect ratio must be between 1:3 and 3:1")


def make_payload(prompt: str, task: str, model: str = "gpt-image-2.5-flare",
                 size: str | None = None) -> dict:
    if task not in TASK_SIZES:
        raise ValueError("unsupported task")
    if model not in SUPPORTED_MODELS:
        raise ValueError("unsupported image model")
    if not prompt.strip():
        raise ValueError("empty prompt")
    if len(prompt) > 32000:
        raise ValueError("prompt exceeds API length limit")
    selected_size = size or TASK_SIZES[task]
    validate_size(selected_size)
    # Exact allowlist. NEVER forward agent/Responses reasoning controls to Images.
    return {
        "model": model,
        "prompt": prompt,
        "n": 1,
        "size": selected_size,
        "quality": "high",
        "background": "transparent",
        "output_format": "png",
    }


def load_prompt(path: Path, task: str) -> str:
    data = json.loads(path.read_text(encoding="utf-8"))
    for request in data.get("requests", []):
        if request.get("name") == task and isinstance(request.get("prompt"), str):
            return request["prompt"]
    raise ValueError("task not found in saved source requests: " + task)


def generate(payload: dict, api_key: str) -> bytes:
    request = Request(
        ENDPOINT,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Authorization": "Bearer " + api_key, "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urlopen(request, timeout=180) as response:
            result = json.load(response)
    except HTTPError as exc:
        # Avoid dumping prompt, API key, or lengthy gateway bodies.
        raw = exc.read(2048).decode("utf-8", errors="replace")
        try:
            err = json.loads(raw).get("error", {})
            detail = str(err.get("message", ""))[:240]
            code = str(err.get("code", ""))[:80]
        except (TypeError, ValueError, AttributeError):
            detail, code = "Unable to decode API error", ""
        raise RuntimeError(f"Image API HTTP {exc.code} code={code}: {detail}") from None
    except URLError as exc:
        raise RuntimeError("Image API connection failed: " + str(exc.reason)[:120]) from None
    if not isinstance(result, dict):
        raise RuntimeError("Image API returned no result object")
    rows = result.get("data")
    if not isinstance(rows, list) or not rows or not isinstance(rows[0], dict):
        raise RuntimeError("Image API returned no image data")
    encoded = rows[0].get("b64_json")
    if not isinstance(encoded, str):
        raise RuntimeError("Image API did not return base64 image data")
    image = base64.b64decode(encoded, validate=True)
    if not image.startswith(PNG_SIGNATURE):
        raise RuntimeError("Image API did not return PNG data")
    return image


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--task", choices=tuple(TASK_SIZES), required=True)
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--model", default="gpt-image-2.5-flare")
    parser.add_argument("--size", help="Override WIDTHxHEIGHT (where supported)")
    parser.add_argument("--execute", action="store_true", help="Make an actual image API request")
    parser.add_argument("--confirm-billing", action="store_true", help="Explicitly acknowledge API charges")
    parser.add_argument("--output", type=Path, help="Required for --execute; must not already exist")
    args = parser.parse_args(argv)
    try:
        prompt = load_prompt(args.source, args.task)
        payload = make_payload(prompt, args.task, args.model, args.size)
        if not args.execute:
            print(json.dumps({
                "mode": "DRY_RUN_NO_REQUEST",
                "task": args.task,
                "model": payload["model"],
                "size": payload["size"],
                "allowed_keys": sorted(payload),
                "contains_reasoning": "reasoning" in payload,
                "prompt_sha256": hashlib.sha256(prompt.encode("utf-8")).hexdigest(),
            }, ensure_ascii=False))
            return 0
        if not args.confirm_billing:
            raise ValueError("Actual API calls require --confirm-billing")
        if args.output is None:
            raise ValueError("Actual API calls require --output")
        if args.output.exists():
            raise FileExistsError("Refusing to overwrite an existing source image")
        key = os.environ.get("OPENAI_API_KEY")
        if not key:
            raise ValueError("OPENAI_API_KEY is not configured; no request was sent")
        image = generate(payload, key)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("xb") as target:
            target.write(image)
        print(json.dumps({
            "result": "SAVED_UNAPPROVED_SOURCE",
            "output": str(args.output),
            "sha256": hashlib.sha256(image).hexdigest(),
            "bytes": len(image),
            "task": args.task,
        }, ensure_ascii=False))
        return 0
    except (ValueError, FileNotFoundError, FileExistsError, RuntimeError, OSError) as exc:
        print("IMAGE_SOURCE_NOT_GENERATED: " + str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
