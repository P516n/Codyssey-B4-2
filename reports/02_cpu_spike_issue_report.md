# [Bug] CPU Spike - CPU 과점유로 인한 Watchdog 비상 차단(SIGTERM) 장애

## 1. Description (현상 설명)
* **어떤 현상이 발생했는가?**
  `agent-leak-app` 실행 중 특정 작업 구간에서 CPU 사용률이 급격히 치솟으며, `[SYSTEM] WATCHDOG: INITIATING EMERGENCY ABORT (SIGTERM)` 메시지가 출력되고 프로세스가 비정상 강제 종료(`Terminated`)되는 현상이 발생했습니다.
* **언제, 어떤 조건에서 발생했는가?**
  단일 스레드 모드(`MULTI_THREAD_ENABLE=false`)에서 `CPU_MAX_OCCUPY`가 허용 권장치(50%)를 초과한 `90%`로 설정되었을 때, `CpuWorker`의 부하가 52.36%에 도달하는 순간 내부 감시 정책인 `Watchdog`에 의해 강제 종료되었습니다.

---

## 2. Evidence & Logs (증거 자료)

### ① 프로그램 실행 로그 핵심 발췌 (`term_run.txt`)
`CpuWorker`의 부하가 가파르게 상승하다가 50% 임계치를 넘자마자 Watchdog 정책에 의해 차단되는 로그입니다:

```text
2026-11-23 03:05:43,772 [INFO] [CpuWorker] Started. Maximum CPU Limit: 90%
2026-11-23 03:05:43,774 [INFO] [CpuWorker] Current Load: 5.00%
2026-11-23 03:05:46,893 [INFO] [CpuWorker] Current Load: 13.34%
2026-11-23 03:05:50,011 [INFO] [CpuWorker] Current Load: 17.17%
2026-11-23 03:05:53,129 [INFO] [CpuWorker] Current Load: 18.96%
2026-11-23 03:05:56,245 [INFO] [CpuWorker] Current Load: 27.39%
2026-11-23 03:05:59,362 [INFO] [CpuWorker] Current Load: 36.85%
2026-11-23 03:06:02,480 [INFO] [CpuWorker] Current Load: 42.77%
2026-11-23 03:06:05,598 [INFO] [CpuWorker] Current Load: 52.36%
2026-11-23 03:06:05,701 [CRITICAL] [CpuWorker] CPU Threshold Violated! (52.36%).

>>> [SYSTEM] WATCHDOG: INITIATING EMERGENCY ABORT (SIGTERM) <<<

Terminated
```

### ② 관제 모니터링 로그 (`term_monitor.txt`)
`monitor.sh` 관제 로그 상에서 프로세스(PID: 43416)가 약 24초 동안 연산을 수행하다가 03:06:07에 급작스럽게 종료(`NOT_FOUND`)된 기록:

```text
Timestamp             | PID     | PPID    | %CPU   | %MEM   | RSS(MB)   | VSZ(MB)   | STAT   | THRDS
------------------------------------------------------------------------------------------
[2026-11-23 03:05:42] | 43416   | 43415   |   7.8% |   0.2% |    17.6MB |    22.2MB | SN+    | 1
[2026-11-23 03:05:46] | 43416   | 43415   |   1.9% |   0.2% |    17.7MB |    23.2MB | SN+    | 1
[2026-11-23 03:06:01] | 43416   | 43415   |   1.0% |   0.2% |    17.7MB |    23.2MB | SN+    | 1
[2026-11-23 03:06:05] | 43416   | 43415   |   1.0% |   0.2% |    17.7MB |    23.2MB | SN+    | 1
[2026-11-23 03:06:07] | NOT_FOUND | --      | --     | --     | --        | --        | --     | --
```

### ③ 시스템 도구(`top`) 출력 결과 (`term_ps.txt`)
시스템 전체 자원 점유 상태 점검:
```text
top - 03:06:48 up  3:27,  0 user,  load average: 0.07, 0.02, 0.00
    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
  43898 appuser   30  10   23712  18020   9656 S   0.0   0.3   0:00.30 agent-leak-app-
```

---

## 3. Root Cause Analysis (원인 분석)

