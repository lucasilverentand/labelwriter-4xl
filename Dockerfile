# CUPS print server with DYMO LabelWriter 4XL drivers
# Based on Debian for ARM64 compatibility and printer-driver-dymo package
FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="CUPS with DYMO LabelWriter 4XL"
LABEL org.opencontainers.image.description="CUPS print server with DYMO LabelWriter drivers for network label printing"
LABEL org.opencontainers.image.source="https://github.com/lucasilverentand/labelwriter-4xl"

# Install CUPS and DYMO drivers
RUN apt-get update && apt-get install -y --no-install-recommends \
    cups \
    cups-client \
    cups-bsd \
    printer-driver-dymo \
    avahi-daemon \
    libnss-mdns \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure CUPS for network access
RUN sed -i 's/Listen localhost:631/Listen 0.0.0.0:631/' /etc/cups/cupsd.conf && \
    sed -i 's/<Location \/>/<Location \/>\n  Allow @LOCAL/' /etc/cups/cupsd.conf && \
    sed -i 's/<Location \/admin>/<Location \/admin>\n  Allow @LOCAL/' /etc/cups/cupsd.conf && \
    sed -i 's/<Location \/admin\/conf>/<Location \/admin\/conf>\n  Allow @LOCAL/' /etc/cups/cupsd.conf && \
    echo "ServerAlias *" >> /etc/cups/cupsd.conf && \
    echo "DefaultEncryption Never" >> /etc/cups/cupsd.conf

# Create cups user for admin access
RUN useradd -r -G lpadmin -M cups 2>/dev/null || true

# Expose CUPS port
EXPOSE 631

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Persistent storage for CUPS configuration
VOLUME ["/etc/cups"]

ENTRYPOINT ["/entrypoint.sh"]
CMD ["cupsd", "-f"]
