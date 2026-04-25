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

# Use expect to spawn claude, handle optional trust dialog, then fetch /usage
RAW=$(expect -c "
    log_user 1
    set timeout 20
    spawn $CLAUDE --dangerously-skip-permissions
    # Wait up to 4s for an optional directory trust dialog.
    # Option 1 (Yes, trust) is pre-selected — send Enter to confirm it.
    # If no dialog appears (directory already trusted), continue immediately.
    set timeout 4
    expect {
        -re {trust|Trust} {
            send \"\r\"
            sleep 5
        }
        timeout {}
    }
    set timeout 20
    send \"/usage\r\"
    sleep 6
    send \"\x1b\"
    sleep 1
    send \"/exit\r\"
    expect eof
" 2>/dev/null)

# Strip ANSI codes and control chars
CLEAN=$(echo "$RAW" | sed $'s/\x1b\[[0-9;]*[a-zA-Z]//g' | sed $'s/\x1b\[?[0-9]*[a-z]//g' | sed $'s/\x1b\[[0-9;]*m//g' | sed $'s/\x1b[>\\[][^a-zA-Z]*[a-zA-Z]//g' | tr -s ' ')

# Parse sections using an awk state machine.
# Claude's /usage TUI now renders each section across multiple lines:
#   Line 1: header  (e.g. "Currentsession" — spaces may be collapsed by ANSI stripping)
#   Line 2: progress bar with percentage  (e.g. "42%used")
#   Line 3: reset time  (e.g. "Resets8:20pm(Asia/Jerusalem)")
# The awk approach also handles the older single-line format for backwards compatibility.
PARSED=$(echo "$CLEAN" | awk '
    # Section header detection — [[:space:]]* handles collapsed spaces
    /[Cc]urrent[[:space:]]*[Ss]ession/ && !/[Ww]eek/ {
        in_session=1; in_weekly_all=0; in_weekly_sonnet=0
    }
    /[Cc]urrent[[:space:]]*[Ww]eek/ && /[Aa]ll[[:space:]]*[Mm]odels|allmodels/ {
        in_weekly_all=1; in_session=0; in_weekly_sonnet=0
    }
    /[Cc]urrent[[:space:]]*[Ww]eek/ && /[Ss]onnet/ {
        in_weekly_sonnet=1; in_session=0; in_weekly_all=0
    }
    # End of usage dialog
    /[Ee]sc[[:space:]]*to[[:space:]]*[Cc]ancel|[Rr]efreshing/ {
        in_session=0; in_weekly_all=0; in_weekly_sonnet=0
    }
    # Extract percentage (first N% found after header)
    in_session && !session_pct && match($0, /[0-9]+%/) {
        session_pct = substr($0, RSTART, RLENGTH-1)
    }
    in_weekly_all && !weekly_all_pct && match($0, /[0-9]+%/) {
        weekly_all_pct = substr($0, RSTART, RLENGTH-1)
    }
    in_weekly_sonnet && !weekly_sonnet_pct && match($0, /[0-9]+%/) {
        weekly_sonnet_pct = substr($0, RSTART, RLENGTH-1)
    }
    # Extract reset time: strip "Resets" prefix and "Esc…" suffix
    in_session && !session_reset && /[Rr]eset/ {
        session_reset = $0
        sub(/.*[Rr]eset[s]?[[:space:]]*/,"",session_reset)
        sub(/[Ee]sc.*/,"",session_reset)
    }
    in_weekly_all && !weekly_all_reset && /[Rr]eset/ {
        weekly_all_reset = $0
        sub(/.*[Rr]eset[s]?[[:space:]]*/,"",weekly_all_reset)
        sub(/[Ee]sc.*/,"",weekly_all_reset)
    }
    in_weekly_sonnet && !weekly_sonnet_reset && /[Rr]eset/ {
        weekly_sonnet_reset = $0
        sub(/.*[Rr]eset[s]?[[:space:]]*/,"",weekly_sonnet_reset)
        sub(/[Ee]sc.*/,"",weekly_sonnet_reset)
    }
    END {
        print session_pct
        print session_reset
        print weekly_all_pct
        print weekly_all_reset
        print weekly_sonnet_pct
        print weekly_sonnet_reset
    }
')

SESSION_PCT=$(echo "$PARSED"         | sed -n '1p')
SESSION_RESET=$(echo "$PARSED"       | sed -n '2p')
WEEKLY_ALL_PCT=$(echo "$PARSED"      | sed -n '3p')
WEEKLY_ALL_RESET=$(echo "$PARSED"    | sed -n '4p')
WEEKLY_SONNET_PCT=$(echo "$PARSED"   | sed -n '5p')
WEEKLY_SONNET_RESET=$(echo "$PARSED" | sed -n '6p')

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
        | sed 's/Jan/ Jan /g; s/Feb/ Feb /g; s/Mar/ Mar /g; s/Apr/ Apr /g; s/May/ May /g; s/Jun/ Jun /g; s/Jul/ Jul /g; s/Aug/ Aug /g; s/Sep/ Sep /g; s/Oct/ Oct /g; s/Nov/ Nov /g; s/Dec/ Dec /g' \
        | sed 's/at/ at /g; s/pm/pm /g; s/am/am /g' \
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
