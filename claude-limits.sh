#!/bin/bash

# Claude Code Rate Limit Status for Waybar
# Uses Anthropic OAuth usage API for real utilization data
# Format: %used:Xh (e.g., 14%:3h)
#
# Requires: curl, jq
# Claude Code must be logged in (OAuth credentials at ~/.claude/.credentials.json)

CREDENTIALS_FILE="$HOME/.claude/.credentials.json"
CACHE_FILE="/tmp/claude-usage-cache.json"

# Check credentials exist
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo '{"text": "", "tooltip": "No Claude credentials found"}'
    exit 0
fi

# Refresh cache if older than 60 seconds
refresh_needed=true
if [ -f "$CACHE_FILE" ]; then
    cache_mtime=$(stat -c%Y "$CACHE_FILE" 2>/dev/null || stat -f%m "$CACHE_FILE" 2>/dev/null || echo "0")
    now=$(date +%s)
    if [ $((now - cache_mtime)) -lt 60 ]; then
        refresh_needed=false
    fi
fi

if [ "$refresh_needed" = true ]; then
    TOKEN=$(jq -r '.claudeAiOauth.accessToken' "$CREDENTIALS_FILE" 2>/dev/null)
    if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
        curl -s -f \
            -H "Authorization: Bearer $TOKEN" \
            -H "anthropic-beta: oauth-2025-04-20" \
            "https://api.anthropic.com/api/oauth/usage" \
            -o "$CACHE_FILE.tmp" 2>/dev/null && mv "$CACHE_FILE.tmp" "$CACHE_FILE" 2>/dev/null
    fi
fi

# Read cache
if [ ! -f "$CACHE_FILE" ]; then
    echo '{"text": "", "tooltip": "No usage data yet"}'
    exit 0
fi

# Parse with jq
FIVE_UTIL=$(jq -r '.five_hour.utilization // 0' "$CACHE_FILE" 2>/dev/null)
FIVE_RESET=$(jq -r '.five_hour.resets_at // empty' "$CACHE_FILE" 2>/dev/null)
WEEK_UTIL=$(jq -r '.seven_day.utilization // 0' "$CACHE_FILE" 2>/dev/null)
WEEK_RESET=$(jq -r '.seven_day.resets_at // empty' "$CACHE_FILE" 2>/dev/null)

# Calculate hours until 5h reset
hours_till_reset="-"
if [ -n "$FIVE_RESET" ] && [ "$FIVE_RESET" != "null" ]; then
    reset_epoch=$(date -d "$FIVE_RESET" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%S" "$(echo "$FIVE_RESET" | cut -d+ -f1 | cut -d. -f1)" +%s 2>/dev/null)
    now_epoch=$(date +%s)
    if [ -n "$reset_epoch" ]; then
        diff_seconds=$((reset_epoch - now_epoch))
        if [ $diff_seconds -le 0 ]; then
            hours_till_reset="0"
        else
            hours_till_reset=$(( (diff_seconds + 1800) / 3600 ))
        fi
    fi
fi

# Format: %used:Xh
FIVE_INT=$(printf "%.0f" "$FIVE_UTIL" 2>/dev/null || echo "0")
WEEK_INT=$(printf "%.0f" "$WEEK_UTIL" 2>/dev/null || echo "0")

formatted_text="${FIVE_INT}%:${hours_till_reset}h"
tooltip="Claude Code: 5h ${FIVE_INT}% (resets in ${hours_till_reset}h), 7d ${WEEK_INT}%"

echo "{\"text\": \"${formatted_text}\", \"tooltip\": \"${tooltip}\"}"
