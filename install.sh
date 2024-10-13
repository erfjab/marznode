#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME="marznode"
SCRIPT_VERSION="v0.1.0"
SCRIPT_URL="https://raw.githubusercontent.com/erfjab/marznode/main/install.sh"
INSTALL_DIR="/var/lib/marznode"
LOG_FILE="${INSTALL_DIR}/marznode.log"
COMPOSE_FILE="${INSTALL_DIR}/docker-compose.yml"
GITHUB_REPO="https://github.com/marzneshin/marznode.git"
GITHUB_API="https://api.github.com/repos/XTLS/Xray-core/releases"

declare -r -A COLORS=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[0;33m'
    [BLUE]='\033[0;34m'
    [PURPLE]='\033[0;35m'
    [CYAN]='\033[0;36m'
    [RESET]='\033[0m'
)

DEPENDENCIES=(
    "docker"
    "docker-compose"
    "curl"
    "wget"
    "unzip"
    "git"
    "jq"
)

log() { echo -e "${COLORS[BLUE]}[INFO]${COLORS[RESET]} $*"; }
warn() { echo -e "${COLORS[YELLOW]}[WARN]${COLORS[RESET]} $*" >&2; }
error() { echo -e "${COLORS[RED]}[ERROR]${COLORS[RESET]} $*" >&2; exit 1; }
success() { echo -e "${COLORS[GREEN]}[SUCCESS]${COLORS[RESET]} $*"; }

check_root() {
    [[ $EUID -eq 0 ]] || error "This script must be run as root"
}

show_version() {
    log "MarzNode Script Version: $SCRIPT_VERSION"
}

update_script() {
    local script_path="/usr/local/bin/$SCRIPT_NAME"
    
    if [[ -f "$script_path" ]]; then
        log "Updating the script..."
        curl -o "$script_path" $SCRIPT_URL
        chmod +x "$script_path"
        success "Script updated to the latest version!"
        echo "Current version: $SCRIPT_VERSION"
    else
        warn "Script is not installed. Use 'install-script' command to install the script first."
    fi
}


check_dependencies() {
    local missing_deps=()
    for dep in "${DEPENDENCIES[@]}"; do
        command -v "$dep" &>/dev/null || missing_deps+=("$dep")
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "Installing missing dependencies: ${missing_deps[*]}"
        apt update && apt install -y "${missing_deps[@]}" || warn "Some dependencies might have failed to install."
    fi

    command -v docker &>/dev/null || { log "Installing Docker..."; curl -fsSL https://get.docker.com | sh; }
    command -v docker-compose &>/dev/null || {
        log "Installing Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    }
}

is_installed() { [[ -d "$INSTALL_DIR" && -f "$COMPOSE_FILE" ]]; }
is_running() { docker ps | grep -q "marznode"; }

create_directories() {
    mkdir -p "$INSTALL_DIR" "${INSTALL_DIR}/data"
}

get_certificate() {
    log "Please paste the Marznode certificate from the Marzneshin panel (press Ctrl+D when finished):"
    cat > "${INSTALL_DIR}/client.pem"
    echo
    success "Certificate saved to ${INSTALL_DIR}/client.pem"
}

show_xray_versions() {
    log "Available Xray versions:"
    curl -s "$GITHUB_API" | jq -r '.[0:10] | .[] | .tag_name' | nl
}

select_xray_version() {
    show_xray_versions
    local choice
    read -p "Select Xray version (1-10): " choice
    local selected_version=$(curl -s "$GITHUB_API" | jq -r ".[0:10] | .[$((choice-1))] | .tag_name")

    echo "Selected Xray version: $selected_version"
    while true; do
        read -p "Confirm selection? (Y/n): " confirm
        if [[ $confirm =~ ^[Yy]$ ]] || [[ -z $confirm ]]; then
            download_xray_core "$selected_version"
            return 0
        elif [[ $confirm =~ ^[Nn]$ ]]; then
            echo "Selection cancelled. Please choose again."
            return 1
        else
            echo "Invalid input. Please enter Y or n."
        fi
    done
}


download_xray_core() {
    local version="$1"
    case "$(uname -m)" in
        'i386' | 'i686') arch='32' ;;
        'amd64' | 'x86_64') arch='64' ;;
        'armv5tel') arch='arm32-v5' ;;
        'armv6l')
        arch='arm32-v6'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || arch='arm32-v5'
        ;;
        'armv7' | 'armv7l')
        arch='arm32-v7a'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || arch='arm32-v5'
        ;;
        'armv8' | 'aarch64') arch='arm64-v8a' ;;
        'mips') arch='mips32' ;;
        'mipsle') arch='mips32le' ;;
        'mips64')
        arch='mips64'
        lscpu | grep -q "Little Endian" && arch='mips64le'
        ;;
        'mips64le') arch='mips64le' ;;
        'ppc64') arch='ppc64' ;;
        'ppc64le') arch='ppc64le' ;;
        'riscv64') arch='riscv64' ;;
        's390x') arch='s390x' ;;
        *)
        print_error "Error: The architecture is not supported."
        exit 1
        ;;
    esac
    local xray_filename="Xray-linux-${arch}.zip"
    local download_url="https://github.com/XTLS/Xray-core/releases/download/${version}/${xray_filename}"

    wget -q --show-progress "$download_url" -O "/tmp/${xray_filename}"
    unzip -o "/tmp/${xray_filename}" -d "${INSTALL_DIR}"
    rm "/tmp/${xray_filename}"

    chmod +x "${INSTALL_DIR}/xray"

    wget -q --show-progress "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" -O "${INSTALL_DIR}/data/geoip.dat"
    wget -q --show-progress "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat" -O "${INSTALL_DIR}/data/geosite.dat"

    success "Xray-core ${version} installed successfully."
}

