#!/bin/bash
# Spawns claude, sends /usage, captures output, extracts quota data as JSON
# Usage: ./fetch-quota.sh [claude-path]

# CRITICAL: GUI apps launch with minimal/empty PATH — set it first
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:${HOME:+$HOME/.local/bin}:${PATH:-}"

# Ensure env vars that claude needs for auth
export HOME="${HOME:-$(eval echo ~)}"
export USER="${USER:-$(whoami)}"
export SHELL="${SHELL:-/bin/zsh}"
export TERM="${TERM:-xterm-256color}"

# Source user's shell profile for full environment
[[ -f "$HOME/.zprofile" ]] && source "$HOME/.zprofile" 2>/dev/null
[[ -f "$HOME/.zshrc" ]] && source "$HOME/.zshrc" 2>/dev/null

CLAUDE="${1:-claude}"

# Find claude if not a full path
if [[ "$CLAUDE" != /* ]]; then
    CLAUDE=$(which claude 2>/dev/null || echo "")
    if [[ -z "$CLAUDE" ]]; then
        for p in /usr/local/bin/claude /opt/homebrew/bin/claude "$HOME/.claude/local/claude" "$HOME/.local/bin/claude"; do
            [[ -x "$p" ]] && CLAUDE="$p" && break
        done
    fi
fi

if [[ -z "$CLAUDE" || ! -x "$CLAUDE" ]]; then
    echo '{"error":"cli_not_found"}'
    exit 1
fi

# Working directory is set by the calling app to a trusted claude project dir

# Use expect — --dangerously-skip-permissions bypasses trust dialog
RAW=$(expect -c "
    log_user 1
    set timeout 20
    spawn $CLAUDE --dangerously-skip-permissions
    sleep 4
    send \"/usage\r\"
    sleep 6
    send \"\x1b\"
    sleep 1
    send \"/exit\r\"
    expect eof
" 2>/dev/null)

# Strip ANSI codes and control chars
CLEAN=$(echo "$RAW" | sed $'s/\x1b\[[0-9;]*[a-zA-Z]//g' | sed $'s/\x1b\[?[0-9]*[a-z]//g' | sed $'s/\x1b\[[0-9;]*m//g' | sed $'s/\x1b[>\\[][^a-zA-Z]*[a-zA-Z]//g' | tr -s ' ')

# The TUI output may collapse all sections onto one line.
# Split on "Current " so each section is on its own line before parsing.
SPLIT=$(echo "$CLEAN" | sed 's/Current /\nCurrent /g')

# Extract percentages — each section is now isolated
SESSION_PCT=$(echo "$SPLIT" | grep -i "session" | grep -v -i "week" | grep -oE '[0-9]+%' | head -1 | tr -d '%')
WEEKLY_ALL_PCT=$(echo "$SPLIT" | grep -i "allmodels\|all models" | grep -oE '[0-9]+%' | head -1 | tr -d '%')
WEEKLY_SONNET_PCT=$(echo "$SPLIT" | grep -i "Sonnetonly\|Sonnet only" | grep -oE '[0-9]+%' | head -1 | tr -d '%')

# Extract reset times — strip everything up to and including "Reset(s)" then strip trailing "Esc to cancel"
SESSION_RESET=$(echo "$SPLIT" | grep -i "session" | grep -v -i "week" | sed 's/.*[Rr]ese[tTs]*//' | sed 's/Esc.*//' | tr -d $'\r' | head -1)
WEEKLY_ALL_RESET=$(echo "$SPLIT" | grep -i "allmodels\|all models" | sed 's/.*[Rr]ese[tTs]*//' | sed 's/Esc.*//' | tr -d $'\r' | head -1)
WEEKLY_SONNET_RESET=$(echo "$SPLIT" | grep -i "Sonnetonly\|Sonnet only" | sed 's/.*[Rr]ese[tTs]*//' | sed 's/Esc.*//' | tr -d $'\r' | head -1)

# Default to 0/— if empty
SESSION_PCT=${SESSION_PCT:-0}
WEEKLY_ALL_PCT=${WEEKLY_ALL_PCT:-0}
WEEKLY_SONNET_PCT=${WEEKLY_SONNET_PCT:-0}
SESSION_RESET=${SESSION_RESET:-"—"}
WEEKLY_ALL_RESET=${WEEKLY_ALL_RESET:-"—"}
WEEKLY_SONNET_RESET=${WEEKLY_SONNET_RESET:-"—"}

# Clean up reset strings: add spaces back around known words
clean_reset() {
    echo "$1" | tr -d '\r\n' | sed 's/ *$//' \
        | sed 's/Mar/ Mar /g; s/at/ at /g; s/pm/pm /g; s/am/am /g' \
        | sed 's/(/ (/g' | tr -s ' ' | sed 's/ *$//'
}
SESSION_RESET=$(clean_reset "$SESSION_RESET")
WEEKLY_ALL_RESET=$(clean_reset "$WEEKLY_ALL_RESET")
WEEKLY_SONNET_RESET=$(clean_reset "$WEEKLY_SONNET_RESET")

# Output JSON
cat <<EOF
{
    "sessionPercent": $SESSION_PCT,
    "sessionResetTime": "$SESSION_RESET",
    "weeklyAllPercent": $WEEKLY_ALL_PCT,
    "weeklyAllResetTime": "$WEEKLY_ALL_RESET",
    "weeklySonnetPercent": $WEEKLY_SONNET_PCT,
    "weeklySonnetResetTime": "$WEEKLY_SONNET_RESET"
}
EOF
