#!/usr/bin/env bash
# One-time setup: download llama.cpp binary (CPU x64), download GGUF model, write Codex config.
# Run on a machine with internet. No GPU; inference is CPU-only via llama.cpp.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "[bootstrap] ROOT=$ROOT"

# 1. Dirs
mkdir -p "$ROOT/models"
echo "[bootstrap] Created models/"

# 2. Minimal venv for model download only (huggingface_hub)
if [[ ! -d "$ROOT/.venv" ]]; then
  uv venv "$ROOT/.venv" --python 3.12
  echo "[bootstrap] Created .venv"
fi
export VIRTUAL_ENV="$ROOT/.venv"
export PATH="$ROOT/.venv/bin:$PATH"
uv pip install --quiet "huggingface_hub>=0.20.0"
echo "[bootstrap] Venv ready (huggingface_hub for download only)"

# 3. Download llama.cpp prebuilt binary (default: Linux x64 CPU)
#    Override: LLAMA_BIN_OS_ARCH=macos-arm64 or linux-x64 (default)
LLAMA_SERVER=""
if [[ -d "$ROOT/llama_bin" ]]; then
  LLAMA_SERVER=$(find "$ROOT/llama_bin" -maxdepth 3 -name "llama-server" -type f -executable -print -quit 2>/dev/null)
fi
if [[ -z "$LLAMA_SERVER" ]] || [[ ! -x "$LLAMA_SERVER" ]]; then
  echo "[bootstrap] Downloading llama.cpp binary (CPU x64) ..."
  LLAMA_SERVER=$("$ROOT/scripts/download_llama_bin.sh")
fi
if [[ -z "$LLAMA_SERVER" ]] || [[ ! -x "$LLAMA_SERVER" ]]; then
  echo "[bootstrap] ERROR: llama-server not found after download." >&2
  exit 1
fi
echo "[bootstrap] Using llama-server at $LLAMA_SERVER"

# 4. Model for CPU/llama.cpp: must be a GGUF repo. Default: bartowski/Qwen_Qwen3.5-2B-GGUF (Qwen3.5-2B)
HF_MODEL_REPO_ID="${HF_MODEL_REPO_ID:-bartowski/Qwen_Qwen3.5-2B-GGUF}"
MODEL_NAME="${HF_MODEL_REPO_ID##*/}"
MODEL_DIR="$ROOT/models/$MODEL_NAME"
if [[ ! -d "$MODEL_DIR" ]] || [[ -z "$(ls -A "$MODEL_DIR" 2>/dev/null)" ]]; then
  echo "[bootstrap] Downloading $HF_MODEL_REPO_ID ..."
  unset ALL_PROXY all_proxy 2>/dev/null || true
  "$ROOT/.venv/bin/python" scripts/download_model.py "$ROOT" "$HF_MODEL_REPO_ID"
else
  echo "[bootstrap] Model already present at $MODEL_DIR"
fi

# 5. Codex config and model info (base_url = codex-proxy so Codex gets correct tool handling)
mkdir -p "$ROOT/.codex"
[[ -f "$ROOT/scripts/codex-config.toml.template" ]] || { echo "[bootstrap] ERROR: scripts/codex-config.toml.template not found." >&2; exit 1; }
PROXY_PORT="${CODEX_PROXY_PORT:-28081}"
DEFAULT_CTX=8192
sed -e "s/__PROXY_PORT__/$PROXY_PORT/g" -e "s/__MODEL_NAME__/$MODEL_NAME/g" -e "s/__CTX_WINDOW__/$DEFAULT_CTX/g" "$ROOT/scripts/codex-config.toml.template" > "$ROOT/.codex/config.toml"
echo "MODEL_DIR=\"$MODEL_DIR\"" > "$ROOT/.codex/model_info"
echo "SERVED_MODEL_NAME=\"$MODEL_NAME\"" >> "$ROOT/.codex/model_info"
echo "LLAMA_SERVER=\"$LLAMA_SERVER\"" >> "$ROOT/.codex/model_info"

# Optional: vLLM (GPU) support. When USE_VLLM=1, install vllm and set VLLM_MODEL for start-vllm.sh.
# vLLM requires HuggingFace format (config.json + safetensors), NOT GGUF. Default: the base model
# that the GGUF was quantized from. On GPU, full-precision is fine (no quantization needed).
if [[ "${USE_VLLM:-0}" == "1" ]]; then
  echo "[bootstrap] Installing vLLM (GPU) ..."
  uv pip install --quiet "vllm>=0.6.0"
  VLLM_MODEL="${VLLM_MODEL:-Qwen/Qwen3.5-2B}"
  VLLM_SERVED_NAME="${VLLM_MODEL##*/}"
  echo "VLLM_MODEL=\"$VLLM_MODEL\"" >> "$ROOT/.codex/model_info"
  echo "VLLM_SERVED_NAME=\"$VLLM_SERVED_NAME\"" >> "$ROOT/.codex/model_info"
  echo "[bootstrap] vLLM ready. Model: $VLLM_MODEL (GPU, HF format). Start with: ./start-vllm.sh"
fi

echo "[bootstrap] .codex/config.toml and .codex/model_info installed (model=$MODEL_NAME, proxy_port=$PROXY_PORT)"

echo "[bootstrap] Done. Next: ./start-llama-server.sh (CPU) or ./start-vllm.sh (GPU, requires USE_VLLM=1 at bootstrap)"
