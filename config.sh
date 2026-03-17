#!/bin/bash

REPO_URL="https://raw.githubusercontent.com/dav473programer/aptman/refs/heads/main/aptman.sh"
DEST_PATH="/usr/local/bin/aptman"
DESKTOP_FILE="/usr/share/applications/aptman.desktop"
echo "Installing aptman..."
sudo wget -qO "$DEST_PATH" "$REPO_URL"
sudo chmod +x "$DEST_PATH"
sudo bash -c "cat > $DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=APT Manager
Comment=Manage your APT's effortlessly.
Exec=$DEST_PATH
Terminal=true
Icon=system-software-install
Categories=Utility;System
EOF

echo "Installation complete! You can now run APT Manager (aptman) or find it in your menu."

