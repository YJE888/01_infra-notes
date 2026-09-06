# Minimize Microservice 취약점

## Linux Capabilities

### Linux 권한

- 리눅스 권한 모델
  - 하나의 특권 작업만 필요한데, root 전체 권한을 줘야되는 상황이 많음
  - 웹 서버가 80번 포트(Well-Known 포트는 root만 열 수 있음)를 열려면 root 권한이 필요
  - 웹 서버 프로세스에 root의 모든 권한(파일 시스템 전체 접근, 커널 모듈 로드 등)을 다 주지 않아도 됨
  ```text
  root (UID 0)    → 모든 권한 다 가짐
  일반 사용자      → 제한된 권한만 가짐
  ```
- Linux Capabilities는 root의 거대한 권한을 40여 개의 세분화된 조각으로 쪼갠 것
  - 필요한 조각만 골라서 부여 가능

### 컨테이너와의 관계

- 컨테이너는 기본적으로 호스트와 커널을 공유
- 컨테이너 프로세스에 과도한 capability가 있으면, 컨테이너 탈출(escape) 후 호스트 전체를 장악할 위험이 커짐

### 주요 Capability

| Capability         | 권한 내용                                        | 위험도    |
| ------------------ | ------------------------------------------------ | --------- |
| `NET_BIND_SERVICE` | 1024 미만의 포트 바인딩                          | 낮음      |
| `CHOWN`            | 파일 소유자 변경                                 | 낮음      |
| `SETUID`/`SETGID`  | 프로세스의 UID/GID 변경                          | 중간      |
| `NET_ADMIN`        | 네트워크 인터페이스, 방화벽 규칙 설정            | 높음      |
| `SYS_ADMIN`        | 마운트, 네임스페이스 조작 등(사실상 준root 권한) | 매우 높음 |
| `SYS_PTRACE`       | 다른 프로세스 추적/디버깅(`ptrace`)              | 높음      |
| `SYS_MODULE`       | 커널 모듈 로드/언로드                            | 매우 높음 |
| `DAC_OVERRIDE`     | 파일 권한(rwx)검사 무시                          | 높음      |
| `KILL`             | 임의 프로세스에 시그널 전송                      | 중간      |
| `NET_RAW`          | ping 모듈 사용                                   | 낮음      |

> `SYS_ADMIN`은 광범위한 작업을 포함하고 있어서 사실상 root 권한과 다름없음

### Docker/Container의 기본 Capability 세트

- 컨테이너 런타임은 기본적으로 모든 capability를 주지 않고, 최소한의 안전한 세트만 부여함
  ```text
  기본 허용: CHOWN, DAC_OVERRIDE, FSETID, FOWNER, MKNOD, NET_RAW,
          SETGID, SETUID, SETFCAP, SETPCAP, NET_BIND_SERVICE,
          SYS_CHROOT, KILL, AUDIT_WRITE
  ```
  > `NET_ADMIN`, `SYS_ADMIN`, `SYS_MODULE` 같은 위험한 것들은 기본적으로 제외되어 있음

### Kubernetes Pod에서 Capability 제어

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: capability-demo
spec:
  containers:
    - name: app
      image: nginx
      securityContext:
        capabilities:
          add: ["NET_BIND_SERVICE"] # 필요한 것만 추가
          drop: ["ALL"] # 나머지 기본 세트는 전부 제거
---
securityContext:
  capabilities:
    drop:
      - ALL # 먼저 모든 capability 제거
    add:
      - NET_BIND_SERVICE # 정말 필요한 것만 다시 추가
