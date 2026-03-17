# claude-limits-waybar

Show your Claude Code rate limits in waybar. Displays 5-hour utilization % and hours until reset.

```
14%:2h
```

Hover for tooltip with both 5h and 7d utilization.

## How it works

Reads your Claude Code OAuth credentials from `~/.claude/.credentials.json` and calls the Anthropic usage API (`/api/oauth/usage`) to get your actual rate limit utilization. Caches the response for 60 seconds.

## Requirements

- [waybar](https://github.com/Alexays/Waybar)
- [Claude Code](https://github.com/anthropics/claude-code) logged in via OAuth
- `curl` and `jq`

## Install

```bash
git clone https://github.com/backmeupplz/claude-limits-waybar.git
cd claude-limits-waybar
bash install.sh
```

Then add `"custom/claude-limits"` to your waybar modules and add the module definition to your `config.jsonc`:

```jsonc
"custom/claude-limits": {
  "exec": "$HOME/.config/waybar/scripts/claude-limits.sh",
  "interval": 60,
  "return-type": "json",
  "format": "{}",
  "tooltip": true
}
```

Restart waybar.

## Manual install

Copy `claude-limits.sh` to `~/.config/waybar/scripts/`, make it executable, and add the module config above to your waybar config.

## API response

The script calls `https://api.anthropic.com/api/oauth/usage` which returns:

```json
{
  "five_hour": { "utilization": 14.0, "resets_at": "2026-03-17T17:00:01Z" },
  "seven_day": { "utilization": 16.0, "resets_at": "2026-03-20T15:00:01Z" },
  "seven_day_sonnet": { "utilization": 20.0, "resets_at": "2026-03-19T21:00:00Z" }
}
```

## License

MIT
