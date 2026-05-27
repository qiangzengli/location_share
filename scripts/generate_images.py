#!/usr/bin/env python3

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_PROMPT = (
    "一位成年中国女性时尚写真，体现东方审美与高级感，五官精致，黑色长发，"
    "优雅自信，身材匀称，性感但不低俗。她穿着带有现代中国风元素的高级红黑礼服，"
    "剪裁修身，露肩设计，配以细致金色配饰。场景为电影感棚拍，柔和轮廓光与暖色氛围光，"
    "皮肤质感自然，姿态优雅，眼神坚定，整体风格时尚杂志封面级，高清细节，写实摄影风格。"
)


@dataclass
class GeneratedImage:
    response_id: str | None
    image_id: str | None
    revised_prompt: str | None
    image_base64: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate images sequentially with OpenAI Responses API."
    )
    parser.add_argument("--count", type=int, default=1000, help="How many images to generate.")
    parser.add_argument(
        "--prompt",
        default=DEFAULT_PROMPT,
        help="Prompt text. Use --prompt-file for longer prompts.",
    )
    parser.add_argument(
        "--prompt-file",
        help="Optional UTF-8 text file containing the prompt. Overrides --prompt.",
    )
    parser.add_argument(
        "--out-dir",
        default="generated_images/chinese_beauty_batch",
        help="Directory to store generated images and logs.",
    )
    parser.add_argument(
        "--model",
        default="gpt-5",
        help="Main model for Responses API. Official docs show image generation via Responses API tools.",
    )
    parser.add_argument(
        "--image-size",
        default="1024x1536",
        help="Requested output size for the image generation tool.",
    )
    parser.add_argument(
        "--image-quality",
        default="high",
        help="Requested output quality for the image generation tool.",
    )
    parser.add_argument(
        "--output-format",
        default="png",
        choices=["png", "jpeg", "webp"],
        help="Image file format to save.",
    )
    parser.add_argument(
        "--background",
        default="opaque",
        choices=["opaque", "transparent", "auto"],
        help="Background mode for generation.",
    )
    parser.add_argument(
        "--retries",
        type=int,
        default=5,
        help="Max retries per image on transient failures.",
    )
    parser.add_argument(
        "--delay-seconds",
        type=float,
        default=1.0,
        help="Delay between successful generations.",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=300,
        help="HTTP timeout in seconds.",
    )
    parser.add_argument(
        "--start-index",
        type=int,
        default=1,
        help="Starting number used in filenames.",
    )
    return parser.parse_args()


def read_prompt(args: argparse.Namespace) -> str:
    if args.prompt_file:
        return Path(args.prompt_file).read_text(encoding="utf-8").strip()
    return args.prompt.strip()


def ensure_api_key() -> str:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise SystemExit("Missing OPENAI_API_KEY environment variable.")
    return api_key


def make_request(
    *,
    api_key: str,
    model: str,
    prompt: str,
    image_size: str,
    image_quality: str,
    output_format: str,
    background: str,
    timeout: int,
) -> GeneratedImage:
    payload = {
        "model": model,
        "input": prompt,
        "tools": [
            {
                "type": "image_generation",
                "action": "generate",
                "size": image_size,
                "quality": image_quality,
                "output_format": output_format,
                "background": background,
            }
        ],
    }
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url="https://api.openai.com/v1/responses",
        data=body,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        data = json.loads(response.read().decode("utf-8"))
    return extract_image(data)


def extract_image(response_json: dict[str, Any]) -> GeneratedImage:
    output_items = response_json.get("output", [])
    for item in output_items:
        if item.get("type") == "image_generation_call" and item.get("result"):
            return GeneratedImage(
                response_id=response_json.get("id"),
                image_id=item.get("id"),
                revised_prompt=item.get("revised_prompt"),
                image_base64=item["result"],
            )
    raise ValueError(f"No image_generation_call result found in response: {response_json}")


def ext_for_format(output_format: str) -> str:
    return "jpg" if output_format == "jpeg" else output_format


def next_missing_index(out_dir: Path, start_index: int, output_format: str) -> int:
    extension = ext_for_format(output_format)
    index = start_index
    while (out_dir / f"image_{index:04d}.{extension}").exists():
        index += 1
    return index


def append_jsonl(path: Path, payload: dict[str, Any]) -> None:
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, ensure_ascii=False) + "\n")


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def main() -> int:
    args = parse_args()
    prompt = read_prompt(args)
    api_key = ensure_api_key()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    log_path = out_dir / "manifest.jsonl"
    extension = ext_for_format(args.output_format)

    current_index = next_missing_index(out_dir, args.start_index, args.output_format)
    target_last_index = args.start_index + args.count - 1

    if current_index > target_last_index:
        print("Requested image range is already complete.")
        return 0

    print(f"Output directory: {out_dir.resolve()}")
    print(f"Generating images {current_index}..{target_last_index}")

    while current_index <= target_last_index:
        attempt = 0
        while True:
            attempt += 1
            try:
                generated = make_request(
                    api_key=api_key,
                    model=args.model,
                    prompt=prompt,
                    image_size=args.image_size,
                    image_quality=args.image_quality,
                    output_format=args.output_format,
                    background=args.background,
                    timeout=args.timeout,
                )
                image_path = out_dir / f"image_{current_index:04d}.{extension}"
                image_path.write_bytes(base64.b64decode(generated.image_base64))
                append_jsonl(
                    log_path,
                    {
                        "index": current_index,
                        "saved_at": utc_now_iso(),
                        "file": image_path.name,
                        "response_id": generated.response_id,
                        "image_id": generated.image_id,
                        "revised_prompt": generated.revised_prompt,
                        "prompt": prompt,
                    },
                )
                print(f"[ok] {current_index:04d} -> {image_path}")
                current_index += 1
                time.sleep(args.delay_seconds)
                break
            except urllib.error.HTTPError as exc:
                response_text = exc.read().decode("utf-8", errors="replace")
                should_retry = exc.code in {408, 409, 429, 500, 502, 503, 504}
                if attempt > args.retries or not should_retry:
                    print(f"[failed] {current_index:04d} HTTP {exc.code}: {response_text}", file=sys.stderr)
                    return 1
                wait_seconds = min(60, 2 ** attempt)
                print(
                    f"[retry] {current_index:04d} HTTP {exc.code}, attempt {attempt}/{args.retries}, waiting {wait_seconds}s",
                    file=sys.stderr,
                )
                time.sleep(wait_seconds)
            except (urllib.error.URLError, TimeoutError, ValueError) as exc:
                if attempt > args.retries:
                    print(f"[failed] {current_index:04d}: {exc}", file=sys.stderr)
                    return 1
                wait_seconds = min(60, 2 ** attempt)
                print(
                    f"[retry] {current_index:04d} {type(exc).__name__}, attempt {attempt}/{args.retries}, waiting {wait_seconds}s",
                    file=sys.stderr,
                )
                time.sleep(wait_seconds)

    print("Completed requested generation run.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
