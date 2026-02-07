# Monitoring Stack

- Spring Boot 서버를 모니터링하는 IaC 구성. (Prometheus + Loki + Grafana)

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
| `SCRAPE_TOKEN` | | — | Bearer 토큰. 대상 서버 Nginx에서 `/actuator/` 접근 시 이 값과 일치할 때만 허용 |
| `GRAFANA_PORT` | | `3000` | Grafana 포트 |
| `GRAFANA_ADMIN_PASSWORD` | | `admin` | Grafana 비밀번호 (배포 시 변경) |
| `PROMETHEUS_PORT` | | `9090` | |
| `LOKI_PORT` | | `3100` | |
| `GRAFANA_ADMIN_USER` | | `admin` | |
| `GRAFANA_ROOT_URL` | | `http://localhost:3000` | |

---

## Spring Boot 설정 (모니터링 대상 서버)

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

**Nginx에서 `/actuator/` 보호 (선택)**  
`.env`의 `SCRAPE_TOKEN`과 동일한 값을 Nginx에서 검사하여 보안 강화

```nginx
location /actuator/ {
    if ($http_authorization != "Bearer 여기에_SCRAPE_TOKEN_과_동일한_값") {
        return 403;
    }
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

---

## Grafana 데이터소스 설정

Connections → Data sources → Add:

- **Prometheus**: `http://prometheus:9090`
- **Loki**: `http://loki:3100`
