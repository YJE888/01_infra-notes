# 커스터마이즈
- [가이드 문서](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/)
- 처음 YAML 파일을 개발하는 것이 어렵고 그 이후에는 보통 컨테이너 이미지 태그 버전을 바꾸거나, 사본(Replica) 수 또는 설정 값(configmap) 변경 등의 작은 업데이트만 발생함
  - 이런 사항을 변경하다보면 잦은 실수가 발생
- 자주 변경되지 않는 매니페스트를 하나 두고, 자주 변경되는 파라미터를 설정하기 위한 파일만 환경별로 하나씩 정의

## 커스터마이즈를 사용한 쿠버네티스 리소스 배포
- 커스터마이즈를 사용하려면 쿠버네티스 리소스 파일을 담은 기본 디렉터리를 만들고 리소스와 커스터마이즈 세부사항을 담는 kustomization.yaml 파일을 만들어야됨
### 쿠버네티스 리소스 파일 생성
```bash
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  creationTimestamp: null
  name: pacman

# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: pacman-kikd
  name: pacman-kikd
  namespace: pacman
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pacman-kikd
  template:
    metadata:
      labels:
        app: pacman-kikd
    spec:
      containers:
      - image: lordofthejars/pacman-kikd:1.0.0
        name: pacman-kikd
        ports:
        - containerPort: 8080

# service.yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: pacman-kikd
  name: pacman-kikd
  namespace: pacman
spec:
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  selector:
    app: pacman-kikd
```
### kustomization.yaml 파일 생성
```bash
$ kustomize create --autodetect

# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization # kustomization 파일
resources: # 애플리케이션에 속한 리소스는 깊이 우선(depth-first) 순서로 처리됨
- deployment.yaml
- namespace.yaml
- service.yaml
```
- 적용
```bash
# . 은 kustomization.yaml 파일이 있는 위치를 현재 디렉터리로 지정
$ k apply --dry-run=client -o yaml -k .
```
```yaml
apiVersion: v1
items: # kustomization.yaml에 정의된 모든 쿠버네티스 객체 목록
- apiVersion: v1
  kind: Namespace # namespace 객체
  metadata:
    annotations:
      kubectl.kubernetes.io/last-applied-configuration: |
        {"apiVersion":"v1","kind":"Namespace","metadata":{"annotations":{},"creationTimestamp":null,"name":"pacman"}}
    name: pacman
- apiVersion: v1
  kind: Service # service 객체
  metadata:
    annotations:
      kubectl.kubernetes.io/last-applied-configuration: |
        {"apiVersion":"v1","kind":"Service","metadata":{"annotations":{},"labels":{"app":"pacman-kikd"},"name":"pacman-kikd","namespace":"pacman"},"spec":{"ports":[{"name":"http","port":8080,"targetPort":8080}],"selector":{"app":"pacman-kikd"}}}
    labels:
      app: pacman-kikd
    name: pacman-kikd
    namespace: pacman
  spec:
    ports:
    - name: http
      port: 8080
      targetPort: 8080
    selector:
      app: pacman-kikd
- apiVersion: apps/v1
  kind: Deployment # deployment 객체
  metadata:
    annotations:
      kubectl.kubernetes.io/last-applied-configuration: |
        {"apiVersion":"apps/v1","kind":"Deployment","metadata":{"annotations":{},"labels":{"app":"pacman-kikd"},"name":"pacman-kikd","namespace":"pacman"},"spec":{"replicas":1,"selector":{"matchLabels":{"app":"pacman-kikd"}},"template":{"metadata":{"labels":{"app":"pacman-kikd"}},"spec":{"containers":[{"image":"lordofthejars/pacman-kikd:1.0.0","name":"pacman-kikd","ports":[{"containerPort":8080}]}]}}}}
    labels:
      app: pacman-kikd
    name: pacman-kikd
    namespace: pacman
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: pacman-kikd
    template:
      metadata:
        labels:
          app: pacman-kikd
      spec:
        containers:
        - image: lordofthejars/pacman-kikd:1.0.0
          name: pacman-kikd
          ports:
          - containerPort: 8080
kind: List
metadata: {}
```
```bash
# 적용
$ k apply -k .
namespace/pacman created
service/pacman-kikd created
deployment.apps/pacman-kikd created
```
- 루트의 kustomization.yaml 파일로 base의 kustomization.yaml도 적용이 가능함
```bash
.
├── base
│   ├── deployment.yaml
│   └── kustomization.yaml
├── kustomization.yaml
└── configmap.yaml

# ./kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization 
resources: 
- ./base
- ./configmap.yaml

# ./base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization 
resources: 
- ./deployment.yaml
```

