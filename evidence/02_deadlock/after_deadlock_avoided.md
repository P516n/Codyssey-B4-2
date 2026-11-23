# [증거 자료] Deadlock - After (MULTI_THREAD_ENABLE=false)

## 1. 실행 환경 및 조건

| 항목 | 설정값 | 비고 |
| :--- | :--- | :--- |
| **`MEMORY_LIMIT`** | `512` (단위: MB) | OOM 회피 조건 유지 |
| **`CPU_MAX_OCCUPY`** | `50` (단위: %) | 기본값 유지 |
| **`MULTI_THREAD_ENABLE`** | `false` | **동시성 락 경쟁 비활성화 (단일 스레드 모드 전환)** |
| **실행 일시** | `2026-11-23 02:48:14` | 회피 및 정상 동작 검증 실행 |

---

## 2. 애플리케이션 실행 로그 (`term_run.txt` 발췌)

```text
appuser@123b82407037:~$ MEMORY_LIMIT=512 MULTI_THREAD_ENABLE=false /app/run.sh
==================================================
🚀 Executing agent-leak-app (x86_64)
   MEMORY_LIMIT        : 512 MB
   CPU_MAX_OCCUPY      : 50 %
   MULTI_THREAD_ENABLE : false
==================================================
>>> Starting Agent Boot Sequence...
[1/6] Checking User Account               [OK]
[2/6] Verifying Environment Variables     [OK]
[3/6] Checking Required Files             [OK]
[4/6] Checking Port Availability          [OK]
[5/6] Verifying Log Permission            [OK]
[6/6] Verifying Mission Environment       [OK]
------------------------------------------------------------
All Boot Checks Passed!
Agent READY
2026-11-23 02:48:14,858 [INFO] [SafetyGuard] Process priority lowered (nice=10).
2026-11-23 02:48:14,860 [INFO] Agent listening at port 15034

==================================================
 [ Agent Initiate ] Resource Check
==================================================
 [ MEMORY ] Limit: 512MB                [ OK ]
 [ CPU    ] Limit: 50%                  [ OK ]
 [ THREAD ] Concurrency: False          [ OK ]
--------------------------------------------------
 >>> SYSTEM STATUS: STABLE. STARTING WORKLOAD MONITORING...
==================================================

2026-11-23 02:48:16,869 [INFO] >>> Scenario Selected: [Healthy System Monitoring]

>>> [SYSTEM] ALL CONFIGURATIONS OPTIMAL. RUNNING STABILITY TEST... <<<

2026-11-23 02:48:16,872 [INFO] [Scheduler] Task Scheduler Initialized.
2026-11-23 02:48:16,874 [INFO] [Scheduler] Registered Tasks: ['Thread-A', 'Thread-B', 'Thread-C']
2026-11-23 02:48:16,875 [INFO] [Scheduler] Starting task execution...
2026-11-23 02:48:16,878 [INFO] [Thread-A] Task Started. Calculating... (20%)
2026-11-23 02:48:16,930 [INFO] [Thread-A] Calculating... (40%)
2026-11-23 02:48:16,983 [INFO] [Thread-A] Calculating... (60%)
2026-11-23 02:48:17,036 [INFO] [Thread-A] Calculating... (80%)
2026-11-23 02:48:17,088 [INFO] [Thread-A] Task Completed. (100%)
2026-11-23 02:48:17,140 [INFO] [Thread-B] Task Started. Calculating... (20%)
2026-11-23 02:48:17,193 [INFO] [Thread-B] Calculating... (40%)
2026-11-23 02:48:17,245 [INFO] [Thread-B] Calculating... (60%)
2026-11-23 02:48:17,298 [INFO] [Thread-B] Calculating... (80%)
2026-11-23 02:48:17,350 [INFO] [Thread-B] Task Completed. (100%)
2026-11-23 02:48:17,403 [INFO] [Thread-C] Task Started. Calculating... (20%)
2026-11-23 02:48:17,455 [INFO] [Thread-C] Calculating... (40%)
2026-11-23 02:48:17,508 [INFO] [Thread-C] Calculating... (60%)
2026-11-23 02:48:17,560 [INFO] [Thread-C] Calculating... (80%)
2026-11-23 02:48:17,613 [INFO] [Thread-C] Task Completed. (100%)
2026-11-23 02:48:17,665 [INFO] [Scheduler] All tasks completed.
```

---

## 3. Before & After 비교 분석 요약

| 비교 항목 | Before (`MULTI_THREAD_ENABLE=true`) | After (`MULTI_THREAD_ENABLE=false`) | 변화 및 검증 결과 |
| :--- | :--- | :--- | :--- |
| **자원 락 상태** | 상호 락 점유 대기 (`Status: BLOCKED`) | 순차 실행으로 락 경쟁 없음 | 락 충돌 배제 |
| **태스크 완료율** | **0%** (진행 불가 무한 대기) | **100% 완료** (Thread-A, B, C 완료) | **정상 처리 성공** |
| **시스템 상태** | 스레드 정체 (`top -H` CPU 0.0%) | 작업 완료 후 다음 워커 정상 이행 | 무응답 결함 해소 |
| **데드락 조건** | 점유 대기 및 순환 대기 형성 | 단일 흐름으로 순환 대기 원천 차단 | **데드락 회피 검증 완료** |
