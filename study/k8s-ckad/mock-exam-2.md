# 문제 1

`nginx` 이미지, `tier:frontend` 라벨, `2개`의 레플리카를 가진 `my-webapp`이라는 Deployment를 생성하세요.
이 Deployment를 `front-end-service`라는 이름의 `NodePort` 서비스로 노출하되, 포트: `80`, NodePort: `30083`으로 설정하세요.

# 해설 1

```bash
# deployment 생성
$ k create deployment my-webapp --image nginx --replicas 2 $dr > my-webapp.yaml

$ cat my-webapp.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: my-webapp
    tier: frontend # label 설정
  name: my-webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-webapp
  template:
    metadata:
      labels:
        app: my-webapp
    spec:
      containers:
        - image: nginx
          name: nginx
```

```bash
# 적용
$ k apply -f my-webapp.yaml
deployment.apps/my-webapp created

# 서비스 생성
$ k expose deployment my-webapp --name front-end-service --port 80 --type NodePort $dr > my-webapp-svc.yaml

$ cat my-webapp-svc.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: my-webapp
    tier: frontend
  name: front-end-service
spec:
  ports:
    - port: 80
      protocol: TCP
      targetPort: 80
      nodePort: 30083 # nodeport 추가
  selector:
    app: my-webapp
  type: NodePort
```

```bash
$ k apply -f my-webapp-svc.yaml
```

# 문제 2

클러스터의 `node01` 노드에 taint를 추가하세요.

- 키: `app_type`
- 값: `alpha`
- 효과: `NoSchedule`
  `node01`에 대한 toleration을 가진 `alpha`라는 이름의 Pod를 `redis` 이미지로 생성하세요.

# 해설 2

```bash
# 기존 taint 확인
$ k describe nodes node01 | grep -i taints
Taints:             <none>

# taint 생성
$ k taint node node01 app_type=alpha:NoSchedule
node/node01 tainted

$ k describe nodes node01 | grep -i taints
Taints:             app_type=alpha:NoSchedule

$ k run alpha --image redis $dr > alpha-pod.yaml

$ k apply -f alpha-pod.yaml

$ cat alpha-pod.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: alpha
  name: alpha
spec:
  tolerations: # taint 추가
    - key: "app_type"
      operator: "Equal"
      value: "alpha"
      effect: "NoSchedule"
  containers:
    - image: redis
      name: alpha
```

# 문제 3

`controlplane` 노드에 `app_type=beta` 라벨을 적용하세요. `nginx` 이미지와 `3개`의 레플리카를 가진 `beta-apps`라는 새 Deployment를 생성하세요.
Pod가 `controlplane`에만 배치되도록 Deployment에 Node Affinity를 설정하세요.

- NodeAffinity: `requiredDuringSchedulingIgnoredDuringExecution`
- Deployment beta-apps의 Pod가 controlplane에서만 실행되고 있나요?
- Deployment beta-apps에 3개의 Pod가 실행 중인가요?

# 해설 3

```bash
$ k label nodes controlplane app_type=beta
node/controlplane labeled

$ k create deployment beta-apps --image nginx --replicas 3 $dr > beta-apps.yaml

$ k apply -f beta-apps.yaml
deployment.apps/beta-apps created

$ cat beta-apps.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: beta-apps
  name: beta-apps
spec:
  replicas: 3
  selector:
    matchLabels:
      app: beta-apps
  template:
    metadata:
      labels:
        app: beta-apps
    spec:
      containers:
        - image: nginx
          name: nginx
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: app_type
                    operator: In
                    values:
                      - beta
```

# 문제 4

`my-video-service` 서비스를 URL `http://ckad-mock-exam-solution.com:30093/video` 에서 접근 가능하도록 새 Ingress 리소스를 생성하세요.
Ingress 리소스 생성을 위한 세부 사항은 다음과 같습니다.

- `annotation`: `nginx.ingress.kubernetes.io/rewrite-target: /`
- `host`: `ckad-mock-exam-solution.com`
- `path`: `/video`
- 설정 완료 후, 노드에서 해당 URL의 curl 테스트가 성공해야 합니다: `HTTP 200`

# 해설 4

```bash
$ k get svc -o wide
NAME               TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE    SELECTOR
kubernetes         ClusterIP   172.20.0.1     <none>        443/TCP    22m    <none>
my-video-service   ClusterIP   172.20.23.83   <none>        8080/TCP   116s   app=webapp-video

# ingress 생성 전 접속 확인
$ curl -kv http://ckad-mock-exam-solution.com:30093/video
*   Trying 10.244.213.52:30093...
* Connected to ckad-mock-exam-solution.com (10.244.213.52) port 30093 (#0)
> GET /video HTTP/1.1
> Host: ckad-mock-exam-solution.com:30093
> User-Agent: curl/7.81.0
> Accept: */*
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 404 Not Found # 404에러
< Date: Sun, 28 Jun 2026 09:30:54 GMT
< Content-Type: text/html

# ingress class 확인
$ k get ingressclasses.networking.k8s.io
NAME    CONTROLLER             PARAMETERS   AGE
nginx   k8s.io/ingress-nginx   <none>       7m15s

$ ka ingress.yaml
ingress.networking.k8s.io/my-video-ingress created

$ k get ingress
NAME               CLASS   HOSTS                         ADDRESS          PORTS   AGE
my-video-ingress   nginx   ckad-mock-exam-solution.com   172.20.235.189   80      34s

$ cat ingress.yaml
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-video-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: "ckad-mock-exam-solution.com"
      http:
        paths:
          - pathType: Prefix
            path: "/video"
            backend:
              service:
                name: my-video-service
                port:
                  number: 8080
```

