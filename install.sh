#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST_DIR="$HOME/.config/waybar/scripts"
DEST="$DEST_DIR/claude-limits.sh"
CONFIG="$HOME/.config/waybar/config.jsonc"
STYLE="$HOME/.config/waybar/style.css"

echo "Installing claude-limits-waybar..."

# Check dependencies
for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd is required but not installed."
        exit 1
    fi
done

# Check Claude Code credentials
if [ ! -f "$HOME/.claude/.credentials.json" ]; then
    echo "Warning: Claude Code credentials not found at ~/.claude/.credentials.json"
    echo "Make sure you're logged into Claude Code (run 'claude' and complete OAuth login)."
fi

# Install the script
mkdir -p "$DEST_DIR"
cp "$SCRIPT_DIR/claude-limits.sh" "$DEST"
chmod +x "$DEST"
echo "Installed script to $DEST"

# Add waybar module config if not already present
if [ -f "$CONFIG" ]; then
    if grep -q "custom/claude-limits" "$CONFIG"; then
        echo "Waybar config already has custom/claude-limits module, skipping."
    else
        echo ""
        echo "Add this to your waybar config.jsonc modules-center (or wherever you want it):"
        echo ""
        echo '  "custom/claude-limits"'
        echo ""
        echo "And add this module definition:"
        echo ""
        cat << 'EOF'
  "custom/claude-limits": {
    "exec": "$HOME/.config/waybar/scripts/claude-limits.sh",
    "interval": 300,
    "return-type": "json",
    "format": "{}",
    "tooltip": true
  },
EOF
    fi
else
    echo ""
    echo "No waybar config found at $CONFIG"
    echo "Create one and add the custom/claude-limits module (see README)."
fi

# Add style if not already present
if [ -f "$STYLE" ]; then
    if grep -q "custom-claude-limits" "$STYLE"; then
        echo "Waybar style already has claude-limits styling, skipping."
    else
        echo "" >> "$STYLE"
        cat >> "$STYLE" << 'EOF'

#custom-claude-limits {
  min-width: 12px;
  margin: 0 0 0 7.5px;
  font-size: 10px;
  padding-bottom: 1px;
}
EOF
        echo "Added claude-limits styling to $STYLE"
    fi
fi

echo ""
echo "Done! Restart waybar to see it:"
echo "  killall waybar && waybar &"
echo ""
echo "Or if you're on Omarchy:"
echo "  omarchy-restart-waybar"
