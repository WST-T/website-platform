#!/bin/bash
set -e  # Exit on any error

echo "Starting cleanup and destroy process..."

# Make cleanup script executable
chmod +x clean_s3.sh

# Get bucket name before destroying resources
if terraform output -raw s3_bucket_name &>/dev/null; then
  S3_BUCKET=$(terraform output -raw s3_bucket_name)
  echo "Found S3 bucket to clean: $S3_BUCKET"

  # Run cleanup script to empty bucket
  ./clean_s3.sh "$S3_BUCKET"
else
  echo "No S3 bucket found in terraform state, skipping cleanup"
fi

# Now destroy all resources
echo "Destroying all AWS resources..."
terraform destroy -auto-approve

echo "All resources have been destroyed."
