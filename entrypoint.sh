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

    if [ -n "$PRINTER_URI" ]; then
        echo "Found LabelWriter 4XL at: $PRINTER_URI"
        # Add the printer with the correct PPD
        lpadmin -p labelwriter-4xl \
            -D "DYMO LabelWriter 4XL" \
            -L "Network Label Printer" \
            -v "$PRINTER_URI" \
            -m drv:///sample.drv/dymo.ppd 2>/dev/null || \
        lpadmin -p labelwriter-4xl \
            -D "DYMO LabelWriter 4XL" \
            -L "Network Label Printer" \
            -v "$PRINTER_URI" \
            -P /usr/share/ppd/dymo/lw4xl.ppd 2>/dev/null || \
        lpadmin -p labelwriter-4xl \
            -D "DYMO LabelWriter 4XL" \
            -L "Network Label Printer" \
            -v "$PRINTER_URI" \
            -m everywhere 2>/dev/null || true

        # Enable and accept jobs
        cupsenable labelwriter-4xl 2>/dev/null || true
        cupsaccept labelwriter-4xl 2>/dev/null || true

        # Set as default printer
        lpadmin -d labelwriter-4xl 2>/dev/null || true

        echo "LabelWriter 4XL configured successfully"
    else
        echo "LabelWriter 4XL not detected, skipping auto-configuration"
    fi
}

# Run auto-configuration in background after CUPS starts
(sleep 10 && configure_labelwriter) &

echo "Starting CUPS..."
exec "$@"
