#!/usr/bin/env bash
set -euo pipefail

# config
MODEL="${GEMINI_MODEL:-gemini-2.5-flash-latest}"
API_KEY="${GEMINI_API_KEY:?Please export GEMINI_API_KEY environment variable}"
# DEFAULT=1: enable Interactions‑API by default; set env GEMINI_USE_INTERACTIONS=0 for local‑json mode
USE_INTERACTIONS="${GEMINI_USE_INTERACTIONS:-1}"
# auto‑get current folder name as session title, allow env override
AUTO_FOLDER_TITLE=$(basename "$PWD")
GEMINI_SESSION_TITLE="${GEMINI_SESSION_TITLE:-${AUTO_FOLDER_TITLE}}"

# generateContent stable mode (local JSON history)
GEN_CONTENT_URL="https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent"
SESSION_FILE="./gemini_session.json"

# Interactions‑API beta (cloud‑saved sessions, AI‑Studio web list)
INTERACT_BASE="https://generativelanguage.googleapis.com/v1beta/interactions"
STATE_FILE="./.current_interaction_id"
STORE=true

SYS_PROMPT="You act as rigorous C‑language assistant. Focus on standard C, avoid non‑standard extensions.
For audit: find undefined‑behavior, memory bugs, type‑safety risks.
For code generation: output only clean C source code, no markdown fences, no extra explanatory prose."

cmd_help() {
cat <<EOF
Environment toggle:
  export GEMINI_USE_INTERACTIONS=0      → switch to stable local‑json generateContent mode
  export GEMINI_SESSION_TITLE="my‑name" → override auto folder‑name web title
(default: GEMINI_USE_INTERACTIONS=1, cloud‑side Interactions‑API enabled)

Environment model override example:
  export GEMINI_MODEL=gemini-3.5-flash-lite

Commands:
  ./gemini.sh new           reset session
  ./gemini.sh ask "text"    send prompt
  ./gemini.sh ask -         read prompt from stdin (vim pipe)
[Interactions‑API only:]
  ./gemini.sh list          list cloud interaction sessions
  ./gemini.sh del ID        delete cloud‑interaction‑id
  ./gemini.sh current       show active interaction id
EOF
}

# ----- generateContent mode -----
cmd_new_gencontent() {
    jq -n '[
        {"role":"user","parts":[{"text":"'"${SYS_PROMPT}"'"}]}
    ]' > "${SESSION_FILE}"
    echo "New local session created: ${SESSION_FILE}"
}

cmd_ask_gencontent() {
    local USER_INPUT
    if [ "$1" = "-" ]; then
        USER_INPUT=$(cat)
    else
        USER_INPUT="$1"
    fi
    HIST=$(cat "${SESSION_FILE}")
    NEW_HIST=$(echo "$HIST" | jq --arg ut "${USER_INPUT}" '. + [{"role":"user","parts":[{"text":$ut}]}]')
    PAYLOAD=$(jq -n --argjson hist "$NEW_HIST" '{ "contents": $hist, "store": false }')
    RAW=$(curl -s -X POST "${GEN_CONTENT_URL}?key=${API_KEY}" \
        -H "Content-Type: application/json" \
        -d "${PAYLOAD}")
    REPLY=$(echo "$RAW" | jq -r '.candidates[0].content.parts[0].text')
    FINAL_HIST=$(echo "$NEW_HIST" | jq --arg rt "${REPLY}" '. + [{"role":"model","parts":[{"text":$rt}]}]')
    echo "${FINAL_HIST}" > "${SESSION_FILE}"
    printf "\n%s\n\n" "${REPLY}"
}

# ----- Interactions‑API beta mode -----
cmd_new_interact() {
    rm -f "${STATE_FILE}"
    echo "Reset cloud‑session pointer; next ask() creates new cloud interaction."
    echo "Auto web‑session title (folder name): [${GEMINI_SESSION_TITLE}]"
}

get_current_id() {
    [ -f "${STATE_FILE}" ] && cat "${STATE_FILE}" || echo ""
}

cmd_ask_interact() {
    local USER_INPUT
    if [ "$1" = "-" ]; then
        USER_INPUT=$(cat)
    else
        USER_INPUT="$1"
    fi
    local CUR_ID=$(get_current_id)
    local FULL_INPUT

    if [ -z "${CUR_ID}" ]; then
        # FIRST message for NEW cloud interaction: inject folder‑name title prefix
        FULL_INPUT="[${GEMINI_SESSION_TITLE}]

${SYS_PROMPT}

${USER_INPUT}"
        PAYLOAD=$(jq -n \
            --arg model "${MODEL}" \
            --arg input "${FULL_INPUT}" \
            --argjson store "${STORE}" \
            '{ "model":$model, "input":$input, "store":$store }')
    else
        # continue existing interaction: NO title prefix
        FULL_INPUT="${USER_INPUT}"
        PAYLOAD=$(jq -n \
            --arg model "${MODEL}" \
            --arg prev "${CUR_ID}" \
            --arg input "${FULL_INPUT}" \
            --argjson store "${STORE}" \
            '{ "model":$model, "previous_interaction_id":$prev, "input":$input, "store":$store }')
    fi

    RAW=$(curl -s -X POST "${INTERACT_BASE}" \
        -H "x-goog-api-key:${API_KEY}" \
        -H "Content-Type:application/json" \
        -d "${PAYLOAD}")
    INTERACTION_ID=$(echo "$RAW" | jq -r '.id')
    REPLY=$(echo "$RAW" | jq -r '.output_text')
    if [ -z "${CUR_ID}" ]; then
        echo "${INTERACTION_ID}" > "${STATE_FILE}"
        echo "New cloud‑interaction id=${INTERACTION_ID}"
    fi
    printf "\n%s\n\n" "${REPLY}"
}

cmd_list_interact() {
    curl -s -X GET "${INTERACT_BASE}" -H "x-goog-api-key:${API_KEY}" | jq
}

cmd_del_interact() {
    local ID="$1"
    curl -s -X DELETE "${INTERACT_BASE}/${ID}" -H "x-goog-api-key:${API_KEY}"
    local CUR=$(get_current_id)
    [ "${CUR}" = "${ID}" ] && rm -f "${STATE_FILE}"
    echo "Deleted cloud‑interaction: ${ID}"
}

cmd_current_interact() {
    local c=$(get_current_id)
    if [ -z "${c}" ]; then
        echo "No active cloud interaction."
    else
        echo "Active interaction id: ${c}"
    fi
}

# ----- command dispatch -----
case "${1:-help}" in
new|clear)
    if [ "${USE_INTERACTIONS}" = "1" ]; then
        cmd_new_interact
    else
        cmd_new_gencontent
    fi
    ;;
ask)
    shift
    if [ "${USE_INTERACTIONS}" = "1" ]; then
        cmd_ask_interact "$1"
    else
        cmd_ask_gencontent "$1"
    fi
    ;;
list)
    [ "${USE_INTERACTIONS}" != "1" ] && { echo "Error: list only works with GEMINI_USE_INTERACTIONS=1"; exit 1; }
    cmd_list_interact
    ;;
del)
    [ "${USE_INTERACTIONS}" != "1" ] && { echo "Error: del only works with GEMINI_USE_INTERACTIONS=1"; exit 1; }
    cmd_del_interact "$2"
    ;;
current)
    [ "${USE_INTERACTIONS}" != "1" ] && { echo "Error: current only works with GEMINI_USE_INTERACTIONS=1"; exit 1; }
    cmd_current_interact
    ;;
help|--help|"")
    cmd_help
    exit 0
    ;;
*)
    cmd_help
    exit 1
    ;;
esac

