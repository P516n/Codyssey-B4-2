#!/usr/bin/env bash
# ==============================================================================
# /app/run.sh - Application Runner with configurable environment variables
# ==============================================================================

export AGENT_HOME="${AGENT_HOME:-/home/appuser/agent-app}"
export AGENT_PORT="${AGENT_PORT:-15034}"
export AGENT_UPLOAD_DIR="${AGENT_UPLOAD_DIR:-$AGENT_HOME/upload_files}"
export AGENT_KEY_PATH="${AGENT_KEY_PATH:-$AGENT_HOME/api_keys}"
export AGENT_LOG_DIR="${AGENT_LOG_DIR:-$AGENT_HOME/logs}"
export MEMORY_LIMIT="${MEMORY_LIMIT:-128}"
export CPU_MAX_OCCUPY="${CPU_MAX_OCCUPY:-50}"
export MULTI_THREAD_ENABLE="${MULTI_THREAD_ENABLE:-true}"

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  APP_BIN="/app/bin/agent-leak-app-x86"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
  APP_BIN="/app/bin/agent-leak-app-arm64"
else
  echo "❌ Unsupported architecture: $ARCH"
  exit 1
fi

echo "=================================================="
echo "🚀 Executing agent-leak-app ($ARCH)"
echo "   MEMORY_LIMIT        : $MEMORY_LIMIT MB"
echo "   CPU_MAX_OCCUPY      : $CPU_MAX_OCCUPY %"
echo "   MULTI_THREAD_ENABLE : $MULTI_THREAD_ENABLE"
echo "=================================================="

"$APP_BIN"
