# kubeadm Certificate Renewal (with ansible)

## 1. 개요
- 대상 클러스터
- 갱신 대상 인증서
- 갱신 주기 및 기준(30일)
- kubespray로 설치한 kubernetes 클러스터에서 control-plane 인증서를 만료 30일 전에 자동 갱신
  
## 2. 사전 점검
- 인증서 만료 확인 명령

## 3. 자동 갱신 절차 (Ansible)
- apiserver 인증서의 만료 날짜 확인
- 30일 미만일 경우 하기의 절차 실행하고 30일 이상일 경우 skip
- 백업 절차 (/etc/kubernetes)
  - /root/k8s-certs-backup 경로에 실행 날짜로 디렉토리 생성 후 kubernetes.tar.gz로 /etc/kubernetes 백업
  - 갱신 실행
  - kubeconfig 갱신
  - kubelet 재시작

## 4. 갱신 후 검증
- kubeadm certs check-expiration
- kubectl get nodes

## 5. 주의사항
- serial=1 이유
  - 컨트롤플레인 노드를 순차적으로 하나씩 처리하기 위한 옵션
- renew 조건 설명
  - 잔여 만료 기간이 30일 보다 짧을 때만 수행(이미 만료된 인증서에 대해서도 동작 검증 완료)
  - renew = true
    - 인증서 백업 → 갱신 → kubelet 재시작 → 검증 수행
  - renew = false
    - 모든 갱신 관련 작업은 skip
- kubeadm 경로 이슈
  - ansible command 모듈 사용 시 kubeadm 경로를 찾지 못하는 이슈가 발생할 수 있어 절대경로 사용

## 6. 실행 방법
- hosts 파일에 아래와 같이 컨트롤플레인 명시
```ini
all:
  children:
    kube_control_plane:
      hosts:
        cp1:
          ansible_host: 192.168.0.200
        cp2:
          ansible_host: 192.168.0.100
```
- 실행
```bash
ansible-playbook -i hosts renew-kubeadm-certs.yaml
```

