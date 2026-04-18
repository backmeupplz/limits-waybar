#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST_DIR="$HOME/.config/waybar/scripts"
DEST="$DEST_DIR/limits-waybar.sh"
LEGACY_DEST="$DEST_DIR/claude-limits.sh"
CONFIG="$HOME/.config/waybar/config.jsonc"
STYLE="$HOME/.config/waybar/style.css"

echo "Installing limits-waybar..."

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

# Install the script and keep the legacy filename working for existing configs
mkdir -p "$DEST_DIR"
cp "$SCRIPT_DIR/limits-waybar.sh" "$DEST"
cp "$SCRIPT_DIR/limits-waybar.sh" "$LEGACY_DEST"
chmod +x "$DEST"
chmod +x "$LEGACY_DEST"
echo "Installed script to $DEST"
echo "Installed legacy compatibility script to $LEGACY_DEST"

# Add waybar module config if not already present
if [ -f "$CONFIG" ]; then
    if grep -q "custom/limits-waybar" "$CONFIG"; then
        echo "Waybar config already has custom/limits-waybar module, skipping."
    elif grep -q "custom/claude-limits" "$CONFIG"; then
        echo "Waybar config already has legacy custom/claude-limits module."
        echo "It will keep working and now show both Claude and Codex limits."
    else
        echo ""
        echo "Add this to your waybar config.jsonc modules-center (or wherever you want it):"
        echo ""
        echo '  "custom/limits-waybar"'
        echo ""
        echo "And add this module definition:"
        echo ""
        cat << 'EOF'
  "custom/limits-waybar": {
    "exec": "$HOME/.config/waybar/scripts/limits-waybar.sh",
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
    echo "Create one and add the custom/limits-waybar module (see README)."
fi

# Add style if not already present
if [ -f "$STYLE" ]; then
    if grep -q "custom-limits-waybar" "$STYLE" && grep -q "custom-claude-limits" "$STYLE"; then
        echo "Waybar style already has limits-waybar styling, skipping."
    elif grep -q "custom-claude-limits" "$STYLE"; then
        echo "" >> "$STYLE"
        cat >> "$STYLE" << 'EOF'

#custom-limits-waybar {
  min-width: 12px;
  margin: 0 0 0 7.5px;
  font-size: 10px;
  padding-bottom: 1px;
}
EOF
        echo "Added limits-waybar styling to $STYLE"
    elif grep -q "custom-limits-waybar" "$STYLE"; then
        echo "" >> "$STYLE"
        cat >> "$STYLE" << 'EOF'

#custom-claude-limits {
  min-width: 12px;
  margin: 0 0 0 7.5px;
  font-size: 10px;
  padding-bottom: 1px;
}
EOF
        echo "Added legacy claude-limits styling to $STYLE"
    else
        echo "" >> "$STYLE"
        cat >> "$STYLE" << 'EOF'

#custom-limits-waybar,
#custom-claude-limits {
  min-width: 12px;
  margin: 0 0 0 7.5px;
  font-size: 10px;
  padding-bottom: 1px;
}
EOF
        echo "Added limits-waybar styling to $STYLE"
    fi
fi

echo ""
echo "Done! Restart waybar to see it:"
echo "  killall waybar && waybar &"
echo ""
echo "Or if you're on Omarchy:"
echo "  omarchy-restart-waybar"
