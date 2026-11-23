# [증거 자료] 태스크 스케줄링 알고리즘 분석 (FCFS 추론)

## 1. 수집 환경 및 실행 조건

| 항목 | 설정값 | 비고 |
| :--- | :--- | :--- |
| **`MEMORY_LIMIT`** | `512` (단위: MB) | OOM 방지를 위한 충분한 메모리 할당 |
| **`CPU_MAX_OCCUPY`** | `20` (단위: %) | CPU 스파이크 워치독 방지 |
| **`MULTI_THREAD_ENABLE`** | `false` | 스레드 순차 실행 모드 활성화 |
| **수집 출처** | `term_run.txt` (Line 363 ~ 381) | 실행 로그 발췌 |
| **실행 일시** | `2026-11-23 02:48:16` | 정상 순차 실행 모드 검증 테스트 |

---

## 2. 태스크 스케줄러 실행 로그 원본

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

---

## 3. 타임스탬프 상세 타임라인 분석

| 태스크명 | 시작 시각 | 완료 시각 | 소요 시간(ms) | 비고 |
| :--- | :--- | :--- | :--- | :--- |
| **`Thread-A`** | `02:48:16,878` | `02:48:17,088` | 210ms | 02:48:16,874에 1순위 등록됨 |
| **`Thread-B`** | `02:48:17,140` | `02:48:17,350` | 210ms | Thread-A 완료 후 즉시 착수 |
| **`Thread-C`** | `02:48:17,403` | `02:48:17,613` | 210ms | Thread-B 완료 후 즉시 착수 |

---

## 4. 패턴 분석 및 결론

1. **비선점성(Non-preemptive)**:
   - `Thread-A`가 시작(`16.878`)된 후 완료(`17.088`)될 때까지 다른 스레드의 컨텍스트 스위칭이나 끼어들기가 일절 발생하지 않음.
   - 라운드 로빈(Round-Robin)과 같은 시분할(Time-slice) 기반의 교차 실행 패턴이 아님.
2. **도착 순서(큐 등록 순서) 기반 엄격한 처리**:
   - `Registered Tasks: ['Thread-A', 'Thread-B', 'Thread-C']` 큐에 등록된 인덱스 순서 그대로 `Thread-A ➔ Thread-B ➔ Thread-C`로 실행됨.
3. **최종 결론**:
   - 본 애플리케이션의 내부 태스크 스케줄러는 **FCFS (First-Come, First-Served / FIFO) 비선점형 스케줄링 알고리즘**을 채택하고 있음을 명확하게 입증함.
