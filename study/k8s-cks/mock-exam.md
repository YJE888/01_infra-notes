# Foundation - Containers under the hood

## Container Namespaces Docker

다음 속성을 가진 두 개의 Docker 컨테이너 `app1`과 `app2`를 실행하세요:

- `nginx:alpine` 이미지를 실행해야 합니다
- 동일한 PID 커널 네임스페이스를 공유해야 합니다
- `sleep infinity` 명령을 실행해야 합니다
- 백그라운드(detached 모드)에서 실행되어야 합니다

그런 다음 각 컨테이너가 어떤 프로세스를 볼 수 있는지 확인하고, 그 이유를 이해해 보세요.

```bash
# $ docker run --help
# Usage:  docker run [OPTIONS] IMAGE [COMMAND] [ARG...]

$ docker run --name app1 -d nginx:alpine sleep infinity

# app1 단독 실행
$ docker exec app1 ps aux
PID   USER     TIME  COMMAND
    1 root      0:00 sleep infinity # app1의 프로세스
    7 root      0:00 ps aux

$ $ocker run --name app2 --pid=container:app1 -d nginx:alpine sleep infinity

$ docker exec app1 ps aux
PID   USER     TIME  COMMAND
    1 root      0:00 sleep infinity
   13 root      0:00 sleep infinity
   19 root      0:00 ps aux

$ docker exec app2 ps aux
PID   USER     TIME  COMMAND
    1 root      0:00 sleep infinity # app1의 sleep infinity
   13 root      0:00 sleep infinity # app2의 sleep infinity
   25 root      0:00 ps aux # 각각의 docker exec로 띄운 ps aux
```

- app1만 실행
  - app1은 자기만의 새 PID 네임스페이스를 만들었고, 그 안에서 `sleep`이 PID가 1이 됨
  - 호스트의 다른 프로세스는 보이지 않음
- app2를 `--pid=container:app1`로 실행
  - 새 PID 네임스페이스를 만들지 말고 app1의 네임스페이스에 들어가라는 의미
  - `app2`의 `sleep`은 PID 1이 되지 못하고, app1 네임스페이스 안에서 다음 번호인 PID 13을 받음
- 사용자가 `kill`로 상대 컨테이너 프로세스를 종료할 수 있는 문제 발생

## Container Namespaces Podman

다음 속성을 가진 두 개의 Podman 컨테이너 `app1`과 `app2`를 실행하세요:

- `nginx:alpine` 이미지를 실행해야 합니다
- 동일한 PID 커널 네임스페이스를 공유해야 합니다
- `sleep infinity` 명령을 실행해야 합니다
- 백그라운드(detached 모드)에서 실행되어야 합니다

그런 다음 각 컨테이너가 어떤 프로세스를 볼 수 있는지 확인하고, 그 이유를 이해해 보세요.

```bash
$ podman run -d --name app1 nginx:alpine sleep infinity

$ podman ps
CONTAINER ID  IMAGE                           COMMAND         CREATED         STATUS         PORTS       NAMES
dcd30e8afab8  docker.io/library/nginx:alpine  sleep infinity  56 seconds ago  Up 56 seconds              app1
$ podman exec app1 ps aux
PID   USER     TIME  COMMAND
    1 root      0:00 sleep infinity
    5 root      0:00 ps aux

$ podman run --help | grep -i pid
      --pid string                               PID namespace to use

$ podman run -d --name app2 --pid=container:app1 nginx:alpine sleep infinity

$ podman exec app1 ps aux
PID   USER     TIME  COMMAND
    1 root      0:00 sleep infinity
    9 root      0:00 sleep infinity
   13 root      0:00 ps aux

$ podman exec app2 ps aux
PID   USER     TIME  COMMAND
    1 root      0:00 sleep infinity
    9 root      0:00 sleep infinity
   18 root      0:00 ps aux
```

# Cluster Setup - Network Policies

## NetworkPolicy Create Default Deny

Namespace `app`에 기존 Pod들이 있습니다.
Namespace `app`에 있는 Pod들에서 나가는 모든 트래픽(egress)에 대해 `deny-out`이라는 이름의 새로운 기본 거부(default-deny) NetworkPolicy가 필요합니다.
단, 포트 `53`의 TCP 및 UDP DNS 트래픽은 계속 허용되어야 합니다.

```yaml
# netpol.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-out
  namespace: app
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - ports:
        - protocol: TCP
          port: 53
        - protocol: UDP
          port: 53
```

- ports는 리스트 형식으로 UDP와 TCP를 분리하여 작성(대시 두 개)
- 확인

```bash
# these should fail
k -n app exec app1-0 -- curl www.google.com
k -n app exec microservice1-0 -- curl www.google.com
k -n app exec app1-0 -- curl microservice1
k -n app exec microservice1-0 -- curl app1

# DNS should still work
k -n app exec app1-0 -- nslookup www.google.com
k -n app exec microservice1-0 -- nslookup www.google.com
k -n app exec app1-0 -- nslookup microservice1
k -n app exec microservice1-0 -- nslookup app1

# ingress
# these should still work
k -n default run nginx --image=nginx:1.21.5-alpine --restart=Never -i --rm  -- curl app1.app.svc.cluster.local
k -n default run nginx --image=nginx:1.21.5-alpine --restart=Never -i --rm  -- curl microservice1.app.svc.cluster.local
```

## NetworkPolicy Namespace Selector

Namespace `space1`과 `space2`에 기존 Pod들이 있습니다.

Namespace `space1`에 있는 모든 Pod가 오직 Namespace `space2`에 있는 Pod로만 나가는 트래픽(outgoing)을 가지도록 제한하는 `np`라는 이름의 새로운 NetworkPolicy가 필요합니다. 들어오는 트래픽(incoming)은 영향을 받지 않아야 합니다.

또한 Namespace `space2`에 있는 모든 Pod가 오직 Namespace `space1`에 있는 Pod로부터만 들어오는 트래픽(incoming)을 받도록 제한하는 `np`라는 이름의 새로운 NetworkPolicy가 필요합니다. 나가는 트래픽(outgoing)은 영향을 받지 않아야 합니다.

