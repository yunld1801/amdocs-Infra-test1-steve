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

# ====================================================
# PART 2. Linux Scenarios Setup (Chain Problem)
# ====================================================

mkdir -p /root/linux-quiz

# [시나리오]
# start_app.sh를 만들지만 실행 권한을 뺌 (chmod 644)
# 이 스크립트가 실행되면 /var/log/app_cache 에 5GB 파일을 몰래 생성함

cat <<'EOF' > /root/linux-quiz/start_app.sh
#!/bin/bash

echo "[INFO] Starting Application..."
echo "[INFO] Loading configurations..."
sleep 1

# 몰래 대용량 파일 생성 (함정 발동)
# 경로: /var/log/app_cache/.temp_data_v1.img (숨김 파일)
mkdir -p /var/log/app_cache
echo "[WARN] Generating initial cache data..."

# fallocate로 5GB 생성 (실패 시 dd 사용)
if fallocate -l 5G /var/log/app_cache/.temp_data_v1.img 2>/dev/null; then
    echo "[INFO] Cache initialized."
else
    echo "[INFO] Initializing legacy cache..."
    dd if=/dev/zero of=/var/log/app_cache/.temp_data_v1.img bs=1M count=5120 status=none
fi

echo "[SUCCESS] Application started successfully!"
echo "------------------------------------------------"
echo "Warning: Disk usage has increased significantly."
EOF

# [핵심] 실행 권한 제거 (Owner: RW, Group: R, Other: R)
# 루트 유저라도 실행 권한(x)이 없으면 ./start_app.sh 실행 시 Permission denied 발생함
chmod 644 /root/linux-quiz/start_app.sh

echo "Linux environment configured at $(date)" >> /root/setup_log.txt
