# Cluster Hardening

## Authentication

- 인증은 누구인지 신원을 확인하는 단계
- 인증이 먼저고, 인가가 나중이므로, 인증에 실패하면 인가 단계까지 가지도 않음
- Kubernetes는 `User` 오브젝트가 없음
  - kubectl get users 같은 명령어 자체가 존재하지 않음
  - 외부에서 발급된 자격증명(인증서, 토큰 등)을 신뢰할 수 있는지만 검증

  | 방식                    | 신원 확인 방법                   | 사용 주체                                       |
  | ----------------------- | -------------------------------- | ----------------------------------------------- |
  | x.509 클라이언트 인증서 | 인증서의 CN(사용자명), O(그룹명) | 관리자, 컴포넌트 간 통신(apiserver <-> etcd 등) |
  | ServiceAccount토큰(JWT) | 토큰 내 subject 클레임           | Pod 내부 프로세스                               |
  | 정적 토큰 파일          | 파일 내 토큰-사용자 매핑         | 레거시(비권장)                                  |
  | OIDC                    | 외부 IdP가 발급한 ID 토큰        | 실무 사용자 인증(Google, Okta등)                |
  | Webhook                 | 외부 시스템에 검증 위임          | 커스텀 인증 시스템 연동                         |

- apiserver는 여러 Authentication를 체인으로 등록해두고, 요청이 들어오면 하나씩 순서대로 처리
  - 인증서로 접근하는 관리자와 토큰으로 접근하는 Pod를 동시에 처리할 수 있는 이유임
  ```bash
  # 내가 어떻게 인증되는지 확인
  kubectl auth whoami
  ```

## Authorization

- 인가는 이것을 할 수 있는지 권한을 확인하는 단계
- 인증에서 얻은 `username`/`groups`를 가지고 이 사용자가 이 리소스에 동작을 해도 되는지 확인
- 인가 모드
  | 모드 | 설명 | 실무 사용 |
  | ------- | ------------------------------------------ | ---------------- |
  | RBAC | Role 기반, Yaml로 선언적 관리 | 표준 |
  | ABAC | 정책 파일 기반 | 레거시 |
  | Node | kubelet 전용, 자기 노드 리소스만 접근 허용 | RBAC와 함께 사용 |
  | Webhook | 외부 정책 엔진에 위임(OPA 등) | 실무에서 고급 정책 설정 시 사용 |
- `--authorization-mode=Node,RBAC` - 실제 kubeadm 클러스터의 기본값
  - 여러 모드를 콤마로 나열하면, 하나라도 허용되면 통과됨(OR 방식)
- RBAC 4대 오브젝트

  ```text
  Role / ClusterRole        → "무엇을 할 수 있는지" 정의 (규칙 집합)
  RoleBinding / ClusterRoleBinding → "누구에게" 그 규칙을 적용할지 연결
  ```

  | 오브젝트           | 범위                                                  | 예시                                 |
  | ------------------ | ----------------------------------------------------- | ------------------------------------ |
  | Role               | 특정 네임스페이스                                     | `dev` 네임스페이스의 pod만 조회 가능 |
  | ClusterRole        | 클러스터 전체(또는 재사용 가능한 규칙)                | 모든 네임스페이스의 node 조회        |
  | RoleBinding        | Role/ClusterRole을 특정 네임스페이스의 subject에 연결 |                                      |
  | ClusterRoleBinding | ClusterRole을 클러스터 전체 범위로 연결               |                                      |

- 인가 확인 명령어

  ```bash
  kubectl auth can-i create pods --as=zealvora -n dev
  kubectl auth can-i list secrets --as=system:serviceaccount:dev:my-sa
  ```

