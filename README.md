# Monitoring Stack

- Spring Boot 서버를 모니터링하는 IaC 구성. (Prometheus + Loki + Grafana)
- 앱 서버의 Alloy가 로그는 Loki로, 메트릭은 Prometheus로 push. 이 서버에서 앱 서버로 접속하지 않음

---

## 빠른 시작

```bash
git clone https://github.com/내계정/내저장소.git
cd 내저장소
nano .env   # 선택 (아래 환경 변수 참고)
chmod +x install.sh
./install.sh
```

| 서비스        | URL (기본)          |
|------------|-------------------|
| Grafana    | http://홈서버IP:3000 |
| Prometheus | http://홈서버IP:9090 |
| Loki       | http://홈서버IP:3100 |

Grafana 기본 로그인: `admin` / `.env`의 `GRAFANA_ADMIN_PASSWORD`

---

## 환경 변수 (.env)

루트에 `.env` 생성. 없으면 기본값 적용.

| 변수                       | 기본값                     | 설명                     |
|--------------------------|-------------------------|------------------------|
| `GRAFANA_PORT`           | `3000`                  | Grafana 포트             |
| `GRAFANA_ADMIN_USER`     | `admin`                 |                        |
| `GRAFANA_ADMIN_PASSWORD` | `admin`                 | Grafana 비밀번호 (배포 시 변경) |
| `GRAFANA_ROOT_URL`       | `http://localhost:3000` |                        |
| `PROMETHEUS_PORT`        | `9090`                  |                        |
| `LOKI_PORT`              | `3100`                  |                        |

---

## 데이터 수신 (앱 서버 → 이 서버)

앱 서버의 Alloy 설정은 Renzzle_BE의 `alloy/config.alloy`.

| 데이터 | 앱 서버가 보내는 주소                                  | 받는 곳                         |
|-----|-----------------------------------------------|------------------------------|
| 로그  | `https://loki.kang-sm.dev/loki/api/v1/push`   | Loki                         |
| 메트릭 | `https://prometheus.kang-sm.dev/api/v1/write` | Prometheus (remote write 수신) |

둘 다 같은 Bearer 토큰(BE의 `LOKI_TOKEN`)을 보내고, 앞단 Nginx가 검사.

**Nginx: Prometheus remote write 수신**

```nginx
server {
    server_name prometheus.kang-sm.dev;
    # listen · ssl 설정은 Loki server 블록과 동일

    location = /api/v1/write {
        if ($http_authorization != "Bearer 여기에_LOKI_TOKEN과_동일한_값") {
            return 403;
        }
        client_max_body_size 10m;
        proxy_pass http://127.0.0.1:9090;
    }

    location / {
        return 404;
    }
}
```

---

## Spring Boot 설정 (모니터링 대상 서버)

메트릭 노출을 위해 Actuator + Micrometer Prometheus 추가. Alloy가 Docker 네트워크 안에서 `/actuator/prometheus`를 수집하므로 외부에 공개할 필요 없음.

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
