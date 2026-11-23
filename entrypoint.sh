#!/usr/bin/env bash

# ==============================================================================
# entrypoint.sh - Container Entrypoint Script
# ==============================================================================

# 기본값 세팅
export AGENT_HOME="${AGENT_HOME:-/home/appuser/agent-app}"
export AGENT_PORT="${AGENT_PORT:-15034}"
export AGENT_UPLOAD_DIR="${AGENT_UPLOAD_DIR:-$AGENT_HOME/upload_files}"
export AGENT_KEY_PATH="${AGENT_KEY_PATH:-$AGENT_HOME/api_keys}"
export AGENT_LOG_DIR="${AGENT_LOG_DIR:-$AGENT_HOME/logs}"
export MEMORY_LIMIT="${MEMORY_LIMIT:-128}"
export CPU_MAX_OCCUPY="${CPU_MAX_OCCUPY:-50}"
export MULTI_THREAD_ENABLE="${MULTI_THREAD_ENABLE:-true}"

# 필수 디렉터리 생성 (권한 보장)
mkdir -p "$AGENT_UPLOAD_DIR" "$AGENT_KEY_PATH" "$AGENT_LOG_DIR"

# 필수 secret.key 파일 생성
echo -n "agent_api_key_test" > "$AGENT_KEY_PATH/secret.key"
chmod 600 "$AGENT_KEY_PATH/secret.key"

echo "=== Container Boot: agent-leak-tester ready ==="
echo "AGENT_HOME          : $AGENT_HOME"
echo "AGENT_PORT          : $AGENT_PORT"
echo "AGENT_LOG_DIR       : $AGENT_LOG_DIR"
echo "MEMORY_LIMIT        : $MEMORY_LIMIT MB"
echo "CPU_MAX_OCCUPY      : $CPU_MAX_OCCUPY %"
echo "MULTI_THREAD_ENABLE : $MULTI_THREAD_ENABLE"
echo "==============================================="

# 인자가 주어진 경우 해당 명령 실행 (예: bash 등)
if [ $# -gt 0 ]; then
  exec "$@"
fi

# 앱 1회 실행 후, 앱이 종료되어도 컨테이너가 죽지 않고 분석을 위해 유지되도록 처리
/app/run.sh || true

echo ""
echo "========================================================================"
echo "⚠️  [Notice] The application has stopped (or terminated by policy)."
echo "    The container remains ACTIVE for monitoring, log analysis, and re-runs."
echo "    - Access Shell : docker exec -it agent-leak-tester bash"
echo "    - Re-run App   : /app/run.sh (or MEMORY_LIMIT=256 /app/run.sh)"
echo "    - Run Monitor  : /home/appuser/scripts/monitor.sh"
echo "========================================================================"

# 컨테이너 유지
exec sleep infinity