## 커스터마이즈를 활용하여 컨테이너 이미지 업데이트
- [커스터마이즈 참고 문서](https://kubernetes.io/ko/docs/tasks/manage-kubernetes-objects/kustomization/#%EC%82%AC%EC%9A%A9%EC%9E%90-%EC%A0%95%EC%9D%98)
- 기존 1.0.0 태그를 1.0.1로 변경
- `kustomize.yaml`
```yaml
# 기존 deployment.yaml의 이미지명
# - image: lordofthejars/pacman-kikd:1.0.0
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- namespace.yaml
- service.yaml

images: 
- name: lordofthejars/pacman-kikd
  newTag: "1.0.1" # 새로운 태그
```
- dry-run으로 출력 결과물에 새 태그가 포함되어 있는지 확인
```bash
$ kustomize build .
...
apiVersion: apps/v1
kind: Deployment
metadata:
...
    spec:
      containers:
      - image: lordofthejars/pacman-kikd:1.0.1 # 이미지 변경 확인
        name: pacman-kikd
        ports:
        - containerPort: 8080
```
- 선언적으로 변경하는 방법
  - kustomization.yaml 파일과 같은 디렉터리에서 아래의 명령을 실행
```bash
$ kustomize edit set image lordofthejars/pacman-kikd:1.0.2

# kustomization.yaml의 이미지 버전이 변경되어 있음
$ grep -A2 'images:' kustomization.yaml 
images:
- name: lordofthejars/pacman-kikd
  newTag: 1.0.2
```
## 커스터마이즈를 통한 임의의 쿠버네티스 필드 업데이트
- 커스터마이즈를 사용하여 replicas 등의 쿠버네티스 필드 업데이트
- 방법 1
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- namespace.yaml
- service.yaml

patches:                      # 패치 리소스
  - target:                   # 변경해야되는 쿠버네티스 객체 지정
      group: apps
      version: v1           
      kind: Deployment
      name: pacman-kikd
    patch: |-                 # 패치 표현식
      - op: replace           # 적용할 연산
        path: /spec/replicas  # spec.replicas를 변경
        value: 3              # 새 값
```
- 방법 2
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- namespace.yaml
- service.yaml

replicas:
- name: pacman-kikd
  count: 3
```
```bash
$ kustomize build .
apiVersion: apps/v1
kind: Deployment
metadata:
...
  name: pacman-kikd
  namespace: pacman
spec:
  replicas: 3
...
```
- 값을 추가하거나 지우는 방법
- 방법 1
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- namespace.yaml
- service.yaml

replicas:
- name: pacman-kikd
  count: 3

patches:
  - target:
      group: apps
      version: v1      
      kind: Deployment
      name: pacman-kikd
      namespace: pacman
    patch: |-
      - op: add
        path: /metadata/labels/cat
        value: animal
```
- 방법 2
- `external_patch.yaml`
```yaml
- op: replace
  path: /spec/replicas
  value: 3
- op: add
  path: /metadata/labels/cat
  value: animal
```
- `kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- namespace.yaml
- service.yaml

patches:
  - target:
      group: apps
      version: v1      
      kind: Deployment
      name: pacman-kikd
      namespace: pacman
    path: external_patch.yaml
```
```bash
$ kustomize build .
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: pacman-kikd
    cat: animal # 추가됨
  name: pacman-kikd
  namespace: pacman
spec:
  replicas: 3 # 변경됨
```
- 전략적 머지 패치(patchesStrategicMerge)
- Deployment의 컨테이너 이미지(image)를 바꾸는 방법은 원본 Deployment에서 바꾸고 싶은 부분만 최소 YAML로 덮어쓰기
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- namespace.yaml
- service.yaml

patches:
  - target:
      labelSelector: "app=pacman-kikd" # 레이블을 사용하여 대상을 선택
      kind: Deployment
    patch: |-
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: pacman-kikd
      spec:
        template:
          spec:
            containers:
            - name: pacman-kikd
              image: lordofthejars/pacman-kikd:1.2.0 # 변경이 필요한 정보만 수정
```
## 다중 환경 배포
