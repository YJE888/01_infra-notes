# 쿠버네티스 보안

## Kubernetes Security Primitives

### 호스트 보안

- root 계정에 대한 액세스 비활성화
- SSH Key 기반 인증 활성화
  - 패스워드 기반 인증 비활성화

### 쿠버네티스 보안

- Authentication
  - 누가 액세스 하는지
  - Static Token File
  - Certificates
  - External Authentication providers - LDAP
  - Service Accounts
- Authorization
  - RBAC Authorization
  - ABAC Authorization
  - Node Authorization
  - Webhook Mode
- TLS Certificates
  - Kube-apiserver와 통신하는 kubelet, kube-proxy, kube-scheduler, kube controller-manager, etcd cluster 등과 같이 모든 통신은 TLS 암호화를 사용하여 보안 유지
- Network Policies
  - 기본적으로 모든 파드는 클러스터 내의 다른 모든 파드에 액세스할 수 있음
  - Network Policy를 사용하여 액세스를 제한할 수 있음

## Authentication(인증)

- 인증 메커니즘을 통해 Kubernetes 클러스터에 대한 액세스를 보호하는데 중점을 둠
- Accounts

  <img src="./images/authentication.png" width="80%">
  - 대상
    - User(Admins, Developers)
  - 인증 방법
    - Certificates
    - External Authentication providers - LDAP
    - Static Token File
      - kube-apiserver가 `--token-auth-file`에 등록된 CSV 파일에 있는 토큰만 인정하여 API 요청의 `Bearer Token`을 인증하는 방식
      - 토큰이 평문으로 저장되어 있어 실무에서는 잘 사용하지 않음
      - 사용 방법
        - user-token-details.csv 파일 생성
          ```bash
          # 파일 내용
          # token               # username # UserUID # Groups
          KpjcVbI7rCFAHYPkBzRb7gu1cUc4B,user10,u0010,group1
          rJjncHmvtxHc6M1WQddhtvNyhygTmxS,user11,u0011,group1
          mjpOFIEiFOkL9toikaRNtt59ePtczZSq,user12,u0012,group2
          PG41IXhs7QjqwWkmBkvggT9gJoyUqZij,user13,u0013,group2
          ```
        - kubea-apiserver 실행 옵션에 아래와 같이 저장
          ```bash
          --token-auth-file=user-token-details.csv
          ```
        - 사용자가 API 요청 시 Bearer Token을 사용
          ```bash
          curl -v -k https://master-node-ip:6443/api/v1/pods \
          --header "Authorization: Bearer KpjcVbI7rCFAHYPkBzRb7gu1cUc4B"
          ```

  - Service Accounts
    - Bot

## API Groups

- kubernetes에서 API Group은 리소스를 기능/도메인별로 묶어서 관리하는 논리적인 네임스페이스로 아래와 같은 구조를 가짐
- YAML에서는 아래의 내용이 `apiVersion` 필드로 나타남

  ```yaml
  <apiGroup>/<version>/<resource>
  ```

- kube-apiserver와 Rest를 통해 직접 상호작용하게 됨

  ```bash
  $ curl -k https://kube-master-ip:6443/version
  {
  "major": "1",
  "minor": "34",
  "emulationMajor": "1",
  "emulationMinor": "34",
  "minCompatibilityMajor": "1",
  "minCompatibilityMinor": "33",
  "gitVersion": "v1.34.2",
  "gitCommit": "8cc511e399b929453cd98ae65b419c3cc227ec79",
  "gitTreeState": "clean",
  "buildDate": "2025-11-11T19:00:39Z",
  "goVersion": "go1.24.9",
  "compiler": "gc",
  "platform": "linux/amd64"
  }
  ```

### REST Endpoint 종류

- `/version`
  - 운영 정보 엔드포인트
  - 클러스터(kube-apiserver) 버전 정보 제공

  ```bash
  curl -k https://master-ip:6443/version
    --key admin.key
    --cert admin.crt
    --cacert ca.crt
  ```

- `/api`
  - Core API Group 엔드포인트

  ```bash
  curl -k https://master-ip:6443/api

  # 하위 구조
    /api/v1/pods
  /api/v1/services
  /api/v1/nodes

  ```

