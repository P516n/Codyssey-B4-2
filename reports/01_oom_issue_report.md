# [Bug] OOM Crash - 힙 메모리 지속 누수로 인한 MemoryGuard 강제 종료 결함

## 1. Description (현상 설명)
* **어떤 현상이 발생했는가?**
  `agent-leak-app` 실행 후 물리 메모리(RSS)가 시간 경과에 따라 선형적으로 급격히 증가하다가, 터미널에 `[SYSTEM] SELF-TERMINATED (Memory Limit Exceeded)` 메시지와 함께 프로세스가 예고 없이 강제 종료(Killed)되는 현상이 발생했습니다.
* **언제, 어떤 조건에서 발생했는가?**
  기본 환경변수 `MEMORY_LIMIT=128MB` 설정 상태에서 프로세스 기동 약 16초 후, 힙 메모리가 임계치를 초과한 150MB에 도달하는 시점에 프로세스 자가 보호 메커니즘인 `MemoryGuard`에 의해 트리거되었습니다.

---

## 2. Evidence & Logs (증거 자료)

### ① `monitor.sh` 관제 로그 데이터 (물리 메모리 선형 증가 수치)
자식 워커 프로세스(PID: 22327)를 2초 주기로 추적한 결과, 물리 메모리(RSS)가 3초당 약 25MB씩 지속적으로 누수되는 패턴이 관측되었습니다:

```text
Timestamp             | PID     | PPID    | %CPU   | %MEM   | RSS(MB)   | VSZ(MB)   | STAT   | THRDS
------------------------------------------------------------------------------------------
[2026-11-23 02:07:19] | 22327   | 22326   |   6.2% |   0.2% |    17.4MB |    22.2MB | SN+    | 1
[2026-11-23 02:07:21] | 22327   | 22326   |   3.3% |   0.6% |    42.4MB |    47.2MB | SN+    | 1
[2026-11-23 02:07:23] | 22327   | 22326   |   2.8% |   1.0% |    67.4MB |    72.2MB | SN+    | 1
[2026-11-23 02:07:27] | 22327   | 22326   |   1.9% |   1.3% |    92.4MB |    97.2MB | SN+    | 1
[2026-11-23 02:07:29] | 22327   | 22326   |   1.8% |   1.7% |   117.4MB |   122.2MB | SN+    | 1
[2026-11-23 02:07:33] | 22327   | 22326   |   1.6% |   2.1% |   142.4MB |   147.2MB | SN+    | 1
[2026-11-23 02:07:35] | NOT_FOUND | --      | --     | --     | --        | --        | --     | --
```

### ② 프로그램 실행 로그 중 핵심 구간 발췌 (`term_run.txt`)
`MemoryWorker` 스레드가 힙 메모리를 증대시키다가 `MEMORY_LIMIT`에 도달하여 비상 자가 종료되는 로그입니다:

```text
2026-11-23 02:07:20,074 [INFO] [MemoryWorker] Current Heap: 25MB
2026-11-23 02:07:23,111 [INFO] [MemoryWorker] Current Heap: 50MB
2026-11-23 02:07:26,162 [INFO] [MemoryWorker] Current Heap: 75MB
2026-11-23 02:07:29,207 [INFO] [MemoryWorker] Current Heap: 100MB
2026-11-23 02:07:32,261 [INFO] [MemoryWorker] Current Heap: 125MB
2026-11-23 02:07:35,311 [INFO] [MemoryWorker] Current Heap: 150MB
2026-11-23 02:07:35,312 [CRITICAL] [MemoryGuard] Memory limit exceeded (150MB >= 128MB) / (Recommend Over 256MB)
2026-11-23 02:07:35,314 [CRITICAL] [MemoryGuard] Self-terminating process 22327 to prevent system instability.

>>> [SYSTEM] SELF-TERMINATED (Memory Limit Exceeded) <<<

/app/run.sh: line 32: 22326 Killed                  "$APP_BIN"
```

---

## 3. Root Cause Analysis (원인 분석)

### ① 애플리케이션 레벨 원인
`MemoryWorker` 로직 내에서 주기적으로 할당된 데이터 구조체(리스트/캐시 등)가 작업 완료 후 가비지 컬렉터(GC)에 의해 회수되지 않고 메모리 참조가 유지되는 전형적인 **메모리 누수(Memory Leak)** 결함입니다. 3초마다 약 25MB씩 힙 메모리가 해제 없이 누적되었습니다.

### ② OS 및 런타임 보호 정책 동작 원리
* **운영체제 OOM Killer와 MemoryGuard의 차이**:
  * 리눅스 커널의 기본 OOM(Out of Memory) Killer는 시스템 전체 물리 메모리와 스왑 영역이 고갈될 때 점수가 높은 프로세스를 무작위 선정하여 `SIGKILL`을 보냅니다. 이는 시스템 전체 패닉이나 무관한 다른 서비스 프로세스의 의도치 않은 종료를 초래할 위험이 있습니다.
  * `agent-leak-app`은 이를 방지하기 위해 프로세스 내부에 **자가 임계치 감시자(`MemoryGuard`)**를 두고, 할당 메모리가 `MEMORY_LIMIT`을 초과하는 즉시 스스로 자식 프로세스를 정리(`Self-terminating`)하여 호스트 OS 및 인접 프로세스의 안정성을 보장하도록 설계되었습니다.

---

## 4. Workaround & Verification (조치 및 검증)

### ① 임시 조치 내용
환경변수 `MEMORY_LIMIT`을 기존 `128MB`에서 `256MB`로 2배 상향 조정하여 프로세스 재실행:
```bash
MEMORY_LIMIT=256 /app/run.sh
```

### ② Before & After 비교 결과 (검증)

| 항목 | Before (`MEMORY_LIMIT=128MB`) | After (`MEMORY_LIMIT=256MB`) | 비교 결과 |
| :--- | :--- | :--- | :--- |
| **종료 시점 힙 메모리** | 150 MB | 275 MB | 허용 한도 증대에 비례하여 도달 |
| **프로세스 생존 시간** | **약 16초** (02:07:19 ~ 02:07:35) | **약 34초** (02:07:51 ~ 02:08:25) | **생존 시간 2.1배 이상 연장 확인** |
| **관제 최대 점유 RSS** | 142.4 MB | 267.7 MB | 물리 메모리 점유율 동반 상승 확인 |
| **종료 메시지** | `150MB >= 128MB` 초과 종료 | `275MB >= 256MB` 초과 종료 | MemoryGuard 정책 정상 동작 확인 |

> 📌 증거 원본 파일: [evidence/01_oom/before_memory_limit_128mb.txt](../evidence/01_oom/before_memory_limit_128mb.txt), [evidence/01_oom/after_memory_limit_256mb.txt](../evidence/01_oom/after_memory_limit_256mb.txt)

### ③ 근본적 해결을 위한 추가 제안 (코드 레벨)
* **메모리 참조 해제**: `MemoryWorker` 루프 내부에서 사용이 끝난 임시 캐시 또는 리스트 객체에 대해 `del`, `.clear()`, 또는 `.pop()`을 명시적으로 호출하고 순환 참조를 제거해야 합니다.
* **WeakRef 또는 LRU Cache 도입**: 무제한 메모리 증식을 방지하기 위해 최대 크기(`maxsize`)가 제한된 캐시 정책(`functools.lru_cache` 등)을 적용해야 합니다.
