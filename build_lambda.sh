#!/bin/bash
mkdir -p lambda_package
pip install requests boto3 -t lambda_package/
cp lambda_handler.py lambda_package/
cd lambda_package
zip -r ../image_downloader.zip .
cd ..
rm -rf lambda_package
echo "Lambda package created: image_downloader.zip"
