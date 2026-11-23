# Codyssey-B4-2: 시스템 장애 분석 및 기술 리포트 (Troubleshooting Mission)

운영체제 위에서 실행되는 애플리케이션의 3대 핵심 시스템 장애(**Memory Leak/OOM Crash**, **CPU Spike/Latency**, **Deadlock**)를 관제 도구와 시스템 유틸리티를 활용해 추적·분석하고, 이를 GitHub Issue 형태의 기술 리포트로 작성한 프로젝트입니다.

---

## 📑 시스템 장애 분석 리포트 목록 (산출물)

| 번호 | 장애 유형 | 리포트 문서 링크 | 핵심 분석 요약 |
| :---: | :--- | :--- | :--- |
| **01** | **OOM Crash (Memory Leak)** | [01_oom_issue_report.md](./reports/01_oom_issue_report.md) | 3초당 25MB 메모리 누수로 인한 `MemoryGuard` 자가 종료 분석 및 `MEMORY_LIMIT` 상향(128MB ➔ 256MB)에 따른 생존 시간 Before & After 검증 |
| **02** | **CPU Spike (Watchdog Abort)** | [02_cpu_spike_issue_report.md](./reports/02_cpu_spike_issue_report.md) | CPU 과점유(52.36%)에 따른 `Watchdog` 비상 차단(`SIGTERM`) 분석 및 `CPU_MAX_OCCUPY` 제한(90% ➔ 20%)을 통한 안정적 쿨다운 생존 검증 |
| **03** | **Deadlock (교착 상태)** | [03_deadlock_issue_report.md](./reports/03_deadlock_issue_report.md) | 멀티스레드 상호 락 점유 대기(`BLOCKED`) 및 정체 현상 진단(`ps -L`, `top -H`)과 `MULTI_THREAD_ENABLE=false`를 통한 데드락 원천 회피 검증 |
| **보너스**| **스케줄링 알고리즘 추론** | [04_bonus_scheduling_report.md](./reports/04_bonus_scheduling_report.md) | Thread-A ➔ Thread-B ➔ Thread-C 순차 실행 타임스탬프 분석을 통한 **FCFS(First-Come, First-Served)** 알고리즘 역추론 및 아키텍처 분석 |

---

## 🗂️ 객관적 증거 자료 아카이브 ([evidence/](./evidence))

수집된 터미널 실행 로그, 관제 로그(`monitor.sh`), 시스템 유틸리티 출력(`ps`, `top`)을 Before & After에 맞추어 보관하고 있습니다.

* **[OOM 증거]** [Before (128MB, 16초 만에 사망)](./evidence/01_oom/before_memory_limit_128mb.txt) | [After (256MB, 34초로 생존 시간 2배 증가)](./evidence/01_oom/after_memory_limit_256mb.txt)
* **[Deadlock 증거]** [Before (교착 상태로 3개 스레드 무한 대기)](./evidence/02_deadlock/before_deadlock_reproduced.txt) | [After (단일 스레드 정상 완료)](./evidence/02_deadlock/after_deadlock_avoided.txt)
* **[CPU Spike 증거]** [Before (임계치 위반으로 Watchdog SIGTERM 종료)](./evidence/03_cpu_spike/before_cpu_watchdog_terminated.txt) | [After (20% 제한 쿨다운 순환 생존)](./evidence/03_cpu_spike/after_cpu_healthy_cooldown.txt)
* **[보너스 과제 증거]** [스케줄링 태스크 순차 실행 타임스탬프 로그](./evidence/04_bonus_scheduling/scheduling_task_logs.txt)
* **[원본 로그]** [터미널 실행 로그](./logs/term_run.txt) | [관제 모니터링 로그](./logs/term_monitor.txt) | [프로세스/스레드 진단 로그](./logs/term_ps.txt)

---

## 🛠️ 1. 환경 구축 (Environment Setup)

애플리케이션은 보안 제약 상 root 계정으로 실행할 수 없으며, 필수 환경변수(`AGENT_HOME`), 포트 바인딩(`15034`), 그리고 `$AGENT_HOME/api_keys/secret.key` 파일이 사전에 준비되어야 합니다.

### Case 1: Ubuntu 24.04 Native / VM 환경
```bash
# 1. 필수 시스템 유틸리티 설치
sudo apt update && sudo apt install -y procps sysstat htop net-tools curl

# 2. 필수 디렉터리, secret.key 생성 및 환경변수 로드
source ./setup_env.sh

# 3. 바이너리 실행 권한 부여
chmod +x ./bin/agent-leak-app-x86
```

### Case 2: Docker Compose 컨테이너 환경 (권장)
```bash
# 1. 컨테이너 빌드 및 백그라운드 구동
docker compose up -d --build

# 2. 컨테이너 내부 셸 접속
docker exec -it agent-leak-tester bash
```

---

## 🔬 2. 장애 시나리오별 재현 및 검증 방법 (Reproduction & Verification)

> 💡 **관제 사전 준비**: 아래 모든 시나리오를 실행하기 전, **별도의 터미널(터미널 1)**에서 실시간 모니터링 스크립트를 켜두면 프로세스의 물리 메모리(RSS)와 CPU 점유율 변화를 실시간으로 기록할 수 있습니다.
> ```bash
> # 터미널 1: 관제 모니터링 스크립트 실행
> bash /home/appuser/scripts/monitor.sh   # (네이티브 환경은 ./scripts/monitor.sh)
> ```

---

### ① 메모리 누수 및 OOM Crash (Memory Leak)

