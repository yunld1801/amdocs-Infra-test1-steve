#!/bin/bash


# =================================================================
# [설정] Slack Webhook URL을 여기에 붙여넣으세요.
SLACK_WEBHOOK_URL="[Credentials]"
# =================================================================


# 디버깅을 위해 로그를 파일과 화면에 동시에 출력
LOGfile="/var/log/setup_debug.log"
exec > >(tee -a $LOGfile) 2>&1


echo "[1/3] Setting up Slack Audit System..."


# ----------------------------------------------------
# PART 0. Webhook & Audit Setup (가장 먼저 실행!)
# ----------------------------------------------------


# 1. 스크립트 시작 알림 (URL이 맞는지 즉시 확인용)
curl -s -H "Content-Type: application/json" \
     -d "{\"text\": \"⚙️ **Environment Setup Started...** (User: $(whoami))\"}" \
     "$SLACK_WEBHOOK_URL"


# 2. 프로필에 감시 스크립트 등록
cat <<EOF >> /etc/profile


# [로그인 알림] 접속 시 즉시 전송
if [ -z "\$LOGIN_NOTIFIED" ]; then
    LOGIN_MSG="{\"text\": \"🔔 *New User Login Detected!* \\n> *User:* \$(whoami) \\n> *Time:* \$(date)\"}"
    
    # 디버깅을 위해 화면에 전송 시도 메시지 출력
    echo "[AUDIT] Sending Login Notification to Slack..."
    curl -s -H "Content-Type: application/json" -d "\$LOGIN_MSG" "$SLACK_WEBHOOK_URL"
    echo "" 
    
    export LOGIN_NOTIFIED=true
fi


# [명령어 로깅] 실시간으로 파일에 기록
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


# [로그아웃 알림] 세션 종료 시 마지막 100줄 전송
upload_audit_log() {
    # JSON 깨짐 방지를 위한 특수문자 처리 (매우 중요)
    LOG_CONTENT=\$(tail -n 100 \$AUDIT_FILE | sed 's/\\\\/\\\\\\\\/g' | sed 's/"/\\\\"/g' | sed ':a;N;\$!ba;s/\n/\\\\n/g')
    
    LOGOUT_MSG="{
        \"text\": \"🔒 *Session Closed (User: \$(whoami))* \\n\\n*Recent Activity:*\\n\`\`\`\\n\$LOG_CONTENT\\n\`\`\`\"
    }"


    curl -s -H "Content-Type: application/json" -d "\$LOGOUT_MSG" "$SLACK_WEBHOOK_URL" > /dev/null 2>&1
}


# 종료(EXIT), 창닫기(SIGHUP), 강제종료(SIGTERM) 감지
trap upload_audit_log EXIT SIGHUP SIGTERM
EOF


# 현재 세션에 즉시 적용
source /etc/profile


# 1. 클러스터 및 환경 대기
launch.sh


echo "Configuring Cluster Environment..."


# [설정 1] ControlPlane Taint 제거 
# (이유: node01을 잠글 것이므로, 나머지 2~5번 파드들은 마스터 노드에서라도 실행되어야 함)
kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null
kubectl taint nodes --all node-role.kubernetes.io/master- 2>/dev/null




# [설정 2 - 중요] 배포 전에 미리 노드를 잠금(Cordon)
# 그래야 1번 파드가 갈 곳이 없어서 Pending에 빠짐
NODE_NAME=$(kubectl get nodes -o name | grep node01 | cut -d/ -f2)
if [ ! -z "$NODE_NAME" ]; then
  kubectl cordon $NODE_NAME
fi




# ==========================================
# PART 1. Kubernetes 시나리오
# ==========================================
cat <<EOF > /root/broken-k8s.yaml
# [문제 1] 노드 Cordon (Pending)
# node01로만 가야 하는데(nodeSelector), node01이 잠겨(Cordon) 있어서 못 가는 상황
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-01
  labels:
    app: test-01
spec:
  replicas: 1
  selector:
