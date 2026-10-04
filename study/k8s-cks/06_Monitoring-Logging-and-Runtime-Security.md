# Monitoring, Logging and Runtime Security

## 목차

- [Overview of Falco](#overview-of-falco)
- [Installing Falco](#installing-falco)
- [Falco - Practical](#falco---practical)
- [Writing Custom Falco Rules and Macros](#writing-custom-falco-rules-and-macros)
- [Falco Rule for /dev/mem Access](#falco-rule-for-devmem-access)
- [Falco Configuration File](#falco-configuration-file)
- [Introduction to Sysdig](#introduction-to-sysdig)
- [Audit Logging In-Detail](#audit-logging-in-detail)
- [Falco Rule 작성법](#falco-rule-작성법)

## Overview of Falco

### Falco란

- CNCF(Cloud Native Computing Foundation) 소속의 오픈소스 **런타임 보안 도구**임
- 실행 중인 컨테이너/호스트에서 발생하는 **비정상적이거나 의심스러운 행위를 실시간으로 탐지**하는 게 목적임
- Sysdig라는 회사에서 만들어서 CNCF에 기증한 프로젝트임 (그래서 뒤에 Sysdig도 같이 다룸)

### 왜 필요한가

- 지금까지 배운 것들(RBAC, NetworkPolicy, Pod Security Standards, 이미지 스캔 등)은 전부 **사전 예방(preventive)** 성격임
- 근데 아무리 사전 예방을 잘해도, 알려지지 않은 취약점(zero-day)이나 설정 실수로 뚫릴 가능성은 항상 남아있음
- Falco는 이미 침투가 "일어나고 있는 시점"을 실시간으로 잡아내는 **탐지(detective) 계층**임
- 즉, 지금까지 배운 게 "문을 얼마나 튼튼하게 잠그느냐"였다면 Falco는 "누가 몰래 들어왔을 때 알람을 울리는 것"임

### 동작 원리

- 커널 레벨에서 시스템 콜(syscall)을 실시간으로 가로채서 관찰함
- 두 가지 방식으로 syscall을 수집함
  - **커널 모듈(kernel module)** 방식
    - 커널에 직접 모듈을 올려서 수집 (오래된 방식)
  - **eBPF** 방식
    - 커널 모듈 없이 eBPF 프로그램으로 안전하게 수집 (최신 권장 방식, 앞서 배운 Cilium과 같은 기술 기반임)
- 수집한 syscall을 **미리 정의된 규칙(rule)** 과 대조해서, 규칙에 걸리면 알림(alert)을 발생시킴

### 대표 탐지 시나리오

- 컨테이너 안에서 셸(`/bin/bash`, `/bin/sh`)이 실행됨 (정상적인 웹서버 컨테이너라면 있으면 안 되는 행위)
- 컨테이너 안에서 민감한 파일(`/etc/shadow` 등)에 쓰기 시도가 발생함
- 컨테이너가 예상치 못한 아웃바운드 네트워크 연결을 시도함
- 컨테이너 안에서 `kubectl`, `curl` 같은 도구가 설치되거나 실행됨 (원래 없어야 하는데 생겼다는 건 공격자가 도구를 심은 정황일 수 있음)

### CKS에서의 위치

- CKS 도메인 6(모니터링, 로깅, 런타임 보안)의 핵심 도구임
- 앞서 배운 Audit Logging이 "API 서버로 들어온 요청"을 기록하는 거라면, Falco는 "노드/컨테이너 안에서 실제로 벌어지는 행동"을 감시하는 거라서 계층이 다름

## Installing Falco

### 설치 방식 종류

- 호스트에 직접 데몬으로 설치하는 방식
- Kubernetes에 DaemonSet으로 설치하는 방식 (모든 노드에서 실행되어야 하니까 DaemonSet이 자연스러운 형태임)

### 패키지로 직접 설치 (호스트 방식)

```bash
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" | sudo tee -a /etc/apt/sources.list.d/falcosecurity.list

sudo apt-get update
sudo apt-get install -y falco
```

### 설치 시 드라이버 선택 물어봄

- 설치 과정에서 syscall 수집 방식을 물어보는 경우가 있음
- eBPF 방식을 권장함 (커널 모듈보다 안전하고, 커널 재컴파일 걱정도 없음)

### 서비스 시작

```bash
sudo systemctl enable falco
sudo systemctl start falco
sudo systemctl status falco
```

### Helm으로 Kubernetes에 설치하는 방식 (실무에서 더 흔함)

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco falcosecurity/falco --namespace falco --create-namespace
```

### 설치 확인

```bash
kubectl get pods -n falco
# 모든 노드에 하나씩 DaemonSet Pod가 떠있어야 정상임
```

## Falco - Practical

### 기본 동작 확인

```bash
# Falco 로그를 실시간으로 확인
sudo journalctl -u falco -f
```

### 셸 실행 탐지 테스트

```bash
# 임의의 컨테이너에 접속해서 셸 실행
kubectl exec -it <pod-name> -- /bin/bash

# Falco 로그에 아래와 같은 알림이 뜸
Warning A shell was spawned in a container with an attached terminal
(user=root container_id=xxxx container_name=my-app shell=bash)
```

### 민감 파일 접근 탐지 테스트

```bash
kubectl exec -it <pod-name> -- cat /etc/shadow

Warning Sensitive file opened for reading (user=root file=/etc/shadow)
```

### Falco 로그 심각도(Priority) 레벨

| 레벨          | 의미                   |
| ------------- | ---------------------- |
| EMERGENCY     | 시스템 사용 불가       |
| ALERT         | 즉시 조치 필요         |
| CRITICAL      | 심각한 상태            |
| ERROR         | 오류 상태              |
| WARNING       | 경고성 조건            |
| NOTICE        | 정상이지만 중요한 상태 |
| INFORMATIONAL | 정보성 메시지          |
| DEBUG         | 디버깅 메시지          |

### 알림을 어디로 보낼지 설정 가능

- 기본은 stdout/로그 파일로 출력됨
- 실무에서는 Slack, Kafka, Elasticsearch 등으로 알림을 전달하는 **Falcosidekick**이라는 별도 컴포넌트를 붙여서 씀

```bash
helm install falcosidekick falcosecurity/falcosidekick
```

### CKS 시험 관점

- Falco를 설치하고, 특정 행위를 발생시켜서 로그에 잡히는지 확인하는 실습형 문제가 나올 가능성 높음
- 로그를 특정 파일로 리다이렉션하거나 grep으로 특정 이벤트를 찾는 문제도 나올 수 있음

## Writing Custom Falco Rules and Macros

### Rule(규칙)이란

- "이런 조건을 만족하는 syscall이 발생하면 알림을 울려라"라는 정의임
- 기본 규칙 파일 위치

```bash
/etc/falco/falco_rules.yaml # Falco 기본 제공 규칙 (직접 수정 비권장)
/etc/falco/falco_rules.local.yaml # 사용자 커스텀 규칙 (여기에 추가하는 게 원칙)
```

### Rule 기본 구조

```yaml
- rule: Terminal shell in container
  desc: A shell was used as the entrypoint/exec point into a container
  condition: >
    spawned_process and container
    and shell_procs and proc.tty != 0
  output: >
    A shell was spawned in a container (user=%user.name container=%container.name shell=%proc.name)
  priority: WARNING
  tags: [container, shell]
```

- `condition`: 언제 이 규칙이 발동할지 (조건식)
- `output`: 발동됐을 때 남길 로그 메시지 형식 (%로 변수 삽입 가능)
- `priority`: 심각도
- `tags`: 분류용 태그

### Macro(매크로)란

- 여러 규칙에서 **반복해서 쓰이는 조건식을 재사용 가능하게 이름 붙여놓은 것**임
- 코드에서 함수를 만들어서 재사용하는 것과 같은 개념임

```yaml
- macro: shell_procs
  condition: (proc.name in (bash, sh, zsh, ash))
```

- 위에서 본 규칙의 `shell_procs`가 바로 이 매크로를 참조하는 것임
- 매크로를 하나 만들어두면 여러 규칙에서 재사용 가능해서 유지보수가 편해짐

### List(리스트)도 존재함

```yaml
- list: sensitive_files
  items: [/etc/shadow, /etc/passwd, /etc/sudoers]
```

- 반복되는 "값 목록"을 재사용하기 위한 것임 (매크로가 조건식 재사용이라면, list는 값 재사용임)

### 커스텀 규칙 작성 실습 예시

- 특정 네임스페이스에서 셸 실행 시 CRITICAL로 탐지

```yaml
# /etc/falco/falco_rules.local.yaml

- rule: Shell in production namespace
  desc: Detect shell execution in the production namespace
  condition: >
    spawned_process and container
    and shell_procs
    and k8s.ns.name = "production"
  output: >
    CRITICAL: Shell spawned in production (user=%user.name pod=%k8s.pod.name ns=%k8s.ns.name)
  priority: CRITICAL
  tags: [production, shell]
```

### 규칙 적용 후 재시작

```bash
sudo systemctl restart falco
```

### CKS 시험 관점

- 기존 규칙을 약간 수정하거나(예: priority 변경), 새 매크로/규칙을 추가하는 문제가 나올 가능성 높음
- YAML 문법 자체보다 `condition` 필드를 정확히 작성할 수 있는지가 핵심임

## Falco Rule for /dev/mem Access

### /dev/mem이 뭔가

- 리눅스에서 **물리 메모리(RAM) 전체에 직접 접근할 수 있게 해주는 특수 디바이스 파일**임
- 이 파일에 접근할 수 있으면, 커널이나 다른 프로세스의 메모리 내용을 직접 읽거나 조작할 수 있음
- 정상적인 애플리케이션이라면 **절대로 접근할 이유가 없는 파일**임

### 왜 이게 심각한 탐지 대상인가

- `/dev/mem`에 접근한다는 것 자체가 "매우 낮은 수준(low-level)의 시스템 조작을 시도하고 있다"는 강력한 신호임
- 공격자가 커널 익스플로잇을 시도하거나, 메모리에서 민감한 정보(암호화 키, 패스워드 등)를 직접 긁어가려 할 때 이 경로를 씀
- 정상 워크로드에서는 거의 발생하지 않기 때문에 **오탐(false positive)이 매우 낮은 탐지 규칙**임

### Falco 기본 규칙에 이미 포함되어 있음

```yaml
- rule: Read/Write Memory Devices
  desc: An attempt to read/write /dev/mem or /dev/kmem
  condition: >
    (open_read or open_write)
    and (fd.name startswith /dev/mem or fd.name startswith /dev/kmem)
  output: >
    Memory device opened for reading/writing (user=%user.name command=%proc.cmdline device=%fd.name)
  priority: CRITICAL
```

### 왜 CKS에서 예시로 자주 언급되는가

- "정상적인 동작에서는 절대 안 일어나는데, 공격일 때만 나타나는" 대표적인 탐지 패턴이기 때문임
- Falco 규칙 작성 원칙을 설명할 때 교과서적인 예시로 자주 쓰임 (오탐 최소화 + 명확한 위협 신호)

### 테스트해보기

```bash
kubectl exec -it <pod-name> -- cat /dev/mem
# Falco가 CRITICAL 알림을 즉시 발생시킴
```

## Falco Configuration File

### 설정 파일 위치

- /etc/falco/falco.yaml

### 주요 설정 항목

```yaml
rules_file:
  - /etc/falco/falco_rules.yaml
  - /etc/falco/falco_rules.local.yaml

json_output: true

log_level: info

priority: debug

outputs:
  rate: 1
  max_burst: 1000

file_output:
  enabled: true
  filename: /var/log/falco/falco.log

syslog_output:
  enabled: true

http_output:
  enabled: false
  url: ""
```

### 항목별 의미

| 설정                     | 의미                                                                 |
| ------------------------ | -------------------------------------------------------------------- |
| `rules_file`             | 어떤 규칙 파일들을 로드할지 (여러 개 나열 가능, 순서대로 로드됨)     |
| `json_output`            | 로그를 JSON 형식으로 출력할지 (다른 도구와 연동 시 파싱 편하라고 씀) |
| `priority`               | 어느 심각도 이상부터 로그로 남길지 (여기보다 낮은 심각도는 무시됨)   |
| `outputs.rate/max_burst` | 짧은 시간에 알림이 폭주하는 걸 제한하는 레이트 리미팅                |
| `file_output`            | 파일로도 로그를 저장할지                                             |
| `syslog_output`          | 시스템 syslog로도 보낼지                                             |
| `http_output`            | 외부 HTTP 엔드포인트(Falcosidekick 등)로 전송할지                    |

### 여러 출력 채널을 동시에 켤 수 있음

- 파일 + syslog + HTTP를 동시에 활성화해서, 다양한 시스템(로그 수집기, SIEM, 알림 채널)으로 동시에 보낼 수 있음
- 실무에서는 HTTP 출력을 켜서 Falcosidekick을 거쳐 Slack이나 Elasticsearch로 넘기는 구성이 흔함

### CKS 시험 관점

- `priority` 값을 바꿔서 특정 심각도 이상만 잡게 하거나, `file_output`을 활성화해서 특정 경로에 로그를 남기게 설정하는 문제가 나올 수 있음
- 이건 앞서 배운 Audit Logging의 `--audit-log-path` 개념과 똑같은 패턴임 (설정을 켜야 실제로 파일에 남음)

## Introduction to Sysdig

### Sysdig란

- Falco를 만든 회사이자, 그 회사가 만든 **더 광범위한 시스템 관찰/트러블슈팅 도구**임
- Falco가 "보안 규칙 기반 탐지"에 특화됐다면, Sysdig는 원래 **시스템 전반의 상태를 깊이 들여다보는 범용 진단 도구**로 시작함

### Sysdig의 두 가지 형태

| 구분                            | 설명                                                                                |
| ------------------------------- | ----------------------------------------------------------------------------------- |
| **sysdig (오픈소스 CLI 도구)**  | 시스템 콜을 캡처하고 분석하는 커맨드라인 도구, Falco와 같은 커널 계측 기술을 공유함 |
| **Sysdig Secure (상용 플랫폼)** | Falco를 포함해서 이미지 스캔, 컴플라이언스, 런타임 보안을 통합한 상용 SaaS 제품     |

### sysdig CLI 기본 사용

```bash
# 시스템 전체 syscall 실시간 관찰
sysdig

# 특정 프로세스만 필터링
sysdig proc.name=nginx

# 네트워크 관련 syscall만
sysdig -c topconns
```

### Falco와의 관계 정리

```scss
Sysdig (원조 시스템 계측 기술/회사)
  │
  ▼
그 기술을 이용해서 "보안 규칙 기반 탐지"에 특화시킨 것 = Falco
  │
  ▼
Falco가 CNCF에 기증되어 독립적인 오픈소스 프로젝트로 성장함
```

- 같은 커널 계측 기반 기술을 공유하지만, **Falco는 "보안 이벤트 탐지"에 집중**하고 **Sysdig CLI는 "범용 시스템 진단"에 집중**한다는 차이가 있음

### CKS에서의 위치

- CKS 커리큘럼에서 Sysdig는 보통 **Falco의 배경/유래를 이해하기 위한 개념 소개** 정도로 가볍게 다뤄짐
- 실기 문제로 sysdig CLI를 직접 쓰는 경우는 Falco보다 훨씬 드묾

## Audit Logging In-Detail

### 복습 - 이미 다룬 기본 개념

- 앞서 kube-apiserver의 `--audit-policy-file`, `--audit-log-path` 등 기본 설정은 이미 다룬 내용임
- 이번엔 **정책(Policy) 파일을 더 정교하게 작성하는 법**과 **실전 활용법**을 깊게 다룸

### Audit Policy의 세부 구조 복습

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: <레벨>
    resources: [...]
    namespaces: [...]
    verbs: [...]
    users: [...]
```

- `rules`는 **위에서부터 순서대로 평가**되고, **첫 번째로 매칭되는 규칙이 적용됨** (뒤에 더 구체적인 규칙이 있어도 앞에서 이미 걸리면 그걸로 끝임 - 이게 핵심 포인트임)

### 실전 정책 예시 - 세밀한 다중 규칙

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # 1. 특정 시스템 계정의 노이즈성 요청은 아예 기록 안 함 (맨 위에 위치해야 함)
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]
    resources:
      - group: ""
        resources: ["endpoints", "services"]

  # 2. Secret은 최대한 자세히 기록 (단, 값 자체는 metadata만 - 보안 위해 Request/Response는 위험할 수 있음)
  - level: Metadata
    resources:
      - group: ""
        resources: ["secrets"]

  # 3. configmap 변경은 요청 내용까지 기록
  - level: Request
    verbs: ["create", "update", "patch", "delete"]
    resources:
      - group: ""
        resources: ["configmaps"]

  # 4. 나머지는 기본적으로 Metadata 레벨
  - level: Metadata
```

### 규칙 순서가 왜 중요한지 예시로 이해

- 만약 1번 규칙이 없다면, `kube-proxy`의 반복적인 watch 요청이 계속 로그에 쌓여서 **로그 용량이 폭증**함
- 그래서 "노이즈성 요청은 맨 위에서 걸러내고(None), 중요한 리소스는 그 아래에서 상세히(Request/RequestResponse) 잡는" 순서가 실전에서 중요함

### omitStages - 특정 처리 단계는 기록 제외

```yaml
rules:
  - level: RequestResponse
    omitStages:
      - "RequestReceived"
```

- API 요청은 내부적으로 여러 단계(RequestReceived → ResponseStarted → ResponseComplete)를 거침
- `RequestReceived` 단계는 "요청이 막 들어온 시점"이라 아직 처리 결과를 모름 - 이 단계를 기록에서 빼면 중복 로그를 줄일 수 있음

### Webhook Backend - 파일 대신 외부 시스템으로 전송

```yaml
# apiserver 옵션
--audit-webhook-config-file=/etc/kubernetes/audit-webhook-kubeconfig
--audit-webhook-batch-max-wait=5s
```

```yaml
# audit-webhook-kubeconfig 내용 (kubeconfig 형식을 재활용함)
apiVersion: v1
kind: Config
clusters:
  - cluster:
      server: https://audit-collector.example.com/events
    name: audit-webhook
contexts:
  - context:
      cluster: audit-webhook
      user: ""
    name: audit-webhook
current-context: audit-webhook
```

- 파일이 아니라 외부 로그 수집 시스템(SIEM 등)으로 실시간 전송하고 싶을 때 씀
- 대규모 클러스터에서는 로컬 파일보다 이 방식이 실무적으로 더 많이 쓰임

### Audit 로그 분석 실전 - jq 활용

```bash
# 특정 사용자의 모든 행위 조회
cat /var/log/api-audit.log | jq 'select(.user.username == "bob")'

# 특정 리소스에 대한 delete 요청만 조회
cat /var/log/api-audit.log | jq 'select(.verb == "delete" and .objectRef.resource == "secrets")'

# 실패한(403) 요청만 조회 - 권한 없는 시도를 찾을 때 유용함
cat /var/log/api-audit.log | jq 'select(.responseStatus.code == 403)'
```

### Falco와 Audit Logging의 역할 차이 정리

| 구분        | Audit Logging                                                         | Falco                                                                |
| ----------- | --------------------------------------------------------------------- | -------------------------------------------------------------------- |
| 관찰 대상   | kube-apiserver로 들어온 **API 요청**                                  | 노드/컨테이너 안에서 벌어지는 **실제 시스템 행위**                   |
| 탐지 범위   | "누가 무슨 API를 호출했는지"                                          | "컨테이너 안에서 무슨 프로세스가 실행됐는지, 무슨 파일에 접근했는지" |
| 예시        | "bob이 secret을 조회 시도함 (403)"                                    | "nginx 컨테이너 안에서 갑자기 bash 셸이 실행됨"                      |
| 우회 가능성 | API를 거치지 않는 공격(예: 컨테이너 exec 후 직접 파일 조작)은 못 잡음 | API를 거치지 않아도 실제 행위 기반이라 잡을 수 있음                  |

- 이 둘은 **서로 보완 관계**임 - Audit Logging만으로는 "API 레벨의 행위"만 보이고, Falco만으로는 "누가 그 API를 호출했는지의 맥락"이 부족할 수 있음
- 그래서 실무에서는 둘 다 켜두고, 사고 발생 시 **두 로그를 상호 대조(correlate)**해서 전체 그림을 파악함

### CKS 시험 관점

- Audit Policy의 규칙 순서/omitStages 등 세부 옵션을 정확히 작성하는 문제
- jq를 이용한 로그 필터링/분석 문제 (특정 사용자, 특정 verb, 특정 응답 코드 조합)
- Falco와 Audit Logging의 "역할 차이"를 묻는 개념 문제

## Falco Rule 작성법

### 1. 규칙 파일의 기본 구조

Falco 규칙은 YAML 형식이며, 4가지 필수/선택 요소로 구성됨

```yaml
- rule: <규칙 이름> # 고유한 이름 (필수)
  desc: <설명> # 이 규칙이 뭘 탐지하는지 (권장)
  condition: <조건식> # 언제 발동할지 (필수)
  output: <출력 메시지> # 발동 시 남길 로그 형식 (필수)
  priority: <심각도> # EMERGENCY ~ DEBUG (필수)
  tags: [태그1, 태그2] # 분류용 (선택)
  enabled: true/false # 이 규칙을 켤지 끌지 (선택, 기본 true)
```

파일 위치

```bash
/etc/falco/falco_rules.yaml # Falco 기본 제공 규칙 (직접 수정 비권장)
/etc/falco/falco_rules.local.yaml # 사용자 커스텀 규칙 (여기에 작성하는 게 원칙)
```

### 2. condition 작성법

#### 기본 연산자

| 연산자                   | 의미              |
| ------------------------ | ----------------- |
| `and`, `or`, `not`       | 논리 연산         |
| `=`, `!=`                | 같다/다르다       |
| `in`                     | 목록에 포함되는지 |
| `contains`               | 문자열 포함 여부  |
| `startswith`, `endswith` | 문자열 접두/접미  |
| `>`, `<`, `>=`, `<=`     | 숫자 비교         |

#### 자주 쓰는 필드

```text
proc.name → 실행된 프로세스 이름
proc.cmdline → 전체 실행 명령어
proc.pname → 부모 프로세스 이름
user.name → 실행한 사용자
fd.name → 열린 파일/네트워크 경로
container.id → 컨테이너 ID
container.name → 컨테이너 이름
container.image.repository → 컨테이너 이미지 이름
k8s.pod.name → Pod 이름
k8s.ns.name → 네임스페이스 이름
evt.type → 이벤트(syscall) 종류
fd.sip / fd.dip → 네트워크 연결의 출발지/목적지 IP
```

#### 내장 이벤트 타입 매크로 (Falco가 기본 제공)

| 매크로            | 감지 시점                                                   |
| ----------------- | ----------------------------------------------------------- |
| `spawned_process` | 새 프로세스가 **실행**될 때 (execve 계열 syscall 발생 시점) |
| `open_read`       | 파일이 **읽기용으로 열릴** 때                               |
| `open_write`      | 파일이 **쓰기용으로 열릴** 때                               |
| `inbound`         | 외부에서 들어오는 네트워크 연결                             |
| `outbound`        | 밖으로 나가는 네트워크 연결                                 |

> `spawned_process`, `open_write` 등을 조건 맨 앞에 두는 이유: Falco가 관찰하는 모든 이벤트(파일 접근, 네트워크, 프로세스 실행 등) 중 "지금 보고 싶은 이벤트 종류"로 범위를 좁히기 위함. 이런 매크로는 사용자가 만든 커스텀 매크로(shell_procs 등)와 달리 **Falco 자체가 기본 제공**하는 것임.

### 3. 단계별 조건식 예시 (질문 흐름 그대로 정리)

#### 예시 A — 기본형: 컨테이너 안에서 셸 실행 감지

```yaml
condition: >
  spawned_process
  and container
  and proc.name in (bash, sh, zsh, csh)
```

해석

- `spawned_process` → 새 프로세스가 실행되는 이벤트인지 확인
- `and container` → 그게 컨테이너 안에서 일어난 것인지 확인 (호스트 직접 실행은 제외됨)
- `and proc.name in (...)` → 실행된 프로세스 이름이 bash/sh/zsh/csh 중 하나인지 확인
- 세 조건이 `and`로 연결되어 있어 **전부 참이어야** 발동

| 상황                                 | 발동 여부                          |
| ------------------------------------ | ---------------------------------- |
| 컨테이너 안에서 bash 실행            | 발동                               |
| 컨테이너 안에서 nginx 실행 (셸 아님) | 발동 안 함                         |
| 호스트(컨테이너 밖)에서 bash 실행    | 발동 안 함 (container 조건 불만족) |

#### 예시 B — 매크로로 리팩토링 + 네임스페이스 예외 추가

```yaml
condition: >
  spawned_process
  and container
  and shell_procs
  and not k8s.ns.name in (kube-system, monitoring)
```

해석

- `shell_procs`는 예시 A의 `proc.name in (bash, sh, zsh, csh)`를 매크로로 뽑아낸 것

```yaml
- macro: shell_procs
  condition: (proc.name in (bash, sh, zsh, csh))
```

- `and not k8s.ns.name in (kube-system, monitoring)` → 이 두 네임스페이스는 예외 처리
  - `k8s.ns.name in (...)` 결과를 `not`으로 뒤집음
  - 해당 네임스페이스면 → 조건 전체가 false → 규칙 발동 안 함(예외 처리됨)
  - `not`은 뒤의 `in (...)` 전체에 걸리므로, 명확히 하려면 괄호를 직접 칠 수도 있음: `and not (k8s.ns.name in (kube-system, monitoring))`

왜 예외가 필요한가

- kube-system 같은 시스템 네임스페이스는 관리자가 디버깅 목적으로 셸에 자주 접속함
- 이런 "흔한 정상 행위"까지 매번 탐지하면 알림 피로(alert fatigue)가 생겨서, 진짜 위협 신호가 묻힐 수 있음
- 자주 발생하는 정상 행위는 예외 처리하고, 진짜 이상 행위만 눈에 띄게 하는 게 탐지 규칙 설계의 핵심 원칙

| 상황                               | 예외 없는 규칙 | 예외 추가된 규칙    |
| ---------------------------------- | -------------- | ------------------- |
| production에서 bash 실행           | 발동           | 발동                |
| kube-system에서 디버깅용 bash 실행 | 발동(노이즈)   | 조용함(예외 처리됨) |

### 4. output 작성법

`%필드명` 형식으로 실제 값을 로그 메시지에 삽입함

```yaml
output: >
  Shell spawned in container
  (user=%user.name command=%proc.cmdline
   container=%container.name image=%container.image.repository
   pod=%k8s.pod.name ns=%k8s.ns.name)
```

실제 출력 예시

```text
Shell spawned in container (user=root command=bash container=nginx-abc123 image=nginx pod=nginx-deploy-xyz ns=production)
```

### 주의 — output은 필수 필드

- `output`을 생략하거나 규칙 로드 자체가 실패함

```bash
  falco -r my_rules.yaml --validate
  # Error: rule 'Read sensitive file' has no output field
```

- 빈 문자열(`output: ""`)은 문법적으로는 통과하지만 로그에 아무 정보도 안 남아 사실상 무의미함
- 설명 중 등장한 `output: "..."`는 실제 Falco 문법이 아니라, 반복 설명을 피하기 위한 생략 표기였음 — 실전에서는 반드시 완전한 메시지를 작성해야 함

### 5. Macro(매크로) — 조건 재사용

```yaml
- macro: <매크로 이름>
  condition: <조건식>
```

예시:

```yaml
- macro: shell_procs
  condition: (proc.name in (bash, sh, zsh, csh, ksh))
```

```yaml
- rule: Shell in container
  condition: spawned_process and container and shell_procs
  output: >
    Shell spawned in container (user=%user.name container=%container.name)
  priority: WARNING
```

매크로 중첩도 가능:

```yaml
- macro: sensitive_files
  condition: (fd.name in (/etc/shadow, /etc/passwd, /etc/sudoers))

- macro: sensitive_file_read
  condition: (open_read and sensitive_files)
```

매크로를 쓰는 이유: 같은 조건을 여러 규칙에서 반복 작성하면 나중에 수정할 때 모든 규칙을 일일이 찾아 고쳐야 함 — 매크로로 빼두면 한 곳만 수정해도 전체 규칙에 반영됨

### 6. List(리스트) — 값 목록 재사용

```yaml
- list: sensitive_directories
  items: [/etc, /root, /var/lib/kubelet]
```

```yaml
condition: >
  open_write
  and container
  and fd.directory in (sensitive_directories)
```

Macro vs List 차이

```text
Macro = 조건식(condition) 자체를 재사용
List = 값의 목록만 재사용 (조건식 안에서 in으로 참조)
```

### 7. append: true — 기존 규칙에 조건 추가

```yaml
- rule: Terminal shell in container
  append: true
  condition: >
    and not k8s.ns.name in (kube-system)
```

- 완전히 새 규칙을 만드는 게 아니라, 기존 규칙(falco_rules.yaml)의 condition 뒤에 이 조건을 이어 붙임
- 활용: 기본 규칙 자체는 유용한데 특정 네임스페이스에서 오탐이 잦을 때, 전체를 새로 짜지 않고 예외 조건만 append로 추가

### 8. priority 값 (심각도 순)

```text
# falco.yaml의 priority 설정값보다 덜 심각한 규칙은 로그에 아예 안 남음

EMERGENCY > ALERT > CRITICAL > ERROR > WARNING > NOTICE > INFORMATIONAL > DEBUG
```

### 9. 종합 예시 — payment 네임스페이스에서 네트워크 도구 실행 탐지

```yaml
- list: network_tools
  items: [curl, wget, nc, ncat]

- macro: payment_namespace
  condition: (k8s.ns.name = "payment")

- rule: Network tool used in payment namespace
  desc: Detect usage of network diagnostic/download tools inside the payment namespace
  condition: >
    spawned_process
    and container
    and payment_namespace
    and proc.name in (network_tools)
  output: >
    Network tool executed in payment namespace
    (user=%user.name command=%proc.cmdline
     pod=%k8s.pod.name container=%container.name)
  priority: CRITICAL
  tags: [payment, network, exfiltration]
```

### 10. 문법 검증

```bash
falco -r /etc/falco/falco_rules.local.yaml --validate
```

문법 오류가 있으면 서비스가 안 뜨거나 "rule loading error"가 발생함
