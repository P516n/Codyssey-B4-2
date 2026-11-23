# [증거 자료] OOM Crash - After (MEMORY_LIMIT=256MB)

## 1. 실행 환경 및 조건

| 항목 | 설정값 | 비고 |
| :--- | :--- | :--- |
| **`MEMORY_LIMIT`** | `256` (단위: MB) | 기존 128MB에서 2배 상향 조정 |
| **`CPU_MAX_OCCUPY`** | `50` (단위: %) | 기본값 유지 |
| **`MULTI_THREAD_ENABLE`** | `true` | 기본값 유지 |
| **실행 일시** | `2026-11-23 02:07:51` | 테스트 2차 실행 |

---

## 2. 애플리케이션 실행 로그 (`term_run.txt` 발췌)

```text
appuser@123b82407037:~$ MEMORY_LIMIT=256 /app/run.sh
==================================================
🚀 Executing agent-leak-app (x86_64)
   MEMORY_LIMIT        : 256 MB
   CPU_MAX_OCCUPY      : 50 %
   MULTI_THREAD_ENABLE : true
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
2026-11-23 02:07:51,384 [INFO] [SafetyGuard] Process priority lowered (nice=10).
2026-11-23 02:07:51,386 [INFO] Agent listening at port 15034

==================================================
 [ Agent Initiate ] Resource Check
==================================================
 [ MEMORY ] Limit: 256MB                [ WARNING: Recommend Over 256MB ]
 [ CPU    ] Limit: 50%                  [ OK ]
 [ THREAD ] Concurrency: True           [ WARNING ]
--------------------------------------------------
 >>> SYSTEM WARNING: POTENTIAL DEADLOCK IN CONCURRENT MODE.
==================================================

2026-11-23 02:07:53,456 [INFO] [MemoryWorker] Current Heap: 25MB
2026-11-23 02:07:56,503 [INFO] [MemoryWorker] Current Heap: 50MB
2026-11-23 02:07:59,552 [INFO] [MemoryWorker] Current Heap: 75MB
2026-11-23 02:08:02,600 [INFO] [MemoryWorker] Current Heap: 100MB
2026-11-23 02:08:05,655 [INFO] [MemoryWorker] Current Heap: 125MB
2026-11-23 02:08:08,707 [INFO] [MemoryWorker] Current Heap: 150MB
2026-11-23 02:08:11,758 [INFO] [MemoryWorker] Current Heap: 175MB
2026-11-23 02:08:14,806 [INFO] [MemoryWorker] Current Heap: 200MB
2026-11-23 02:08:17,862 [INFO] [MemoryWorker] Current Heap: 225MB
2026-11-23 02:08:20,921 [INFO] [MemoryWorker] Current Heap: 250MB
2026-11-23 02:08:23,980 [INFO] [MemoryWorker] Current Heap: 275MB
2026-11-23 02:08:23,983 [CRITICAL] [MemoryGuard] Memory limit exceeded (275MB >= 256MB) / (Recommend Over 256MB)
2026-11-23 02:08:23,986 [CRITICAL] [MemoryGuard] Self-terminating process 22715 to prevent system instability.

>>> [SYSTEM] SELF-TERMINATED (Memory Limit Exceeded) <<<

/app/run.sh: line 32: 22714 Killed                  "$APP_BIN"
```

---

## 3. 관제 모니터링 로그 (`term_monitor.txt` 발췌)

```text
Timestamp             | PID     | PPID    | %CPU   | %MEM   | RSS(MB)   | VSZ(MB)   | STAT   | THRDS
------------------------------------------------------------------------------------------
[2026-11-23 02:07:51] | 22715   | 22714   |  47.3% |   0.2% |    17.7MB |    22.2MB | SN+    | 1
[2026-11-23 02:07:53] | 22715   | 22714   |   6.3% |   0.6% |    42.7MB |    47.2MB | SN+    | 1
[2026-11-23 02:07:55] | 22715   | 22714   |   3.3% |   0.6% |    42.7MB |    47.2MB | SN+    | 1
[2026-11-23 02:07:57] | 22715   | 22714   |   2.7% |   1.0% |    67.7MB |    72.2MB | SN+    | 1
[2026-11-23 02:07:59] | 22715   | 22714   |   2.4% |   1.4% |    92.7MB |    97.2MB | SN+    | 1
[2026-11-23 02:08:01] | 22715   | 22714   |   1.9% |   1.4% |    92.7MB |    97.2MB | SN+    | 1
[2026-11-23 02:08:03] | 22715   | 22714   |   1.8% |   1.7% |   117.7MB |   122.2MB | SN+    | 1
[2026-11-23 02:08:05] | 22715   | 22714   |   1.8% |   2.1% |   142.7MB |   147.2MB | DN+    | 1
[2026-11-23 02:08:07] | 22715   | 22714   |   1.6% |   2.1% |   142.7MB |   147.2MB | SN+    | 1
[2026-11-23 02:08:09] | 22715   | 22714   |   1.6% |   2.5% |   167.7MB |   172.2MB | SN+    | 1
[2026-11-23 02:08:11] | 22715   | 22714   |   1.5% |   2.5% |   168.2MB |   197.2MB | RN+    | 1
[2026-11-23 02:08:13] | 22715   | 22714   |   1.5% |   2.9% |   192.7MB |   197.2MB | SN+    | 1
[2026-11-23 02:08:15] | 22715   | 22714   |   1.5% |   3.2% |   217.7MB |   222.2MB | SN+    | 1
[2026-11-23 02:08:17] | 22715   | 22714   |   1.3% |   3.2% |   217.7MB |   222.2MB | SN+    | 1
[2026-11-23 02:08:19] | 22715   | 22714   |   1.4% |   3.6% |   242.7MB |   247.2MB | SN+    | 1
[2026-11-23 02:08:21] | 22715   | 22714   |   1.5% |   4.0% |   267.7MB |   272.2MB | SN+    | 1
[2026-11-23 02:08:23] | 22715   | 22714   |   1.4% |   4.0% |   267.7MB |   272.2MB | SN+    | 1
[2026-11-23 02:08:25] | NOT_FOUND | --      | --     | --     | --        | --        | --     | --
```

---

## 4. Before & After 비교 분석 요약

| 비교 항목 | Before (`MEMORY_LIMIT=128MB`) | After (`MEMORY_LIMIT=256MB`) | 변화 및 검증 결과 |
| :--- | :--- | :--- | :--- |
| **종료 시점 힙 메모리** | 150 MB | 275 MB | 임계치 도달 시점까지 비례 상승 |
| **프로세스 생존 시간** | **약 16초** | **약 34초** | **생존 시간 2.1배 이상 연장 확인** |
| **최대 관측 RSS** | 142.4 MB | 267.7 MB | 물리 메모리 점유율 동반 상승 확인 |
| **종료 시그널/정책** | `MemoryGuard` 자가 종료 | `MemoryGuard` 자가 종료 | 메모리 보호 정책의 일관된 동작 검증 |

* **결론**: 가용 메모리 상향에 따라 프로세스 생존 시간이 비례하여 증가하므로, 전형적인 **메모리 누수(Memory Leak)** 결함임이 명확히 입증되었습니다.
