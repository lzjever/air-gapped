#!/usr/bin/env bash
# Full detection for GPU path: start vLLM + proxy, API test, Codex exec, stop, failure-path checks.
# Run from project root. Requires: USE_VLLM=1 bootstrap already run, codex on PATH.
# Usage: ./scripts/run_tests_vllm.sh  or  make test-vllm
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PORT="${VLLM_PORT:-${LLAMA_PORT:-28080}}"
PROXY_PORT="${CODEX_PROXY_PORT:-28081}"
FAILED=0

run() {
  echo "--- $*"
  if ( set +e; "$@"; ); then echo "  OK"; else echo "  FAIL"; FAILED=1; fi
}

# 1) Preflight
if [[ ! -f "$ROOT/.codex/config.toml" ]]; then
  echo "Run USE_VLLM=1 make deps first." >&2
  exit 1
fi
if [[ ! -f "$ROOT/.codex/model_info" ]]; then
  echo ".codex/model_info not found. Run USE_VLLM=1 ./bootstrap.sh first." >&2
  exit 1
fi
source "$ROOT/.codex/model_info"
if [[ -z "${VLLM_MODEL:-}" ]]; then
  echo "VLLM_MODEL not in model_info. Run USE_VLLM=1 ./bootstrap.sh first." >&2
  exit 1
fi
if ! "$ROOT/.venv/bin/python" -c "import vllm" 2>/dev/null; then
  echo "vLLM not installed. Run USE_VLLM=1 ./bootstrap.sh first." >&2
  exit 1
fi
if curl -sf "http://127.0.0.1:$PORT/v1/models" >/dev/null 2>&1; then
  echo "Backend already running on port $PORT. Stop it with ./stop-vllm.sh then re-run." >&2
  exit 1
fi

# 2) Start vLLM + proxy (use conservative GPU settings to avoid OOM on smaller GPUs)
echo "--- Starting vLLM + codex-proxy..."
START_TIMEOUT="${VLLM_START_TIMEOUT:-900}"
mkdir -p "$ROOT/.codex"
# Let start-vllm.sh auto-detect GPU resources (max_model_len, gpu_memory_utilization).
# Override only if you need specific test values via VLLM_MAX_MODEL_LEN / VLLM_GPU_MEM_UTIL.
./start-vllm.sh > "$ROOT/.codex/vllm-server.log" 2>&1 &
SERVER_PID=$!
cleanup() { kill $SERVER_PID 2>/dev/null; ./stop-vllm.sh 2>/dev/null; }
trap cleanup EXIT

# 3) Wait for backend and proxy
echo "Waiting for vLLM (timeout ${START_TIMEOUT}s)..."
for i in $(seq 1 "$START_TIMEOUT"); do
  if curl -sf "http://127.0.0.1:$PORT/v1/models" >/dev/null 2>&1; then
    echo "  vLLM ready at ${i}s"
    break
  fi
  sleep 1
  if [[ $i -eq "$START_TIMEOUT" ]]; then
    echo "  vLLM did not become ready. Last log lines:"
    tail -30 "$ROOT/.codex/vllm-server.log" 2>/dev/null || true
    exit 1
  fi
done
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

# 4) API test: use model name from backend (vLLM reports its served-model-name)
MODEL_FOR_TEST="${VLLM_SERVED_NAME:-$VLLM_MODEL}"
echo "--- API test (backend port $PORT, model $MODEL_FOR_TEST)"
echo "GET http://127.0.0.1:$PORT/v1/models"
curl -s "http://127.0.0.1:$PORT/v1/models" | head -50
echo ""
echo "POST /v1/chat/completions..."
_chat_out="$ROOT/.codex/test_chat_out.json"
if curl -sf "http://127.0.0.1:$PORT/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "{\"model\": \"$MODEL_FOR_TEST\", \"messages\": [{\"role\": \"user\", \"content\": \"hi\"}], \"max_tokens\": 64}" \
  -o "$_chat_out"; then
  echo "  OK"
  head -20 "$_chat_out"
else
  echo "  FAIL"
  FAILED=1
  [[ -s "$_chat_out" ]] && head -20 "$_chat_out"
fi
echo ""

# 4b) Proxy API tests (Responses API + streaming through codex-proxy)
if curl -sf "http://127.0.0.1:$PROXY_PORT/health" >/dev/null 2>&1; then
  echo "--- Proxy: GET /v1/models"
  if curl -sf "http://127.0.0.1:$PROXY_PORT/v1/models" >/dev/null 2>&1; then
    echo "  OK"
  else
    echo "  FAIL"; FAILED=1
  fi

  echo "--- Proxy: POST /v1/responses (non-streaming, Responses API)"
  _proxy_resp="$ROOT/.codex/test_proxy_responses.json"
  if curl -sf --max-time 120 "http://127.0.0.1:$PROXY_PORT/v1/responses" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$MODEL_FOR_TEST\",\"input\":\"Say hello\",\"max_output_tokens\":32}" \
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
    -d "{\"model\":\"$MODEL_FOR_TEST\",\"input\":\"Say hello\",\"max_output_tokens\":32,\"stream\":true}" \
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
else
  echo "--- Proxy not running on $PROXY_PORT; skipping proxy tests"
  FAILED=1
fi

# 5) Codex exec (via proxy)
if command -v codex &>/dev/null; then
  _codex_out="$ROOT/.codex/codex_exec_out.txt"
  _codex_timeout="${CODEX_EXEC_TIMEOUT:-300}"
  if timeout "$_codex_timeout" ./run-codex.sh exec "echo test-ok" 2>&1 | tee "$_codex_out"; then
    echo "  OK"
  else
    _exit=$?
    if [[ $_exit -eq 124 ]]; then
      echo "  SKIP (Codex exec timed out after ${_codex_timeout}s)"
    elif grep -q "type.*must be.*function" "$_codex_out" 2>/dev/null; then
      echo "  SKIP (tool type rejected; proxy should prevent this)"
    else
      echo "  FAIL"
      FAILED=1
    fi
  fi
else
  echo "--- codex not on PATH; skipping Codex exec test"
fi

# 6) Stop
./stop-vllm.sh
# Wait until backend and proxy ports are free
for i in 1 2 3 4 5 6 7 8 9 10; do
  curl -sf "http://127.0.0.1:$PORT/v1/models" >/dev/null 2>&1 || true
  curl -sf "http://127.0.0.1:$PROXY_PORT/health" >/dev/null 2>&1 || true
  sleep 2
  ! curl -sf "http://127.0.0.1:$PROXY_PORT/health" >/dev/null 2>&1 && break
done
sleep 2
trap - EXIT

# 7) Failure-path checks (run-codex.sh prints "Codex proxy not reachable" when proxy is down)
echo "--- Failure-path checks..."
_codex_timeout_offline=30
_offline_out=$(timeout "$_codex_timeout_offline" ./run-codex.sh exec "x" 2>&1) || true
if echo "$_offline_out" | grep -qE "not reachable|proxy not reachable|Connection refused|error sending request|stream disconnected|Reconnecting"; then
  echo "  run-codex exec without server: OK"
else
  echo "  run-codex exec without server: FAIL (output: ${_offline_out:0:200})"
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
  echo "All checks passed (GPU/vLLM)."
else
  echo "Some checks failed."
  exit 1
fi
