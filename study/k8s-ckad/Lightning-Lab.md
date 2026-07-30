# Lightning Lab

## 문제 1

`log-volume` 이라는 **PersistentVolume**을 아래 조건으로 생성하세요.

- **StorageClassName** : manual (이미 생성되어 있음 — 다시 생성하지 말 것)
- **AccessModes** : ReadWriteMany(RWX)
- **Capacity** : 1Gi
- **hostPath** : /opt/volume/nginx

다음으로, `log-claim` 이라는 **PersistentVolumeClaim**을 생성하세요.

- 최소 `200Mi` 스토리지 요청
- 위에서 생성한 `log-volume` 에 바인딩

마지막으로, `logger` 라는 Pod를 생성하세요.

- 이미지 : `nginx:alpine`
- 컨테이너 내부 `/var/www/nginx` 경로에 `log-claim` 마운트

## 해결 1

```bash
Solution manifest file to create a Persistent Volume called log-volume as follows:-

apiVersion: v1
kind: PersistentVolume
metadata:
  name: log-volume
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  storageClassName: manual
  hostPath:
    path: /opt/volume/nginx

then create a Persistent Volume Claim called log-claim as follows:-

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: log-claim
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 200Mi
  storageClassName: manual

Check the bind status of PV and PVC by running the following command:-

root@controlplane:~$ kubectl get pv,pvc

Now, create a new pod called logger with nginx:alpine image as follows:-

---
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: logger
# pod name
  name: logger
spec:
  containers:
  - image: nginx:alpine
    name: logger
    volumeMounts:
    - name: log
      mountPath: /var/www/nginx
  volumes:
  - name: log
    persistentVolumeClaim:
        claimName: log-claim
```

## 문제 2

이미 배포되어 있는 상태입니다.

- `secure-pod`라는 이름의 Pod
- 이 Pod를 타겟으로 하는 `secure-service`라는 이름의 Service

현재 `secure-pod`로의 인바운드/아웃바운드 네트워크 연결이 모두 실패하고 있습니다.
아래 조건을 만족하도록 문제를 해결하세요.

- `webapp-color` Pod에서 `secure-pod` 로의 인바운드 연결이 성공해야 합니다.

> 1. 지시사항에서 명시적으로 요청하지 않는 한, 기존 Kubernetes 오브젝트를 삭제하거나 재생성하지 마세요.
> 2. 모든 리소스는 `default` 네임스페이스에 있습니다. (별도로 명시되지 않는 한)
> 3. 수정 사항은 영구적으로 유지되어야 합니다. 테스트를 반복하더라도 변경 내용이 유효하고 정상 동작해야 합니다.

## 해결 2

```bash
$ k get netpol
NAME           POD-SELECTOR   AGE
default-deny   <none>         15m

$ k describe netpol default-deny
Name:         default-deny
Namespace:    default
Created on:   2026-06-14 12:35:49 +0000 UTC
Labels:       <none>
Annotations:  <none>
Spec:
  PodSelector:     <none> (Allowing the specific traffic to all pods in this namespace)
  Allowing ingress traffic:
    <none> (Selected pods are isolated for ingress connectivity)
  Not affecting egress traffic
  Policy Types: Ingress

# pod 상태
$ k get pods --show-labels
NAME           READY   STATUS    RESTARTS   AGE   LABELS
secure-pod     1/1     Running   0          17m   run=secure-pod
webapp-color   1/1     Running   0          27m   name=webapp-color

$ k get svc
NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
kubernetes       ClusterIP   172.20.0.1      <none>        443/TCP   69m
secure-service   ClusterIP   172.20.143.76   <none>        80/TCP    17m

# netpol 정의
$ cat netpol.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ingree-netpol
  namespace: default
spec:
  podSelector:
    matchLabels:
      run: secure-pod
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          name: webapp-color
    ports:
    - protocol: TCP
      port: 80     # 목적지 pod의 포트

# 적용 전
k exec webapp-color -- wget -O- http://secure-servic
e
Connecting to secure-service (172.20.143.76:80)
^C

# 적용
k apply -f netpol.yaml
networkpolicy.networking.k8s.io/ingree-netpol created

# 적용 후
k exec webapp-color -- wget -O- http://secure-service
Connecting to secure-service (172.20.143.76:80)
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
```

## 문제 3

`dvl1987` 네임스페이스에 `time-check`라는 Pod를 생성하세요. 이 Pod는 `busybox` 이미지를 사용하는 `time-check`라는 컨테이너를 실행해야 합니다.

