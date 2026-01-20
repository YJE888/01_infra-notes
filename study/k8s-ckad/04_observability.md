# Observability

- POD Conditions
  - PodScheduled
  - Initialized
  - ContainersReady
  - Ready

## Readiness Probes

- 컨테이너가 트래픽을 받을 준비가 되었는지 확인
- 실패 시 Pod는 살아있지만(Service에서 제외) 상태가 됨
- 재시작은 발생하지 않음 (livenessProbe와 가장 큰 차이)
- jenkins의 경우 상태가 ready이지만 실제로 jenkins web ui를 기동하는데 오랜 시간이 필요함
  - 이 때, 트래픽이 파드로 전달되는 경우 연결이 실패하게 됨

### 서비스 준비 상태 확인 방법

- 웹서버의 경우 HTTP Test인 /api/ready 등으로 확인 가능
  ```yaml
  readinessProbe:
    httpGet:
      path: /api/ready
      port: 8080
    initialDelaySeconds: 10 # 컨테이너 시작 후 첫 readiness 체크를 10초 뒤에 실행
    periodSeconds: 5 # readiness 체크를 5초 간격으로 반복 수행
    failureThreshold: 8 # 연속으로 8번 실패해야 pod를 NotReady 상태로 판단, 기본값은 3번
  ```
- 데이터베이스의 경우 TCP Test인 3306번 포트 등으로 확인 가능
  ```yaml
  readinessProbe:
    tcpSocket:
      port: 3306
  ```
- 커스텀 스크립트를 실행해서 준비가 됐는지도 확인 가능
  ```yaml
  readinessProbe:
    exec:
      command:
        - cat
        - /app/is_ready
  ```

## Liveness Probes

- 컨테이너가 정상적으로 살아있는지(멈추지 않았는지) 확인
- 실패 시 컨테이너를 비정상 상태로 판단하고, 컨테이너 재시작이 발생함
- 재시작 과정에서 Pod는 일시적으로 Service 트래픽에서 제외됨

### 서비스 준비 상태 확인 방법

- 웹서버의 경우 HTTP Test인 /api/ready 등으로 확인 가능
  ```yaml
  livenessProbe:
    httpGet:
      path: /api/ready
      port: 8080
    initialDelaySeconds: 10 # 컨테이너 시작 후 첫 readiness 체크를 10초 뒤에 실행
    periodSeconds: 5 # readiness 체크를 5초 간격으로 반복 수행
    failureThreshold: 8 # 연속으로 8번 실패해야 pod를 NotReady 상태로 판단, 기본값은 3번
  ```
- 데이터베이스의 경우 TCP Test인 3306번 포트 등으로 확인 가능
  ```yaml
  livenessProbe:
    tcpSocket:
      port: 3306
  ```
- 커스텀 스크립트를 실행해서 준비가 됐는지도 확인 가능
  ```yaml
  livenessProbe:
    exec:
      command:
        - cat
        - /app/is_ready
  ```

## Logging

### Docker 환경

- 로그 확인 커맨드

  ```bash
  $ docker run -d kodekloud/event-simulator

  $ docker logs -f ecf
  ```

### Kubernetes 환경

- 로그 확인 커맨드

  ```bash
  $ kubectl logs -f event-simulator-pod

  $ k logs --tail 100 webapp-1
  ```

- 컨테이너가 두 개일 때 컨테이너명까지 지정해야됨
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: event-simulator-pod
  spec:
    containers:
      - name: event-simulator
        image: kodekloud/event-simulator
      - name: image-processor
        image: some-image-processor
  ```
  ```bash
  $ kubectl logs -f event-simulator-pod event-simulator
  ```

## Monitor and Debug Applications

- Kubernetes는 완전한 기능을 갖춘 기본 내장 모니터링 솔루션을 제공하지 않음
- `Metrics Server`, `Prometheus`, `Elastic Stack`과 같은 오픈소스 솔루션과 `Datadog`, `Dynatrace`와 같은 상용(독점) 모니터링 솔루션을 함께 활용할 수 있음
- Metrics Server
  - 쿠버네티스가 현재 시점의 CPU 및 메모리 사용량을 확인하기 위해 사용하는 컴포넌트
  - 메트릭을 디스크에 저장하지 않고 메모리(in-memory)에만 유지하는 실시간 메트릭 수집기
  - 주로 `HPA(Horizontal Pod Autoscaler)` 및 kubectl top 기능을 지원하는 용도로 사용됨
  - 쿠버네티스는 각 노드에서 kubelet이라는 에이전트를 실행하고, kubelet에는 서브 컴포넌트로 `cAdvisor`(Container Advisor)가 포함되어 있음
  - cAdvisor는 각 Pod 및 컨테이너의 리소스 사용량(CPU, 메모리 등) 을 수집하고 해당 메트릭을 Kubelet API를 통해 노출하여 Metrics Server가 이를 활용할 수 있도록 함

  ```bash
  $ kubectl top nodes

  $ kubectl top pods
  ```
