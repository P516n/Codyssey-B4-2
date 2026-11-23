# [증거 자료] Deadlock - Before (MULTI_THREAD_ENABLE=true)

## 1. 실행 환경 및 조건

| 항목 | 설정값 | 비고 |
| :--- | :--- | :--- |
| **`MEMORY_LIMIT`** | `512` (단위: MB) | OOM 조기 차단 방지를 위해 충분히 부여 |
| **`CPU_MAX_OCCUPY`** | `50` (단위: %) | 기본값 |
| **`MULTI_THREAD_ENABLE`** | `true` | **멀티스레드 동시성 활성화 (자원 락 경쟁 유도)** |
| **실행 일시** | `2026-11-23 02:08:26` | 3차 테스트 실행 |

---

## 2. 애플리케이션 실행 로그 (`term_run.txt` 발췌)

```text
2026-11-23 02:08:26,205 [INFO] [SafetyGuard] Process priority lowered (nice=10).
2026-11-23 02:08:26,207 [INFO] Agent listening at port 15034

==================================================
 [ Agent Initiate ] Resource Check
==================================================
 [ MEMORY ] Limit: 512MB                [ OK ]
 [ CPU    ] Limit: 50%                  [ OK ]
 [ THREAD ] Concurrency: True           [ WARNING ]
--------------------------------------------------
 >>> SYSTEM WARNING: POTENTIAL DEADLOCK IN CONCURRENT MODE.
==================================================

2026-11-23 02:08:28,219 [WARNING] [AgentWorker] Initializing concurrent transaction processors...
2026-11-23 02:08:28,222 [WARNING] [System] CAUTION: Strict resource locking is enabled.
2026-11-23 02:08:33,251 [INFO] [Worker-Thread-1] Process Started. Attempting to lock [Shared_Memory_A]...
2026-11-23 02:08:33,251 [INFO] [AgentWorker][Worker-Thread-2] Process Started. Attempting to lock [Socket_Pool_B]...
2026-11-23 02:08:33,251 [INFO] [AgentWorker] Waiting for worker threads to complete transactions...
2026-11-23 02:08:33,253 [INFO] [AgentWorker][Worker-Thread-1] LOCK ACQUIRED: [Shared_Memory_A]. (Holding...)
2026-11-23 02:08:33,255 [INFO] [AgentWorker][Worker-Thread-2] LOCK ACQUIRED: [Socket_Pool_B]. (Holding...)
2026-11-23 02:08:33,259 [INFO] [AgentWorker][Worker-Thread-1] Processing critical data in Memory A...
2026-11-23 02:08:33,261 [INFO] [AgentWorker][Worker-Thread-2] Establishing network connections in Pool B...
2026-11-23 02:08:35,273 [INFO] [AgentWorker][Worker-Thread-1] Need resource [Socket_Pool_B] to finish job.
2026-11-23 02:08:35,274 [INFO] [AgentWorker][Worker-Thread-2] Need resource [Shared_Memory_A] to write logs.
2026-11-23 02:08:35,275 [INFO] [AgentWorker][Worker-Thread-1] WAITING for [Socket_Pool_B]... (Status: BLOCKED)
2026-11-23 02:08:35,277 [INFO] [AgentWorker][Worker-Thread-2] WAITING for [Shared_Memory_A]... (Status: BLOCKED)
```
*(※ 이 시점 이후 추가 로그 출력이 완전히 정지되며 무한 대기 상태 돌입)*

---

## 3. 프로세스 생존 및 스레드 상태 시스템 도구 출력 (`term_ps.txt` 발췌)

### ① 프로세스 생존 확인 (`ps -ef | grep agent`)
프로세스가 비정상 종료(Crash)된 것이 아니라 정상 동작 상태로 PID가 살아있음을 증명:
```text
UID          PID    PPID  C STIME TTY          TIME CMD
appuser    34932   34930  0 02:46 pts/0    00:00:00 /app/bin/agent-leak-app-x86
appuser    34933   34932  0 02:46 pts/0    00:00:00 /app/bin/agent-leak-app-x86
```

