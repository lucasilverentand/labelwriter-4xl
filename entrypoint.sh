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
    echo "Starting dbus for Avahi..."
    service dbus start
    echo "Starting Avahi daemon for printer discovery..."
    avahi-daemon --daemonize --no-chroot || echo "Warning: Failed to start Avahi"

    # Create custom Avahi service file if PRINTER_BONJOUR_NAME is set
    if [ -n "$PRINTER_BONJOUR_NAME" ]; then
        echo "Configuring custom Bonjour name: $PRINTER_BONJOUR_NAME"

        # Disable CUPS's built-in Bonjour advertising
        sed -i 's/^BrowseLocalProtocols.*/BrowseLocalProtocols none/' /etc/cups/cupsd.conf

        mkdir -p /etc/avahi/services
        cat > /etc/avahi/services/labelwriter.service <<EOF
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name>$PRINTER_BONJOUR_NAME</name>
  <service>
    <type>_ipp._tcp</type>
    <port>631</port>
    <txt-record>txtvers=1</txt-record>
    <txt-record>qtotal=1</txt-record>
    <txt-record>rp=printers/labelwriter-4xl</txt-record>
    <txt-record>ty=DYMO LabelWriter 4XL</txt-record>
    <txt-record>pdl=application/pdf,image/jpeg,image/png</txt-record>
    <txt-record>printer-state=3</txt-record>
    <txt-record>printer-type=0x2</txt-record>
  </service>
</service-group>
EOF
    fi
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

    # Configure printer with DYMO driver
    PRINTER_NAME="labelwriter-4xl"
    PRINTER_DESC="DYMO LabelWriter 4XL"
    PRINTER_LOC="Network Label Printer"

    # Use the DYMO LabelWriter 4XL driver
    if ! lpadmin -p "$PRINTER_NAME" -D "$PRINTER_DESC" -L "$PRINTER_LOC" -v "$PRINTER_URI" -m "dymo:0/cups/model/lw4xl.ppd" -E 2>/dev/null; then
        echo "Warning: Failed to configure printer with DYMO driver"
        return
    fi

    # Set as default printer
    lpadmin -d "$PRINTER_NAME" 2>/dev/null || true

    echo "LabelWriter 4XL configured successfully"
}

# Run auto-configuration in background after CUPS starts
(sleep 10 && configure_labelwriter) &

echo "Starting CUPS..."
exec "$@"
