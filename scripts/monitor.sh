#!/usr/bin/env bash
# ==============================================================================
# scripts/monitor.sh - Real-time System & Process Resource Monitor
# ==============================================================================
# [옵션 설명 및 기술적 배경]
# - ps -eo pid,ppid,%cpu,%mem,rss,vsz,stat,nlwp,comm
#   * pid   : 프로세스 식별자 (Process ID)
#   * ppid  : 부모 프로세스 식별자 (Parent PID) - 부모/자식 구조 추적용
#   * %cpu  : CPU 사용률 (프로세스 생존 기간 동안 누적된 CPU 점유율)
#   * %mem  : 시스템 전체 물리 메모리 대비 점유율 (%)
#   * rss   : Resident Set Size (실제 물리 메모리에 상주하는 크기, KB)
#   * vsz   : Virtual Memory Size (스왑 및 가상 할당 포함 전체 크기, KB)
#   * stat  : 프로세스 상태 코드 (R: 실행 중, S: 대기/수면, D: I/O 대기 등)
#   * nlwp  : Number of Light-Weight Processes (스레드 개수) - Deadlock 시 다중 스레드 추적
# ==============================================================================

TARGET_NAME="${1:-agent-leak-app}"
INTERVAL="${2:-2}"
LOG_FILE="${3:-monitor.log}"

echo "==========================================================================================" | tee -a "$LOG_FILE"
echo "🔍 Real-time Monitor for: '$TARGET_NAME' (Interval: ${INTERVAL}s)" | tee -a "$LOG_FILE"
echo "📝 Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "==========================================================================================" | tee -a "$LOG_FILE"
printf "%-21s | %-7s | %-7s | %-6s | %-6s | %-9s | %-9s | %-6s | %-5s\n" \
  "Timestamp" "PID" "PPID" "%CPU" "%MEM" "RSS(MB)" "VSZ(MB)" "STAT" "THRDS" | tee -a "$LOG_FILE"
echo "------------------------------------------------------------------------------------------" | tee -a "$LOG_FILE"

while true; do
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

  # agent-leak-app 관련 프로세스 중 RSS(메모리) 점유가 가장 높은 실제 워커 프로세스 PID 추출
  # (부모 프로세스가 아닌 실제 메모리를 할당/작업하는 자식 프로세스를 정확하게 타겟팅)
  PID=$(ps -eo pid,rss,cmd --sort=-rss 2>/dev/null | grep -E "$TARGET_NAME" | grep -v "grep" | grep -v "monitor.sh" | awk 'NR==1 {print $1}')

  if [ -n "$PID" ] && [ -d "/proc/$PID" ]; then
    RAW_STATS=$(ps -p "$PID" -o pid,ppid,%cpu,%mem,rss,vsz,stat,nlwp --no-headers 2>/dev/null)

    if [ -n "$RAW_STATS" ]; then
      read -r P_PID P_PPID P_CPU P_MEM P_RSS P_VSZ P_STAT P_NLWP <<< "$RAW_STATS"

      # KB -> MB 변환
      RSS_MB=$(awk "BEGIN {printf \"%.1f\", $P_RSS/1024}")
      VSZ_MB=$(awk "BEGIN {printf \"%.1f\", $P_VSZ/1024}")

      printf "[%s] | %-7s | %-7s | %5.1f%% | %5.1f%% | %7sMB | %7sMB | %-6s | %-5s\n" \
        "$TIMESTAMP" "$P_PID" "$P_PPID" "$P_CPU" "$P_MEM" "$RSS_MB" "$VSZ_MB" "$P_STAT" "$P_NLWP" | tee -a "$LOG_FILE"
    fi
  else
    printf "[%s] | %-7s | %-7s | %-6s | %-6s | %-9s | %-9s | %-6s | %-5s\n" \
      "$TIMESTAMP" "NOT_FOUND" "--" "--" "--" "--" "--" "--" "--" | tee -a "$LOG_FILE"
  fi

  sleep "$INTERVAL"
done
