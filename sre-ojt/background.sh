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

# ... (Part 1 Kubernetes는 그대로 유지) ...

# ====================================================
# PART 2. Linux Scenarios Setup (Chain Problem)
# ====================================================

mkdir -p /root/linux-quiz

# start_app.sh 생성
cat <<'EOF' > /root/linux-quiz/start_app.sh
#!/bin/bash

# [TRAP] 실행 권한 확인 (sh ./start_app.sh 방지용)
if [ ! -x "$0" ]; then
  echo "-bash: $0: Permission denied"
  exit 126
fi

echo "[INFO] Starting Application..."
echo "[INFO] Loading configurations..."
sleep 1

# 몰래 대용량 파일 생성 (경로 숨김)
# 경로: /var/log/app_cache/.temp_data_v1.img
mkdir -p /var/log/app_cache
echo "[WARN] Generating initial cache data..."

# [수정] fallocate 제거 -> dd로 강제 쓰기 (3GB)
# if=/dev/zero (0으로 채움), bs=1M (단위), count=3072 (3GB)
# 만약 5GB를 원하면 count=5120 으로 변경하세요.
dd if=/dev/zero of=/var/log/app_cache/.temp_data_v1.img bs=1M count=5120 status=progress

echo ""
echo "[SUCCESS] Application started successfully!"
echo "------------------------------------------------"
echo "Warning: Disk usage has increased significantly."
EOF

# 권한 설정 (실행 권한 뺌)
chmod 644 /root/linux-quiz/start_app.sh

# 완료 로그
echo "Linux environment configured at $(date)" >> /root/setup_log.txt
