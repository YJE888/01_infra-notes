# S3 Transfer Acceleration
- S3 버킷과 나 사이의 전송 속도를 AWS 글로벌 네트워크로 가속화 (업로드/다운로드 가속)
- 사용자가 가까운 엣지 로케이션으로 업로드하면, AWS 백본 네트워크를 통해 S3 버킷 리전에 빠르게 전달(HTTP 기반)

# AWS Global Accelerator
- 애플리케이션 엔드포인트 대상(ALB, NLB, EC2, Elastic IP, CloudFront 등)
- Anycast IP 제공 (고정 글로벌 IP)
- 사용자가 가까운 AWS 엣지 로케이션에 접속 → AWS 글로벌 네트워크를 타고 최적의 리전 엔드포인트로 라우팅
- <u>TCP/UDP 레벨(L4 Layer)</u>에서 지연시간 최적화, 장애 시 헬스체크 기반 페일오버 제공
- 다국적 사용자에게 동적 웹 애플리케이션(게임 서버, API 서버 등)을 빠르게 제공
- 비정상 리전 자동으로 제외하는 헬스체크 지원
- TCP, UDP, HTTP/HTTPS 전부 가능

# CloudFront
- S3나 EC2 같은 원본 콘텐츠를 전 세계 POP에 캐싱해서, 사용자에게 가까운 위치에서 배포 (주로 다운로드/컨텐츠 전달 최적화) -> CDN
- Amazon S3 Bucket, ALB, EC2, AWS Media Services, AWS API Gateway, Lambda 등
- HTTPS/TLS, WAF와 연계해 보안 강화 가능
- CloudFront는 전 세계 300개 이상의 엣지 로케이션에서 트래픽을 먼저 수용
    - 공격을 전 세계로 분산해 흡수
    - 캐싱을 통해 원본 서버 보호
- 원본의 개별 인스턴스의 헬스체크를 하지 않음
- 한 리전의 원본만 지정 가능
- <u>정적/캐시 가능 리소스용, 동적 API 캐싱 불가</u>

### CloudFront Cache
- 웹 콘텐츠를 전 세계 사용자에게 더 빠르게 전달하기 위해 데이터를 임시로 저장해두는 시스템


| 항목                     | CloudFront           | Global Accelerator       |
| ---------------------- | -------------------- | ------------------------ |
| 주요 용도                  | 정적/동적 웹 콘텐츠 전송 (CDN) | 글로벌 TCP/UDP 트래픽 가속 및 라우팅 |
| L7 (HTTP 기반)           | V                    | V                        |
| L4 (TCP/UDP 기반)        | X                    | V                        |
| 여러 리전 간 헬스 기반 라우팅      | X                    | V                        |
| 실시간 트래픽 (게임, 음성, 금융 등) | X                    | V                        |
| 콘텐츠 캐싱                 | V                    | X                        |

### 서명된 쿠키 (Signed Cookies)
- CloudFront에서 제공하는 접근 제어 방식 중 하나
- <u>특정 사용자 집합</u>에만 CloudFront 콘텐츠(비디오 등)를 전달할 수 있음
- 하드코딩된 URL을 바꾸지 않아도 됨! (쿠키를 이용하므로 URL 그대로 유지)
- 다만, 쿠키를 지원하지 않는 클라이언트에서는 동작하지 않음 → 일부 사용자 불가
- S3 원본은 OAC(OAI)로 보호하고, CloudFront를 통해서만 접근 가능

### 서명된 URL (Signed URL)
- <u>특정 사용자 집햅</u>에만 CloudFront 콘텐츠 전달
- 동일한 접근 제어 목적이지만, URL에 서명 정보를 포함
- 쿠키 미지원 환경에서도 동작 (URL로 직접 인증 정보 전달)
- 단점: URL이 변경되어야 함
- 하지만 “일부 사용자”만 변경하면 되므로, 전체 사용자 영향은 최소화됨
- S3 원본은 OAC(OAI)로 보호하고, CloudFront를 통해서만 접근 가능
```css
           ┌─────────────────────────────┐
           │      Amazon CloudFront      │
           │  (Signed URL / Signed Cookie) │
           └──────────┬──────────────────┘
                      │
       ┌──────────────┴──────────────┐
       │                             │
 [쿠키 지원 클라이언트]       [쿠키 미지원 클라이언트]
 (서명된 쿠키 방식)             (서명된 URL 방식)
                      │
                      ▼
           [Amazon S3 (원본)]
           - Origin Access Control(OAC)
           - CloudFront 외 접근 차단
```

# Amazon Athena
- S3의 데이터를 서버리스 SQL(Presto/Trino 기반)로 질의
- AWS Glue Data Catalog 스키마를 사용
- 태그/메타데이터 기반 검색 가능
- 실시간 스트리밍 쿼리 불가(정척 데이터 분석)

# Application Insights + OpsItems
- Application Insights 는 애플리케이션 성능/오류 모니터링용

# Amazon CloudWatch
- AWS에서 제공하는 모니터링 & 관찰(Observability) 서비스
- AWS 리소스, 애플리케이션, 온프레미스 시스템의 메트릭, 로그, 이벤트, 알람을 수집하고 시각화하여 운영 상태를 추적
- 복합 경보(Composite Alarm)는 여러 CloudWatch 지표나 경보를 조합해 둘 다 만족할 때만 알림을 발생시킴 -> 허위 경보를 줄이고, 조건을 정밀하게 제어 가능

### CloudWatch 단일 경보
- 대상: 단일 지표 (예: CPUUtilization, DiskReadOps)
- 조건: 지정한 임계치 초과/미만 여부
- 사용 사례
    - CPU 사용률이 80% 이상일 때 알림
    - 디스크 쓰기 IOPS가 10,000 이상일 때 알림
- 제한: 여러 지표를 동시에 고려할 수 없음 → 허위 경보 발생 가능

### CloudWatch 복합 경보 (Composite Alarm)
- 대상: 여러 개의 단일 경보를 조합 (AND / OR 논리)
- 조건: 복수 지표 조건이 동시에 만족될 때만 알림
- 사용 사례
    - CPU 사용률이 80% 이상 AND 디스크 읽기 IOPS가 5,000 이상일 때 알림
    - CPU 사용률이 90% 이상 OR 메모리 사용률이 90% 이상일 때 알림
- 장점:
    - 허위 경보(노이즈) 줄임
    - 실제 장애 가능성이 높은 상황에만 알림

### Amazon CloudWatch Logs & Logs Insights
- 애플리케이션/시스템 로그의 수집·보관·검색/시각화
- 전용 쿼리 언어, 알람/모니터링에 강점

### CloudWatch Metrics (지표 수집)
- EC2 CPU 사용률, RDS 연결 수, Lambda 호출 횟수 등 리소스 지표를 자동 수집
- 커스텀 메트릭도 애플리케이션에서 직접 전송 가능
- 대시보드에서 그래프화
- `Backlog per instance` = “인스턴스 한 대가 떠안은 대기 작업량”
    - 이 값을 기준으로 오토스케일링하면 실제 업무량에 맞게 똑똑하게 확장/축소할 수 있음
- CloudWatch Logs Metric Filter 생성
    - 로그에서 SSH(22/TCP), RDP(3389/TCP) 패턴을 감지
    ```ini
    [version, account, interfaceid, srcaddr, dstaddr, srcport, dstport, protocol, packets, bytes, start, end, action, logstatus]
    dstport = 22 || dstport = 3389
    ```

### CloudWatch Target Tracking Policy(대상 추적 정책)
- 목표 사용률을 정해놓는 것
- **CPU 목표 = 60%**로 설정하면,
    - CPU가 60% 이상 → Task 늘림
    - CPU가 60% 이하 → Task 줄임

### CloudWatch Alarms (알람)
- 특정 메트릭 임계값 초과 시 알람 발생
- Amazon SNS, Auto Scaling, Systems Manager와 연동해 자동 대응 가능
- Metric Filter에서 트리거된 지표에 기반해 ALARM 상태 시 SNS 주제 알림 전송

### CloudWatch Events / EventBridge
- 리소스 상태 변화(예: EC2 인스턴스 상태 변경, S3 객체 업로드 이벤트)를 감지
- 다른 서비스(Lambda, Step Functions, SNS, SQS 등)와 연계해 자동 처리 가능
- 최근에는 EventBridge로 발전하여 SaaS 애플리케이션 이벤트까지 통합 지원
- 이벤트 소스(AWS/SaaS/Custom)에서 발생한 이벤트를 필터링하고, 다양한 AWS 서비스(Target)으로 라우팅하는 이벤트 버스 플랫폼
- 사용 예시
    - 매일 특정 시간에 RDS/EC2 인스턴스 자동 시작·중지 (스케줄 이벤트 → Lambda → Start/Stop API)
    - S3 버킷에 파일 업로드 이벤트 → Lambda 호출 → ETL 처리 → DynamoDB 저장
    - SaaS 애플리케이션(Zendesk 티켓 생성) → EventBridge → SNS → Slack 알림
1. 이벤트 수집
- AWS 서비스 이벤트 (S3, EC2, RDS, DynamoDB 등)
- 사용자 정의 이벤트 (앱/마이크로서비스에서 Publish)
- SaaS 파트너 서비스 이벤트 (Zendesk, PagerDuty, Datadog 등)

2. 이벤트 필터링 & 라우팅
- 이벤트 패턴(조건)에 따라 특정 대상(Target)으로 이벤트 전달
- 예: "source": "aws.rds", "detail-type": "RDS DB Instance State Change" → Lambda로 전달

3. 이벤트 전송 (Target)
- Lambda, Step Functions, SQS, SNS, Kinesis, ECS, API Gateway, CodePipeline 등 다양한 AWS 서비스로 전달 가능

4. 스케줄링 기능
- Cron 표현식, Rate 표현식으로 주기적인 작업 예약 (예: 매일 9시 Lambda 실행)
- 기존 CloudWatch Events의 기능이 EventBridge로 통합


### CloudWatch Dashboards
- 모니터링할 메트릭을 한눈에 볼 수 있는 시각화 대시보드
- 여러 AWS 계정/리전을 통합 모니터링 가능

### CloudWatch Contributor Insights & Anomaly Detection
- 이상 탐지(비정상적인 트래픽, 지표 변동 자동 탐지)
- 주요 트래픽 소스 기여자 분석
# AWS Step Functions
- 여러 작업을 순서/분기/병렬로 이어주는 서버리스 워크플로 오케스트레이터
- 조건 분기, 병렬 처리, 재시도/백오프, 에러 처리(Catch), 타임아웃, 대기(Wait)
# Amazon Redshift
- 페타바이트급 데이터 웨어하우스
- 고성능 집계/BI에 적합하나 적재/관리 필요
- S3/Firehose와 연계해 BI 분석(SQL 기반) 수행
    - 실시간 분석 불가, 지연 발생
- 클릭스트림, 로그, 매출 분석 등 대규모 쿼리 최적화

# AWS Glue
- 서버리스 데이터 통합 카탈로그/크롤러/ETL(Extract, Transform, Load) 서버리스 서비스
- 스키마 추출·정제·포맷 변환(예: JSON→Parquet)에 적합
- 대규모 데이터셋을 추출(Extract), 변환(Transform), 적재(Load)하는 과정을 자동화/간소화하는 데 사용
- AWS Glue는 데이터 파이프라인에서 대규모 데이터를 자동으로 수집/정제/분석용으로 변환하는 서비스

### AWS Glue Job Bookmark
- Glue 작업에서 "데이터 소스의 처리 상태"를 추적하는 기능
- 이전 실행에서 *처리한 데이터를 기억*하고, 다음 실행 시 *새 데이터만 처리*
- 주로 S3, JDBC 소스에서 많이 사용

# AWS Organizations 범위(스코프)
```kotlin
조직(Organization) ──> 조직 단위(OU, Organizational Unit) ──> 계정(Account) ──> IAM 사용자/역할
```
### 조직(Organization)
- 최상위 개념
- 조직 전체에 걸쳐 여러 OU와 계정을 포함
- 식별자는 o-xxxxxxx 형태의 Organization ID
- 하나의 Organization에는 수십~수천 개 계정이 속할 수 있음

### 조직 단위(OU)
- 계정을 그룹핑하는 하위 단위
- 트리 구조(OU 안에 또 다른 OU 가능)
- 특정 정책(SCP)을 OU 단위로 적용할 수 있음
- 식별자는 ou-xxxx-yyyyyyyy 형태의 OU ID
- OU는 결국 "조직의 부분집합"

