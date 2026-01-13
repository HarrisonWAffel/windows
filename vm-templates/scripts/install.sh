#!/bin/bash

# sets up required tools for creating vagrant boxes with packer
set -e
echo "==> Installing required tools for Vagrant box creation..."
# Install Packer
if ! command -v packer &> /dev/null; then
    echo "Packer not found, installing..."
    # Download and install Packer (example for Linux x86_64)
    PACKER_VERSION="1.9.2"
    wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip
    unzip packer_${PACKER_VERSION}_linux_amd64.zip
    sudo mv packer /usr/local/bin/
    rm packer_${PACKER_VERSION}_linux_amd64.zip
else
    echo "Packer is already installed."
fi
# Install Vagrant
if ! command -v vagrant &> /dev/null; then
    echo "Vagrant not found, installing..."
    # Download and install Vagrant (example for Linux x86_64)
    VAGRANT_VERSION="2.3.10"
    wget https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_x86_64.deb
    sudo dpkg -i vagrant_${VAGRANT_VERSION}_x86_64.deb
    rm vagrant_${VAGRANT_VERSION}_x86_64.deb
else
    echo "Vagrant is already installed."
fi
echo "==> Installation of required tools completed."

# install virtual box and vm tooling
sudo apt-get install virtualbox virtualbox-ext-pack mkisofs -y

