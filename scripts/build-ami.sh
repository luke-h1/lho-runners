#!/bin/bash

# ======================
# This script builds the GitHub Runner Ubuntu AMI using Packer and Terraform.
# It fetches the VPC configuration from Terraform and uses it to build the AMI 
# and associates it with the correct security group and subnet.
# Make sure to run this script *AFTER* the VPC has been created.
# ======================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Building GitHub Runner AMI with Terraform VPC configuration${NC}"

cd terraform

if [ ! -d ".terraform" ]; then
    echo -e "${RED}Error: Terraform not initialized. Run 'terraform init' first.${NC}"
    exit 1
fi

echo -e "${YELLOW}Fetching VPC configuration from Terraform...${NC}"

PACKER_CONFIG=$(terraform output -json packer_config)

REGION=$(echo $PACKER_CONFIG | jq -r '.region')
SUBNET_ID=$(echo $PACKER_CONFIG | jq -r '.subnet_id')
SECURITY_GROUP_ID=$(echo $PACKER_CONFIG | jq -r '.security_group_id')
ASSOCIATE_PUBLIC_IP=$(echo $PACKER_CONFIG | jq -r '.associate_public_ip_address')

echo -e "${GREEN}Configuration:${NC}"
echo "  Region: $REGION"
echo "  Subnet: $SUBNET_ID"
echo "  Security Group: $SECURITY_GROUP_ID"
echo "  Associate Public IP: $ASSOCIATE_PUBLIC_IP"

cd images

if ! command -v packer &> /dev/null; then
    echo -e "${RED}Error: Packer is not installed. Please install Packer first.${NC}"
    exit 1
fi

echo -e "${YELLOW}Initializing Packer...${NC}"
packer init github_agent.linux.pkr.hcl

echo -e "${YELLOW}Validating Packer configuration...${NC}"
packer validate \
    -var "region=$REGION" \
    -var "subnet_id=$SUBNET_ID" \
    -var "security_group_id=$SECURITY_GROUP_ID" \
    -var "associate_public_ip_address=$ASSOCIATE_PUBLIC_IP" \
    github_agent.linux.pkr.hcl

echo -e "${YELLOW}Building AMI...${NC}"
packer build \
    -var "region=$REGION" \
    -var "subnet_id=$SUBNET_ID" \
    -var "security_group_id=$SECURITY_GROUP_ID" \
    -var "associate_public_ip_address=$ASSOCIATE_PUBLIC_IP" \
    github_agent.linux.pkr.hcl

echo -e "${GREEN}AMI build completed successfully!${NC}"

if [ -f "manifest.json" ]; then
    echo -e "${GREEN}AMI Details:${NC}"
    cat manifest.json | jq '.builds[0].artifact_id'
fi