### AWS Organizations + SCP(Service Control Policy)
- 계정 단위 권한 제어
- 특정 리전 서비스 사용 차단 가능
- 중앙에서 여러 계정을 관리 가능

# VPC 엔드포인트
### Gateway Endpoint
- S3, DynamoDB 전용
- 라우팅 테이블에 엔드포인트를 추가해 내부 네트워크로 접근 가능
- 라우팅 테이블(Route Table)에 엔드포인트를 등록해서, 해당 서비스로 가는 트래픽이 <u>인터넷 게이트웨이 대신 AWS 내부 네트워크</u>로 가도록 설정
- ENI(Elastic Network Interface)를 만들지 않음 → 비용 없음
- 단순하고 저렴

### Interface Endpoint (PrivateLink 기반)
- 대부분의 AWS 서비스 (SNS, SQS, KMS, API Gateway, SSM 등)
- 사실상 거의 모든 AWS 서비스 접근 가능
- 특정 서비스 엔드포인트만 프라이빗 연결
- VPC 서브넷 안에 ENI를 만들어 서비스와 연결
- 시간당 ENI 비용 + 데이터 처리 비용 발생
- Security Group 적용 가능

# VPC Peering
- VPC 전체를 연결
- 보안제약(특정 서비스만을 제한) 불가

| 항목           | **VPC Peering**             | **AWS PrivateLink**             | **VPN (Site-to-Site)**       |
| ------------ | --------------------------- | ------------------------------- | ---------------------------- |
| **연결 범위**    | VPC ↔ VPC 전체 CIDR 연결        | 특정 서비스(NLB 뒤 서비스)만 연결           | 온프레미스 ↔ AWS VPC 연결           |
| **트래픽 경로**   | AWS 백본 네트워크                 | AWS 백본 네트워크                     | 인터넷(IPSec) or Direct Connect |
| **보안성**      | 프라이빗 (AWS 내부)               | 프라이빗 (AWS 내부)                   | 암호화된 터널(IPSec)               |
| **제어 단위**    | 전체 VPC 간 라우팅                | **서비스 단위 (엔드포인트별)**             | 전체 네트워크 (온프레 ↔ VPC)          |
| **라우팅 필요**   | Yes (CIDR 기반 라우트 추가)        | No (엔드포인트가 ENI처럼 보임)            | Yes (온프레 라우팅 필요)             |
| **주요 사용 사례** | 내부 팀 간 VPC 공유, 같은 회사 VPC 통신 | SaaS 제공자 서비스 연결, 특정 서비스 프라이빗 접속 | 온프레 네트워크 ↔ AWS 보안 연결         |
| **운영 오버헤드**  | 중간                          | 낮음 (엔드포인트만 생성)                  | 중간~높음 (VPN 관리 필요)            |
| **제한 사항**    | 중복 CIDR 불가                  | 공급자가 **NLB** 사용해야 함             | 인터넷 품질/지연 영향 받음              |

# VPC Flow Logs
- VPC/Subnet/ENI 수준에서 트래픽(소스/목적 IP, 포트, 프로토콜)을 CloudWatch Logs로 전송

# API Gateway
- 서버리스 API 관리 서비스
- API(애플리케이션 인터페이스) 를 만들어 외부/내부 클라이언트가 호출할 수 있게 해주는 서비스
```
클라이언트 → API Gateway → Lambda/EC2/다른 서비스 호출
```
- 즉, API Gateway는 S3와 직접 연결하는 용도가 아님

### 1. API 생성 및 배포
- REST API, HTTP API, WebSocket API 지원
- 클라이언트가 HTTPS 요청으로 호출할 수 있는 엔드포인트 자동 제공

### 2. 백엔드 연동
- AWS Lambda, EC2, ECS, DynamoDB, S3 등과 연동 가능
- 예: GET /items → Lambda 함수 호출 → DynamoDB 조회

### 3. API 관리
- 인증/인가 (IAM, Cognito, Lambda Authorizer 등)
- 트래픽 제어 (rate limiting, throttling)
- 로깅 및 모니터링 (CloudWatch Logs, X-Ray)

### 4. Private API
- VPC Endpoint (PrivateLink)와 연동해서 API를 VPC 내부에서만 호출 가능하게 구성 가능

### API Gateway + PrivateLink는 언제 쓰는가?
- 내부 비즈니스 API를 사내망에서만 호출하고 싶을 때
- 회사 내부 서비스 → API Gateway (Private) → 내부 Lambda/EC2 호출
- 외부 노출 없이 내부망 API 형태로 제공

# S3 File Gateway
- AWS Storage Gateway 서비스의 한 모드
- 온프레미스 환경(데이터센터, 사무실 서버 등)에서 S3 File Gateway를 배포하여 S3를 파일 스토리지처럼 사용할 수 있게 해주는 가상 어플라이언스
- 로컬에서 NFS(Network File System) 또는 SMB(Server Message Block) 프로토콜로 접근 가능
- 데이터를 저장하면 실제로는 Amazon S3 버킷에 객체(Object) 형태로 저장됨

# AWS Storage Gateway
- Storage Gateway는 온프레미스 ↔ AWS 스토리지 연결 솔루션 (캐시/백업/아카이브 용도)
- 파일/볼륨/테이프 게이트웨이 형태 제공

# AWS Direct Connect
- 온프레미스 데이터센터 ↔ AWS 간 전용 네트워크 회선을 제공하는 서비스
- <u>인터넷을 거치지 않고, 전용선으로 AWS와 직접 연결</u>
- 인터넷을 거치지 않으므로 데이터 전송 중 보안 위험 줄어듦
- 초기 구축/계약이 필요하기 때문에 단기간 마이그레이션보다는 장기 연결에 적합

# AWS Site-to-Site VPN
- 온프레미스 ↔ AWS 간 인터넷 기반 IPSec 터널
- 저렴하지만 인터넷을 사용하므로 가끔 지연이 발생할 수 있음
- Direct Connect의 백업 연결로 자주 활용

# AWS DataSync
- 온프레미스 ↔ AWS 스토리지 간 데이터 이동 자동화
- 지원 대상: S3, EFS, FSx, NFS, SMB
- 특징: 증분 전송, 병렬 업로드, 네트워크 최적화, 암호화
- DataSync Agent를 온프레미스에 설치해 네트워크를 통해 전송
- 전송 간 <u>대역폭 제어 가능</u> - 설정으로 다른 트래픽에 영향을 주지 않음

# Amazon EFS(Elastic File System)
- EFS는 NFS 프로토콜 기반의 Linux 공유 파일시스템
- Lustre를 지원하지 않음

# AWS DMS (Database Migration Service)
- 관계형 DB, NoSQL, 데이터 웨어하우스 간 마이그레이션 서비스
- 파일(JSON, CSV 등)을 S3에 로드 가능하긴 하지만, 대규모 파일 전송용으로는 비효율적
- 온프레미스 DB → AWS DB, AWS DB → AWS DB, 혹은 클라우드 DB → 온프레 DB 등 다양한 조합을 지원
- 데이터 이동 중에 원본 데이터베이스는 계속 운영 가능 → 다운타임 최소화
- 동종 마이그레이션(예: Oracle → Oracle)과 이기종 마이그레이션(예: Oracle → Aurora, SQL Server → MySQL 등) 모두 지원

# Amazon SQS (Simple Queue Service)
- 완전관리형 메시지 큐 서비스
- 생산자(Producer)가 큐에 메시지를 넣으면, 소비자(Consumer)가 메시지를 꺼내서 처리
- 버퍼 역할: 메시지를 큐에 저장 → 처리할 때까지 보존
- 확장성: 초당 수십만 건 메시지도 처리 가능
- 신뢰성: 메시지 보존 가능(최대 14일)
- 기본은 At-least-once 전달 (중복 가능 → idempotent 처리 권장)
- 생산자/소비자 분리(Decoupling)하거나, 갑작스러운 트래픽 폭주 시 버퍼링, 안정적으로 워크로드를 처리할 때 사용
- 비동기 처리 및 버퍼 역할
- Lambda와 네이티브 통합 → 메시지가 많아지면 Lambda 자동 병렬 실행
- 내구성과 확장성이 뛰어남
- At-least-once delivery 보장 → 최소 한 번은 전달하지만, 같은 메시지가 두 번 전달될 수도 있음
- 메시지가 처리되는 동안 다른 소비자가 동일 메시지를 가져가지 않도록 하는 기능이 있음 → Visibility Timeout
- Standard Queue: 무제한 처리량, 순서 보장 없음
- FIFO Queue: 순서 보장 + 중복 제거 → 데이터 유실·중복 방지

### Visibility Timeout
- 한 Consumer(예: EC2 인스턴스)가 메시지를 가져가면, 일정 시간 동안 그 메시지를 다른 Consumer가 보지 못하게 숨김
- 이 시간이 지나기 전에 메시지가 삭제되지 않으면, 메시지는 다시 다른 Consumer에게 전달될 수 있음
- Visibility Timeout을 너무 짧게 설정하면, 처리 중인데 아직 삭제되지 않은 메시지가 다른 인스턴스에 재전달 → 중복 처리 발생

### 관련 API
- CreateQueue
    - 새 큐 생성
- AddPermission
    - 큐에 권한 추가
- ReceiveMessage
    - 메시지 가져오기, WaitTimeSeconds(롱 폴링 설정 가능)
- ChangeMessageVisibility
    - 메시지의 Visibility Timeout 수정

# Amazon SNS (Simple Notification Service)
- 퍼블리시/서브스크라이브(Pub/Sub, 발행/구독) 모델의 메시지 브로커 서비스
- 한 곳(SNS 주제, Topic)에 메시지를 발행(Publish)하면, 여러 구독자(Subscriber)에게 동시에 전달됨
- 한 이벤트를 여러 구독자(subscriber)에게 동시에 전파(fan-out) 가능
- 구독자는 SQS, Lambda, HTTP 엔드포인트, 이메일,SMS 등 다양
메시지 필터링 기능 제공 (구독자별로 특정 조건 메시지만 받게 가능)
- 이벤트/알림 브로드캐스팅 할 때 사용하거나 한 이벤트를 여러 마이크로서비스가 동시에 처리해야 할 때 사용

### SNS FIFO Topic
- 일반적으로 SNS(Standard topic) 은 메시지를 매우 빠르게 전달
    - 중복이 발생할 수 있음
- FIFO Topic은 순서를 보장하고, 중복을 방지함

# Amazon Kinesis Data Streams
- 대규모 실시간 스트리밍 데이터 수집 서비스
- 데이터를 샤드(Shard)에 분산 저장하고, 여러 소비자가 동시에 읽을 수 있음(확장성)
- 샤드 단위로 확장: 샤드를 늘리면 처리량 증가
- 초당 수십만 건 이벤트 수집 가능
- 실시간 분석이나 이벤트 처리에 적합
- 로그, IoT 센서 데이터, 클릭스트림 등 실시간 데이터 수집/처리와 실시간 대시보드, 보안 분석, Fraud detection에 사용

# Amazon Kinesis Data Analytics
- Kinesis Data Streams나 Firehose에서 들어오는 데이터를 실시간 분석하는 서비스
- SQL, Apache Flink를 사용해 스트리밍 데이터를 변환/집계
- SQL 기반이라 쉬움 (예: 1분 단위 평균, Top N 계산)
- Flink 기반 고급 스트리밍 처리도 가능
- 실시간 로그 분석 (예: 초당 평균 요청 수, 에러율 계산)이나  실시간 이상 탐지, 알림 트리거에 사용
- Kinesis Data Analytics는 실시간 데이터 분석(SQL, Flink 기반) 서비스로 메시지 소비(소비자 확장성, fan-out)와 직접 관련 없음

# Amazon Kinesis Data Firehose
- 스트리밍 데이터 수집 → 변환 → 적재를 자동화해주는 완전 관리형 서비스
- Firehose는 데이터를 전달할 때 **TLS(HTTPS)** 를 사용해서 암호화를 보장
    - Firehose는 내부 버퍼링 중인 임시 저장 스토리지에 대해 KMS 기반 암호화를 사용
    - Firehose 내부 처리 중인 데이터는 암호화된 상태로 유지
