#!/bin/bash
# Script to clean up S3 bucket contents before deletion

# Get the S3 bucket name from terraform output
if [ -z "$1" ]; then
  echo "Getting S3 bucket name from terraform output..."
  S3_BUCKET=$(terraform output -raw s3_bucket_name)
else
  S3_BUCKET=$1
fi

if [ -z "$S3_BUCKET" ]; then
  echo "Error: Could not determine S3 bucket name"
  exit 1
fi

echo "Emptying S3 bucket: $S3_BUCKET"

# First, check if the bucket exists
if aws s3api head-bucket --bucket "$S3_BUCKET" 2>/dev/null; then
  echo "Bucket exists, proceeding with cleanup..."

  # Delete all objects
  aws s3 rm s3://$S3_BUCKET/ --recursive

  # Delete any versioned objects if bucket has versioning enabled
  aws s3api list-object-versions \
    --bucket $S3_BUCKET \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --output json | \
  jq 'if .Objects then .Objects else [] end' | \
  jq -c '.[]' | \
  while read -r OBJECT; do
    KEY=$(echo $OBJECT | jq -r '.Key')
    VERSION_ID=$(echo $OBJECT | jq -r '.VersionId')
    aws s3api delete-object \
      --bucket $S3_BUCKET \
      --key "$KEY" \
      --version-id "$VERSION_ID"
    echo "Deleted object: $KEY (version $VERSION_ID)"
  done

  # Delete any delete markers
  aws s3api list-object-versions \
    --bucket $S3_BUCKET \
    --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
    --output json | \
  jq 'if .Objects then .Objects else [] end' | \
  jq -c '.[]' | \
  while read -r OBJECT; do
    KEY=$(echo $OBJECT | jq -r '.Key')
    VERSION_ID=$(echo $OBJECT | jq -r '.VersionId')
    aws s3api delete-object \
      --bucket $S3_BUCKET \
      --key "$KEY" \
      --version-id "$VERSION_ID"
    echo "Deleted delete marker: $KEY (version $VERSION_ID)"
  done

  echo "S3 bucket $S3_BUCKET has been emptied"
else
  echo "Bucket $S3_BUCKET does not exist, nothing to clean up"
fi