```

- Privileged와의 차이

  | 설정                      | 의미                                                                                             |
  | ------------------------- | ------------------------------------------------------------------------------------------------ |
  | `Privileged: true`        | 모든 capability와 추가 권한(디바이스 접근)을 통째로 부여(가장 위험, 사실상 컨테이너 격리 무력화) |
  | `capabilities.add: [...]` | 필요한 capability만 개별적으로 부여(세밀한 제어)                                                 |

> privileged: true는 capability 세분화 개념 자체를 무시하고 전부 다 열어버리는 것이라, CKS에서 가장 먼저 찾아서 제거해야 할 설정

## Security Context

- Pod 또는 컨테이너가 어떤 보안 설정으로 실행될지 정의하는 필드

### 적용 레벨

- Pod
  - Pod 내 모든 컨테이너의 기본값
  - `spec.securityContext`
- Container
  - 해당 컨테이너에만 적용
  - Pod에도 동일한 설정이 있다면 덮어쓰게 됨
  - `spec.containers[].securityContext`

  ```yaml
  apiVersion: v1
  kind: Pod
  spec:
    securityContext: # ← Pod 레벨 (모든 컨테이너에 기본 적용)
      runAsUser: 1000
    containers:
      - name: app
        image: nginx
        securityContext: # ← Container 레벨 (해당 컨테이너에만 적용, Pod 설정을 override)
          runAsUser: 2000
  ```

> 일부 필드(예: capabilities, readOnlyRootFilesystem)는 Container 레벨에서만 설정 가능하고, Pod 레벨에는 없음

### 핵심 필드

- `runAsUser` / `runAsGroup` — 실행 사용자/그룹 지정
  - 컨테이너 이미지가 기본적으로 root(UID 0)로 실행되도록 되어 있어도, 이 설정으로 강제로 비root 사용자로 실행시킬 수 있음

  ```yaml
  securityContext:
    runAsUser: 1000 # UID 1000으로 프로세스 실행
    runAsGroup: 3000 # GID 3000
  ```

- runAsNonRoot — root 실행 자체를 차단
  - 이 값이 true인데 이미지가 root로 실행되려고 하면, Pod 생성 자체가 거부됨

  ```text
  runAsNonRoot: true 만 있고 runAsUser 없음
          │
          ▼
  이미지의 Dockerfile에 USER 지시어가 없으면(root) → 시작 실패
  이미지에 이미 비root USER가 설정되어 있으면 → 정상 시작
  ```

  ```yaml
  securityContext:
    runAsNonRoot: true
  ```

- `readOnlyRootFilesystem` — 루트 파일시스템 읽기 전용화
  - 컨테이너의 루트 파일시스템(`/`)을 쓰기 불가능하게 만듦
  - 침해당한 컨테이너가 악성 파일을 심거나 시스템 파일을 변조하는 걸 막는 강력한 방어책

  ```yaml
  securityContext:
    readOnlyRootFilesystem: true
  ```

  ```yaml
  # 애플리케이션이 임시로 쓸 공간이 필요하면 emptyDir로 별도 마운트
  volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
    - name: tmp
      emptyDir: {}
  ```

- `allowPrivilegeEscalation` — 권한 상승 차단
  - `setuid`/`setgid` 바이너리 등을 통해 프로세스가 자신의 부모보다 더 높은 권한을 얻는 것을 차단

  ```yaml
  securityContext:
    allowPrivilegeEscalation: false
  ```

  > `privileged: true`이거나 `CAP_SYS_ADMIN`이 있으면 이 설정과 무관하게 항상 `true`로 강제

- `privileged` — 특권 컨테이너 (가장 위험)
  - 모든 capability + 호스트 디바이스 접근 권한까지 통째로 부여해서 사실상 컨테이너 격리가 무의미해짐

  ```yaml
  securityContext:
    privileged: true # 절대 지양
  ```

- `capabilities` — 세분화된 커널 권한

  ```yaml
  securityContext:
    capabilities:
      drop: ["ALL"]
      add: ["NET_BIND_SERVICE"]
  ```

- `seccompProfile` — 시스템 콜 필터링
  - 허용된 시스템 콜만 사용하도록 제한됨
  - RuntimeDefault가 대부분의 경우 안전한 시작점

  ```yaml
  securityContext:
    seccompProfile:
      type: RuntimeDefault # 컨테이너 런타임의 기본 seccomp 프로파일 사용
      # 또는
      # type: Localhost
      # localhostProfile: profiles/audit.json
  ```

- `fsGroup` — 볼륨 파일의 그룹 소유권 지정
  - Pod가 마운트하는 볼륨의 파일들이 이 GID로 소유되도록 강제
  - 여러 컨테이너가 공유 볼륨을 안전하게 쓸 때 유용

  ```yaml
  securityContext:
    fsGroup: 2000
  ```

- 안전한 pod 설정 가이드

  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: secure-pod
  spec:
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      fsGroup: 2000
      seccompProfile:
        type: RuntimeDefault
    containers:
      - name: app
        image: nginx
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
              - ALL
            add:
              - NET_BIND_SERVICE
        volumeMounts:
          - name: tmp
            mountPath: /tmp
    volumes:
      - name: tmp
        emptyDir: {}
  ```

