# Jenkins Blue-Green 무중단 배포

Jenkins CI/CD 파이프라인을 활용한 Blue-Green 무중단 배포 구성 프로젝트입니다.
Spring Boot 애플리케이션을 Docker 컨테이너로 운영하며, Nginx가 트래픽을 Blue/Green 슬롯 간 전환합니다.

---

## 아키텍처 개요

```
GitHub Push
    │
    ▼
┌─────────┐    빌드 / 테스트 / SonarQube     ┌──────────────────────────────┐
│ Jenkins │ ─────────────────────────────► │  Docker Image (sw_team_7_spring) │
└─────────┘                                └──────────────────────────────┘
    │                                                      │
    │  deploy.sh                                           │ docker pull / recreate
    ▼                                                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Docker Host                              │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                   Nginx (:8620)                          │  │
│   │          upstream.conf → spring-blue OR spring-green     │  │
│   └──────────────┬─────────────────────┬─────────────────────┘  │
│                  │ (Active)             │ (Standby)              │
│      ┌───────────▼───────┐   ┌─────────▼─────────┐             │
│      │  Spring Blue       │   │  Spring Green      │             │
│      │  (:8630 → :8080)  │   │  (:8640 → :8080)  │             │
│      └───────────────────┘   └───────────────────┘             │
│                                                                 │
│                        MySQL DB                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Blue-Green 배포 흐름

무중단 배포의 핵심은 **현재 트래픽을 받는 Active 슬롯은 유지하고, Standby 슬롯에만 새 버전을 배포**한 뒤 헬스체크를 통과하면 트래픽을 전환하는 것입니다.

```
[현재 상태]
  Active  : spring-blue  ← 실 트래픽 수신 중
  Standby : spring-green ← 유휴 상태

      │
      ▼ 1. Standby(green) 컨테이너 중지

      │
      ▼ 2. 새 이미지로 Standby(green) 재시작

      │
      ▼ 3. /actuator/health 폴링 (최대 30초)

      │  헬스체크 실패 시 → green 중지 후 배포 중단
      │  헬스체크 통과 시
      ▼ 4. upstream.conf를 spring-green으로 교체 + nginx reload

[전환 완료]
  Active  : spring-green ← 실 트래픽 수신 중
  Standby : spring-blue  ← 다음 배포 시 대상
```

Nginx reload는 **graceful reload**이므로 기존 커넥션이 끊기지 않습니다.

---

## Jenkins 파이프라인 구성

아래는 이 프로젝트에 적용하는 Jenkinsfile 예시입니다.

```groovy
pipeline {
    agent any

    environment {
        IMAGE_NAME = "sw_team_7_spring"
        DEPLOY_DIR = "/home/sw_team_7/deployTest"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build & Test') {
            steps {
                dir('backend') {
                    sh './gradlew clean build'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                dir('backend') {
                    sh './gradlew sonar'
                }
            }
        }

        stage('Docker Image Build') {
            steps {
                sh "docker build -t ${IMAGE_NAME}:latest ./backend"
            }
        }

        stage('Blue-Green Deploy') {
            steps {
                sh "${DEPLOY_DIR}/scripts/deploy.sh"
            }
        }
    }

    post {
        failure {
            echo '배포 실패 - 트래픽은 기존 Active 슬롯에서 계속 처리됩니다.'
        }
    }
}
```

### 파이프라인 단계 설명

| Stage | 설명 |
|-------|------|
| Checkout | GitHub에서 소스 코드 체크아웃 |
| Build & Test | Gradle로 빌드 및 단위 테스트 실행 |
| SonarQube Analysis | 정적 코드 분석 (sonar.host.url: `172.20.0.3:9000`) |
| Docker Image Build | `sw_team_7_spring:latest` 이미지 빌드 |
| Blue-Green Deploy | `deploy.sh` 실행 → Standby 교체 → 헬스체크 → 트래픽 전환 |

---

## 프로젝트 구조

```
deployTest/
├── backend/                  # Spring Boot 애플리케이션
│   ├── src/
│   │   └── main/java/test/deploy/jenkins_sornar/
│   │       ├── controller/   # BoardController (REST API)
│   │       ├── service/      # BoardService
│   │       ├── entity/       # Board (JPA Entity)
│   │       ├── dto/          # BoardCreateRequest, BoardResponse
│   │       └── repository/   # BoardRepository
│   ├── Dockerfile
│   ├── init.sql              # DB 초기화 스크립트
│   └── build.gradle
├── nginx/
│   ├── conf.d/
│   │   ├── default.conf      # Nginx 서버 블록 (proxy_pass http://backend)
│   │   └── upstream.conf     # 현재 Active 슬롯 (배포 시 교체됨)
│   └── upstream/
│       ├── upstream_blue.conf   # spring-blue:8080
│       └── upstream_green.conf  # spring-green:8080
├── scripts/
│   ├── deploy.sh             # Blue-Green 배포 오케스트레이션
│   └── switch.sh             # Nginx upstream 교체 + reload
├── docker-compose.yml
└── .env                      # prod 환경 변수 (Git 미포함)
```

---

## 환경 설정

### 사전 요구사항

- Docker & Docker Compose
- Java 21
- Jenkins (권장: Docker로 운영)

### Docker 네트워크 생성 (최초 1회)

```bash
docker network create app-network
```

### `.env` 파일 작성 (서버에 직접 생성)

```env
SPRING_PROFILES_ACTIVE=prod
DB_HOST=<mysql_host>
DB_PORT=3306
DB_NAME=board_db
DB_USERNAME=<username>
DB_PASSWORD=<password>
SERVER_PORT=8080
```

### 포트 정보

| 서비스 | 호스트 포트 | 설명 |
|--------|-------------|------|
| Nginx | 8620 | 외부 트래픽 진입점 |
| Spring Blue | 8630 | Blue 슬롯 직접 접근 |
| Spring Green | 8640 | Green 슬롯 직접 접근 |

---

## 수동 실행

```bash
# 전체 스택 시작
docker-compose up -d

# Blue-Green 배포 수동 실행
./scripts/deploy.sh

# Nginx 트래픽만 수동 전환 (배포 없이)
./scripts/switch.sh

# 현재 Active 슬롯 확인
cat nginx/conf.d/upstream.conf

# 헬스체크
curl http://localhost:8620/health
curl http://localhost:8630/actuator/health  # blue 직접
curl http://localhost:8640/actuator/health  # green 직접
```

---

## API

Swagger UI: `http://<host>:8620/swagger-ui.html`

| Method | Path | 설명 |
|--------|------|------|
| POST | `/api/boards` | 게시글 생성 |
| GET | `/api/boards` | 게시글 목록 (페이징) |
| GET | `/api/boards/{id}` | 게시글 단건 조회 |

---

## 기술 스택

| 분류 | 기술 |
|------|------|
| Backend | Spring Boot 3.4.5, Java 21, JPA, Lombok |
| Database | MySQL |
| Infra | Docker, Docker Compose, Nginx |
| CI/CD | Jenkins, SonarQube |