#### [Before] 128MB 임계치 초과 및 자가 종료 재현
```bash
# 터미널 2: 기본 메모리 제한(128MB)으로 실행
MEMORY_LIMIT=128 /app/run.sh
```
* **동작 원리**: `MemoryWorker`가 3초마다 약 25MB씩 힙 메모리를 해제 없이 누적합니다.
* **관측 결과**:
  * 02:07:20(25MB)부터 시작하여 약 16초 후 150MB에 도달합니다.
  * `[CRITICAL] [MemoryGuard] Memory limit exceeded (150MB >= 128MB)` 로그 출력.
  * 호스트 시스템 전체의 패닉을 방지하기 위해 내부 `MemoryGuard` 정책에 의해 `SELF-TERMINATED (Killed)` 됩니다.

#### [After] 임계치 상향(256MB) 조치 및 생존 시간 비교
```bash
# 터미널 2: 가용 메모리를 256MB로 상향하여 실행
MEMORY_LIMIT=256 /app/run.sh
```
* **관측 결과**:
  * 02:07:53(25MB)부터 시작하여 약 34초 동안 생존한 후 275MB 도달 시점에 종료됩니다.
  * **Before(16초) 대비 생존 시간이 2.1배 이상 연장**되는 것을 확인하여, 메모리 누수의 전형적 특징(가용 메모리 증설 시 비례하여 생존 시간 증가)을 입증합니다.

---

### ② 교착 상태 (Deadlock)

#### [Before] 멀티스레드 락 경쟁으로 인한 영구 무응답 재현
```bash
# 터미널 2: OOM을 회피(512MB)하고 멀티스레드 동시성 활성화
MEMORY_LIMIT=512 MULTI_THREAD_ENABLE=true /app/run.sh
```
* **동작 원리**: 
  * `Worker-Thread-1`이 `Shared_Memory_A` 락을 쥐고 `Socket_Pool_B`를 요청.
  * `Worker-Thread-2`가 `Socket_Pool_B` 락을 쥐고 `Shared_Memory_A`를 요청.
* **관측 결과**:
  * 두 스레드가 서로의 자원을 기다리며 `Status: BLOCKED` 로그를 끝으로 화면과 출력이 완전히 정체됩니다.
* **시스템 진단 (터미널 3)**:
  ```bash
  # 1. 프로세스 생존 확인 (PID 존재)
  ps -ef | grep agent
  
  # 2. 스레드 목록 및 대기 상태 확인 (3개 스레드 모두 SNl+ 상태)
  ps -L -p <PID> -o pid,tid,stat,%cpu,%mem,comm
  
  # 3. CPU/자원 정체 증거 확인 (%CPU 0.0% 확인)
  top -b -n 1 -H -p <PID>
  ```

#### [After] 단일 스레드 모드로 전환하여 데드락 회피
```bash
# 터미널 2: 동시성 자원 경쟁 비활성화
MEMORY_LIMIT=512 MULTI_THREAD_ENABLE=false /app/run.sh
```
* **관측 결과**:
  * 동시성 락 충돌 조건(점유 대기 및 순환 대기)이 원천 배제되어, `Thread-A` ➔ `Thread-B` ➔ `Thread-C`가 순차적으로 100% 완료되며 파이프라인이 정상적으로 진행됩니다.

---

### ③ CPU 과점유 및 Watchdog 보호 조치 (CPU Spike)

#### [Before] CPU 과점유 유도 및 Watchdog 비상 차단(SIGTERM) 재현
```bash
# 터미널 2: CPU 한도를 90%로 과도하게 허용하여 실행
MEMORY_LIMIT=512 MULTI_THREAD_ENABLE=false CPU_MAX_OCCUPY=90 /app/run.sh
```
* **동작 원리**: `CpuWorker`가 부하를 지속적으로 가중시키다가 내부 안전 임계치(50%)를 위반합니다.
* **관측 결과**:
  * 부하가 5.00% ➔ 13.34% ➔ 36.85% ➔ 52.36%로 급상승합니다.
  * 50%를 초과하는 순간 `[CRITICAL] [CpuWorker] CPU Threshold Violated! (52.36%)` 출력.
  * `>>> [SYSTEM] WATCHDOG: INITIATING EMERGENCY ABORT (SIGTERM) <<<` 메시지와 함께 실행 약 24초 만에 프로세스가 비상 강제 종료(`Terminated`)됩니다.

#### [After] CPU 안전 임계치(20%) 설정 및 자가 조절 쿨다운 확인
```bash
# 터미널 2: CPU 한도를 안전 범위(20%)로 제한하여 실행
MEMORY_LIMIT=512 MULTI_THREAD_ENABLE=false CPU_MAX_OCCUPY=20 /app/run.sh
```
* **관측 결과**:
  * CPU 부하가 20%에 도달하면 `Peak reached (20.00%). Starting cooldown...` 로그와 함께 5%로 부하를 낮추는 자가 조절(Cooldown)을 반복합니다.
  * Watchdog 개입 없이 프로세스가 강제 종료되지 않고 지속적으로 안정 생존(`Healthy System Monitoring`)함을 확인합니다.

---

### ④ [보너스] FCFS 스케줄링 알고리즘 패턴 확인
`MULTI_THREAD_ENABLE=false` 실행 시 출력되는 태스크 스케줄러 로그를 확인합니다:
```text
[Thread-A] Task Started. Calculating... (20% -> 100% Completed)
[Thread-B] Task Started. Calculating... (20% -> 100% Completed)
[Thread-C] Task Started. Calculating... (20% -> 100% Completed)
```
* 앞선 작업이 끝나기 전 다른 작업이 끼어드는 타임 슬라이스(Round-Robin)가 없으며, 등록된 순서 그대로 끝까지 처리하는 **비선점형 FCFS (First-Come, First-Served) 스케줄링**이 적용되었음을 증명합니다.
