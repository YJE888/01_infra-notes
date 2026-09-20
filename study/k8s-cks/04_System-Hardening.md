# System Hardening

## 목차

- [Overview of AppArmor](#overview-of-apparmor)
- [Practical - AppArmor](#practical---apparmor)
- [AppArmor and Kubernetes](#apparmor-and-kubernetes)
- [OCI and Container Runtimes](#oci-and-container-runtimes)
- [Configuring containerd and runc](#configuring-containerd-and-runc)
- [Container Runtime Interface](#container-runtime-interface)
- [Overview of Container Sandboxes](#overview-of-container-sandboxes)
- [Overview - gVisor and RunTimeClass](#overview---gvisor-and-runtimeclass)
- [Practical - gVisor](#practical---gvisor)
- [전체 이론 구조 — 계층별 방어(Defense in Depth) 관점](#전체-이론-구조--계층별-방어defense-in-depth-관점)

## Overview of AppArmor

- **Linux 커널에 내장된 보안 도구**로, "이 프로그램은 딱 이런 파일만 읽고, 이런 네트워크만 쓰고, 이런 동작만 하게 허락한다"는 규칙을 프로그램 하나하나에 걸어주는 시스템
- 프로그램이 실행되면 → 그 프로그램을 실행한 사용자의 모든 권한을 그대로 씀
  - 예: 웹서버 프로세스가 root로 실행되면, 이론상 root가 할 수 있는 모든 걸 할 수 있음
- AppArmor 적용 시 프로그램마다 "허용 목록(profile)"을 따로 만들어서 그 프로그램은 "허락받은 것"만 할 수 있음
  - 예: 웹서버는 /var/www 폴더만 읽고 쓸 수 있고, /etc/passwd 같은 건 절대 못 건드림

### Mandatory Access Control (MAC)

- Linux의 전통적인 접근 제어는 **DAC(Discretionary Access Control, 임의 접근 제어)**
  - 파일 소유자가 "이 파일은 나만, 또는 이 그룹만 읽게 하겠다"를 **스스로 정함**
  - 문제: 프로세스가 소유자의 권한을 그대로 물려받음 → 소유자가 root면 사실상 전부 접근 가능

- AppArmor는 **MAC(Mandatory Access Control, 강제 접근 제어)**을 구현함
  - 파일 소유자의 의사와 무관하게, **시스템 관리자가 미리 정한 규칙이 모든 걸 강제**함
  - root 권한으로 실행되는 프로세스라도, AppArmor 규칙이 막으면 못 함

> - DAC (기존 방식): 소유자가 권한을 정함 → root면 사실상 무제한
> - MAC (AppArmor): 관리자가 정한 규칙이 절대적 → root라도 규칙 밖은 불가능

### 왜 컨테이너 보안에서 중요한가

- 컨테이너가 침해당해도(해킹당해도), AppArmor 규칙이 걸려있으면 **공격자가 그 규칙 밖의 일은 아예 할 수 없음**
- 예를 들어 컨테이너 안의 프로세스가 호스트의 커널 모듈을 로드하려 시도해도, AppArmor가 커널 레벨에서 차단

### AppArmor vs SELinux (참고)

- 둘 다 비슷한 목적(리눅스 프로세스 권한 제한)의 도구
- AppArmor
  - 파일 "경로" 기준으로 규칙을 만듦 (직관적, 설정 쉬움) — Ubuntu, Debian 계열에서 주로 씀
- SELinux
  - 파일에 "라벨"을 붙여서 규칙을 만듦 (더 강력하지만 복잡함) — RedHat, CentOS 계열에서 주로 씀

## Practical - AppArmor

### 프로파일(profile) 작성 및 적용 실습 흐름

- AppArmor는 **프로세스 단위(주로 실행 파일 경로 기준)로 "허용 목록(whitelist)"** 을 만드는 방식
- "기본적으로 다 막고, 명시된 것만 허용" (default-deny)
- 이건 앞서 배운 NetworkPolicy의 "allow-list 모델"과 똑같은 사고방식
- 네트워크에서는 트래픽을, AppArmor에서는 파일/시스템 자원 접근을 이 방식으로 통제한다는 차이만 있음

#### 1단계 - AppArmor 설치 확인

```bash
# AppArmor가 이미 커널에 활성화되어 있는지 확인
cat /sys/module/apparmor/parameters/enabled
# Y 라고 나오면 활성화된 것

# 설치된 도구 확인
aa-status
```

#### 2단계 - 간단한 프로파일 작성

- 프로파일은 텍스트 파일로 작성
- 예를 들어 "이 프로그램은 쓰기 작업을 아예 못 하게" 만드는 프로파일임

```bash
/etc/apparmor.d/deny-write

#include <tunables/global>

profile deny-write flags=(attach_disconnected) {
#include <abstractions/base>

file, # 파일 관련 규칙 시작
deny /** w, # 모든 경로(/**)에 대해 쓰기(w) 거부
}
```

- `profile deny-write { ... }`
  - `deny-write`라는 이름의 규칙 묶음을 정의
- `file,`
  - 파일 관련 규칙을 쓰겠다는 선언
- `deny /** w,`
  - `/**`(모든 경로)에 대해 `w`(쓰기) 권한을 명시적으로 거부

#### 3단계 - 프로파일 로드

```bash
# 작성한 프로파일을 커널에 등록
sudo apparmor_parser -q /etc/apparmor.d/deny-write

# 로드됐는지 확인
sudo aa-status
```

#### 4단계 - 프로파일을 컨테이너에 적용

```bash
# 컨테이너 실행 시 이 프로파일을 적용
docker run --security-opt apparmor=deny-write my-image
```

#### 5단계 - 실제 동작 테스트

```bash
# 컨테이너 안에서
touch /tmp/test.txt
# Permission denied  ← AppArmor가 차단!
```

### 프로파일 모드 - enforce vs complain

| 모드         | 동작                                                         |
| ------------ | ------------------------------------------------------------ |
| **enforce**  | 규칙 위반 시 실제로 **차단**                                 |
| **complain** | 규칙 위반해도 **차단 안 하고 로그만 기록** (테스트/디버깅용) |

```bash
# complain 모드로 전환 (일단 뭐가 걸리는지 로그만 보고 싶을 때)
sudo aa-complain /etc/apparmor.d/deny-write

# enforce 모드로 전환 (실제로 차단하고 싶을 때)
sudo aa-enforce /etc/apparmor.d/deny-write
```

> - Pod Security Admission의 `audit`/`warn` vs `enforce` 개념과 똑같은 아이디어
> - "먼저 관찰만 해보고, 문제없으면 실제로 차단 걸기"라는 패턴이 여기서도 똑같이 적용됨

## AppArmor and Kubernetes

### Kubernetes에서 AppArmor 적용하는 방법

- Kubernetes Pod의 `securityContext`에서 AppArmor 프로파일을 지정할 수 있음

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-demo
spec:
  containers:
    - name: app
      image: nginx
      securityContext:
        appArmorProfile:
          type: Localhost
          localhostProfile: deny-write # 앞서 만든 프로파일 이름
```

### `type` 종류

| type             | 의미                                                                       |
| ---------------- | -------------------------------------------------------------------------- |
| `RuntimeDefault` | 컨테이너 런타임(containerd 등)이 기본 제공하는 프로파일 사용               |
| `Localhost`      | 노드에 직접 등록해둔 커스텀 프로파일 사용 (`localhostProfile`로 이름 지정) |
| `Unconfined`     | AppArmor 적용 안 함 (비권장)                                               |

- `RuntimeDefault`는 "특정 프로파일을 만들지 않아도, 컨테이너 런타임(containerd 등)이 **미리 합리적으로 만들어둔 기본 프로파일** 을 쓰겠다"는 의미
- **대부분의 컨테이너에서 특별한 이유가 없다면 이 정도만 적용해도 상당한 방어 효과**가 있음
- 커스텀 프로파일(`Localhost`)은 정말 특수한 요구사항이 있을 때만 필요

### 사전 준비 조건

- AppArmor 프로파일은 Pod가 스케줄링될 노드에 미리 등록되어 있어야됨
- Kubernetes가 자동으로 프로파일을 배포해주지 않음
- 각 워커 노드에 SSH로 접속해서 프로파일 파일을 직접 만들고 `apparmor_parser`로 로드
- Pod yaml에서 그 프로파일 이름을 참조
  > 만약 프로파일이 등록 안 된 노드에 Pod가 스케줄링되면, Pod 생성이 실패함

### 현재 적용된 프로파일 확인

```bash
# Pod 안에서 실제로 적용된 프로파일 확인
kubectl exec <pod-name> -- cat /proc/1/attr/current
```

## OCI and Container Runtimes

### OCI(Open Container Initiative)란

- "컨테이너가 어떻게 생겨야 하고, 어떻게 실행되어야 하는지"에 대한 업계 표준 규격

```scss
OCI 표준이 없던 시절:
Docker만의 독자적인 이미지 포맷, 독자적인 실행 방식
│
▼
문제: 다른 회사가 Docker와 호환되는 도구를 만들기 어려움
Docker에 종속됨 (vendor lock-in)

OCI 표준화 이후:
"컨테이너 이미지는 이런 형식이어야 한다" (OCI Image Spec)
"컨테이너는 이렇게 실행되어야 한다" (OCI Runtime Spec)
│
▼
결과: Docker, containerd, CRI-O 등 여러 도구가 서로 호환됨
Kubernetes는 특정 회사 제품에 종속되지 않고 다양한 런타임 선택 가능
```

### OCI의 2가지 핵심 스펙

| 스펙                 | 내용                                                     |
| -------------------- | -------------------------------------------------------- |
| **OCI Image Spec**   | 컨테이너 이미지의 형식 규정 (레이어 구조, 메타데이터 등) |
| **OCI Runtime Spec** | 컨테이너를 실제로 어떻게 시작/실행/종료할지 규정         |

### Container Runtime 종류

| 런타임            | 설명                                                                               |
| ----------------- | ---------------------------------------------------------------------------------- |
| **containerd**    | Docker에서 분리되어 나온 표준 컨테이너 런타임, Kubernetes에서 가장 널리 씀         |
| **CRI-O**         | Kubernetes 전용으로 만들어진 경량 런타임                                           |
| **runc**          | 실제로 컨테이너 프로세스를 "생성"하는 저수준 도구 (OCI Runtime Spec의 기준 구현체) |
| **Docker Engine** | 예전엔 Kubernetes와 직접 연동됐지만, 지금은 사용 안 함 (아래에서 설명)             |

### 계층 구조로 이해하기

```scss
kubelet (Kubernetes의 노드 에이전트)
│
│ CRI(Container Runtime Interface)라는 표준 인터페이스로 대화
▼
containerd (고수준 런타임 - 이미지 관리, 네트워크 등 담당)
│
│ OCI Runtime Spec으로 호출
▼
runc (저수준 런타임 - 실제로 Linux namespace/cgroup을 만들어서 "컨테이너 프로세스"를 기동)
│
▼
실제 리눅스 프로세스 (이게 우리가 아는 "컨테이너")
```

> - 컨테이너는 사실 "특별한 종류의 프로세스"일 뿐임
> - namespace(격리)와 cgroup(자원 제한)이라는 Linux 커널 기능을 조합해서 "마치 독립된 시스템처럼 보이게" 만든 일반 프로세스
> - `runc`가 바로 이 조합 작업을 실제로 수행하는 도구임

## Configuring containerd and runc

- 고수준 런타임 (containerd, CRI-O)
  - 역할: 이미지 다운로드, 저장, 네트워크 설정, 컨테이너 생명주기 "관리"
  - 비유: 레스토랑의 "매니저" (주문받고, 재료 준비 지시하고, 서빙까지 총괄)

- 저수준 런타임 (runc, runsc/gVisor, kata-runtime)
  - 역할: 실제로 namespace/cgroup을 조합해서 "프로세스 하나를 탄생"시키는 마지막 단계
  - 비유: 레스토랑의 "요리사" (매니저 지시를 받아 실제 요리를 만드는 사람)

### containerd 설정 파일

```bash
# 기본 설정 파일 생성
containerd config default > /etc/containerd/config.toml
```

- 설정 파일(`config.toml`)에서 다양한 보안/동작 옵션을 조정할 수 있음

### 주요 설정 예시

```toml
# /etc/containerd/config.toml

[plugins."io.containerd.grpc.v1.cri".containerd]
  default_runtime_name = "runc"     # 기본으로 쓸 저수준 런타임 지정

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
```

### cgroup driver 일치의 중요성 (`SystemdCgroup = true`)

- **cgroup(control group)** 은 프로세스의 CPU/메모리 등 자원 사용을 제한하는 커널 기능
- 이걸 관리하는 방식이 시스템에 두 가지가 있음(`systemd` 방식 vs `cgroupfs` 방식)
- **kubelet과 컨테이너 런타임이 서로 다른 방식을 쓰면 자원 관리가 충돌** 할 수 있으므로 둘을 반드시 일치시켜야 한다는 게 개념적 핵심이에요 (실습에서 `SystemdCgroup = true`로 맞췄던 이유)

### 여러 런타임을 동시에 등록 가능 (중요! — 뒤에 나올 gVisor와 연결됨)

```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
  # 일반적인 컨테이너용 runc
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
    runtime_type = "io.containerd.runc.v2"

  # 더 강하게 격리된 컨테이너용 gVisor(runsc)
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
    runtime_type = "io.containerd.runsc.v1"
```

- 하나의 노드에서 "이 Pod는 일반 runc로, 저 Pod는 더 안전한 gVisor로" 실행하는 게 가능함
- 이 내용이 `RuntimeClass`와 연결되는 핵심 개념임

### 설정 변경 후 재시작

```bash
systemctl restart containerd
```

## Container Runtime Interface

### CRI란?

- kubelet이 컨테이너 런타임과 "어떻게 대화할지" 정한 표준 인터페이스(API 규격)
- 구현 방식은 몰라도 되고, "이렇게 부르면 이렇게 응답한다"는 약속만 지키면 되는 것
  - CRI는 kubelet이 **"컨테이너를 만들어줘", "컨테이너 상태 알려줘" 같은 요청을 표준화된 형태(gRPC API)로 정의** 한 것임
  - kubelet은 이 인터페이스 뒤에 뭐가 있는지(containerd인지 CRI-O인지) 전혀 신경 쓰지 않음

### 왜 필요했나

```scss
CRI가 없던 시절:
kubelet 코드 안에 Docker 전용 코드가 직접 박혀있었음
│
▼
문제: 다른 런타임(containerd, CRI-O 등)을 쓰려면
kubelet 자체를 뜯어고쳐야 했음 → 매우 비효율적

CRI 도입 이후:
kubelet은 "CRI라는 표준 언어"로만 말함
│
▼
결과: containerd(CNCF)든 CRI-O(RedHat)든, CRI 표준만 지키면
kubelet과 아무 문제 없이 호환됨
```

- Kubernetes 입장에서는 어떤 회사의 런타임을 쓰든, CRI 규격만 지키면 다 호환됨
- Docker Engine이 CRI를 직접 지원 안 하게 되면서 (dockershim이라는 어댑터가 폐기되면서) Kubernetes 1.24부터 Docker를 직접 지원하지 않게됨
- Docker로 만든 이미지 자체는 OCI 표준이라 여전히 잘 돌아가고, "Docker Engine"이라는 런타임 자체를 못 쓰게 된 것뿐임

### CRI 확인 명령어

```bash
# 노드가 어떤 런타임을 쓰고 있는지 확인
kubectl get nodes -o wide
# CONTAINER-RUNTIME 컬럼에 containerd://1.7.x 같은 정보가 나옴

# crictl로 CRI 직접 확인 (kubectl과 유사하지만 런타임 레벨 조회 도구)
crictl ps
crictl images
```

## Overview of Container Sandboxes

### "Sandbox(샌드박스)"란?

- "모래상자"라는 뜻 그대로, 애들이 모래놀이를 하는 상자처럼, 문제가 생겨도 그 상자 밖으로 영향이 안 나가게 격리된 안전한 실행 공간을 의미

### 일반 컨테이너의 격리 수준 — 사실 "완전한 격리"가 아님

```scss
일반컨테이너(runc 기반)
│
▼
호스트 커널을 그대로 "공유"함 (namespace로 격리된 것처럼 보이지만, 커널은 하나)
│
▼
문제: 컨테이너 안에서 커널 취약점을 이용하면 호스트 커널까지 침투(컨테이너 탈출)
  가능;
```

- 일반 컨테이너는 "다른 프로세스인 척 보이게" 격리했을 뿐, **커널 자체는 호스트와 공유** 하고 있음
- 만약 커널에 취약점이 있으면, 그 취약점을 통해 컨테이너 경계를 넘어 호스트를 공격할 수 있음

### Container Sandbox — 더 강한 격리

- **커널 자체를 컨테이너와 분리** 시켜서, 설령 컨테이너가 뚫려도 진짜 호스트 커널까지는 도달하지 못하게 만드는 기술

```scss
일반 컨테이너: 컨테이너 ─── (같은 커널 공유) ─── 호스트
Sandboxed 컨테이너: 컨테이너 ─── (가짜/격리된 커널) ─── 진짜 호스트 커널
                                ↑
                                공격자가 여기까지만 도달, 진짜 커널엔 못 감
```

- 높은 격리 = 높은 보안, 낮은 성능 (가상머신급)
- 낮은 격리 = 낮은 보안, 높은 성능 (일반 컨테이너)
- 이게 바로 **"컨테이너는 가상머신만큼 강력한 격리를 제공하지 않는다"** 는 근본적 한계이고, Sandbox 기술이 등장한 이유

### 대표적인 Sandbox 기술 2가지

| 기술                | 방식                                                                |
| ------------------- | ------------------------------------------------------------------- |
| **gVisor**          | 유저스페이스에서 커널 기능을 흉내내는 "가짜 커널" 계층을 하나 더 둠 |
| **Kata Containers** | 아예 초경량 가상머신(VM)을 하나씩 띄워서 그 안에서 컨테이너를 실행  |

### 언제 이런 강력한 격리가 필요한가

- **신뢰할 수 없는 코드 실행** (예: 사용자가 업로드한 코드를 실행해주는 서비스)
- **멀티테넌시 환경** (여러 고객의 워크로드가 같은 노드에서 실행되는 경우)
- **강력한 규제/컴플라이언스 요구사항**이 있는 환경

> 일반적인 내부 신뢰된 애플리케이션에는 오버헤드(성능 저하) 때문에 잘 안 쓰고, **"특별히 위험한" 워크로드에만 선택적으로 적용**하는 게 일반적

## Overview - gVisor and RunTimeClass

- User Space (유저 공간) ← 일반 애플리케이션이 실행되는 곳, 권한 제한적
- Kernel Space (커널 공간) ← 하드웨어를 직접 제어하는 특권 영역

### gVisor란?

- gvisor는 Google이 만든 **"유저스페이스 커널"**
- 컨테이너의 시스템 콜(syscall)을 진짜 Linux 커널로 바로 보내지 않고, **gVisor가 중간에서 가로채서 자기가 직접 처리**
- 일반적으로 애플리케이션이 시스템 콜(syscall)을 호출하면 **User Space → Kernel Space로 직접** 넘어가짐
- gVisor는 이 경계에 **"가짜 커널"을 하나 끼워 넣는** 방식

- 일반 컨테이너
  - 애플리케이션 → syscall → 호스트 Linux 커널 (직접 호출)

- gVisor 컨테이너
  - 애플리케이션 → syscall → gVisor(가짜 커널, runsc) → (필요한 것만 선별해서) → 진짜 호스트 커널

> - gVisor는 syscall을 자기 코드로 재구현해서 처리하고, 정말 필요한 최소한의 경우에만 진짜 커널에 요청을 넘김
> - 애플리케이션이 아무리 위험한 syscall을 시도해도, 진짜 커널에는 도달하지 못하고 gVisor 선에서 걸러짐

### gVisor의 실행 파일 이름 — `runsc`

- `runc`가 일반 컨테이너를 실행하는 도구였다면, gVisor는 `runsc`(run sandboxed container)라는 자체 실행 도구를 사용함
- 위의 (containerd 설정)에서 본 것처럼, containerd에 `runsc`를 별도 런타임으로 등록해서 사용함

### RuntimeClass — "어떤 Pod에 어떤 런타임을 쓸지" 지정하는 Kubernetes 오브젝트

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc # containerd에 등록해둔 이름과 일치해야 함
```

- `RuntimeClass`라는 오브젝트를 하나 만들어두면, Pod에서 이걸 이름으로 참조할 수 있음

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sandboxed-pod
spec:
  runtimeClassName: gvisor # 이 Pod는 gVisor로 실행해라!
  containers:
    - name: app
      image: nginx
```

### 이게 왜 좋은가 — 선택적 적용

- 클러스터 안에서 신뢰된 내부 서비스 Pod → runtimeClassName 생략 (기본 runc, 빠름)
- 클러스터 안에서 신뢰할 수 없는 외부 코드 실행 Pod → runtimeClassName: gvisor (느리지만 안전)

> 같은 클러스터, 같은 노드 안에서도 Pod마다 다른 수준의 격리를 선택적으로 적용할 수 있다는 게 RuntimeClass의 핵심 장점

## Practical - gVisor

### 실습

#### 1단계 - gVisor(runsc) 설치 (각 노드에)

```bash
# gVisor 바이너리 다운로드 및 설치
$ curl -fsSL https://gvisor.dev/archive.key | sudo gpg --dearmor -o /usr/share/keyrings/gvisor-archive-keyring.gpg

$ echo "deb [signed-by=/usr/share/keyrings/gvisor-archive-keyring.gpg] https://storage.googleapis.com/gvisor/releases release main" | sudo tee /etc/apt/sources.list.d/gvisor.list

$ sudo apt-get update && sudo apt-get install -y runsc
```

#### 2단계 - containerd에 gVisor 런타임 등록

```toml
# /etc/containerd/config.toml

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
```

```bash
systemctl restart containerd
```

#### 3단계 - RuntimeClass 오브젝트 생성

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
```

```bash
kubectl apply -f runtimeclass-gvisor.yaml
```

#### 4단계 - gVisor로 실행되는 Pod 배포

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gvisor-test
spec:
  runtimeClassName: gvisor
  containers:
    - name: app
      image: nginx
```

```bash
kubectl apply -f gvisor-pod.yaml
```

#### 5단계 - 실제로 gVisor에서 실행 중인지 검증

```bash
# Pod가 스케줄된 노드에 SSH 접속 후
kubectl exec gvisor-test -- dmesg
# gVisor 환경에서는 dmesg 출력이 일반 Linux와 다르게 나오거나 제한됨

# 또는 커널 버전 확인 시 gVisor 특유의 문자열이 보임
kubectl exec gvisor-test -- uname -a
# 출력에 "gVisor"라는 단어가 포함되어 있으면 확인된 것
```

- gVisor Pod 안에서 `uname -a`를 실행하면 일반 Linux와 다른 결과가 나오는 이유는, **gVisor가 진짜 Linux 커널이 아니라 "Linux 커널인 척 흉내 내는 자체 구현체"** 이기 때문임
- 이게 바로 "유저스페이스 커널"이라는 개념이 실제로 눈에 보이는 순간임
- 일반 컨테이너: syscall이 커널까지 "한 번에" 도달
- gVisor 컨테이너: syscall이 gVisor를 "거쳐서" 처리됨 (한 단계 더 거침)
  - 이 "한 단계 더 거치는" 과정 자체가 약간의 지연(latency)을 만들게 됨

#### 6단계 - 일반 Pod와 성능/동작 비교

- gVisor는 syscall을 중간에서 가로채서 처리하는 만큼, 일반 컨테이너보다 약간의 성능 오버헤드가 있음
- 따라서 "정말 필요한 워크로드에만" 선택적으로 적용하는 게 실무 원칙

## 흐름 정리

```scssAppArmor = 프로세스 단위로 "뭘 할 수 있는지" 세밀하게 제한하는 도구
│
▼
Kubernetes Pod에 AppArmor 프로파일 적용 (securityContext)
│
▼
컨테이너는 결국 OCI 표준을 따르는 "특별한 프로세스"
│
▼
kubelet → CRI(표준 인터페이스) → containerd → runc(또는 runsc) → 실제 프로세스 생성
│
▼
문제: 일반 컨테이너(runc)는 호스트 커널을 그대로 공유 → 침해 시 위험
│
▼
해결책: Container Sandbox (gVisor 등) → 가짜 커널 계층으로 추가 격리
│
▼
RuntimeClass로 "이 Pod는 gVisor로, 저 Pod는 일반 runc로" 선택적 적용
```

## 전체 이론 구조 — 계층별 방어(Defense in Depth) 관점

- 1층 방어: RBAC/인증 — "누가 애초에 Pod를 만들 수 있는가"
- 2층 방어: Pod Security Standards — "Pod 스펙 자체가 안전한 모양인가"
- 3층 방어: SecurityContext (capabilities, runAsNonRoot 등) — "프로세스 자체의 권한 제한"
- 4층 방어: AppArmor/Seccomp — "프로세스가 할 수 있는 시스템 콜/파일 접근 제한"
- 5층 방어: Container Sandbox (gVisor) — "설령 위 방어가 다 뚫려도, 진짜 커널까지 도달 못 하게"