이 NetworkPolicy들은 포트 `53`의 TCP 및 UDP DNS 트래픽은 계속 모두 허용해야 합니다.

```bash
$ k get ns --show-labels
NAME                 STATUS   AGE     LABELS
space1               Active   44m     kubernetes.io/metadata.name=space1
space2               Active   44m     kubernetes.io/metadata.name=space2
```

```yaml
# netpol-1.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: np
  namespace: space1
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: space2
    - ports:
        - port: 53
          protocol: TCP
        - port: 53
          protocol: UDP
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: np
  namespace: space2
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: space1
```

```bash
# these should work
k -n space1 exec app1-0 -- curl -m 1 microservice1.space2.svc.cluster.local
k -n space1 exec app1-0 -- curl -m 1 microservice2.space2.svc.cluster.local
k -n space1 exec app1-0 -- nslookup tester.default.svc.cluster.local
k -n kube-system exec -it validate-checker-pod -- curl -m 1 app1.space1.svc.cluster.local

# these should not work
k -n space1 exec app1-0 -- curl -m 1 tester.default.svc.cluster.local
k -n kube-system exec -it validate-checker-pod -- curl -m 1 microservice1.space2.svc.cluster.local
k -n kube-system exec -it validate-checker-pod -- curl -m 1 microservice2.space2.svc.cluster.local
k -n default run nginx --image=nginx:1.21.5-alpine --restart=Never -i --rm  -- curl -m 1 microservice1.space2.svc.cluster.local
```

# Cluster Setup - Secure Ingress

## Ingress Create

Namespace `world`에 Ingress를 통해 접근할 수 있도록 만들어야 하는 기존 Deployment 두 개가 있습니다.
먼저: 두 Deployment 모두에 대해 포트 `80`용 ClusterIP Service를 생성하세요. Service 이름은 Deployment와 동일해야 합니다.

```bash
$ k get deployments.apps -n world
NAME     READY   UP-TO-DATE   AVAILABLE   AGE
asia     2/2     2            2           81s
europe   2/2     2            2           81s

$ k expose deployment -n world asia --port 80
service/asia exposed

$ k expose deployment -n world europe --port 80
service/europe exposed

$ k get svc -n world
NAME     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
asia     ClusterIP   10.109.61.12    <none>        80/TCP    17s
europe   ClusterIP   10.98.201.127   <none>        80/TCP    6s
```

Nginx Ingress Controller가 설치되어 있습니다.
도메인 이름 `world.universe.mine`에 대해 `world`라는 이름의 새로운 Ingress 리소스를 생성하세요. 이 도메인은 `/etc/hosts`를 통해 K8s 노드 IP를 가리킵니다.

Ingress 리소스는 기존 Service들을 가리키는 두 개의 라우트를 가져야 합니다:
`http://world.universe.mine:30080/europe/`
그리고
`http://world.universe.mine:30080/asia/`

```bash
$ k get ingressclasses.networking.k8s.io
NAME    CONTROLLER             PARAMETERS   AGE
nginx   k8s.io/ingress-nginx   <none>       5m35s
```

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: world
  namespace: world
spec:
  ingressClassName: nginx
  rules:
    - host: "world.universe.mine"
      http:
        paths:
          - pathType: Prefix
            path: "/europe"
            backend:
              service:
                name: europe
                port:
                  number: 80
          - pathType: Prefix
            path: "/asia"
            backend:
              service:
                name: asia
                port:
                  number: 80
```

## Ingress Secure

이전 시나리오 [Ingress Create](https://killercoda.com/killer-shell-cks/scenario/ingress-create)를 먼저 해결했는지 확인하세요.

Nginx Ingress Controller가 설치되어 있고, Namespace `world`에 Ingress 리소스가 구성되어 있습니다.
다음 명령으로 애플리케이션에 접근할 수 있습니다:
`curl http://world.universe.mine:30080/europe`

다음 명령으로 새로운 TLS 인증서를 생성하세요:
`openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout cert.key -out cert.crt -subj "/CN=world.universe.mine/O=world.universe.mine"`

Ingress가 새 인증서를 사용하도록 설정하여 다음 명령을 호출할 수 있도록 하세요:
`curl -kv https://world.universe.mine:30443/europe`

curl의 verbose 출력에서 기본 Ingress 인증서가 아닌 새 인증서가 사용되고 있음을 보여줘야 합니다.

```bash
$ k get all -n world
NAME                          READY   STATUS    RESTARTS   AGE
pod/asia-6c47dd4c59-cb7pj     1/1     Running   0          2m59s
pod/asia-6c47dd4c59-t5cjf     1/1     Running   0          2m59s
pod/europe-6d4c9695b7-v7mcd   1/1     Running   0          2m59s
pod/europe-6d4c9695b7-zcqdt   1/1     Running   0          2m59s

NAME             TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/asia     ClusterIP   10.102.70.11     <none>        80/TCP    2m59s
service/europe   ClusterIP   10.106.100.203   <none>        80/TCP    2m59s

NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/asia     2/2     2            2           3m
deployment.apps/europe   2/2     2            2           3m

NAME                                DESIRED   CURRENT   READY   AGE
replicaset.apps/asia-6c47dd4c59     2         2         2       2m59s
replicaset.apps/europe-6d4c9695b7   2         2         2       2m59s

$ curl http://world.universe.mine:30080/europe
hello, you reached EUROPE

$ openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout cert.key -out cert.crt -subj "/CN=world.universe.mine/O=world.universe.mine"
...........+.........+....+.................+.............+..+...+.......+.....+...+.......+...+.....+..........+..+.......+.....+......+......+.+..............+.+.........+.....+......+...+.+...+......+.....+.+...+...........+......+.........+...................+..+.+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*...+...+..+.......+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*..........+..+...+....+...+...+..+...+.+.......................+......+......+...+............+....+.....+......+......+.........+...+.+.....+.+..................+..+.+..+.+.....+...............................+......+...+.........+..+.+...+.........+..+...+...+.......+...+...+......+...+......+......+...........+..........+..+................+..+.......+............+.....+.........+.......+..+.+..+...+.+......+..+..................+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
..+............+..+...+....+........+.+..+.......+.....+.......+...+..+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*..+....+.....+......+...+.+............+.....+...+..........+.........+..+..........+.....+...+......+....+...+..+......+.+...+..+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*........+...+.+.....+.+.....+...+...+....+...+..+.+..+......+...............+...................+......+.........+........+....+...+..+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

$ ls
cert.crt  cert.key  filesystem

$ k create secret tls ssl -n world --cert=./cert.crt --key=./cert.key
secret/ssl created

$ k get secrets -n world
NAME   TYPE                DATA   AGE
ssl    kubernetes.io/tls   2      9s
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: world
  namespace: world
rules:
spec:
  tls: # 추가
    - hosts: # 추가
        - world.universe.mine # 추가
      secretName: ssl # secret 이름 설정
  ingressClassName: nginx
  rules:
    - host: world.universe.mine
      http:
        paths:
          - backend:
              service:
                name: europe
                port:
                  number: 80
            path: /europe
            pathType: Prefix
          - backend:
              service:
                name: asia
                port:
                  number: 80
            path: /asia
            pathType: Prefix
```

