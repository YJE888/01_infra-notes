# Linux에서 USB 장치 마운트하기

- 리눅스 서버에서 USB 저장장치를 인식하고 마운트하는 기본 절차를 정리한 문서임

## USB 장치 식별 (lsblk)

- USB 연결 전 장치 확인
  ```bash
  lsblk
  ```
- USB 연결 후 장치 확인
  - 예시에서는 USB 장치가 /dev/xvdc로 인식
  ```bash
  $ lsblk
  NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
  ...
  xvdc                      202:0    0   16G  0 disk
  ```

## 마운트 포인트 생성 (mkdir)

- 마운트 포인트는 USB 드라이브의 내용을 접근할 디렉토리임
- 일반적으로 /mnt 또는 /media 하위에 생성
  ```bash
  sudo mkdir /mnt/usb
  ```

## USB 마운트 (mount)

- USB를 생성한 마운트 포인트에 연결
- 기본 마운트 커맨드
  ```bash
  sudo mount /dev/xvdc /mnt/usb
  ```
- 파일 시스템 유형 지정 (필요 시)
  - 대부분의 리눅스 배포판은 파일 시스템을 자동으로 인식하지만, 인식하지 못하는 경우 -t 옵션으로 명시할 수 있음
- 파일 시스템 타입 확인
  ```bash
  lsblk -f
  ```
- FAT32(vfat) 형식인 경우
  - USB는 주로 FAT32(vfat) 또는 NTFS 형식을 사용함
  ```bash
  sudo mount -t vfat /dev/sdb1 /mnt/usb
  ```

## 마운트 확인 및 사용

- 마운트 상태 확인
  - MOUNTPOINT 컬럼에 /mnt/usb가 표시되면 정상적으로 마운트된 상태

  ```bash
  $ lsblk
  NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
  ...
  xvdc                      202:0    0   16G  0 disk /mnt/usb

  # usb 접근
  cd /mnt/usb
  ls -l
  ```

## 마운트 해제 (umount)

- USB 장치를 안전하게 제거하기 전에 반드시 언마운트를 수행
  ```bash
  cd ~
  sudo umount /mnt/usb
  ```
- 언마운트 오류 처리
  - device is busy 오류 발생 시 해당 디렉토리를 사용 중인 터미널 종료
  - 실행 중인 프로세스 종료 후 다시 시도