1. 같은 네임스페이스에 `TIME_FREQ=10` 데이터를 가진 `time-config`라는 ConfigMap을 생성하세요.
2. `time-check` 컨테이너는 다음 명령어를 실행해야 합니다: `while true; do date; sleep $TIME_FREQ; done`, 출력 결과는 `/opt/time/time-check.log` 파일로 저장되어야 합니다.
3. Pod 내부의 `/opt/time` 경로는 **Pod의 생명주기 동안 데이터가 유지되는 볼륨**으로 마운트되어야 합니다.

## 해결 3

```bash
Create a namespace called dvl1987 by using the below command:-

$ kubectl create namespace dvl1987

Solution manifest file to create a configMap called time-config in the given namespace as follows:-

apiVersion: v1
data:
  TIME_FREQ: "10"
kind: ConfigMap
metadata:
  name: time-config
  namespace: dvl1987

Now, create a pod called time-check in the same namespace as follows:-

---
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: time-check
  name: time-check
  namespace: dvl1987
spec:
  volumes:
  - name: log-volume
    emptyDir: {}
  containers:
  - image: busybox
    name: time-check
    env:
    - name: TIME_FREQ
      valueFrom:
            configMapKeyRef:
              name: time-config
              key: TIME_FREQ
    volumeMounts:
    - mountPath: /opt/time
      name: log-volume
    command:
    - "/bin/sh"
    - "-c"
    - "while true; do date; sleep $TIME_FREQ;done > /opt/time/time-check.log"
```

## 문제 4

1. 아래 조건으로 `nginx-deploy`라는 새 Deployment를 생성하세요.

- 컨테이너 이름 : `nginx`
- 이미지 : `nginx:1.16`
- 레플리카 : 4개
- RollingUpdate 전략
  - `maxSurge=1`
  - `maxUnavailable=2`

2. Deployment를 `1.17` 버전으로 업그레이드하세요.
3. 모든 Pod가 업데이트된 후, 업데이트를 취소하고 이전 버전으로 롤백하세요.

## 해결 4

```bash
Run the following command to create a manifest for deployment nginx-deploy and save it into a file:-

kubectl create deployment nginx-deploy --image=nginx:1.16 --replicas=4 --dry-run=client -oyaml > nginx-deploy.yaml

and add the strategy field under the spec section as follows:-

  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 2

So final manifest file for deployment called nginx-deploy should looks like below:-

apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx-deploy
  name: nginx-deploy
  namespace: default
spec:
  replicas: 4
  selector:
    matchLabels:
      app: nginx-deploy
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 2
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: nginx-deploy
    spec:
      containers:
      - image: nginx:1.16
        imagePullPolicy: IfNotPresent
        name: nginx

then run the kubectl apply -f nginx-deploy.yaml to create a deployment resource.

Now, upgrade the deployment's image version using the kubectl set image command:-

kubectl set image deployment nginx-deploy nginx=nginx:1.17

Run the kubectl rollout command to undo the update and go back to the previous version:-

kubectl rollout undo deployment nginx-deploy

# 히스토리 확인
$ k rollout history deployment nginx-deploy
deployment.apps/nginx-deploy
REVISION  CHANGE-CAUSE
1         <none>


k rollout history deployment nginx-deploy
deployment.apps/nginx-deploy
REVISION  CHANGE-CAUSE
1         <none>
2         <none>


k rollout undo deployment nginx-deploy --to-revision 1
deployment.apps/nginx-deploy rolled back

k rollout history deployment nginx-deploy
deployment.apps/nginx-deploy
REVISION  CHANGE-CAUSE
2         <none>
3         <none>

k describe deployments.apps nginx-deploy | grep -i revision
Annotations:            deployment.kubernetes.io/revision: 3
```

## 문제 5

Redis Deployment 생성
default 네임스페이스에 아래 조건으로 Deployment를 생성하세요.

- 이름 : `redis`
- 이미지 : `redis:alpine`
- 레플리카 : `1`
- 라벨 : `app=redis`
- CPU 요청 : `0.2` CPU (`200m`)
- 컨테이너 포트 : `6379`

볼륨

1. `data`라는 이름의 emptyDir 볼륨, `/redis-master-data`에 마운트
2. `redis-config`라는 이름의 ConfigMap 볼륨, `/redis-master`에 마운트
   - ConfigMap은 이미 생성되어 있습니다. 다시 생성하지 마세요.

## 해결 5

```bash
Solution manifest file to create a deployment redis as follows:-

apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: redis
  name: redis
spec:
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      volumes:
      - name: data
        emptyDir: {}
      - name: redis-config
        configMap:
          name: redis-config
      containers:
      - image: redis:alpine
        name: redis
        volumeMounts:
        - mountPath: /redis-master-data
          name: data
        - mountPath: /redis-master
          name: redis-config
        ports:
        - containerPort: 6379
        resources:
          requests:
            cpu: "0.2"
```

## 문제 6

