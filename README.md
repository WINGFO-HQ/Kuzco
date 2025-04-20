# Kuzco & ViKey Inference Auto Installer

This script automates the installation and configuration process for Kuzco Node and ViKey Inference on your VPS.

## Overview

The Kuzco & ViKey Inference Auto Installer simplifies the deployment of Kuzco nodes by automatically setting up all required components, detecting available ports, and configuring the necessary services.

## Prerequisites

- Ubuntu/Debian-based VPS
- Sufficient funds in your [ViKey](https://vikey.ai/) account
- A registered account on [Kuzco](https://inference.supply) with Worker ID and Code
- RAM: 2GB
- OS: Ubuntu (20.04 / 22.04)

## Features

- Automatic system update and package installation
- Docker installation (if not already installed)
- ViKey Inference setup with automatic port detection
- Kuzco Node configuration and deployment
- Convenient management script for ViKey services

## Quick Installation

You can install the Kuzco node using either curl or wget. Choose one of the following methods:

### Using curl

```bash
curl -L https://raw.githubusercontent.com/WINGFO-HQ/Kuzco/refs/heads/main/kuzco.sh -o kuzco.sh && chmod +x kuzco.sh && ./kuzco.sh
```

### Using wget

```bash
wget https://raw.githubusercontent.com/WINGFO-HQ/Kuzco/refs/heads/main/kuzco.sh && chmod +x kuzco.sh && ./kuzco.sh
```

4. Follow the prompts to enter:
   - Your ViKey API key (from [ViKey](https://vikey.ai/))
   - Preferred port (or accept the suggested available port)
   - Your Kuzco Worker ID and Code (from [Kuzco](https://inference.supply) dashboard)

## Post-Installation

After successful installation, you can manage your ViKey Inference service using the provided management script:

```bash
# View service status
~/vikey-manager.sh status

# Stop the service
~/vikey-manager.sh stop

# Start the service
~/vikey-manager.sh start

# Restart the service
~/vikey-manager.sh restart

# Check used ports
~/vikey-manager.sh ports
```

## Checking Logs

To check service logs:

```bash
# Kuzco Worker logs
cd ~/kuzco-installer-docker/kuzco-main
docker-compose logs -f --tail 100

# ViKey Inference logs
cd ~/vikey-inference
tail -f vikey.log
```

## Important Notes

- Ensure you have sufficient funds in your ViKey account to handle API requests
- The script automatically detects and configures available ports to avoid conflicts
- Check your Kuzco dashboard regularly to monitor worker status and earnings

## Troubleshooting

If you encounter issues:

1. Verify your ViKey API key is correct and has sufficient balance
2. Ensure your Kuzco Worker ID and Code are entered correctly
3. Check logs for specific error messages
4. Try restarting the ViKey service using the management script

## Disclaimer

This script is provided as-is. Always backup your data before running installation scripts on production systems.
