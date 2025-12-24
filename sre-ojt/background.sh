#!/bin/bash


# =================================================================
# [설정] 복사한 Slack Webhook URL을 여기에 붙여넣으세요.
SLACK_WEBHOOK_URL="[Credentials]"
# =================================================================


# 1. 클러스터 및 환경 대기
launch.sh


echo "Configuring Cluster Environment..."


# ----------------------------------------------------
# PART 1. Slack Audit Setup (감시 설정)
# ----------------------------------------------------


cat <<EOF >> /etc/profile


# 1. 로그인 알림 (접속 시 즉시 전송)
if [ -z "\$LOGIN_NOTIFIED" ]; then
    # Slack용 JSON 메시지
    LOGIN_MSG="{\"text\": \"🔔 *New User Login Detected!* \\n> *User:* \$(whoami) \\n> *Time:* \$(date)\"}"
    
    curl -H "Content-Type: application/json" \
         -d "\$LOGIN_MSG" \
         "$SLACK_WEBHOOK_URL" > /dev/null 2>&1
    export LOGIN_NOTIFIED=true
fi


# 2. 명령어 실시간 로깅 (날짜+시간 포함)
AUDIT_FILE="/var/log/.audit_history"
if [ ! -f "\$AUDIT_FILE" ]; then
    touch \$AUDIT_FILE
    chmod 666 \$AUDIT_FILE
fi


log_command() {
    local cmd=\$(history 1 | sed "s/^[ ]*[0-9]\+[ ]*//")
    if [ "\$cmd" != "\$LAST_CMD" ]; then
        # [YYYY-MM-DD HH:MM:SS] 명령어 형식으로 저장
        echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$cmd" >> \$AUDIT_FILE
        export LAST_CMD="\$cmd"
    fi
}
export PROMPT_COMMAND="log_command"


# 3. 로그아웃 시 히스토리 전송 (최대 100줄)
upload_audit_log() {
    # 1) 마지막 100줄 읽기
    # 2) Slack JSON 포맷을 위해 특수문자(\, ") 이스케이프 및 줄바꿈 처리
    LOG_CONTENT=\$(tail -n 100 \$AUDIT_FILE | sed 's/\\\\/\\\\\\\\/g' | sed 's/"/\\\\"/g' | sed ':a;N;\$!ba;s/\n/\\\\n/g')
    
    # 3) Slack 메시지 구성 (코드 블록 \`\`\` 사용)
    LOGOUT_MSG="{
        \"text\": \"🔒 *Session Closed (User: \$(whoami))* \\n\\n*Recent Activity (Last 100 lines):*\\n\`\`\`\\n\$LOG_CONTENT\\n\`\`\`\"
    }"


    curl -H "Content-Type: application/json" \
         -d "\$LOGOUT_MSG" \
         "$SLACK_WEBHOOK_URL" > /dev/null 2>&1
}


# 종료(EXIT), 창닫기(SIGHUP), 강제종료(SIGTERM) 감지
trap upload_audit_log EXIT SIGHUP SIGTERM


EOF


source /etc/profile


# 1. 클러스터 및 환경 대기
launch.sh


echo "Configuring Cluster Environment..."


# [설정 1] ControlPlane Taint 제거 
# (이유: node01을 잠글 것이므로, 나머지 2~5번 파드들은 마스터 노드에서라도 실행되어야 함)
kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null

  namespace: OJT
