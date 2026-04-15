
#!/bin/bash

# 디렉토리 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

NGINX_CONTAINER="sw_team_7_nginx"
NGINX_CONF_PATH="/etc/nginx/conf.d/upstream.conf"

# 현재 upstream 확인 (nginx 컨테이너 내부에서 직접 읽기)
CURRENT=$(docker exec $NGINX_CONTAINER grep -o 'spring-blue\|spring-green' $NGINX_CONF_PATH)

# 전환할 upstream 파일 결정
if [ "$CURRENT" == "spring-blue" ]; then
  NEW_CONF="$PROJECT_ROOT/nginx/upstream/upstream_green.conf"
  echo "파일 전환: spring-blue → spring-green"
else
  NEW_CONF="$PROJECT_ROOT/nginx/upstream/upstream_blue.conf"
  echo "파일 전환: spring-green → spring-blue"
fi

# nginx 컨테이너에 직접 복사
docker cp "$NEW_CONF" "$NGINX_CONTAINER:$NGINX_CONF_PATH"

# 문법 검사
if ! docker exec $NGINX_CONTAINER nginx -t; then
  echo "검사: nginx 문법 오류 - 롤백"
  docker exec $NGINX_CONTAINER sh -c "sed -i 's/spring-blue/ROLLBACK/g;s/spring-green/$CURRENT/g;s/ROLLBACK/spring-blue/g' $NGINX_CONF_PATH" 2>/dev/null || true
  # 원본 파일 복원
  if [ "$CURRENT" == "spring-blue" ]; then
    docker cp "$PROJECT_ROOT/nginx/upstream/upstream_blue.conf" "$NGINX_CONTAINER:$NGINX_CONF_PATH"
  else
    docker cp "$PROJECT_ROOT/nginx/upstream/upstream_green.conf" "$NGINX_CONTAINER:$NGINX_CONF_PATH"
  fi
  exit 1
fi

echo "검사: 문법 통과"

# reload
if ! docker exec $NGINX_CONTAINER nginx -s reload; then
  echo "reload: 실패 - 롤백"
  if [ "$CURRENT" == "spring-blue" ]; then
    docker cp "$PROJECT_ROOT/nginx/upstream/upstream_blue.conf" "$NGINX_CONTAINER:$NGINX_CONF_PATH"
  else
    docker cp "$PROJECT_ROOT/nginx/upstream/upstream_green.conf" "$NGINX_CONTAINER:$NGINX_CONF_PATH"
  fi
  docker exec $NGINX_CONTAINER nginx -s reload
  exit 1
fi

echo "reload: 성공 - switch 완료"
