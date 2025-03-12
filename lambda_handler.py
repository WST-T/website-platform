import os
import boto3
import requests
import json
import time

def handler(event, context):
    print("Starting image downloader lambda function...")

    api_url = os.environ.get('API_ENDPOINT')
    bucket_name = os.environ.get('S3_BUCKET')

    print(f"Using API URL: {api_url}")
    print(f"Target S3 bucket: {bucket_name}")

    s3_client = boto3.client('s3')

    max_retries = 5
    retry_delay = 3

    for attempt in range(max_retries):
        try:
            print(f"Attempting to connect to API at {api_url} (attempt {attempt+1}/{max_retries})")

            response = requests.get(api_url, timeout=10)
            print(f"API Response Status Code: {response.status_code}")

            if response.status_code != 200:
                print(f"Error fetching product data: {response.status_code}")
                if attempt < max_retries - 1:
                    print(f"Retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                continue

            data = response.json()
            products = data.get("products", [])

            if not products:
                print("No products found in API response!")
                print(f"API response content: {response.text[:200]}...")
                if attempt < max_retries - 1:
                    print(f"Retrying in {retry_delay} seconds...")
                    time.sleep(retry_delay)
                continue

            print(f"Found {len(products)} products to download")

            index_html = """
            <!DOCTYPE html>
            <html>
              <head>
                <meta charset="utf-8">
                <title>Website Platform</title>
                <meta http-equiv="refresh" content="0; url=index.html">
              </head>
              <body>
                <p>Redirecting to <a href="index.html">home page</a>...</p>
              </body>
            </html>
            """

            s3_client.put_object(
                Bucket=bucket_name,
                Key="index.html",
                Body=index_html,
                ContentType='text/html',
                ACL='public-read'
            )
            print(f"Created index.html in bucket: {bucket_name}")

            s3_client.put_object(
                Bucket=bucket_name,
                Key="images/",
                Body="",
                ACL='public-read'
            )
            print(f"Created images/ directory in bucket: {bucket_name}")

            for product in products:
                image_url = product.get("url")
                image_name = product.get("name")

                if not image_url or not image_name:
                    print(f"Missing URL or name: {product}")
                    continue

                print(f"Downloading {image_name} from {image_url}")
                image_response = requests.get(image_url, timeout=10)
                if image_response.status_code == 200:
                    s3_client.put_object(
                        Bucket=bucket_name,
                        Key=f"images/{image_name}",
                        Body=image_response.content,
                        ContentType='image/png',
                        ACL='public-read'
                    )
                    print(f"Successfully uploaded: {image_name} to S3 bucket: {bucket_name}")
                else:
                    print(f"Failed to download {image_name}: {image_response.status_code}")

            print("Image download and upload to S3 complete!")
            return {
                'statusCode': 200,
                'body': json.dumps('Images successfully processed!')
            }

        except Exception as e:
            print(f"Error on attempt {attempt+1}: {str(e)}")
            if attempt < max_retries - 1:
                print(f"Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)

    print("Failed to download and process images after multiple attempts")
    return {
        'statusCode': 500,
        'body': json.dumps('Error processing images')
    }
