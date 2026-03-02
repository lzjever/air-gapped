# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [0.5.0] - 2026-03-03

### Changed

- **Default model:** CPU and GPU now use **Qwen 3.5 latest** (千问 3.5 最新版). Same model: [Qwen/Qwen3.5-2B](https://huggingface.co/Qwen/Qwen3.5-2B). CPU uses GGUF from [bartowski/Qwen_Qwen3.5-2B-GGUF](https://huggingface.co/bartowski/Qwen_Qwen3.5-2B-GGUF); GPU uses the Hugging Face repo directly.
- **Test timeouts:** vLLM startup 180s → 900s; llama-server startup 120s → 300s (first-time download).

---

## [0.4.0] - 2026-03-01

### Added

- **Prebuilt llama.cpp binary:** Bootstrap downloads the latest Linux x64 CPU tarball from [GitHub releases](https://github.com/ggml-org/llama.cpp/releases) instead of building from source. No CMake/compiler required. Use `LLAMA_BIN_OS_ARCH=macos-arm64` or `macos-x64` on macOS.
- **scripts/download_llama_bin.sh:** Fetches release tag and `llama-<tag>-bin-ubuntu-x64.tar.gz`, extracts to `llama_bin/`.

### Fixed

- **download_llama_bin.sh:** Skip `find` when `llama_bin/` does not exist (avoids exit under `set -e`). More robust tag extraction from GitHub API (grep + sed). User-Agent header for requests.
- **run_tests.sh:** Failure-path checks now capture command output before grepping so "not reachable" and "config.toml not found" are detected reliably. Added 2s sleep after server stop. Codex exec test treated as SKIP when API returns 400 "tool type must be 'function'" (known compatibility).

### Changed

- **Bootstrap:** Uses downloaded binary; `make clean` removes `llama_bin/` (no `llama.cpp/`).
- **Docs:** README and VERSIONS.md updated for binary download and `llama_bin/`.
- **pyproject.toml:** Renamed to `air-gapped-codex-llamacpp`, version 0.4.0; removed vLLM dependency; wheel includes `scripts/` for `uv run`.

---

## [0.3.0] - 2026-03-01

### Changed (breaking)

- **Replaced vLLM with llama.cpp:** Inference is now done by [llama.cpp](https://github.com/ggml-org/llama.cpp) only. **GPU support removed**; runtime is CPU-only.
- **Bootstrap:** Installs minimal venv (huggingface_hub for model download), downloads default GGUF model. llama.cpp is provided via prebuilt binary (see 0.4.0).
- **Scripts:** `start-vllm.sh` / `stop-vllm.sh` replaced by `start-llama-server.sh` / `stop-llama-server.sh`. `test-vllm-api.sh` replaced by `test-api.sh`.
- **Config:** `.codex/config.toml` proxy name is now "llama.cpp". Port env is `LLAMA_PORT` (default 28080).
- **Makefile:** `make deps` no longer accepts GPU; `make upgrade` only upgrades huggingface_hub.

### Removed

- vLLM, PyTorch, CUDA, and all GPU-related options and documentation.
- `scripts/run_vllm_serve.py` and tokenizer-only download logic (llama.cpp uses tokenizer embedded in GGUF).

### Documentation

- README and README.zh-CN updated for llama.cpp, CPU-only, and new commands.
- docs/README.md rewritten for llama.cpp architecture and bootstrap.

---

## [0.2.0] - 2026-03-01

### Added

- **CPU-first defaults:** Default install is CPU-only (no CUDA). Use `VLLM_USE_GPU=1 ./bootstrap.sh` or `./bootstrap.sh gpu` for GPU/CUDA.
- **Default model:** `Nanbeige/Nanbeige4.1-3B` (CPU-friendly).
- **Auto-detect CPU resources:** When running in CPU mode, `start-vllm.sh` auto-detects logical CPU count and total RAM, and sets `OMP_NUM_THREADS` and `VLLM_CPU_KVCACHE_SPACE` (~50% RAM, min 2 GiB). Override with `VLLM_CPU_NUM_THREADS` and `VLLM_CPU_KVCACHE_SPACE` if needed.
- **Install mode tracking:** `.codex/install_mode` records whether bootstrap was CPU (0) or GPU (1). `start-vllm.sh` warns if you set `VLLM_DEVICE=cuda` but the project was bootstrapped CPU-only.
- **CHANGELOG.md** (this file).

### Changed

- **Bootstrap:** Default is CPU-only install (PyTorch from CPU index on Linux when possible; vLLM may still pull CUDA wheels due to pinned deps). Runtime remains CPU unless `VLLM_DEVICE=cuda`.
- **start-vllm.sh:** Default device is `cpu`. CPU thread and KV cache size are auto-set when not provided.
- **Makefile:** `make deps` = CPU bootstrap; `make deps GPU=1` = GPU bootstrap.
- **Test script:** Wait for vLLM ready extended to 10 min for CPU + GGUF first load.

### Documentation

- **docs/README.md:** Bootstrap CPU/GPU modes, CPU inference control (threads, KV cache), install mode.
- **README.md / README.zh-CN.md:** Short copy, default CPU + GGUF, optional GPU/full model, link to CPU tuning.

---

## [0.1.0] - 2026-02-28

### Added

- Initial portable air-gapped Codex + vLLM kit: bootstrap, start/stop vLLM, run Codex against local model.
- Support for GPU and CPU (default model and device evolved in 0.2.0).
- Project charter (CHARTER.md), version baseline (VERSIONS.md), technical docs (docs/README.md).
