#!/bin/bash
set -e  # Exit on any error

echo "Starting deployment..."

# Check for .env file and load variables if it exists
if [ -f .env ]; then
  echo "Loading environment variables from .env file..."
  export $(grep -v '^#' .env | xargs)
fi

# Prompt for Datadog credentials if not provided through environment variables
if [ -z "$DATADOG_APPLICATION_ID" ] || [ -z "$DATADOG_CLIENT_TOKEN" ] || [ -z "$DATADOG_SITE" ]; then
  read -p "Enter your Datadog Application ID: " DATADOG_APPLICATION_ID
  read -p "Enter your Datadog Client Token: " DATADOG_CLIENT_TOKEN
  read -p "Enter your Datadog Site (default: datadoghq.eu): " DATADOG_SITE

  # Set default value for site if not provided
  DATADOG_SITE=${DATADOG_SITE:-datadoghq.eu}

  # Save to .env file for future runs
  echo "# Datadog RUM Configuration" > .env
  echo "DATADOG_APPLICATION_ID=${DATADOG_APPLICATION_ID}" >> .env
  echo "DATADOG_CLIENT_TOKEN=${DATADOG_CLIENT_TOKEN}" >> .env
  echo "DATADOG_SITE=${DATADOG_SITE}" >> .env

  echo "Saved Datadog configuration to .env file"
fi

# Create a temporary version of the Datadog RUM script with actual values
echo "Configuring Datadog RUM script with environment variables..."
cp static/js/datadog-rum.js static/js/datadog-rum.js.template
sed -i "s/%%DATADOG_APPLICATION_ID%%/${DATADOG_APPLICATION_ID}/g" static/js/datadog-rum.js
sed -i "s/%%DATADOG_CLIENT_TOKEN%%/${DATADOG_CLIENT_TOKEN}/g" static/js/datadog-rum.js
sed -i "s/%%DATADOG_SITE%%/${DATADOG_SITE}/g" static/js/datadog-rum.js
sed -i "s/%%ENVIRONMENT%%/production/g" static/js/datadog-rum.js

# Ensure SSH key exists for EC2 instance
if [ ! -f ~/.ssh/id_rsa.pub ]; then
  echo "SSH public key not found. Generating a new SSH key pair..."
  ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
fi

# Make scripts executable
chmod +x build_lambda.sh
chmod +x hugo_build.sh
chmod +x clean_s3.sh

# Build Lambda package
echo "Building Lambda package..."
./build_lambda.sh

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Test the plan to check for any issues
echo "Creating Terraform plan..."
terraform plan -out=tfplan

# Apply Terraform configuration
echo "Applying Terraform configuration..."
terraform apply tfplan

# Wait for AWS resources to fully propagate
echo "Waiting for AWS resources to stabilize..."
sleep 10

# Build and deploy the Hugo site
echo "Building and deploying Hugo site..."
./hugo_build.sh

# Restore the template version of the Datadog RUM script for version control
mv static/js/datadog-rum.js.template static/js/datadog-rum.js

echo "Deployment complete!"
echo "Website URL: $(terraform output -raw website_url)"
echo "API Server IP: $(terraform output -raw api_server_public_ip)"
echo "Datadog RUM has been configured and deployed."
