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
LATEST_RUN_SOURCE = Path("docs/remake/pr122-hero-parallel/evidence/visual-review-20261023/image-generation-retry.json")
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
IMAGE_FIELDS = frozenset({
    "model", "prompt", "n", "size", "quality", "background", "output_format",
})


def image_payload(options: dict) -> dict:
    """Filter at the HTTP boundary, even when a caller supplies text options."""
    payload = {key: value for key, value in options.items() if key in IMAGE_FIELDS}
    missing = IMAGE_FIELDS - payload.keys()
    if missing:
        raise ValueError("missing image fields: " + ", ".join(sorted(missing)))
    return payload


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
    # The later single-S run retry records one request, without changing its text.
    request = data.get("request", {})
    if request.get("task", "run") == task and isinstance(request.get("prompt"), str):
        return request["prompt"]
    for request in data.get("requests", []):
        if request.get("name") == task and isinstance(request.get("prompt"), str):
            return request["prompt"]
    raise ValueError("task not found in saved source requests: " + task)


def generate(payload: dict, api_key: str) -> bytes:
    payload = image_payload(payload)
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
    parser.add_argument("--source", type=Path, help="Saved request JSON; latest reviewed run retry is preferred")
    parser.add_argument("--model", default="gpt-image-2.5-flare")
    parser.add_argument("--size", help="Override WIDTHxHEIGHT (where supported)")
    parser.add_argument("--execute", action="store_true", help="Make an actual image API request")
    parser.add_argument("--confirm-billing", action="store_true", help="Explicitly acknowledge API charges")
    parser.add_argument("--output", type=Path, help="Required for --execute; must not already exist")
    parser.add_argument("--receipt", type=Path, help="Save a bounded result, including blocked attempts")
    args = parser.parse_args(argv)
    receipt = {"task": args.task, "http_requests": 0, "new_source_files": 0}
    try:
        if args.receipt is not None and args.receipt.exists():
            raise FileExistsError("Refusing to overwrite an existing receipt")
        source = args.source or (LATEST_RUN_SOURCE if args.task == "run" and LATEST_RUN_SOURCE.exists() else SOURCE)
        prompt = load_prompt(source, args.task)
        size = args.size or ("1536x1024" if source == LATEST_RUN_SOURCE else None)
        payload = make_payload(prompt, args.task, args.model, size)
        receipt.update({
            "source": str(source),
            "allowed_keys": sorted(payload),
            "contains_reasoning": "reasoning" in payload,
            "prompt_sha256": hashlib.sha256(prompt.encode("utf-8")).hexdigest(),
            "size": payload["size"],
        })
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
            receipt["result"] = "BLOCKED_CREDENTIAL_NOT_CONFIGURED"
            raise ValueError("OPENAI_API_KEY is not configured; no request was sent")
        receipt["http_requests"] = 1
        image = generate(payload, key)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("xb") as target:
            target.write(image)
        receipt.update({
            "result": "SAVED_UNAPPROVED_SOURCE",
            "output": str(args.output),
            "sha256": hashlib.sha256(image).hexdigest(),
            "bytes": len(image),
            "task": args.task,
            "new_source_files": 1,
        })
        # Verify decoded pixels as well as the PNG signature. Preserve a rejected
        # raw response on disk for review, rather than silently discarding it.
        from PIL import Image
        with Image.open(args.output) as decoded:
            decoded.load()
            receipt["dimensions"] = list(decoded.size)
            if decoded.format != "PNG" or "x".join(map(str, decoded.size)) != payload["size"]:
                receipt["result"] = "HOLD_UNEXPECTED_IMAGE_FORMAT_OR_SIZE"
                raise ValueError("Saved source needs format/dimension review")
        print(json.dumps(receipt, ensure_ascii=False))
        return 0
    except (ValueError, FileNotFoundError, FileExistsError, RuntimeError, OSError) as exc:
        receipt.setdefault("result", "SOURCE_GENERATION_FAILED")
        print("IMAGE_SOURCE_NOT_GENERATED: " + str(exc), file=sys.stderr)
        return 2
    finally:
        if args.receipt is not None and not args.receipt.exists():
            args.receipt.parent.mkdir(parents=True, exist_ok=True)
            with args.receipt.open("x", encoding="utf-8") as target:
                json.dump(receipt, target, indent=2, ensure_ascii=False)
                target.write("\n")


if __name__ == "__main__":
    raise SystemExit(main())
