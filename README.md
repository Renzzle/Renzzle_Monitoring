# Renzzle Monitoring

Renzzle 백엔드의 로그와 메트릭을 수집하고 Grafana로 보여 주는 모니터링 서버 구성이다. Prometheus, Loki, Grafana를 Docker Compose로 실행하며, Grafana의 데이터소스와 대시보드도 이 레포에서 관리한다.

대시보드 읽는 법과 지표 정의는 [docs/metrics-guide.md](docs/metrics-guide.md)에 있다.

## 구성

```
App server (Renzzle_BE)                  Monitoring server (this repo)

Spring Boot ─▶ Alloy ─┬─ logs ─────▶ Nginx ─▶ Loki ──────────┐
                      └─ metrics ──▶ Nginx ─▶ Prometheus ────┴─▶ Grafana
```

- 앱 서버의 Alloy가 로그와 메트릭을 이 서버로 보낸다(push). 이 서버는 앱 서버에 접속하지 않는다.
- 두 요청 모두 Bearer 토큰을 보내고, 앞단 Nginx가 토큰을 검사한다.

```
docker-compose.yml        스택 정의 (이미지 버전 고정)
install.sh                Docker 설치와 스택 실행
loki/                     Loki 설정
prometheus/               Prometheus 설정
grafana/provisioning/     데이터소스·대시보드 자동 등록 설정
grafana/dashboards/       대시보드 JSON
docs/metrics-guide.md     대시보드·지표 가이드
```

## 설치

```bash
git clone https://github.com/Renzzle/Renzzle_Monitoring.git
cd Renzzle_Monitoring
vi .env          # 선택. 아래 환경 변수 참고
./install.sh
```

Docker가 없으면 `install.sh`가 Docker만 설치하고 끝난다. 이때는 `newgrp docker`를 실행한 뒤 `./install.sh`를 한 번 더 실행한다.

| 서비스 | 주소 |
|---|---|
| Grafana | `http://<서버 IP>:3000` |
| Prometheus | `http://<서버 IP>:9090` |
| Loki | `http://<서버 IP>:3100` |

Grafana 계정은 `admin`과 `.env`의 `GRAFANA_ADMIN_PASSWORD`다.

## 업데이트

```bash
git pull
docker compose up -d
```

| 바뀐 파일 | 반영 방법 |
|---|---|
| `grafana/dashboards/*.json` | 자동 반영 (1분 이내) |
| `loki/`, `prometheus/` 설정 | `docker compose restart loki` 또는 `prometheus` |
| `docker-compose.yml` | `docker compose up -d` |

이미지 버전은 `docker-compose.yml`에 고정돼 있다. `latest`를 쓰면 서버에 이미 받아 둔 이미지가 계속 쓰이기 때문이다. 버전을 올릴 때는 태그를 바꾸고 `docker compose up -d`를 실행한다.

## 환경 변수

`.env` 파일은 선택이다. 없으면 기본값을 쓴다.

| 변수 | 기본값 | 설명 |
|---|---|---|
| `GRAFANA_PORT` | `3000` | Grafana 포트 |
| `GRAFANA_ADMIN_USER` | `admin` | Grafana 관리자 계정 |
| `GRAFANA_ADMIN_PASSWORD` | `admin` | Grafana 관리자 비밀번호. 배포 전에 반드시 바꾼다 |
| `GRAFANA_ROOT_URL` | `http://localhost:3000` | Grafana 외부 주소 |
| `PROMETHEUS_PORT` | `9090` | Prometheus 포트 |
| `LOKI_PORT` | `3100` | Loki 포트 |

## 데이터 보관

| 데이터 | 기간 | 설정 |
|---|---|---|
| 로그 (Loki) | 90일 | `loki/loki-config.yml`의 `retention_period` |
| 메트릭 (Prometheus) | 90일 | `docker-compose.yml`의 `--storage.tsdb.retention.time` |

MAU 추이나 결제 내역처럼 로그로 계산하는 지표는 90일 전까지만 조회할 수 있다.

## 데이터 수신

앱 서버의 Alloy 설정은 Renzzle_BE의 `alloy/config.alloy`에 있다.

| 데이터 | 앱 서버가 보내는 주소 | 받는 곳 |
|---|---|---|
| 로그 | `https://loki.kang-sm.dev/loki/api/v1/push` | Loki |
| 메트릭 | `https://prometheus.kang-sm.dev/api/v1/write` | Prometheus (remote write) |

두 요청 모두 BE의 `LOKI_TOKEN`을 Bearer 토큰으로 보낸다. Prometheus 쪽 Nginx 설정은 다음과 같다. `listen`과 SSL 설정은 Loki 블록과 같다.

```nginx
server {
    server_name prometheus.kang-sm.dev;

    location = /api/v1/write {
        if ($http_authorization != "Bearer <LOKI_TOKEN>") {
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

## 앱 서버 설정 (Renzzle_BE)

메트릭은 Actuator와 Micrometer Prometheus 레지스트리로 노출한다. Alloy가 Docker 네트워크 안에서 `/actuator/prometheus`를 수집하므로 외부에 공개하지 않는다.

```kotlin
implementation("org.springframework.boot:spring-boot-starter-actuator")
implementation("io.micrometer:micrometer-registry-prometheus")
```

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  endpoint:
    prometheus:
      enabled: true
  metrics:
    distribution:
      slo:
        "[http.server.requests]": 50ms,100ms,200ms,300ms,500ms,1s,2s,5s
```

`slo` 설정은 API 응답 시간을 구간별로 집계한다. 서버 상태 대시보드의 p95 응답 시간이 이 값으로 계산되며, 없으면 평균과 최대만 표시된다.

서비스 대시보드는 BE 로그를 파싱해서 계산한다. 아래 형식이 바뀌면 대시보드 쿼리도 함께 고쳐야 한다.

- `logback-spring.xml`의 로그 패턴: `[traceId] [user=ID] LEVEL logger - message`
- `RequestLoggingFilter`의 접근 로그: `METHOD path status=200 12ms route=/api/...`
- 결제·랭크 이벤트 로그 문구: `In-app purchase granted.`, `Rank game ended.` 등

## Grafana

Grafana는 시작할 때 `grafana/provisioning/`을 읽어 데이터소스와 대시보드를 등록한다. 화면에서 따로 추가할 것은 없다.

| 폴더 | 대시보드 |
|---|---|
| 서비스 분석 | 서비스 현황 (홈), 결제, 유저 추적 |
| 서버 상태 | 서버 상태 |

데이터소스는 `prometheus`(`http://prometheus:9090`)와 `loki`(`http://loki:3100`)다. 같은 이름의 데이터소스가 이미 있으면 새로 만들지 않고 기존 것을 이어서 쓴다. UID가 그대로라 예전에 가져온 대시보드도 계속 동작한다. 이름이 다르면(예: `Prometheus`) 데이터소스가 하나씩 더 생긴다. 새 대시보드는 어느 쪽이든 동작하므로, 예전 대시보드를 쓰지 않게 되면 옛 데이터소스를 지운다. 기존 이름은 다음 명령으로 확인한다.

```bash
curl -s -u admin:<비밀번호> http://localhost:3000/api/datasources
```

대시보드를 Grafana 화면에서 고치면 재시작할 때 파일 내용으로 돌아간다. 수정 방법은 [가이드의 대시보드 수정](docs/metrics-guide.md#대시보드-수정)을 따른다.