- 인증 vs 인가 구분

  ```bash
  # 인증 실패
  # 인증서/토큰이 아예 없거나 유효하지 않음 → 누구인지조차 모름 → 인가 단계 진입 불가
  curl https://apiserver:6443/api/v1/pods
  # → 401 Unauthorized

  # 인증 성공, 인가 실패
  # zealvora라는 신원은 확인됐지만(인증 성공), RBAC에 secrets 조회 권한이 없음(인가 실패)
  kubectl get secrets --as=zealvora
  # → Error: pods is forbidden: User "zealvora" cannot list resource "secrets"
  # → 403 Forbidden

  # 둘 다 성공
  kubectl get pods --as=zealvora
  # → 정상 응답 (200)
  ```

- 관계도
  ```scss
  User makes a request to API Server
                │
                ▼
        Which Authorization Mode?
                │
     ┌──────────┼──────────────┐
     │          │              │
  AlwaysAllow AlwaysDeny      RBAC
     │          │              │
     ▼          ▼              ▼
  Request    Request      Check RBAC Policies
  Always     Always              │
  Allowed    Denied   ┌──────────┼──────────┬──────────────┬─────────────┐
                      │          │          │              │             │
                User is      Developer   User lacks   ServiceAccount   Unknown
              cluster-admin  has 'get'   required     has RoleBinding   user
                               perm on    role
                               pods
                       │          │          │              │             │
                       ▼          ▼          ▼              ▼             ▼
                    Access     Access     Access         Access        Access
                    Granted    Granted    Denied         Granted       Denied
  ```

## Role and RoleBinding

- 4대 오브젝트 관계도

  ```scss
  Role/ClusterRole          →  "무엇을(what) 할 수 있는가" (권한 규칙 집합)
          │
          │ 연결(binding)
          ▼
  RoleBinding/ClusterRoleBinding  →  "누가(who)" 그 규칙을 갖는가
          │
          │ 대상(subject)
          ▼
  User / Group / ServiceAccount
  ```

- Role은 네임스페이스 범위 권한
  - Role은 네임스페이스에 속한 리소스(pods, secret등)에만 사용 가능
  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    namespace: dev
    name: pod-reader
  rules:
    - apiGroups: [""] # "" = core API group (pods, secrets 등)
      resources: ["pods"]
      verbs: ["get", "list", "watch"]
  ```
- ClusterRole - 클러스터 전체 범위(또는 재사용 가능한 규칙)
  - node, pv, namespace 같은 클러스터 범위 리소스는 반드시 ClusterRole을 써야됨
  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: ClusterRole
  metadata:
    name: node-reader
  rules:
    - apiGroups: [""]
      resources: ["nodes"] # node는 네임스페이스에 속하지 않는 리소스 → ClusterRole 필수
      verbs: ["get", "list"]
  ```
