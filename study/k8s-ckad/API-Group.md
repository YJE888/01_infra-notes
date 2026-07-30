# API Group

- 문제
  ```text
  controlplane 노드에서 rbac.authorization.k8s.io API 그룹의 v1alpha1 버전을 활성화하세요.
  ```
- 해설
  - `v1alpha1` 버전은 기본적으로 비활성화 되어 있기 때문에, `--runtime-config` 옵션으로 명시적으로 활성화 해야됨
  - 기존 `rbac.authorization.k8s.io` API 그룹
    ```bash
    $ k api-resources | grep rbac.authorization.k8s.io
    clusterrolebindings                              rbac.authorization.k8s.io/v1      false        ClusterRoleBinding
    ```

    - `v1` : 안정화된 정식버전
    - `v1beta1` : 베타버전(거의 안정)
    - `v1aplha1` : 알파버전(실험적, 기본 비활성화)
- `kube-apiserver` manifest 수정
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    annotations:
      kubeadm.kubernetes.io/kube-apiserver.advertise-address.endpoint: 10.244.220.237:6443
    labels:
      component: kube-apiserver
      tier: control-plane
    name: kube-apiserver
    namespace: kube-system
  spec:
    containers:
      - command:
          - kube-apiserver
          - --advertise-address=10.244.220.237
          - --runtime-config=rbac.authorization.k8s.io/v1alpha1=true # 내용 추가
  ```

# Kubectl convert

- 쿠버네티스 API 버전이 올라가면서 구버전 manifest를 신버전으로 변환해주는 플러그인

  ```yaml
  # 구버전
  apiVersion: apps/v1beta1

  # convert 후 신버전으로 자동 변환
  apiVersion: apps/v1
  ```

- 문제 해결

  ```bash
  # 오래된 apiVersion이 명시되어 있는 yaml 파일
  $ cat ingress-old.yaml
  ---
  # Deprecated API version
  apiVersion: networking.k8s.io/v1beta1
  kind: Ingress
  metadata:
    name: ingress-space
    annotations:
      nginx.ingress.kubernetes.io/rewrite-target: /
  spec:
    rules:
    - http:
        paths:
        - path: /video-service
          pathType: Prefix
          backend:
            serviceName: ingress-svc
            servicePort: 80

  # convert 후 신버전으로 자동 변환된 파일 내용 확인
  $ kubectl convert -f ingress-old.yaml
  apiVersion: networking.k8s.io/v1 # convert 후 신버전으로 자동 변환
  kind: Ingress
  metadata:
    annotations:
      nginx.ingress.kubernetes.io/rewrite-target: /
    name: ingress-space
  spec:
    rules:
    - http:
        paths:
        - backend:
            service:
              name: ingress-svc
              port:
                number: 80
          path: /video-service
          pathType: Prefix
  status:
    loadBalancer: {}

  # 생성
  $ kubectl convert -f ingress-old.yaml  | kubectl create -f -
  ```
