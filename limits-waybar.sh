#!/bin/bash

set -u

CLAUDE_CREDENTIALS_FILE="${CLAUDE_CREDENTIALS_FILE:-$HOME/.claude/.credentials.json}"
CLAUDE_CACHE_FILE="${CLAUDE_CACHE_FILE:-/tmp/limits-waybar-claude-cache.json}"
OPENAI_AUTH_FILE="${OPENAI_AUTH_FILE:-$HOME/.codex/auth.json}"
OPENAI_USAGE_CACHE_FILE="${OPENAI_USAGE_CACHE_FILE:-/tmp/limits-waybar-openai-usage-cache.json}"
OPENAI_USAGE_CACHE_TTL="${OPENAI_USAGE_CACHE_TTL:-600}"
OPENAI_USAGE_URL="${OPENAI_USAGE_URL:-https://chatgpt.com/backend-api/wham/usage}"

format_duration() {
    local diff_seconds="$1"

    if [ "$diff_seconds" -le 0 ]; then
        printf "0m"
    elif [ "$diff_seconds" -lt 3600 ]; then
        printf "%sm" "$(( (diff_seconds + 30) / 60 ))"
    elif [ "$diff_seconds" -lt 86400 ]; then
        printf "%sh" "$(( (diff_seconds + 1800) / 3600 ))"
    else
        printf "%sd" "$(( (diff_seconds + 43200) / 86400 ))"
    fi
}

parse_iso_epoch() {
    local iso="$1"
    local normalized

    normalized=$(printf "%s" "$iso" | sed -E 's/\.([0-9]+)(Z|[+-][0-9]{2}:[0-9]{2})$/\2/')
    date -d "$normalized" +%s 2>/dev/null \
        || date -jf "%Y-%m-%dT%H:%M:%SZ" "$normalized" +%s 2>/dev/null \
        || date -jf "%Y-%m-%dT%H:%M:%S" "$normalized" +%s 2>/dev/null
}

get_file_mtime() {
    local file="$1"

    stat -c%Y "$file" 2>/dev/null || stat -f%m "$file" 2>/dev/null || echo "0"
}

get_claude_cache_reset_epoch() {
    local five_reset reset_epoch

    if [ ! -f "$CLAUDE_CACHE_FILE" ]; then
        return 1
    fi

    five_reset=$(jq -r '.five_hour.resets_at // empty' "$CLAUDE_CACHE_FILE" 2>/dev/null)
    if [ -z "$five_reset" ] || [ "$five_reset" = "null" ]; then
        return 1
    fi

    reset_epoch=$(parse_iso_epoch "$five_reset")
    if [ -n "$reset_epoch" ]; then
        printf "%s\n" "$reset_epoch"
        return 0
    fi

    return 1
}

