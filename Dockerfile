FROM ubuntu:24.04

# 타임존 및 비대화형 설정
ENV DEBIAN_FRONTEND=noninteractive

# 필수 모니터링 및 디버깅 유틸리티 설치
RUN apt-get update && apt-get install -y --no-install-recommends \
    procps \
    sysstat \
    htop \
    net-tools \
    iproute2 \
    curl \
    vim \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 일반 사용자 생성 (root 실행 방지 조건 충족)
RUN useradd -m -s /bin/bash appuser

# 앱 디렉터리 및 워크스페이스 디렉터리 사전 생성 및 권한 설정
# (볼륨 마운트 시 부모 디렉터리가 root 소유로 자동 생성되어 권한 오류가 발생하는 현상 방지)
RUN mkdir -p /app /home/appuser/agent-app/upload_files \
    /home/appuser/agent-app/api_keys \
    /home/appuser/agent-app/logs \
    /home/appuser/scripts

COPY bin/ /app/bin/
COPY entrypoint.sh /app/entrypoint.sh
COPY run.sh /app/run.sh

RUN chmod +x /app/entrypoint.sh /app/run.sh /app/bin/* && \
    chown -R appuser:appuser /app /home/appuser

# 일반 사용자로 전환
USER appuser
WORKDIR /home/appuser

ENTRYPOINT ["/app/entrypoint.sh"]
