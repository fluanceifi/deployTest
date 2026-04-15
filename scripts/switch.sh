
#!/bin/bash

# 디렉토리 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

UPSTREAM_DIR="$PROJECT_ROOT/nginx/conf.d"
UPSTREAM_CONF="$UPSTREAM_DIR/upstream.conf"
BACKUP_CONF="$PROJECT_ROOT/nginx/conf.d/upstream.conf.bak"  # 백업 파일

# 백업
cp $UPSTREAM_CONF $BACKUP_CONF

# 판별
CURRENT=$(grep -o 'spring-blue\|spring-green' $UPSTREAM_CONF)

# 파일 전환 → 문법 검사 → reload

if [ "$CURRENT" == "spring-blue" ]; then
  cp "$PROJECT_ROOT/nginx/upstream/upstream_green.conf" "$UPSTREAM_CONF"
  echo " 파일 전환: spring blue → spring-green"
else
  cp "$PROJECT_ROOT/nginx/upstream/upstream_blue.conf" "$UPSTREAM_CONF"
  echo "파일 전환: spring-green → spring-blue"
fi


# 문법 검사
if ! docker exec sw_team_7_nginx nginx -t; then
  echo "검사: nginx 문법 오류 - 롤백"
  cp $BACKUP_CONF $UPSTREAM_CONF # 복원
  exit 1
fi

echo "검사: 문법 통과"

#reload
if ! docker exec sw_team_7_nginx nginx -s reload; then
  echo "reload: 실패 - 롤백"
  cp $BACKUP_CONF $UPSTREAM_CONF #복원
  docker exec sw_team_7_nginx nginx -s reload #원본 reload
  exit 1
fi

echo "reload: 성공 - switch 완료"

