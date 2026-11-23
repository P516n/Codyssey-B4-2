# [증거 자료] CPU Spike - After (CPU_MAX_OCCUPY=20%)

## 1. 실행 환경 및 조건

| 항목 | 설정값 | 비고 |
| :--- | :--- | :--- |
| **`MEMORY_LIMIT`** | `512` (단위: MB) | OOM 회피 조건 유지 |
| **`CPU_MAX_OCCUPY`** | `20` (단위: %) | **CPU 허용 한도를 안전 권장 범위(20%)로 제한** |
| **`MULTI_THREAD_ENABLE`** | `false` | 데드락 회피 조건 유지 |
| **실행 일시** | `2026-11-23 02:59:02` | 정상 생존 검증 실행 |

---

## 2. 애플리케이션 실행 로그 (`term_run.txt` 발췌)

```text
appuser@123b82407037:~$ MEMORY_LIMIT=512 MULTI_THREAD_ENABLE=false CPU_MAX_OCCUPY=20 /app/run.sh
==================================================
🚀 Executing agent-leak-app (x86_64)
   MEMORY_LIMIT        : 512 MB
   CPU_MAX_OCCUPY      : 20 %
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
2026-11-23 02:59:02,185 [INFO] [SafetyGuard] Process priority lowered (nice=10).
2026-11-23 02:59:02,186 [INFO] Agent listening at port 15034

==================================================
 [ Agent Initiate ] Resource Check
==================================================
 [ MEMORY ] Limit: 512MB                [ OK ]
 [ CPU    ] Limit: 20%                  [ OK ]
 [ THREAD ] Concurrency: False          [ OK ]
--------------------------------------------------
 >>> SYSTEM STATUS: STABLE. STARTING WORKLOAD MONITORING...
==================================================

2026-11-23 02:59:05,031 [INFO] [CpuWorker] Started. Maximum CPU Limit: 20%
2026-11-23 02:59:05,035 [INFO] [CpuWorker] Current Load: 5.00%
2026-11-23 02:59:08,153 [INFO] [CpuWorker] Current Load: 12.35%
2026-11-23 02:59:11,272 [INFO] [CpuWorker] Current Load: 16.16%
2026-11-23 02:59:13,385 [INFO] [CpuWorker] Peak reached (20.00%). Starting cooldown...
2026-11-23 02:59:14,392 [INFO] [CpuWorker] Current Load: 20.00%
2026-11-23 02:59:17,510 [INFO] [CpuWorker] Current Load: 14.14%
2026-11-23 02:59:20,629 [INFO] [CpuWorker] Current Load: 13.19%
2026-11-23 02:59:23,746 [INFO] [CpuWorker] Current Load: 8.39%
2026-11-23 02:59:26,858 [INFO] [CpuWorker] Current Load: 5.14%
2026-11-23 02:59:28,971 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
2026-11-23 02:59:29,978 [INFO] [CpuWorker] Current Load: 5.00%
2026-11-23 02:59:33,096 [INFO] [CpuWorker] Current Load: 11.68%
2026-11-23 02:59:35,208 [INFO] [CpuWorker] Peak reached (20.00%). Starting cooldown...
```
*(※ 주기적으로 20% Peak 도달 시 자가 Cooldown을 수행하며 Watchdog 강제 종료 없이 지속 생존)*

---

## 3. Before & After 비교 분석 요약

| 비교 항목 | Before (`CPU_MAX_OCCUPY=90%`) | After (`CPU_MAX_OCCUPY=20%`) | 변화 및 검증 결과 |
| :--- | :--- | :--- | :--- |
| **CPU 최대 점유율** | **52.36%** (위반 발생) | **20.00%** (한계치 도달 후 자가 제어) | 과점유 방지 성공 |
| **Watchdog 트리거 여부** | **트리거됨 (`SIGTERM` Abort)** | **트리거되지 않음 (정상 동작)** | 보호 정책 위반 차단 |
| **프로세스 동작 상태** | 기동 후 약 24초 만에 `Terminated` | `Starting cooldown...` 순환 반복 | **정상 상태 지속 생존 확인** |

* **결론**: 과점유 방지 정책(`Watchdog`)의 동작 메커니즘을 확인하였으며, 환경변수 조정을 통해 시스템 안정성을 유지할 수 있음을 검증 완료했습니다.
