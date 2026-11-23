# 📁 Evidence Directory Index

본 디렉터리는 시스템 장애 분석 미션에서 수집된 실제 터미널 실행 로그(`term_run.txt`), 관제 로그(`term_monitor.txt`), 시스템 상태 진단 출력(`term_ps.txt`)을 각 장애 시나리오별 Before & After에 맞추어 정리한 객관적 증거 자료 저장소입니다.

---

## 🗂️ 디렉터리 구조 및 파일 목록

### 1. [01_oom/](./01_oom) - 메모리 누수 및 OOM Crash
* [before_memory_limit_128mb.md](./01_oom/before_memory_limit_128mb.md): `MEMORY_LIMIT=128MB` 조건에서 25MB 단위로 물리 메모리가 누수되며 16초 만에 `MemoryGuard`에 의해 `SELF-TERMINATED`된 증거
* [after_memory_limit_256mb.md](./01_oom/after_memory_limit_256mb.md): `MEMORY_LIMIT=256MB`로 상향 조정 후 생존 시간이 34초로 2배 이상 연장된 Before & After 비교 증거

### 2. [02_deadlock/](./02_deadlock) - 교착 상태 (Deadlock)
* [before_deadlock_reproduced.md](./02_deadlock/before_deadlock_reproduced.md): `MULTI_THREAD_ENABLE=true` 조건에서 Thread-1과 Thread-2가 락을 교차 점유 대기(`BLOCKED`)하며 멈춘 증거, `ps -ef`(생존), `ps -L`(3개 스레드 `SNl+`), `top -H`(CPU 0.0% 정체)
* [after_deadlock_avoided.md](./02_deadlock/after_deadlock_avoided.md): `MULTI_THREAD_ENABLE=false`로 동시성을 해제하여 데드락 4대 조건을 원천 차단하고 태스크를 정상 완료한 증거

### 3. [03_cpu_spike/](./03_cpu_spike) - CPU 과점유 및 Watchdog 보호 조치
* [before_cpu_watchdog_terminated.md](./03_cpu_spike/before_cpu_watchdog_terminated.md): `CPU_MAX_OCCUPY=90%`로 과도한 CPU 점유 허용 시 52.36%에 도달하자 `Watchdog`이 긴급 개입하여 `SIGTERM`(`Terminated`) 강제 종료한 증거
* [after_cpu_healthy_cooldown.md](./03_cpu_spike/after_cpu_healthy_cooldown.md): `CPU_MAX_OCCUPY=20%`로 제한하여 Peak 도달 시 자동으로 Cooldown 주기를 돌며 강제 종료 없이 지속 생존하는 증거

### 4. [04_bonus_scheduling/](./04_bonus_scheduling) - 스케줄링 알고리즘 추론
* [scheduling_task_logs.md](./04_bonus_scheduling/scheduling_task_logs.md): Thread-A(100%) -> Thread-B(100%) -> Thread-C(100%) 순서대로 비선점형 순차 실행된 타임스탬프 기반 FCFS(First-Come, First-Served) 역추론 증거
