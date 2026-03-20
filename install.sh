#!/bin/bash
# Установка NVIDIA 390.157 из папки 390.157-15 (Debian-метод)
# Для чистой системы Debian 12/13, Ubuntu 24.04

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${GREEN}[1/7] Проверка исходников...${NC}"
if [ ! -d "390.157-15" ]; then
    echo -e "${RED}Папка 390.157-15 не найдена!${NC}"
    exit 1
fi

echo -e "${GREEN}[2/7] Установка зависимостей для сборки...${NC}"
sudo apt update
sudo apt install -y build-essential dkms devscripts debhelper dh-dkms po-debconf quilt \
    linux-headers-$(uname -r)

echo -e "${GREEN}[3/7] Подготовка исходников (распаковка .run)...${NC}"
cd 390.157-15
for arch in amd64 i386 armhf; do
    if [ -f "$arch/NVIDIA-Linux-*.run" ]; then
        chmod +x $arch/NVIDIA-Linux-*.run
        (cd $arch && ./NVIDIA-Linux-*.run --extract-only --target ../nvidia-source-$arch)
    fi
done

echo -e "${GREEN}[4/7] Применение патчей и сборка пакетов...${NC}"
cp -r debian nvidia-source-amd64/
cd nvidia-source-amd64
export QUILT_PATCHES=debian/patches
quilt push -a || true
dpkg-buildpackage -b -uc -us -d

cd ..

echo -e "${GREEN}[5/7] Установка собранных пакетов...${NC}"
sudo dpkg -i nvidia-legacy-390xx-alternative*.deb
sudo dpkg -i nvidia-legacy-390xx-kernel-support*.deb
sudo dpkg -i libnvidia-legacy-390xx-glcore*.deb
sudo dpkg -i libglx-nvidia-legacy-390xx0*.deb
sudo dpkg -i libgl1-nvidia-legacy-390xx-glx*.deb
sudo dpkg -i libnvidia-legacy-390xx-ml1*.deb
sudo dpkg -i nvidia-legacy-390xx-kernel-dkms*.deb
sudo dpkg -i xserver-xorg-video-nvidia-legacy-390xx*.deb
sudo dpkg -i nvidia-legacy-390xx-smi*.deb

echo -e "${GREEN}[6/7] Исправление зависимостей...${NC}"
sudo apt --fix-broken install -y

echo -e "${GREEN}[7/7] Настройка альтернатив и Xorg...${NC}"
sudo update-alternatives --install /usr/lib/glx glx /usr/lib/nvidia/legacy-390xx 390
sudo update-alternatives --set glx /usr/lib/nvidia/legacy-390xx
sudo update-alternatives --install /usr/lib/nvidia/nvidia nvidia /usr/lib/nvidia/legacy-390xx 390
sudo update-alternatives --set nvidia /usr/lib/nvidia/legacy-390xx

sudo mkdir -p /etc/X11/xorg.conf.d
sudo tee /etc/X11/xorg.conf.d/20-nvidia.conf > /dev/null <<EOF
Section "Device"
    Identifier "NVIDIA"
    Driver "nvidia"
    BusID "PCI:1:0:0"
    Option "AllowEmptyInitialConfiguration" "true"
EndSection
EOF

if [ -d /usr/share/sddm/scripts ]; then
    echo "xrandr --setprovideroutputsource modesetting NVIDIA-0" | sudo tee -a /usr/share/sddm/scripts/Xsetup
    echo "xrandr --auto" | sudo tee -a /usr/share/sddm/scripts/Xsetup
    sudo chmod a+rx /usr/share/sddm/scripts/Xsetup
fi

echo -e "${GREEN}✅ Установка завершена! Перезагрузи систему.${NC}"
