# Mock Exam

## 환경 설정

```bash
export dr='--dry-run=client -o yaml'
```

## 문제 1

`nginx-448839`라는 이름의 Pod를 `nginx:alpine` 이미지를 사용하여 배포하세요.

- 이름: nginx-448839
- 이미지: nginx:alpine

## 해설 1

```bash
$ k run nginx-448839 --image nginx:alpine
pod/nginx-448839 created

$ k get pods
NAME           READY   STATUS    RESTARTS   AGE
nginx-448839   1/1     Running   0          66s
```

## 문제 2

namespace를 생성하세요.

- Namespace: apx-z993845

## 해설 2

```bash
$ k create ns apx-z993845
namespace/apx-z993845 created

$ k get ns
NAME              STATUS   AGE
apx-z993845       Active   2s
```

## 문제 3

`httpd:2.4-alpine` 이미지를 사용하여 `httpd-frontend`라는 이름의 새 Deployment를 3개의 레플리카로 생성하세요.

- 이름: httpd-frontend
- 레플리카: 3
- 이미지: httpd:2.4-alpine

## 해설 3

```bash
$ k create deployment httpd-frontend --replicas 3 --image httpd:2.4-alpine
deployment.apps/httpd-frontend created

$ k get pods -l app=httpd-frontend
NAME                              READY   STATUS    RESTARTS   AGE
httpd-frontend-64d454bb7d-4qsj4   1/1     Running   0          15s
httpd-frontend-64d454bb7d-swcpk   1/1     Running   0          15s
httpd-frontend-64d454bb7d-w9mkm   1/1     Running   0          15s
```

## 문제 4

`tier=msg` 라벨이 설정된 `redis:alpine` 이미지를 사용하여 `messaging` Pod를 배포하세요.
Pod 이름: messaging

- 이미지: redis:alpine
- 라벨: tier=msg

## 해설 4

```bash
$ k run messaging --image redis:alpine $dr > messaging.yaml

$ cat messaging.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    tier: msg # labels 값 수정
  name: messaging
spec:
  containers:
  - image: redis:alpine
    name: messaging

$ k apply -f messaging.yaml
pod/messaging created

$ k get pods -l tier=msg
NAME        READY   STATUS    RESTARTS   AGE
messaging   1/1     Running   0          19s
```

## 문제 5

`rs-d33393`라는 ReplicaSet이 생성되었습니다. 하지만 Pod들이 정상적으로 올라오지 않고 있습니다. 문제를 식별하고 수정하세요.
수정 후, ReplicaSet이 4개의 `Ready` 레플리카를 갖도록 하세요.

- 레플리카: 4

## 해설 5

```bash
$ k describe pods rs-d33393-rmx9t
Name:             rs-d33393-rmx9t
Namespace:        default
Priority:         0
Service Account:  default
Node:             controlplane/10.244.170.128
...
Controlled By:  ReplicaSet/rs-d33393
Containers:
  busybox-container:
    Container ID:
    Image:         busyboxXXXXXXX
    Image ID:
    Port:          <none>
    Host Port:     <none>
    Command:
      sh
      -c
      echo Hello Kubernetes! && sleep 3600
    State:          Waiting
      Reason:       InvalidImageName # 이미지 이름이 유효하지 않음
    Ready:          False
...
Events:
  Type     Reason         Age                   From               Message
  ----     ------         ----                  ----               -------
  Normal   Scheduled      2m43s                 default-scheduler  Successfully assigned default/rs-d33393-rmx9t to controlplane
  Warning  Failed         52s (x12 over 2m42s)  kubelet            spec.containers{busybox-container}: Error: InvalidImageName
  Warning  InspectFailed  41s (x13 over 2m42s)  kubelet            spec.containers{busybox-container}: Failed to apply default image tag "busyboxXXXXXXX": couldn't parse image name "busyboxXXXXXXX": invalid reference format: repository name (library/busyboxXXXXXXX) must be lowercase

$ k edit rs rs-d33393
        image: busyboxXXXXXXX # 이미지명 수정

$ k delete pods -l name=busybox-pod --force
pod "rs-d33393-28b87" deleted from default namespace
pod "rs-d33393-bbv5k" deleted from default namespace
pod "rs-d33393-fzkbc" deleted from default namespace
pod "rs-d33393-rmx9t" deleted from default namespace

$ k get pods -l name=busybox-pod
NAME              READY   STATUS    RESTARTS   AGE
rs-d33393-5j8nz   1/1     Running   0          13s
rs-d33393-5q4wf   1/1     Running   0          12s
rs-d33393-gwv9v   1/1     Running   0          13s
rs-d33393-krdkj   1/1     Running   0          12s
```

