import os
import requests
import json
from pathlib import Path
import time
import sys

def download_images():
    print("Starting image downloader script...")

    image_dir = Path("static/images")
    image_dir.mkdir(parents=True, exist_ok=True)
    print(f"Created directory: {image_dir.absolute()}")

    api_host = "api" if os.environ.get("DOCKER_ENVIRONMENT") else "localhost"
    api_url = f"http://{api_host}:3000"

    print(f"Environment: {'Docker' if os.environ.get('DOCKER_ENVIRONMENT') else 'Local'}")
    print(f"Using API URL: {api_url}")

    max_retries = 10
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

            for product in products:
                image_url = product.get("url")
                image_name = product.get("name")

                if not image_url or not image_name:
                    print(f"Missing URL or name: {product}")
                    continue

                if os.environ.get("DOCKER_ENVIRONMENT"):
                    image_url = image_url.replace("localhost", "api")

                print(f"Downloading {image_name} from {image_url}")
                image_response = requests.get(image_url, timeout=10)
                if image_response.status_code == 200:
                    image_path = image_dir / image_name
                    with open(image_path, "wb") as f:
                        f.write(image_response.content)
                    print(f"Successfully downloaded: {image_name} to {image_path}")
                else:
                    print(f"Failed to download {image_name}: {image_response.status_code}")

            print("Image download complete!")
            print(f"Contents of {image_dir}: {os.listdir(image_dir)}")
            return

        except Exception as e:
            print(f"Error on attempt {attempt+1}: {str(e)}")
            if attempt < max_retries - 1:
                print(f"Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)

    print("Failed to download images after multiple attempts")
    sys.exit(1)

if __name__ == "__main__":
    download_images()