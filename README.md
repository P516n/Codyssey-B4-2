# Codyssey-B4-2: 시스템 장애 분석 및 기술 리포트 (Troubleshooting Mission)

운영체제 위에서 실행되는 애플리케이션의 3대 핵심 시스템 장애(**Memory Leak/OOM Crash**, **CPU Spike/Latency**, **Deadlock**)를 관제 도구와 시스템 유틸리티를 활용해 추적·분석하고, 이를 GitHub Issue 형태의 기술 리포트로 작성한 결과물입니다.

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

---

## 🛠️ 환경 구축 및 재현 방법

### Case 1: Ubuntu 24.04 Native / VM
```bash
# 환경 설정 및 secret.key 생성
source ./setup_env.sh

# 관제 실행 (터미널 1)
bash ./scripts/monitor.sh

# 애플리케이션 실행 (터미널 2)
./bin/agent-leak-app-x86
```

### Case 2: Docker Compose
```bash
# 컨테이너 빌드 및 백그라운드 구동
docker compose up -d --build

# 관제 실행 (터미널 1)
docker exec -it agent-leak-tester bash
bash /home/appuser/scripts/monitor.sh

# 애플리케이션 실행 (터미널 2)
docker exec -it agent-leak-tester bash
/app/run.sh
```