- 실시간 스트리밍 데이터(로그, 이벤트 등)를 받아서 S3, Redshift, OpenSearch, Splunk 등으로 전송
- 운영자가 서버나 클러스터를 직접 관리할 필요 없음 → Data Streams보다 관리가 단순
- 초 단위(약간의 지연)로 배치 전송하는 구조라 “근실시간(near real-time)” 이라고 표현
- 지원 대상
    - Amazon S3 (Data Lake 구축용)
    - Amazon Redshift (분석 DB)
    - Amazon OpenSearch Service (로그 검색/분석)
    - Splunk (모니터링 툴)
    - HTTP endpoint
# GuardDuty
- 계정·네트워크·S3 로그 기반 위협 탐지/알림
- 패킷 필터링/차단 기능이 없음 → 탐지 알림은 주지만 트래픽을 막지 못함

# AWS Firewall Manager
- 정책 중앙 관리/배포(WAF, Network Firewall, SG 등)
- 실제 필터링은 해당 서비스가 수행

### AWS Network Firewall
- VPC 네트워크 경계 보안(상태 저장/IPS/DNS 필터링)
- 인라인 차단 가능

# AWS Shield
- AWS가 제공하는 DDoS(Distributed Denial of Service) 방어 서비스
- 두 가지 버전이 있음

### AWS Shield Standard
- 무료
- 모든 AWS 고객에게 자동 적용
- L3/L4 (네트워크/전송 계층) 수준의 일반적인 DDoS 공격 방어

### AWS Shield Advanced
- 유료 (월 $3,000 이상)
- 더 정교하고 대규모 공격에 대한 보호 제공
- 고급 DDoS 방어
    - L3/L4 뿐 아니라, L7 (애플리케이션 계층) 공격까지 방어
    - AWS의 글로벌 DDoS 대응 팀(DDOS Response Team, DRT)이 지원
    - 공격 시 24/7 전문가 핫라인 연결 가능
- 보호 대상 리소스
    - Amazon CloudFront
    - Route 53
    - Global Accelerator
    - Elastic IP (EC2, ELB 등 연결된 경우)

# IAM (Identity and Access Management)
- 역할: AWS 리소스 접근 권한 관리
- 구성 요소
    - User: 사람(개별 계정)
        - 실제 사람 계정 (개발자, 운영자)
        - Access Key/Secret Key, 콘솔 로그인 비밀번호를 가질 수 있음
        - 정책(Policy)을 직접 붙일 수 있음
    - Group: 사용자 묶음
        - 여러 User를 묶어놓은 것
        - 그룹 자체에 정책을 붙이면 그룹 안의 모든 User가 권한 상속
        - User ↔ Group은 1:N 관계 가능 (한 User는 여러 그룹에 속할 수 있음)
    - Policy: 권한 JSON 문서
        - JSON 문서 형태로 “어떤 리소스에 어떤 작업을 허용/거부”할지 정의
        - User, Group, Role에 붙일 수 있음
    - Role: 서비스/애플리케이션이 AWS 리소스에 접근할 때 쓰는 임시 권한
        - 사람이 아닌 서비스/애플리케이션용 권한
        - User처럼 고정 자격증명(비밀번호, 키)이 없음 → 임시 자격증명을 발급받아 사용
        - 예: EC2가 S3에 접근할 때, Lambda가 DynamoDB에 접근할 때
        - 신뢰 주체(Trust Policy) 기반: “누가 이 Role을 쓸 수 있나?”를 정의
- 매핑 예시
    - User ↔ Group ↔ Policy
        - 개발자(User) 여러 명 → "개발팀 그룹" → S3 읽기/쓰기 정책 부여
    - EC2 ↔ Role ↔ Policy
        - EC2 인스턴스 → IAM Role 연결 → Role에 "S3 FullAccess" 정책 부여
    - Lambda ↔ Role ↔ Policy
        - Lambda 함수 → IAM Role 연결 → Role에 "DynamoDB PutItem" 권한 부여
```scss
[사람(개발자, 운영자)] ---> [IAM User]
                               │
                               ▼
                        [IAM Group]  (선택)
                               │
                               ▼
                         [IAM Policy]
                     (권한: S3 Read, EC2 Start 등)


[AWS 서비스 (EC2, Lambda, ECS...)] ---> [IAM Role]
                                             │
                                             ▼
                                       [IAM Policy]
                                 (권한: S3 FullAccess 등)
```
- 권한
    - s3:PutObjectLegalHold
    - AWS IAM 정책에서 사용하는 S3 API 작업 권한(Action) 중 하나
    - Amazon S3 객체(Object)에 대해 법적 보존(Legal Hold) 상태를 설정하거나 해제할 수 있는 권한을 제어

### IAM Role for Service Account(IRSA)
- EKS에서 포드가 AWS 리소스(DynamoDB)에 접근하려면 IAM Role for Service Account(IRSA) 를 사용
- IRSA는 Pod → ServiceAccount → IAM Role → IAM Policy 구조로 연결
- 액세스 키 없이도 안전하게 DynamoDB 접근이 가능
```css
        +-------------------------+
        |  Amazon DynamoDB        |
        | (AWS Managed Service)   |
        +-----------▲-------------+
                    │ (PrivateLink)
         VPC Endpoint (Gateway)
                    │
     +--------------+---------------+
     |   Private Subnet (No IGW)    |
     |   EKS Pod (Spring Boot App)  |
     |   IRSA Role -> DynamoDB      |
     +------------------------------+
```

# Appliance로의 라우팅
### Gateway Load Balancer
- 서드파티 가상 방화벽/IPS 같은 패킷 기반(레이어4/입력된 IP 패킷) 어플라이언스를 인라인으로 투명 삽입하도록 설계된 서비스이며, 운영 오버헤드가 가장 낮은 표준 해법
    - 투명(Transparent)
        - 사용자는 어플라이언스가 중간에 있는지 눈치채지 못함
        - 단순히 라우팅 테이블만 GWLB 엔드포인트로 바꾸면, 트래픽이 자동으로 어플라이언스로 전달됨
- 운영 편의성과 안정성 측면에서 사실상 GWLB가 표준임(어플라이언스 = GWLB로 붙인다가 정답)
    - 어플라이언스
        - 보통 “플러그 앤 플레이(바로 가져다 쓰는)” 개념으로, 복잡한 설정 없이 특정 기능만 잘 수행
        - 물리적 장비일 수 있고, 가상머신/소프트웨어 형태일 수도 있음
### Network Load Balancer
- NLB는 연결 분산만 제공하며 패킷 검사용 서비스 삽입 기능이 없음
- 어플라이언스가 다른 VPC(검사 VPC)에 있는 상황을 표준 방식으로 투명 삽입하기 어려움

### Application Load Balancer
- ALB는 HTTP/HTTPS(L7) 전용임
- 문제의 어플라이언스는 IP 패킷 기반이므로 
#### ALB Session Affinity
- 동일 클라이언트의 요청을 일정 시간 동안 같은 대상(Target/EC2) 으로 라우팅하는 기능
- 장점
    - 인스턴스 로컬 메모리에 세션을 두는 기존 앱을 코드 수정 없이 유지 가능
    - 간단 설정으로 빠르게 동작
- 단점 / 주의점
    - 세션 상태가 인스턴스에 묶임 → 오토스케일/장애/스케일 인 시 세션 유실 위험
    - 부하 불균형(핫스팟) 유발 가능

### Transit Gateway 배포
- VPC, 온프레미스, VPN, Direct Connect 등을 한 곳에서 깔끔하게 연결하고 관리하게 해주는 라우터
- TGW는 VPC 간 라우팅 허브일 뿐, 인라인 트래픽 검사 기능을 제공하지 않음
- 별도 어플라이언스 연계와 복잡한 라우팅/고가용성 구성이 필요해 <u>운영 오버헤드가 큼</u>

| 방식                       | 설명                 | 비용           | 특징                     |
| ------------------------ | ------------------ | ------------ | ---------------------- |
| **VPC Peering**          | 두 VPC를 직접 연결 (1:1) | 저렴        | 간단, 동일 리전/계정 간에 가장 효율적 |
| **Transit Gateway**      | 여러 VPC를 중앙 허브로 연결  | 높음      | 대규모 네트워크에서 유리          |
| **Transit VPC (전송 VPC)** | EC2 기반 라우팅 허브 구성   | 매우 비쌈 | 과거 방식, 비효율적            |


# Application Load Balancer(ALB)
- L7(HTTP/HTTPS) 로드 밸런서
- URL 경로, 호스트 기반 라우팅 가능
- 여러 가용영역에 걸쳐 트래픽을 분산하여 고가용성 확보

# NAT Gateway
- AWS가 완전관리형으로 제공하는 NAT 서비스로, **자동으로 확장(Auto Scaling)** 되어 처리량 제한이 사실상 없음
- 각 가용 영역(AZ) 마다 하나씩 생성할 경우 AZ 장애 발생 시 다른 AZ의 NAT Gateway로 트래픽 우회 가능

# ElastiCache
- ElastiCache(특히 Redis)는 읽기 트래픽(read-heavy workload) 을 줄이는 데 특화된 캐시 서비스

# Amazon RDS (Relational Database Service)
- 관리형 관계형 데이터베이스 서비스
- MySQL, PostgreSQL, Oracle, SQL Server, MariaDB, Aurora 지원
- 백업/복제/패치 관리 자동화
- 스케일링은 가능하지만 초대량 트래픽에는 병목이 될 수 있음

### Amazon RDS Proxy
- 애플리케이션과 DB 사이에 연결 풀링 계층 제공
    - RDS Proxy가 “DB 성능을 높이는 도구”처럼 보이지만, 실제로는 연결 관리(커넥션 관리) 목적이지 쿼리 성능 향상 목적이 아님
    - DB 커넥션을 풀(pool)로 유지해서 애플리케이션의 연결 생성/해제 오버헤드를 줄임
    - 쿼리 자체의 실행 속도를 빠르게 하지 않음
- DB 연결 효율성 향상, 장애 조치는 일부 가능하지만 DB 다운타임 자체는 해결 불가

### Amazon RDS Multi-AZ 배포
- 고가용성을 위해 장애 조치(failover) 지원 -> HA 확보
    - 한 AZ 장애 시 자동으로 다른 AZ로 장애 조치됨(동기식 복제)
- 데이터베이스를 두 개 이상의 가용영역(AZ)에 동기 복제
- 고가용성 확보 목적이며 성능 확장(읽기 분산)에는 도움 안 됨

### Amazon RDS Read Replica
- 읽기 트래픽을 분산하여 성능 향상 가능
- Aurora에서는 자동으로 Reader Endpoint 제공
- 읽기 복제는 **비동기 복제** -> 장애조치/무손실이 아님

### Amazon RDS for Oracle
- 완전 관리형 Oracle DB로 OS에는 접근 불가

### Amazon RDS Custom for Oracle
- RDS 관리형이지만 EC2처럼 OS 및 DB에 직접 접근 가능
- 패치, 에이전트 설치, 특수 설정 가능

| 항목          | RDS Proxy (선택지 B)            | ElastiCache (선택지 A)         |
| ----------- | ---------------------------- | --------------------------- |
| 목적          | 연결 수 관리 (Connection Pooling) | 데이터 읽기 성능 개선 (Caching)      |
| 작동 위치       | 애플리케이션 ↔ DB 사이               | 애플리케이션 ↔ 캐시 ↔ DB            |
| DB 부하 감소    | ❌ 거의 없음                      | ✅ read 부하 크게 감소             |
| 쿼리 응답 속도 개선 | ❌                            | ✅                           |
| 변경 수준       | 적음                           | 적음 (애플리케이션 캐시 로직만 추가)       |
| 적합한 시나리오    | 짧은 연결이 많은 서버리스/Lambda 환경     | read-heavy 웹 서비스 (이 문제의 상황) |


# Amazon DynamoDB
- 관리형 NoSQL 데이터베이스 (Key-Value, Document DB)
    - 완전 서버리스, 관리 부담 적음(운영 관리 최소화)
- 밀리초 단위 응답 시간 제공
- 자동 스케일링 → 초당 수백만 요청 처리 가능(온디맨드 모드 지원)
- 주문 처리, 세션 저장, IoT, 게임 순위표 등에서 자주 사용
- 예측 가능한 워크로드에 Provisioned RCU 및 WCU 사용
- 드물게 접근하는 테이블에는 Standard-IA 사용
- on-demand는 예측이 어려운 급변 트래픽에 유리하나 단가가 높음
    - on-demand에는 RCU와 WCU를 사용하지 않음
