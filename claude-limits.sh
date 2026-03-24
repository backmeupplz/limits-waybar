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

# Refresh cache if older than 5 minutes
refresh_needed=true
if [ -f "$CACHE_FILE" ]; then
    cache_mtime=$(stat -c%Y "$CACHE_FILE" 2>/dev/null || stat -f%m "$CACHE_FILE" 2>/dev/null || echo "0")
    now=$(date +%s)
    if [ $((now - cache_mtime)) -lt 300 ]; then
        refresh_needed=false
    fi
fi

if [ "$refresh_needed" = true ]; then
    TOKEN=$(jq -r '.claudeAiOauth.accessToken' "$CREDENTIALS_FILE" 2>/dev/null)
    if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
        response=$(curl -s -w "\n%{http_code}" \
            -H "Authorization: Bearer $TOKEN" \
            -H "anthropic-beta: oauth-2025-04-20" \
            "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
        http_code=$(echo "$response" | tail -1)
        body=$(echo "$response" | sed '$d')
        if [ "$http_code" = "200" ]; then
            echo "$body" > "$CACHE_FILE.tmp" && mv "$CACHE_FILE.tmp" "$CACHE_FILE" 2>/dev/null
        fi
        # On non-200 (e.g. 429), keep using stale cache
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

# Calculate time until 5h reset
time_till_reset=""
if [ -n "$FIVE_RESET" ] && [ "$FIVE_RESET" != "null" ]; then
    reset_epoch=$(date -d "$FIVE_RESET" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%S" "$(echo "$FIVE_RESET" | cut -d+ -f1 | cut -d. -f1)" +%s 2>/dev/null)
    now_epoch=$(date +%s)
    if [ -n "$reset_epoch" ]; then
        diff_seconds=$((reset_epoch - now_epoch))
        if [ $diff_seconds -le 0 ]; then
            time_till_reset="0m"
        elif [ $diff_seconds -lt 3600 ]; then
            time_till_reset="$(( (diff_seconds + 30) / 60 ))m"
        else
            time_till_reset="$(( (diff_seconds + 1800) / 3600 ))h"
        fi
    fi
fi

# Format: %used:Xh or %used:Xm
FIVE_INT=$(printf "%.0f" "$FIVE_UTIL" 2>/dev/null || echo "0")
WEEK_INT=$(printf "%.0f" "$WEEK_UTIL" 2>/dev/null || echo "0")

if [ -n "$time_till_reset" ]; then
    formatted_text="${FIVE_INT}%:${time_till_reset}"
    tooltip="Claude Code: 5h ${FIVE_INT}% (resets in ${time_till_reset}), 7d ${WEEK_INT}%"
else
    formatted_text="${FIVE_INT}%"
    tooltip="Claude Code: 5h ${FIVE_INT}%, 7d ${WEEK_INT}%"
fi

echo "{\"text\": \"${formatted_text}\", \"tooltip\": \"${tooltip}\"}"
