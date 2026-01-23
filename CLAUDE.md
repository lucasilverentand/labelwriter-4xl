# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker image providing a CUPS print server with DYMO LabelWriter 4XL drivers for network label printing. Based on Debian bookworm-slim for ARM64 compatibility (Raspberry Pi, Apple Silicon) and AMD64 support.

## Build Commands

```bash
# Build locally for current architecture
docker build -t labelwriter-4xl .

# Build multi-arch (requires buildx)
docker buildx build --platform linux/amd64,linux/arm64 -t labelwriter-4xl .

# Run locally for testing
docker run -d --name labelwriter --privileged -p 631:631 \
  -v /dev/bus/usb:/dev/bus/usb \
  -e CUPS_ADMIN_PASSWORD=test \
  labelwriter-4xl
```

## Architecture

The image consists of two main components:

1. **Dockerfile**: Installs CUPS, DYMO drivers (`printer-driver-dymo`), and Avahi. Configures CUPS for network access by modifying `/etc/cups/cupsd.conf` to allow local network connections without encryption.

2. **entrypoint.sh**: Handles runtime configuration:
   - Creates/configures admin user with `CUPS_ADMIN_PASSWORD`
   - Optionally starts Avahi daemon for mDNS discovery
   - Auto-detects and configures LabelWriter 4XL in background (10s delay after CUPS starts)
   - Tries multiple PPD sources: `drv:///sample.drv/dymo.ppd`, `/usr/share/ppd/dymo/lw4xl.ppd`, or `everywhere` driver

## Environment Variables

- `CUPS_ADMIN_USER`: Admin username (default: `admin`)
- `CUPS_ADMIN_PASSWORD`: Admin password (required)
- `ENABLE_AVAHI`: Set to `true` for mDNS printer discovery
- `TZ`: Timezone

## USB Device Info

DYMO vendor ID: `0922`, LabelWriter 4XL device ID: `0020`

## CI/CD

GitHub Actions workflow (`.github/workflows/build.yaml`) builds and pushes multi-arch images to `ghcr.io` on push to main or version tags.