```bash
$ curl -m1 -kvI https://world.universe.mine:30443/europe 2>&1 | grep subject | grep world.universe.mine
```

- `-m1` : 최대 1초 타임아웃 (응답이 없으면 바로 실패 처리)
- `-k` : 인증서 검증 무시 (self-signed 인증서라 CA 신뢰 체인이 없어도 진행)
- `-v` : verbose — TLS 핸드셰이크 상세 정보(인증서 subject 포함)를 출력
- `-I` : HEAD 요청만 보내고 응답 본문은 받지 않음 (헤더만 필요하므로 빠름)

# Cluster Setup - Node Metadata Protection

## NetworkPolicy Metadata Protection

클라우드 제공업체들은 중요한 정보를 노출하는 메타데이터 서버(Metadata Server)를 가지고 있을 수 있습니다. 예를 들어 [GCP](https://cloud.google.com/compute/docs/metadata/overview)나 [AWS](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html)가 있습니다.

이 과제에서는 `1.1.1.1`에 메타데이터 서버가 있다고 가정합니다.
`nc -v 1.1.1.1 53` 명령으로 해당 IP로의 연결을 테스트할 수 있습니다.

Namespace `default`에 `metadata-server`라는 이름의 NetworkPolicy를 생성하세요. 이 정책은 `1.1.1.1`을 제외한 모든 IP(`0.0.0.0/0`)로 나가는 트래픽(egress)을 허용해야 합니다.

이 NetworkPolicy는 오직 label `trust=nope`가 있는 Pod에만 영향을 미쳐야 합니다.

```bash
# np.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: metadata-server
  namespace: default
spec:
  podSelector:
    matchLabels:
      trust: nope
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 1.1.1.1/32

# 확인
# these should work
k exec trust-0 -- nc -v -w 1 1.1.1.1 53
k exec trust-0 -- nc -v -w 1 8.8.8.8 53
k exec no-trust-0 -- nc -v -w 1 8.8.8.8 53

# these should not work
k exec no-trust-0 -- nc -v -w 1 1.1.1.1 53
```

# Cluster Setup - CIS Benchmarks

## Cluster Setup - CIS Benchmarks

`kube-bench`를 사용하여 1.2.15 항목의 상태가 PASS인지 확인하세요.

```bash
$ k get node
NAME           STATUS   ROLES           AGE     VERSION
controlplane   Ready    control-plane   7d18h   v1.35.1

# controlplane으로 실행 시 1.2.15 항목이 없음
$ kube-bench run --targets controlplane --check 1.2.15
[INFO] 3 Control Plane Configuration

== Summary controlplane ==
0 checks PASS
0 checks FAIL
0 checks WARN
0 checks INFO

== Summary total ==
0 checks PASS
0 checks FAIL
0 checks WARN
0 checks INFO
```

```bash
$ kube-bench version
0.10.3

$ cd /etc/kube-bench/cfg/

# 쿠버네티스 버전 1.31이 cis-1.10을 사용한다는데 노드는 1.35이므로 가장 최신인 cis-1.10을 사용
$ grep -ir -A18 'version' config.yaml
version_mapping:
  "1.15": "cis-1.5"
  "1.16": "cis-1.6"
  "1.17": "cis-1.6"
  "1.18": "cis-1.6"
  "1.19": "cis-1.20"
  "1.20": "cis-1.20"
  "1.21": "cis-1.20"
  "1.22": "cis-1.23"
  "1.23": "cis-1.23"
  "1.24": "cis-1.24"
  "1.25": "cis-1.7"
  "1.26": "cis-1.8"
  "1.27": "cis-1.9"
  "1.28": "cis-1.9"
  "1.29": "cis-1.9"
  "1.30": "cis-1.10"
  "1.31": "cis-1.10" # 여기서 사용하고 있는 버전
  "eks-1.0.1": "eks-1.0.1"

$ pwd
/etc/kube-bench/cfg/cis-1.10

$ ls
config.yaml  controlplane.yaml  etcd.yaml  master.yaml  node.yaml  policies.yaml

# 1.2.15 id가 명시되어 있는 파일이 master.yaml인지 controlplane.yaml인지 확인
$ grep -ir '1.2.15' .
./master.yaml:      - id: 1.2.15
```

`1.2.15` 항목은 `master.yaml`에 명시되어 있으므로 target은 master로 실행해야됨

```bash
# target 지정 없이 실행 시 해당 버전의 모든 파일을 대상으로 실행
$ kube-bench run --check 1.2.15
[INFO] 1 Control Plane Security Configuration
[INFO] 1.2 API Server
[FAIL] 1.2.15 Ensure that the --profiling argument is set to false (Automated)

== Remediations master ==
1.2.15 Edit the API server pod specification file /etc/kubernetes/manifests/kube-apiserver.yaml
on the control plane node and set the below parameter.
--profiling=false

$ kube-bench run --targets master --check 1.2.15
[INFO] 1 Control Plane Security Configuration
[INFO] 1.2 API Server
[FAIL] 1.2.15 Ensure that the --profiling argument is set to false (Automated)

== Remediations master ==
1.2.15 Edit the API server pod specification file /etc/kubernetes/manifests/kube-apiserver.yaml
on the control plane node and set the below parameter.
--profiling=false


== Summary master ==
0 checks PASS
1 checks FAIL
0 checks WARN
0 checks INFO

== Summary total ==
0 checks PASS
1 checks FAIL
0 checks WARN
0 checks INFO
```

파일 수정

```bash
$ grep -ir 'profiling' -B3 /etc/kubernetes/manifests/kube-apiserver.yaml
  containers:
  - command:
    - kube-apiserver
    - --profiling=false
```

apiserver 재시작 및 확인

```bash
$ ps -ef | grep kube-api
root        8785    8735  3 11:16 ?        00:00:04 kube-apiserver --profiling=false --advertise-address=172.30.1.2 --allow-privileged=true --authorization-mode=Node,RBAC...

$ kill -9 8785

$ crictl ps
CONTAINER           IMAGE               CREATED             STATE               NAME                      ATTEMPT             POD ID              POD                                       NAMESPACE
8feb2ab26b271       6f9eeb0cff981       3 seconds ago       Running             kube-apiserver            1                   308fa5aaa7e51       kube-apiserver-controlplane               kube-system
...

$ kube-bench run --targets master --check 1.2.15
[INFO] 1 Control Plane Security Configuration
[INFO] 1.2 API Server
[PASS] 1.2.15 Ensure that the --profiling argument is set to false (Automated)

== Summary master ==
1 checks PASS
0 checks FAIL
0 checks WARN
0 checks INFO

== Summary total ==
1 checks PASS
0 checks FAIL
0 checks WARN
0 checks INFO
```

`kube-bench`를 사용하여 1.3.2 항목의 상태가 PASS인지 확인하세요.

```bash
$ kube-bench run --targets master --check 1.3.2
[INFO] 1 Control Plane Security Configuration
[INFO] 1.3 Controller Manager
[FAIL] 1.3.2 Ensure that the --profiling argument is set to false (Automated)

== Remediations master ==
1.3.2 Edit the Controller Manager pod specification file /etc/kubernetes/manifests/kube-controller-manager.yaml
on the control plane node and set the below parameter.
--profiling=false


== Summary master ==
0 checks PASS
1 checks FAIL
0 checks WARN
0 checks INFO

== Summary total ==
0 checks PASS
1 checks FAIL
0 checks WARN
0 checks INFO

$ grep -ir 'profiling' -B3 /etc/kubernetes/manifests/kube-controller-manager.yaml
  containers:
  - command:
    - kube-controller-manager
    - --profiling=false

$ kube-bench run --targets master --check 1.3.2
[INFO] 1 Control Plane Security Configuration
[INFO] 1.3 Controller Manager
[PASS] 1.3.2 Ensure that the --profiling argument is set to false (Automated)

== Summary master ==
1 checks PASS
0 checks FAIL
0 checks WARN
0 checks INFO

== Summary total ==
1 checks PASS
0 checks FAIL
0 checks WARN
0 checks INFO
```

`kube-bench`를 사용하여 1.1.19 항목의 상태가 PASS인지 확인하세요.

```bash
root@controlplane:~$ kube-bench run --targets master --check 1.1.19
[INFO] 1 Control Plane Security Configuration
[INFO] 1.1 Control Plane Node Configuration Files
[FAIL] 1.1.19 Ensure that the Kubernetes PKI directory and file ownership is set to root:root (Automated)

== Remediations master ==
1.1.19 Run the below command (based on the file location on your system) on the control plane node.
For example,
chown -R root:root /etc/kubernetes/pki/


== Summary master ==
0 checks PASS
1 checks FAIL
0 checks WARN
0 checks INFO

== Summary total ==
0 checks PASS
1 checks FAIL
0 checks WARN
0 checks INFO

root@controlplane:~$ chown -R root:root /etc/kubernetes/pki
root@controlplane:~$ kube-bench run --targets master --check 1.1.19
[INFO] 1 Control Plane Security Configuration
[INFO] 1.1 Control Plane Node Configuration Files
[PASS] 1.1.19 Ensure that the Kubernetes PKI directory and file ownership is set to root:root (Automated)

== Summary master ==
1 checks PASS
0 checks FAIL
0 checks WARN
0 checks INFO

== Summary total ==
1 checks PASS
0 checks FAIL
0 checks WARN
0 checks INFO
```

# Cluster Setup - Verify Platform Binaries

## Cluster Setup - Verify Platform Binaries

설치된 것과 동일한 버전의 `kubelet` 바이너리를 다운로드하세요.

`wget https://dl.k8s.io/vX.Y.Z/kubernetes-server-linux-amd64.tar.gz`

두 바이너리의 sha 해시를 비교한 뒤 다음과 같이 답하세요:

`echo SAME > /answer` 또는 `echo DIFFERENT > /answer`

```bash
$ which kubelet
/usr/bin/kubelet

$ sha512sum /usr/bin/kubelet
631468b7152cf5da78d6b1b2bc6ffd1ea64b29264aadabdfb2934475e5657db937c882a843e585344a380398414bae9f89643fa2728fc8fe00194661c6ed20ca  /usr/bin/kubelet

$ kubelet --version
Kubernetes v1.35.1

$ wget https://dl.k8s.io/v1.35.1/kubernetes-server-linux-amd64.tar.gz

$ tar xfz kubernetes-server-linux-amd64.tar.gz

$ cd kubernetes/
$ sha512sum server/bin/kubelet
2434f4822134cf810699a745ccb5cec3f0d2d366239a3776c585081c6247c66e1b8c373d01b76487f608a61ee66272d38cfb86d55674d60be5e4098f548cf6bf  server/bin/kubelet


$ HASH1=$(sha512sum /usr/bin/kubelet | awk '{print $1}')
$ echo $HASH1
631468b7152cf5da78d6b1b2bc6ffd1ea64b29264aadabdfb2934475e5657db937c882a843e585344a380398414bae9f89643fa2728fc8fe00194661c6ed20ca

$ HASH2=$(sha512sum server/bin/kubelet | awk '{print $1}')
$ echo $HASH2
2434f4822134cf810699a745ccb5cec3f0d2d366239a3776c585081c6247c66e1b8c373d01b76487f608a61ee66272d38cfb86d55674d60be5e4098f548cf6bf

$ [ "$HASH1" = "$HASH2" ] && echo SAME > /answer || echo DIFFERENT > /answer
DIFFERENT
```

# Cluster Hardening - RBAC

## RBAC ServiceAccount Permissions

`ns1`과 `ns2` 네임스페이스가 이미 존재합니다.
두 네임스페이스 모두에 ServiceAccount `pipeline`을 생성하세요.
이 SA들은 클러스터 전체에서 거의 모든 것을 조회(view)할 수 있어야 합니다. 이를 위해 기본 ClusterRole인 `view`를 사용할 수 있습니다.
이 SA들은 자신의 네임스페이스에서 Deployment를 생성하고 삭제할 수 있어야 합니다.
`kubectl auth can-i`를 사용하여 모든 것을 검증하세요.

```bash
# role verb 확인
$ kubectl api-resources -o wide

$ k get ns ns1 ns2
NAME   STATUS   AGE
ns1    Active   4m39s
ns2    Active   4m39s

$ k create sa pipeline -n ns1
serviceaccount/pipeline created

$ k create sa pipeline -n ns2
serviceaccount/pipeline created

$ k get clusterrole view
NAME   CREATED AT
view   2026-10-03T16:36:59Z

$ k auth can-i delete deployments --as system:serviceaccount:ns1:pipeline -n ns1
no

$ k create clusterrolebinding pipeline-view --clusterrole view --serviceaccount ns1:pipeline --serviceaccount ns2:pipeline

# ClusterRole을 하나 만들고 각 네임스페이스에서 RoleBinding으로 연결하면 재사용할 수 있음
$ k create clusterrole pipeline-deployment --verb create,delete --resource deployments

$ k create rolebinding pipeline-deployment --clusterrole pipeline-deployment --serviceaccount ns1:pipeline -n ns1

$ k create rolebinding pipeline-deployment --clusterrole pipeline-deployment --serviceaccount ns2:pipeline -n ns2
```

- 확인

```bash
# namespace ns1 deployment manager
k auth can-i delete deployments --as system:serviceaccount:ns1:pipeline -n ns1 # YES
k auth can-i create deployments --as system:serviceaccount:ns1:pipeline -n ns1 # YES
k auth can-i update deployments --as system:serviceaccount:ns1:pipeline -n ns1 # NO
k auth can-i update deployments --as system:serviceaccount:ns1:pipeline -n default # NO

# namespace ns2 deployment manager
k auth can-i delete deployments --as system:serviceaccount:ns2:pipeline -n ns2 # YES
k auth can-i create deployments --as system:serviceaccount:ns2:pipeline -n ns2 # YES
k auth can-i update deployments --as system:serviceaccount:ns2:pipeline -n ns2 # NO
k auth can-i update deployments --as system:serviceaccount:ns2:pipeline -n default # NO

# cluster wide view role
k auth can-i list deployments --as system:serviceaccount:ns1:pipeline -n ns1 # YES
k auth can-i list deployments --as system:serviceaccount:ns1:pipeline -A # YES
k auth can-i list pods --as system:serviceaccount:ns1:pipeline -A # YES
k auth can-i list pods --as system:serviceaccount:ns2:pipeline -A # YES
k auth can-i list secrets --as system:serviceaccount:ns2:pipeline -A # NO (default view-role doesn't allow)
```

## RBAC User Permissions

`applications` 네임스페이스가 이미 존재합니다.

1. User `smoke`는 `applications` 네임스페이스에서 Pod, Deployment, StatefulSet을 `create`하고 `delete`할 수 있어야 합니다.
2. User `smoke`는 모든 네임스페이스에서 `view` 권한(기본 ClusterRole인 `view`의 권한과 동일)을 가져야 하지만, `kube-system`에서는 가지면 안 됩니다.
3. User `smoke`는 `applications` 네임스페이스에서 사용 가능한 Secret 이름 목록을 조회할 수 있어야 합니다. Secret 이름만 조회 가능해야 하며, 데이터는 조회할 수 없어야 합니다.
4. `kubectl auth can-i`를 사용하여 모든 것을 검증하세요.

5. role 생성

```bash
$ k get ns applications
NAME           STATUS   AGE
applications   Active   10m

$ k api-resources -o wide | grep -iE 'pods|deploy|sts'
pods                                po                                  v1                                true         Pod                                create,delete,deletecollection,get,list,patch,update,watch   all
deployments                         deploy                              apps/v1                           true         Deployment                         create,delete,deletecollection,get,list,patch,update,watch   all
statefulsets                        sts                                 apps/v1                           true         StatefulSet                        create,delete,deletecollection,get,list,patch,update,watch   all
certificatesigningrequests          csr                                 certificates.k8s.io/v1            false        CertificateSigningRequest          create,delete,deletecollection,get,list,patch,update,watch

$ k create role smoke --verb create,delete --resource pods,deployments,statefulsets -n applications
role.rbac.authorization.k8s.io/smoke created

$ k create rolebinding smoke --role smoke --user smoke -n applications
rolebinding.rbac.authorization.k8s.io/smoke created
```

2. kube-system만 제외해야되므로, clusterrole인 `view`를 RoleBinding으로 kube-system 네임스페이스를 제외한 각각의 네임스페이스에 RoleBinding

```bash
$ k get ns
NAME                 STATUS   AGE
applications         Active   5m40s
cilium-secrets       Active   20h
default              Active   20h
kube-node-lease      Active   20h
kube-public          Active   20h
kube-system          Active   20h
local-path-storage   Active   20h

# kube-system 제외하고 view 마운트
k create rolebinding smoke-view --clusterrole view --user smoke -n applications
k create rolebinding smoke-view --clusterrole view --user smoke -n default
k create rolebinding smoke-view --clusterrole view --user smoke -n kube-node-lease
k create rolebinding smoke-view --clusterrole view --user smoke -n kube-public
k create rolebinding smoke-view --clusterrole view --user smoke -n cilium-secrets
k create rolebinding smoke-view --clusterrole view --user smoke -n local-path-storage
```

3. 시크릿의 내용은 볼 수 없고, 리스트만 볼 수 있는 롤 생성

```bash
$ k create role smoke-secret --verb list --resource secrets -n applications
role.rbac.authorization.k8s.io/smoke-secret created
```

- 확인

```bash
# applications
k auth can-i create deployments --as smoke -n applications # YES
k auth can-i delete deployments --as smoke -n applications # YES
k auth can-i delete pods --as smoke -n applications # YES
k auth can-i delete sts --as smoke -n applications # YES
k auth can-i delete secrets --as smoke -n applications # NO
k auth can-i list deployments --as smoke -n applications # YES
k auth can-i list secrets --as smoke -n applications # NO
k auth can-i get secrets --as smoke -n applications # NO

# view in all namespaces but not kube-system
k auth can-i list pods --as smoke -n default # YES
k auth can-i list pods --as smoke -n applications # YES
k auth can-i list pods --as smoke -n kube-public # YES
k auth can-i list pods --as smoke -n kube-node-lease # YES
k auth can-i list pods --as smoke -n kube-system # NO
```

## CertificateSigningRequests sign manually

첫 번째 단계에서는 CSR을 생성하고, 두 번째 단계에서는 K8s CA 파일로 CSR에 직접 서명합니다.
여기서의 목적은 K8s와 통신할 수 있는 새로운 "user"를 만드는 것입니다.
이를 위해 이제:

1. `60099@internal.users`라는 이름의 user를 위해 `/root/60099.key`에 새 KEY를 생성하세요.
2. 해당 KEY에 대한 CSR을 `/root/60099.csr`에 생성하세요.

- [키 생성](https://kubernetes.io/docs/tasks/tls/certificate-issue-client-csr/#create-x.509-certificatessigningrequest)

```bash
$ openssl genrsa -out 60099.key 3072

$ openssl req -new -key 60099.key -out 60099.csr
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:
State or Province Name (full name) [Some-State]:
Locality Name (eg, city) []:
Organization Name (eg, company) [Internet Widgits Pty Ltd]:
Organizational Unit Name (eg, section) []:
Common Name (e.g. server FQDN or YOUR name) []:60099@internal.users
Email Address []:60099@internal.users

Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:
An optional company name []:
```

K8s CA 파일로 CSR에 직접 서명하여 `/root/60099.crt`에 CRT를 생성하세요.
이 CRT를 사용해 K8s에 연결하는 `60099@internal.users`라는 이름의 새로운 `kubectl` context를 생성하세요.

```bash
# CRT 생성
$ openssl x509 -req -in 60099.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out 60099.crt -days 500
Certificate request self-signature ok
subject=C = AU, ST = Some-State, O = Internet Widgits Pty Ltd, CN = 60099@internal.users, emailAddress = 60099@internal.users
```

- kubeconfig에 사용자 등록
  - kubeconfig의 users 항목에 60099@internal.users를 추가하고, 인증에 쓸 키와 인증서 파일 경로를 지정
  - 이름을 kubeconfig로 했지만 별칭일 뿐이고, 실제 k8s 사용자 이름은 인증서의 CN으로 결정됨

```bash
$ k config set-credentials 60099@internal.users --client-key=60099.key --client-certificate=60099.crt
User "60099@internal.users" set.
```

- context 생성
  - context는 cluster + user (+ namespace) 조합

```bash
$ k config set-context 60099@internal.users --cluster=kubernetes --user=60099@internal.users
Context "60099@internal.users" modified.
```

- 확인 및 전환

```bash
$ k config get-contexts
CURRENT   NAME                          CLUSTER      AUTHINFO               NAMESPACE
*         60099@internal.users          kubernetes   60099@internal.users
          kubernetes-admin@kubernetes   kubernetes   kubernetes-admin

$ k config use-context 60099@internal.users
Switched to context "60099@internal.users".
```

- 접속 테스트
  - 인증(Authentication)은 성공
    - API 서버가 인증서를 받아들이고 사용자를 60099@internal.users로 인식(401)
  - 인가(Authorization)는 실패
    - 이 사용자에게 RBAC 권한을 하나도 안 줬으니 Forbidden이 정상(403)

```bash
$ k get ns # fails because no permissions, but shows the correct username returned
Error from server (Forbidden): namespaces is forbidden: User "60099@internal.users" cannot list resource "namespaces" in API group "" at the cluster scope
```

## CertificateSigningRequests sign via API

여기서는 먼저 CSR을 생성한 다음, K8s API를 사용해 서명합니다.
여기서의 목적은 K8s와 통신할 수 있는 새로운 "user"를 만드는 것입니다.
이를 위해 이제:

1. `60099@internal.users`라는 이름의 user를 위해 `/root/60099.key`에 새 KEY를 생성하세요.
2. 해당 KEY에 대한 CSR을 `/root/60099.csr`에 생성하세요.

```bash
$ openssl genrsa -out 60099.key 2048

$ ls
60099.key  filesystem

$ openssl req -new -key 60099.key -out 60099.csr
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:
State or Province Name (full name) [Some-State]:
Locality Name (eg, city) []:
Organization Name (eg, company) [Internet Widgits Pty Ltd]:
Organizational Unit Name (eg, section) []:
Common Name (e.g. server FQDN or YOUR name) []:60099@internal.users
Email Address []:60099@internal.users

Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:
An optional company name []:
```

`/root/60099.csr`을 API로 보내는 `60099@internal.users`라는 이름의 K8s CertificateSigningRequest 리소스를 생성하세요.
K8s API가 CertificateSigningRequest에 서명하도록 하세요.
CRT 파일을 `/root/60099.crt`로 다운로드하세요.
이 CRT를 사용해 K8s에 연결하는 `60099@internal.users`라는 이름의 새로운 `kubectl` context를 생성하세요.

```yaml
# CertificateSigningRequest Template
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: { { NAME } } # ADD
spec:
  groups:
    - system:authenticated
  request: { { BASE_64_ENCODED_CSR } } # ADD
  signerName: kubernetes.io/kube-apiserver-client
  usages:
    - client auth
```

```bash
$ cat 60099.csr | base64 -w 0
LS0tLS1CRUdJTiBDRVJUSUZJQ0FURSBSRVFVRVNULS0tLS0KTUlJQ3p6Q0NBYmNDQVFBd2dZa3hDekFKQmdOVkJBWVRBa0ZWTVJNd0VRWURWUVFJREFwVGIyMWxMVk4wWVhSbApNU0V3SHdZRFZRUUtEQmhKYm5SbGNtNWxkQ0JYYVdSbmFYUnpJRkIwZVNCTWRHUXhIVEFiQmdOVkJBTU1GRFl3Ck1EazVRR2x1ZEdWeWJtRnNMblZ6WlhKek1TTXdJUVlKS29aSWh2Y05BUWtCRmhRMk1EQTVPVUJwYm5SbGNtNWgKYkM1MWMyVnljekNDQVNJd0RRWUpLb1pJaHZjTkFRRUJCUUFEZ2dFUEFEQ0NBUW9DZ2dFQkFNQjgraWl2bndlTQpoaFVKcDNwNEM5R0o4b016NzI0TVBPWXIyVm0raCtxM011SjFiN1F5WlRHQlIzejluNjVVdmN4ajdHVjBCY3pyCkh6b1F0c3lCZmNKQzhQSEorZXhhaXhXVUxKczJ2bDNtdCtsb0VYRW5jaVM5L0s0cW42STFJdG9XdVJqUEhoLzAKZlEycXFsQVJpZWxYQjZjOUx4NDk5VDYrNDN6YncyQTVUc1BFWFk4eGlJekg0SnRiUUczSDRybUpYWnR0NVJibwpXZ2F1S05NN3BUQkRFUm83S0FZQXhLVlZiQmJzQ0xZdk4weDM4M1loaTFNQngvUGRCMENJY1ZsZWZ6ZTN6WU1FCnZZQlFaQ1FaSS9QV3VYNE5sVkxmT0F4L25wT1Q4QjM3Q3FQbXFFOGdBVjE0RGpFcHRCSlZJUVZHWWhwczdBNkUKRUpUdkdXVHVzek1DQXdFQUFhQUFNQTBHQ1NxR1NJYjNEUUVCQ3dVQUE0SUJBUUEvRGdMN1JSZFZLVHVRL1FDUAplYm12bXFvandDL1VsRHhGLzFrb1oydmRNREVYUDlTL1AzUDE1TW5DMkdPZy9JMjBlc1V4TS84VmwyRkZhM0VkCjZiTDA2V3d6QWhta29Id1U3N3J6ajlZUVk3OXpyNjJGRU9sKyt1eWZuYVZ2TzNzcEJnR3g3ei8zUVlsMnVBcDMKeHd5Mk91Nzl2WXpvdnRJSWtzSHJJK3VMUFZ5RjRBbTAvUnVmcjUyQnRxaUt5TjZIaFpsalg5NTQzek52c0ViUgp4cmVnWWdMY2djci9NeVRuN2w2cW5meFJWa0ZRYU5reHRmYnJRc0tBNEg1NGhKYVp6NElVdktyTjBTd2k1VFMrCkdHMFlGNGFhUjNQc2VUKzJ0NSs0NCt2S2VuM1IvN0dVRElhOTRPaGVhSU5wazRzSkdVbnZxUzd3bVlnTE9ZWVcKWG1vawotLS0tLUVORCBDRVJUSUZJQ0FURSBSRVFVRVNULS0tLS0K
$ vi csr.yaml
```

```yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: 60099@internal.users # ADD
spec:
  groups:
    - system:authenticated
  request: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURSBSRVFVRVNULS0tLS0KTUlJQ3p6Q0NBYmNDQVFBd2dZa3hDekFKQmdOVkJBWVRBa0ZWTVJNd0VRWURWUVFJREFwVGIyMWxMVk4wWVhSbApNU0V3SHdZRFZRUUtEQmhKYm5SbGNtNWxkQ0JYYVdSbmFYUnpJRkIwZVNCTWRHUXhIVEFiQmdOVkJBTU1GRFl3Ck1EazVRR2x1ZEdWeWJtRnNMblZ6WlhKek1TTXdJUVlKS29aSWh2Y05BUWtCRmhRMk1EQTVPVUJwYm5SbGNtNWgKYkM1MWMyVnljekNDQVNJd0RRWUpLb1pJaHZjTkFRRUJCUUFEZ2dFUEFEQ0NBUW9DZ2dFQkFNQjgraWl2bndlTQpoaFVKcDNwNEM5R0o4b016NzI0TVBPWXIyVm0raCtxM011SjFiN1F5WlRHQlIzejluNjVVdmN4ajdHVjBCY3pyCkh6b1F0c3lCZmNKQzhQSEorZXhhaXhXVUxKczJ2bDNtdCtsb0VYRW5jaVM5L0s0cW42STFJdG9XdVJqUEhoLzAKZlEycXFsQVJpZWxYQjZjOUx4NDk5VDYrNDN6YncyQTVUc1BFWFk4eGlJekg0SnRiUUczSDRybUpYWnR0NVJibwpXZ2F1S05NN3BUQkRFUm83S0FZQXhLVlZiQmJzQ0xZdk4weDM4M1loaTFNQngvUGRCMENJY1ZsZWZ6ZTN6WU1FCnZZQlFaQ1FaSS9QV3VYNE5sVkxmT0F4L25wT1Q4QjM3Q3FQbXFFOGdBVjE0RGpFcHRCSlZJUVZHWWhwczdBNkUKRUpUdkdXVHVzek1DQXdFQUFhQUFNQTBHQ1NxR1NJYjNEUUVCQ3dVQUE0SUJBUUEvRGdMN1JSZFZLVHVRL1FDUAplYm12bXFvandDL1VsRHhGLzFrb1oydmRNREVYUDlTL1AzUDE1TW5DMkdPZy9JMjBlc1V4TS84VmwyRkZhM0VkCjZiTDA2V3d6QWhta29Id1U3N3J6ajlZUVk3OXpyNjJGRU9sKyt1eWZuYVZ2TzNzcEJnR3g3ei8zUVlsMnVBcDMKeHd5Mk91Nzl2WXpvdnRJSWtzSHJJK3VMUFZ5RjRBbTAvUnVmcjUyQnRxaUt5TjZIaFpsalg5NTQzek52c0ViUgp4cmVnWWdMY2djci9NeVRuN2w2cW5meFJWa0ZRYU5reHRmYnJRc0tBNEg1NGhKYVp6NElVdktyTjBTd2k1VFMrCkdHMFlGNGFhUjNQc2VUKzJ0NSs0NCt2S2VuM1IvN0dVRElhOTRPaGVhSU5wazRzSkdVbnZxUzd3bVlnTE9ZWVcKWG1vawotLS0tLUVORCBDRVJUSUZJQ0FURSBSRVFVRVNULS0tLS0K # ADD
  signerName: kubernetes.io/kube-apiserver-client
  usages:
    - client auth
```

```bash
$ k apply -f csr.yaml
certificatesigningrequest.certificates.k8s.io/60099@internal.users created

$ k get csr
NAME                   AGE   SIGNERNAME                                    REQUESTOR                  REQUESTEDDURATION   CONDITION
60099@internal.users   24s   kubernetes.io/kube-apiserver-client           kubernetes-admin           <none>              Pending

# k8s가 승인(API)
$ k certificate approve 60099@internal.users
certificatesigningrequest.certificates.k8s.io/60099@internal.users approved
$ k get csr
NAME                   AGE   SIGNERNAME                                    REQUESTOR                  REQUESTEDDURATION   CONDITION
60099@internal.users   53s   kubernetes.io/kube-apiserver-client           kubernetes-admin           <none>              Approved,Issued


$ k get csr 60099@internal.users -ojsonpath="{.status.certificate}" | base64 -d > 60099.crt

$ cat 60099.crt
-----BEGIN CERTIFICATE-----
MIIDSjCCAjKgAwIBAgIRAKXCz0F1NLG7HRiYUgLgUAcwDQYJKoZIhvcNAQELBQAw
FTETMBEGA1UEAxMKa3ViZXJuZXRlczAeFw0yNjEwMDQxMzMzMjJaFw0yNzEwMDQx
MzMzMjJaMGQxCzAJBgNVBAYTAkFVMRMwEQYDVQQIEwpTb21lLVN0YXRlMSEwHwYD
VQQKExhJbnRlcm5ldCBXaWRnaXRzIFB0eSBMdGQxHTAbBgNVBAMMFDYwMDk5QGlu
dGVybmFsLnVzZXJzMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwHz6
KK+fB4yGFQmnengL0YnygzPvbgw85ivZWb6H6rcy4nVvtDJlMYFHfP2frlS9zGPs
ZXQFzOsfOhC2zIF9wkLw8cn57FqLFZQsmza+Xea36WgRcSdyJL38riqfojUi2ha5
GM8eH/R9DaqqUBGJ6VcHpz0vHj31Pr7jfNvDYDlOw8RdjzGIjMfgm1tAbcfiuYld
m23lFuhaBq4o0zulMEMRGjsoBgDEpVVsFuwIti83THfzdiGLUwHH890HQIhxWV5/
N7fNgwS9gFBkJBkj89a5fg2VUt84DH+ek5PwHfsKo+aoTyABXXgOMSm0ElUhBUZi
GmzsDoQQlO8ZZO6zMwIDAQABo0YwRDATBgNVHSUEDDAKBggrBgEFBQcDAjAMBgNV
HRMBAf8EAjAAMB8GA1UdIwQYMBaAFA6dCRJZCQMsq1KoliQ8SReKF6yjMA0GCSqG
SIb3DQEBCwUAA4IBAQAU7n0Zv3RVFRo/Dx9D6/TE69BZbhIcdOYvPIuGEW6So84A
j+agwBknKKXc+af8rULdDCAeGhijGNi3VNzvqMzgVZMFKsLHNls5RwFSVmWb80Uu
HCLH/B0fIfrvIpqMVZqHRFhRGPVoleOCa34bztevRFj15MwXqhnyWi3zqchoHCzN
G/QPA2Non9wYgmKoe/h23g9Zw6OoS2SacrJgA0Opp8Y2of/NWnDdVeOaNVwmyA1E
UubMEHtBTaxrBSB4seu6sEbOTAAeZyWQVy2RS6menN23b5bDvdkQmb1DtAqPyYnv
ySGC8CVbrY16HMrp042A7cK4Vz+RyukmuL1YYQVd
-----END CERTIFICATE-----
```

- CRT 사용

```bash
$ k config set-credentials 60099@internal.users --client-key=60099.key --client-certificate=60099.crt
User "60099@internal.users" set.

$ k config set-context 60099@internal.users --cluster=kubernetes --user=60099@internal.users
Context "60099@internal.users" created.

$ k config get-contexts
CURRENT   NAME                          CLUSTER      AUTHINFO               NAMESPACE
          60099@internal.users          kubernetes   60099@internal.users
*         kubernetes-admin@kubernetes   kubernetes   kubernetes-admin

$ k config use-context 60099@internal.users
Switched to context "60099@internal.users".

$ k get ns # fails because no permissions, but shows the correct username returned
Error from server (Forbidden): namespaces is forbidden: User "60099@internal.users" cannot list resource "namespaces" in API group "" at the cluster scope
```

- 실무에서는 CA 개인키를 직접 다루지 않는 API 방식이 더 안전하고 승인 이력도 남아 권장됨
