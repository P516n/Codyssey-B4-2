#!/usr/bin/env bash
# ==============================================================================
# setup_env.sh - Case 1: Linux Native / VM Environment Setup
# ==============================================================================

# 1. Root 계정 실행 방지 (요구사항: root가 아닌 일반 사용자)
if [ "$EUID" -eq 0 ]; then
  echo "❌ [ERROR] agent-leak-app must not be run as root."
  echo "Please run as a standard non-root user."
  return 1 2>/dev/null || exit 1
fi

# 2. 작업 기본 디렉터리 및 환경변수 설정
export AGENT_HOME="${AGENT_HOME:-$HOME/agent-leak-workspace}"
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR="$AGENT_HOME/upload_files"
export AGENT_KEY_PATH="$AGENT_HOME/api_keys"
export AGENT_LOG_DIR="$AGENT_HOME/logs"

# 3. 시나리오 제어 환경변수 (기본값 설정 - 테스트 시나리오에 따라 변경)
# - MEMORY_LIMIT: 정수, 50~512 (MB)
# - CPU_MAX_OCCUPY: 정수, 10~100 (%)
# - MULTI_THREAD_ENABLE: true/false (1/0, yes/no)
export MEMORY_LIMIT="${MEMORY_LIMIT:-128}"
export CPU_MAX_OCCUPY="${CPU_MAX_OCCUPY:-50}"
export MULTI_THREAD_ENABLE="${MULTI_THREAD_ENABLE:-true}"

# 4. 필수 디렉터리 생성
mkdir -p "$AGENT_UPLOAD_DIR" "$AGENT_KEY_PATH" "$AGENT_LOG_DIR"

# 5. 필수 secret.key 파일 생성 (내용: agent_api_key_test)
echo -n "agent_api_key_test" > "$AGENT_KEY_PATH/secret.key"
chmod 600 "$AGENT_KEY_PATH/secret.key"

# 6. 바이너리 실행 권한 부여
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$PROJECT_DIR/bin" ]; then
  chmod +x "$PROJECT_DIR/bin/agent-leak-app-x86" 2>/dev/null || true
  chmod +x "$PROJECT_DIR/bin/agent-leak-app-arm64" 2>/dev/null || true
fi

echo "=================================================="
echo "✅ Environment configured successfully!"
echo "AGENT_HOME          : $AGENT_HOME"
echo "AGENT_PORT          : $AGENT_PORT"
echo "AGENT_UPLOAD_DIR    : $AGENT_UPLOAD_DIR"
echo "AGENT_KEY_PATH      : $AGENT_KEY_PATH"
echo "AGENT_LOG_DIR       : $AGENT_LOG_DIR"
echo "MEMORY_LIMIT        : $MEMORY_LIMIT MB"
echo "CPU_MAX_OCCUPY      : $CPU_MAX_OCCUPY %"
echo "MULTI_THREAD_ENABLE : $MULTI_THREAD_ENABLE"
echo "=================================================="
echo "To run the application:"
echo "  x86_64 : $PROJECT_DIR/bin/agent-leak-app-x86"
echo "  arm64  : $PROJECT_DIR/bin/agent-leak-app-arm64"
echo "=================================================="