### RCU (Read Capacity Unit)
- 강한 일관성(Strongly Consistent) 기준 4KB 아이템 1건/초 = 1 RCU
- 최종 일관성(Eventually Consistent)는 절반(즉, 4KB 1건/초 = 0.5 RCU)
- 트랜잭션 읽기는 2배(Strong 기준의 2배 RCU)

### WCU (Write Capacity Unit)
- 1KB 아이템 1건/초 = 1 WCU
- 트랜잭션 쓰기는 2배(2 WCU/1KB)

### DynamoDB PITR (Point-in-Time Recovery)
- 최대 35일간 변경된 모든 데이터 상태를 저장
- 임의 시점(초 단위)으로 복원 가능
- 운영자가 별도 스크립트 짤 필요 없음 → 관리형 서비스
- 백업 주기를 15분보다 훨씬 짧게 지원

### DynamoDB On-Demand Backup
- DynamoDB 전용 기능
- 테이블 전체를 특정 시점에 수동/자동 백업
- 장기 보관용 (법적 규제 준수 등)
- 단점
    - 주기적 자동화나 보존 정책을 직접 관리해야 함 (운영 부담 ↑)

### DynamoDB 용량 모드
- On-Demand Capacity Mode
    - 사용량 기반 자동 확장 (요청당 과금)
    - 예측 불가 트래픽, 초기 애플리케이션에 적합
    - 비용은 요청 수에 비례
- Provisioned Capacity Mode (+ Auto Scaling)
    - 예상 처리량을 기준으로 설정
    - Auto Scaling으로 자동 확장 가능
    - 하지만 급격한 스파이크 트래픽에는 늦게 반응할 수 있음

### DynamoDB Global Tables
- DynamoDB에 저장되는 데이터를 여러 리전의 테이블로 자동 동기화
- 한 리전에서 쓰기 작업을 해도 다른 리전에 자동 복제(다중 리전 복제 목적) → RPO = 0, RTO 매우 낮음
- 비용이 높음

### Amazon DynamoDB Accelerator (DAX)
- 개념
    - DynamoDB 전용 인메모리 캐시 서비스
    - 완전관리형(Managed)이고, DynamoDB와 호환 API 제공
    - 자주 조회되는 데이터에 대해 마이크로초(µs) 단위 응답을 제공
    - DynamoDB 자체의 밀리초(ms) 단위 응답 속도 → 마이크로초 단위로 줄여줌

### DynamoDB TTL(Time To Live)
- 각 항목에 만료 타임스탬프(예: expireAt) 속성을 넣음
- 그 시간이 지나면 DynamoDB가 해당 항목을 자동으로 삭제됨
- 삭제는 비동기적으로 진행되며, 항목이 만료되면 쿼리/스캔 시 더 이상 보이지 않음

# AWS Backup
- DynamoDB 포함 EBS, RDS 스냅샷, FSx, EFS 등 다양한 리소스 백업 가능
- 스케줄링(예: 매일 1회, 매주 1회 등) + 보존 기간 자동 관리 가능 (예: 7년, 10년 등 규제 준수)
- 운영 효율적
- 중앙집중 관리 (모든 리소스 백업 정책 일괄 적용 가능)
- 콘솔에서 크로스 리전 복사(Cross-Region Copy) 기능을 설정할 수 있음

# AWS Cost Explorer
- AWS 리소스 사용량과 비용을 시각화·분석할 수 있는 서비스
- 필터링/그룹 기능으로 서비스별, 계정별, 태그별, 인스턴스 유형별 비용 분석 가능
- 그래프·차트 제공 → “지난 2개월간 EC2 인스턴스 유형별 비용” 같은 분석에 최적화
- 운영 오버헤드 거의 없음 (콘솔에서 바로 사용)

# AWS Budgets
- 예산 관리 도구
- 서비스 사용량/비용이 특정 기준을 초과하면 알림(SNS, 이메일 등) 발송
- 비용 분석보다 예산 초과 감시/알림이 목적
- 세부 분석 기능은 부족

# AWS Billing & Cost Management Dashboard
- 계정의 총 지출 요약을 보여주는 대시보드
- 서비스별 비용, 최근 사용량 추이 등 큰 그림(overview) 제공
- 하지만 인스턴스 유형별 심층 분석 같은 세밀한 비교는 불가

# AWS CUR (Cost and Usage Report)
- 가장 상세한 비용/사용량 데이터를 CSV/Parquet 형식으로 S3에 저장
- 필드 단위(계정, 리전, 서비스, API 호출, 태그 등)까지 추적 가능
- 단점
    데이터가 방대 → 분석하려면 Athena, Redshift, QuickSight 같은 추가 도구 필요
- 운영 오버헤드 큼, 대신 맞춤형 심층 분석 가능

# Amazon QuickSight
- BI(비즈니스 인텔리전스) 도구 (대시보드/시각화)
- 데이터 소스: S3, RDS, Redshift, Athena, CUR 데이터 등과 연동해 대시보드/시각화 생성 
- 사용 사례: 경영 보고서, 시각화 대시보드, 권한 기반 데이터 공유

# DR 전략(설계 패턴)
### 파일럿 라이트 (Pilot Light)
- 핵심 리소스(특히 DB) 만 DR 리전에 “최소 용량”으로 구동
- 장애 시 나머지 애플리케이션 서버, 로드밸런서 등을 빠르게 기동 → RTO 증가
- 보통 DB에는 교차 리전 복제(Cross-region Replication) 를 구성
- 예
    - RDS → Cross-region read replica
    - DynamoDB → Global Table
    - Aurora → Aurora Global Database (보조 리전 클러스터)

### 웜 대기(Warm Standby)
- DR 리전에 축소된 용량의 **전체 스택(DB + 앱 + 캐시 등) 을 상시 운영**
- 평상시에는 트래픽이 거의 없지만, 장애 시 즉시 확장하여 운영으로 전환 → 낮은 RTO
- DB는 마찬가지로 교차 리전 복제 또는 글로벌 DB 구조로 최신 상태 유지
- 예
    - Aurora Global Database를 DR 리전에도 작게 띄워둠 (Reader 전용)
    - RDS cross-region replica + 작은 EC2/Auto Scaling 최소 용량 실행

# Amazon Aurora (PostgreSQL 호환)
- AWS 관리형 관계형 데이터베이스
    - 클러스터 기반(DB 인스턴스 필요)
- MySQL, PostgreSQL 호환 가능
- 자동 백업, 복제, 고가용성 제공
- 성능과 확장성 향상 (RDS보다 빠름)
- Aurora Replica 또는 멀티 AZ 배포 시 자동 페일오버 지원
- 스냅샷과 PITR(시점 복구) 지원 → 데이터 보호 강화
- 성능이 MySQL보다 최대 5배 빠르고 장애 복구도 매우 빠름
- 6중 복제 (6-way replication)
    - 각 AZ에 2개의 복제본을 두어서, 총 6개의 데이터 복제본을 유지합니다.
    - 예
        - AZ1 → 2개 복제본
        - AZ2 → 2개 복제본
        - AZ3 → 2개 복제본
- 데이터 손실을 막기 위해 다수결(quorum) 방식 사용
    - 쓰기(Write)
        - 6개 중 4개 이상에 기록되면 성공 처리
    - 읽기(Read)
        - 6개 중 3개 이상만 읽으면 가능

### Aurora Read Replica
- Aurora에서 제공하는 읽기 전용 복제본
- 최대 15개까지 생성 가능
- 거의 실시간으로 데이터를 복제하여 읽기 부하를 분산하거나 스테이징/리포트 환경에 활용 가능

### Aurora Global Database
- 다중 리전 읽기 전용 복제(보조 클러스터), 보통 초 단위 미만 지연
- 장애 시 보조 리전을 빠르게 승격해 쓰기 가능
- DR/RPO·RTO 최적화에 적합

# AWS Config
- AWS 리소스의 구성 변경을 지속적으로 추적하고, <u>규칙을 통해 준수 여부 검사</u> 가능
- 인증서 만료일 체크, S3 버킷 정책/버전 관리/퍼블릭 접근 차단 등 구성 변경 여부 감지 가능
- 리소스 구성 및 리소스 변경 사항을 자동으로 평가하여 AWS 인프라 전반의 지속적인 규정 준수 및 자체 거버넌스를 보장
- 규정 준수 감사, 보안 분석, 변경 관리 및 운영 문제 해결 작업을 간소화
- 차단 기능 없음

# AWS Trusted Advisor
- 계정 전체를 점검하는 서비스 (보안, 비용, 성능, 서비스 제한 등)
- 하지만 S3 버킷 구성 변경 실시간 추적 기능은 없음
- 모범 사례 기반 점검(비용/보안 권장사항 등)

# Amazon Inspector
- EC2, ECR, Lambda의 취약점 및 보안 검사 도구(취약점 스캐너)
- S3 구성 변경 추적과는 무관

# S3 Storage Lens
- AWS가 제공하는 S3 전역 분석 도구로, 모든 버킷의 스토리지 사용량과 액세스 패턴을 시각적으로 보여줌
- Storage Lens에서 `TotalRequests` 지표가 매우 낮은 버킷을 찾으면 → 그 버킷의 데이터를 “S3 Standard-IA”나 “Glacier”로 이전하여 비용 절감 가능

| 모드                      | 설명                                           |
| ----------------------- | -------------------------------------------- |
| **기본(Basic) 메트릭**       | 저장된 데이터 양, 객체 수, 버킷 크기 등만 표시                 |
| **고급(Advanced) 활동 메트릭** | 객체 액세스 횟수, 요청 유형(GET/PUT), 마지막 액세스 시간 등 포함 |


# S3 암호화 방식 4가지 (서버 측 3개 + 클라이언트 측 1개)
- Amazon S3에서 객체 암호화를 수행하려면 업로드 요청(`PutObject`) 시 HTTP 헤더 `x-amz-server-side-encryption` 이 반드시 포함
    - 서버 측 암호화(SSE) 방식을 지정하는 헤더
    - `AES256`(SSE-S3) 또는 `aws:kms`(SSE-KMS)
- `s3:x-amz-acl` 는 객체의 접근 제어(ACL)를 지정하는 헤더
- `aws:SecureTransport`는 요청이 HTTPS(SSL/TLS)로 전송되었는지를 나타내는 조건 키
    - true : HTTPS 사용
    - false : HTTP 사용
### SSE-S3 (서버 측 암호화 – S3 관리형 키)
- 데이터를 S3에 저장할 때, S3가 알아서 자체 관리하는 키로 암호화
- 사용자는 키를 직접 관리할 수 없음
- 설정만 해두면 자동 적용됨
- 키는 리전 단위로 관리됨(즉, 다중 리전 키 기능은 제공되지 않음)

### SSE-KMS (서버 측 암호화 – KMS 고객 관리형 키)
- S3에 데이터를 넣을 때, KMS에서 생성한 키를 지정해 암호화
- 키의 생성, 권한, 로테이션 등을 고객이 직접 제어 가능
- `--sse aws:kms` 와 `--sse-kms-key-id` 옵션으로 지정
- <u>멀티 리전 키(Multi-Region KMS Key)</u>를 쓰면 리전 간 복제 시에도 동일 키처럼 동작 가능

### SSE-C (서버 측 암호화 – 고객 제공 키)
- 사용자가 매번 API 요청할 때 키를 직접 제공
- S3는 그 키로 암호화만 하고 저장하지 않음
- 키를 관리해야 하므로 운영 오버헤드가 큼
- 거의 쓰이지 않음

### 클라이언트 측 암호화 (CSE, Client-Side Encryption)
- 애플리케이션이 <u>데이터를 직접 암호화</u>한 뒤 S3에 저장
- S3는 그냥 암호화된 데이터를 받아 저장만 함
- 복호화도 애플리케이션이 직접 해야 함
- 운영 부담이 크고, 문제 요구사항(“S3 버킷에 저장된 데이터를 KMS 고객 관리형 키로 암호화”)과는 다름

