#!/bin/bash
# Install Ralph setup script globally
# Usage: ./install.sh

set -e

RALPH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="ralph-setup"

# Check if we have write permissions
if [ ! -w "$INSTALL_DIR" ]; then
  echo "Installing Ralph globally requires sudo access..."
  sudo -v
  USE_SUDO=true
else
  USE_SUDO=false
fi

# Create a wrapper script that knows where Ralph lives
echo "Creating global ralph-setup command..."

WRAPPER=$(cat << EOF
#!/bin/bash
# Ralph global setup wrapper
RALPH_SOURCE="$RALPH_DIR"
exec "\$RALPH_SOURCE/setup-ralph.sh" "\$@"
EOF
)

if [ "$USE_SUDO" = true ]; then
  echo "$WRAPPER" | sudo tee "$INSTALL_DIR/$SCRIPT_NAME" > /dev/null
  sudo chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
else
  echo "$WRAPPER" > "$INSTALL_DIR/$SCRIPT_NAME"
  chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
fi

echo ""
echo "✓ Ralph installed globally!"
echo ""
echo "You can now run from anywhere:"
echo "  ralph-setup /path/to/your/project"
echo ""
echo "To uninstall:"
echo "  sudo rm $INSTALL_DIR/$SCRIPT_NAME"
echo ""
