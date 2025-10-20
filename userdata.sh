#!/bin/bash
apt update
apt install -y apache2

# Get the instance ID using the instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# Install the AWS CLI
apt install -y awscli
echo "Hi from EC2 instance from subnet1"

# Start Apache and enable it on boot
systemctl start apache2
systemctl enable apache2