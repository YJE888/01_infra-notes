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

---

## RBAC

dev-user(kubeconfig에 명시되어 있는 user)가 default 네임스페이스에서 Pod를 생성(create), 조회(list), 삭제(delete)할 수 있도록 필요한 Role과 RoleBinding을 생성

- Role 이름: developer
- Role 리소스: pods
- Role 권한(동작):
  - list
  - create
  - delete
- RoleBinding 이름: dev-user-binding
- RoleBinding 대상 사용자: dev-user

```bash
# kubeconfig 파일 확인
$ k config view | grep -w -A4 dev-user
- name: dev-user
  user:
    client-certificate-data: DATA+OMITTED
    client-key-data: DATA+OMITTED

# dev-user로 파드 조회
$ kubectl get pods --as dev-user
Error from server (Forbidden): pods is forbidden: User "dev-user" cannot list resource "pods" in API group "" in the namespace "default"

# Role 생성
$ kubectl create role developer --verb list,create,delete --resource pods
role.rbac.authorization.k8s.io/developer created

# RoleBinding 생성
$ k create rolebinding dev-user-binding --role developer --user dev-user
rolebinding.rbac.authorization.k8s.io/dev-user-binding created

# 권한 확인
kubectl get pods --as dev-user
NAME                  READY   STATUS    RESTARTS   AGE
red-cdd5fc4dd-cmzzc   1/1     Running   0          10m
red-cdd5fc4dd-g844v   1/1     Running   0          10m
```

## Security Context

- Pod 또는 Container의 보안 설정을 정의하는 필드
- 리눅스의 권한/보안 기능을 쿠버네티스에서 제어할 수 있게 해줌

### 적용 레벨

1. Pod 레벨 - `spec.securityContext`
2. Container 레벨 - `spec.containers[].securityContext`

- Container 레벨이 Pod 레벨보다 우선순위가 높음

Pod 레벨 vs Container 레벨 비교

| 옵션                     | Pod 레벨 | Container 레벨 |
| ------------------------ | -------- | -------------- |
| runAsUser                | O        | O              |
| runAsGroup               | O        | O              |
| runAsNonRoot             | O        | O              |
| fsGroup                  | O        | X              |
| capabilities             | X        | O              |
| privileged               | X        | O              |
| allowPrivilegeEscalation | X        | O              |
| readOnlyRootFilesystem   | X        | O              |

### 주요 옵션

- `runAsUser / runAsGroup`
  - 컨테이너 프로세스를 실행할 UID / GID 지정

```yaml
securityContext:
  runAsUser: 1000 # UID 1000으로 실행
  runAsGroup: 3000 # GID 3000으로 실행
```

- `runAsNonRoot`
  - root(UID=0)로 실행 금지

```yaml
securityContext:
  runAsNonRoot: true # root로 실행 시 컨테이너 시작 거부
```

- `fsGroup`
  - 볼륨(Volume)에 대한 그룹 소유권 설정 **Pod 레벨에서만 사용** 가능

```yaml
securityContext:
  fsGroup: 2000 # 마운트된 볼륨의 파일들이 GID 2000 소유가 됨
```

- `capabilities`
  - 리눅스 capabilities 추가/제거 *container 레벨*에서만 사용 가능

```yaml
securityContext:
  capabilities:
    add: ["NET_ADMIN", "SYS_TIME"] # 권한 추가
    drop: ["ALL"] # 모든 권한 제거
```

- `NET_ADMIN` : 네트워크 설정 변경 권한
- `SYS_TIME` : 시스템 시간 변경 권한
- `SYS_PTRACE` : 프로세스 추적 권한
- `ALL` : 모든 권한

- `privileged`
  - 컨테이너를 특권 모드로 실행(호스트와 동일한 권한)

```yaml
securityContext:
  privileged: true # ⚠️ 매우 위험, 운영환경 사용 지양
```

- `allowPrivilegeEscalation`
  - 권한 상승 허용 여부(sudo, setuid등)

```yaml
securityContext:
  allowPrivilegeEscalation: false # 권한 상승 차단
```

- `readOnlyRootFilesystem`
  - 루트 파일시스템을 읽기 전용으로 설정

```yaml
securityContext:
  readOnlyRootFilesystem: true # 파일시스템 변경 불가
```