| 암호화 방식      | 풀네임                                                | 키 관리 주체                | 특징                                                                                                   | 사용 사례                          |
| ----------- | -------------------------------------------------- | ---------------------- | ---------------------------------------------------------------------------------------------------- | ------------------------------ |
| **SSE-S3**  | Server-Side Encryption with Amazon S3 Managed Keys | **AWS**                | - S3가 자동으로 키 관리 (`aws/s3`)<br>- 가장 단순, 추가 설정 거의 없음<br>- 객체 업로드 시 자동 암호화                              | 기본 암호화, 간단한 규제 충족              |
| **SSE-KMS** | Server-Side Encryption with AWS KMS Keys           | **AWS KMS (고객 제어 가능)** | - KMS 키 사용 (AWS 관리형 or 고객 관리형 CMK)<br>- CloudTrail 로깅 지원 (누가 키 사용했는지 추적)<br>- 비용 발생 (KMS API 호출당 과금) | 규제/감사 요건 충족, 세밀한 접근 제어 필요      |
| **SSE-C**   | Server-Side Encryption with Customer-Provided Keys | **고객**                 | - 고객이 직접 키를 제공 (매 요청 시 헤더에 포함)<br>- AWS는 키 저장 안 함<br>- 키 관리 책임 100% 고객                               | 키를 직접 보관/관리해야 하는 특수 보안 환경      |
| **CSE**     | Client-Side Encryption                             | **고객 (애플리케이션)**        | - 데이터 업로드 전, 클라이언트 애플리케이션이 직접 암호화<br>- AWS는 암호화된 데이터만 저장<br>- 키 관리도 고객 책임                            | 애플리케이션 단에서 데이터 보호 필요, 내부 정책 요구 |

| 항목            | **SSE-C (고객 제공 키)**     | **SSE-S3 (S3 관리형 키)** | **SSE-KMS (KMS 관리형 키)**  |
| ------------- | ----------------------- | --------------------- | ------------------------ |
| 키 관리 주체       | 고객이 직접 키 제공 및 관리        | AWS S3가 자동 관리         | AWS KMS (고객 관리 키 선택 가능)  |
| 키 교체(회전)      | 고객이 직접 교체해야 함           | 자동 교체됨 (투명 관리)        | 자동 회전(매년) 가능 / 수동 회전 가능  |
| CloudTrail 로깅 | ❌ 불가능 (키 사용 내역 기록 불가)   | ❌ 불가능 (키 사용 내역 기록 불가) | ✅ 가능 (키 사용 내역 추적 지원)     |
| 감사/규정 준수 적합성  | 낮음 (고객이 직접 입증 필요)       | 낮음 (감사 로그 없음)         | 높음 (감사 로그 + 키 관리 세분화 가능) |
| 사용 편의성        | 불편 (클라이언트가 매 요청 시 키 제공) | 매우 간단 (추가 설정 불필요)     | 중간 (KMS 키 생성 및 권한 관리 필요) |
| 비용            | 없음                      | 없음                    | KMS 사용량에 따른 비용 발생        |

| 구분         | **AWS KMS**                             | **AWS ACM**                           |
| ---------- | --------------------------------------- | ------------------------------------- |
| **풀네임**    | Key Management Service                  | Certificate Manager                   |
| **목적**     | **데이터 암호화용 키 관리**                       | **SSL/TLS 인증서 관리**                    |
| **암호화 대상** | 데이터, 파일, 로그, DB, S3 객체 등                | 네트워크 트래픽(HTTPS, SSL/TLS)              |
| **사용 예시**  | S3, EBS, RDS, DynamoDB 암호화              | CloudFront, ALB, API Gateway HTTPS 연결 |
| **핵심 리소스** | Customer Master Key (CMK) / KMS Key     | X.509 SSL/TLS 인증서                     |
| **보안 방식**  | 대칭키/비대칭키 암호화                            | 공개키/개인키 기반 SSL/TLS                    |
| **관리 포인트** | 키 생성·회전·정책·KMS API 호출                   | 인증서 발급·갱신·배포                          |
| **통합 서비스** | S3, RDS, EBS, Lambda, Secrets Manager 등 | ELB, CloudFront, API Gateway, NLB 등   |
| **자동화 수준** | 수동 회전 가능 (자동회전 1년)                      | ACM이 자동으로 갱신 관리 (무료)                  |
| **요금**     | 키 저장·API 호출 단위 과금                       | **AWS에서 발급받은 인증서는 무료**                |


# AWS Systems Manager Session Manager
- 브라우저/CLI로 EC2(또는 온프) 인스턴스에 에이전트 기반 원격 접속(쉘/PowerShell/포트포워딩)을 제공하는 운영자용 도구
    - 웹 애플리케이션의 “사용자 세션” 관리와 무관
    - 개발/운영자가 서버에 접속할 때 쓰는 운영 접속 채널임
- 인바운드 포트(SSH/RDP) 열 필요 없음
- SSH 키, 퍼블릭 IP, 배스천 필요 없음
- IAM으로 접근 제어, CloudTrail/CloudWatch에 세션 로깅 가능
- 보안 + 운영 효율성 측면에서 AWS가 권장하는 최신 방식
- IAM 권한으로 접근 제어, SSM Agent 필요

# Amazon AppFlow
- SaaS 애플리케이션 ↔ AWS 서비스 간 데이터 통합을 지원하는 완전관리형 서비스
- 사용자가 직접 코드 작성이나 서버 운영 없이, 클릭 몇 번으로 SaaS → AWS (또는 반대) 데이터 전송 파이프라인을 구축 가능
- 특징
    - 양방향 데이터 전송
        - SaaS 애플리케이션 → AWS 서비스 (예: Salesforce → S3, Redshift, DynamoDB)
        - AWS 서비스 → SaaS 애플리케이션 (예: S3 → Salesforce)

# Amazon Macie
- Amazon S3에 저장된 민감한 데이터를 자동으로 식별·분류·보호하는 보안 서비스
- 머신러닝(ML)과 패턴 매칭을 사용해서 개인 식별 정보(PII), 금융 정보, 개인정보 등이 포함된 데이터를 탐지
- 주요 기능
    - 데이터 식별 & 분류
        - S3 버킷 안의 데이터를 스캔해서 주민등록번호, 신용카드 번호, 이름, 이메일 주소 등 민감 데이터를 자동으로 찾아냄
        - 미리 정의된 패턴 외에도 사용자 정의 패턴(Custom Data Identifier) 추가 가능
    - 데이터 가시성 제공
        - 조직 내에서 어떤 S3 버킷이 존재 여부
        - 버킷에 공개 설정이 되어 있는지 여부
        - 암호화는 적용되어 있는지 등
    - 보안/컴플라이언스 지원
        - GDPR, HIPAA, PCI DSS 같은 규제 준수를 지원하기 위해 민감 데이터 저장 위치를 추적
    - 자동 알림 & 통합
        - Amazon EventBridge, Security Hub, CloudWatch와 통합 가능<br>
        → 민감 데이터 탐지 시 자동 알림/대응 프로세스 실행 가능
```css
        +-------------------+
        |   Amazon S3       |
        | (데이터 저장소)       |
        +---------+---------+
                  |
                  v
        +-------------------+
        |   Amazon Macie    |
        | - 데이터 스캔        |
        | - 민감정보 식별       |
        | - 버킷 설정 점검      |
        +---------+---------+
                  |
      +-----------+-----------+
      |                       |
      v                       v
+-------------+        +-------------------+
| 민감 데이터    |        | 버킷 보안 점검        |
| 탐지 결과     |         | - 공개 여부         |
| - PII, 신용카드|        | - 암호화 상태        |
+------+------ +        +---------+---------+
       |                           |
       v                           v
+-------------+        +-------------------+
| CloudWatch  |        | AWS Security Hub  |
| EventBridge |        | (보안 통합 뷰)       |
+------+------ +        +-------------------+
       |
       v
+-------------------+
| 알림/대응 자동화      |
| (SNS, Lambda 등)   |
+-------------------+
```

# 예약 인스턴스 (Reserved Instances)
- 장기 계약(1년, 3년)으로 비용 절감을 위한 옵션
- 용량 확보 목적이 아니라 비용 절약 목적

# 온디맨드 인스턴스 (On-Demand Instances)
- EC2 인스턴스 구매 옵션 중 하나
- 필요한 순간 바로 실행 가능, 사용 시간(초/분/시간)에 따라 과금
- 장점
    - 유연하고 선결제 없이 언제든 시작/종료 가능
- 단점
    - 용량 보장은 안 됨
- 특정 리전/가용영역(AZ)에 수요가 폭증하면 “용량 부족(Capacity Error)” 발생 가능

# 온디맨드 용량 예약 (On-Demand Capacity Reservation)
- 인스턴스를 실행하기 위한 “자리”를 예약하는 개념
- 특정 리전/AZ에서 EC2 인스턴스 용량을 사전에 예약해 둘 수 있는 기능
- 사용하지 않더라도 비용이 발생
- 단기 이벤트(세일, 스포츠 경기, 선거, 특별 방송 등) 같은 경우에 용량 보장을 위해 활용

# S3 Intelligent-Tiering
- 자주 액세스 ↔ 드물게 액세스 자동 최적화
- 예측하기 어려운 액세스 패턴에 적합

# S3 Glacier / Glacier Deep Archive
- 장기 보관용 초저비용 스토리지
- 검색/복원 지연 가능

# S3 Glacier Select
- Glacier 안에 있는 데이터도 SQL로 직접 검색 가능
- 전체 복원 없이 필요한 데이터만 가져올 수 있음

# AWS Systems Manager Patch Manager
- OS별(예: Amazon Linux, Ubuntu, Windows) 패치 및 AWS 제공 업데이트 자동화
- 패치 준수 보고서를 생성할 수도 있음
- Patch Manager는 SSM 에이전트를 통해 동작하므로 인스턴스에 SSM Agent와 필요한 IAM 권한이 필요
- 서드파티 앱 패치에는 한계

# Amazon Detective
- 보안 사건 원인 분석·조사(포렌식 보조)
- 취약점 스캔/패치 자동화 기능 아님

# AWS Systems Manager Maintenance Window
- 어떤 OS(Windows, Linux, macOS 등)든 상관없이,
SSM Agent가 설치되고 Systems Manager에 등록된 인스턴스라면 대상이 될 수 있음
- 위의 Window란 OS가 아닌 토큰?과 같은 의미로 사용되는 단어임
- 예약 기반 패치 및 관리 작업 수행
- 특정 시간(업무 외 시간, 주말 새벽 등)에만 패치 적용
- Patch Manager / Run Command / Automation과 연계 실행

# AWS Systems Manager State Manager
- 인스턴스의 상태를 원하는 구성대로 유지
- 인스턴스가 생성되면 자동으로 패치 적용
- 항상 특정 보안 업데이트가 설치된 상태를 유지

# AWS Systems Manager Run Command
- EC2 인스턴스(또는 온프레미스 서버)에 사용자 정의 명령/스크립트 동시 실행
- 확장성 높음 (수천 대 이상)
- IAM으로 안전한 권한 제어 가능
- 타사 소프트웨어 보안 패치에 적합

# Amazon FSx for NetApp ONTAP
- AWS에서 NetApp ONTAP 파일 시스템을 네이티브로 제공하는 완전관리형 NAS 서비스
- 지원 프로토콜
    - NFS, SMB, iSCSI 모두 지원
# Amazon FSx for Windows File Server
- 완전관리형(Managed) 네이티브 Windows 파일 시스템 서비스
- 마이크로소프트의 SMB(Server Message Block) 프로토콜과 NTFS 파일 시스템을 그대로 지원
- Windows Server 기반으로 동작 → Active Directory(AD)와 통합 가능
- AWS에서 기존 온프레미스 Windows 파일 서버를 그대로 클라우드에서 사용하는 느낌

# Amazon FSx for Lustre
- HPC(고성능 컴퓨팅), 빅데이터, 머신러닝 등에 최적화된 분산 파일시스템
- 완전 관리형 서비스, Lustre 클라이언트로 접근 가능
- Amazon S3와 통합되어 S3 데이터를 바로 마운트 가능
### Lustre(러스터)
- 고성능 병렬 분산 파일 시스템 (Parallel Distributed File System)
- 주로 HPC(High Performance Computing, 초고성능 컴퓨팅) 환경에서 사용됨
- 대규모 데이터 처리, 슈퍼컴퓨터, 과학 계산, 빅데이터 분석, 머신러닝/AI 워크로드 등에서 활용
- 이름은 Linux + Cluster → Lustre 에서 유래

| 항목         | FSx for Windows File Server | FSx for Lustre   | FSx for ONTAP              |
| ---------- | --------------------------- | ---------------- | -------------------------- |
| **프로토콜**   | SMB (Windows 전용)            | Lustre (HPC용)    | NFS / SMB / iSCSI          |
| **주요 용도**  | Windows 애플리케이션 공유           | 고성능 HPC, ML 학습용  | 범용 NAS, 하이브리드 클라우드         |
| **특징**     | AD 통합, SMB 전용               | 초고속 I/O (밀리초 미만) | NetApp 기능, 멀티 프로토콜, S3 티어링 |
| **비용 효율성** | 중간                          | 고가(고성능)          | 효율적 (자동 티어링 지원)            |


