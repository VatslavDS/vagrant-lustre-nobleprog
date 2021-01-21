#!/bin/bash

####################################################
# Install Lustre Kernel Modules and Setup Filesystem
####################################################

# Install modules into the now running lustre kernel
yum -y --nogpgcheck --enablerepo=lustre-server install \
  kmod-lustre \
  kmod-lustre-osd-ldiskfs \
  lustre-osd-ldiskfs-mount \
  lustre \
  lustre-resource-agents

# Enable and start lustre & lnet
systemctl enable lustre
systemctl start lustre
systemctl enable lnet
systemctl start lnet

# Setup our lnet network

if ! lnetctl ping master; then
    lnetctl net add --net tcp0 --if eth1
    lnetctl export > /etc/lnet.conf
fi

# Format the lustre volumes - don't try if they are mounted :-) (re-provision)
if ! mountpoint -q /mgs; then
    mkfs.lustre --reformat --fsname=lustre1 --mgs /dev/sdc
fi
if ! mountpoint -q /mdt; then
    mkfs.lustre --reformat --fsname=lustre1 --mgsnode=10.0.2.15@tcp0 --mdt --index=0 /dev/sdf
fi
if ! mountpoint -q /ost; then
    mkfs.lustre --reformat --mgsnode=10.0.2.15@tcp0 --fsname=lustre1 --ost --index=0 /dev/sdg
fi

# Setup mounts & mount them
mkdir -p /mgs /mdt /ost
if ! grep -q "mgs" /etc/fstab; then
    echo "/dev/sdc        /mgs         lustre  defaults_netdev 0 0" >> /etc/fstab
fi
if ! grep -q "mdt" /etc/fstab; then
    echo "/dev/sdf        /mdt         lustre  defaults_netdev 0 0" >> /etc/fstab
fi
if ! grep -q "ost" /etc/fstab; then
    echo "/dev/sdg        /ost         lustre  defaults_netdev 0 0" >> /etc/fstab
fi
if ! mountpoint -q /mgs; then
    mount /mgs
fi
if ! mountpoint -q /mdt; then
    mount /mdt
fi
if ! mountpoint -q /ost; then
    mount /ost
fi

# Mount the filesystem to our own host
mkdir -p /lustre
if ! grep -q "/lustre" /etc/fstab; then
    echo "10.0.2.15@tcp0:/lustre1        /lustre         lustre  defaults_netdev 0 0" >> /etc/fstab
fi

if ! mountpoint -q /lustre; then
    mount /lustre
fi

# Make perms wide open on it
chmod 777 /lustre