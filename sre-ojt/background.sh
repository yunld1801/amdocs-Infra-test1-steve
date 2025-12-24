#!/bin/bash


# =================================================================
# [설정] Slack Webhook URL을 '정확히' 붙여넣으세요.
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
# 중복 전송 방지 및 디버깅을 위해 에러 로그 표시
if [ -z "\$LOGIN_NOTIFIED" ]; then
    LOGIN_MSG="{\"text\": \"🔔 *New User Login Detected!* \\n> *User:* \$(whoami) \\n> *Time:* \$(date)\"}"
    
    # [수정] 성공 여부를 확인하기 위해 -v 옵션이나 에러 출력을 봅니다.
    curl -H "Content-Type: application/json" -d "\$LOGIN_MSG" "$SLACK_WEBHOOK_URL"
    
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
    # JSON 포맷 깨짐 방지를 위한 이스케이프 처리
    LOG_CONTENT=\$(tail -n 100 \$AUDIT_FILE | sed 's/\\\\/\\\\\\\\/g' | sed 's/"/\\\\"/g' | sed ':a;N;\$!ba;s/\n/\\\\n/g')
    
    LOGOUT_MSG="{
        \"text\": \"🔒 *Session Closed (User: \$(whoami))* \\n\\n*Recent Activity (Last 100 lines):*\\n\`\`\`\\n\$LOG_CONTENT\\n\`\`\`\"
    }"


    curl -s -H "Content-Type: application/json" -d "\$LOGOUT_MSG" "$SLACK_WEBHOOK_URL" > /dev/null 2>&1
}


trap upload_audit_log EXIT SIGHUP SIGTERM


