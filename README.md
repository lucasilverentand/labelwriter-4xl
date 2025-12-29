# DYMO LabelWriter 4XL Print Server

A Docker image running CUPS with DYMO LabelWriter 4XL drivers, designed for network label printing in Kubernetes environments.

## Features

- **Multi-architecture support**: AMD64 and ARM64 (Raspberry Pi, Apple Silicon)
- **DYMO drivers included**: `printer-driver-dymo` package with PPD files for LabelWriter 4XL
- **Auto-configuration**: Automatically detects and configures the printer on startup
- **Network printing**: CUPS web interface and IPP printing on port 631
- **Kubernetes ready**: Designed for use with USB passthrough in privileged containers

## Quick Start

### Docker

```bash
docker run -d \
  --name labelwriter \
  --privileged \
  -p 631:631 \
  -v /dev/bus/usb:/dev/bus/usb \
  -v cups-config:/etc/cups \
  -e CUPS_ADMIN_USER=admin \
  -e CUPS_ADMIN_PASSWORD=changeme \
  ghcr.io/lucasilverentand/labelwriter-4xl:latest
```

### Docker Compose

```yaml
services:
  labelwriter:
    image: ghcr.io/lucasilverentand/labelwriter-4xl:latest
    privileged: true
    ports:
      - "631:631"
    volumes:
      - /dev/bus/usb:/dev/bus/usb
      - cups-config:/etc/cups
    environment:
      - TZ=Europe/Amsterdam
      - CUPS_ADMIN_USER=admin
      - CUPS_ADMIN_PASSWORD=changeme

volumes:
  cups-config:
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CUPS_ADMIN_USER` | Username for CUPS admin access | `admin` |
| `CUPS_ADMIN_PASSWORD` | Password for CUPS admin access | (required) |
| `TZ` | Timezone | `UTC` |
| `ENABLE_AVAHI` | Enable Avahi for mDNS discovery | `false` |

## Accessing the Printer

### Web Interface

Open `http://localhost:631` in your browser to access the CUPS administration interface.

### Network Printing

Add the printer on your devices using:

- **IPP URL**: `ipp://your-server:631/printers/labelwriter-4xl`
- **macOS/iOS**: Should auto-discover via Bonjour (if Avahi enabled)
- **Windows**: Add printer via `http://your-server:631/printers/labelwriter-4xl`

## Kubernetes Deployment

This image is designed to work with Node Feature Discovery (NFD) for automatic scheduling to nodes with the printer connected.

### NFD Rule

```yaml
apiVersion: nfd.k8s-sigs.io/v1alpha1
kind: NodeFeatureRule
metadata:
  name: labelwriter-4xl-detection
spec:
  rules:
    - name: 'printer.dymo.labelwriter-4xl'
      labels:
        'labelwriter-4xl': 'true'
      matchFeatures:
        - feature: usb.device
          matchExpressions:
            vendor: { op: In, value: ['0922'] }
            device: { op: In, value: ['0020'] }
```

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: labelwriter-4xl
spec:
  replicas: 1
  selector:
    matchLabels:
      app: labelwriter-4xl
  template:
    metadata:
      labels:
        app: labelwriter-4xl
    spec:
      nodeSelector:
        labelwriter-4xl: 'true'
      containers:
        - name: cups
          image: ghcr.io/lucasilverentand/labelwriter-4xl:latest
          securityContext:
            privileged: true
          ports:
            - containerPort: 631
          volumeMounts:
            - name: usb
              mountPath: /dev/bus/usb
            - name: config
              mountPath: /etc/cups
          env:
            - name: CUPS_ADMIN_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: labelwriter-secrets
                  key: password
      volumes:
        - name: usb
          hostPath:
            path: /dev/bus/usb
        - name: config
          persistentVolumeClaim:
            claimName: labelwriter-config
```

## Supported Printers

While optimized for the LabelWriter 4XL, this image includes drivers for all DYMO LabelWriter models:

- LabelWriter 4XL
- LabelWriter 450 / 450 Turbo / 450 Twin Turbo / 450 DUO
- LabelWriter 400 / 400 Turbo
- LabelWriter 330 / 330 Turbo
- LabelWriter 320 / 315 / 310 / 300

## Troubleshooting

### Printer not detected

1. Ensure the container has access to USB devices (`--privileged` or proper device mounts)
2. Check if the printer is visible: `lsusb | grep -i dymo`
3. Verify USB vendor/product ID: DYMO uses vendor `0922`, LabelWriter 4XL is device `0020`

### Cannot print

1. Check CUPS logs: `docker logs labelwriter`
2. Verify printer status in CUPS web UI at `/printers/`
3. Ensure the printer is enabled and accepting jobs

### Driver issues

The image uses `printer-driver-dymo` from Debian repositories. If you encounter driver issues, the PPD files are located at `/usr/share/ppd/dymo/`.

## License

MIT
