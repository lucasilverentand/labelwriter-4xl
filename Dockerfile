# CUPS print server with DYMO LabelWriter 4XL drivers
# Based on Debian for ARM64 compatibility and printer-driver-dymo package
FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="CUPS with DYMO LabelWriter 4XL"
LABEL org.opencontainers.image.description="CUPS print server with DYMO LabelWriter drivers for network label printing"
LABEL org.opencontainers.image.source="https://github.com/lucasilverentand/labelwriter-4xl"

# Install CUPS, DYMO drivers, and AirPrint support
RUN apt-get update && apt-get install -y --no-install-recommends \
    cups \
    cups-client \
    cups-bsd \
    cups-filters \
    printer-driver-dymo \
    avahi-daemon \
    libnss-mdns \
    openssl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure CUPS for network access and AirPrint
RUN sed -i 's/Listen localhost:631/Listen 0.0.0.0:631/' /etc/cups/cupsd.conf && \
    sed -i 's/<Location \/>/<Location \/>\n  Allow all/' /etc/cups/cupsd.conf && \
    sed -i 's/<Location \/admin>/<Location \/admin>\n  Allow all/' /etc/cups/cupsd.conf && \
    sed -i 's/<Location \/admin\/conf>/<Location \/admin\/conf>\n  Allow all/' /etc/cups/cupsd.conf && \
    sed -i 's/Order allow,deny/Order deny,allow/' /etc/cups/cupsd.conf && \
    echo "ServerAlias *" >> /etc/cups/cupsd.conf && \
    echo "DefaultEncryption Never" >> /etc/cups/cupsd.conf && \
    echo "Browsing On" >> /etc/cups/cupsd.conf && \
    echo "WebInterface Yes" >> /etc/cups/cupsd.conf && \
    echo "DefaultShared Yes" >> /etc/cups/cupsd.conf

# Expose CUPS port
EXPOSE 631

# Copy custom LabelWriter 4XL PPD with comprehensive label sizes
COPY lw4xl.ppd /usr/share/ppd/dymo/lw4xl.ppd

# Copy entrypoint script
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# Persistent storage for CUPS configuration
VOLUME ["/etc/cups"]

ENTRYPOINT ["/entrypoint.sh"]
CMD ["cupsd", "-f"]