- `seccompProfile`
  - 시스템 콜(syscall)제한 프로파일 설정

```yaml
securityContext:
  seccompProfile:
    type: RuntimeDefault # 런타임 기본 프로파일 사용
```

- `RuntimeDefault` : 컨테이너 런타임 기본값
- `Unconfined` : 제한 없음
- `Localhost` : 노드의 커스텀 프로파일 사용

### 보안 Best Practice(모범 사례)

- runAsNonRoot : 항상 true 로 설정
- allowPrivilegeEscalation : false 설정
- capabilities drop : ["ALL"] 후 필요한 것만 add
- readOnlyRootFilesystem : true 설정
- privileged : true 운영환경 사용 금지
- runAsUser : 0 (root) 사용 금지

### 사례

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-pod
spec:
  securityContext:
    runAsUser: 1001
  containers:
    - image: ubuntu
      name: web
      command: ["sleep", "5000"]
      securityContext:
        runAsUser: 1002

    - image: ubuntu
      name: sidecar
      command: ["sleep", "5000"]
```

- web 컨테이너는 uid가 1002로 실행됨
- sidecar 컨테이너는 uid가 1001로 실행됨

## Service Account

- Service Account
  - 파드 내부 애플리케이션이 쿠버네티스 API 서버와 통신할 때 사용하는 계정
  ```bash
  사람(Human)     → User Account     (kubectl 사용하는 사람)
  애플리케이션    → Service Account  (파드 내부 앱이 API 서버에 접근할 때)
  ```
- 파드 생성 시 자동으로 token이 마운트됨
- TokenRequest API 기반 토큰 사용
- 만료 기간 있음 (보안 강화)
- Projected Volume으로 마운트

```bash
# 경로: /var/run/secrets/kubernetes.io/serviceaccount/
/var/run/secrets/kubernetes.io/serviceaccount/
├── token      ← API 서버 인증 토큰
├── ca.crt     ← 클러스터 CA 인증서
└── namespace  ← 현재 네임스페이스
```

### 비활성화

- service account 레벨에서 비활성화
- pod/deployment 레벨에서 비활성화(pod 레벨 설정이 sa레벨보다 우선순위가 높음)

### Projected Volume

- 여러 개의 볼륨 소스를 하나의 디렉토리에 합쳐서 마운트하는 볼륨 타입
- 일반 볼륨

```yaml
volumes:
  - name: secret-vol
    secret:
      secretName: my-secret
  - name: configmap-vol
    configMap:
      name: my-configmap
```

- Projected 볼륨

```yaml
volumes:
  - name: token # 하나의 볼륨에
    projected:
      sources:
        - serviceAccountToken: # SA 토큰
            path: token
        - secret: # Secret도 함께
            name: my-secret
        - configMap: # ConfigMap도 함께
            name: my-configmap
```

### Projected Volume이 지원하는 소스 종류

| 소스                  | 설명            |
| --------------------- | --------------- |
| `serviceAccountToken` | SA 토큰         |
| `secret`              | 시크릿          |
| `configMap`           | 컨피그맵        |
| `downwardAPI`         | 파드 메타데이터 |

---

```
Projected Volume = 쿠버네티스 공식 볼륨 타입 이름
                   (여러 소스를 하나로 투영/합성한다는 의미)
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-dashboard
spec:
  template:
    spec:
      serviceAccountName: dashboard-sa
      automountServiceAccountToken: false # 자동 마운트 비활성화

      volumes:
        - name: token # 볼륨 이름
          projected:
            sources:
              - serviceAccountToken:
                  path: token
                  expirationSeconds: 3607 # 토큰 만료 시간
                  audience: api # 대상 서비스

      containers:
        - name: dashboard
          image: nginx
          volumeMounts:
            - name: token # 볼륨 이름 매칭
              mountPath: /var/run/secrets/kubernetes.io/serviceaccount
              readOnly: true # 읽기 전용
```

### 토큰 확인 방법

```bash
# 파드 내부에서 토큰 확인
k exec -it my-pod -- cat /var/run/secrets/kubernetes.io/serviceaccount/token

# SA에 연결된 Secret 확인 (구버전)
k describe sa dashboard-sa

