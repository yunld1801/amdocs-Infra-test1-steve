#!/bin/bash


# =================================================================
# [설정] Slack Webhook URL을 '따옴표' 안에 정확히 넣으세요.
SLACK_WEBHOOK_URL="[Credentials]"
# =================================================================


# 로그 파일 설정 (디버깅용)
LOGfile="/var/log/setup_debug.log"
exec > >(tee -a $LOGfile) 2>&1


echo "=============================================="
echo "[1/4] Webhook Connection Test..."
echo "=============================================="


# 1. 시작 알림 (URL 테스트용)
# 여기서 ok가 안 나오면 URL이 틀린 겁니다.
curl -s --max-time 5 -H "Content-Type: application/json" \
     -d "{\"text\": \"⚙️ **Environment Setup Started...** (User: $(whoami))\"}" \
     "$SLACK_WEBHOOK_URL"
echo ""


# 2. 감시 스크립트 등록 (/etc/profile)
# 세션 로그인/로그아웃 시 알림 발송
cat <<EOF >> /etc/profile


# [로그인 알림]
if [ -z "\$LOGIN_NOTIFIED" ]; then
    LOGIN_MSG="{\"text\": \"🔔 *New User Login Detected!* \\n> *User:* \$(whoami) \\n> *Time:* \$(date)\"}"
    # 조용히 전송 (에러 무시)
    curl -s --max-time 5 -H "Content-Type: application/json" -d "\$LOGIN_MSG" "$SLACK_WEBHOOK_URL" > /dev/null 2>&1
    export LOGIN_NOTIFIED=true
fi


# [명령어 기록]
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


# [로그아웃 알림] (100줄 전송)
upload_audit_log() {
    LOG_CONTENT=\$(tail -n 100 \$AUDIT_FILE | sed 's/\\\\/\\\\\\\\/g' | sed 's/"/\\\\"/g' | sed ':a;N;\$!ba;s/\n/\\\\n/g')
    LOGOUT_MSG="{
        \"text\": \"🔒 *Session Closed (User: \$(whoami))* \\n\\n*Recent Activity:*\\n\`\`\`\\n\$LOG_CONTENT\\n\`\`\`\"
    }"
    curl -s --max-time 5 -H "Content-Type: application/json" -d "\$LOGOUT_MSG" "$SLACK_WEBHOOK_URL" > /dev/null 2>&1
}
trap upload_audit_log EXIT SIGHUP SIGTERM
EOF


# 현재 세션에 즉시 적용
source /etc/profile




echo "=============================================="
echo "[2/4] Launching Kubernetes Cluster..."
echo "=============================================="


# 3. 클러스터 실행