# FSx File Gateway
- 온프레미스에서 FSx 파일 시스템에 SMB/NFS로 접근 가능하게 해주는 게이트웨이
- 자주 사용하는 데이터는 온프레미스 캐시에 두어 지연을 줄임
- 마이그레이션 중 양쪽에서 동일한 파일 서버처럼 사용할 수 있음

# API Gateway Custom Domain Name
- API Gateway의 기본 엔드포인트(URL) 대신, 회사 도메인을 연결 가능
- HTTPS를 위해 반드시 ACM 인증서 필요 (API GW와 같은 리전에서 발급)

# AWS Certificate Manager (ACM)
- 공인 인증서 무료 발급(SSL/TLS 인증서 관리 서비스)
- 인증서 발급, 갱신 자동화 지원 (단, ACM에서 발급된 인증서만)
- API Gateway, CloudFront, ALB 등에 적용 가능

# AWS Secrets Manager
- DB, API 키, 자격 증명, 기타 시크릿 안전하게 저장
- 자동 로테이션 기능 (예: RDS 비밀번호 자동 변경 지원)
- IAM + KMS와 통합 → 접근 제어 + 암호화

# Parameter Store (SSM)
- 보안 매개변수 저장 가능하지만, 자동 로테이션 지원은 없음
- 주로 설정 값/간단한 시크릿 관리

# Route 53
- DNS 관리 서비스
- ALIAS 레코드로 API Gateway 커스텀 도메인에 연결
- 지연 시간 기반 라우팅, 지리적 라우팅 가능
- 컨텐츠 전송 가속은 불가능

# Amazon Comprehend
- 자연어 처리(NLP) 서비스
- 텍스트에서 의미와 감정을 분석하는 데 사용
- 뉴스 기사나 댓글에서 부정적인 감정 탐지, 키워드 추출, 언어 감지
- 이미지가 아니라 텍스트 전용 서비스

# Amazon Comprehend Medical
- 헬스케어/의료 분야 특화 NLP 서비스
- Comprehend를 기반으로 의료 도메인에 최적화된 서비스
- 주요 기능
    - 의학적 개체 인식
        - 환자 이름, 진단명(Disease), 증상(Symptom), 약물(Medication), 치료(Treatment) 등 추출
    - ICD-10-CM, RxNorm 코드 매핑
        - 추출된 의학 개념을 표준 의료 코드로 자동 변환
    - PHI (개인 건강 정보, Protected Health Information) 인식
        - 개인정보(이름, 주소, 의료 기록 번호 등) 자동 탐지 → 비식별화(De-identification) 가능

# Amazon Transcribe Medical
- Amazon Transcribe Medical은 의료 분야에 특화된 음성 → 텍스트 변환(의료 음성 인식) 서비스
- 일반 Amazon Transcribe는 모든 도메인(콜센터, 회의, 방송 등) 음성 인식을 지원
- Transcribe Medical은 특히 헬스케어/의료 상황에 최적화되어 있음

# Amazon Translate
- Amazon Translate는 완전관리형 신경망 기계 번역(NMT, Neural Machine Translation) 서비스
- AWS가 제공하는 클라우드 기반 번역 서비스
- 텍스트를 한 언어에서 다른 언어로 자동 번역
- 개발자가 번역 기능을 손쉽게 애플리케이션에 통합할 수 있음

# Amazon Rekognition
- 이미지와 동영상 분석 서비스
- 사진 속에서 사람, 사물, 텍스트, 부적절한 콘텐츠 등을 탐지 가능
- 소셜 미디어 이미지에서 폭력적/성인물 자동 탐지
- 문제에서 요구한 “업로드된 이미지에 부적절한 내용이 있는지 확인”에 가장 적합

# Amazon SageMaker
- 완전 관리형 머신러닝 모델 개발/학습/배포 플랫폼
- 데이터 과학자가 직접 모델을 훈련시키고 커스텀 AI 모델을 배포할 때 사용
- 유연하지만, 개발/운영 부담이 큼 (문제에서 요구한 “개발 노력 최소화”와는 반대)

# Amazon Textract
- 스캔한 문서, 이미지(PDF, JPG, PNG 등) 에서 텍스트를 자동으로 추출해주는 서비스
- 단순한 OCR(광학 문자 인식)을 넘어서, 문서 내의 구조적 정보(표, 폼, 키-값 쌍)까지 이해하고 추출
    - 주민등록증, 계약서, 설문지, 송장 같은 문서에서 이름, 주소, 금액, 서명란 등을 자동으로 구분해서 데이터화

# AWS Fargate
- 컨테이너 서버리스 실행 서비스 (ECS/EKS에서 사용)
- 서버를 직접 관리하지 않고 도커 컨테이너를 실행
- 머신러닝 모델이나 커스텀 애플리케이션을 컨테이너로 배포할 때 사용
- 이미지의 부적절한 콘텐츠 탐지가 목적이라면 → 직접 모델 배포 필요, 개발 노력이 큼

# Amazon EMR (Elastic MapReduce)
- AWS의 관리형 빅데이터 처리 플랫폼
- Spark, Hadoop, Hive 등 오픈소스 프레임워크 실행
- 대용량 로그 분석, ETL, ML 전처리 등에 적합
- 배치 분석 중심

# Amazon S3
- 데이터 레이크 저장소

# AWS Lake Formation
- 데이터 레이크 권한/보안 관리 + 데이터 소스 통합
- 빅데이터용 하둡(Hadoop) 클러스터를 AWS가 대신 관리해주는 서비스
- S3 기반 데이터 레이크의 보안·카탈로그·권한(테이블/열/행/LF-Tag) 을 중앙에서 관리
- Athena/EMR/Redshift Spectrum/Glue가 공통으로 참조하는 거버넌스 허브 역할

# S3 Object Lock
- 객체 단위 WORM 기능
- 거버넌스 모드(Governance Mode)
    - 관리자 권한으로만 삭제/수정 가능
- 규정 준수 모드(Compliance Mode)
    - 어떤 사용자도 삭제/수정 불가 (강력 보장)
- 법적 준수 모드(Legal Hold)
    - 보존기간과 별개로 **기간이 없으며**, 해제(Release) 하기 전까지 삭제, 수정 불가
    - 적절한 IAM 권한(s3:PutObjectLegalHold)을 가진 사용자는 해제 가능

# S3 버전 관리 (Versioning)
- Object Lock을 사용하려면 반드시 활성화 필요
- 이전 버전도 보존 가능

# S3 Standard-IA (Infrequent Access)
- 자주 사용하지 않지만 필요할 때는 빠르게 접근해야 하는 데이터 저장용
- 저장 비용은 저렴, 대신 읽기/쓰기 요청 시 요금(Access Fee) 발생
- 백업 파일이나 드물게 접근되는 데이터에 사용

# StorageClass
| 스토리지 클래스             | 사용 목적            | 가용성    | 복원 속도 | 최소 보관 기간 |
| -------------------- | ---------------- | ------ | ----- | -------- |
| Standard             | 자주 접근            | 99.99% | 밀리초   | 없음       |
| Intelligent-Tiering  | 패턴 불규칙           | 99.9%  | 밀리초   | 30일      |
| Standard-IA          | 가끔 접근            | 99.9%  | 밀리초   | 30일      |
| One Zone-IA          | 가끔 접근, 재생 가능 데이터(잃어버려도 원본이나 다른 경로로 다시 만들 수 있어서 데이터 유실 위험을 감수할 수 있는 데이터) | 99.5%  | 밀리초   | 30일      |
| Glacier              | 장기 보관, 드물게 접근    | 99.99% | 분\~시간 | 90일      |
| Glacier Deep Archive | 초장기 보관, 거의 접근 안함 | 99.9%  | 시간    | 180일     |

# AWS Systems Manager(SSM)
- AWS 리소스를 운영·관리·자동화하기 위한 관리 서비스 모음
- EC2, RDS, 온프레미스 서버까지 하나의 콘솔/CLI에서 관리 가능

| 기능                  | 설명                           | 예시                          |
| ------------------- | ---------------------------- | --------------------------- |
| **Parameter Store** | 설정값/시크릿 안전 저장                | DB 연결 문자열 저장                |
| **Session Manager** | SSH 필요 없이 브라우저/CLI로 인스턴스 접속  | 보안·감사 로그 자동 기록              |
| **Patch Manager**   | EC2/온프레미스 서버 자동 패치 관리        | 보안 업데이트 자동화                 |
| **Automation**      | 반복 작업을 문서(SSM Document)로 자동화 | EC2 시작/중지 스케줄링              |
| **Run Command**     | 여러 인스턴스에 동시에 명령 실행           | 모든 서버에서 로그 수집               |
| **Inventory**       | 인스턴스의 소프트웨어/구성 수집            | 어떤 서버에 어떤 버전 설치되어 있는지 확인    |
| **OpsCenter**       | 운영 문제 티켓 관리                  | CloudWatch 알람을 OpsItem으로 생성 |

# Amazon MQ
- AWS 완전 관리형 메시지 브로커 서비스
- 오픈소스 메시지 브로커인 ActiveMQ와 RabbitMQ를 AWS가 관리형으로 제공 
- 다중 AZ 활성/대기(HA) 구성을 제공 → 직접 서버 운영 불필요

### ActiveMQ
- Apache ActiveMQ는 오픈소스 메시지 브로커(Message Broker)
- 메시지 브로커는 애플리케이션 간의 메시지(데이터)를 안전하고 비동기적으로 주고받을 수 있게 해주는 미들웨어

# AWS Snow Family
### AWS Snowcone
- 소형(8TB) Edge 디바이스, 주로 IoT·리모트 환경에서 사용
### AWS Snowball Edge Storage Optimized
- 80TB 스토리지 제공, 오프라인 대용량 데이터 전송에 적합
### AWS Snowball Edge Compute Optimized
- 42TB 스토리지 + EC2 인스턴스 기능 포함, 현장 데이터 처리/분석 용도

# OAI (Origin Access Identity)
- CloudFront가 대신 S3에 접근할 수 있는 IAM 유사 사용자 역할을 하는 ID
- 동작 방식
    1. OAI를 생성
    2. CloudFront 배포에 OAI를 연결
    3. S3 버킷 정책에서 "Principal": {"AWS": "OAI_ARN"} 방식으로 해당 OAI만 접근 허용
- 장점
    - S3 퍼블릭 접근 차단 가능
    - CloudFront 경유 요청만 허용
- 단점
    - 비교적 구식 방법 (IAM 역할 기반이라 제한적)
    - 새로운 기능들 (서명된 URL, 서명된 쿠키, 요청 헤더 제어 등)에 제약
    - 현재도 많이 사용되지만, <u>AWS가 OAC로 전환 권장 중</u>
### OAC (Origin Access Control)
- 2022년 도입된 OAI의 진화판
- CloudFront가 오리진(S3, ALB 등)에 보안 요청을 보낼 때 더 세밀한 제어 가능
- 동작 방식
    1. OAC 생성 (CloudFront 배포와 연결)
    2. CloudFront가 S3 요청 시 서명(Signature v4) 기반 인증 사용
    3. S3는 이 서명을 검증 후 요청 허용
- 장점
    - OAI보다 더 유연하고 안전
    - SigV4 서명 지원 → API 요청과 동일한 보안 수준
    - HTTP 헤더 기반 정책 제어 가능
    - CloudFront Functions, Lambda@Edge와 연계 시 더 강력
- 권장 사례
    - 새로 구축하는 경우 OAC 사용이 표준
    - OAI는 레거시 호환성

# AWS Organizations Alternate Contacts
- 각 AWS 계정에 대해 보안(Security), 운영(Operations), 청구(Billing) 담당자 이메일을 등록할 수 있음
- AWS는 루트 이메일뿐만 아니라 이 대체 연락처로도 알림을 발송
- 중앙 관리자가 계정별 대체 연락처를 일괄 설정 가능