- `/apis`
  - Named API Groups 진입점
  - 확장 API 그룹들의 인덱스
  - Deployment, Job, Ingress, CRD 등

  ```bash
  $ curl -k https://master-ip:6443/apis

  # 하위 구조
  /apis/apps/v1/deployments
  /apis/batch/v1/jobs
  /apis/networking.k8s.io/v1/ingresses
  ```

- `/metrics`
  - 모니터링 엔드포인트
  - Prometheus format 메트릭 제공
  - 사용 주체
    - Prometheus
    - Kube-prometheus-stack
    - metrics-server

  ```bash
  curl -k https://master-ip:6443/metrics
  ```

- `/healthz`
  - 헬스 체크 엔드포인트
  - 로드밸런서 헬스체크에 사용
  - 요즘엔 `/readyz`, `/livez`를 많이 사용

  ```bash
  curl -k https://master-ip:6443/healthz
  ```

- `/logs`
  - apiserver 로그 접근용 엔드포인트
  - 디버깅/운영 목적

## Authorization(인가)

<img src="./images/authorization.png" width="80%">

```scss
요청 →
    Authentication →
          Authorization (Mode 순서대로)
              Node → RBAC → Webhook
                |
                └─ 하나라도 Allow → 통과
                └─ 전부 Deny → 403 Forbidden
```

- Authentication(인증) - 누구임?을 거친 후 Authorization(인가) - 너 이거 해도 됨? 을 거치게 됨
- 인증 실패 시 `401 Unauthorized` -> Authentication 단계 실패
- 인가 실패 시 `403 Forbidden` -> Authorization 단계 실패

### Authorization Mode

- kube-apiserver의 `--authorization-mode` 로 설정
- 여러 모드로 지정하고 싶은 경우 `Node,RBAC` 등과 같이 쉼표로 구분
- 여러 모드를 구성한 경우 요청은 지정된 순서대로 각 모드를 사용하여 승인됨
  - 하나라도 Allow이면 통과, 어느 하나라도 Deny이면 거부

  ```yaml
  # 허용
  Node : Allow
  RBAC : (아직 확인하지 않음)

  # noOpinion
  Node  : NoOpinion (난 모르겠음)
  RBAC  : Allow

  # 거부
  Node  : Deny
  RBAC  : (볼 기회도 없음)
  ```

- 종류
  - AlwaysAllow
    - 모든 요청을 무조건 허용
  - Node
    - 노드 전용 인가 모드
    - kubelet이 할 수 있는 행동만 제한적으로 허용
    - 거의 항상 RBAC와 함께 사용함
  - ABAC(Attribute-Based Access Control)
    - 요청 속성 기반 판단
    - user, namespace, verb, resource 등을 JSON 정책 파일로 정의
    - 정책 파일 수정 시 API Server 재시작 필요
    - 운영 난이도가 높아 거의 사용하지 않음
  - RBAC(Role-Based Access Control)
    - Kubernetes 표준
    - 동적 변경 가능
    - 실무 기본 설정으로 Node와 함께 많이 쓰임
  - Webhook
    - 외부 시스템에 인가 판단을 위임
    - API Server가 외부 HTTP 서비스에 질의
    - 사내 IAM 연동이나, 정책 엔진(OPA, Kyverno-like 시스템) 등을 구성할 때 사용
  - AlwaysDeny
    - 모든 요청을 무조건 거부
    - 사실상 클러스터 사용 불가

## Role Based Access Controls

- 액세스 확인

  ```bash
  kubectl auth can-i create deployments

  kubectl auth can-i create deployments --as dev-user

  kubectl auth can-i create deployments --as dev-user --namespace default
  ```

## Admission Controllers

- kube-apiserver의 `--enable-admission-plugins` 로 설정
- Authorization
  - kubelet(with `~/.kube/config`) -> Authentication(인증) -> Authorization(`role` base) -> Create Pod
- Admission Controllers
  - kubelet -> Authentication -> Authorization -> Admission Controllers -> Create Pod
  - 인가(Authorization)까지 통과한 요청이라도, 클러스터 정책에 맞지 않으면 마지막에 걸러내는 관문
    - latest 이미지 사용 금지
    - privileged pod 실행 금지
    - 리소스 제한 없는 pod 실행 금지
    - 특정 네임스페이스에 특정 리소스 생성 금지
