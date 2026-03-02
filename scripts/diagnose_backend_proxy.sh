#!/usr/bin/env bash
# Diagnose backend (and optional proxy): run with server already up (./start-llama-server.sh).
# Tests: (1) direct backend non-streaming, (2) via proxy non-streaming if proxy up, (3) via proxy streaming if proxy up.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
source "$ROOT/env.sh" 2>/dev/null || true
BACKEND_PORT="${LLAMA_PORT:-28080}"
PROXY_PORT="${CODEX_PROXY_PORT:-28081}"
MODEL="${SERVED_MODEL_NAME:-Qwen_Qwen3.5-2B-GGUF}"
TIMEOUT_NONSTREAM=90
TIMEOUT_STREAM=45

run_test() {
  local name="$1"
  local port="$2"
  local stream="$3"
  local timeout="$4"
  echo "--- $name (port $port, stream=$stream, timeout=${timeout}s)"
  local start=$(date +%s)
  local out="$ROOT/.codex/diag_${name}.json"
  local err="$ROOT/.codex/diag_${name}.err"
  local extra=""
  [[ "$stream" == "true" ]] && extra=',"stream":true'
  if curl -sf --max-time "$timeout" "http://127.0.0.1:$port/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5${extra}}" \
    -o "$out" 2>"$err"; then
    local elapsed=$(($(date +%s) - start))
    local size=$(wc -c < "$out" 2>/dev/null || echo 0)
    echo "  OK (${elapsed}s, ${size} bytes)"
    head -3 "$out"
    return 0
  else
    local elapsed=$(($(date +%s) - start))
    echo "  FAIL (after ${elapsed}s)"
    [[ -s "$err" ]] && cat "$err"
    [[ -s "$out" ]] && head -5 "$out"
    return 1
  fi
}

echo "Backend port=$BACKEND_PORT, proxy port=$PROXY_PORT, model=$MODEL"
echo ""

if ! curl -sf --max-time 3 "http://127.0.0.1:$BACKEND_PORT/v1/models" >/dev/null 2>&1; then
  echo "Backend not reachable at port $BACKEND_PORT. Start with: ./start-llama-server.sh"
  exit 1
fi
USE_PROXY=false
if curl -sf --max-time 3 "http://127.0.0.1:$PROXY_PORT/v1/models" >/dev/null 2>&1; then
  USE_PROXY=true
fi

FAILED=0
run_test "direct_backend" "$BACKEND_PORT" "false" "$TIMEOUT_NONSTREAM" || FAILED=1
echo ""

if [[ "$USE_PROXY" == true ]]; then
  run_test "via_proxy" "$PROXY_PORT" "false" "$TIMEOUT_NONSTREAM" || FAILED=1
  echo ""
  echo "--- via_proxy_stream (port $PROXY_PORT, stream=true, timeout=${TIMEOUT_STREAM}s)"
  start=$(date +%s)
  out="$ROOT/.codex/diag_via_proxy_stream.json"
  if curl -sf --max-time "$TIMEOUT_STREAM" "http://127.0.0.1:$PROXY_PORT/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":10,\"stream\":true}" \
    -o "$out" 2>/dev/null; then
    elapsed=$(($(date +%s) - start))
    size=$(wc -c < "$out" 2>/dev/null || echo 0)
    echo "  OK (${elapsed}s, ${size} bytes)"
    head -5 "$out"
  else
    elapsed=$(($(date +%s) - start))
    echo "  FAIL (after ${elapsed}s)"
    [[ -s "$out" ]] && head -5 "$out"
    FAILED=1
  fi
else
  echo "Proxy not running on $PROXY_PORT (optional). Start with USE_CODEX_PROXY=1 ./start-llama-server.sh to test proxy."
fi

echo ""
if [[ $FAILED -eq 0 ]]; then
  echo "Diagnostic passed. Backend responds."
  [[ "$USE_PROXY" == true ]] && echo "Proxy also responds."
else
  echo "Some tests failed. direct_backend FAIL => backend issue."
fi
exit $FAILED
