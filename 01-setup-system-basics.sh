#!/bin/bash
set -e

echo "[SYSTEM] Iniciando configuração base do sistema..."

# --- Personalização do Prompt de Comando ---
echo "[SYSTEM] Configurando PS1..."
cat <<'EOF' > /etc/profile.d/ps1.sh
export PS1='\[\033[0;99m\][\[\033[0;96m\]\u\[\033[0;99m\]@\[\033[0;92m\]\h\[\033[0;99m\]] \[\033[1;38m\]\w \[\033[0;94m\][$(date +%k:%M:%S)]\[\033[0;99m\] \$\[\033[0m\] '
EOF
chmod +x /etc/profile.d/ps1.sh

# --- Aplicação de ajustes finos (sysctl) ---
echo "[SYSTEM] Aplicando ajustes de kernel (sysctl)..."
cat <<'EOF' > /etc/sysctl.d/95-zabbix-proxy-tuning.conf
# ===================================================================
# TUNING PARA ORANGE PI 3B (8GB) - ZABBIX PROXY + DOCKER
# ===================================================================

# --- Gerenciamento de Memória ---
# Reduzido para 64MB. Garante memória atômica para rede sem desperdiçar RAM.
vm.min_free_kbytes = 65536
# Prioriza RAM, mas não proíbe swap totalmente (evita travamentos súbitos).
vm.swappiness = 10
# Mantém informações de arquivos em cache por mais tempo (ótimo para Zabbix/DB).
vm.vfs_cache_pressure = 50

# --- Proteção de I/O (CRUCIAL PARA CARTÃO SD/eMMC) ---
# Força o sistema a gravar no disco mais frequentemente em pequenos lotes
# em vez de travar o sistema tentando gravar 1GB de uma vez.
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10

# --- Rede e Conexões (TCP/BBR) ---
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
# Fila de conexões pendentes (2048 é suficiente para proxy, 4096 é ok).
net.core.somaxconn = 2048
net.ipv4.tcp_max_syn_backlog = 4096

# --- Buffers de TCP (Ajustado para 8GB) ---
# Reduzido o MAX de 16MB para 8MB para evitar OOM (Out of Memory) em picos.
# Formato: min default max
net.ipv4.tcp_rmem = 4096 87380 8388608
net.ipv4.tcp_wmem = 4096 65536 8388608

# --- Portas e Timers ---
# Expande portas efêmeras para o Proxy abrir muitas conexões de saída.
net.ipv4.ip_local_port_range = 1024 65535
# Reutiliza conexões em TIME_WAIT (essencial para Docker/NAT).
net.ipv4.tcp_tw_reuse = 1
# Timeout de FIN mais curto para liberar recursos mais rápido
net.ipv4.tcp_fin_timeout = 15

# --- Sistema ---
fs.file-max = 1000000
kernel.panic = 10
EOF
# Aplicar imediatamente
sysctl --system

# --- Configuração de timezone e NTP ---
echo "[SYSTEM] Configurando timezone e NTP..."
timedatectl set-timezone America/Sao_Paulo
timedatectl set-ntp true

# --- Instalação de dependências essenciais ---
echo "[SYSTEM] Instalando dependências..."
apt-get update -y
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common \
    net-tools \
    iproute2 \
    iputils-ping \
    wget \
    nftables

# --- Instalação de ferramentas VMware (se aplicável) ---
if hostnamectl | grep -qi vmware; then
    echo "[SYSTEM] Ambiente VMware detectado. Instalando open-vm-tools..."
    apt-get -y install open-vm-tools
    systemctl enable --now open-vm-tools
fi

echo "[SYSTEM] Configuração base finalizada."