이 클러스터의 여러 네임스페이스에 Pod들이 배포되어 있습니다. Pod들을 검사하여 `Ready` 상태가 아닌 Pod를 찾으세요. 문제를 해결하세요.

다음으로, 동일한 Pod에서 `ls /var/www/html/file_check` 명령어가 실패할 경우 컨테이너를 재시작하는 체크를 추가하세요. 이 체크는 `10초` 후에 시작되고 `60초`마다 실행되어야 합니다.

오브젝트를 삭제하고 재생성해도 됩니다. probe의 경고는 무시하세요.

## 해결 6

```bash
$ k get pods -A
...
dev1401       nginx1401                                  0/1     Running   0          15m

# pod 상태 확인
$ k describe pod -n dev1401 nginx1401
Name:             nginx1401
Namespace:        dev1401
Priority:         0
Service Account:  default
Node:             node01/10.244.56.126
Start Time:       Mon, 15 Jun 2026 13:01:00 +0000
Labels:           run=nginx
Annotations:      cni.projectcalico.org/containerID: b7e07df631829bdd8e15e26f8021c74265d500579441d7871d90cc48252bfcd7
                  cni.projectcalico.org/podIP: 172.17.1.2/32
                  cni.projectcalico.org/podIPs: 172.17.1.2/32
Status:           Running
IP:               172.17.1.2
IPs:
  IP:  172.17.1.2
Containers:
  nginx:
    Container ID:   containerd://50a3c58af1e40fbb818b485312ae454b29b1979dde9497c1861fa1fafe372454
    Image:          kodekloud/nginx
    Image ID:       docker.io/kodekloud/nginx@sha256:2862900861517dfaf9e0ed0f4fa199744a7410f4f78520866031c725c386bb5e
    Port:           9080/TCP # port 가 9080
    Host Port:      0/TCP
    State:          Running
      Started:      Mon, 15 Jun 2026 13:01:08 +0000
    Ready:          False
    Restart Count:  0
    Readiness:      http-get http://:8080/ delay=0s timeout=1s period=10s # readiness 포트가 8080  #success=1 #failure=3
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-75lkw (ro)
Conditions:
  Type                        Status
  PodReadyToStartContainers   True
  Initialized                 True
  Ready                       False
  ContainersReady             False
  PodScheduled                True
Volumes:
  kube-api-access-75lkw:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    Optional:                false
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type     Reason     Age                 From               Message
  ----     ------     ----                ----               -------
  Normal   Scheduled  16m                 default-scheduler  Successfully assigned dev1401/nginx1401 to node01
  Normal   Pulling    16m                 kubelet            spec.containers{nginx}: Pulling image "kodekloud/nginx"
  Normal   Pulled     16m                 kubelet            spec.containers{nginx}: Successfully pulled image "kodekloud/nginx" in 6.508s (6.508s including waiting). Image size: 50986074 bytes.
  Normal   Created    16m                 kubelet            spec.containers{nginx}: Container created
  Normal   Started    16m                 kubelet            spec.containers{nginx}: Container started
  Warning  Unhealthy  75s (x98 over 16m)  kubelet            spec.containers{nginx}: Readiness probe failed: Get "http://172.17.1.2:8080/": dial tcp 172.17.1.2:8080: connect: connection refused

$ k get pods -n dev1401 nginx1401 -o yaml > nginx1401.yaml
$ cat nginx1401.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: nginx
  name: nginx1401
  namespace: dev1401
spec:
  containers:
  - image: kodekloud/nginx
    imagePullPolicy: IfNotPresent
    name: nginx
    ports:
    - containerPort: 9080
      protocol: TCP
    readinessProbe:
      failureThreshold: 3
      httpGet:
        path: /
        port: 9080 # readiness 포트를 8080에서 9080으로 수정
        scheme: HTTP
    livenessProbe: # livenessProbe 추가
      exec:
        command:
        - ls
        - /var/www/html/file_check
      initialDelaySeconds: 10 # 체크는 10초 후에 시작
      periodSeconds: 60 # 60초마다 실행
...

$ k delete pods -n dev1401 nginx1401 --force
$ k apply -f nginx1401.yaml
```

## 문제 7

매 `1분`마다 실행되는 `dice`라는 CronJob을 생성하세요.
`/root/throw-a-dice`에 위치한 Pod 템플릿을 사용하세요. `throw-dice` 이미지는 1에서 6 사이의 값을 랜덤으로 반환합니다. 6이 나오면 `성공`, 나머지는 `실패`로 간주합니다.
Job은 `비병렬(non-parallel)`로 실행되어야 하며 작업을 `1번` 완료해야 합니다.
`backoffLimit`은 `25`로 설정하세요.
작업이 `20초` 이내에 완료되지 않으면 Job은 실패 처리되고 Pod는 종료되어야 합니다.

