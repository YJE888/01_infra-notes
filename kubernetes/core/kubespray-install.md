# Kubespray 구성(Rocky Linux 9.6)
## 사전 구성
- `epel-release`, `sshpass`, `wget`, `tar`, `git`패키지 설치
```bash
dnf -y install epel-release
dnf install -y sshpass wget tar git
```
- kubespray 복제
```bash
git clone https://github.com/kubernetes-sigs/kubespray.git
```

```bash
$ python -V
Python 3.9.21
```
- python 3.11 다운로드
```bash
sudo dnf -y install python3.11 python3-pip
python3.11 -m ensurepip
python3.11 -m pip --version
python3.11 -m pip install --upgrade pip
python3.11 -m pip --version
```

- Ansible 설치
  - Rocky Linux 9.6에 설치되어 있는 Python 버전으로 ansible-core 설치 시 버전이 낮아 에러 발생
  - 너무 최신버전을 설치해도 에러가 발생함(호환성을 따져봐야됨)
```bash
cd kubespray

# 명시된 ansible 버전을 설치하고 그에 맞는 ansible-core를 설치함
pip3 install -r requirements.txt

# 설치된 버전 확인
pip show ansible
ansible --version
```

- 버전이 너무 높게 설치되어 삭제하고 재설치 해야되는 경우
```bash
pip uninstall ansible ansible-core -y

# 특정 버전 ansible 설치
pip index versions ansible
pip3 install ansible==12.3.0

# 특정 버전 ansible-core 설치
pip3 index versions ansible-core
pip3 install "ansible-core==2.18.0"
```  
### Ansible 설정
- 키 생성
```bash
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
```
- 키 배포
  - 키 배포 시 `Permission denied (publickey,gssapi-keyex,gssapi-with-mic)`에러가 발생하면 `PasswordAuthentication` 값을 `yes`로 임시로 바꾸고 키 배포 후 원복
```bash
ssh-copy-id user@10.10.10.201
ssh-copy-id user@10.10.10.204
ssh-copy-id user@10.10.10.205

ssh user@10.10.10.201
ssh user@10.10.10.204
ssh user@10.10.10.205
```
- 인벤토리 파일 생성
```bash
mkdir -p ~/ansible && cd ~/ansible
cat <<EOF > inventory
[servers]
10.10.10.201
10.10.10.204
10.10.10.205

[servers:vars]
ansible_user=user
ansible_ssh_pass=ehost12@!
ansible_become_password=ehost12@!
EOF
```
- ping 모듈로 통신체크
```bash
ansible -i inventory all -m ping
```
- pre-install.yaml 작성
```bash
cat <<'EOF' > os-preinstall.yaml
# default ntp_server : time.google.com  
# ansible-playbook -i inventory pre-install.yaml -e "ntp_server=ntp.kornet.net"  
---  
- name: Rocky9 Kubernetes Preinstaller  
  hosts: all  
  gather_facts: false
  become: yes
  vars:  
    ntp_server: "time.google.com"  
  tasks:  
    - name: 'Populate service facts'  
      service_facts:  

    - name: Insert hosts block
      ansible.builtin.blockinfile:
        path: /etc/hosts
        block: |
          10.10.10.201 master1
          10.10.10.204 worker1
          10.10.10.205 worker2
  
    - name: Stop 'firewalld'  
      service:  
        name: "{{item}}"  
        state: stopped  
        enabled: no  
      loop:  
       - firewalld  
         #      when: ansible_facts.services[item] is defined  
      ignore_errors: yes  
  
    - name: Disable SWAP(1/2)  
      shell: swapoff -a  
  
    - name: Disable SWAP(2/2)  
      replace:  
        path: /etc/fstab  
        regexp: '(.*swap.*)'  
        replace: '# \1'  
        backup: yes  
  
    - name: Set maximum number of files  
      lineinfile:  
        path: /etc/sysctl.conf  
        regexp: '^fs.file-max'  
        line: 'fs.file-max = 2097152'  
        state: present  
  
    - name: Configuration Kernel Parameter (1/2)  
      lineinfile:  
        path: /etc/sysctl.conf  
        regexp: '^net.ipv4.ip_forward='  
        line: 'net.ipv4.ip_forward=1'  
        state: present  
  
    - name: Configuration Kernel Parameter (2/2)  
      shell: |  
        cat <<EOF > /etc/sysctl.d/k8s.conf  
        net.bridge.bridge-nf-call-ip6tables = 1  
        net.bridge.bridge-nf-call-iptables = 1  
        EOF  
  
    - name: Apply sysctl  
      command: sysctl -p  
  
    - name: Ensure root soft nofile  
      lineinfile:  
        path: /etc/security/limits.conf  
        regexp: '^root\s+soft\s+nofile'  
        line: 'root soft nofile 65536'  
        state: present  
  
    - name: Ensure root hard nofile  
      lineinfile:  
        path: /etc/security/limits.conf  
        regexp: '^root\s+hard\s+nofile'  
        line: 'root hard nofile 65536'  
        state: present  
  
    - name: Start 'chronyd' Service  
      service:  
        name: chronyd  
        enabled: yes  
        state: restarted  
  
    - name: Set timezone using timedatectl
      ansible.builtin.command: timedatectl set-timezone Asia/Seoul
EOF
```
## Kubespray 설치
```bash
cp -r ~/kubespray/inventory/sample/ ~/kubespray/inventory/mycluster

```
- kubespray inventory.ini 파일 수정
```bash
# 공인 NIC가 2개일 경우 ip를 명시해야 원하는 대역으로 클러스터가 생성됨
vi kubespray/inventory/mycluster/inventory.ini
```
```ini
[kube_control_plane]
master1 ansible_host=10.10.10.201 ip=10.10.10.201 etcd_member_name=etcd1

[etcd:children]
kube_control_plane

[kube_node]
worker1 ansible_host=10.10.10.204 ip=10.10.10.204
worker2 ansible_host=10.10.10.205 ip=10.10.10.205
```
- NOPASSWD 설정
  - 모든 노드(10.10.10.201/204/205)에서 설정
```bash
sudo visudo -f /etc/sudoers.d/user
```
```bash
user ALL=(ALL) NOPASSWD: ALL
```
- 실행
```bash
cd kubespray
ansible-playbook -i inventory/mycluster/inventory.ini cluster.yml -b
```
```bash
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```