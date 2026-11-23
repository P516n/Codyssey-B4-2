# [Analysis] 로그 패턴 분석을 통한 스케줄링 알고리즘 추론

## 1. 로그 관찰 개요
`agent-leak-app`의 동시성 락 충돌을 회피한 정상 실행 상태(`MEMORY_LIMIT=512 MULTI_THREAD_ENABLE=false`)에서 스케줄러(`Scheduler`)가 등록된 작업 스레드들(`Thread-A`, `Thread-B`, `Thread-C`)을 처리하는 실행 로그를 수집하여, 런타임에 적용된 작업 스케줄링(Scheduling) 기법을 역추론했습니다.

---

## 2. 증거 자료 (`term_run.txt` 발췌)

스케줄러 초기화 후 등록된 3개 작업의 시작 및 완료 타임스탬프와 진행률(Progress) 로그 원본입니다:

```text
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

> 📌 증거 원본 파일: [evidence/04_bonus_scheduling/scheduling_task_logs.txt](../evidence/04_bonus_scheduling/scheduling_task_logs.txt)

---

## 3. 패턴 분석 및 최종 결론

### ① 라운드 로빈(Round-Robin)이 아닌 근거
* 라운드 로빈 스케줄링은 정해진 시간 할당량(Time Quantum)이 만료되면 실행 중인 태스크가 선점(Preemption)되어 중단되고 다음 태스크로 CPU가 전환되는 인터리빙(Interleaving) 패턴이 나타나야 합니다.
* 본 관측에서는 `Thread-A`가 시작(02:48:16,878)된 후 **중간에 끼어들기 없이 100% 완료(02:48:17,088)될 때까지 CPU를 독점**하여 실행되었습니다. 따라서 시분할 기반의 라운드 로빈 방식이 아닙니다.

### ② 우선순위(Priority) 스케줄링이 아닌 근거
* 특정 중요도나 우선순위에 따라 순서가 뒤바뀌지 않고, 초기 스케줄러 등록 목록인 `['Thread-A', 'Thread-B', 'Thread-C']`의 큐 진입 순서 그대로 엄격하게 실행되었습니다.

### ③ 최종 결론: FCFS (First-Come, First-Served / FIFO) 스케줄링
* 먼저 큐에 등록된 작업이 CPU를 할당받으면 완료될 때까지 다른 작업에 양보하지 않는 **비선점형(Non-preemptive) FCFS 스케줄링 알고리즘**으로 최종 결론지을 수 있습니다.

---

## 4. 기술적 장단점 및 적합한 서비스 아키텍처 분석

### ① FCFS 스케줄링의 장단점
* **장점**:
  * **구현 단순성 및 오버헤드 최소화**: 스케줄러 로직이 직관적이며, 프로세스/스레드 간 빈번한 문맥 교환(Context Switching)에 따른 CPU 캐시 미스와 스케줄링 오버헤드가 거의 없습니다.
  * **기아(Starvation) 방지**: 먼저 들어온 요청은 반드시 언젠가 처리되므로 특정 작업이 무한정 밀리는 현상이 없습니다.
* **단점 (호송 효과 / Convoy Effect)**:
  * 앞선 작업의 수행 시간이 길어지면, 뒤에 대기하는 가벼운 작업들의 응답 시간이 과도하게 늘어나는 **호송 효과(Convoy Effect)**가 발생합니다.

### ② 적합한 서비스 아키텍처
* **적합한 환경**:
  * **대용량 일괄 처리(Batch Processing) 시스템**: 은행의 마감 정산 시스템, 데이터 레이크의 야간 ETL 파이프라인처럼 실시간 인터랙션보다 전체 처리량(Throughput)과 완료 보장이 최우선인 배치 워커 환경에 가장 적합합니다.
* **부적합한 환경**:
  * **대고객 실시간 웹/API 서버**: 클라이언트의 빠른 응답 시간(Latency)과 공평성이 필수적인 온라인 트랜잭션 처리(OLTP) 환경에서는 FCFS 방식 적용 시 한 사용자의 긴 요청으로 인해 전체 사용자가 지연을 겪으므로 부적합합니다 (이 경우 Round-Robin 또는 Fair-Queueing 권장).
