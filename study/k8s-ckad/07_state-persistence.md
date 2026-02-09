# Docker Storage

- Storage Driver
  - 컨테이너 내부 파일시스템을 어떻게 관리할지
- Volume Driver
  - 컨테이너 밖의 데이터를 어디에 어떻게 저장할지

## Storage in Docker

- Docker file system
  ```bash
  /var/lib/docker
  ├── overlay2
  ├── containers
  ├── image
  └── volumes
  ```

### Layered Architecture

- Dockerfile 1
  ```docker
  FROM Ubuntu
  RUN apt-get update && apt-get -y install python
  RUN pip install flask flask-mysql
  COPY . /opt/source-code
  ENTRYPOINT FLASK_APP=/opt/source-code/app.py flask run
  ```
  ```bash
  docker build Dockerfile -t flask/my-custom-app
  # Layer 1. Base Ubuntu Layer        120MB
  # Layer 2. Change in apt packages   360MB
  # Layer 3. Change in pip packages   6.3MB
  # Layer 4. Source code              229B
  # Layer 5. Update Entrypoint        0B
  ```
- Dockerfile 2
  - 같은 레이어는 이전에 빌드한 레이어를 재사용하므로 이미지를 재빌드 및 업데이트 시 시간을 많이 절약할 수 있음

  ```docker
  FROM Ubuntu
  RUN apt-get update && apt-get -y install python
  RUN pip install flask flask-mysql
  COPY app2.py /opt/source-code
  ENTRYPOINT FLASK_APP=/opt/source-code/app2.py flask run
  ```

  ```bash
  docker build Dockerfile -t flask/my-custom-app
  # Layer 1. Base Ubuntu Layer        0MB
  # Layer 2. Change in apt packages   0MB
  # Layer 3. Change in pip packages   0MB
  # Layer 4. Source code              229B
  # Layer 5. Update Entrypoint        0B
  ```

- docker build로 생성된 위의 레이어를 `Image Layer`라고 하며, *Read Only*의 형태로 마운트됨
- docker run으로 생성된 레이어를 `Container Layer`라고 하며 _Read Write_ 형태로 마운트되고, 컨테이너가 삭제되면 안의 모든 내용도 삭제됨

### Volume

도커 볼륨 마운트

- docker volume으로 볼륨을 생성 시 `/var/lib/docker`경로에 영구 볼룜이 생성됨
- 관리 주체가 도커 엔진임

  ```bash
  ## 도커 볼륨 마운트
  $ docker volume create data_volume
  $ tree
  /var/lib/docker
    ├── volumes
    │   └── data_volume
    └── ...

  # 도커 컨테이너에 마운트
  $ docker run -v data_volume:/var/lib/mysql mysql
  ```

도커 바인드 마운트

- 호스트(내 컴퓨터)의 특정 디렉토리를 컨테이너에 직접 연결하는 방식
- 관리 주체가 사용자가 됨

  ```bash
  docker run -v /home/user/project:/app ubuntu

  docker run --mount type=bind,source=/home/user/project,target=/app ubuntu
  ```

# Volume Driver Plugins in Docker

### 스토리지 드라이버

- Docker 컨테이너의 이미지와 컨테이너 파일시스템을 관리하는 드라이버
  - 컨테이너 내부의 / 파일 시스템이 어떻게 저장되고 동작할지를 담당
- 대상
  - 이미지 레이어
  - 컨테이너 레이어
  - overlay 구조(overlay2가 표준)

### 볼륨 드라이버

- docker volume 데이터를 어디에 저장할지 결정하는 플러그인
- 대상
  - docker volume 데이터(컨테이너 외부 persistent data)
  - 외부 스토리지 연결(NFS, EBS, Ceph등)
- 드라이버 종류
  - local(기본값) : 로컬 디스크에 저장
  - nfs : NFS 서버 마운트
  - ceph, glusterfs 등

# Stateful Sets

- statefulset은 replica가 2일 때 파드가 순차적으로 실행하고 ready 상태 일 때 다음 파드가 실행됨
- podManagementPolicy 항목을 통해 파드를 하나씩 순서대로 만들지, 동시에 만들지 정할 수 있음
  - OrderedReady(기본값)
    - 파드를 순서대로 하나씩 생성
      - pod-0 생성
      - pod-0이 ready 상태가 될 때까지 대기
      - pod-1 생성
      - pod-1이 ready 상태가 될 때까지 대기
    - 파드를 삭제 시 역순으로 삭제 됨
      - pod-1부터 삭제 후 pod-0 삭제
  - Parallel
    - deployment와 동일한 방식으로 생성됨
    - 파드를 동시에 생성 가능
      - pod-0, pod-1이 한번에 생성
    - 파드를 삭제 시 동시에 삭제 가능

# Headless Services

- ClusterIP가 없는 서비스
- 로드밸런싱을 하지 않고 각각의 POD에 직접 접근 가능
- DNS를 Pod 단위로 제공하는 서비스

| 구분           | 일반 Service          | Headless Service   |
| -------------- | --------------------- | ------------------ |
| ClusterIP 존재 | 있음                  | 없음               |
| 접근 방식      | 하나의 대표 IP로 접근 | Pod 각각 직접 접근 |
| 로드밸런싱     | 자동 분산             | 없음               |
| DNS 결과       | Service IP 반환       | Pod IP 목록 반환   |
| 사용 목적      | Stateless 앱          | Stateful 앱        |

### Headless 서비스를 사용하는 이유

- 일반 서비스는 항상 하나의 IP로 트래픽을 분산
- DB 클러스터의 경우 Master에만 쓰기 요청을 보내야되므로 마스터 DB 파드에만 직접 접근 필요
- headless service가 있다면 mysql-0, mysql-1, mysql-2 파드의 DNS는 아래와 같이 생성됨

  ```bash
  # headless 서비스 pod
  mysql-0.mysql-headless.default.svc.cluster.local
  mysql-1.mysql-headless.default.svc.cluster.local
  mysql-2.mysql-headless.default.svc.cluster.local

  # 일반 서비스 pod
  pod-ip-address.service-name.my-namespace.svc.cluster-domain.example.


  172-17-0-3.default.pod.cluster.local
  mysql-1.default.svc.cluster.local
  mysql-2.default.svc.cluster.local
  ```

- headless service 사용 예시

  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: mysql-headless
    namespace: default
  spec:
    clusterIP: None # Headless 핵심
    selector:
      app: mysql
    ports:
      - name: mysql
        port: 3306
        targetPort: 3306

  ---
  apiVersion: apps/v1
  kind: StatefulSet
  metadata:
    name: mysql
  spec:
    serviceName: mysql-headless # headless 서비스 이름
    replicas: 3
    selector:
      matchLabels:
        app: mysql
    template:
      metadata:
        labels:
          app: mysql
      spec:
        containers:
          - name: mysql
            image: mysql:8
            ports:
              - name: mysql
                containerPort: 3306
  ```