| 구분        | Root Email              | Alternate Contacts           |
| --------- | ----------------------- | ---------------------------- |
| **필수 여부** | 모든 계정에 1개 필수            | 선택적, 최대 3개 유형 등록             |
| **관리 주체** | 계정 생성 시 등록              | 계정별 또는 Organizations에서 일괄 관리 |
| **사용 목적** | 계정 로그인, 계정 복구, 기본 알림 수신 | 알림 분산 (보안, 운영, 청구 담당자별)      |
| **보안 위험** | 한 명만 관리하면 알림 누락 위험 ↑    | 여러 담당자가 함께 받아서 리스크 ↓         |

# Compute Savings Plans
- AWS에서 컴퓨팅 비용을 절감할 수 있는 요금제(할인 모델)
- 특정 인스턴스 유형이나 리전 등에 묶이지 않고, 유연하게 <u>EC2, Fargate, Lambda 등</u> 다양한 컴퓨팅 서비스에 적용할 수 있는 가장 유연한 Savings Plan
- 약정
    - 1년 또는 3년 기간 동안 일정 사용량(예: 10$/hr)을 온디맨드 대비 할인된 요금으로 보장받음
- 단점
    - Instance Savings Plans보다 할인율은 조금 낮음

| 구분         | Reserved Instance (RI)                            | Compute Savings Plans                  | EC2 Instance Savings Plans                 |
| ---------- | ------------------------------------------------- | -------------------------------------- | ------------------------------------------ |
| **적용 범위**  | EC2 인스턴스만                                         | EC2(모든 인스턴스 패밀리/리전) + Fargate + Lambda | 특정 리전/인스턴스 패밀리의 EC2                        |
| **유연성**    | 낮음 (인스턴스 패밀리·리전·OS·테넌시 고정, Convertible RI만 교체 가능) | 최고 (서비스, 인스턴스, 리전 자유롭게 적용)             | 중간 (같은 리전 내에서 인스턴스 패밀리 고정, 인스턴스 크기는 변경 가능) |
| **할인율**    | 최대 72%                                            | 최대 66%                                 | 최대 72%                                     |
| **약정 기간**  | 1년 또는 3년                                          | 1년 또는 3년                               | 1년 또는 3년                                   |
| **결제 옵션**  | All Upfront / Partial Upfront / No Upfront        | 동일                                     | 동일                                         |
| **적합 대상**  | 특정 EC2 인스턴스 장기간 고정 사용                             | 워크로드 변동 많고 EC2·Fargate·Lambda 혼합 사용    | 특정 리전/패밀리에서 EC2만 장기간 고정 사용                 |
| **운영 편의성** | 낮음 (인스턴스 변경 어려움)                                  | 가장 높음 (자동 적용)                          | 중간 (리전/패밀리 고정이라 일부 제약)                     |

# AWS Amplify
- 프론트엔드 & 모바일 앱 개발 플랫폼
- 호스팅
    - React, Vue, Angular, Next.js 앱을 자동 빌드·배포·호스팅
- CI/CD
    - GitHub, GitLab, CodeCommit 등과 연동해 자동 배포
- 백엔드 연동
    - 클릭/CLI로 API, 인증, 스토리지 생성
- GraphQL(API → AppSync)
- REST(API → API Gateway + Lambda)
- 인증(Cognito)
- 스토리지(S3)
- 라이브러리/SDK 제공
    - 앱에서 Cognito 로그인, 파일 업로드 등 쉽게 구현 가능
- 운영 부담 최소화
    - 서버 관리 필요 없음, 프론트엔드 개발자가 빠르게 앱 개발 가능

# Amazon Cognito
- Amazon Cognito는 사용자 인증(로그인)과 권한 부여(Access Control) 를 관리해주는 AWS의 완전관리형 서비스
- 웹/모바일 애플리케이션에 회원가입, 로그인, 인증 기능을 쉽게 추가 가능
- 사용자가 로그인하면 토큰(JWT) 을 발급 → 이 토큰을 API Gateway, AppSync, EC2 등에서 검증
- 비밀번호 기반 로그인, 소셜 로그인(Google, Facebook, Apple 등), 기업용 SAML/AD 로그인 지원
- 주요 기능
    - User Pools
        - 앱 사용자의 계정을 직접 관리 (회원가입, 로그인, 다단계 인증 등)
    - Identity Pools
        - 로그인한 사용자에게 AWS 리소스(S3, DynamoDB 등)에 접근할 수 있는 IAM 권한 부여
    - 보안 기능
        - 다단계 인증(MFA)
        - 비정상 로그인 탐지(예: 다른 국가에서 시도)

| 항목        | **Amazon Cognito**                                                                    | **AWS IAM**                                                 |
| --------- | ------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| **대상**    | 애플리케이션 **사용자 (end-user)**                                                             | AWS 리소스를 관리/운영하는 **관리자/개발자/서비스**                            |
| **주요 기능** | - 회원가입/로그인 관리<br>- 소셜 로그인(Google, Facebook, Apple 등)<br>- 다단계 인증(MFA)<br>- 토큰(JWT) 발급 | - IAM 사용자, 그룹, 역할 관리<br>- 세부 권한 정책 부여<br>- AWS 리소스 접근 제어    |
| **사용 예시** | - 모바일 앱 로그인<br>- 웹 서비스 회원 관리<br>- 사용자별로 S3/DynamoDB 접근 권한 부여                          | - EC2 인스턴스가 S3에 접근할 수 있도록 역할 부여<br>- 운영자가 콘솔/CLI로 AWS 자원 제어 |
| **통합 방식** | - 앱 → Cognito 로그인 → JWT 토큰 발급 → API Gateway/AppSync 등에서 검증                            | - AWS 서비스 자체에 IAM Role/Policy 연결                            |
| **보안 기능** | - 비밀번호 정책<br>- MFA<br>- 이상 로그인 감지                                                     | - 세분화된 리소스 기반 정책<br>- 조건부 액세스 (예: 특정 IP, 시간대)               |
| **관리 범위** | 애플리케이션 사용자 단위                                                                         | AWS 리소스/서비스 단위                                              |


# AWS Control Tower
- 멀티계정 환경을 쉽게 설정·거버넌스
- 계정 표준화, 보안·규정 준수 가드레일 제공
- 데이터 상주 가드레일로 특정 리전만 허용 가능하고 그 외 리전은 사용 차단 가능

# Amazon Data Lifecycle Manager (DLM)
- 개념
    - Amazon EC2/EBS 전용 자동 백업 관리 서비스
    - EBS 스냅샷 또는 EC2 인스턴스 AMI를 주기적으로 자동 생성·삭제해주는 기능을 제공
    - “수동으로 스냅샷 찍고 지우는” 운영 부담을 줄여주는 스케줄러 기반 백업 관리 서비스
- 지원 대상
	- Amazon EBS 볼륨 → 주기적인 EBS 스냅샷 생성/삭제 자동화
	- Amazon EC2 인스턴스 → 주기적인 AMI 이미지 생성/삭제 자동화

# AWS Transfer Family
- SFTP, FTPS(FTP over SSL), FTP 프로토콜을 지원하는 완전관리형 서비스(패치, 가용성, 확장 등이 필요 없음 -> 고가용성 내장)
- 온프레미스나 외부 파트너가 기존에 쓰던 FTP 서버를 AWS로 옮기지 않고도 동일한 방식으로 파일을 송수신 가능
- 파일은 AWS Transfer Family 서버에 올라가지만, 실제 저장은 Amazon S3 또는 Amazon EFS 에 저장

# AWS Elastic Beanstalk
- 웹 애플리케이션과 서비스를 빠르게 배포하고 확장할 수 있는 PaaS (Platform as a Service) 형태의 서비스
- 사용자가 코드만 업로드하면, Beanstalk이 알아서 아래를 관리
    - EC2 인스턴스
    - Auto Scaling
    - Elastic Load Balancing
    - 보안 그룹
    - CloudWatch 모니터링
- 개발자는 애플리케이션 로직에만 집중할 수 있음
- 지원하는 플랫폼
    - 언어/프레임워크
        - Java, .NET, Node.js, Python, PHP, Ruby, Go, Docker

# Amazon Pinpoint
- 고객에게 대량 메시지를 발송하고, 반응을 추적 및 분석하는 마케팅 커뮤니케이션 플랫폼
- 멀티채널 메시징 지원
    - SMS, Email, Push Notification, Voice, In-App 메시지 발송 가능
- Two-way SMS 지원
    - <u>사용자가 SMS 회신(Reply) 가능</u>
    - 회신 내용은 Amazon SNS, EventBridge, Kinesis Data Streams 등으로 전달 가능
- Journey(여정) 기능
    - 사용자의 행동(클릭, 회신 등)에 따라 자동화된 캠페인 흐름 설계 가능
    - 예: “메시지 전송 → 응답 여부 판단 → 후속 메시지 발송”
- 세그먼트(타겟 그룹) 기반 발송
    - 인구통계, 위치, 행동 데이터 기반으로 사용자 그룹 지정
- 이벤트 분석 및 통계
    - 전송 성공률, 오픈율, 클릭율, 회신률 등을 실시간 추적
    - Event Stream 기능을 통해 Kinesis Data Streams/S3로 데이터 내보내기 가능
- 활용 사례
    - 마케팅 캠페인, 고객 알림, OTP 전송, 설문 요청, 피드백 수집 등

# Amazon Connect
- 콜센터(컨택센터) 구축을 위한 클라우드 기반 음성/채팅 고객지원 플랫폼
- 클라우드 컨택센터 서비스
    - 전화, 웹 채팅, 음성봇(LEX), 에이전트 연결 등 고객 상담용 통합 솔루션
- 통화 흐름(Call Flow) 설계 가능
    - 시각적 인터페이스로 인바운드/아웃바운드 콜 라우팅 정의
- AWS Lambda 연동
    - 콜 플로우 중간에서 고객정보 조회, DB 업데이트 등 맞춤형 동작 수행 가능
- 다른 AWS 서비스와 통합
    - Amazon S3 (통화 녹음 저장), Kinesis (실시간 콜 분석), CloudWatch (모니터링) 등
- 분석 기능
    - Contact Lens for Amazon Connect로 감정 분석, 키워드 추출, 상담품질 분석 가능
- 활용 사례
    - 고객센터, 기술지원센터, 예약/문의 상담, 자동응답시스템(IVR) 등

# AWS Security Token Service(AWS STS)
- 임시 보안 자격증명(Access Key, Secret, Session Token)을 발급하는 서비스
- 만료 시간이 있는 임시 자격증명 → 노출 위험/영향 축소
- 권한을 최소화·시간 제한으로 부여 가능(보안 모범사례)
- 주요 API
    - AssumeRole: 역할 기반 크로스계정/권한 상승
    - GetSessionToken: IAM 사용자용 임시 자격증명(보통 MFA와 함께)
    - AssumeRoleWithSAML/OIDC: 연동 인증을 통한 임시 크레덴셜

### AssumeRole
- `AssumeRole` 은 STS의 대표적인 API 명령어
    - 다른 역할을 맡는다는 의미
    - 한 계정(A)가 다른 계정(B)에서 만든 IAM Role을 맡아(Assume) 해당 Role의 권한으로 행동할 수 있게됨
    ```css
    [공급업체 계정 B]                [회사 계정 A]
      │                              │
      │ aws sts assume-role 호출      │
      └──────────────▶ [VendorAccessRole 생성]
                          │
                          └─ Trust Policy: Account B 허용

    ```
```css
회사 계정(Account A)
 └── IAM Role (예: VendorAccessRole)
       ├─ Trust policy: 공급업체 계정 ID 허용
       └─ Permission policy: S3, EC2 등 접근 권한 부여

공급업체 계정(Account B)
 └── 사용자가 STS AssumeRole 호출 → 임시 자격 증명 획득 → 회사 리소스 접근

```

# AWS Resource Groups Tag Editor
- 여러 리전/서비스에 걸친 태그 기반 검색·대량 편집·CSV 내보내기를 제공하는 콘솔 도구
- 콘솔에서 Tag Editor를 열고, 리전 다중 선택 → 태그 키=“응용 프로그램”(또는 Application), 값 지정 → 모든 지원 리소스 검색만 하면 즉시 결과가 나옴
- 전 리전·다수 서비스 일괄 조회/내보내기
    - EC2, Lambda, RDS, SNS, SQS 등 여러 서비스의 태그된 리소스를 한 번에 찾아 CSV로 내보내기도 가능

# EC2 Instance Family 요약

