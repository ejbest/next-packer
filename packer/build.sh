#!/bin/bash
# Builds Ubuntu 24.04 (Noble) cloud image pre-baked with Docker + Libvirt + QEMU.
# Uploads result to MAAS as custom/ubuntu-24.04-libvirt-host.
# Run once per image update. Do NOT run as part of the routine rebuild pipeline.
set -e

echo "==========================================================="
echo " MAAS Golden Image Builder — Ubuntu 24.04 (Noble)          "
echo " Pre-installing Docker, Libvirt, and QEMU                  "
echo "==========================================================="

echo "[1/5] Installing dependencies and Packer..."
sudo apt-get update
sudo apt-get install -y git qemu-system qemu-utils ovmf cloud-image-utils curl libnbd-bin nbdkit fuse2fs wget gpg lsb-release

wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
sudo apt-get update && sudo apt-get install -y packer

echo "[2/5] Cloning Canonical packer-maas repository..."
rm -rf packer-maas
git clone https://github.com/canonical/packer-maas.git
cd packer-maas/ubuntu

# Speed up build: more CPUs/memory, virtio-rng for faster SSH key generation
sed -i 's/cpus           = 2/cpus           = 4/g' ubuntu-cloudimg.pkr.hcl
sed -i 's/memory         = 2048/memory         = 4096/g' ubuntu-cloudimg.pkr.hcl
sed -i 's/\["-device", "virtio-gpu-pci"\],/\["-device", "virtio-gpu-pci"\],\n    \["-device", "virtio-rng-pci"\],/g' ubuntu-cloudimg.pkr.hcl
sed -i 's/>= 1.11.0/>= 1.10.0/g' variables.pkr.hcl

echo "[3/5] Creating customize script..."
cat << 'EOF' > customize.sh
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
    curl wget gnupg ca-certificates apt-transport-https \
    libguestfs-tools genisoimage ovmf zip unzip \
    cloud-image-utils efibootmgr ipmitool \
    qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils \
    virtinst cpu-checker qemu-efi-aarch64 qemu-system-arm \
    docker.io docker-compose-v2 \
    linux-generic grub-efi-amd64
EOF
chmod +x customize.sh

echo "[4/5] Building image via Packer (10-15 minutes)..."
make custom-cloudimg.tar.gz SERIES=noble CUSTOMIZE=$(pwd)/customize.sh

echo "[5/5] Uploading to MAAS as custom/ubuntu-24.04-libvirt-host..."
MAAS_API_URL="${MAAS_API_URL:?MAAS_API_URL required}"
MAAS_API_KEY="${MAAS_API_KEY:?MAAS_API_KEY required}"

curl -s -X POST "${MAAS_API_URL}/api/2.0/boot-resources/" \
    -H "Authorization: OAuth ${MAAS_API_KEY}" \
    -F "name=custom/ubuntu-24.04-libvirt-host" \
    -F "title=Ubuntu 24.04 (Noble) - Libvirt/Docker Pre-baked" \
    -F "architecture=amd64/generic" \
    -F "filetype=tgz" \
    -F "content=@custom-cloudimg.tar.gz"

echo "==========================================================="
echo " DONE — image uploaded as custom/ubuntu-24.04-libvirt-host "
echo "==========================================================="