- RoleBinding으로 권한 부여

  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: read-pods-binding
    namespace: dev
  subjects:
  - kind: User
    name: zealvora
    apiGroup: rbac.authorization.k8s.io
  - kind: ServiceAccount
    name: my-app-sa
    namespace: dev
  roleRef:
    kind: Role
    name: pod-reader          # 위에서 만든 Role 참조
    apiGroup: rbac.authorization.k8s.io

  # subject는 여러 종류를 동시에 넣을 수 있음
  subjects:
  - kind: User
    name: zealvora
    apiGroup: rbac.authorization.k8s.io
  - kind: Group
    name: dev-team              # 인증서의 O 필드와 매칭
    apiGroup: rbac.authorization.k8s.io
  - kind: ServiceAccount
    name: my-app-sa
    namespace: dev               # ServiceAccount는 namespace 필드가 별도로 필요
  ```

### Create Token for RBAC Practicals

- ServiceAccount는 Pod 내부 프로세스가 API 서버에 인증할 때 쓰는 신원임
- 사람이 아니라 애플리케이션/프로세스용 계정
  ```bash
  # ServiceAccount 생성
  kubectl create serviceaccount my-app-sa -n dev
  ```
- 토큰 생성
  - 짧은 유효기간(기본 1시간)의 토큰을 즉석에서 발급
  - 자동으로 만료되므로 유출돼도 위험이 제한적

  ```bash
  # 토큰 생성
  kubectl create token my-app-sa -n dev

  # 100h의 유효기간을 갖는 토큰 생성
  kubectl create token my-app-sa -n dev --duration=100h
  ```

### verbs, resource, apiGroups

- RBAC Role/ClusterRole의 `rules` 필드를 구성하는 3대 핵심 요소
  ```yaml
  rules:
    - apiGroups: [""] # ① 어느 API 그룹의
      resources: ["pods"] # ② 어떤 리소스에
      verbs: ["get", "list"] # ③ 어떤 동작을 할 수 있는가
  ```
- api-group 확인

  ```bash
  # deployment 리소스 출력
  kubectl api-resources --api-group="apps"

  # pod, service 등의 리소스 출력
  kubectl api-reousrces --api-group=""
  ```

- verbs
  | verbs | 설명 |
  | ------ | --------------------------------- |
  | get | 특정 리소스를 읽음(조회) |
  | list | 해당 타입의 모든 리소스 목록 조회 |
  | create | 새 리소스 생성 |
  | delete | 리소스 삭제 |
  | update | 기존 리소스 수정 |
  | watch | 리소스 변경 사항 감시(실시간) |

- RoleBinding 구조
  ```scss
  RoleBinding
  ├── Subjects (누구에게 권한을 줄지) — 3가지 종류
  │     ├── kind: User            (사람)
  │     ├── kind: Group            (그룹)
  │     └── kind: ServiceAccount   (Pod/애플리케이션)
  │
  └── RoleRef (어떤 권한 규칙을 적용할지)
        └── kind: Role, name: pod-read-only
  ```

## ServiceAccount

### ServiceAccount

- 사람이 아니라 Pod(프로세스)가 Kubernetes API에 인증할 때 사용하는 신원
  ```bash
  # 모든 네임스페이스에 자동 생성되는 default serviceaccount
  kubectl get serviceaccounts -n default
  # NAME      SECRETS   AGE
  # default   0         10d
  ```

  - pod를 만들 때 `serviceAccountName`을 명시하지 않으면 default sa가 자동으로 사용됨
- JWT(Json Web Token)으로 구성됨
  > JWT란?
  >
  > - 정보 + 위조 방지 서명이 합쳐진 하나의 문자열임
  > - Payload 부분은 누구나 읽을 수 있는 base64로 인코딩된 정보로 민감정보를 넣으면 안됨
  ```json
  eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6ZGV2Om15LWFwcC1zYSJ9.SflKxwRJSMeKKF2QT4fwpM...
     └─ ① Header ─┘  └──────── ② Payload ─────────┘  └─────── ③ Signature ────────┘
  ```

  - Header - 어떤 방식으로 서명했는지..
    ```json
    { "alg": "RS256", "typ": "JWT" }
    ```
  - Payload - 실제 정보(kubernetes serviceaccount 토큰 예시)
    - 누구인지(sub), 언제 만료되는지(exp) 같은 정보가 들어있음
    ```json
    {
      "sub": "system:serviceaccount:dev:my-app-sa",
      "exp": 1735689600,
      "iat": 1735686000
    }
    ```
  - Signature - 위조 방지 서명
    - apiserver가 본인만 아는 비밀키로 Header와 Payload를 서명한 값
    - 내용이 바뀌게 되면 서명이 달라져서 무결성이 위반
- JWT가 쓰이는 곳
  ```text
  Pod 내부의 ServiceAccount 토큰 = 바로 JWT
  /var/run/secrets/kubernetes.io/serviceaccount/token
          │
          ▼
  이 파일 안의 내용이 바로 위에서 본 것 같은 JWT 문자열
  ```

### ServiceAccount Security

- 최소 권한(Principle of Least Privilege)
  - pod마다 필요한 최소 권한만 가진 전용 SA 생성
- 토큰 자동 마운트 비활성화(`automountServiceAccountToken`)
  - API 서버와 통신할 필요가 없는 Pod(단순 웹서버, 배치작업)라면, 토큰 자체를 마운트하지 않는게 안전함
  - 토큰이 마운트되어 있다면, 그 Pod가 침해당했을 때 공격자가 토큰을 훔쳐서 API에 접근할 수 있음

  ```yaml
  # SA 레벨에서 비활성화 (이 SA를 쓰는 모든 Pod에 적용)
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: log-reader-sa
  automountServiceAccountToken: false

  # Pod 레벨에서 비활성화 (개별 Pod만 예외 처리하고 싶을 때)
  apiVersion: v1
  kind: Pod
  spec:
    serviceAccountName: log-reader-sa
    automountServiceAccountToken: false
  ```

  - Pod레벨에서의 설정이 ServiceAccount레벨에서의 설정보다 우선순위가 높음
    - SA는 true, Pod는 false라면 Pod 설정을 따라감

- 짧은 유효기간 토큰 사용(Bound ServiceAccount Token)
  - Kubernetes 1.24+부터는 기본적으로 projected volume 방식으로 짧은 유효기간(기본 1시간)의 토큰이 자동 발급/갱신
  - 레거시 방식(영구 Secret 토큰)과 달리, 탈취되어도 자동 만료되어 위험이 제한됨
  - 레거시 토큰은 Pod가 삭제돼도 여전히 유효했지만, projected volume 방식의 토큰은 그 Pod가 살아있는 동안만 유효(Bound Token이라 함)
  ```yaml
  # Pod 내부에서 실제로 마운트되는 방식 (자동 처리되지만 원리는 이렇게)
  volumes:
    - name: kube-api-access
      projected:
        sources:
          - serviceAccountToken:
              expirationSeconds: 3600 # 짧은 유효기간
              path: token
  ```
  ```text
  expirationSeconds: 3607   (기본 1시간 + 여유 7초)
          │
          ▼
  kubelet이 토큰 만료 80% 시점에 자동으로 새 토큰 요청 → 파일 내용 자동 교체
          │
          ▼
  Pod 애플리케이션은 아무 조치 없이도 항상 최신 토큰 사용
  ```
- SA와 특정 Audience/용도 제한
  ```bash
  kubectl create token my-app-sa --audience=vault --duration=15m
  ```
  ```yaml
  - serviceAccountToken:
    audience: vault # 이 토큰은 오직 "vault"라는 대상에만 사용 가능
    expirationSeconds: 600
    path: vault-token
  ```

  - `--audience`로 이 토큰이 어떤 대상(API)을 향해 쓰일 수 있는지 제한할 수 있음
  - 예를 들어 Vault 같은 외부 시스템 인증 전용 토큰을 발급할 때 사용
- imagePullSecrets 최소화
  - ServiceAccount에 컨테이너 레지스트리 인증 정보를 연결할 수도 있는데, 필요 이상으로 넓은 레지스트리 접근 권한을 주지 않도록 주의

| 항목                     | 레거시 secret 토큰         | Projected Volume(BoundServiceAccountToken) |
| ------------------------ | -------------------------- | ------------------------------------------ |
| 유효기간                 | 없음(영구)                 | 짧은(기본 1시간, 자동 갱신)                |
| Pod 종속성               | 없음(Pod 삭제 후에도 유효) | 있음(Pod와 함께 소멸)                      |
| 저장 위치                | etcd의 Secret 오브젝트     | 메모리 상에서 즉석 발급(tmpfs)             |
| Audience 제한            | 불가능                     | 가능                                       |
| kube-bench 권장          | 지양대상                   | 기본값(권장)                               |
| Kubernetes 기본값(1.24+) | 수동 생성해야만 존재       | 자동 적용                                  |

## Version Skew Policy(버전 스큐 정책)

- Kubernetes 클러스터를 구성하는 여러 컴포넌트(kube-apiserver, kubelet, kube-proxy, kubectl등)는 서로 완전히 같은 버전일 필요는 없지만, 허용되는 버전 차이(skew)에는 제한이 있는데 이 규칙을 정의한 게 `Version Skew Policy` 임
- kube-apiserver - 기준점
  - 모든 다른 컴포넌트 버전은 kube-apiserver를 기준으로 비교

  | Major Version | Minor Version | Patch Version |
  | :-----------: | :-----------: | :-----------: |
  |       1       |      32       |       2       |

  > HA(고가용성) 클러스터에서 여러 대의 kube-apiserver가 있을 경우, 가장 오래된 인스턴스와 가장 최신 인스턴스는 마이너 버전 1개 차이까지만 허용
  >
  > - 예: 최신 kube-apiserver가 1.35라면 → 다른 인스턴스는 1.35 또는 1.34까지만 허용

- kubelet
  - kubelet은 kube-apiserver보다 최신 버전일 수 없음
  - kubelet은 kube-apiserver보다 최대 3개 마이너 버전까지 낮을 수 있음
  ```text
  예: kube-apiserver가 1.35라면
  → kubelet은 1.35, 1.34, 1.33, 1.32 까지 지원됨
  ```
  > HA 클러스터에서 apiserver 버전이 섞여있으면(예: 1.35와 1.34 혼재), 허용되는 kubelet 버전 범위는 더 좁아짐
  >
  > - kubelet은 1.34, 1.33, 1.32까지만 지원됨
  > - 1.31은 1.35 apiserver(1.32까지)에서 지원하지 못함
- kube-proxy
  - kube-proxy도 kube-apiserver보다 최신일 수 없고, 최대 3개 마이너 버전까지 낮을 수 있음
- Control Plane 컴포넌트(controller-manager, scheduler)
  - 단일 클러스터 내에서 kube-apiserver, kube-controller-manager, kube-scheduler는 서로 마이너 버전 1개 이내여야 됨
  - 즉, apiserver보다 최대 1버전 낮을 수 있음
- kubectl(클라이언트)
  - kubectl은 API 서버 기준 앞뒤로 1개 마이너 버전까지 지원(n-1 ~ n+1)
  - 즉, kubectl은 apiserver보다 한 버전 높거나 낮아도 됨

## Upgrading kubeadm Clusters

- 업그레이드 순서
  ```text
  1. etcd
  2. kube-apiserver
  3. kube-controller-manager, kube-scheduler
  4. kubelet, kube-proxy (워커 노드)
  5. kubectl (클라이언트, 아무 때나 가능)
  ```
- 한 번에 하나의 마이너 버전씩 업그레이드해야 하며, 1.27에서 1.30으로 바로 건너뛸 수 없음
- 업그레이드 커맨드

  ```bash
  # 각 컴포넌트 현재 버전 확인
  kubectl version
  kubectl get nodes -o wide          # kubelet 버전 확인 (KUBELET-VERSION 컬럼)
  kube-proxy --version

  # kubeadm 업그레이드 계획 확인
  kubeadm upgrade plan

  # 실제 업그레이드(apiserver, controller-manager, scheduler, etcd)만 자동으로 업그레이드
  kubeadm upgrade apply v1.29.0
  ```

- kubelet은 별도로, 노드마다 직접 업그레이드해야됨
  - kubeadm upgrade apply → static pod manifest만 교체 (control plane)
  - kubelet 자체는 systemd 서비스로 각 노드에서 독립 실행 중으로 kubeadm이 원격으로 손댈 수 있는 영역이 아님

  ```bash
  # 이 노드의 kubelet도 수동으로 업그레이드
  $ apt-mark unhold kubelet kubectl
  $ apt-get update && apt-get install -y kubelet=1.29.0-1.1 kubectl=1.29.0-1.1
  $ apt-mark hold kubelet kubectl

  # kubelet 재시작
  systemctl daemon-reload
  systemctl restart kubelet
  ```