- 각 필드가 막는 공격 시나리오 정리
  | 필드 | 막는 위협 |
  | ------------------------------- | ------------------------------------------ |
  | runAsNonRoot: true | 컨테이너 탈출 시 root 권한으로 호스트 장악 |
  | readOnlyRootFilesystem: true | 악성코드 심기, 시스템 파일 변조 |
  | allowPrivilegeEscalation: false | setuid 바이너리를 통한 권한 상승 |
  | capabilities.drop: ALL | 불필요한 커널 권한 악용 |
  | privileged: false | 호스트 디바이스/네임스페이스 전면 접근 |
  | seccompProfile | 위험한 시스템 콜 남용 (예: ptrace, mount) |

### Pod Security Standards(PSS)와의 연결

- SecurityContext 설정들이 바로 다음에 다룰 **Pod Security Standards(Baseline/Restricted)** 가 강제함
- PSS는 "이런 SecurityContext 설정을 지켰는지" 자동으로 검사/차단하는 정책 계층
  ```text
  SecurityContext = Pod가 실제로 갖는 보안 속성 (수동 설정)
  Pod Security Standards = 그 속성들이 정책에 맞는지 강제하는 규칙 (자동 검증)
  ```

## Privileged Pods

- `securityContext.privileged: true`로 설정된 컨테이너로, 컨테이너가 가진 격리(isolation) 경계를 사실상 전부 해제하고 호스트와 거의 동등한 권한을 갖게 되는 상태

  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: privileged-pod
  spec:
    containers:
      - name: app
        image: nginx
        securityContext:
          privileged: true # 위험
  ```

- Privileged 모드가 존재하는 이융
  - CNI 플러그인(Calico, Cilium 같은 네트워크 설정 도구(네트워크 인터페이스 직접 조작)
  - 스토리지 드라이버 - CSI 드라이버(디스크 마운트/포맷)
  - 모니터링 에이전트 - 노드의 커널 메트릭 수집(Datadog agent등)
  - Docker-in-Docker, CI/CD 파이프라인에서 컨테이너 내부에 또 컨테이너 실행
    > 이런 시스템 컴포넌트들은 보통 kube-system 네임스페이스에서, DaemonSet 형태로, 명확한 이유가 있을 때만 privileged를 씀

### 차단 및 예방 방법

- 방법 1
  - Pod Security Standards로 원천 차단(가장 강력)

    ```yaml
    apiVersion: v1
    kind: Namespace
    metadata:
      name: production
      labels:
        pod-security.kubernetes.io/enforce: restricted # privileged Pod 생성 자체를 거부
    ```

    - `restricted` 정책은 `privileged: true`인 Pod의 **생성 자체를 API 레벨에서 거부**

- 방법 2
  - Admission Controller/OPA Gatekeeper로 정책 강제
- 방법 3
  - RBAC으로 애초에 시도조차 못 하게 제한

## Admission Controllers

- apiserver에 내장된(compiled-in) 플러그인들로, API 요청이 etcd에 저장되기 직전에 가로채서 검사하거나 수정하는 코드 조각

### Mutating vs Validating

- Mutating이 값을 바꿔놓은 최종 상태를 Validating이 검사할 수 있게 됨

  ```scss
  요청 도착
      │
      ▼
  Mutating Admission Controllers 실행 (순서대로, 여러 개 가능)
      │  → 요청 내용을 "수정"할 수 있음
      ▼
  Validating Admission Controllers 실행 (순서대로, 여러 개 가능)
      │  → 요청을 "검사만" 하고, 문제 있으면 거부
      ▼
  etcd에 저장
  ```

### 내장 Admission Controller 주요 목록

| 플러그인                   | 타입                | 역할                                                    |
| -------------------------- | ------------------- | ------------------------------------------------------- |
| NamespaceLifecycle         | Validating          | 삭제 중인/존재하지 않는 네임스페이스에 리소스 생성 방지 |
| LimitRanger                | Mutating+Validating | 리소스 기본값 주입 및 제한 검증                         |
| ServiceAccount             | Mutating            | Pod에 기본 ServiceAccount 자동 할당                     |
| DefaultStorageClass        | Mutating            | PVC에 기본 StorageClass 자동 지정                       |
| ResourceQuota              | Validating          | 네임스페이스 리소스 쿼터 초과 방지                      |
| AlwaysPullImages           | Mutating            | 이미지 풀 정책을 항상 Always로 강제                     |
| PodSecurity                | Validating          | Pod Security Standards 강제 (PSA)                       |
| NodeRestriction            | Validating          | kubelet이 자기 노드 관련 리소스만 수정하도록 제한       |
| MutatingAdmissionWebhook   | Mutating            | 외부 웹훅 기반 커스텀 mutation                          |
| ValidatingAdmissionWebhook | Validating          | 외부 웹훅 기반 커스텀 validation                        |

### Webhook Admission Controller

- 내장 플러그인만으로 부족할 때, 외부 서버(웹훅)에 판단을 위임할 수 있음
- OPA/Gatekeeper, Kyverno 같은 정책 엔진의 동작 원리
  ```text
  apiserver → (HTTPS 요청) → 외부 Webhook 서버 → 허용/거부 응답 → apiserver가 그대로 반영
  ```
- ValidatingWebhookConfiguration 예시

  ```yaml
  apiVersion: admissionregistration.k8s.io/v1
  kind: ValidatingWebhookConfiguration
  metadata:
    name: pod-policy-webhook
  webhooks:
    - name: pod-policy.example.com
      clientConfig:
        service:
          name: webhook-service
          namespace: webhook-ns
          path: "/validate"
        caBundle: <base64-encoded-CA-cert>
      rules:
        - apiGroups: [""]
          apiVersions: ["v1"]
          operations: ["CREATE", "UPDATE"]
          resources: ["pods"]
      admissionReviewVersions: ["v1"]
      sideEffects: None
      failurePolicy: Fail # 웹훅 서버 응답 없으면 어떻게 할지
  ```

  - `failurePolicy` - 중요한 보안 설정

    ```yaml
    failurePolicy: Fail      # 웹훅 서버가 응답 안 하면 → 요청 거부 (안전, 기본값)
    failurePolicy: Ignore    # 웹훅 서버가 응답 안 하면 → 요청 허용 (위험할 수 있음)
    ```

    > - `failurePolicy: Ignore`로 설정되어 있으면, 웹훅 서버가 다운되거나 네트워크 문제가 생겼을 때 정책 검사 자체가 우회되어 아무 제약 없이 통과됨
    > - 보안이 중요한 정책이라면 Fail로 설정해야됨

  - MutatingWebhookConfiguration 구조
    - Istio의 사이드카 자동 주입(auto sidecar injection)이 바로 이 MutatingWebhook으로 구현

    ```yaml
    apiVersion: admissionregistration.k8s.io/v1
    kind: MutatingWebhookConfiguration
    metadata:
      name: sidecar-injector
    webhooks:
      - name: inject-sidecar.example.com
        clientConfig:
          service:
            name: injector-service
            namespace: injector-ns
            path: "/mutate"
        rules:
          - apiGroups: [""]
            apiVersions: ["v1"]
            operations: ["CREATE"]
            resources: ["pods"]
    ```

## ImagePullPolicy

- 컨테이너 이미지를 언제 새로 다운로드할지 결정하는 설정

  ```yaml
  spec:
  containers:
    - name: app
      image: nginx:1.25
      imagePullPolicy: Always
  ```

  - `Always` : 매번 Pod 생성 시 레지스트리에서 이미지를 다시 pull(로컬 캐시 무시)
  - `IfNotPresent` : 노드에 이미지가 이미 있으면 재사용하고, 없으면 pull
  - `Never` : 로컬에 있는 이미지만 사용, 없으면 오류(오프라인 환경용도)

### 태그에 따라 변경되는 값

- 태그를 `nginx:latest` 태그를 사용하면 기본값은 `Always`로 설정됨
- 태그를 구체적인 버전 `nginx:1.25`로 적으면 기본값은 `IfNotPresent`로 설정됨

### 보안적 이슈

- 시나리오 A : `IfNotPresent`
  - 처음 pod 배포 시 nginx:1.25 이미지 pull
  - 누군가 레지스트리의 nginx:1.25에 악성코드 주입
  - 이후 같은 노드에서 Pod를 재시작/재배포해도 옛날 버전의 이미지를 그대로 사용
- 시나리오 B : `Always`
  - Pod가 재시작될 때마다 매번 레지스트리에서 최신 이미지를 받어옴
  - 최신의 이미지 자체에 아직 패치되지 않은 취약점이 존재
  - Pod를 재시작할 때마다 취약한 최신 버전을 계속 받아서 실행하게 됨
  - **이미지 스캔과 함께 써야 안전함**

## Admission Controller - AlwaysPullImages

- `imagePullPolicy` 설정과 무관하게 강제로 `Always`로 만드는 플러그인임
- imagePullSecret(레지스트리 인증)이 있는 이미지에 대한 접근 제어를 실질적으로 강화하고자 사용됨
  ```bash
  --enable-admission-plugins=AlwaysPullImages
  ```
- 시나리오
  1. 사용자 A가 프라이빗 레지스트리에서 특정 이미지로 Pod를 실행 (권한 있음, 정상적으로 pull됨)
  2. 그 이미지가 이제 노드에 로컬 캐시로 남음
  3. 사용자 B는 그 레지스트리에 접근 권한이 없는데, imagePullPolicy가 IfNotPresent라면 노드에 캐시된 이미지를 그대로 재사용 가능!
     → 권한 없이 프라이빗 이미지를 실행하는 셈
  - AlwaysPullImages를 활성화하면, Pod 생성 시마다 반드시 레지스트리 인증을 다시 거치게 강제돼서 이런 우회를 막

## Pod Security Standards

- 이건 그냥 "Pod가 안전하려면 어떤 조건들을 만족해야 하는가"를 정의해놓은 문서/기준
- PSS는 그 자체로 아무것도 하지 않고 기준만 정의해놓음
- 3단계 등급표
  ```text
  Privileged 등급   = 아무 제약 없음 (규칙 자체가 거의 없음)
  Baseline 등급     = "이 정도는 지켜야 한다" (예: privileged 컨테이너 금지)
  Restricted 등급   = "이만큼 엄격하게 지켜야 한다" (예: 위 조건 + 비root 실행 필수 + capability 전부 제거 등)
  ```

## Pod Security Admission

- 규칙을 실제로 검사
- kube-apiserver 안에 내장되어 있고, Pod가 생성될 때마다 "이 Pod가 PSS의 어느 등급을 만족하는지" 실제로 검사
- 네임스페이스 라벨로 활성화함
  ```text
  Pod 생성 요청이 들어옴
          │
          ▼
  PSA(Pod Security Admission)가 가로챔  ← 이게 실제로 "일하는" 부분
          │
          ▼
  "이 네임스페이스는 Restricted 등급을 요구하는데,
  이 Pod가 privileged: true로 되어있네? 규칙 위반이다!"
          │
          ▼
  Pod 생성 거부 (또는 경고, 또는 로그만 남김 - 설정에 따라)
  ```
- 네임스페이스 라벨로 활성화함
- 명령어

  ```bash
  kubectl label namespace production pod-security.kubernetes.io/enforce=restricted
  ```

  ```text
  pod-security.kubernetes.io/enforce=restricted
         │                    │        │
         │                    │        └─ PSS의 3단계 중 어느 등급 (Restricted)
         │                    └─ PSA의 3가지 모드 (enforce = 위반 시 거부)
         └─ "이건 PSA 기능을 쓰겠다"는 라벨 키
  ```

- 3가지 모드
  - enforce
    - 위반 시 거부됨
    - 생성 실패
  - audit
    - 위반해도 생성은 허용, audit 로그에 기록만 됨
    - 생성됨(로그에 남음)
  - warn
    - 위반해도 생성은 허용, kubectl 사용자에게 경고 메시지 출력
    - 생성됨(터미널에 경고 뜸)

- 실무에서의 사용
  - enforce부터 바로 걸면 예상치 못한 서비스 중단이 생길 수 있어서, 먼저 관찰(audit/warn) → 나중에 실제 차단(enforce) 순서로 가는 게 실무 원칙

  ```bash
  # 1단계: 먼저 warn + audit만 걸어서 "어떤 것들이 위반인지" 파악 (아무것도 막지 않음)
  kubectl label namespace prod \
    pod-security.kubernetes.io/warn=restricted \
    pod-security.kubernetes.io/audit=restricted

  # 2단계: 위반 사항들을 하나씩 수정 (사용자들이 warn 메시지 보고 스스로 고침)

  # 3단계: 문제 없는 게 확인되면, 그제서야 진짜로 막는 enforce 적용
  kubectl label namespace prod pod-security.kubernetes.io/enforce=restricted
  ```

- 하나의 네임스페이스에 3개를 동시에 다르게 거는 것도 가능

  ```yaml
  metadata:
  labels:
    pod-security.kubernetes.io/enforce: baseline # 최소한 baseline은 무조건 강제
    pod-security.kubernetes.io/warn: restricted # restricted 기준으론 경고만 줌
    pod-security.kubernetes.io/audit: restricted # restricted 위반은 로그로 추적
  ```

  - 당장 baseline은 무조건 지켜야 하지만, restricted까지는 점진적으로 유도하는 세밀한 전략도 가능

## PSA and PSS

- 구분

  ```text
  ┌─────────────────────────────────────────┐
  │  Pod Security Standards (PSS)           │
  │  = "무엇이 안전한가"에 대한 정의/표준           │
  │  (Privileged, Baseline, Restricted)     │
  └─────────────────────────────────────────┘
                │ 강제 적용
                ▼
  ┌─────────────────────────────────────────┐
  │  Pod Security Admission (PSA)           │
  │  = 그 표준을 실제로 검사하는 apiserver 기능    │
  │  (Namespace label로 활성화)               │
  └─────────────────────────────────────────┘
  ```

  ```yaml
  pod-security.kubernetes.io/enforce: restricted
    └─PSA─┘  └──PSS──┘
    (모드)    (프로필)
  ```

## Admission Controller - ImagePolicyWebHook

- 이미지 자체의 신뢰성을 외부 웹훅 서버에 검증 위임하는 Admission Controller
  ```text
  Pod 생성 요청 (특정 이미지 사용)
          │
          ▼
  ImagePolicyWebhook이 가로챔
          │
          ▼
  외부 웹훅 서버에 "이 이미지 써도 되나?" 질의
          │
          ▼
  웹훅 서버가 이미지 스캔 결과, 서명 검증, 신뢰 레지스트리 여부 등을 판단해서 응답
          │
          ▼
  허용/거부
  ```
- 설정 방법
  ```yaml
  # /etc/kubernetes/admission/admission_config.yaml
  apiVersion: apiserver.config.k8s.io/v1
  kind: AdmissionConfiguration
  plugins:
    - name: ImagePolicyWebhook
      configuration:
        imagePolicy:
          kubeConfigFile: /etc/kubernetes/admission/imagepolicy-kubeconfig.yaml
          allowTTL: 50
          denyTTL: 50
          retryBackoff: 500
          defaultAllow: false # 웹훅 응답 없을 때 기본적으로 거부 (안전)
  ```
  ```yaml
  # apiserver에 적용
  - --enable-admission-plugins=ImagePolicyWebhook
  - --admission-control-config-file=/etc/kubernetes/admission/admission_config.yaml
  ```
  > - defaultAllow: false가 핵심 보안 설정
  > - 앞서 배운 failurePolicy: Ignore와 같은 맥락의 함정
  > - 웹훅 서버가 다운됐을 때 기본적으로 거부(false)해야 안전하고, true로 두면 웹훅이 죽어도 아무 이미지나 다 통과되는 구멍이 생김

## Revising Kubernetes Secrets

- Secret이 "안전하지 않은" 기본 이유
  1. base64 인코딩일 뿐, 암호화 아님 (누구나 디코딩 가능)
  2. etcd에 평문으로 저장됨 (Encryption Provider 설정 안 하면)
  3. Secret을 조회할 수 있는 RBAC 권한이 있으면 누구나 값 확인 가능
  4. Pod 환경변수로 주입하면 로그/에러 메시지에 실수로 노출될 위험
- Secret 보안 강화 체크리스트

  ```yaml
  # 1. Encryption at Rest 적용 (앞서 다룬 내용)
  --encryption-provider-config=/etc/kubernetes/enc/enc.yaml

  # 2. RBAC으로 secret 접근 최소화
  rules:
  - apiGroups: [""]
    resources: ["secrets"]
    resourceNames: ["specific-secret"]   # 특정 secret만
    verbs: ["get"]

  # 3. 환경변수보다 볼륨 마운트 권장
  volumeMounts:
  - name: secret-vol
    mountPath: /etc/secret
    readOnly: true
  volumes:
  - name: secret-vol
    secret:
      secretName: my-secret
  ```

- 외부 Secret 관리 도구
  - Kubernetes 기본 Secret의 한계 때문에 실무에서는 아래의 솔루션 사용
  - External Secrets Operator (Vault, AWS Secrets Manager 연동)
  - Sealed Secrets (Git에 암호화된 형태로 안전하게 커밋 가능)

## Cilium

- eBPF(extended Berkeley Packet Filter) 기술 기반의 차세대 CNI(Container Network Interface)
- 앞서 NetworkPolicy 배울 때 언급했던 CNI들(Calico 등) 중 하나인데, Kubernetes 표준 NetworkPolicy보다 훨씬 강력한 기능을 제공
- Cilium이 특별한 이유
  ```text
  기존 CNI (iptables 기반)     →   Cilium (eBPF 기반)
  - L3/L4 정책만 지원 가능       →   L3/L4/L7까지 지원 (HTTP 메서드, 경로 단위!)
  - 성능 오버헤드 있음          →   커널 레벨에서 직접 처리, 더 빠름
  - DNS 인식 정책 어려움        →   DNS 기반 정책 native 지원
  ```

## Structure of Cilium Network Policies

- Kubernetes 표준 NetworkPolicy를 확장한 커스텀 CRD
  ```yaml
  apiVersion: cilium.io/v2
  kind: CiliumNetworkPolicy
  metadata:
    name: example-policy
    namespace: default
  spec:
    endpointSelector: # 표준 NetworkPolicy의 podSelector와 동일 역할
      matchLabels:
        app: backend
    ingress:
      - fromEndpoints: # 표준의 "from" + podSelector와 유사
          - matchLabels:
              app: frontend
        toPorts:
          - ports:
              - port: "8080"
                protocol: TCP
  ```
- 표준 NetworkPolicy와 용어 비교
  | NetworkPolicy | CiliumNetworkPolicy |
  | --------------------- | ------------------------- |
  | podSelector | endpointSelector |
  | from/to + podSelector | fromEndpoints/toEndpoints |
  | ports | toPorts |

## Layer 3 Rules

- IP/엔드포인트 단위의 접근 제어
- Kubernetes 표준 NetworkPolicy의 `podSelector`, `namespaceSelector`, `ipBlock`과 개념적으로 동일
  ```yaml
  apiVersion: cilium.io/v2
  kind: CiliumNetworkPolicy
  metadata:
    name: l3-rule
  spec:
    endpointSelector:
      matchLabels:
        app: backend
    ingress:
      - fromEndpoints:
          - matchLabels:
              app: frontend # 특정 라벨의 Pod만 허용
      - fromCIDR:
          - "10.0.0.0/24" # 특정 IP 대역만 허용
  ```

## Layer 4 Rules

- 포트/프로토콜 단위의 제어
- 표준 NetworkPolicy의 ports 필드와 동일한 개념
  ```yaml
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: frontend
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
  ```

## DNS Rules(Cilium) - L7의 대표 사례

- L3와 L4는 표준 NetworkPolicy로도 충분히 구현 가능한 수준
- 도메인 이름 기반으로 아웃바운드를 제어하는, 표준 NetworkPolicy로는 불가능한 기능
  ```yaml
  apiVersion: cilium.io/v2
  kind: CiliumNetworkPolicy
  metadata:
    name: dns-based-egress
  spec:
    endpointSelector:
      matchLabels:
        app: myapp
    egress:
      - toFQDNs:
          - matchName: "api.github.com" # 이 도메인으로만 나가도록 허용
      - toEndpoints:
          - matchLabels:
              "k8s:io.kubernetes.pod.namespace": kube-system
              k8s-app: kube-dns
        toPorts:
          - ports:
              - port: "53"
                protocol: UDP
  ```
- NetworkPolicy 한계
  - IP 기반의 한계
  - 앞서 다룬 ipBlock은 IP 주소가 고정되어 있어야 쓸 수 있음
  - 하지만 `api.github.com` 같은 서비스는 IP가 수시로 바뀌는 CDN/클라우드 서비스라서 IP 기반 정책이 현실적으로 유지보수가 어려움
  - DNS 기반 정책은 도메인 이름으로 지정하면 Cilium이 내부적으로 IP를 실시간 추적해줘서 이 문제를 해결할 수 있음

## Deny Policies

- Kubernetes 표준 NetworkPolicy의 가장 큰 한계였던 "명시적 deny 불가능" 문제를 Cilium이 해결한 기능
  ```yaml
  apiVersion: cilium.io/v2
  kind: CiliumNetworkPolicy
  metadata:
    name: explicit-deny
  spec:
    endpointSelector:
      matchLabels:
        app: sensitive-app
    ingressDeny: # "Deny"라는 명시적 필드!
      - fromEndpoints:
          - matchLabels:
              app: untrusted-app
  ```
- 표준 NetworkPolicy와 결정적 차이

```text
표준 K8s NetworkPolicy: Allow만 가능 (allow-list 모델)
Cilium: Allow + explicit Deny 모두 가능
```

- Deny의 우선순위
  - Allow보다 항상 먼저 평가됨
  ```text
  평가 순서:
  1. Deny 정책 먼저 체크 → 걸리면 즉시 차단 (다른 Allow가 있어도 무시)
  2. Deny에 안 걸리면 → Allow 정책 체크
  ```
- 이게 앞서 다뤘던 "except를 이용한 우회 방법"보다 훨씬 명확하고 강력한 제어 방식

## Cilium Transparent Encryption

- Pod 간 트래픽을 자동으로 암호화하는 Cilium의 기능
- 앞서 다룬 mTLS/서비스 메시 개념과 연결되는 내용
- 두 가지 구현 방식
  | 방식 | 설명 |
  |------|------|
  | IPsec | 커널 레벨 IPsec 터널로 노드 간 트래픽 암호화 |
  | WireGuard | 더 가볍고 빠른 최신 VPN 프로토콜 기반 암호화 |
  ```yaml
  # Cilium 설치 시 WireGuard 암호화 활성화 (Helm values 예시)
  encryption:
    enabled: true
    type: wireguard
  ```
- Transparent
  ```text
  애플리케이션 코드 수정 없이
  Pod 스펙 변경 없이
          │
          ▼
  Cilium이 CNI 레벨(커널)에서 자동으로 모든 Pod 간 트래픽을 암호화
  ```
- 서비스 메시(Istio 등)처럼 사이드카를 주입할 필요 없이, CNI 레벨에서 통째로 암호화를 처리한다는 게 핵심 장점
- 오버헤드가 더 적고 설정이 간단
- 전체 흐름 요약
  ```text
  ImagePullPolicy (이미지를 언제 받아올지)
          │
          ▼
  AlwaysPullImages (강제로 매번 받아오게 + 권한 재검증)
          │
          ▼
  ImagePolicyWebhook (그 이미지가 신뢰할 만한지 외부 검증)
          │
          ▼
  PSS/PSA (Pod 자체의 보안 설정이 표준을 만족하는지 검증)
          │
          ▼
  Secrets 보안 (Pod가 다루는 민감 데이터 보호)
          │
          ▼
  Cilium (Pod들 간 네트워크 트래픽 세밀 제어 + 암호화)
  ```
