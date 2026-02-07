# 모니터링 스택 (Prometheus + Loki + Grafana)

다른 인스턴스의 Spring Boot 서버를 홈서버 한 대에서 모니터링하는 IaC 구성.

---

## 빠른 시작

```bash
git clone https://github.com/내계정/내저장소.git
cd 내저장소
nano .env   # APP_SERVER_IP 설정 (아래 환경 변수 참고)
chmod +x install.sh
./install.sh
```

| 서비스     | URL (기본)              |
|-----------|--------------------------|
| Grafana   | http://홈서버IP:3000     |
| Prometheus| http://홈서버IP:9090     |
| Loki      | http://홈서버IP:3100     |

Grafana 기본 로그인: `admin` / `.env`의 `GRAFANA_ADMIN_PASSWORD`

---

## 환경 변수 (.env)

루트에 `.env` 생성. 없으면 기본값 적용.

| 변수 | 필수 | 기본값 | 설명 |
|------|:----:|--------|------|
| `APP_SERVER_IP` | ✅ | — | 스크래핑할 Spring 서버 IP/호스트 |
| `APP_SERVER_PORT` | | `8080` | Spring 앱 포트 |
| `GRAFANA_PORT` | | `3000` | Grafana 포트 |
| `GRAFANA_ADMIN_PASSWORD` | | `admin` | Grafana 비밀번호 (배포 시 변경) |
| `PROMETHEUS_PORT` | | `9090` | |
| `LOKI_PORT` | | `3100` | |
| `GRAFANA_ADMIN_USER` | | `admin` | |
| `GRAFANA_ROOT_URL` | | `http://localhost:3000` | |

---

## Spring Boot 설정 (모니터링 대상)

메트릭 수집을 위해 Actuator + Micrometer Prometheus 추가.

**의존성 (Gradle)**

```kotlin
implementation("org.springframework.boot:spring-boot-starter-actuator")
implementation("io.micrometer:micrometer-registry-prometheus")
```

**application.yml**

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  endpoint:
    prometheus:
      enabled: true
```

---

## Grafana 데이터소스 설정

Connections → Data sources → Add:

- **Prometheus**: `http://prometheus:9090`
- **Loki**: `http://loki:3100`

---

## 참고

- Docker 미설치 시 `install.sh`가 Docker 설치 후 안내 메시지 출력. `newgrp docker` 후 스크립트 재실행.
- 데이터는 Docker 볼륨에 저장되어 컨테이너 재생성 후에도 유지됨.
- Loki 로그 수집: Spring 서버에 Promtail 설치하거나 Logback Loki Appender 사용 → `http://홈서버IP:3100/loki/api/v1/push`
