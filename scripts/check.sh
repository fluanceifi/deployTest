#!/bin/bash

set -e

UPSTREAM_CONF="./nginx/upstream/upstream.conf"
NGINX_PORT="8620"
MAX_RETRY=30

# ──────────────────────────────────────────
# 1. upstream.conf 읽기 → Active / StandBy 판별
# ──────────────────────────────────────────
ACTIVE=$(grep -o 'spring-blue\|spring-green' "$UPSTREAM_CONF")

if [ "$ACTIVE" == "spring-blue" ]; then
    STANDBY_SERVICE="sw_team_7_spring_green"
    STANDBY_PORT="8640"
else
    STANDBY_SERVICE="sw_team_7_spring_blue"
    STANDBY_PORT="8630"
fi

echo "현재 Active  : $ACTIVE"
echo "배포 StandBy : $STANDBY_SERVICE (port: $STANDBY_PORT)"

# ──────────────────────────────────────────
# 2. StandBy 컨테이너 종료
# ──────────────────────────────────────────
echo "StandBy 컨테이너 종료..."
docker-compose stop "$STANDBY_SERVICE"

# ──────────────────────────────────────────
# 3. 새 이미지로 StandBy 재시작
# ──────────────────────────────────────────
echo "새 이미지로 StandBy 재시작..."
docker-compose up -d --no-deps --force-recreate "$STANDBY_SERVICE"

# ──────────────────────────────────────────
# 4. StandBy 헬스체크 폴링 (/actuator/health)
# ──────────────────────────────────────────
echo "StandBy 헬스체크 대기 중..."
COUNT=0
until curl -sf "http://localhost:${STANDBY_PORT}/actuator/health" > /dev/null 2>&1; do
    COUNT=$((COUNT + 1))
    if [ "$COUNT" -ge "$MAX_RETRY" ]; then
        echo "헬스체크 실패: ${MAX_RETRY}초 안에 응답 없음 → 배포 중단"
        docker-compose stop "$STANDBY_SERVICE"
        exit 1
    fi
    echo "  대기 중... ($COUNT/$MAX_RETRY)"
    sleep 1
done
echo "  헬스체크 통과"

# ──────────────────────────────────────────
# 5. switch.sh 호출 (nginx upstream 교체 + reload)
# ──────────────────────────────────────────
echo "nginx 트래픽 전환..."
chmod +x ./scripts/switch.sh
./scripts/switch.sh

# ──────────────────────────────────────────
# 6. nginx /health 최종 확인
# ──────────────────────────────────────────
sleep 1
if curl -sf "http://localhost:${NGINX_PORT}/health" > /dev/null 2>&1; then
    echo "배포 완료: nginx 정상 응답"
else
    echo "nginx /health 응답 없음 → 확인 필요"
    exit 1
fi
