#!/bin/bash

# 1. 클러스터 및 환경 대기
launch.sh

echo "Configuring Cluster Environment..."

# [필수] ControlPlane Taint 제거 
# 이유: 문제 1번에서 node01을 잠글(Cordon) 것이므로, 
# 나머지 파드(2~5번)가 정상적으로 스케줄링 되려면 마스터 노드가 열려있어야 함.
kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null
kubectl taint nodes --all node-role.kubernetes.io/master- 2>/dev/null

# ==========================================
# PART 1. Kubernetes 시나리오 (재정렬됨)
# ==========================================
cat <<EOF > /root/broken-k8s.yaml
# [문제 1] 노드 Cordon (Pending)
# (구 6번 -> 신 1번)
# node01이 잠겨있어서 배포가 안되는 상황
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
      # [중요] 마스터 노드로 도망가지 못하게 node01로 강제 지정
      nodeSelector:
        kubernetes.io/hostname: node01
      containers:
      - name: nginx
        image: nginx:alpine
---
# [문제 2] OOMKilled
# (구 1번 -> 신 2번)
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
      - name: stress-container
        image: polinux/stress
        command: ["stress"]
        args: ["--vm", "1", "--vm-bytes", "250M", "--vm-hang", "1"]
        resources:
          limits:
            memory: "100Mi"
---
# [문제 3] Liveness Probe 실패
# (구 2번 -> 신 3번)
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
# [문제 4] CPU 요청 과다 (Pending)
# (구 3번 -> 신 4번)
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
      - name: nginx
        image: nginx:alpine
        resources:
          requests:
            cpu: "100" 
---
# [문제 5] 명령어 오타 (CrashLoopBackOff)
# (구 4번 -> 신 5번)
# (구 5번 ImagePull 문제는 삭제됨)
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
      - name: busybox
        image: busybox
        command: ["sleeeeeeeeep", "3600"]
EOF

# 배포 실행
kubectl apply -f /root/broken-k8s.yaml

# [문제 1번 설정] 노드 Cordon 처리
NODE_NAME=$(kubectl get nodes -o name | grep node01 | cut -d/ -f2)
if [ ! -z "$NODE_NAME" ]; then
  kubectl cordon $NODE_NAME
fi

# ====================================================
# PART 2. Linux Scenarios Setup
# ====================================================

mkdir -p /root/linux-quiz

cat <<'EOF' > /root/linux-quiz/start_app.sh
#!/bin/bash

# [TRAP] 실행 권한 체크
if [ ! -x "$0" ]; then
  echo "-bash: $0: Permission denied"
  exit 126
fi

echo "[INFO] Starting Application..."
echo "[INFO] Loading configurations..."
sleep 1

# 몰래 대용량 파일 생성 (5GB)
mkdir -p /var/log/app_cache
echo "[WARN] Generating initial cache data..."

dd if=/dev/zero of=/var/log/app_cache/.temp_data_v1.img bs=1M count=5120 status=progress

echo ""
echo "[SUCCESS] Application started successfully!"
echo "------------------------------------------------"
echo "Warning: Disk usage has increased significantly."
EOF

chmod 644 /root/linux-quiz/start_app.sh

echo "Environment Setup Complete at $(date)" >> /root/setup_log.txt
