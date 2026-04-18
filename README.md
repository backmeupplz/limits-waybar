# limits-waybar

Show your Claude Code and Codex rate limits in Waybar. Displays 5-hour utilization and time until reset for each tool.

```
C14%:2h O0%:4h
```

Hover for a tooltip with both 5h and 7d utilization for Claude and Codex.

## How it works

- Claude Code: reads your OAuth credentials from `~/.claude/.credentials.json` and calls the Anthropic usage API (`/api/oauth/usage`). Responses are cached for 5 minutes.
- Codex: reads the latest `rate_limits` snapshot from your local Codex session logs under `~/.codex/sessions`.

## Requirements

- [waybar](https://github.com/Alexays/Waybar)
- [Claude Code](https://github.com/anthropics/claude-code) logged in via OAuth for Claude limits
- [Codex](https://openai.com/codex/) for Codex limits
- `curl` and `jq`

## Install

```bash
git clone https://github.com/backmeupplz/limits-waybar.git
cd limits-waybar
bash install.sh
```

Then add `"custom/limits-waybar"` to your Waybar modules and add the module definition to your `config.jsonc`:

```jsonc
"custom/limits-waybar": {
  "exec": "$HOME/.config/waybar/scripts/limits-waybar.sh",
  "interval": 60,
  "return-type": "json",
  "format": "{}",
  "tooltip": true
}
```

If you already use the legacy `custom/claude-limits` module, rerun `install.sh` and it will keep working with the updated script.

Restart Waybar.

## Manual install

Copy `limits-waybar.sh` to `~/.config/waybar/scripts/`, make it executable, and add the module config above to your Waybar config.

## Claude API response

The Claude part calls `https://api.anthropic.com/api/oauth/usage`, which returns:

```json
{
  "five_hour": { "utilization": 14.0, "resets_at": "2026-03-17T17:00:01Z" },
  "seven_day": { "utilization": 16.0, "resets_at": "2026-03-20T15:00:01Z" },
  "seven_day_sonnet": { "utilization": 20.0, "resets_at": "2026-03-19T21:00:00Z" }
}
```

## License

MIT
