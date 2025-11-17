# 🌈 SpectrumOS Installation Guide - Laptop

## Phase 1: Preparation (On Arch Linux)

### Step 1: Setup the Repository

```bash
# Run the setup script from the artifact
cd ~
chmod +x setup-spectrumos.sh
./setup-spectrumos.sh
```

### Step 2: Copy All Configuration Files

Save each artifact to its corresponding location in `~/SpectrumOS/`:

```bash
cd ~/SpectrumOS

# Save flake.nix (main flake artifact)
# Save hosts/laptop/default.nix
# Save modules/bootloader.nix
# Save modules/hyprland.nix
# Save modules/sddm.nix
# Save modules/graphics/nvidia.nix
# Save modules/graphics/amd.nix
# Save home/common.nix
# Save home/hyprland/hyprland.nix
# Save home/hyprland/kitty.nix
```

### Step 3: Update Git Email

```bash
cd ~/SpectrumOS
# Edit home/common.nix and change the email
nano home/common.nix
# Change: userEmail = "your-email@example.com";
```

### Step 4: Commit Everything

```bash
git add .
git commit -m "Complete SpectrumOS base configuration"
```

### Step 5: Push to GitHub (Optional but Recommended)

```bash
# Create a new repository on GitHub called "SpectrumOS"
git remote add origin https://github.com/gibranlp/SpectrumOS.git
git branch -M main
git push -u origin main
```

### Step 6: Download NixOS

```bash
cd ~/Downloads
wget https://channels.nixos.org/nixos-24.11/latest-nixos-minimal-x86_64-linux.iso
```

### Step 7: Create Bootable USB

```bash
# Find your USB device (be VERY careful!)
lsblk

# Create bootable USB (replace /dev/sdX with your USB device)
sudo dd if=nixos-minimal-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

---

## Phase 2: Installation (Boot from USB)

### Step 1: Boot NixOS USB

- Reboot laptop
- Enter BIOS/UEFI (usually F2, F12, or DEL)
- Boot from USB
- Select "NixOS Installer"

### Step 2: Connect to WiFi

```bash
# Start wpa_supplicant for WiFi
sudo systemctl start wpa_supplicant

# Connect to WiFi
sudo wpa_cli
> add_network
> set_network 0 ssid "YourWiFiName"
> set_network 0 psk "YourPassword"
> enable_network 0
> quit

# Test connection
ping -c 3 nixos.org
```

### Step 3: Partition Disks

**Check your current partitions:**
```bash
lsblk
```

You mentioned Windows is on another drive, so we'll only touch the Linux drive.

**Assuming your Linux drive is /dev/nvme0n1 (adjust if different):**

```bash
# Use gdisk for GPT partition table
sudo gdisk /dev/nvme0n1

# Delete old Arch partitions:
# d (delete), select partition number, repeat for all Arch partitions

# Create new partitions:
# n (new partition)
# Partition 1: EFI (512MB) - type EF00
# Partition 2: root (rest of space) - type 8300

# w (write changes)
```

**Format partitions:**
```bash
# Format EFI partition (if it doesn't exist from Windows)
sudo mkfs.fat -F 32 /dev/nvme0n1p1

# Format root partition
sudo mkfs.ext4 -L nixos /dev/nvme0n1p2
```

### Step 4: Mount Filesystems

```bash
# Mount root
sudo mount /dev/nvme0n1p2 /mnt

# Create boot directory
sudo mkdir -p /mnt/boot

# Mount EFI
sudo mount /dev/nvme0n1p1 /mnt/boot
```

### Step 5: Generate Initial Configuration

```bash
# Generate hardware config
sudo nixos-generate-config --root /mnt

# This creates:
# /mnt/etc/nixos/configuration.nix
# /mnt/etc/nixos/hardware-configuration.nix
```

### Step 6: Clone SpectrumOS Repository

```bash
# Install git temporarily
nix-shell -p git

# Clone your repo
cd /mnt
sudo mkdir -p /mnt/home/gibranlp
sudo git clone https://github.com/gibranlp/SpectrumOS.git /mnt/home/gibranlp/SpectrumOS

# Or if you didn't push to GitHub, copy from USB:
# Mount your USB with the repo
# sudo cp -r /path/to/SpectrumOS /mnt/home/gibranlp/
```

### Step 7: Copy Hardware Configuration

```bash
# Copy the generated hardware config to our flake
sudo cp /mnt/etc/nixos/hardware-configuration.nix /mnt/home/gibranlp/SpectrumOS/hosts/laptop/
```

### Step 8: Review Hardware Configuration

```bash
# Check if hardware-configuration.nix detected your drives correctly
cat /mnt/home/gibranlp/SpectrumOS/hosts/laptop/hardware-configuration.nix
```

### Step 9: Install NixOS

```bash
# Install with our flake
sudo nixos-install --flake /mnt/home/gibranlp/SpectrumOS#spectrum-laptop

# This will:
# - Download all packages
# - Build the system
# - Install NixOS
# Takes 15-30 minutes depending on internet speed
```

### Step 10: Set Root Password

```bash
# When prompted, set root password
# You'll need this for first boot
```

### Step 11: Set User Password

```bash
# After installation completes, chroot into the system
sudo nixos-enter --root /mnt

# Set your user password
passwd gibranlp

# Exit chroot
exit
```

### Step 12: Reboot

```bash
# Unmount and reboot
sudo umount -R /mnt
reboot
```

---

## Phase 3: First Boot

### Step 1: Login

- Boot into NixOS
- SDDM should appear
- Login as `gibranlp`

### Step 2: Verify Installation

```bash
# Check Hyprland is running
echo $XDG_SESSION_TYPE  # Should say "wayland"

# Check Nvidia
nvidia-smi

# Test terminal
# Super + Enter should open Kitty
```

### Step 3: Fix Ownership

```bash
# Fix SpectrumOS directory ownership
sudo chown -R gibranlp:users ~/SpectrumOS
```

---

## Next Steps

Once you're logged in and everything works:

1. **Test basic functionality:**
   - Super + Return (kitty terminal)
   - Super + D (rofi launcher)
   - Super + Q (close window)

2. **Configure git in the new system:**
   ```bash
   git config --global user.name "gibranlp"
   git config --global user.email "your-email@example.com"
   ```

3. **We'll continue building:**
   - Waybar configuration
   - Rofi theming
   - Pywal integration
   - Creative tools (GIMP, Kdenlive)
   - SDDM custom theme

---

## Troubleshooting

**If boot fails:**
- Boot back into USB
- Mount system: `sudo mount /dev/nvme0n1p2 /mnt && sudo mount /dev/nvme0n1p1 /mnt/boot`
- Check logs: `sudo nixos-enter --root /mnt` then `journalctl -b`

**If Nvidia issues:**
- Boot into recovery
- Edit: `/mnt/home/gibranlp/SpectrumOS/modules/graphics/nvidia.nix`
- Try setting `open = false;` or `open = true;`

**If network issues:**
- Use ethernet cable initially
- Fix WiFi after first boot

---

## Important Notes

- **Keep Windows safe:** Windows is on a separate drive, don't touch it during partitioning
- **GRUB still available:** We can dual-boot, systemd-boot will show NixOS, access Windows from BIOS
- **Backups:** Your Arch data is being replaced, make sure you have backups
- **Internet required:** NixOS downloads packages during installation

Ready to start? Let me know when you want to begin! 🚀