setup_docker_compose() {
    local port="${1:-5566}"
    cat > "$COMPOSE_FILE" <<EOF
services:
  marznode:
    image: dawsh/marznode:latest
    restart: always
    network_mode: host
    environment:
      SERVICE_PORT: "$port"
      XRAY_EXECUTABLE_PATH: "/var/lib/marznode/xray"
      XRAY_ASSETS_PATH: "/var/lib/marznode/data"
      XRAY_CONFIG_PATH: "/var/lib/marznode/xray_config.json"
      SSL_CLIENT_CERT_FILE: "/var/lib/marznode/client.pem"
      SSL_KEY_FILE: "./server.key"
      SSL_CERT_FILE: "./server.cert"
    volumes:
      - ${INSTALL_DIR}:/var/lib/marznode
EOF
    success "Docker Compose file created at $COMPOSE_FILE"
}

install_marznode() {
    if is_installed; then
        warn "MarzNode is already installed. Removing previous installation..."
        uninstall_marznode
    fi

    check_dependencies
    create_directories

    echo
    get_certificate
    echo

    local port
    while true; do
        read -p "Enter the service port (default: 5566): " port
        port=${port:-5566}
        
        if ! ss -tuln | grep -q ":$port "; then
            break
        else
            warn "Port $port is already in use. Please choose a different port."
        fi
    done
    echo

    if [ -d "${INSTALL_DIR}/repo" ]; then
        rm -rf "${INSTALL_DIR}/repo"
    fi
    git clone "$GITHUB_REPO" "${INSTALL_DIR}/repo"
    cp "${INSTALL_DIR}/repo/xray_config.json" "${INSTALL_DIR}/xray_config.json"
    
    while true; do
        if select_xray_version; then
            break
        fi
    done
        
    setup_docker_compose "$port"
    
    docker-compose -f "$COMPOSE_FILE" up -d
    
    if command -v ufw &> /dev/null; then
        ufw allow "$port"
        log "Firewall rule added for port $port"
    else
        warn "ufw not found. Please manually open port $port in your firewall."
    fi
    
    success "MarzNode installed successfully!"
}

uninstall_marznode() {
    log "Uninstalling MarzNode..."
    if [[ -f "$COMPOSE_FILE" ]]; then
        docker-compose -f "$COMPOSE_FILE" down --remove-orphans
    fi
    rm -rf "$INSTALL_DIR"
    success "MarzNode uninstalled successfully"
}

manage_service() {
    if ! is_installed; then
        error "MarzNode is not installed. Please install it first."
        return 1
    fi

    local action=$1
    case "$action" in
        start)
            if is_running; then
                warn "MarzNode is already running."
            else
                log "Starting MarzNode..."
                docker-compose -f "$COMPOSE_FILE" up -d
                success "MarzNode started"
            fi
            ;;
        stop)
            if ! is_running; then
                warn "MarzNode is not running."
            else
                log "Stopping MarzNode..."
                docker-compose -f "$COMPOSE_FILE" down
                success "MarzNode stopped"
            fi
            ;;
        restart)
            log "Restarting MarzNode..."
            docker-compose -f "$COMPOSE_FILE" down
            docker-compose -f "$COMPOSE_FILE" up -d
            success "MarzNode restarted"
            ;;
    esac
}

show_status() {
    if ! is_installed; then
        error "Status: Not Installed"
        return 1
    fi

    if is_running; then
        success "Status: Up and Running [uptime: $(docker ps --filter "name=marznode_marznode_1" --format "{{.Status}}")]"        
    else
        error "Status: Stopped"
    fi
}


show_logs() {
    log "Showing MarzNode logs (press Ctrl+C to exit):"
    docker-compose -f "$COMPOSE_FILE" logs --tail=100 -f
}

install_script() {
    local script_path="/usr/local/bin/$SCRIPT_NAME"
    
    cp "$(realpath "$0")" "$script_path"
    chmod +x "$script_path"
    success "Script installed successfully. You can now use '$SCRIPT_NAME' command from anywhere."
}

uninstall_script() {
    local script_path="/usr/local/bin/$SCRIPT_NAME"
    if [[ -f "$script_path" ]]; then
        rm "$script_path"
        success "Script uninstalled successfully from $script_path"
    else
        warn "Script not found at $script_path. Nothing to uninstall."
    fi
}

print_help() {
    echo
    echo "Usage: $SCRIPT_NAME <command>"
    echo
    echo "Commands [$SCRIPT_VERSION]:"
    echo "  install          Install MarzNode"
    echo "  uninstall        Uninstall MarzNode"
    echo "  update           Update MarzNode to the latest version"
    echo "  start            Start MarzNode service"
    echo "  stop             Stop MarzNode service"
    echo "  restart          Restart MarzNode service"
    echo "  status           Show MarzNode and Xray status"
    echo "  logs             Show MarzNode logs"
    echo "  version          Show script version"
    echo "  install-script   Install this script to /usr/local/bin"
    echo "  uninstall-script Uninstall this script from /usr/local/bin"
    echo "  update-script    Update this script to the latest version"
    echo "  help             Show this help message"
    echo
}


main() {
    check_root

    if [[ $# -eq 0 ]]; then
        print_help
        exit 0
    fi

    case "$1" in
        install)         install_marznode ;;
        uninstall)       uninstall_marznode ;;
        update)          update_marznode ;;
        start|stop|restart) manage_service "$1" ;;
        status)          show_status ;;
        logs|log)            show_logs ;;
        version)         show_version ;;
        install-script)  install_script ;;
        uninstall-script) uninstall_script ;;
        update-script)   update_script ;;
        help|*)          print_help ;;
    esac
}

main "$@"