# 토큰 직접 생성 (임시)
k create token dashboard-sa

# 만료 시간 지정해서 토큰 생성
k create token dashboard-sa --duration=1h
```

### 요약

- SA 생성 → k create sa <이름>
- 파드에 SA 적용 → spec.serviceAccountName
- 자동마운트 끄기 → automountServiceAccountToken: false
- 권한 부여 → RoleBinding으로 SA에 Role 연결
- 신버전 토큰 → Projected Volume 사용
- 토큰 확인 → k create token <SA이름>

## taint 와 toleration

### Effect 효과

- NoSchedule
  - 새로운 파드 → Toleration 없으면 이 노드에 배치 안됨
  - 기존 파드 → 그대로 유지 (영향 없음)
- PreferNoSchedule
  - 새로운 파드 → 가능하면 배치하지 않음, 다른 노드 없으면 배치됨 (완전 거부가 아닌 권고 수준)
  - 기존 파드 → 그대로 유지
- NoExecute
  - 새로운 파드 → Toleration 없으면 배치 안됨
  - 기존 파드 → Toleration 없으면 즉시 퇴출(Evict)!
    tolerationSeconds 설정 시 해당 시간 후 퇴출

| Effect             | 동작                                   | 기존 파드 |
| ------------------ | -------------------------------------- | --------- |
| `NoSchedule`       | Toleration 없는 파드 **스케줄링 거부** | 영향 없음 |
| `PreferNoSchedule` | 가능하면 스케줄링 안 함 **(소프트)**   | 영향 없음 |
| `NoExecute`        | 스케줄링 거부 + **기존 파드도 퇴출**   | 퇴출됨    |

### toleration 옵션 상세

```yaml
tolerations:
  - key: "app"
    operator: "Equal"
    value: "blue"
    effect: "NoSchedule"
    tolerationSeconds: 3600 # NoExecute일 때만 사용, 없으면 영원히 유지
```

- operator 종류
- equal
  - key=value 정확히 일치
  - vaule 값 필요

- exists
  - key만 존재하면 됨
  - value 불필요

  ```yaml
  # Equal 예시
  tolerations:
  - key: "app"
    operator: "Equal"
    value: "blue"
    effect: "NoSchedule"

  # Exists 예시 (value 없음)
  tolerations:
  - key: "app"
    operator: "Exists"
    effect: "NoSchedule"
  ```

## NodeAffinity

```text
NodeSelector  →  단순한 노드 선택 (key=value 정확히 일치)
NodeAffinity  →  고급 노드 선택 (다양한 조건, 연산자 지원)
```

### NodeAffinity 타입

- requiredDuringSchedulingIgnoredDuringExecution
  - 반드시 만족해야됨(없으면 pending)
  - 실행 중에 노드 변경 시 퇴출되지 않음
- preferredDuringSchedulingIgnoredDuringExecution
  - 만족하면 좋음
  - 실행 중에 노드 변경 시 퇴출되지 않음

### NodeAffinity Operator

| operator     | 설명                          | value 필요 여부 |
| ------------ | ----------------------------- | --------------- |
| In           | 값 목록 중 하나와 일치        | O               |
| NotIn        | 값 목록 중 어느 것과도 불일치 | O               |
| Exists       | key만 존재하면 됨             | X               |
| DoesNotExist | key가 존재하지 않아야 함      | X               |
| Gt           | 지정한 값보다 커야 함         | O               |
| Lt           | 지정한 값보다 작아야 함       | O               |

### 예시

In / NotIn
노드 라벨: disktype=ssd, disktype=hdd, disktype=nvme

- operator: In / values: [ssd, nvme] → ssd, nvme 노드만 선택
- operator: NotIn / values: [hdd] → hdd 제외한 노드 선택
  Exists / DoesNotExist
- operator: Exists → disktype 라벨이 있는 노드면 값 상관없이 선택
- operator: DoesNotExist → disktype 라벨이 아예 없는 노드만 선택

Gt / Lt
노드 라벨: cpu-count=4

- operator: Gt / values: ["2"] → cpu-count가 2보다 큰 노드 선택 (4 선택됨)
- operator: Lt / values: ["8"] → cpu-count가 8보다 작은 노드 선택 (4 선택됨)