Job 완료를 기다릴 필요는 없습니다. 요구사항에 맞게 CronJob이 생성되기만 하면 됩니다.

## 해결 7

```bash
apiVersion: batch/v1
kind: CronJob
metadata:
  name: dice
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      completions: 1
      backoffLimit: 25 # 작업이 성공하기 전에 종료되지 않도록 하기 위한 설정
      activeDeadlineSeconds: 20
      template:
        spec:
          containers:
          - name: dice
            image: kodekloud/throw-dice
          restartPolicy: Never
```

## 문제 8

`busybox` 이미지를 사용하여 `dev2406` 네임스페이스에 `my-busybox`라는 Pod를 생성하세요. 컨테이너 이름은 `secret`이어야 하며 `3600`초 동안 sleep 해야 합니다.

컨테이너는 `/etc/secret-volume` 경로에 `secret-volume`이라는 `읽기 전용(read-only)` Secret 볼륨을 마운트해야 합니다. 마운트할 Secret은 이미 생성되어 있으며 이름은 `dotfile-secret`입니다.

Pod가 반드시 `controlplane` 노드에만 스케줄링되도록 설정하세요.

## 해결 8

```bash
$ k run my-busybox -n dev2406 --image busybox --dry-run=client -o yaml --command -- sleep 3600 > my-busybox.yaml

$ cat my-busybox.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: my-busybox
  name: my-busybox
  namespace: dev2406
spec:
  containers:
  - command:
    - sleep
    - "3600"
    image: busybox
    name: secret # 컨테이너 이름 변경
    volumeMounts:
      - name: secret-volume
        readOnly: true
        mountPath: /etc/secret-volume
  volumes:
    - name: secret-volume
      secret:
        secretName: dotfile-secret
  nodeSelector:
    kubernetes.io/hostname: controlplane

$ k apply -f my-busybox.yaml
```

## 문제 9

`ingress-vh-routing`이라는 단일 Ingress 리소스를 생성하세요. 아래 조건에 따라 여러 호스트네임으로 HTTP 트래픽을 라우팅해야 합니다:

1. `video-service`는 `http://watch.ecom-store.com:30093/video` 로 접근 가능해야 합니다.
2. `apparels-service`는 `http://apparels.ecom-store.com:30093/wear` 로 접근 가능해야 합니다.

백엔드 서비스로 전달되는 경로가 올바르게 재작성(rewrite)되도록 아래 `어노테이션(annotation)`을 리소스에 추가하세요:

```
nginx.ingress.kubernetes.io/rewrite-target: /
```

여기서 `30093`은 `Ingress Controller`가 사용하는 포트입니다.

## 해결 9

```bash
$ k get ingressclasses.networking.k8s.io
NAME    CONTROLLER             PARAMETERS   AGE
nginx   k8s.io/ingress-nginx   <none>       26m

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-vh-routing
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: "nginx"
  rules:
  - host: watch.ecom-store.com
    http:
      paths:
      - pathType: Prefix
        path: "/video"
        backend:
          service:
            name: video-service
            port:
              number: 8080
  - host: apparels.ecom-store.com
    http:
      paths:
      - pathType: Prefix
        path: "/wear"
        backend:
          service:
            name: apparels-service
            port:
              number: 8080

# 검증
$ k get svc
NAME               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
apparels-service   ClusterIP   172.20.176.13   <none>        8080/TCP   10m
video-service      ClusterIP   172.20.167.42   <none>        8080/TCP   10m

# curl 로 apparels 서비스 내용 확인
$ curl -s 172.20.176.13:8080 | grep jpg
    <img src="https://res.cloudinary.com/cloudusthad/image/upload/v1547052428/apparels.jpg">

# curl 로 video 서비스 내용 확인
$ curl -s 172.20.167.42:8080 | grep jpg
    <img src="https://res.cloudinary.com/cloudusthad/image/upload/v1547052431/video.jpg">

# 도메인 url로 확인
$ curl -s http://watch.ecom-store.com:30093/video | grep jpg
    <img src="https://res.cloudinary.com/cloudusthad/image/upload/v1547052431/video.jpg">

$ curl -s http://apparels.ecom-store.com:30093/wear | grep jpg
    <img src="https://res.cloudinary.com/cloudusthad/image/upload/v1547052428/apparels.jpg">
```

## 문제 10

`default` 네임스페이스에 `dev-pod-dind-878516`이라는 Pod가 배포되어 있습니다. `log-x`라는 컨테이너의 로그를 확인하고, 경고(warning) 메시지를 `controlplane` 노드의 `/opt/dind-878516_logs.txt` 파일로 리다이렉트하세요.

## 해결 10

```bash
$ kubectl logs dev-pod-dind-878516 -c log-x | grep WARNING > /opt/dind-878516_logs.txt
```