- Admission Controller 종류
  - 일반적으로 `Mutating Admission Controller`를 먼저 호출한 다음 유효성 검사를 위해 `Validating Admission Controller`를 호출함
  - Validating Admission Controller
    - 조건 불만족 시 거부
  - Mutating Admission Controller
    - 요청 객체 자동 수정
      - sidecar 자동 주입
      - default label 추가
      - resource limit 자동 추가
- Webhook 사용 순서
  1. webhook 서버 배포
  2. Admission Webhook 구성

## API Versions

- kubernetes 리소스의 안정성을 나타내는 버전 표기
- Alpha(`v1alpha1`)
  - 구조 변경 가능
  - 운영에서 사용 불가
- Beta(`v1beta1`)
  - 실제 사용 가능
  - 운영에서 사용하는 것을 주의
- Stable/GA(`v1`)
  - 하위 호환 보장
  - 운영에서 사용 가능
  - 문서 및 도구 완비
- API Group 과 Version 구조

  ```bash
  /apis/<apiGroup>/<version>

  # core group
  /api/v1
  ```

## API Deprecations

- API Deprecations rule은 kubernetes API를 언제, 어떤 순서로, 어떻게 폐기되고 제거되는가에 대한 공식 규칙
  - 언제까지 사용가능하고
  - 언제 경고가 나오고
  - 언제 완전히 제거되는지

### Deprecation의 3단계

- Introduced(도입)
  - Alpha / Beta / GA로 등장
- Deprecated(사용 중단 예고)
  - 여전히 동작은 가능하지면 앞으로 제거
  - 사용 시 경고(Warning) 발생
  - 대체 API 존재
- Removed(제거)
  - 아예 없어짐
  - API 서버에서 인식 불가

### Kubernetes의 핵심 Deprecation 규칙 5가지

1. GA API는 최소 12개월 or 3 릴리스 보장
   - Stable(GA) API는 바로 제거되지 않는다
   - 최소 3 minor release 또는 최소 12개월
   - 운영 안정성 보장
2. Beta API는 최소 9개월 or 3 릴리스
   - Beta는 GA보다 보장 기간이 짧음
   - 갑자기 제거되지는 않음
3. Alpha API는 보장 없음
   - 언제든 변경/삭제 가능
   - 기본적으로 운영에서 사용하지는 않음
4. Deprecated
   - 바로 Removed되지는 않음
   - 반드시 Deprecated (경고) → 다음 릴리스들 유지 → Removed

5. Removed되면 복구 불가

- 예시
  - Ingress API
    - 과거
      ```yaml
      apiVersion: extensions/v1beta1
      kind: Ingress
      ```
    - 현재
      ```yaml
      apiVersion: networking.k8s.io/v1
      kind: Ingress
      ```
    - _removed API 사용_ 시 에러 `no matches for kind "Ingress" in version "extensions/v1beta1"`
    - _deprecated API 사용_ 시 경고 `Warning: extensions/v1beta1 Ingress is deprecated in v1.19, unavailable in v1.22`

### 체크포인트

- API 체크
  ```bash
  kubectl api-version
  ```
- Deprecated API 사용 여부 점검
  ```bash
  kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis
  # 또는
  kubectl get apiservices
  ```

## Custom Resource Definition

- Kubernetes에 내가 만든 리소스 타입을 추가하는 방법
- Pod, Service 같은 기본적인 리소스 외에 회사, 솔루션, 플랫폼에 맞는 리소스를 직접 정의
- CRD는 이런 리소스가 있다고 Kubernetes에 알려주는 스키마이고, CR(Custom Resource)는 리소스의 실제 인스턴스
  ```scss
  CRD (설계도)
  ↓
  Custom Resource (실제 객체)
  ↓
  Controller / Operator
  ↓
  실제 Pod / Service / Secret 생성
  ```
- CRD는 명세서일뿐 실제 동작은 Controller가 하게 됨

### CRD의 장점

- CRD는 Kubernetes API처럼 사용 가능
- Kubectl / RBAC / Admission 그대로 적용
- GitOps에 최적
- 선언적 관리 가능

### CRD의 단점 및 주의사항

- Controller가 없으면 무용지물임
- 버전 관리 필요(v1, v1beta1 등)

### 예시

