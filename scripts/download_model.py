#!/usr/bin/env python3
"""Download a GGUF model from Hugging Face into project models/ for llama.cpp.

Usage:
  python scripts/download_model.py <ROOT> [REPO_ID]

  REPO_ID: Hugging Face repo (GGUF for llama.cpp, e.g. bartowski/Qwen_Qwen3.5-2B-GGUF). Omit for default.
  Default: bartowski/Qwen_Qwen3.5-2B-GGUF (Qwen3.5-2B for CPU/llama.cpp).

  Use project .venv: .venv/bin/python scripts/download_model.py <ROOT> [REPO_ID]
"""
from __future__ import annotations

import os
import sys

DEFAULT_REPO = "bartowski/Qwen_Qwen3.5-2B-GGUF"


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: download_model.py <ROOT> [REPO_ID]", file=sys.stderr)
        print("  REPO_ID: HF repo (e.g. owner/repo). Default:", DEFAULT_REPO, file=sys.stderr)
        sys.exit(1)
    root = os.path.abspath(sys.argv[1])
    repo_id = (sys.argv[2].strip() if len(sys.argv) > 2 else "").strip() or DEFAULT_REPO
    if "/" not in repo_id:
        repo_id = DEFAULT_REPO
    local_name = repo_id.split("/")[-1]
    local_dir = os.path.join(root, "models", local_name)
    os.makedirs(local_dir, exist_ok=True)

    from huggingface_hub import snapshot_download

    snapshot_download(repo_id=repo_id, local_dir=local_dir)
    print(f"Model saved to {local_dir}")
    print(f"Served model name (for config): {local_name}")


if __name__ == "__main__":
    main()
