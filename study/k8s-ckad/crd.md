# CRD (Custom Resource Definition) 문제 해설

## 1. 개념 정리

### Custom Resource란?

> 기본 쿠버네티스 설치에서는 제공되지 않는 **쿠버네티스 API의 확장판**

쿠버네티스 기본 리소스 vs 커스텀 리소스:

| 기본 리소스                    | 커스텀 리소스               |
| ------------------------------ | --------------------------- |
| `Pod`, `Deployment`, `Service` | 사용자가 직접 정의한 리소스 |
| 기본 설치 시 제공              | CRD를 통해 추가             |
| `apps/v1` 등 기본 API 그룹     | 사용자 정의 API 그룹        |

## 2. 주요 용어

| 용어        | 설명                                                    |
| ----------- | ------------------------------------------------------- |
| **CRD**     | 커스텀 리소스의 **설계도** (어떤 필드를 가질지 정의)    |
| **CR**      | CRD를 바탕으로 실제 **생성된 리소스**                   |
| **served**  | API 서버가 해당 버전으로 요청을 **받을 수 있는지** 여부 |
| **storage** | etcd에 **저장되는 버전**인지 여부 (하나만 `true` 가능)  |
| **scope**   | 리소스 범위 (`Namespaced` or `Cluster`)                 |

```yaml
versions:
  - name: v1
    served: true # v1으로 kubectl 명령어 사용 가능
    storage: true

  - name: v1beta1
    served: false # v1beta1은 더 이상 API 요청 불가
    storage: false
---
versions:
  - name: v1
    served: true
    storage: true # ← etcd에는 v1으로 저장

  - name: v1beta1
    served: true # ← API 요청은 v1beta1로도 받음
    storage: false # ← 하지만 저장은 v1으로만 함
```

## 3. 문제

`/root/crd.yaml`의 미완성 CRD 매니페스트를 완성하여  
`internals.datasets.kodekloud.com` 이름의 **네임스페이스 범위 CRD**를 정의하세요.

### 요구 스펙

| 항목         | 값                                 |
| ------------ | ---------------------------------- |
| **CRD 이름** | `internals.datasets.kodekloud.com` |
| **그룹**     | `datasets.kodekloud.com`           |
| **스코프**   | `Namespaced`                       |
| **버전**     | `v1`                               |
| **served**   | `true`                             |
| **storage**  | `true`                             |

### 스키마 필드

| 필드명         | 타입    |
| -------------- | ------- |
| `internalLoad` | string  |
| `range`        | integer |
| `percentage`   | string  |

---

**에러 2: `plural` 이름 불일치**

```yaml
# 수정 전
plural: internal    # metadata.name 앞부분과 불일치

# 수정 후
plural: internals   # metadata.name: internals.datasets.kodekloud.com 과 일치
```

> `metadata.name` 규칙: **`{plural}` + `.` + `{group}`** 형식이어야 함

---

## 5. 최종 완성 매니페스트

```yaml
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: internals.datasets.kodekloud.com # plural.group 형식
spec:
  group: datasets.kodekloud.com
  scope: Namespaced # scope 네임스페이스로 지정
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                internalLoad:
                  type: string
                range:
                  type: integer
                percentage:
                  type: string
  names:
    plural: internals # metadata.name 앞부분과 일치해야됨
    singular: internal
    kind: Internal
    shortNames:
      - int
```

---

## 6. 적용 순서

```bash
# 1. CRD 생성
$ kubectl apply -f /root/crd.yaml

# 2. CRD 확인
$ kubectl get crd internals.datasets.kodekloud.com

# 3. 커스텀 리소스 생성
$ cat custom.yaml
---
kind: Internal
apiVersion: datasets.kodekloud.com/v1
metadata:
  name: internal-space
  namespace: default
spec:
  internalLoad: "high"
  range: 80
  percentage: "50"

$ kubectl apply -f /root/custom.yaml

# 4. 생성된 커스텀 리소스 확인
$ kubectl get internals
```