- CRD 생성
  ```yaml
  apiVersion: apiextensions.k8s.io/v1
  kind: CustomResourceDefinition
  metadata:
    name: flighttickets.flights.com
  spec:
    group: flights.com # API Group 정의, CR 에서 apiVersion에 사용
    scope: Namespaced # 생성 범위 지정, Namespace 소속 리소스
    names:
      kind: FlightTicket # kind 정의
      singular: flightticket # 단수형 이름, 조회 이름, k get flightticket
      plural: flighttickets # 복수형 이름, 조회 이름, k get flighttickets
      shortNames: # 축약 이름, 조회 이름, statefulsets를 sts로 조회하듯이 flighttickets를 ft로 조회 가능
        - ft
    versions:
      - name: v1 # API Version 정의, CR 에서 apiVersion에 사용
        served: true
        storage: true
        schema:
          openAPIV3Schema: # 허용 필드
            type: object
            properties:
              spec:
                type: object
                required:
                  - from
                  - to
                  - number
                properties: # 규칙 위반 시 Admission 단계에서 생성 거부
                  from:
                    type: string
                  to:
                    type: string
                  number:
                    type: integer
                    minimum: 1
                    maximum: 10
              status: # 구조만 정의하고 실제 값은 Controller가 값을 입력
                type: object
                properties:
                  phase:
                    type: string
  ```
- CR 생성
  ```yaml
  apiVersion: flights.com/v1
  kind: FlightTicket
  metadata:
    name: my-flight-ticket
  spec:
    from: Mumbai
    to: London
    number: 2
  ```
- 생성 순서

  ```bash
  # 1. CRD 생성
  kubectl apply -f flightticket-crd.yaml

  # 2. 리소스 등록 확인
  kubectl api-resources | grep flight

  # 3. CR 생성
  kubectl apply -f flightticket.yaml

  # 4. 조회
  kubectl get flighttickets
  kubectl get ft
  ```

## Custom Controllers

- kubernetes 리소스(CR)를 감시(watch)하다가, 실제 상태를 원하는 상태로 맞추는 프로그램
- CRD와 CR만 있으면 Kubernetes의 동작
  - etcd 저장
  - 조회(kubectl get)
  - 실제 동작 없음
  - Status 업데이트 없음(pending)
- Controller의 동작
  ```bash
  1. CR 변경 감지 (Create / Update / Delete)
  2. 현재 상태 조회
  3. 원하는 상태와 비교
  4. 차이가 있으면 조치
  5. status 업데이트
  ```

### 예시

- CRD 가 생성되어 있는 상태에서 사용자가 CR 생성
- Controller가 감지
- 원하는 상태 해석(spec)
  ```yaml
  spec:
    from: Mumbai
    to: London
    number: 2
  ```
- 실제 행동 수행
  - 외부 항공 예약 API 호출
  - 좌석 2개 예약
  - 결과 저장
- Status 업데이트
  ```yaml
  status:
    phase: Confirmed
    bookingId: ABC123
  ```
- 사용자가 상태 확인
  ```bash
  kubectl get flightticket
  NAME               STATUS
  my-flight-ticket   Confirmed
  ```

## Operator Framework

- Custom Controller를 표준 방식으로 만들고, 배포하고, 운영하게 해주는 종합 툴체인
- Kubernetes Operator를 만들고 관리하기 위한 공식 프레임워크 모음
- CRD + Controller를 표준 구조 + 배포 + 운영 까지 포함해서 제공하는 프레임워크

### Operator Framework가 필요한 이유

- Custom Controller를 직접 개발
  - watch / reconcile 로직 직접 구현
  - RBAC, leader election 직접 처리
  - CRD 버전 관리 직접 설계
  - 배포/업그레이드 전략 직접 고민
    -> 반복 작업 + 실수 위험
- Operator Framework 사용
  - 베스트 프랙티스 기본 제공
  - 코드 생성 + 표준 구조
  - 배포·업그레이드·마켓플레이스 연계

### Operator Framework 구성요소

- Operator SDK(제작 도구)
  - Operator를 만드는 도구
  - CRD/Controller 코드 자동 생성
- 사용 예시
  ```bash
  operator-sdk init --domain flights.com --repo github.com/example/flight-operator
  operator-sdk create api --group flights --version v1 --kind FlightTicket
  ```
- OLM(Operator Lifecycle Manager)
  - Operator의 설치 및 업그레이드 버전 관리 담당자
  - Operator 설치, 자동 업그레이드, 의존성 관리
