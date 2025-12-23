#!/bin/bash

# 1. 클러스터 및 환경 대기
launch.sh

# ==========================================
# PART 1. Kubernetes 시나리오 (초급용 6개)
# ==========================================
cat <<EOF > /root/broken-k8s.yaml
# [문제 1] OOMKilled (메모리 부족)
# 원인: Limit이 너무 작음
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-01-oom
  labels:
    app: stress-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: stress-test
  template:
    metadata:
      labels:
        app: stress-test
    spec:
      containers:
      - name: stress-container
        image: polinux/stress
        command: ["stress"]
        args: ["--vm", "1", "--vm-bytes", "250M", "--vm-hang", "1"]
        resources:
          limits:
            memory: "100Mi"
---
# [문제 2] Liveness Probe 실패
# 원인: 포트가 다름 (80 vs 8080)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-02-probe
  labels:
    app: nginx-broken-probe
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-broken-probe
  template:
    metadata:
      labels:
        app: nginx-broken-probe
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /
            port: 8080 
          initialDelaySeconds: 2
          periodSeconds: 3
---
# [문제 3 - 신규] 리소스 요청 과다 (Pending)
# 원인: 노드 CPU는 2개인데 100개를 요구함
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-03-cpu
  labels:
    app: heavy-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: heavy-app
  template:
    metadata:
      labels:
        app: heavy-app
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        resources:
          requests:
            cpu: "100" 
---
# [문제 4] 명령어 오타 (CrashLoopBackOff)
# 원인: sleeeeeeeeep 오타
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-04-typo
  labels:
    app: typo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: typo-app
  template:
    metadata:
      labels:
        app: typo-app
    spec:
      containers:
      - name: busybox
        image: busybox
        command: ["sleeeeeeeeep", "3600"]
---
# [문제 5] 이미지 태그 오류 (ImagePullBackOff)
# 원인: 존재하지 않는 태그
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-05-image
  labels:
    app: wrong-image
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wrong-image
  template:
    metadata:
      labels:
        app: wrong-image
    spec:
      containers:
      - name: nginx
        image: nginx:1.99.9-beta-invalid
---
# [문제 6 - 신규] 노드 스케줄링 불가 (Pending)
# 원인: 노드가 Cordon 되어 있음 (문제 세팅 단계에서 설정)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-06-node
  labels:
    app: maintenance-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: maintenance-app
  template:
    metadata:
      labels:
        app: maintenance-app
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
EOF

# 1. 워커 노드 하나를 Cordon 처리 (스케줄링 금지)하여 문제 6번 유발
# (Killercoda 환경에 따라 node01이 없을 수도 있으므로 체크)
NODE_NAME=$(kubectl get nodes -o name | grep node01 | cut -d/ -f2)
if [ -z "$NODE_NAME" ]; then
  # node01이 없으면 controlplane이라도 cordon
  kubectl cordon controlplane
else
  kubectl cordon $NODE_NAME
fi

# 2. K8s 문제 배포
kubectl apply -f /root/broken-k8s.yaml


# ==========================================
# PART 2. Linux 시나리오 (초급용)
# ==========================================

mkdir -p /root/linux-quiz

# 리눅스 문제 세팅 스크립트 생성
cat <<'EOF' > /root/linux-quiz/setup_linux_problems.sh
#!/bin/bash

# [Linux 문제 1] 권한 문제
# 실행 권한 제거
echo '#!/bin/bash' > /root/linux-quiz/start_app.sh
echo 'echo "Application Started Successfully!"' >> /root/linux-quiz/start_app.sh
chmod 644 /root/linux-quiz/start_app.sh 

# [Linux 문제 2] CPU 과부하 프로세스 (좀비/Hang)
# yes 명령어로 CPU 100% 유발 (백그라운드)
nohup yes > /dev/null 2>&1 &
echo "CPU Load Generated. Find the process and kill it." > /root/linux-quiz/cpu_alert.log

# [Linux 문제 3] Disk Full (대용량 파일)
# 3GB짜리 더미 파일을 숨겨진 경로에 생성
# (실제 Full은 위험하므로 큰 파일을 찾는 것으로 대체)
mkdir -p /var/log/.archive
dd if=/dev/zero of=/var/log/.archive/backup_2024.dump bs=1M count=3000 status=none

echo "Linux problems setup complete."
EOF

# 스크립트 실행
chmod +x /root/linux-quiz/setup_linux_problems.sh
/root/linux-quiz/setup_linux_problems.sh

# 완료 로그
echo "All Beginner scenarios deployed at $(date)" >> /root/setup_log.txt
