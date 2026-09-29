# Supply Chain Security

## 목차

- [Supply Chain Security](#supply-chain-security)
  - [목차](#목차)
  - [Vulnerability, Exploit and Payload](#vulnerability-exploit-and-payload)
    - [Vulnerability(취약점)](#vulnerability취약점)
    - [Exploit(익스플로잇)](#exploit익스플로잇)
    - [Payload(페이로드)](#payload페이로드)
    - [세 개념의 관계](#세-개념의-관계)
    - [컨테이너 맥락에서의 예시](#컨테이너-맥락에서의-예시)
  - [Container Security Scanning](#container-security-scanning)
    - [개념](#개념)
    - [스캔이 필요한 이유](#스캔이-필요한-이유)
    - [스캔 시점에 따른 분류](#스캔-시점에-따른-분류)
    - [스캔 도구 종류](#스캔-도구-종류)
  - [Scan images for known vulnerabilities](#scan-images-for-known-vulnerabilities)
    - [Trivy 실습 위주로 정리](#trivy-실습-위주로-정리)
      - [설치](#설치)
      - [기본 스캔 명령](#기본-스캔-명령)
      - [출력 예시 구조](#출력-예시-구조)
    - [심각도(Severity) 필터링](#심각도severity-필터링)
    - [CI/CD 파이프라인에서 자동 실패시키기](#cicd-파이프라인에서-자동-실패시키기)
    - [특정 취약점 무시하기 (오탐/예외 처리)](#특정-취약점-무시하기-오탐예외-처리)
    - [파일시스템/Git 저장소 직접 스캔도 가능](#파일시스템git-저장소-직접-스캔도-가능)
    - [CKS 시험 관점](#cks-시험-관점)
  - [Scanning K8S Clusters for Security Best Practices](#scanning-k8s-clusters-for-security-best-practices)
    - [개념](#개념-1)
    - [kube-bench 복습](#kube-bench-복습)
    - [그 외 클러스터 스캔 도구](#그-외-클러스터-스캔-도구)
    - [kube-hunter의 특이점](#kube-hunter의-특이점)
    - [CKS 시험 관점](#cks-시험-관점-1)
  - [Overview of Static Analysis](#overview-of-static-analysis)
    - [Static Analysis(정적 분석)란](#static-analysis정적-분석란)
    - [Kubernetes 맥락에서의 정적 분석 대상](#kubernetes-맥락에서의-정적-분석-대상)
    - [정적 분석이 찾아내는 문제 유형](#정적-분석이-찾아내는-문제-유형)
    - [대표 도구](#대표-도구)
    - [실습 예시 (kubesec)](#실습-예시-kubesec)
    - [왜 "배포 전에" 정적 분석을 하는 게 중요한가](#왜-배포-전에-정적-분석을-하는-게-중요한가)
    - [CKS 시험 관점](#cks-시험-관점-2)
  - [Securing the Docker Daemon](#securing-the-docker-daemon)
    - [Docker Daemon이란](#docker-daemon이란)
    - [Docker Daemon이 왜 위험할 수 있는가](#docker-daemon이-왜-위험할-수-있는가)
    - [보안 강화 방향](#보안-강화-방향)
    - [User Namespace Remapping (참고 개념)](#user-namespace-remapping-참고-개념)
  - [DockerFile - Security Best Practices](#dockerfile---security-best-practices)
    - [이미지 자체를 안전하게 "설계"하는 단계의 중요성](#이미지-자체를-안전하게-설계하는-단계의-중요성)
    - [핵심 모범 사례 목록](#핵심-모범-사례-목록)
      - [1. 최소한의 베이스 이미지 사용](#1-최소한의-베이스-이미지-사용)
      - [2. 비root 사용자로 실행](#2-비root-사용자로-실행)
      - [3. 불필요한 도구/패키지 설치 금지](#3-불필요한-도구패키지-설치-금지)
      - [4. 멀티스테이지 빌드로 빌드 도구 제거](#4-멀티스테이지-빌드로-빌드-도구-제거)
      - [5. 시크릿을 이미지에 절대 포함시키지 않기](#5-시크릿을-이미지에-절대-포함시키지-않기)
      - [6. 이미지 태그 고정 (불변성)](#6-이미지-태그-고정-불변성)
      - [7. COPY를 ADD보다 우선 사용](#7-copy를-add보다-우선-사용)
  - [Docker Daemon Configuration File](#docker-daemon-configuration-file)
    - [설정 파일 위치](#설정-파일-위치)
    - [주요 보안 관련 설정 항목](#주요-보안-관련-설정-항목)
    - [설정 적용 방법](#설정-적용-방법)
    - [CKS 시험 관점](#cks-시험-관점-3)
  - [Protecting Docker Daemon Socket](#protecting-docker-daemon-socket)
    - [Docker Daemon Socket이란](#docker-daemon-socket이란)
    - [왜 이게 심각한 위협인가](#왜-이게-심각한-위협인가)
    - [자주 발생하는 실수 — 소켓을 컨테이너에 마운트](#자주-발생하는-실수--소켓을-컨테이너에-마운트)
    - [보호 방법](#보호-방법)
  - [Practical - Docker Daemon Socket on TLS](#practical---docker-daemon-socket-on-tls)
    - [배경 — 기본 상태의 위험성](#배경--기본-상태의-위험성)
    - [TLS를 적용해서 안전하게 만드는 실습 흐름](#tls를-적용해서-안전하게-만드는-실습-흐름)
      - [1단계 - CA, 서버 인증서, 클라이언트 인증서 생성](#1단계---ca-서버-인증서-클라이언트-인증서-생성)
      - [2단계 - Daemon 설정에 TLS 적용](#2단계---daemon-설정에-tls-적용)
      - [3단계 - 클라이언트에서 인증서로 접속](#3단계---클라이언트에서-인증서로-접속)
      - [4단계 - 인증서 없이 접속 시도 시 거부되는지 확인](#4단계---인증서-없이-접속-시도-시-거부되는지-확인)
    - [CKS 시험 관점](#cks-시험-관점-4)
  - [BOM and SBOM](#bom-and-sbom)
    - [BOM(Bill of Materials)이란](#bombill-of-materials이란)
    - [SBOM(Software Bill of Materials)이란](#sbomsoftware-bill-of-materials이란)
    - [왜 SBOM이 중요한가](#왜-sbom이-중요한가)
      - [1. 새로운 취약점이 발견됐을 때 빠른 대응 가능](#1-새로운-취약점이-발견됐을-때-빠른-대응-가능)
      - [2. 공급망 투명성 확보](#2-공급망-투명성-확보)
      - [3. 라이선스 컴플라이언스](#3-라이선스-컴플라이언스)
    - [SBOM 표준 형식](#sbom-표준-형식)
  - [Practical -Generating SBOM](#practical--generating-sbom)
    - [도구 — Syft (Anchore)](#도구--syft-anchore)
      - [설치](#설치-1)
      - [SBOM 생성](#sbom-생성)
      - [다양한 형식으로 출력](#다양한-형식으로-출력)
    - [Trivy로 SBOM과 취약점 스캔을 함께 하는 방법](#trivy로-sbom과-취약점-스캔을-함께-하는-방법)
    - [CI/CD 파이프라인 통합 예시 흐름](#cicd-파이프라인-통합-예시-흐름)
    - [CKS 시험 관점](#cks-시험-관점-5)
  - [전체 흐름 정리](#전체-흐름-정리)

---

## Vulnerability, Exploit and Payload

### Vulnerability(취약점)

- 소프트웨어나 시스템 안에 존재하는 "결함" 또는 "약점"을 의미함
- 설계 실수, 코딩 실수, 설정 실수 등 다양한 원인으로 발생함
- 존재한다고 해서 곧바로 피해가 생기는 건 아니고, 누군가 그걸 "악용"해야 실제 문제가 됨
- 예: 특정 버전의 오픈소스 라이브러리에 메모리를 초과해서 쓸 수 있는 버그가 있음 (buffer overflow)
- CVE(Common Vulnerabilities and Exposures)라는 공통 식별 번호로 전 세계가 공유해서 관리함
  - 형식: `CVE-2024-12345` 같은 형태
  - CVSS(Common Vulnerability Scoring System) 점수로 심각도를 0~10점 사이로 매김

### Exploit(익스플로잇)

- 취약점을 실제로 "악용하는 방법" 또는 그 방법을 구현한 코드를 의미함
- 취약점이 "문(door)이 고장 나서 잠기지 않는 상태"라면, exploit은 "그 문을 열고 들어가는 실제 행위/도구"임
- 취약점만 있고 exploit이 아직 없으면 상대적으로 덜 위험하다고 평가되지만, exploit이 공개되는 순간 위험도가 급격히 올라감
- Exploit-DB, Metasploit 같은 공개 데이터베이스/프레임워크에 실제 exploit 코드가 등록되기도 함

### Payload(페이로드)

- exploit이 성공한 "이후에" 실제로 실행되는 악성 코드나 작업을 의미함
- 취약점을 뚫고 들어간 다음 "무엇을 할지"에 해당하는 부분임
- 예: 시스템에 침투한 뒤 랜섬웨어를 설치하거나, 암호화폐 채굴 프로그램을 심거나, 백도어를 설치하는 행위 자체가 payload임

### 세 개념의 관계

```scss
Vulnerability (문이 고장남)
    │
    ▼
Exploit (그 문을 여는 방법/도구)
    │
    ▼
Payload (문을 열고 들어가서 실제로 하는 나쁜 짓)
```

- 이 3단계 흐름을 이해하는 게 컨테이너 보안 전체를 이해하는 기초임
- CKS 도메인에서 다루는 이미지 스캔, 정적 분석, 런타임 보안 등은 결국 이 3단계 중 어느 지점을 막을지에 대한 도구들임
  - 이미지 스캔: vulnerability를 사전에 찾아서 제거
  - 런타임 보안(Falco 등): exploit이나 payload가 실행되는 순간을 탐지

### 컨테이너 맥락에서의 예시

- 취약점: 컨테이너 이미지 안의 오래된 openssl 라이브러리에 알려진 버그가 있음
- Exploit: 그 버그를 이용해서 원격에서 코드를 실행시키는 스크립트가 공개되어 있음
- Payload: 그 스크립트로 침투한 공격자가 컨테이너 안에 채굴 프로그램을 설치함

## Container Security Scanning

### 개념

- 컨테이너 이미지나 실행 중인 컨테이너를 검사해서, 알려진 취약점이나 잘못된 설정이 있는지 찾아내는 작업 전체를 의미함
- "언제" 스캔하느냐에 따라 여러 단계로 나뉨

### 스캔이 필요한 이유

- 컨테이너 이미지는 보통 여러 "레이어"로 구성됨 (베이스 OS 이미지 + 여러 패키지 + 애플리케이션 코드)
- 각 레이어마다 알려진 취약점을 가진 패키지가 포함되어 있을 수 있음
- 개발자가 직접 작성한 코드는 안전해도, 가져다 쓴 오픈소스 라이브러리나 베이스 이미지 자체에 취약점이 숨어있을 수 있음

### 스캔 시점에 따른 분류

| 시점                      | 설명                                                                               |
| ------------------------- | ---------------------------------------------------------------------------------- |
| **빌드 시점 (CI/CD)**     | 이미지를 만들 때 파이프라인에서 자동으로 스캔, 취약점 발견 시 빌드 자체를 실패시킴 |
| **레지스트리 저장 시점**  | 이미지 레지스트리(Harbor, ECR 등)가 저장된 이미지를 주기적으로 재스캔              |
| **배포 시점 (Admission)** | 앞서 배운 ImagePolicyWebhook 등으로 배포 직전에 검증                               |
| **런타임 시점**           | 이미 실행 중인 컨테이너를 주기적으로 스캔해서, 새로 발견된 취약점이 있는지 확인    |

### 스캔 도구 종류

- Trivy (Aqua Security, 오픈소스, 사용이 간단해서 CKS 실습에서 자주 사용됨)
- Clair (CoreOS 계열, 레지스트리 연동형)
- Grype (Anchore)
- Snyk (상용 서비스형)

## Scan images for known vulnerabilities

### Trivy 실습 위주로 정리

#### 설치

```bash
sudo apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy
```

#### 기본 스캔 명령

```bash
trivy image nginx:1.25
```

#### 출력 예시 구조

```bash
nginx:1.25 (debian 12.1)

Total: 15 (UNKNOWN: 0, LOW: 5, MEDIUM: 6, HIGH: 3, CRITICAL: 1)

┌─────────────┬────────────────┬──────────┬───────────────────┐
│ Library │ Vulnerability │ Severity │ Installed Version │
├─────────────┼────────────────┼──────────┼───────────────────┤
│ openssl │ CVE-2024-XXXXX │ CRITICAL │ 3.0.11 │
└─────────────┴────────────────┴──────────┴───────────────────┘
```

### 심각도(Severity) 필터링

```bash
# CRITICAL, HIGH만 보고 싶을 때
trivy image --severity CRITICAL,HIGH nginx:1.25
```

### CI/CD 파이프라인에서 자동 실패시키기

```bash
# CRITICAL 취약점 발견 시 exit code 1 반환 → 파이프라인 실패
trivy image --severity CRITICAL --exit-code 1 nginx:1.25
```

- `--exit-code` 옵션이 CI/CD 게이트의 핵심임
- exit code가 0이 아니면 CI 도구(Jenkins, GitLab CI 등)가 이 단계를 "실패"로 처리해서 이후 배포 단계로 넘어가지 못하게 막음

### 특정 취약점 무시하기 (오탐/예외 처리)

```bash
# .trivyignore 파일에 무시할 CVE 번호를 적어둠
echo "CVE-2024-XXXXX" >> .trivyignore
trivy image nginx:1.25
```

- 오탐이거나, 실제로 영향받지 않는 경로의 취약점일 때 예외 처리하는 용도임
- 무분별하게 사용하면 진짜 위험한 취약점까지 무시될 수 있어서 신중하게 관리해야 함

### 파일시스템/Git 저장소 직접 스캔도 가능

```bash
trivy fs ./my-app-directory
trivy repo https://github.com/example/repo
```

### CKS 시험 관점

- Trivy 명령어를 직접 실행해서 결과를 해석하고, 특정 심각도 이상만 필터링하는 문제 유형이 나올 수 있음
- 스캔 결과를 파일로 저장하라는 형태의 문제도 나올 수 있음 (`-o` 옵션 등)

## Scanning K8S Clusters for Security Best Practices

### 개념

- 이미지 자체의 취약점이 아니라, **클러스터 전체의 설정이 보안 모범 사례를 따르고 있는지**를 점검하는 영역임
- 앞서 다룬 kube-bench가 바로 여기 속함 (CIS 벤치마크 기준 점검)

### kube-bench 복습

```bash
kube-bench run --targets master,node,etcd
```

- 파일 권한, 인증서 설정, admission plugin 활성화 여부 등을 종합적으로 점검함

### 그 외 클러스터 스캔 도구

| 도구            | 특징                                                                       |
| --------------- | -------------------------------------------------------------------------- |
| **kube-bench**  | CIS Kubernetes Benchmark 기반 정적 설정 점검                               |
| **kubescape**   | CIS 벤치마크 + NSA/CISA 가이드라인 + 커스텀 프레임워크까지 광범위하게 지원 |
| **kube-hunter** | 공격자 관점에서 클러스터를 "침투 테스트"하듯 스캔 (실제로 취약점을 찔러봄) |
| **Popeye**      | 클러스터 안의 잘못 설정되거나 낭비되는 리소스(orphan 리소스 등)를 점검     |

### kube-hunter의 특이점

- kube-bench가 "설정 파일을 읽어서" 점검하는 방식이라면, kube-hunter는 실제로 "네트워크로 공격을 시도"해보는 능동적 방식임
- 예: 앞서 다룬 kubelet API의 인증 없는 접근 가능 여부를 실제로 네트워크 요청을 보내서 확인함
- 그래서 kube-hunter는 실제 운영 클러스터에서 함부로 돌리면 위험할 수 있어서, 테스트 환경에서 먼저 검증하는 게 권장됨

### CKS 시험 관점

- kube-bench 실행/결과 해석이 가장 핵심 (앞서 여러 번 다룬 내용)
- kube-hunter, kubescape는 개념 이해 위주로 다뤄질 가능성이 높음

## Overview of Static Analysis

### Static Analysis(정적 분석)란

- 코드나 설정 파일을 **실제로 실행하지 않고** 그 내용 자체를 분석해서 문제를 찾는 방법임
- 반대 개념은 Dynamic Analysis(동적 분석)로, 실제로 실행시켜보면서 동작을 관찰하는 방식임

### Kubernetes 맥락에서의 정적 분석 대상

- YAML 매니페스트 파일 (Pod, Deployment, NetworkPolicy 등)
- Dockerfile
- Helm 차트
- Terraform 등 IaC(Infrastructure as Code) 파일

### 정적 분석이 찾아내는 문제 유형

- `privileged: true`로 설정된 Pod
- `resources.limits`가 없는 컨테이너 (자원 제한 누락)
- `latest` 태그 사용 (불변성 위배)
- 루트로 실행되도록 방치된 컨테이너
- 과도한 RBAC 권한 (와일드카드 사용 등)
- 네임스페이스 미지정

### 대표 도구

| 도구                    | 특징                                                               |
| ----------------------- | ------------------------------------------------------------------ |
| **kubesec**             | Kubernetes YAML을 점수화해서 위험도를 매김                         |
| **kube-score**          | 매니페스트에 대한 모범 사례 검사                                   |
| **Checkov**             | Kubernetes뿐 아니라 Terraform, CloudFormation 등 광범위한 IaC 지원 |
| **Conftest (OPA 기반)** | Rego 정책 언어로 커스텀 규칙을 정의해서 검사                       |

### 실습 예시 (kubesec)

```bash
kubesec scan pod.yaml
```

```json
{
  "score": -3,
  "scoring": {
    "critical": [
      {
        "selector": "containers[].securityContext.privileged",
        "reason": "Privileged containers can allow almost completely unrestricted host access"
      }
    ]
  }
}
```

### 왜 "배포 전에" 정적 분석을 하는 게 중요한가

- CI/CD 파이프라인 초반 단계에서 문제를 잡을수록 수정 비용이 적음 ("shift-left" 원칙)
- 이미 운영 중인 클러스터에서 문제를 발견하는 것보다, 애초에 배포되기 전에 걸러내는 게 훨씬 안전하고 저렴함

### CKS 시험 관점

- 정적 분석 도구를 직접 설치해서 돌리는 문제보다는, "왜 이 설정이 위험한지" 판단하는 개념 문제나, 앞서 배운 SecurityContext/RBAC 지식을 활용해서 매니페스트를 직접 고치는 문제로 나올 가능성이 높음

## Securing the Docker Daemon

### Docker Daemon이란

- Docker 컨테이너를 실제로 생성/실행/관리하는 백그라운드 프로세스임 (`dockerd`)
- 사용자가 `docker run` 같은 명령을 입력하면, 이 daemon이 그 요청을 받아서 실제 작업을 수행함
- CKS에서는 Kubernetes 자체보다 "컨테이너 런타임을 다루는 호스트 레벨 보안"의 일부로 다뤄짐 (containerd 환경에서도 유사한 원리가 적용됨)

### Docker Daemon이 왜 위험할 수 있는가

- Docker Daemon은 기본적으로 **root 권한으로 실행**됨
- Daemon에 접근할 수 있는 사람은 사실상 호스트 전체에 대한 root 권한을 가진 것과 마찬가지임
- 이유: 컨테이너를 만들 때 호스트의 디렉토리를 마운트하거나, privileged 모드로 실행하는 것도 가능하기 때문임

### 보안 강화 방향

| 영역                | 강화 방법                                            |
| ------------------- | ---------------------------------------------------- |
| 접근 제어           | Daemon 소켓에 대한 접근을 제한 (뒤에서 자세히 다룸)  |
| 사용자 네임스페이스 | 컨테이너 안의 root를 호스트의 비root 사용자로 매핑   |
| 로깅/감사           | Daemon의 모든 API 호출을 로그로 남김                 |
| 리소스 제한         | 컨테이너가 호스트 자원을 무제한으로 쓰지 못하게 제한 |
| 최신 버전 유지      | Docker 자체의 보안 패치를 빠르게 적용                |

### User Namespace Remapping (참고 개념)

- 컨테이너 안에서는 root(UID 0)처럼 보이지만, 실제 호스트에서는 비root의 높은 UID로 매핑되는 기능임
- 이걸 설정하면, 설령 컨테이너 탈출이 발생해도 호스트에서는 root 권한이 아니게 되어 피해가 제한됨

## DockerFile - Security Best Practices

### 이미지 자체를 안전하게 "설계"하는 단계의 중요성

- 앞서 다룬 스캔/정적 분석은 "이미 만들어진 것"을 검사하는 사후 대응이라면, Dockerfile 작성 단계는 애초에 안전하게 "만드는" 사전 예방임

### 핵심 모범 사례 목록

#### 1. 최소한의 베이스 이미지 사용

```dockerfile
# 나쁜 예 - 불필요한 패키지가 많은 무거운 이미지
FROM ubuntu:22.04

# 좋은 예 - 꼭 필요한 것만 있는 경량 이미지
FROM alpine:3.19
# 또는 아예 shell도 없는 distroless 이미지
FROM gcr.io/distroless/static-debian12
```

- 베이스 이미지가 크고 복잡할수록 그 안에 포함된 패키지 수가 많아지고, 그만큼 취약점이 숨어있을 확률도 올라감

#### 2. 비root 사용자로 실행

```dockerfile
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
```

- 앞서 SecurityContext에서 배운 `runAsNonRoot`와 같은 목적을 이미지 레벨에서 미리 반영하는 것임

#### 3. 불필요한 도구/패키지 설치 금지

```dockerfile
# 나쁜 예 - 디버깅용 도구를 이미지에 그대로 남김
RUN apt-get install -y curl wget netcat vim

# 이런 도구들은 공격자가 침투 후 정찰/추가 공격에 악용할 수 있음
```

#### 4. 멀티스테이지 빌드로 빌드 도구 제거

```dockerfile
# 빌드 단계 - 컴파일러, 빌드 도구 등이 포함됨
FROM golang:1.22 AS builder
WORKDIR /app
COPY . .
RUN go build -o myapp

# 최종 단계 - 실행에 필요한 결과물만 가져옴
FROM alpine:3.19
COPY --from=builder /app/myapp /myapp
ENTRYPOINT ["/myapp"]
```

- 빌드 단계에서 쓰인 컴파일러, 소스코드, 빌드 캐시 등이 최종 이미지에 전혀 남지 않음
- 공격 표면(attack surface)을 크게 줄이는 효과가 있음

#### 5. 시크릿을 이미지에 절대 포함시키지 않기

```dockerfile
# 절대 하면 안 되는 예
ENV DB_PASSWORD=supersecret123
COPY id_rsa /root/.ssh/id_rsa
```

- 이미지 레이어에 한번 새겨지면, 나중에 그 레이어를 삭제해도 이미지 히스토리에 흔적이 남아 추출 가능함
- 시크릿은 반드시 런타임에 Kubernetes Secret이나 외부 시크릿 관리 도구로 주입해야 함

#### 6. 이미지 태그 고정 (불변성)

```dockerfile
# 나쁜 예
FROM node:latest

# 좋은 예 - 정확한 버전 고정
FROM node:20.11.0-alpine
```

- 앞서 다룬 `imagePullPolicy`/`latest` 태그의 문제와 같은 맥락임

#### 7. COPY를 ADD보다 우선 사용

- `ADD`는 원격 URL 다운로드, 압축 해제 등 부가 기능이 있어서 예상치 못한 동작을 유발할 수 있음
- 단순 파일 복사 목적이면 `COPY`가 더 명확하고 안전함

## Docker Daemon Configuration File

### 설정 파일 위치

- /etc/docker/daemon.json

### 주요 보안 관련 설정 항목

```json
{
  "icc": false,
  "userns-remap": "default",
  "no-new-privileges": true,
  "live-restore": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

| 설정                                  | 의미                                                                                                              |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `icc` (Inter-Container Communication) | `false`로 하면 컨테이너끼리 기본 브리지 네트워크로 자유롭게 통신하는 걸 차단                                      |
| `userns-remap`                        | User Namespace Remapping 활성화 (앞서 설명한 root UID 매핑)                                                       |
| `no-new-privileges`                   | 컨테이너 프로세스가 실행 중에 추가 권한을 얻는 것을 차단 (SecurityContext의 allowPrivilegeEscalation과 같은 개념) |
| `live-restore`                        | Daemon이 재시작되어도 실행 중인 컨테이너는 계속 살아있게 유지                                                     |
| `log-opts`                            | 로그 파일 크기 제한 (무한정 쌓여서 디스크가 꽉 차는 것 방지)                                                      |

### 설정 적용 방법

```bash
# 설정 파일 수정 후
sudo systemctl restart docker
```

### CKS 시험 관점

- `daemon.json`의 특정 항목이 누락되었거나 잘못된 값으로 설정된 상황을 찾아서 고치는 문제 유형으로 나올 가능성이 높음

## Protecting Docker Daemon Socket

### Docker Daemon Socket이란

- /var/run/docker.sock
- Docker CLI(`docker` 명령어)가 Daemon과 통신할 때 쓰는 **Unix 소켓 파일** 임
- 이 소켓에 접근 가능한 사람/프로세스는 **Daemon에 명령을 내릴 수 있음 = 사실상 호스트 root 권한** 을 갖는 것과 같음

```scss
소켓에 접근 가능
│
▼
docker run -v /:/host --privileged ubuntu 같은 명령 실행 가능
│
▼
호스트의 루트 파일시스템(/)을 컨테이너 안에 통째로 마운트
│
▼
호스트 시스템 파일에 자유롭게 접근 = 사실상 호스트 완전 장악
```

### 왜 이게 심각한 위협인가

### 자주 발생하는 실수 — 소켓을 컨테이너에 마운트

```yaml
# 위험한 패턴 (CI/CD 도구에서 흔히 발견됨 - Docker-in-Docker 목적)
volumeMounts:
  - name: docker-socket
    mountPath: /var/run/docker.sock
volumes:
  - name: docker-socket
    hostPath:
      path: /var/run/docker.sock
```

- CI/CD 파이프라인에서 "컨테이너 안에서 또 다른 컨테이너를 빌드"하기 위해 이런 패턴을 종종 씀
- 하지만 이 Pod가 침해당하면 공격자가 그대로 호스트 Docker Daemon을 통째로 장악할 수 있음
- 이게 CKS에서 "이 볼륨 마운트가 왜 위험한지" 묻는 대표적인 함정 패턴임

### 보호 방법

1. **소켓 파일 권한 제한**

```bash
chmod 660 /var/run/docker.sock
chown root:docker /var/run/docker.sock
```

- `docker` 그룹에 속한 사용자만 접근 가능하도록 제한
- 단, `docker` 그룹에 속한다는 것 자체가 이미 강한 권한이므로 그룹 멤버 관리를 신중히 해야 함

2. **소켓을 컨테이너에 절대 마운트하지 않기**

- Docker-in-Docker가 꼭 필요하면, 소켓 마운트 대신 격리된 DinD(Docker-in-Docker) 전용 컨테이너를 쓰거나 rootless 방식을 고려

3. **TCP 소켓 대신 Unix 소켓 유지, 혹은 TCP를 쓴다면 반드시 TLS 적용**

- 다음 섹션에서 자세히 다룸

## Practical - Docker Daemon Socket on TLS

### 배경 — 기본 상태의 위험성

- Docker Daemon을 네트워크(TCP)로 원격 접근 가능하게 열어두면, 기본적으로는 **인증 없이 아무나 접근 가능**한 매우 위험한 상태가 됨

```bash
# 위험한 설정 (인증 없음)
dockerd -H tcp://0.0.0.0:2375
```

- 이 포트에 접근할 수 있는 사람은 누구나 그 호스트에서 컨테이너를 마음대로 생성/실행 가능함

### TLS를 적용해서 안전하게 만드는 실습 흐름

#### 1단계 - CA, 서버 인증서, 클라이언트 인증서 생성

```bash
# CA 키 생성
openssl genrsa -out ca-key.pem 4096
openssl req -x509 -new -nodes -key ca-key.pem -days 365 -out ca.pem -subj "/CN=docker-ca"

# 서버 키/인증서 생성 (Daemon용)
openssl genrsa -out server-key.pem 4096
openssl req -new -key server-key.pem -out server.csr -subj "/CN=docker-host"
openssl x509 -req -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -days 365

# 클라이언트 키/인증서 생성 (docker CLI용)
openssl genrsa -out key.pem 4096
openssl req -new -key key.pem -out client.csr -subj "/CN=client"
openssl x509 -req -in client.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out cert.pem -days 365
```

- 앞서 etcd/apiserver에서 배운 mTLS 구조와 완전히 동일한 원리임 (CA 하나로 서버/클라이언트 인증서를 각각 서명)

#### 2단계 - Daemon 설정에 TLS 적용

```json
// /etc/docker/daemon.json
{
  "tls": true,
  "tlscacert": "/etc/docker/certs/ca.pem",
  "tlscert": "/etc/docker/certs/server-cert.pem",
  "tlskey": "/etc/docker/certs/server-key.pem",
  "tlsverify": true,
  "hosts": ["tcp://0.0.0.0:2376"]
}
```

- `tlsverify: true`가 핵심임 — 이게 있어야 클라이언트도 인증서를 제시해야만 접속 허용됨 (mTLS)
- 포트도 암호화 안 된 기본 포트(2375)가 아니라 TLS 전용 포트(2376)를 씀

```bash
systemctl restart docker
```

#### 3단계 - 클라이언트에서 인증서로 접속

```bash
docker --tlsverify \
  --tlscacert=ca.pem \
  --tlscert=cert.pem \
  --tlskey=key.pem \
  -H=docker-host:2376 version
```

#### 4단계 - 인증서 없이 접속 시도 시 거부되는지 확인

```bash
docker -H=docker-host:2376 version
# 에러 발생 - TLS 핸드셰이크 실패
```

### CKS 시험 관점

- 이 흐름은 앞서 다룬 etcd/kube-apiserver mTLS 실습과 구조적으로 동일하니, 그 개념을 그대로 적용하면 풀 수 있음
- "CA 생성 → 서버/클라이언트 인증서 서명 → 설정 파일에 반영 → 검증"이라는 패턴이 CKS 전반에 반복해서 등장함

## BOM and SBOM

### BOM(Bill of Materials)이란

- 원래 제조업에서 쓰이던 용어로, **제품을 만드는 데 들어간 모든 부품의 목록** 을 의미함
- 예: 자동차를 만들 때 어떤 나사, 어떤 엔진 부품이 얼마나 들어갔는지 정리한 문서

### SBOM(Software Bill of Materials)이란

- BOM 개념을 소프트웨어에 적용한 것으로, **소프트웨어(또는 컨테이너 이미지)를 구성하는 모든 구성 요소(라이브러리, 패키지, 버전 정보 등)의 목록** 을 의미함
- 컨테이너 이미지 SBOM 예시 (개념)
  - ubuntu:22.04 (베이스 OS)
  - openssl 3.0.2
  - python 3.11.4
  - flask 2.3.2
  - requests 2.31.0
  - ... (이미지 안의 모든 구성 요소)

### 왜 SBOM이 중요한가

#### 1. 새로운 취약점이 발견됐을 때 빠른 대응 가능

```scss
새로운 CVE가 openssl 3.0.x에서 발견됨
│
▼
SBOM이 있으면: "우리 이미지 중 openssl 3.0.2를 쓰는 게 몇 개인지" 즉시 검색 가능
SBOM이 없으면: 모든 이미지를 일일이 다시 스캔해야 함 (시간 소요, 누락 위험)
```

#### 2. 공급망 투명성 확보

- 소프트웨어가 어떤 구성 요소로 이루어져 있는지 명확히 알 수 있어서, 공급망 공격(supply chain attack)에 대한 대응력이 높아짐
- 최근 각국 정부/규제 기관(미국 행정명령 등)이 SBOM 제출을 의무화하는 추세임

#### 3. 라이선스 컴플라이언스

- 각 구성 요소의 오픈소스 라이선스를 추적해서, 법적 문제가 없는지 확인하는 용도로도 활용됨

### SBOM 표준 형식

| 형식                                      | 특징                                            |
| ----------------------------------------- | ----------------------------------------------- |
| **SPDX** (Software Package Data Exchange) | 리눅스 재단 주도, 가장 널리 쓰이는 표준 중 하나 |
| **CycloneDX**                             | OWASP 주도, 보안 중심으로 설계됨                |

## Practical -Generating SBOM

### 도구 — Syft (Anchore)

Trivy도 SBOM 생성을 지원하지만, Syft가 SBOM 생성 전용 도구로 널리 쓰임

#### 설치

```bash
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
```

#### SBOM 생성

```bash
syft nginx:1.25 -o table

NAME VERSION TYPE
libssl3 3.0.11 deb
python3 3.11.2 deb
curl 7.88.1 deb
...
```

#### 다양한 형식으로 출력

```bash
# SPDX 형식으로 저장
syft nginx:1.25 -o spdx-json > nginx-sbom.json

# CycloneDX 형식으로 저장
syft nginx:1.25 -o cyclonedx-json > nginx-sbom-cyclonedx.json
```

### Trivy로 SBOM과 취약점 스캔을 함께 하는 방법

```bash
# SBOM 생성
trivy image --format spdx-json --output sbom.json nginx:1.25

# 이미 생성된 SBOM을 기반으로 취약점 스캔 (이미지를 다시 안 받아도 됨)
trivy sbom sbom.json
```

- 이 방식이 실무에서 효율적인 이유는, SBOM만 있으면 이미지 전체를 다시 pull하지 않고도 취약점 스캔이 가능하기 때문임

### CI/CD 파이프라인 통합 예시 흐름

1. 이미지 빌드
2. Syft로 SBOM 생성
3. SBOM을 아티팩트 저장소에 보관 (나중에 취약점 발생 시 빠르게 조회하기 위함)
4. Trivy로 SBOM 기반 취약점 스캔
5. CRITICAL 발견 시 파이프라인 실패
6. 통과하면 이미지 레지스트리에 푸시 + SBOM도 함께 첨부

### CKS 시험 관점

- SBOM 생성 명령어를 직접 실행하고 결과를 특정 형식/경로로 저장하는 문제 유형이 나올 수 있음
- "왜 SBOM이 공급망 보안에 중요한지" 개념 이해도 함께 물어볼 수 있음

## 전체 흐름 정리

```scss
Vulnerability/Exploit/Payload (위협의 기본 구조 이해)
    │
    ▼
Container Security Scanning (이미지의 알려진 취약점 탐지 - Trivy)
    │
    ▼
K8s Cluster Scanning (클러스터 설정 자체의 보안 점검 - kube-bench)
    │
    ▼
Static Analysis (배포 전 매니페스트/Dockerfile 자체를 사전 검증)
    │
    ▼
Docker Daemon Security (이미지를 실제로 다루는 호스트 레벨 컴포넌트 보호)
    │
    ▼
SBOM (무엇이 이 이미지 안에 들어있는지 투명하게 기록 → 신규 취약점 대응 속도 향상)
```