## 문제 6

`marketing` 네임스페이스 내에서 `redis` Deployment를 클러스터 내부 `6379` 포트로 노출하는 `messaging-service` 서비스를 생성하세요.
명령형(imperative) 명령어를 사용하세요

- 서비스: messaging-service
- 포트: 6379
- 올바른 타입의 서비스를 사용하세요
- 올바른 라벨을 사용하세요

## 해설 6

```bash
# 라벨 확인
$ k get pods -n marketing --show-labels
NAME                     READY   STATUS    RESTARTS   AGE   LABELS
redis-7f9699f579-974dv   1/1     Running   0          30m   name=redis-pod,pod-template-hash=7f9699f579

$ k expose deployment -n marketing redis --name messaging-service --port 6379 $dr > messaging-service.yaml

$ cat messaging-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: messaging-service
  namespace: marketing
spec:
  ports:
  - port: 6379
    protocol: TCP
    targetPort: 6379
  selector: # label 값 확인
    name: redis-pod

$ k apply -f messaging-service.yaml

$ k get svc -n marketing
NAME                TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
messaging-service   ClusterIP   172.20.240.218   <none>        6379/TCP   2m48s

# pod ip 확인
$ k get pods -n marketing -o wide
NAME                     READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
redis-7f9699f579-974dv   1/1     Running   0          33m   172.17.0.7   controlplane   <none>           <none>

# 엔드포인트 확인
$ k get -n marketing endpointslices.discovery.k8s.io
NAME                      ADDRESSTYPE   PORTS   ENDPOINTS    AGE
messaging-service-tmh5n   IPv4          6379    172.17.0.7   42s
```

## 문제 7

`webapp-color` Pod의 환경변수를 업데이트하여 `green` 배경을 사용하도록 하세요.

- Pod 이름: webapp-color
- 라벨 이름: webapp-color
- 환경변수: APP_COLOR=green

## 해설 7

```bash
$ k get pods webapp-color -o yaml > webapp-color.yaml

$ cat webapp-color.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    name: webapp-color
  name: webapp-color
  namespace: default
spec:
  containers:
  - env:
    - name: APP_COLOR
      value: green # env 값 변경
    image: kodekloud/webapp-color
    imagePullPolicy: Always
    name: webapp-color
...

$ k delete pods webapp-color --force
$ k apply -f webapp-color.yaml
```

## 문제 8

`cm-3392845`라는 이름의 새 ConfigMap을 생성하세요. 아래 명세를 사용하세요.

- ConfigMap 이름: cm-3392845
- 데이터: DB_NAME=SQL3322
- 데이터: DB_HOST=sql322.mycompany.com
- 데이터: DB_PORT=3306

## 해설 8

```bash
$ k create cm cm-3392845 --from-literal DB_NAME=SQL3322 --from-literal DB_HOST=sql322.mycompany.com --from-literal DB_PORT=3306 $dr
apiVersion: v1
data:
  DB_HOST: sql322.mycompany.com
  DB_NAME: SQL3322
  DB_PORT: "3306"
kind: ConfigMap
metadata:
  name: cm-3392845

$ k create cm cm-3392845 --from-literal DB_NAME=SQL3322 --from-literal DB_HOST=sql322.mycompany.com --from-literal DB_PORT=3306
configmap/cm-3392845 created
```

## 문제 9

아래 데이터를 사용하여 `db-secret-xxdf`라는 이름의 새 Secret을 생성하세요.

- Secret 이름: db-secret-xxdf
- Secret 1: DB_Host=sql01
- Secret 2: DB_User=root
- Secret 3: DB_Password=password123

## 해설 9

```bash
$ k create secret generic db-secret-xxdf --from-literal DB_Host=sql01 --from-literal DB_User=root --from-literal DB_Password=password123 $dr
apiVersion: v1
data:
  DB_Host: c3FsMDE=
  DB_Password: cGFzc3dvcmQxMjM=
  DB_User: cm9vdA==
kind: Secret
metadata:
  name: db-secret-xxdf

$ k create secret generic db-secret-xxdf --from-literal DB_Host=sql01 --from-literal DB_User=root --from-literal DB_Password=password123
secret/db-secret-xxdf created
```

## 문제 10

`app-sec-kff3345` Pod를 `Root 사용자로 실행`하고 `SYS_TIME` 권한(capability)을 갖도록 업데이트하세요.

- Pod 이름: app-sec-kff3345
- 이미지 이름: ubuntu
- SecurityContext: Capability SYS_TIME

