# Ansible 자동화를 위한 SSH Key 배포 스크립트

## 목적

- 쿠버네티스 인증서 갱신을 위한 Ansible Playbook을 실행하기 전에, 마스터 서버를 대상으로 SSH 공개키를 사전에 배포하기 위한 목적과 수행 절차를 정리함
- Ansible 기반 자동화 작업
- 컨테이너 환경에서의 cron 기반의 정기 작업의 비대화(non-interacitve) 실행을 위한 사전 작업

## 필요성

- Ansible과 같은 자동화 도구는 SSH 접속 시 비밀번호 입력 또는 호스트 키 확인 프롬프트가 발생할 경우 자동화 작업이 중단됨
- 최초 SSH 접속 시 `Are you sure you want to continue connecting (yes/no)?` 프롬프트 발생
- 서버 재설치 또는 재구성으로 인한 host key 변경
- known_hosts 파일 내 중복 또는 오래된 host key 정보 존재
- 마스터 서버가 여러 대로 수동 작업 최소화(서버들의 패스워드 입력은 수동으로 입력)

## 수행 순서

- 마스터 서버의 IP 정보 기입
- 기존 KNOWN_HOSTS에 기존의 host key 정보가 있을 경우 중복 방지를 위해 제거 후 등록 시작
- PUBKEY에 공개키 위치 정의
- DEFAULT_KNOWN_HOSTS에 기본적으로 사용 되는 SSH known_hosts 경로 정의
  - 최초 접속 시 발생하는 SSH 확인 프롬프트를 방지하기 위해 기본 경로부터 등록
- ANSIBLE_KNOWN_HOSTS에 컨테이너에서 Ansible이 사용하는 known_hosts 경로를 정의
- 공개키를 마스터 서버의 계정에 배포하여 비밀번호 입력 없이 SSH 접속이 가능하도록 설정
  - 이 과정에서 비밀번호 입력은 수동으로 필요할 수 있음

- 위의 과정을 담은 스크립트 작성

  ```bash
  #!/bin/bash

  HOSTS=(192.168.4.157
    192.168.4.106
    192.168.4.107
  )
  PUBKEY="/root/.ssh/id_ed25519.pub"
  DEFAULT_KNOWN_HOSTS="/root/.ssh/known_hosts"
  ANSIBLE_KNOWN_HOSTS="/root/ansible/ssh/known_hosts"

  for host in "${HOSTS[@]}"; do
    echo "Processing $host"

    # 기존 host key 제거(중복 방지)
    ssh-keygen -R "$host" -f "$DEFAULT_KNOWN_HOSTS" >/dev/null 2>&1 || true
    ssh-keygen -R "$host" -f "$ANSIBLE_KNOWN_HOSTS" >/dev/null 2>&1 || true

    # host key 재등록
    # default_know_hosts에 먼저 등록해서 Are you sure you want to continue connecting (yes/no)?가 뜨는 것을 방지
    ssh-keyscan -H "$host" >> "$DEFAULT_KNOWN_HOSTS"
    ssh-keyscan -H "$host" >> "$ANSIBLE_KNOWN_HOSTS"

    ssh-copy-id -i "$PUBKEY" root@"$host"
  done
  ```

## 주의 사항

- 대상 서버에서 접속 가능한 계정 확인 필요(root, user, infra 등)
- 서버 OS 재설치 또는 SSH Host Key 변경 시 스크립트 재실행이 필요함
