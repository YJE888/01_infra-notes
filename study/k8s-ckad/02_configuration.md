# 구성
## 이미지 생성
- 이미지를 생성하는 방법
	```css
	1. OS - Ubuntu
	2. Update apt repo
	3. Install dependencies using apt
	4. Install Python dependencies using pip
	5. Copy source code to /opt folder
	6. Run the web server using "flask" command
	```
- Dockerfile 생성
	```dockerfile
	# Instruction Argument
	FROM Ubuntu

	RUN apt-get update
	RUN apt-get install python

	RUN pip install flask
	RUN pip install flask-mysql

	COPY . /opt/source-code

	ENTRYPOINT FLASK_APP=/opt/source-code/app.py flask run
	```
- RUN
    - 설치 및 종속성 요구 명시
- COPY
    - 현재 폴더에 있는 소스코드를 이미지의 /opt/source-code로 복사
- ENTRYPOINT
    - 컨테이너가 시작될 때 반드시 실행되는 기본 명령
- 이미지를 빌드하는 방법
	```bash
	docker build Dockerfile -t flask/my-custom-app
	```
## k8s의 Command vs Argument
- Command 지정 방법
	- Ubuntu 이미지의 경우 bash를 커맨드로 가지므로 컨테이너 실행 시 지속되지 않고 종료됨
	- 셸 형식 그대로 사용하는 방법과 JSON 배열 형식으로 지정하는 방법이 있음
	```dockerfile
	FROM Ubuntu
	CMD sleep 5

	CMD command param1
	CMD ["command", "param1"]

	CMD sleep 5

	# 불가능
	# JSON 배열 형식으로 지정하는 경우 배열의 첫 번째 요소는 실행파일이어야됨
	CMD ["sleep 5"]

	# 가능
	CMD ["sleep", "5"]
	```

### Dockerfile에서의 CMD와 ENTRYPOINT
- cmd
	- 기본값
	- 사용자가 쉽게 변경 가능
- entrypoint
	- 고정 실행 파일

- 실행 예시
	```dockerfile
	# Dockerfile
	FROM Ubuntu
	CMD sleep 5
	```
	```bash
	$ docker run ubuntu sleep 10
	# command startup : sleep 10
	```
	```dockerfile
	# dockerfile
	FROM Ubuntu
	ENTRYPOING ["sleep"]
	```
	```bash
	$ docker run ubuntu 10
	# command startup : sleep 10

	# sleep operand missing 에러 발생
	$ docker run ubuntu
	# command startup : sleep
	```
	```dockerfile
	# dockerfile
	FROM Ubuntu
	ENTRYPOINT["sleep"]
	CMD["5"]
	```
	```bash
	$ docker run ubuntu
	# command startup : sleep 5

	$ docker run ubuntu 10
	# command startup : sleep 10

	$ docker run --entrypoint sleep2.0 ubuntu 10
	# command startup : sleep2.0 10
	```
### Command 와 Arguments
- 이미지의 dockerfile
	```dockerfile
	# dockerfile
	FROM Ubuntu
	ENTRYPOINT["sleep"]
	CMD["5"]
	```
- 컨테이너 실행
	```bash
	$ docker run --name ubuntu-sleeper \
	--entrypoint sleep2.0 \
	ubuntu 10
	# command startup : sleep2.0 10
	```
	```yaml
	apiVersion: v1
	kind: Pod
	metadata:
		creationTimestamp: null
		labels:
			run: ubuntu-sleeper
		name: ubuntu-sleeper-pod
	spec:
		containers:
		- image: ubuntu
			name: ubuntu-sleeper
			command: ["sleep2.0"]
			args: ["10"]
	```
	- `command` 항목은 dockerfile의 **Entrypoint**를 재정의하고, `args` 항목은 dockerfile의 **CMD**를 재정의함
## ENV
### ENV Vlue Types
- Plain Key Value
	```yaml
	env:
		- name: APP_COLOR
			values: red
	```
- ConfigMap
	- configmap은 쿠버네티스에서 key-value 쌍의 형태로 구성 데이터를 전달하는 데 사용됨
	- 파드가 생성되면 키 값 쌍을 파드의 컨테이너 내부에서 호스팅되는 애플리케이션의 환경변수로 전달
	```yaml
	env:
		- name: APP_COLOR
			valueFrom:
				configMapKeyRef:
					name: app-config
					key: APP_COLOR
	---
	volumes:
	- name: app-config-volume
		configMap:
			name: app-config
	```

	- 생성
		```bash
		# kubectl create <configmap-name> --from-literal <key>=<value>
		kubectl create cm app-config \
		--from-literal APP_COLOR=blue \
		--from-literal APP_MOD=prod
		```
		- `--from-literal` 항목이 많아질수록 복잡해짐
		```bash
		# 파일로 지정해서 생성
		# kubectl create <configmap-name> --from-file <file-path>
		kubectl create cm app-config \
			--from-file=app_config.properties
		```
- Secrets

	- secret 생성
		```bash
		$ kubectl create secret generic app-secret \
		--from-literal DB_HOST=myslq \
		--from-literal DB_USER=root \
		--from-literal DB_PASSWORD=passrd

		$ kubectl create secret generic app-secret \
		--from-file=app_secret.properties
		```
	```yaml
	# ENV
	envFrom:
		- secretRef:
				name: app-secret
	---
	# Single ENV
	env:
		- name: DB_Password
			valueFrom:
				secretKeyRef:
					name: app-secret
					key: DB_PASSWORD
	---
	# Volume
	volumes:
	- name: app-secret-volume
		secret:
			secretName: app-secret
	```
	- Volume의 경우 3개의 속성으로 secret을 생성했을 때, 컨테이너 내부에서 `/opt/app-secret-volumes` 경로에 `DB_HOST`, `DB_USER`, `DB_PASSWORD` 의 이름을 갖는 3개의 파일이 생성되고 해당 파일의 내용을 cat으로 보면 value 값이 보임