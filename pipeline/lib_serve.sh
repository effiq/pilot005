#!/usr/bin/env bash
# lib_serve.sh — SINGLE OWNER of the vLLM server bring-up (Amendment-07, R15).
# Sourced by lib_calibrate.sh and lib_generate.sh. D10/D11 taught us: two
# copies of this block drift and both hid from pre-flight tests. There is now
# exactly one copy, and preflight_smoke.sh exercises it on real vLLM before
# any cell ignition. Utilization raised 0.92->0.95 (Amendment-08, D14):
# 0.92 left 7.15GiB KV for a 32B-on-80GB envelope needing 8.0GiB at 32768.
#
# Required env: MODEL_DIR MAX_MODEL_LEN PORT
# Optional env: SERVE_EXTRA (verbatim extra flags string, spec data; empty ok)
# Contract: on return, http://127.0.0.1:$PORT/v1/models answers. Loud failure
# otherwise (rc=1, pointer to /tmp/vllm-serve.log). Idempotent via marker.

ensure_server() {
  for v in MODEL_DIR MAX_MODEL_LEN PORT; do
    [ -n "${!v:-}" ] || { echo "lib_serve: missing env $v" >&2; return 2; }
  done
  if [ -f /tmp/.effiq-server-up ]; then
    return 0   # already up (marker); caller's probes will verify liveness
  fi
  # shellcheck disable=SC2086 # SERVE_EXTRA is intentionally word-split (verbatim flags)
  nohup python3 -m vllm.entrypoints.openai.api_server \
    --model "$MODEL_DIR" --served-model-name cell-model \
    --max-model-len "$MAX_MODEL_LEN" --port "$PORT" \
    --gpu-memory-utilization 0.95 --no-enable-prefix-caching \
    ${SERVE_EXTRA:-} > /tmp/vllm-serve.log 2>&1 &
  echo $! > /tmp/.effiq-server-pid
  for i in $(seq 1 180); do
    curl -sf "http://127.0.0.1:${PORT}/v1/models" >/dev/null 2>&1 && break
    sleep 10
  done
  curl -sf "http://127.0.0.1:${PORT}/v1/models" >/dev/null \
    || { echo "server failed to start; see /tmp/vllm-serve.log" >&2; return 1; }
  touch /tmp/.effiq-server-up
}
