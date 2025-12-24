#!/bin/bash

# =================================================================
# [설정] Slack Webhook URL을 따옴표 안에 정확히 넣으세요.
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/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"
# =================================================================

echo "[INIT] Launching Environment..."
# 1. 클러스터 실행
launch.sh

echo "[INIT] Waiting for Kubernetes API to be ready..."
# [수정] 쿠버네티스 API 서버가 응답할 때까지 대기 (Namespace 생성 실패 방지)
while ! kubectl get nodes > /dev/null 2>&1; do
  echo "  - API Server not ready yet. Retrying in 2s..."
  sleep 2
done
echo "[OK] Kubernetes Cluster is Ready!"


# ----------------------------------------------------
# PART 1. Slack Audit Setup (즉시 테스트 포함)
# ----------------------------------------------------

# [수정] 테스트를 위해 기존 변수 초기화 (스크립트 다시 돌려도 알림 오게 함)
unset LOGIN_NOTIFIED

cat <<EOF >> /etc/profile

# 1. 로그인 알림 (접속 시 즉시 전송)
if [ -z "\$LOGIN_NOTIFIED" ]; then
    LOGIN_MSG="{\"text\": \"🔔 *New User Login Detected!* \\n> *User:* \$(whoami) \\n> *Time:* \$(date)\"}"
    
    # [수정] -v 옵션은 끄고, 결과가 ok인지 에러인지 화면에 출력하게 변경
    echo "[DEBUG] Sending Login Notification to Slack..."
    curl -s -H "Content-Type: application/json" -d "\$LOGIN_MSG" "$SLACK_WEBHOOK_URL"
    echo "" # 줄바꿈
    
    export LOGIN_NOTIFIED=true
fi

# 2. 명령어 실시간 로깅
AUDIT_FILE="/var/log/.audit_history"
if [ ! -f "\$AUDIT_FILE" ]; then
    touch \$AUDIT_FILE
    chmod 666 \$AUDIT_FILE
fi

log_command() {
    local cmd=\$(history 1 | sed "s/^[ ]*[0-9]\+[ ]*//")
    if [ "\$cmd" != "\$LAST_CMD" ]; then
        echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$cmd" >> \$AUDIT_FILE
        export LAST_CMD="\$cmd"
    fi
}
export PROMPT_COMMAND="log_command"

# 3. 로그아웃 시 히스토리 전송 (100줄)
upload_audit_log() {
    LOG_CONTENT=\$(tail -n 100 \$AUDIT_FILE | sed 's/\\\\/\\\\\\\\/g' | sed 's/"/\\\\"/g' | sed ':a;N;\$!ba;s/\n/\\\\n/g')
    
    LOGOUT_MSG="{
        \"text\": \"🔒 *Session Closed (User: \$(whoami))* \\n\\n*Recent Activity (Last 100 lines):*\\n\`\`\`\\n\$LOG_CONTENT\\n\`\`\`\"
    }"

    # 로그아웃 때는 조용히 전송
    curl -s -H "Content-Type: application/json" -d "\$LOGOUT_MSG" "$SLACK_WEBHOOK_URL" > /dev/null 2>&1
}

trap upload_audit_log EXIT SIGHUP SIGTERM

EOF

# 현재 세션에 즉시 적용 (이때 Slack 알림이 와야 함!)
source /etc/profile


# ----------------------------------------------------
# PART 2. Kubernetes Setup (Namespace: OJT)
# ----------------------------------------------------

echo "[SETUP] Creating Namespace OJT..."
# [수정] 이미 존재하면 에러 안 나게 처리 (--dry-run 사용하거나 || true)
kubectl create namespace OJT --dry-run=client -o yaml | kubectl apply -f -

# Taint 제거
kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null
kubectl taint nodes --all node-role.kubernetes.io/master- 2>/dev/null

# 노드 잠금
NODE_NAME=\$(kubectl get nodes -o name | grep node01 | cut -d/ -f2)
if [ ! -z "\$NODE_NAME" ]; then
  kubectl cordon \$NODE_NAME
fi

echo "[SETUP] Deploying Broken Resources to Namespace OJT..."
# [수정] namespace: OJT 적용
cat <<EOF > /root/broken-k8s.yaml
# [문제 1] 노드 Cordon (Pending)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-01
  namespace: OJT
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
      nodeSelector:
        kubernetes.io/hostname: node01
      containers:
      - name: nginx
        image: nginx:alpine
---
# [문제 2] OOMKilled
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-02
  namespace: OJT
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
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-03
  namespace: OJT
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
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-04
  namespace: OJT
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
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-05
  namespace: OJT
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

kubectl apply -f /root/broken-k8s.yaml


# ----------------------------------------------------
# PART 3. Linux Setup
# ----------------------------------------------------

echo "[SETUP] Configuring Linux Challenge..."
mkdir -p /root/linux-quiz

cat <<'APP_EOF' > /root/linux-quiz/start_app.sh
#!/bin/bash

if [ ! -x "\$0" ]; then
  echo "-bash: \$0: Permission denied"
  exit 126
fi

echo "[INFO] Starting Application..."
echo "[INFO] Loading configurations..."
sleep 1

mkdir -p /var/log/app_cache
echo "[WARN] Generating initial cache data..."

dd if=/dev/zero of=/var/log/app_cache/.temp_data_v1.img bs=1M count=5120 status=progress

echo ""
echo "[SUCCESS] Application started successfully!"
echo "------------------------------------------------"
echo "Warning: Disk usage has increased significantly."
APP_EOF

chmod 644 /root/linux-quiz/start_app.sh

echo "Setup Complete at \$(date)" >> /root/setup_log.txt
echo "----------------------------------------"
echo "ALL DONE! Check Slack for notification."
