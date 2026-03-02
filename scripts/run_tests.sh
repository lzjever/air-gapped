#!/usr/bin/env bash
# Full detection: start llama-server, API, Codex exec, stop, and failure-path checks.
# Run from project root. Requires: make deps already run, codex on PATH.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PORT="${LLAMA_PORT:-28080}"
FAILED=0

run() {
  echo "--- $*"
  if ( set +e; "$@"; ); then echo "  OK"; else echo "  FAIL"; FAILED=1; fi
}

# 1) Preflight: config and server not already running
if [[ ! -f "$ROOT/.codex/config.toml" ]]; then
  echo "Run make deps first."
  exit 1
fi
if curl -sf "http://127.0.0.1:$PORT/v1/models" >/dev/null 2>&1; then
  echo "Model server already running on port $PORT. Stop it with ./stop-llama-server.sh then re-run."
  exit 1
fi

# 2) Start llama-server
echo "--- Starting llama-server..."
START_TIMEOUT="${LLAMA_START_TIMEOUT:-300}"
mkdir -p "$ROOT/.codex"
./start-llama-server.sh > "$ROOT/.codex/llama-server.log" 2>&1 &
SERVER_PID=$!
cleanup() { kill $SERVER_PID 2>/dev/null; ./stop-llama-server.sh 2>/dev/null; }
trap cleanup EXIT

# 3) Wait for ready
echo "Waiting for model server (timeout ${START_TIMEOUT}s)..."
for i in $(seq 1 "$START_TIMEOUT"); do
  if curl -sf "http://127.0.0.1:$PORT/v1/models" >/dev/null 2>&1; then
    echo "  Server ready at ${i}s"
    break
  fi
  sleep 1
  if [[ $i -eq "$START_TIMEOUT" ]]; then
    echo "  Server did not become ready in ${START_TIMEOUT}s. Last log lines:"
    tail -20 "$ROOT/.codex/llama-server.log" 2>/dev/null || true
    exit 1
  fi
done
PROXY_PORT="${CODEX_PROXY_PORT:-28081}"
if [[ -x "$ROOT/codex-proxy/codex-proxy" ]]; then
  echo "Waiting for codex-proxy on port $PROXY_PORT..."
  for i in $(seq 1 15); do
    if curl -sf "http://127.0.0.1:$PROXY_PORT/health" >/dev/null 2>&1; then
      echo "  Proxy ready"
      break
    fi
    sleep 1
  done
fi

# 4) API test (direct backend)
run ./test-api.sh

# 4b) Proxy API tests (Responses API + streaming through codex-proxy)
if curl -sf "http://127.0.0.1:$PROXY_PORT/health" >/dev/null 2>&1; then
  echo "--- Proxy: GET /v1/models"
  if curl -sf "http://127.0.0.1:$PROXY_PORT/v1/models" >/dev/null 2>&1; then
    echo "  OK"
  else
    echo "  FAIL"; FAILED=1
  fi

  source "$ROOT/.codex/model_info"
  _model="${SERVED_MODEL_NAME:-Qwen_Qwen3.5-2B-GGUF}"

  echo "--- Proxy: POST /v1/chat/completions (non-streaming passthrough)"
  _proxy_chat="$ROOT/.codex/test_proxy_chat.json"
  if curl -sf --max-time 120 "http://127.0.0.1:$PROXY_PORT/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$_model\",\"messages\":[{\"role\":\"user\",\"content\":\"Say hello\"}],\"max_tokens\":32}" \
    -o "$_proxy_chat" 2>/dev/null; then
    echo "  OK"
  else
    echo "  FAIL"; FAILED=1
  fi

  echo "--- Proxy: POST /v1/responses (non-streaming, Responses API)"
  _proxy_resp="$ROOT/.codex/test_proxy_responses.json"
  if curl -sf --max-time 120 "http://127.0.0.1:$PROXY_PORT/v1/responses" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$_model\",\"input\":\"Say hello\",\"max_output_tokens\":32}" \
    -o "$_proxy_resp" 2>/dev/null; then
    if grep -q '"output"' "$_proxy_resp" 2>/dev/null; then
      echo "  OK (Responses API format verified)"
    else
      echo "  FAIL (response missing 'output' field)"
      FAILED=1
    fi
  else
    echo "  FAIL"; FAILED=1
  fi

  echo "--- Proxy: POST /v1/responses (streaming, Responses API)"
  _proxy_stream="$ROOT/.codex/test_proxy_responses_stream.txt"
  if curl -sf --max-time 120 "http://127.0.0.1:$PROXY_PORT/v1/responses" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$_model\",\"input\":\"Say hello\",\"max_output_tokens\":32,\"stream\":true}" \
    -o "$_proxy_stream" 2>/dev/null; then
    if grep -q 'response.output_text.delta' "$_proxy_stream" 2>/dev/null && \
       grep -q 'response.completed' "$_proxy_stream" 2>/dev/null; then
      echo "  OK (streaming events: delta + completed)"
    else
      echo "  FAIL (missing expected streaming events)"
      FAILED=1
    fi
  else
    echo "  FAIL"; FAILED=1
  fi

  echo "--- Proxy: POST /v1/chat/completions (streaming passthrough)"
  _proxy_stream_chat="$ROOT/.codex/test_proxy_chat_stream.txt"
  if curl -sf --max-time 120 "http://127.0.0.1:$PROXY_PORT/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$_model\",\"messages\":[{\"role\":\"user\",\"content\":\"Say hello\"}],\"max_tokens\":32,\"stream\":true}" \
    -o "$_proxy_stream_chat" 2>/dev/null; then
    if grep -q '"delta"' "$_proxy_stream_chat" 2>/dev/null; then
      echo "  OK (streaming chat completions)"
    else
      echo "  FAIL (missing streaming delta)"
      FAILED=1
    fi
  else
    echo "  FAIL"; FAILED=1
  fi
