# Air-Gapped Codex + llama.cpp

**\[ [中文说明](README.zh-CN.md) ]**

---

> **Your ops agent. Offline. One folder.**  
> *Bring a portable AI into the secure room—no cloud, no internet, no compromise.*

---

## Why this exists

Air-gapped ops: no internet, no devices, no docs, no AI. Long K8s commands and configs—memorize or print cheat sheets. Slow and error-prone. **Copy one folder in**; run a Codex-level agent offline. Say "show me unhealthy Pods in namespace X"—it generates the command, runs it, suggests next steps. No internet, no cloud. **In a no-network environment, it's your offline ops expert.**

---

## What it is (technically)

**Air-Gapped Codex + llama.cpp** is a **single, portable directory** that:

- Runs a **local LLM** via [llama.cpp](https://github.com/ggml-org/llama.cpp) (CPU-only inference, no GPU).
- Exposes an **OpenAI-compatible HTTP API** so **[Codex CLI](https://developers.openai.com/codex)** (OpenAI's coding/ops agent) talks to that local model—same agent experience, **fully offline**.
- Can be **prepared once** on a connected machine (download llama.cpp binary and GGUF model, generate config), then **copied as a whole** onto approved media and into the secure area. No internet required on the other side.

Use it for **deployment, configuration, runbooks, and troubleshooting**—without leaving the room or touching the cloud.

**Default model:** [Qwen 3.5 latest](https://huggingface.co/Qwen/Qwen3.5-2B) (千问 3.5 最新版) — CPU and GPU both use this model (GGUF for llama.cpp, Hugging Face for vLLM).

---

## Quick start (3 steps)

Use a terminal in this project folder.

### 1. One-time setup (on a machine with internet)

```bash
./bootstrap.sh
```

This downloads the llama.cpp prebuilt binary (Linux x64 CPU), builds **codex-proxy**, downloads the default CPU model (Qwen3.5-2B GGUF, see [Optional: different model](#optional-different-model-or-port) for the repo), and writes Codex config (pointing at the proxy). When it finishes: `[bootstrap] Done. Next: ...`

### 2. Start the backend (one terminal — keep it open)

**In a terminal, run and leave it open:**

```bash
./start.sh
```

This starts the model server (CPU by default, or GPU if you used `USE_VLLM=1` bootstrap) and **codex-proxy** (port 28081). Wait until you see "Codex proxy running at...". First start may take a short while to load the model.

### 3. Run Codex (in a second terminal)

**Open another terminal** in the same project folder, then:

```bash
./run-codex.sh exec "Help me write a Kubernetes Deployment YAML for a simple web app"
```

Codex uses the local model. Replace the quoted text with your real task—configs, scripts, debugging, whatever you need.

**Stop the server when done:** in the server terminal press **Ctrl+C**, or run `./stop.sh` from any terminal.

---

## Copying into an air-gapped workspace

1. On a machine **with internet**: run `./bootstrap.sh` and wait for it to finish.  
2. **Before copying**, confirm the folder contains:
   - `models/` — downloaded model(s)
   - `.venv/` — Python venv
   - `.codex/` — config and model_info
   - `llama_bin/` — llama.cpp binary
   - `codex-proxy` built (or copy the repo and run `make proxy` on the target machine)
   - Optional check: run `./scripts/check-portable.sh` to verify.
3. Copy the **entire** project folder onto approved media.  
4. On the workspace machine (no network): run `./start.sh` in one terminal (keep it open), then in another terminal `./run-codex.sh exec "your task"`.

No cloud. No API keys. No internet.

---

## What you need

| Requirement | Notes |
|-------------|--------|
| **uv** | [Install uv](https://docs.astral.sh/uv/getting-started/installation/) (Python/env manager). Check: `uv --version`. |
| **Codex CLI** | In **Cursor**: Preferences → Advanced → **Install CLI**. Or install via npm. Check: `codex --version`. |
| **curl** | For bootstrap: download llama.cpp binary. No build tools or GPU required. |

---

## Commands at a glance

| Command | Purpose |
|--------|--------|
| `./bootstrap.sh` | First-time setup (run once, needs internet). |
| `./start.sh` | Start backend + proxy (CPU or GPU if configured). Keep terminal open. |
| `./stop.sh` | Stop backend + proxy. |
| `./run-codex.sh exec "task"` | Run Codex with your task (use in a **second** terminal). |
| `./test-api.sh` | Quick check that the server is responding. |

You can also use `./start-llama-server.sh` / `./stop-llama-server.sh` (CPU) or `./start-vllm.sh` / `./stop-vllm.sh` (GPU) if you want to pick the backend explicitly.

Always run `./run-codex.sh` from **this project folder** so Codex uses this project's config and state (no mixing with `~/.codex`).

---

## Usage guide

### How to use (daily workflow)

**Simplest (one command for start/stop):**

1. **First time only:** `./bootstrap.sh` (needs internet); for GPU, `USE_VLLM=1 ./bootstrap.sh`.
2. **Start:** `./start.sh` (leave terminal open). Uses CPU by default, or GPU if vLLM was configured.
3. **In another terminal:** `./run-codex.sh exec "your task"`.
4. **When done:** `./stop.sh` or Ctrl+C in the server terminal.

**Or choose backend explicitly:**

- **CPU:** `./start-llama-server.sh` / `./stop-llama-server.sh`
- **GPU:** `./start-vllm.sh` / `./stop-vllm.sh`

If vLLM hits **CUDA out of memory**, lower context or VRAM: `VLLM_MAX_MODEL_LEN=32768 VLLM_GPU_MEM_UTIL=0.85 ./start-vllm.sh`

---

### How to switch models

**CPU (llama.cpp) — GGUF models:**

- Default: [Qwen/Qwen3.5-2B](https://huggingface.co/Qwen/Qwen3.5-2B) via GGUF — [bartowski/Qwen_Qwen3.5-2B-GGUF](https://huggingface.co/bartowski/Qwen_Qwen3.5-2B-GGUF) (llama.cpp).
- To use another Hugging Face repo (GGUF or compatible), re-run bootstrap with the repo id; this downloads the new model and updates `.codex/config.toml` and `.codex/model_info`:

  ```bash
  HF_MODEL_REPO_ID=owner/repo-name ./bootstrap.sh
  ```

- Then start the server as usual: `./start-llama-server.sh`. The new model is loaded from `models/<repo-name>/`.

**GPU (vLLM) — HuggingFace format (same model):**

- Default vLLM model (when you used `USE_VLLM=1`): [Qwen/Qwen3.5-2B](https://huggingface.co/Qwen/Qwen3.5-2B) (full-precision). Started with max 1 concurrent, auto-detected context length, high VRAM use (0.95).
- To use another Hugging Face model, re-run bootstrap with vLLM and set `VLLM_MODEL`:

  ```bash
  VLLM_MODEL=owner/repo-name USE_VLLM=1 ./bootstrap.sh
  ```

- Then start vLLM: `./start-vllm.sh`. vLLM will use the model specified in `.codex/model_info` (`VLLM_MODEL`).

**Note:** CPU uses GGUF (quantized, for llama.cpp); GPU uses HuggingFace safetensors (full-precision, for vLLM). Both default to **Qwen3.5-2B** — same model, different formats for each runtime. On GPU, quantization isn't needed.

---

### How to switch between GPU and CPU

You can use **either** llama.cpp (CPU) **or** vLLM (GPU) on the same project; only one backend should run at a time (same port 28080).

**From GPU (vLLM) to CPU (llama.cpp):**

1. Stop the GPU backend: `./stop-vllm.sh`.
2. Ensure you have already run a **CPU** bootstrap at least once (so `models/` has a GGUF and `.codex/model_info` has `MODEL_DIR` / `LLAMA_SERVER`). If you only ever ran `USE_VLLM=1 ./bootstrap.sh`, run a normal bootstrap once: `./bootstrap.sh` (this adds/keeps llama.cpp binary and default GGUF model).
3. Start the CPU backend: `./start-llama-server.sh`.
4. Run Codex as usual: `./run-codex.sh exec "..."`.

If Codex still sends the wrong model name (e.g. the vLLM model name), restore the config for the CPU model by re-running bootstrap without vLLM: `./bootstrap.sh`. That rewrites `.codex/config.toml` with the GGUF model name.

**From CPU (llama.cpp) to GPU (vLLM):**

1. Stop the CPU backend: `./stop-llama-server.sh`.
2. Ensure vLLM is installed and a vLLM model is set. If you have not yet run bootstrap with vLLM, run: `USE_VLLM=1 ./bootstrap.sh` (or `VLLM_MODEL=owner/repo USE_VLLM=1 ./bootstrap.sh`).
3. Start the GPU backend: `./start-vllm.sh`. This will update `.codex/config.toml` to the vLLM model name so requests match.
4. Run Codex as usual: `./run-codex.sh exec "..."`.

**Summary:**

| You want to use | Do this |
|-----------------|--------|
| CPU (llama.cpp) | `./stop-vllm.sh` (if vLLM was running), then `./start-llama-server.sh`. Optionally `./bootstrap.sh` to refresh config model name. |
| GPU (vLLM)      | `./stop-llama-server.sh` (if llama was running), then `./start-vllm.sh`. |

---

### Port and tuning (optional)

**Port:** Backend default is 28080, proxy is 28081. Override with `LLAMA_PORT=28081 ./start-llama-server.sh` (or `VLLM_PORT=28081 ./start-vllm.sh`) and use the same port when running Codex if you change it.

**CPU context / threads:** Context size is **auto-detected** from available RAM (2048–32768). Override with `LLAMA_CTX_SIZE=16384`. Thread count auto-detected from `nproc`; override with `LLAMA_THREADS=8`. Example: `LLAMA_CTX_SIZE=16384 LLAMA_THREADS=8 ./start-llama-server.sh`.

**GPU tuning:** Context length is auto-detected by vLLM from GPU memory. Override: `VLLM_MAX_MODEL_LEN=32768`, `VLLM_GPU_MEM_UTIL=0.85`, `VLLM_MAX_NUM_SEQS=2`.

---

## Troubleshooting

| Issue | What to do |
|------|------------|
| `.codex/config.toml not found` | Run `./bootstrap.sh` first. |
| "Model server is not reachable" or Codex doesn't answer | Start the server: `./start-llama-server.sh`, wait until it's up, then run `./run-codex.sh exec "..."`. |
| Codex CLI not found | Install from Cursor (Preferences → Advanced → Install CLI) or npm; open a new terminal. |
| Port 28080 in use | Run `./stop-llama-server.sh`, wait a few seconds, try again. Or use another port: `LLAMA_PORT=28081 ./start-llama-server.sh` and `LLAMA_PORT=28081 ./run-codex.sh exec "..."`. |
| 400 `'type' of tool must be 'function'` | Codex sends tools llama-server rejects. `./run-codex.sh` uses profile `local` (web_search=disabled). If it still happens, start with `USE_CODEX_PROXY=1 ./start-llama-server.sh` and point config at the proxy (see docs). |
| llama-server not found | Run `./bootstrap.sh` to download the prebuilt binary. |

---

## Project charter and docs

- **[CHARTER.md](CHARTER.md)** — Why this project exists, who it's for, and what we will (and won't) do.
- **[CHANGELOG.md](CHANGELOG.md)** — Release history. Current version: **0.4.0** (see [VERSION](VERSION)).
- **[docs/README.md](docs/README.md)** — Technical reference (architecture, bootstrap, config).
- **[README.zh-CN.md](README.zh-CN.md)** — 中文说明。

---

## Layout (reference)

| Path | Purpose |
|------|--------|
| `bootstrap.sh` | One-time setup (run once). |
| `start-llama-server.sh` | Start llama.cpp (CPU) + proxy. |
| `stop-llama-server.sh` | Stop llama-server and proxy. |
| `start-vllm.sh` | Start vLLM (GPU) + proxy (requires `USE_VLLM=1` at bootstrap). |
| `stop-vllm.sh` | Stop vLLM and proxy. |
| `run-codex.sh` | Run Codex with this project's config. |
| `test-api.sh` | Test server response. |
| `models/`, `.venv/`, `.codex/`, `llama_bin/` | Created by bootstrap; copy them when moving the kit. |

**Make:** `make deps` (= bootstrap), `make clean` (remove generated content), `make test` (run checks; requires `codex` on PATH). For GPU: `USE_VLLM=1 ./bootstrap.sh` then `./start-vllm.sh`.

---

## License

MIT. See [LICENSE](LICENSE).