```bash
# ingress 생성 후 status 코드 확인
$ curl -I http://ckad-mock-exam-solution.com:30093/video
HTTP/1.1 200 OK
Date: Sun, 28 Jun 2026 09:38:47 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 293
Connection: keep-alive

# ingress 생성 후 접속 확인
$ curl http://ckad-mock-exam-solution.com:30093/video
<!doctype html>
<title>Hello from Flask</title>
<body style="background: #30336b;">

<div style="color: #e4e4e4;
    text-align:  center;
    height: 90px;
    vertical-align:  middle;">
    <img src="https://res.cloudinary.com/cloudusthad/image/upload/v1547052431/video.jpg">
</div>
</body>
```

# 문제 5

`pod-with-rprobe`라는 새 Pod가 배포되었습니다. 이 Pod는 Ready 상태가 되기 전에 초기 지연이 있습니다. 아래 명세를 사용하여 새로 생성된 `pod-with-rprobe` Pod에 `readinessProbe`를 추가하세요.

- httpGet 경로: /ready
- httpGet 포트: 8080

# 해설 5

```bash
$ k get pods
NAME                            READY   STATUS    RESTARTS   AGE
pod-with-rprobe                 1/1     Running   0          3m54s
webapp-video-68cff9d6fc-6t5g6   1/1     Running   0          14m

$ k get pods pod-with-rprobe -o yaml > pod-with-rprobe.yaml

$ ka pod-with-rprobe.yaml

# 3분 후 파드 상태 확인
$ k get pods
NAME                            READY   STATUS    RESTARTS   AGE
pod-with-rprobe                 1/1     Running   0          3m55s

$ cat pod-with-rprobe.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    name: pod-with-rprobe
  name: pod-with-rprobe
  namespace: default
spec:
  containers:
    - env:
        - name: APP_START_DELAY
          value: "180" # env 값으로 app 시작 딜레이 옵션
...
name: pod-with-rprobe
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  periodSeconds: 5
  initialDelaySeconds: 180 # env값과 같은 초기 지연값 설정
ports:
  - containerPort: 8080
    protocol: TCP
...
```

# 문제 6

`default` 네임스페이스에 `nginx` 이미지를 사용하는 `nginx1401`이라는 새 Pod를 생성하세요. `ls /var/www/html/probe` 명령어가 실패할 경우 컨테이너를 재시작하도록 livenessProbe를 추가하세요. 이 검사는 `10초` 지연 후 시작되어 `60초`마다 실행되어야 합니다.
오브젝트를 삭제하고 재생성해도 됩니다. probe의 경고는 무시하세요.
livenessProbe가 올바르게 설정된 Pod가 생성되었나요?

# 해설 6

```bash
$ k run nginx1401 -n default --image nginx $dr > nginx1401.yaml

$ cat nginx1401.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: nginx1401
  name: nginx1401
  namespace: default
spec:
  containers:
  - image: nginx
    name: nginx1401
    livenessProbe:
      exec:
        command:
        - ls
        - /var/www/html/probe
      initialDelaySeconds: 10
      periodSeconds: 60
  restartPolicy: OnFailure

$ ka nginx1401.yaml
pod/nginx1401 created

$ k get pods
NAME                            READY   STATUS    RESTARTS   AGE
nginx1401                       1/1     Running   0          50s
```

# 문제 7

`busybox` 이미지와 `echo "cowsay I am going to ace CKAD!"` 명령어를 사용하는 `whalesay`라는 Job을 생성하세요.

- completions: `10`
- backoffLimit: `6`
- restartPolicy: `Never`

# 해설 7

```bash
$ k apply -f whalesay.yaml
job.batch/whalesay created

$ cat whalesay.yaml
```

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  labels:
    run: whalesay
  name: whalesay
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - command:
            - echo
            - cowsay I am going to ace CKAD!
          image: busybox
          name: whalesay
  completions: 10
  backoffLimit: 6
```

# 문제 8

두 개의 컨테이너를 가진 `multi-pod`라는 Pod를 생성하세요.

- 컨테이너 1: 이름: `jupiter`, 이미지: `nginx`
- 컨테이너 2: 이름: `europa`, 이미지: `busybox`, 명령어: `sleep 4800`
- 환경변수
  - 컨테이너 1: `type: planet`
  - 컨테이너 2: `type: moon`
- Pod 이름: multi-pod
  - 컨테이너 1: jupiter
  - 컨테이너 2: europa

# 해셜 8

```bash
$ k run multi-pod --image busybox $dr --command -- sleep 4800 > multi-pod.yaml

$ k apply -f multi-pod.yaml
pod/multi-pod created

$ cat multi-pod.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: multi-pod
  name: multi-pod
spec:
  containers:
    - name: jupiter
      image: nginx
      env:
        - name: type
          value: moon
    - command:
        - sleep
        - "4800"
      image: busybox
      name: europa
      env:
        - name: type
          value: planet
  dnsPolicy: ClusterFirst
  restartPolicy: Always
```

# 문제 9

크기: `50MiB`, 반환 정책: `retain`, 액세스 모드: `ReadWriteMany`, hostPath: `/opt/data`로 `custom-volume`이라는 PersistentVolume을 생성하세요.

# 해설 9

```bash
$ ka hostpath.yaml
persistentvolume/custom-volume created

$ k get pv
NAME            CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
custom-volume   50Mi       RWX            Retain           Available           manual         <unset>                          37s

$ cat hostpath.yaml
```

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: custom-volume
  labels:
    type: local
spec:
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  capacity:
    storage: 50Mi
  accessModes:
    - ReadWriteMany
  hostPath:
    path: "/opt/data"
```