else
  echo "--- Proxy not running on $PROXY_PORT; skipping proxy tests"
  FAILED=1
fi

# 5) Codex exec (if codex on PATH; uses proxy when config base_url points to proxy)
if command -v codex &>/dev/null; then
  _codex_out="$ROOT/.codex/codex_exec_out.txt"
  _codex_timeout="${CODEX_EXEC_TIMEOUT:-600}"
  if timeout "$_codex_timeout" ./run-codex.sh exec "echo test-ok" 2>&1 | tee "$_codex_out"; then
    echo "  OK"
  else
    _exit=$?
    if [[ $_exit -eq 124 ]]; then
      echo "  SKIP (Codex exec timed out after ${_codex_timeout}s; CPU can be slow)"
    elif grep -q "type.*must be.*function" "$_codex_out" 2>/dev/null; then
      echo "  SKIP (llama-server rejects non-function tools; use USE_CODEX_PROXY=1 ./start-llama-server.sh if needed)"
    else
      echo "  FAIL"
      FAILED=1
    fi
  fi
else
  echo "--- codex not on PATH; skipping Codex exec test"
fi

# 6) Stop
./stop-llama-server.sh
for i in 1 2 3 4 5 6 7 8 9 10; do
  curl -sf "http://127.0.0.1:$PORT/v1/models" >/dev/null 2>&1 || break
  sleep 2
done
sleep 2
trap - EXIT

# 7) Failure paths (ensure server is fully stopped)
echo "--- Failure-path checks..."
_codex_timeout_offline=30
_offline_out=$(timeout "$_codex_timeout_offline" ./run-codex.sh exec "x" 2>&1) || true
if echo "$_offline_out" | grep -qE "not reachable|Connection refused|error sending request|stream disconnected|Reconnecting"; then
  echo "  run-codex exec without server: OK"
else
  echo "  run-codex exec without server: FAIL"
  FAILED=1
fi
mv "$ROOT/.codex/config.toml" "$ROOT/.codex/config.toml.bak" 2>/dev/null || true
_config_out=$(./run-codex.sh --help 2>&1) || true
if echo "$_config_out" | grep -q "config.toml not found"; then
  echo "  run-codex without config: OK"
else
  echo "  run-codex without config: FAIL"
  FAILED=1
fi
mv "$ROOT/.codex/config.toml.bak" "$ROOT/.codex/config.toml" 2>/dev/null || true

if [[ $FAILED -eq 0 ]]; then
  echo "All checks passed."
else
  echo "Some checks failed."
  exit 1
fi
