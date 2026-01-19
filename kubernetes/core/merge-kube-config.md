# Kubeconfig 파일 병합
## 기존 파일 및 context 확인
- 기존 설정 확인
    ```bash
    # 기존 context
    $ kubectl config get-contexts
    CURRENT   NAME       CLUSTER    AUTHINFO    NAMESPACE
            dmz        dmz        dmz-admin   solution-ns
            gov-100    private    company      solution-ns
            public     public     pub-adm     rook-ceph
    *         yoo-200    test-200   yoo         solution-ns

    # 기존 파일명
    $ ls -l .kube/config
    -rw-------@ 1 zi  wheel  27674 Dec  6 17:19 .kube/config

    # 새로운 파일명
    $ ls -l config-27
    -rw-r--r--@ 1 zi  staff  5649 Dec 13 23:12 config-27
    ```
## Context 병합
- 기존 파일 백업
    ```bash
    # config.bak.2025-12-13 파일 형태로 백업
    cp ~/.kube/config ~/./config.bak.$(date +%F)
    ```
- 파일 병합
    ```bash
    KUBECONFIG=~/.kube/config:~/config-27 \
    kubectl config view --merge --flatten > /tmp/kubeconfig.merged
    ```
    - `KUBECONFIG=~/.kube/config:~/config-27`
        - `:` 의미
            - 리눅스/유닉스 표준으로 여러 설정 파일을 나열할 때 쓰는 구분자
        - kubectl은 두 개 파일을 동시에 읽음
            ```bash
            1) ~/.kube/config      (기존)
            2) ~/config-27         (새로운)
            ```
    - `kubectl config view`
        - kubeconfig를 수정하지 않고 단순히 내용을 합쳐서 출력만 함
            ```bash
            clusters:
            - name: dmz
            - name: yoo-200
            - name: new-cluster   # ← config-27에서 온 것

            contexts:
            - name: dmz
            - name: yoo-200
            - name: new-context   # ← config-27에서 온 것
            ```
    - `--merge`
        - 같은 항목은 합치고, 새로운 건 추가함
        - 기존 컨텍스트는 유지하고 새 컨텍스트만 추가함
    - `--flatten`
        - 파일 경로를 하나로 정리
    - `> /tmp/kubeconfig.merged`
        - kubectl이 출력한 결과를 /tmp/kubeconfig.merged 파일로 저장
        - ~/.kube/config 는 전혀 안 건드림
    - 병합결과 적용
        - 병합된 결과를 기존 kubeconfig 자리에 덮어쓰고 권한을 안전하게 제한
        ```bash
        mv /tmp/kubeconfig.merged ~/.kube/config
        chmod 600 ~/.kube/config
        ```
- 적용 확인
    ```bash
    $ kubectl config get-contexts
    kubectl config get-contexts

    CURRENT   NAME                             CLUSTER         AUTHINFO           NAMESPACE
            dmz                              dmz             dmz-admin          solution-ns
            gov-100                          private         company             solution-ns
            kubernetes-admin@cluster.local   cluster.local   kubernetes-admin # 추가
            public                           public          pub-adm            rook-ceph
    *         yoo-200                          test-200        yoo                solution-ns
    ```
## Context 이름 변경
```bash
kubectl config rename-context \
  kubernetes-admin@cluster.local inf-27_255_90_120
```
- 확인
    ```bash
    kubectl config get-contexts
    CURRENT   NAME                CLUSTER         AUTHINFO           NAMESPACE
            dmz                 dmz             dmz-admin          solution-ns
            gov-100             private         company             solution-ns
    *         inf-27_255_90_120   cluster.local   kubernetes-admin   default # 추가
            public              public          pub-adm            rook-ceph
            yoo-200             test-200        yoo                solution-ns
    ```
## Context 삭제
- 기존 config 백업
```bash
cp ~/.kube/config ~/.kube/config.bak.$(date +%F)
```
- Context 삭제
```bash
kubectl config delete-context public
kubectl config unset clusters.public
kubectl config unset users.pub-adm
```