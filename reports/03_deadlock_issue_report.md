# [Bug] Deadlock - 멀티스레드 자원 경쟁으로 인한 프로세스 영구 무응답 결함

## 1. Description (현상 설명)
* **어떤 현상이 발생했는가?**
  `agent-leak-app` 실행 후 프로세스가 에러 없이 살아있음(PID 유지)에도 불구하고, CPU와 메모리 변화가 전혀 없고 로그 출력도 완전히 중단된 **영구 무응답(Hang/Freeze)** 상태에 빠졌습니다.
* **언제, 어떤 조건에서 발생했는가?**
  메모리 제약이 충분한 상태(`MEMORY_LIMIT=512MB`)에서 동시성 트랜잭션 옵션(`MULTI_THREAD_ENABLE=true`)을 활성화했을 때, 트랜잭션 처리 스레드 간 상호 락 획득 후 상대 자원을 요청하는 시점에 발생했습니다.

---

## 2. Evidence & Logs (증거 자료)

### ① 마지막 실행 로그 지점 발췌 (`term_run.txt`)
두 스레드가 각각 자원 하나씩을 점유한 채 서로의 자원을 요청하며 `BLOCKED` 상태에 빠진 결정적 로그:

```text
2026-11-23 02:08:33,253 [INFO] [AgentWorker][Worker-Thread-1] LOCK ACQUIRED: [Shared_Memory_A]. (Holding...)
2026-11-23 02:08:33,255 [INFO] [AgentWorker][Worker-Thread-2] LOCK ACQUIRED: [Socket_Pool_B]. (Holding...)
2026-11-23 02:08:33,259 [INFO] [AgentWorker][Worker-Thread-1] Processing critical data in Memory A...
2026-11-23 02:08:33,261 [INFO] [AgentWorker][Worker-Thread-2] Establishing network connections in Pool B...
2026-11-23 02:08:35,273 [INFO] [AgentWorker][Worker-Thread-1] Need resource [Socket_Pool_B] to finish job.
2026-11-23 02:08:35,274 [INFO] [AgentWorker][Worker-Thread-2] Need resource [Shared_Memory_A] to write logs.
2026-11-23 02:08:35,275 [INFO] [AgentWorker][Worker-Thread-1] WAITING for [Socket_Pool_B]... (Status: BLOCKED)
2026-11-23 02:08:35,277 [INFO] [AgentWorker][Worker-Thread-2] WAITING for [Shared_Memory_A]... (Status: BLOCKED)
(※ 이 로그를 끝으로 추가 작업 없이 프로세스가 무한 대기함)
```

### ② 프로세스 생존 증거 (`ps -ef | grep agent`)
프로세스가 크래시된 것이 아니라 정상 동작 상태(PID: 34932, 34933)로 유지되고 있음을 입증:
```text
UID          PID    PPID  C STIME TTY          TIME CMD
appuser    34932   34930  0 02:46 pts/0    00:00:00 /app/bin/agent-leak-app-x86
appuser    34933   34932  0 02:46 pts/0    00:00:00 /app/bin/agent-leak-app-x86
```

### ③ 스레드별 상태 추적 (`ps -L`) 및 자원 정체 증거 (`top -H`)
3개 스레드(메인 스레드 34933, 작업 스레드 35018, 35019)가 모두 `S`(Sleeping, 대기) 상태로 CPU 점유율이 0.0%로 정체된 증거:

```text
[ ps -L 출력 결과 ]
    PID     TID STAT %CPU %MEM COMMAND
  34933   34933 SNl+  0.1  0.2 agent-leak-app-
  34933   35018 SNl+  0.0  0.2 agent-leak-app-
  34933   35019 SNl+  0.0  0.2 agent-leak-app-

[ top -H 출력 결과 ]
Threads:   3 total,   0 running,   3 sleeping,   0 stopped,   0 zombie
    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
  34933 appuser   30  10  170152  17916   9548 S   0.0   0.3   0:00.07 agent-leak-app-
  35018 appuser   30  10  170152  17916   9548 S   0.0   0.3   0:00.00 agent-leak-app-
  35019 appuser   30  10  170152  17916   9548 S   0.0   0.3   0:00.00 agent-leak-app-
```

---

## 3. Root Cause Analysis (원인 분석)