### ② 스레드 목록 및 상태 확인 (`ps -L -p 34933 -o pid,tid,stat,%cpu,%mem,comm`)
메인 스레드 1개와 작업 스레드 2개(총 3개) 모두 대기 상태(`STAT: SNl+`)로 멈춰 있음:
```text
    PID     TID STAT %CPU %MEM COMMAND
  34933   34933 SNl+  0.1  0.2 agent-leak-app-
  34933   35018 SNl+  0.0  0.2 agent-leak-app-
  34933   35019 SNl+  0.0  0.2 agent-leak-app-
```

### ③ 스레드별 실시간 CPU/메모리 정체 확인 (`top -b -n 1 -H -p 34933`)
3개 스레드 모두 Sleeping(`S`) 상태이며, `%CPU: 0.0%`, CPU 누적 시간(`TIME+`)이 0초로 고정된 상태:
```text
top - 02:47:32 up  3:08,  0 user,  load average: 0.07, 0.02, 0.00
Threads:   3 total,   0 running,   3 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.0 us,  0.8 sy,  0.0 ni, 99.2 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
MiB Mem :   6602.8 total,   5593.8 free,    738.3 used,    436.2 buff/cache
MiB Swap:   2048.0 total,   2048.0 free,      0.0 used.   5864.4 avail Mem

    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
  34933 appuser   30  10  170152  17916   9548 S   0.0   0.3   0:00.07 agent-leak-app-
  35018 appuser   30  10  170152  17916   9548 S   0.0   0.3   0:00.00 agent-leak-app-
  35019 appuser   30  10  170152  17916   9548 S   0.0   0.3   0:00.00 agent-leak-app-
```

---

## 4. 관제 모니터링 로그 정체 확인 (`term_monitor.txt` 발췌)

```text
Timestamp             | PID     | PPID    | %CPU   | %MEM   | RSS(MB)   | VSZ(MB)   | STAT   | THRDS
------------------------------------------------------------------------------------------
[2026-11-23 02:46:48] | 34933   | 34932   |   0.3% |   0.2% |    17.5MB |   166.2MB | SNl+   | 3
[2026-11-23 02:47:00] | 34933   | 34932   |   0.2% |   0.2% |    17.5MB |   166.2MB | SNl+   | 3
[2026-11-23 02:47:30] | 34933   | 34932   |   0.1% |   0.2% |    17.5MB |   166.2MB | SNl+   | 3
[2026-11-23 02:47:58] | 34933   | 34932   |   0.0% |   0.2% |    17.5MB |   166.2MB | SNl+   | 3
```
*(약 1분 이상 CPU 0.0%, RSS 17.5MB, 스레드 3개 상태로 무응답 유지)*

---

## 5. 데드락 4대 성립 조건 입증 요약

```mermaid
flowchart LR
    T1["Worker-Thread-1"] -->|점유 (Holding)| R1["[Shared_Memory_A]"]
    R1 -->|요청 대기 (BLOCKED)| T2["Worker-Thread-2"]
    T2 -->|점유 (Holding)| R2["[Socket_Pool_B]"]
    R2 -->|요청 대기 (BLOCKED)| T1
```

1. **상호 배제 (Mutual Exclusion)**: `Shared_Memory_A`와 `Socket_Pool_B`는 1개의 스레드만 독점 획득 가능한 뮤텍스/락 자원.
2. **점유 대기 (Hold and Wait)**: Thread-1은 `Shared_Memory_A`를 점유한 채 `Socket_Pool_B`를 요청, Thread-2는 `Socket_Pool_B`를 점유한 채 `Shared_Memory_A`를 요청.
3. **비선점 (No Preemption)**: 다른 스레드가 점유한 락을 강제로 빼앗을 수 없음.
4. **순환 대기 (Circular Wait)**: `Thread-1 ➔ Socket_Pool_B ➔ Thread-2 ➔ Shared_Memory_A ➔ Thread-1` 형태로 순환 대기 고리가 완성되어 영구 동결 발생.
