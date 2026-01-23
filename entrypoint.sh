#!/bin/bash
set -e

# Set admin password if provided
if [ -n "$CUPS_ADMIN_PASSWORD" ]; then
    ADMIN_USER="${CUPS_ADMIN_USER:-admin}"
    echo "Setting CUPS admin password for user: $ADMIN_USER"

    # Ensure admin user exists first
    if ! id -u "$ADMIN_USER" &>/dev/null; then
        useradd -M "$ADMIN_USER"
    fi

    # Add user to lpadmin group for CUPS admin access
    usermod -aG lpadmin "$ADMIN_USER"

    # Set password by directly modifying /etc/shadow (bypasses PAM issues on ARM64)
    PASSWORD_HASH=$(openssl passwd -6 "$CUPS_ADMIN_PASSWORD")
    if grep -q "^${ADMIN_USER}:" /etc/shadow; then
        sed -i "s|^${ADMIN_USER}:[^:]*:|${ADMIN_USER}:${PASSWORD_HASH}:|" /etc/shadow
    else
        echo "${ADMIN_USER}:${PASSWORD_HASH}:19000:0:99999:7:::" >> /etc/shadow
    fi

    echo "CUPS admin user configured successfully"
fi

# Start avahi for printer discovery (optional)
if [ "$ENABLE_AVAHI" = "true" ]; then
    echo "Starting Avahi daemon for printer discovery..."
    avahi-daemon --daemonize --no-chroot 2>/dev/null || true
fi

# Auto-configure LabelWriter 4XL if detected
configure_labelwriter() {
    echo "Checking for DYMO LabelWriter 4XL..."
    sleep 5  # Wait for USB device to be available

    # Check if already configured
    if lpstat -p labelwriter-4xl 2>/dev/null; then
        echo "LabelWriter 4XL already configured"
        return
    fi

    # Find the printer URI
    PRINTER_URI=$(lpinfo -v 2>/dev/null | grep -i "dymo" | grep -i "4xl" | head -1 | awk '{print $2}')

    if [ -z "$PRINTER_URI" ]; then
        echo "LabelWriter 4XL not detected, skipping auto-configuration"
        return
    fi

    echo "Found LabelWriter 4XL at: $PRINTER_URI"

    # Try PPD sources in order of preference
    PRINTER_NAME="labelwriter-4xl"
    PRINTER_DESC="DYMO LabelWriter 4XL"
    PRINTER_LOC="Network Label Printer"
    PPD_SOURCES="drv:///sample.drv/dymo.ppd /usr/share/ppd/dymo/lw4xl.ppd everywhere"

    for ppd in $PPD_SOURCES; do
        if [ "$ppd" = "everywhere" ]; then
            lpadmin -p "$PRINTER_NAME" -D "$PRINTER_DESC" -L "$PRINTER_LOC" -v "$PRINTER_URI" -m "$ppd" 2>/dev/null && break
        else
            lpadmin -p "$PRINTER_NAME" -D "$PRINTER_DESC" -L "$PRINTER_LOC" -v "$PRINTER_URI" -P "$ppd" 2>/dev/null && break
        fi
    done

    # Enable printer and accept jobs
    cupsenable "$PRINTER_NAME" 2>/dev/null || true
    cupsaccept "$PRINTER_NAME" 2>/dev/null || true
    lpadmin -d "$PRINTER_NAME" 2>/dev/null || true

    echo "LabelWriter 4XL configured successfully"
}

# Run auto-configuration in background after CUPS starts
(sleep 10 && configure_labelwriter) &

echo "Starting CUPS..."
exec "$@"