---

## 7. 결과 확인

```
NAME                               CREATED AT
internals.datasets.kodekloud.com   2026-05-26T12:29:23Z
```

# CRD와 Custom Resource 비교 및 작성 방법

## 1. CRD vs Custom Resource 관계

> CRD는 **설계도**, Custom Resource는 **설계도로 만든 실제 물건**

| 구분                | 역할                     | 비유                        |
| ------------------- | ------------------------ | --------------------------- |
| **CRD**             | 리소스의 구조/규칙 정의  | 붕어빵 **틀**               |
| **Custom Resource** | CRD를 바탕으로 실제 생성 | 붕어빵 **틀로 만든 붕어빵** |

---

## 2. CRD 구조 분석

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: globals.traffic.controller # ← [plural].[group] 형식
spec:
  group: traffic.controller # ← apiVersion 앞부분
  scope: Namespaced
  versions:
    - name: v1 # ← apiVersion 뒷부분
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                dataField: # ← spec 필드명
                  type: integer # ← 필드 타입
                access: # ← spec 필드명
                  type: boolean # ← 필드 타입
  names:
    plural: globals
    singular: global
    kind: Global # ← Custom Resource의 kind
```

---

## 3. CRD → Custom Resource 변환 공식

CRD의 각 항목이 Custom Resource의 어디에 대응되는지:

```
CRD                                    Custom Resource
─────────────────────────────────────────────────────
spec.group        traffic.controller ──→ apiVersion: traffic.controller/v1
versions[].name   v1                 ──→
names.kind        Global             ──→ kind: Global
metadata.name     (직접 지정)         ──→ metadata.name: datacenter
spec의 properties dataField, access  ──→ spec:
                                           dataField: 2
                                           access: true
```

---

## 4. 실제 작성 예시

### CRD 확인

```bash
kubectl describe crd globals.traffic.controller
```

```
Group:   traffic.controller
Versions:
  Name: v1
Names:
  Kind: Global
Spec Properties:
  dataField: integer
  access: boolean
```

### Custom Resource 작성

```yaml
apiVersion: traffic.controller/v1 # group/version
kind: Global # CRD의 names.kind
metadata:
  name: datacenter # 원하는 이름
spec:
  dataField: 2 # CRD 스키마의 필드
  access: true # CRD 스키마의 필드
```

---

## 5. 일반 리소스와 구조 비교

```yaml
# 일반 Deployment               # Custom Resource
apiVersion: apps/v1             apiVersion: traffic.controller/v1
kind: Deployment                kind: Global
metadata:                       metadata:
  name: my-app                    name: datacenter
spec:                           spec:
  replicas: 3                     dataField: 2
  selector: ...                   access: true
```

> 구조가 완전히 동일하고, `apiVersion`과 `kind`만 다릅니다.

---

## 6. 타입별 값 작성 방법

CRD 스키마의 타입에 따라 값을 다르게 작성합니다:

| CRD 타입  | 작성 예시       |
| --------- | --------------- |
| `string`  | `name: "nginx"` |
| `integer` | `replicas: 3`   |
| `boolean` | `access: true`  |

---

## 7. 적용 및 확인

```bash
# 1. 파일 작성
vi custom.yaml

# 2. 적용
kubectl apply -f custom.yaml

# 3. 확인 (plural 이름 사용)
kubectl get globals

# 4. 상세 확인
kubectl describe global datacenter
```

---

## 8. 전체 흐름 요약

```
CRD 생성 (설계도)
      ↓
kubectl describe crd {crd이름}  →  group, version, kind, 필드 확인
      ↓
Custom Resource yaml 작성
  apiVersion: {group}/{version}
  kind: {kind}
  metadata.name: {원하는 이름}
  spec: {CRD 스키마 필드들}
      ↓
kubectl apply -f custom.yaml
      ↓
kubectl get {plural}  →  생성 확인
```