### ① 기술적 원인 분석
애플리케이션 초기 부팅 시 출력된 리소스 정책 경고(`[ CPU ] Limit: 90% [ WARNING: Recommend Under 50% ]`)에서 알 수 있듯이, 단일 프로세스가 호스트의 CPU 코어를 50% 이상 독점하지 못하도록 하는 시스템 안전 가이드라인이 설정되어 있습니다. 
`CPU_MAX_OCCUPY`를 90%로 허용하자 `CpuWorker`가 무제한 연산을 시도하다가 부하가 52.36%에 도달했고, 이를 감지한 **Watchdog 스레드가 `SIGTERM` 시그널을 발행하여 프로세스를 긴급 회수**했습니다.

### ② 관련 OS 동작 원리 (CPU 스케줄링 및 지연 현상)
* **CPU Starvation 및 System Latency**:
  * 운영체제(OS)는 시분할(Time-sharing) 방식으로 여러 프로세스에 CPU 시간을 공평하게 분배합니다. 
  * 만약 특정 유저 프로세스가 CPU를 과도하게 점유하면, 동일 서버에서 구동 중인 다른 핵심 데몬(네트워크 I/O, 웹 서버, 모니터링 에이전트 등)이 CPU 시간을 할당받지 못하는 **기아 현상(Starvation)**이 발생하고, 시스템 전반의 응답 지연(System Latency) 및 타임아웃 장애로 확산됩니다.
* **Watchdog 메커니즘의 필요성**:
  * 운영체제 전체의 연쇄 다운을 방지하기 위해, 개별 프로세스 레벨에서 허용 임계치를 넘는 즉시 비정상 프로세스를 격리/종료시키는 Watchdog(감시견) 패턴이 필수적입니다.

---

## 4. Workaround & Verification (조치 및 검증)

### ① 임시 조치 내용
CPU 점유율 한계치인 `CPU_MAX_OCCUPY` 환경변수를 안전 권장 범위인 `20%`로 하향 조정하여 재실행:
```bash
MEMORY_LIMIT=512 MULTI_THREAD_ENABLE=false CPU_MAX_OCCUPY=20 /app/run.sh
```

### ② Before & After 비교 결과 (검증)

| 항목 | Before (`CPU_MAX_OCCUPY=90%`) | After (`CPU_MAX_OCCUPY=20%`) | 비교 결과 |
| :--- | :--- | :--- | :--- |
| **CPU 최대 점유율** | **52.36%** (위반 발생) | **20.00%** (한계 도달 후 자가 제어) | 과점유 방지 성공 |
| **Watchdog 트리거 여부** | **트리거됨 (`SIGTERM` Abort)** | **트리거되지 않음 (정상 동작)** | 보호 정책 위반 차단 |
| **프로세스 동작 상태** | 실행 후 약 24초 만에 `Terminated` | `Starting cooldown...` 순환 반복 | **정상 상태 지속 생존 확인** |

```text
[ After 실행 시 관측된 정상 쿨다운 로그 ]
2026-11-23 02:59:13 [INFO] [CpuWorker] Peak reached (20.00%). Starting cooldown...
2026-11-23 02:59:28 [INFO] [CpuWorker] Cooldown complete (5.00%). Resuming load increase...
2026-11-23 02:59:35 [INFO] [CpuWorker] Peak reached (20.00%). Starting cooldown...
```

> 📌 증거 원본 파일: [evidence/03_cpu_spike/before_cpu_watchdog_terminated.txt](../evidence/03_cpu_spike/before_cpu_watchdog_terminated.txt), [evidence/03_cpu_spike/after_cpu_healthy_cooldown.txt](../evidence/03_cpu_spike/after_cpu_healthy_cooldown.txt)

### ③ 근본적 해결을 위한 추가 제안 (코드 레벨)
* **적응형 Rate Limiting / Throttling**: 고연산 작업 루프에 `time.sleep()` 기반의 적응형 지연(backoff)을 부여하여 CPU 사용률이 일정 수준을 넘지 않도록 능동 조절.
* **비동기 작업 큐 및 배치 분산**: 대용량 CPU 집중 작업을 Celery, RQ 등 백그라운드 워커 풀로 분산하고, 프로세스의 CPU 친화도(Affinity) 및 Cgroups를 통한 자원 제한 설정.