## 해설 10

```bash
$ k get pods app-sec-kff3345 -o yaml > app-sec.yaml

$ cat app-sec.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-sec-kff3345
  namespace: default
spec:
  securityContext: # root 권한으로 실행
    runAsUser: 0
  containers:
  - command:
    - sleep
    - "4800"
    image: ubuntu
    imagePullPolicy: Always
    name: ubuntu
    securityContext: # SYS_TIME 권한 추가
      capabilities:
        add: ["SYS_TIME"]
...
```

## 문제 11

`e-com-1123` Pod의 로그를 `/opt/outputs/e-com-1123.logs` 파일로 내보내세요.
이 Pod는 다른 네임스페이스에 있습니다. 먼저 네임스페이스를 식별하세요.

## 해설 11

```bash
$ k get pods -A | grep "e-com-1123"
e-commerce    e-com-1123                                 1/1     Running   0          51m

$ k logs -n e-commerce e-com-1123 > /opt/outputs/e-com-1123.logs

$ head -5 /opt/outputs/e-com-1123.logs
[2026-06-21 08:41:40,753] INFO in event-simulator: USER4 logged in
[2026-06-21 08:41:41,754] INFO in event-simulator: USER1 is viewing page1
[2026-06-21 08:41:42,755] INFO in event-simulator: USER2 is viewing page1
[2026-06-21 08:41:43,756] INFO in event-simulator: USER4 is viewing page1
[2026-06-21 08:41:44,757] INFO in event-simulator: USER4 logged in
```

## 문제 12

다음 명세를 사용하여 `Persistent Volume`을 생성하세요.

- 볼륨 이름: pv-analytics
- 스토리지: 100Mi
- 액세스 모드: ReadWriteMany
- 호스트 경로: /pv/data-analytics

## 해설 12

```bash
$ cat pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-analytics
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 100Mi
  accessModes:
    - ReadWriteMany
  hostPath:
    path: "/pv/data-analytics"

$ k apply -f pv.yaml
persistentvolume/pv-analytics created
```

## 문제 13

`redis:alpine` 이미지를 사용하여 `1개의 레플리카`와 `app=redis` 라벨을 가진 `redis` Deployment를 생성하세요. 이를 포트 6379에서 `redis`라는 ClusterIP 서비스로 노출하세요. `access=redis` 라벨을 가진 Pod만 해당 Deployment에 접근할 수 있도록 허용하는 `redis-access`라는 새로운 `Ingress 타입` NetworkPolicy를 생성하세요.

## 해설 13

```bash
$ k create deployment redis --image redis:alpine $dr
apiVersion: apps/v1
kind: Deployment
metadata:
  labels: # 라벨 확인
    app: redis
  name: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - image: redis:alpine
        name: redis

$ k create deployment redis --image redis:alpine
deployment.apps/redis created

# 서비스 생성
$ k expose deployment redis --port 6379 $dr
apiVersion: v1
kind: Service
metadata:
  labels: # 라벨 확인
    app: redis
  name: redis
spec:
  ports:
  - port: 6379
    protocol: TCP
    targetPort: 6379
  selector:
    app: redis

$ k expose deployment redis --port 6379
service/redis exposed

$ cat netpol.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: redis-access
  namespace: default
spec:
  podSelector:
    matchLabels: # app: redis 라벨을 가진 파드에 인그레스 적용
      app: redis
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels: # access: redis 라벨을 가진 출발지 파드만 목적지 app: redis에 접근 가능
          access: redis
    ports:
    - protocol: TCP # 목적지 포트는 6379로 접근
      port: 6379

$ k apply -f netpol.yaml
networkpolicy.networking.k8s.io/redis-access created
```

## 문제 14

다음 두 개의 컨테이너를 가진 `sega`라는 이름의 Pod를 생성하세요:

1. 컨테이너 1: 이름 `tails`, 이미지 `busybox`, 명령어: `sleep 3600`.
2. 컨테이너 2: 이름 `sonic`, 이미지 `nginx`, 환경변수: `NGINX_PORT`, 값 `8080`.

## 해설 14

```bash
$ k run sega --image busybox $dr --command -- sleep 3600 > sega.yaml

$ cat sega.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: sega
  name: sega
spec:
  containers:
  - command:
    - sleep
    - "3600"
    image: busybox
    name: tails
  - name: sonic
    image: nginx
    env:
    - name: NGINX_PORT
      value: "8080" # 따옴표를 넣지 않을 경우 오류가 발생함

$ k apply -f sega.yaml
pod/sega created
```
