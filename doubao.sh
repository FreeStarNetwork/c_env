#!/usr/bin/env bash
set -euo pipefail

# config
MODEL="${DOUBAO_MODEL:-doubao-seed-2-1-pro-260915}"
ARK_API_KEY="${ARK_API_KEY:?Please export ARK_API_KEY (BytePlus ModelArk key)}"
API_URL="${ARK_ENDPOINT:-https://ark.cn-beijing.volces.com/api/v3/responses}"
STATE_FILE="./.current_doubao_response_id"
STORE=true

# auto folder title, env override
AUTO_FOLDER_TITLE=$(basename "$PWD")
DOUBAO_SESSION_TITLE="${DOUBAO_SESSION_TITLE:-${AUTO_FOLDER_TITLE}}"

# ENGLISH system prompt for C audit and code generation
SYS_PROMPT="You are a rigorous C language assistant, avoid compiler-specific extensions.
Audit task: locate undefined behavior, memory bugs, out-of-bounds access, type safety defects, resource leaks.
Code generation task: output only clean C source, no markdown fences, no extra explanatory prose."

cmd_help() {
cat <<EOF
Usage:
  ./doubao.sh new        reset cloud session pointer
  ./doubao.sh ask "text" send prompt, continue cloud context
  ./doubao.sh ask -      read prompt from stdin (vim pipe)
  ./doubao.sh current    show active cloud response id
  ./doubao.sh del ID     delete stored cloud response

Environment:
  export ARK_API_KEY="BytePlus ModelArk key"
  export DOUBAO_MODEL="doubao-seed-2-1-pro-260915"
  export DOUBAO_SESSION_TITLE="custom-title"
  export ARK_ENDPOINT="https://ark.cn-beijing.volces.com/api/v3/responses"
EOF
}

get_current_id() {
    if [ -s "${STATE_FILE}" ]; then
        cat "${STATE_FILE}"
    else
        echo ""
    fi
}

cmd_new() {
    local CUR_ID
    CUR_ID=$(get_current_id)
    if [[ -n "${CUR_ID}" ]]; then
        echo "Deleting old cloud response id=${CUR_ID}"
        curl -s --max-time 30 -X DELETE "${API_URL}/${CUR_ID}" \
            -H "Authorization: Bearer ${ARK_API_KEY}"
    fi
    rm -f "${STATE_FILE}"
    echo "Reset cloud pointer; next ask() creates new cloud response."
    echo "Auto session title: [${DOUBAO_SESSION_TITLE}]"
}

cmd_ask() {
    local USER_INPUT
    if [ "$1" = "-" ]; then
        USER_INPUT=$(cat)
    else
        USER_INPUT="$1"
    fi
    local CUR_ID=$(get_current_id)
    local FULL_INPUT

    if [ -z "${CUR_ID}" ]; then
        # first turn: attach title + English system prompt
        FULL_INPUT="[${DOUBAO_SESSION_TITLE}]

${SYS_PROMPT}

${USER_INPUT}"
        PAYLOAD=$(jq -n \
            --arg model "${MODEL}" \
            --arg input "${FULL_INPUT}" \
            --argjson store "${STORE}" \
            '{
                "model": $model,
                "input": $input,
                "store": $store
            }')
    else
        # continue existing cloud conversation
        FULL_INPUT="${USER_INPUT}"
        PAYLOAD=$(jq -n \
            --arg model "${MODEL}" \
            --arg prev "${CUR_ID}" \
            --arg input "${FULL_INPUT}" \
            --argjson store "${STORE}" \
            '{
                "model": $model,
                "previous_response_id": $prev,
                "input": $input,
                "store": $store
            }')
    fi

    RAW=$(curl -s --max-time 30 -X POST "${API_URL}" \
        -H "Authorization: Bearer ${ARK_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "${PAYLOAD}")

    RESP_ID=$(echo "$RAW" | jq -r '.id')
    REPLY=$(echo "$RAW" | jq -r '.output[] | select(.type=="message") | .content[0].text // "Empty reply"')

    if [ -z "${CUR_ID}" ]; then
        echo "${RESP_ID}" > "${STATE_FILE}"
        echo "New cloud response id=${RESP_ID}"
    fi
    printf "\n%s\n\n" "${REPLY}"
}

cmd_del() {
    local ID="$1"
    curl -s --max-time 30 -X DELETE "${API_URL}/${ID}" \
        -H "Authorization: Bearer ${ARK_API_KEY}"
    local CUR=$(get_current_id)
    [ "${CUR}" = "${ID}" ] && rm -f "${STATE_FILE}"
    echo "Deleted cloud response: ${ID}"
}

cmd_current() {
    local c=$(get_current_id)
    if [ -z "${c}" ]; then
        echo "No active doubao cloud response."
    else
        echo "Active response id: ${c}"
    fi
}

case "${1:-help}" in
new|clear)
    cmd_new
    ;;
ask)
    shift
    cmd_ask "$1"
    ;;
del)
    if [ -z "${2:-}" ]; then
        echo "Usage: $0 del <response-id>"
        exit 1
    fi
    cmd_del "$2"
    ;;
current)
    cmd_current
    ;;
help|-h|--help|"")
    cmd_help
    exit 0
    ;;
*)
    cmd_help
    exit 1
    ;;
esac

