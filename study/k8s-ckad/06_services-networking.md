# Services & Networking

- 쿠버네티스는 기본적으로 모든 파드에서 클러스터 내의 다른 파드 또는 서비스로 트래픽을 허용하는 all alow 규칙으로 구성되어 있음

## Network Policies

- Network Policy가 생성되면 파드에 대한 다른 모든 트래픽을 차단하고, 지정된 규칙과 일치하는 트래픽만 허용하게 됨
- network policy는 `kube-router`, `calico`, `romana` 등에서 지원되며, `flannel`에서는 지원되지 않음

## Developing Network Policies

<img src="./images/network-policy.png" width="80%">

- 첫 번째 규칙의 두 개의 selector는 and 조건으로 동작하고, 첫 번째와 두 번째 규칙은 or 조건으로 동작
  - DB 파드에 대해 Ingress 트래픽 중 파드의 레이블이 api-pod면서 namespace가 prod 인 파드만 허용
  - DB 파드에 대해 ip가 192.168.5.10인 백업 서버는 접근 허용

## Ingress Networking
