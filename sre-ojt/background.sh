#!/bin/bash

# 1. 클러스터 및 환경 대기
launch.sh

# ==========================================
# PART 1. Kubernetes 시나리오 (이름 난독화)
# ==========================================
cat <<EOF > /root/broken-k8s.yaml
# [문제 1] OOMKilled
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-01
  labels:
    app: test-01
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-01
  template:
    metadata:
      labels:
        app: test-01
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
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-02
  labels:
    app: test-02
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-02
  template:
    metadata:
      labels:
        app: test-02
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
# [문제 3] CPU 요청 과다
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-03
  labels:
    app: test-03
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-03
  template:
    metadata:
      labels:
        app: test-03
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        resources:
          requests:
            cpu: "100" 
---
# [문제 4] 명령어 오타
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-04
  labels:
    app: test-04
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-04
  template:
    metadata:
      labels:
        app: test-04
    spec:
      containers:
      - name: busybox
        image: busybox
        command: ["sleeeeeeeeep", "3600"]
---
# [문제 5] 이미지 태그 오류
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-05
  labels:
    app: test-05
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-05
  template:
    metadata:
      labels:
        app: test-05
    spec:
      containers:
      - name: nginx
        image: nginx:1.99.9-beta-invalid
---
# [문제 6] 노드 Cordon
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-06
  labels:
    app: test-06
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-06
  template:
    metadata:
      labels:
        app: test-06
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
EOF

# 노드 Cordon 설정 (문제 6번용)
NODE_NAME=$(kubectl get nodes -o name | grep node01 | cut -d/ -f2)
if [ -z "$NODE_NAME" ]; then
  kubectl cordon controlplane
else
  kubectl cordon $NODE_NAME
fi

# 배포 실행
kubectl apply -f /root/broken-k8s.yaml

# ==========================================
# PART 2. Linux 시나리오 세팅
# ==========================================
mkdir -p /root/linux-quiz

cat <<'EOF' > /root/linux-quiz/setup_linux_problems.sh
#!/bin/bash

# 1. 권한 문제
echo '#!/bin/bash' > /root/linux-quiz/start_app.sh
echo 'echo "Application Started!"' >> /root/linux-quiz/start_app.sh
chmod 644 /root/linux-quiz/start_app.sh 

# 2. CPU 과부하 (Process 이름 숨김 없이 yes 사용)
nohup yes > /dev/null 2>&1 &

# [Linux 문제 3] Disk Full (남은 공간을 100% 채우는 숨겨진 파일 생성)
# 1. 남은 용량(Available)을 바이트 단위로 계산
AVAILABLE_SPACE=$(df --output=avail -B1 / | tail -n 1)

# 2. 숨겨진 경로에 남은 용량만큼의 파일 생성 (정확히 100% 만듦)
# 경로: /var/log/.sys_kernel_dump (숨김 파일)
fallocate -l $AVAILABLE_SPACE /var/log/.sys_kernel_dump

# (만약 fallocate가 실패할 경우를 대비한 보험용 dd - 느리지만 확실함)
if [ $? -ne 0 ]; then
  dd if=/dev/zero of=/var/log/.sys_kernel_dump bs=1M count=5600
fi

# 3. 힌트 메시지 생성 (선택)
echo "Critical: Disk Usage is 100%. Free up space immediately." > /etc/motd
