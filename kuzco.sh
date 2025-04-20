#!/bin/bash

echo "=============================================="
echo "  _  __                    ___           _        _ _         "
echo " | |/ /   _ _____  _____  |_ _|_ __  ___| |_ __ _| | | ___ _ __"
echo " | ' / | | |_  / |/ / _ \  | || '_ \/ __| __/ _\` | | |/ _ \ '__|"
echo " | . \ |_| |/ /|   < (_) | | || | | \__ \ || (_| | | |  __/ |   "
echo " |_|\_\__,_/___|_|\_\___/ |___|_| |_|___/\__\__,_|_|_|\___|_|   "
echo ""
echo "==============================================="
echo " WINGFO Kuzco & ViKey Inference Auto Installer"
echo "==============================================="

is_port_available() {
    port=$1
    if nc -z 127.0.0.1 "$port" >/dev/null 2>&1; then
        return 1
    else
        return 0
    fi
}

find_available_port() {
    for port in $(seq $1 $2); do
        if is_port_available "$port"; then
            echo "$port"
            return 0
        fi
    done
    return 1
}

show_used_ports() {
    echo "Currently used ports (TCP):"
    echo "------------------------"
    ss -tuln | grep LISTEN | awk '{print $5}' | awk -F: '{print $NF}' | sort -n | uniq
    echo "------------------------"
}

if ! command -v nc &> /dev/null; then
    echo "Installing netcat for port checking..."
    sudo apt-get install -y netcat
fi

echo "=== Updating system ==="
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y

if ! command -v docker &> /dev/null; then
    echo "=== Docker not installed, installing Docker ==="
    sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update -y && sudo apt upgrade -y
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
    sudo systemctl status docker
else
    echo "=== Docker already installed, proceeding to next step ==="
fi

echo "=== Installing ViKey Inference ==="
cd ~
git clone https://github.com/direkturcrypto/vikey-inference
cd vikey-inference

show_used_ports

echo "=== ViKey Inference Configuration ==="
read -p "Enter your VIKEY_API_KEY: " vikey_api_key

suggested_port=$(find_available_port 10000 20000)
echo "Recommended available port: $suggested_port"
read -p "Enter custom port for ViKey Inference [default: $suggested_port]: " vikey_port
vikey_port=${vikey_port:-$suggested_port}

if ! is_port_available "$vikey_port"; then
    echo "Warning: Port $vikey_port is already in use."
    read -p "Would you like to find an available port automatically? (y/n): " auto_port
    if [[ "$auto_port" == "y" ]]; then
        suggested_port=$(find_available_port 10000 20000)
        if [[ -n "$suggested_port" ]]; then
            echo "Found available port: $suggested_port"
            read -p "Use this port? (y/n): " use_suggested
            if [[ "$use_suggested" == "y" ]]; then
                vikey_port=$suggested_port
            else
                read -p "Please specify another port: " vikey_port
                while ! is_port_available "$vikey_port"; do
                    echo "Port $vikey_port is still in use. Please try another."
                    read -p "Enter a different port: " vikey_port
                done
            fi
        else
            echo "Could not find an available port in range 10000-20000."
            exit 1
        fi
    else
        read -p "Please specify another port: " vikey_port
        while ! is_port_available "$vikey_port"; do
            echo "Port $vikey_port is still in use. Please try another."
            read -p "Enter a different port: " vikey_port
        done
    fi
fi

echo "Using port $vikey_port for ViKey Inference."

echo "VIKEY_API_KEY=$vikey_api_key" > .env
echo "NODE_PORT=$vikey_port" >> .env

chmod +x vikey-inference-linux
echo "=== Running ViKey Inference in background on port $vikey_port ==="
nohup ./vikey-inference-linux > vikey.log &

echo "=== Installing Kuzco Node ==="
cd ~
git clone https://github.com/direkturcrypto/kuzco-installer-docker
cd kuzco-installer-docker/kuzco-main

read -p "Enter KUZCO_WORKER from Kuzco dashboard: " kuzco_worker
read -p "Enter KUZCO_CODE from Kuzco dashboard: " kuzco_code

VPS_IP=$(curl -s ifconfig.me)
echo "=== Detected VPS IP: $VPS_IP ==="

echo "=== Updating nginx configuration ==="
cat > nginx.conf << EOL
server {
    listen $vikey_port; # Custom port for exposure
    server_name _;

    location / {
        proxy_pass http://$VPS_IP:$vikey_port;
        proxy_buffering off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

echo "=== Updating docker-compose.yml configuration ==="
sed -i "s|KUZCO_WORKER: \"YOUR_WORKER_ID\"|KUZCO_WORKER: \"$kuzco_worker\"|g" docker-compose.yml
sed -i "s|KUZCO_CODE: \"YOUR_WORKER_CODE\"|KUZCO_CODE: \"$kuzco_code\"|g" docker-compose.yml

echo "=== Running Kuzco Node ==="
docker-compose up -d --build

echo "=== Creating ViKey manager script ==="
cat > ~/vikey-manager.sh << 'EOL'
#!/bin/bash

case "$1" in
    start)
        echo "Starting ViKey Inference..."
        cd ~/vikey-inference
        nohup ./vikey-inference-linux > vikey.log &
        echo "ViKey Inference started"
        ;;
    stop)
        echo "Stopping ViKey Inference..."
        pkill -f vikey-inference-linux
        echo "ViKey Inference stopped"
        ;;
    status)
        if pgrep -f vikey-inference-linux > /dev/null; then
            echo "ViKey Inference is running"
            echo "Process info:"
            ps aux | grep vikey-inference-linux | grep -v grep
        else
            echo "ViKey Inference is not running"
        fi
        ;;
    restart)
        echo "Restarting ViKey Inference..."
        pkill -f vikey-inference-linux
        sleep 2
        cd ~/vikey-inference
        nohup ./vikey-inference-linux > vikey.log &
        echo "ViKey Inference restarted"
        ;;
    ports)
        echo "Checking used ports..."
        ss -tuln | grep LISTEN
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart|ports}"
        exit 1
        ;;
esac
exit 0
EOL

chmod +x ~/vikey-manager.sh

echo "=============================================="
echo "=== Installation complete! ==="
echo "ViKey Inference running on port: $vikey_port"
echo "VPS IP: $VPS_IP"
echo ""
echo "To check Kuzco Worker logs: docker-compose logs -f --tail 100"
echo "To check ViKey Inference logs: cd ~/vikey-inference && tail -f vikey.log"
echo ""
echo "To manage ViKey Inference:"
echo "  Start:   ~/vikey-manager.sh start"
echo "  Stop:    ~/vikey-manager.sh stop"
echo "  Status:  ~/vikey-manager.sh status"
echo "  Restart: ~/vikey-manager.sh restart"
echo "  Ports:   ~/vikey-manager.sh ports"
echo "=============================================="