### ① 교착상태(Deadlock) 4대 조건 성립 분석
프로그램 로그와 시스템 도구 출력을 통해 교착 상태의 4대 필요조건이 완벽히 충족되었음을 입증했습니다:

```mermaid
flowchart LR
    T1["Worker-Thread-1"] -->|Holding| R1["[Shared_Memory_A]"]
    R1 -->|Requested by| T2["Worker-Thread-2"]
    T2 -->|Holding| R2["[Socket_Pool_B]"]
    R2 -->|Requested by (BLOCKED)| T1
```

1. **상호 배제 (Mutual Exclusion)**: `Shared_Memory_A`와 `Socket_Pool_B`는 한 번에 하나의 스레드만 락을 점유할 수 있는 배타적 자원입니다.
2. **점유 대기 (Hold and Wait)**: `Worker-Thread-1`은 `Shared_Memory_A`를 쥔 상태로 `Socket_Pool_B`를 요청하고, `Worker-Thread-2`는 `Socket_Pool_B`를 쥔 상태로 `Shared_Memory_A`를 대기합니다.
3. **비선점 (No Preemption)**: 이미 다른 스레드가 획득한 락을 외부에서 강제로 빼앗을 수 없습니다.
4. **순환 대기 (Circular Wait)**: Thread-1 ➔ Thread-2 ➔ Thread-1 형태의 순환 의존 고리가 완성되어 어느 누구도 다음 단계로 진행하지 못하는 영구 동결 상태가 초래되었습니다.

---

## 4. Workaround & Verification (조치 및 검증)

### ① 임시 조치 내용
자원 경쟁을 유발하는 멀티스레드 동시성 옵션 `MULTI_THREAD_ENABLE`을 `false`로 변경하여 단일 스레드 모드로 재실행:
```bash
MEMORY_LIMIT=512 MULTI_THREAD_ENABLE=false /app/run.sh
```

### ② Before & After 비교 결과 (검증)

| 항목 | Before (`MULTI_THREAD_ENABLE=true`) | After (`MULTI_THREAD_ENABLE=false`) | 비교 결과 |
| :--- | :--- | :--- | :--- |
| **자원 획득 상태** | `Status: BLOCKED` (교차 대기) | 순차적 락 획득 및 해제 완료 | 락 충돌 배제 |
| **태스크 완료 여부** | 미완료 (영구 무응답 상태 지속) | **Thread-A, B, C 전 태스크 100% 완료** | **정상 처리 성공** |
| **스레드 상태** | 3개 스레드 생성 후 대기(`SNl+`) | 단일 스레드로 정상 작업 후 워커 전환 | 데드락 원천 회피 |
| **CPU/로그 변화** | 02:08:35 이후 0.0%로 완전 동결 | 스케줄러 완료 후 CPU/메모리 워커 단계 진입 | 파이프라인 지속 |

```text
[ After 실행 시 관측된 정상 작업 완료 로그 ]
2026-11-23 02:48:17 [INFO] [Thread-A] Task Completed. (100%)
2026-11-23 02:48:17 [INFO] [Thread-B] Task Completed. (100%)
2026-11-23 02:48:17 [INFO] [Thread-C] Task Completed. (100%)
2026-11-23 02:48:17 [INFO] [Scheduler] All tasks completed.
```

> 📌 증거 원본 파일: [evidence/02_deadlock/before_deadlock_reproduced.md](../evidence/02_deadlock/before_deadlock_reproduced.md), [evidence/02_deadlock/after_deadlock_avoided.md](../evidence/02_deadlock/after_deadlock_avoided.md)

### ③ 근본적 해결을 위한 추가 제안 (코드 레벨)
* **락 획득 순서의 전역 일관성 유지 (Lock Ordering)**: 모든 스레드가 자원을 요청할 때 반드시 동일한 순서(예: 항상 `Shared_Memory_A` ➔ `Socket_Pool_B` 순)로만 락을 요청하도록 강제하면 순환 대기(Circular Wait)가 원천 차단됩니다.
* **타임아웃 적용 (Timed Lock)**: `mutex.acquire(timeout=5)`처럼 타임아웃을 설정하여, 일정 시간 내에 락을 얻지 못하면 기존 점유 자원을 반납하고 재시도하도록 설계.