get_claude_limits() {
    local refresh_needed cache_mtime token response http_code body
    local five_util five_reset week_util reset_epoch now_epoch time_till_reset cache_reset_epoch
    local five_int week_int text tooltip

    refresh_needed=true
    now_epoch=$(date +%s)
    if [ -f "$CLAUDE_CACHE_FILE" ]; then
        cache_mtime=$(get_file_mtime "$CLAUDE_CACHE_FILE")
        cache_reset_epoch=$(get_claude_cache_reset_epoch)
        if [ $((now_epoch - cache_mtime)) -lt 300 ] && { [ -z "${cache_reset_epoch:-}" ] || [ "$cache_reset_epoch" -gt "$now_epoch" ]; }; then
            refresh_needed=false
        fi
    fi

    if [ "$refresh_needed" = true ]; then
        token=""
        if [ -f "$CLAUDE_CREDENTIALS_FILE" ]; then
            token=$(jq -r '.claudeAiOauth.accessToken' "$CLAUDE_CREDENTIALS_FILE" 2>/dev/null)
        fi
        if [ -n "$token" ] && [ "$token" != "null" ]; then
            response=$(curl -s -w "\n%{http_code}" \
                -H "Authorization: Bearer $token" \
                -H "anthropic-beta: oauth-2025-04-20" \
                "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
            http_code=$(printf "%s\n" "$response" | tail -1)
            body=$(printf "%s\n" "$response" | sed '$d')
            if [ "$http_code" = "200" ]; then
                printf "%s\n" "$body" > "$CLAUDE_CACHE_FILE.tmp" && mv "$CLAUDE_CACHE_FILE.tmp" "$CLAUDE_CACHE_FILE" 2>/dev/null
            fi
        fi
    fi

    if [ ! -f "$CLAUDE_CACHE_FILE" ]; then
        return 1
    fi

    cache_reset_epoch=$(get_claude_cache_reset_epoch)
    now_epoch=$(date +%s)
    if [ -n "${cache_reset_epoch:-}" ] && [ "$cache_reset_epoch" -le "$now_epoch" ]; then
        return 1
    fi

    five_util=$(jq -r '.five_hour.utilization // 0' "$CLAUDE_CACHE_FILE" 2>/dev/null)
    five_reset=$(jq -r '.five_hour.resets_at // empty' "$CLAUDE_CACHE_FILE" 2>/dev/null)
    week_util=$(jq -r '.seven_day.utilization // 0' "$CLAUDE_CACHE_FILE" 2>/dev/null)

    time_till_reset=""
    if [ -n "$five_reset" ] && [ "$five_reset" != "null" ]; then
        reset_epoch=$(parse_iso_epoch "$five_reset")
        now_epoch=$(date +%s)
        if [ -n "$reset_epoch" ]; then
            time_till_reset=$(format_duration "$((reset_epoch - now_epoch))")
        fi
    fi

    five_int=$(printf "%.0f" "$five_util" 2>/dev/null || echo "0")
    week_int=$(printf "%.0f" "$week_util" 2>/dev/null || echo "0")

    if [ -n "$time_till_reset" ]; then
        text="${five_int}%:${time_till_reset}"
        tooltip="Claude: 5h ${five_int}% (resets in ${time_till_reset}), 7d ${week_int}%"
    else
        text="${five_int}%"
        tooltip="Claude: 5h ${five_int}%, 7d ${week_int}%"
    fi

    printf "%s\n%s\n" "$text" "$tooltip"
}

get_codex_limits() {
    local refresh_needed cache_mtime token account_id response http_code body
    local five_util week_util five_reset now_epoch time_till_reset
    local five_int week_int text tooltip

    refresh_needed=true
    now_epoch=$(date +%s)
    if [ -f "$OPENAI_USAGE_CACHE_FILE" ]; then
        cache_mtime=$(get_file_mtime "$OPENAI_USAGE_CACHE_FILE")
        if [ $((now_epoch - cache_mtime)) -lt "$OPENAI_USAGE_CACHE_TTL" ]; then
            refresh_needed=false
        fi
    fi

    if [ "$refresh_needed" = true ]; then
        token=""
        account_id=""
        if [ -f "$OPENAI_AUTH_FILE" ]; then
            token=$(jq -r '.tokens.access_token // empty' "$OPENAI_AUTH_FILE" 2>/dev/null)
            account_id=$(jq -r '.tokens.account_id // empty' "$OPENAI_AUTH_FILE" 2>/dev/null)
        fi
        if [ -n "$token" ] && [ "$token" != "null" ]; then
            if [ -n "$account_id" ] && [ "$account_id" != "null" ]; then
                response=$(curl -s -w "\n%{http_code}" \
                    -H "Authorization: Bearer $token" \
                    -H "ChatGPT-Account-ID: $account_id" \
                    "$OPENAI_USAGE_URL" 2>/dev/null)
            else
                response=$(curl -s -w "\n%{http_code}" \
                    -H "Authorization: Bearer $token" \
                    "$OPENAI_USAGE_URL" 2>/dev/null)
            fi
            http_code=$(printf "%s\n" "$response" | tail -1)
            body=$(printf "%s\n" "$response" | sed '$d')
            if [ "$http_code" = "200" ] && printf "%s\n" "$body" | jq -e '.rate_limit.primary_window' >/dev/null 2>&1; then
                printf "%s\n" "$body" > "$OPENAI_USAGE_CACHE_FILE.tmp" && mv "$OPENAI_USAGE_CACHE_FILE.tmp" "$OPENAI_USAGE_CACHE_FILE" 2>/dev/null
            fi
        fi
    fi

    if [ ! -f "$OPENAI_USAGE_CACHE_FILE" ]; then
        return 1
    fi

    five_util=$(jq -r '.rate_limit.primary_window.used_percent // 0' "$OPENAI_USAGE_CACHE_FILE" 2>/dev/null)
    week_util=$(jq -r '.rate_limit.secondary_window.used_percent // 0' "$OPENAI_USAGE_CACHE_FILE" 2>/dev/null)
    five_reset=$(jq -r '.rate_limit.primary_window.reset_at // empty' "$OPENAI_USAGE_CACHE_FILE" 2>/dev/null)

    time_till_reset=""
    if [ -n "$five_reset" ] && [ "$five_reset" != "null" ]; then
        now_epoch=$(date +%s)
        time_till_reset=$(format_duration "$((five_reset - now_epoch))")
    fi

    five_int=$(printf "%.0f" "$five_util" 2>/dev/null || echo "0")
    week_int=$(printf "%.0f" "$week_util" 2>/dev/null || echo "0")

    if [ -n "$time_till_reset" ]; then
        text="${five_int}%:${time_till_reset}"
        tooltip="Codex: 5h ${five_int}% (resets in ${time_till_reset}), 7d ${week_int}%"
    else
        text="${five_int}%"
        tooltip="Codex: 5h ${five_int}%, 7d ${week_int}%"
    fi

    printf "%s\n%s\n" "$text" "$tooltip"
}

claude_text=""
claude_tooltip=""
if claude_output=$(get_claude_limits); then
    claude_text=$(printf "%s\n" "$claude_output" | sed -n '1p')
    claude_tooltip=$(printf "%s\n" "$claude_output" | sed -n '2p')
fi

codex_text=""
codex_tooltip=""
if codex_output=$(get_codex_limits); then
    codex_text=$(printf "%s\n" "$codex_output" | sed -n '1p')
    codex_tooltip=$(printf "%s\n" "$codex_output" | sed -n '2p')
fi

text="$claude_text"
if [ -n "$codex_text" ]; then
    if [ -n "$text" ]; then
        text="$text $codex_text"
    else
        text="$codex_text"
    fi
fi

tooltip="$claude_tooltip"
if [ -n "$codex_tooltip" ]; then
    if [ -n "$tooltip" ]; then
        tooltip="$tooltip
$codex_tooltip"
    else
        tooltip="$codex_tooltip"
    fi
fi

if [ -z "$text" ]; then
    text=""
    tooltip="No Claude or Codex usage data found"
fi

jq -cn --arg text "$text" --arg tooltip "$tooltip" '{text: $text, tooltip: $tooltip}'