| 카테고리         | 패밀리 (대표 시리즈 예)                                                           | 주요 워크로드                            | 특징/선택 팁                                                   |
| ------------ | ------------------------------------------------------------------------ | ---------------------------------- | --------------------------------------------------------- |
| 범용 (General) | **M**(M6i/M7i/M6a/M7g), **T**(T3/T4g)                                    | 웹/앱 서버, 마이크로서비스, 개발/테스트            | 균형형. **Graviton(g)**는 비용/성능 우수. **T 시리즈**는 버스팅(지속부하 비권장). |
| 컴퓨팅 최적화      | **C**(C7i/C7g/C7a/C6i), (고클럭) **M5zn**                                   | CPU 집약 배치/고QPS API, 게임/광고서빙        | vCPU 우선. 단일 스레드 중요 시 고클럭(z) 고려.                           |
| 메모리 최적화      | **R**(R6i/R7i/R7g/R6a), **X**(X2idn/X2iezn/X7g), **High Memory**(u-)     | 인메모리 캐시/DB, 대용량 메모리 앱, SAP HANA    | 메모리:CPU 비율 큼. **상태저장·인메모리** 워크로드에 최적.                     |
| 스토리지 최적화     | **I**(I4i/I4g), **D**(D3/D3en), (구) **H1**                               | 고 IOPS OLTP/인덱스, 로그/대용량 시퀀셜        | **I**: NVMe SSD 저지연/고IOPS, **D**: HDD 대용량/저비용.            |
| 가속기/ML       | **G**(G5/G6), **P**(P4/P5), **Trn/Inf**(Trn1/2, Inf1/2), **F1**, **VT1** | ML 학습/추론, 그래픽/시각화, FPGA, 비디오 트랜스코딩 | 학습: **P/Trn**, 추론: **Inf/G**, 그래픽: **G**, 특수: **F1/VT1**. |
| HPC 전용       | **Hpc6a/Hpc7a/Hpc7g/Hpc7n**                                              | 고성능 컴퓨팅, 스케일아웃 MPI                 | 고대역/저지연 네트워킹 최적화.                                         |
| 특수           | **Mac1/Mac2**, **.metal**                                                | macOS 빌드/CI, 베어메탈 필요 워크로드          | 하드웨어 직접 접근(**metal**), 애플 생태계(**Mac**).                   |

# 이기종 간 데이터베이스 이전
- 온프레미스 Oracle -> Amazon Aurora PostgreSQL
    - 이기종 마이그레이션(heterogeneous migration)의 표준 패턴은 SCT + DMS (Full load + CDC) 조합
        - CDC는 데이터베이스의 “변경 사항(INSERT, UPDATE, DELETE)” 을 실시간으로 감지해서 복제 대상에 반영하는 기술
    - AWS DMS(Data Migration Service) : 데이터 복제 및 CDC(change data capture, 변경 데이터 캡처) 수행
    - AWS SCT(Schema Conversion Tool) : Oracle → Aurora PostgreSQL 간 스키마 변환
- 메모리 최적화 복제 인스턴스 사용
    - DMS는 내부적으로 복제 인스턴스(replication instance) 를 사용하여 데이터를 버퍼링/전송
    - 읽기·쓰기 트래픽이 많고 CDC 로드가 클 경우, 메모리 최적화(memory-optimized) 타입을 선택해야 데이터 누락이나 지연을 방지

# Scaling
### 단계 조정(Step Scaling)
- **단계(조건)**별로 수동으로 증감량을 지정하는 방식
- CloudWatch 경보(Alarm)가 특정 지표를 기준값 초과할 때 트리거됨
- 초과 정도(얼마나 많이 넘었는지)에 따라 단계별로 지정된 수량만큼 확장/축소
- 예: CPU가 70% 넘으면 +2대, 85% 넘으면 +5대

### 대상 추적(Target Tracking Scaling)
- CPU 등 “지표의 목표값(Target value)”을 유지하도록 자동 제어 루프(Feedback Loop) 형태로 동작하는 방식
- 예: CPU 사용률 목표를 **50%**로 지정
- 실제 CPU가 50%를 넘으면 → 자동으로 늘리고, 50% 밑으로 내려가면 → 자동으로 줄임
- 내부적으로 PID 제어기와 유사한 로직이 작동해서 자동으로 균형점을 찾음

### Storage Auto Scaling
- RDS for Oracle, MySQL, PostgreSQL, MariaDB, SQL Server, Aurora 모두 스토리지 Auto Scaling 지원

# AWS Cold Storage VS Amazon S3 Glacier

| 구분         | **AWS Backup Cold Storage**                        | **Amazon S3 Glacier / Glacier Deep Archive**       |
| ---------- | -------------------------------------------------- | -------------------------------------------------- |
| **역할**     | AWS Backup에서 백업 데이터를 **저비용 장기 보관**하기 위한 전용 스토리지 계층 | 사용자가 직접 S3 버킷 내에서 장기 아카이브 용도로 사용하는 **객체 스토리지 클래스** |
| **대상 서비스** | DynamoDB, RDS, EFS, EC2 등 AWS Backup으로 백업된 리소스     | S3에 저장된 객체 (파일, 로그, 영상 등)                          |
| **접근 방식**  | AWS Backup 콘솔 또는 API로 관리 (직접 접근 불가)                | S3 콘솔/CLI/API로 직접 객체 업·다운로드 가능                     |
| **이동 방식**  | AWS Backup의 Lifecycle 정책에 따라 자동 전환                 | S3 Lifecycle 정책으로 Standard → Glacier 전환            |
| **복원 속도**  | 수 시간 (Glacier 수준)                                  | 수 분~수 시간 (Glacier / Deep Archive 옵션 선택 가능)         |
| **요금 구조**  | AWS Backup 내 요금 체계로 계산 (Glacier 기반)                | S3 스토리지 클래스별 요금으로 직접 청구                            |
| **사용 목적**  | **백업 데이터의 장기 보존 (규정 준수)**                          | **파일/객체의 장기 보관 또는 아카이브**                           |

# Amazon Lightsail
- Amazon Lightsail은 AWS에서 제공하는 “간편형 가상 서버(VPS, Virtual Private Server)” 서비스
- 즉, AWS의 복잡한 EC2 설정을 단순화한 서비스로, “웹사이트나 간단한 애플리케이션을 저렴하게 빠르게 올리고 싶은 사람”을 위한 입문형 클라우드 서비스

# Volume Gateway 두 모드
### Stored Volumes
- 원본 데이터 모두를 온프레미스에 그대로 보관 + AWS로 스냅샷 전송 
    → 로컬 성능 보장, DR/백업에 적합
### Cached Volumes
- 원본 S3 보관 + 로컬은 자주 쓰는 데이터 캐시 
    → 대규모 데이터의 비용/확장성 최적화

# Amazon Elastic Transcoder
- Elastic Transcoder는 이전 세대 서비스로, 현재 AWS에서는 AWS Elemental MediaConvert를 후속 서비스로 권장
- AWS의 비디오 및 오디오 인코딩(Transcoding) 서비스
- 동영상 파일을 다양한 기기에서 재생 가능하도록 변환해주는 관리형 서비스
- 입출력 저장소는 Amazon S3 버킷을 사용
- S3에 저장하거나 CloudFront로 스트리밍 가능
- 동작 방식
    - 입력(Input)
        - 사용자가 변환할 원본 비디오를 Amazon S3에 업로드
    - 파이프라인 생성
        - 변환에 사용할 설정(입출력 버킷, 알림, IAM 역할 등)을 정의한 Pipeline을 생성
    - Job 생성
        - 변환 작업(Job)을 생성하여 어떤 형식으로 변환할지를 지정
        - (예: 1080p MP4, 720p HLS 등)
    - 출력(Output)
        - 변환된 파일은 지정된 S3 버킷에 저장
    - 스트리밍(Optional)
        - CloudFront를 사용해 전 세계 사용자에게 스트리밍 가능

# 배치 그룹(Placement Group)
- 여러 EC2 인스턴스를 특정 물리적 배치 전략(placement strategy) 에 따라 그룹화하는 방법
- 목적
    - 지연 시간(Latency) 최소화
    - 네트워크 처리량(Throughput) 향상
    - 가용성(Availability) 향상
    - 고성능 컴퓨팅(HPC) 워크로드 최적화
- 배치 그룹의 3가지 유형

| 유형                      | 설명                                  | 주요 특징                                       | 주 사용 사례                      |
| ----------------------- | ----------------------------------- | ------------------------------------------- | ---------------------------- |
| **Cluster (클러스터)**  | 인스턴스를 **하나의 AZ 내**에서 **가깝게 배치**     | 매우 낮은 지연, 매우 높은 네트워크 속도, 동일 AZ 내만 가능 | HPC, 인메모리 DB, 실시간 거래 시스템     |
| **Spread (스프레드)**   | 인스턴스를 **서로 다른 하드웨어(랙)** 에 **멀리 배치** |장애 격리, AZ당 최대 7개 인스턴스, 지연은 조금 늘어남    | 소규모 고가용성 시스템, 핵심 서비스         |
| **Partition (파티션)** | 인스턴스를 **여러 파티션(하드웨어 그룹)** 으로 나눠 배치  |대규모 클러스터 환경, 장애 도메인 분리, 대용량 데이터 처리   | Hadoop, Cassandra, HDFS, EMR |

| 워크로드                      | 추천 배치 그룹      |
| ------------------------- | ------------- |
| Redis, Memcached, 인메모리 DB | **Cluster**   |
| 핵심 서비스 7개 이하의 고가용 시스템     | **Spread**    |
| Hadoop, Cassandra, HDFS   | **Partition** |


```css
## Cluster 배치 그룹
[가용 영역 A]
 ┌─────────────────────────────┐
 │ EC2-1  EC2-2  EC2-3  EC2-4  │  ← 같은 랙 또는 가까운 네트워크
 └─────────────────────────────┘
➡ 초고속 통신 (낮은 지연, 높은 처리량)

## Spread 배치 그룹
[가용 영역 A]
 ┌─────┐  ┌─────┐  ┌─────┐
 │EC2-1│  │EC2-2│  │EC2-3│  ← 서로 다른 랙
 └─────┘  └─────┘  └─────┘
➡ 하나의 랙 장애에도 다른 인스턴스는 안전

## Partition 배치 그룹
[가용 영역 A]
 ┌────────────┐ ┌────────────┐ ┌────────────┐
 │Partition 1 │ │Partition 2 │ │Partition 3 │
 │EC2-1~10    │ │EC2-11~20   │ │EC2-21~30   │
 └────────────┘ └────────────┘ └────────────┘
➡ 파티션 간 하드웨어 독립, 대규모 데이터 분산처리에 유리
```

# 회선별 전송 소요시간
| 용량                   | 100Mbps 회선에서 전송 소요시간 |
| -------------------- | -------------------- |
| 1TB                  | 약 1일                 |
| 10TB                 | 약 10일                |
| 20TB                 | 약 20일                |
| 20TB를 10.5Mbps 속도로 전송 | 약 **176일** (즉, 불가능)  |

# 예약 조정
- 지정한 날짜/시간에 원하는 최소, 최대 용량으로 고정 변경
- 사람이 스케줄과 용량을 결정해야 함
# 예측 조정
- 과거 패턴을 학습해 미리 수요를 예측, 시작 전에 자동 증감
- 반복적 패턴(일/주 단위)이 존재하고 과거 지표 데이터 필요
- 자동으로 적정 시점(예: ~30분 전)에 선기동

# AWS Batch
- 대규모 배치/병렬 연산 작업을 <u>컨테이너 기반</u>으로 자동 스케줄링·실행해주는 완전관리형 배치 서비스
    - 각 작업을 컨테이너 이미지로 감싸면 언어가 달라도 실행 가능해짐
- ETL/데이터 처리, 과학·금융 시뮬레이션, 미디어 트랜스코딩, ML 전처리·학습, 대량 파일 처리 등 큐에 넣고 돌리는 비대화형 작업
- Batch 자체 요금은 없고 사용한 컴퓨트(EC2/Spot/Fargate)와 스토리지만 과금됨
- 큐 기반으로 작업을 스케줄링하고 필요 시 EC2/SPOT을 자동으로 증감하여 단일 인스턴스 병목 해소

# App Runner
- HTTP 기반 장기 실행 서비스(웹/API) 배포에 특화
- 시분할 배치 작업/스케줄 실행을 직접 지원하지 않으며, 작업마다 다른 런타임을 컨테이너화해도 스케줄링/큐잉/우선순위/대량 동시 실행 같은 배치 오케스트레이션 기능 부족
