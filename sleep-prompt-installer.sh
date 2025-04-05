#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Check if we are running as root.
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run this installer script as root."
  exit 1
fi

# 1. Create the awake_check.sh script in /usr/local/bin
SCRIPT_PATH="/usr/local/bin/awake_check.sh"
cat > "$SCRIPT_PATH" << 'EOF'
#!/bin/bash

# Check if zenity is installed
if ! command -v zenity &>/dev/null; then
  notify-send "Missing Dependency" "Please install zenity to use Sleep Prompt."
  exit 1
fi

# Display the dialog with one "Yes" button and a 5-second timeout.
zenity --question \
  --title="Sleep Prompt" \
  --text="Are you awake?" \
  --ok-label="Yes" \
  --cancel-label="Cancel" \
  --timeout=5

# If exit status is not 0 (Yes not clicked within 5 seconds), suspend the system.
if [ $? -ne 0 ]; then
  systemctl suspend
fi

exit 0
EOF

# Make the script executable.
chmod +x "$SCRIPT_PATH"

echo "Created script: $SCRIPT_PATH"

# 2. Create the systemd service unit file.
SERVICE_FILE="/etc/systemd/system/awake-check.service"
cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=Check if user is awake

[Service]
Type=oneshot
ExecStart=/usr/local/bin/awake_check.sh
EOF

echo "Created service unit: $SERVICE_FILE"

# 3. Create the systemd timer unit file.
TIMER_FILE="/etc/systemd/system/awake-check.timer"
cat > "$TIMER_FILE" << 'EOF'
[Unit]
Description=Run awake check at 1 AM daily

[Timer]
OnCalendar=*-*-* 01:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

echo "Created timer unit: $TIMER_FILE"

# 4. Reload systemd daemon, enable and start the timer.
systemctl daemon-reload
systemctl enable awake-check.timer
systemctl start awake-check.timer

echo "Systemd timer awake-check.timer has been enabled and started."
