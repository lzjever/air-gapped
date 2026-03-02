#!/usr/bin/env bash
# Quick test that the local model server (llama.cpp) API responds. Run while start-llama-server.sh is running.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
source "$ROOT/env.sh"
PORT="${LLAMA_PORT:-28080}"
if ! curl -sf "http://127.0.0.1:$PORT/v1/models" >/dev/null 2>&1; then
  echo "Cannot reach model server at http://127.0.0.1:$PORT. Start it with: ./start-llama-server.sh" >&2
  exit 1
fi
echo "Listing models (GET http://127.0.0.1:$PORT/v1/models)..."
MODEL_FOR_TEST="Qwen_Qwen3.5-2B-GGUF"
[[ -f "$ROOT/.codex/model_info" ]] && source "$ROOT/.codex/model_info" && MODEL_FOR_TEST="$SERVED_MODEL_NAME"
curl -s "http://127.0.0.1:$PORT/v1/models" | head -50
echo ""
echo "Chat completion (POST /v1/chat/completions)..."
_chat_out="$ROOT/.codex/test_chat_out.json"
curl -sf "http://127.0.0.1:$PORT/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"$MODEL_FOR_TEST\",
    \"messages\": [{\"role\": \"user\", \"content\": \"hi\"}],
    \"max_tokens\": 64
  }" -o "$_chat_out"
head -20 "$_chat_out"
echo ""
