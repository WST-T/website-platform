# Websites Platform Take Home Assessment

## Overview

This project demonstrates a complete workflow for building, deploying, and maintaining a website platform with the following components:

- Hugo-based static website showcasing Datadog products
- API server providing product data
- Automated image downloader service
- Infrastructure as Code (Terraform) for AWS deployment
- CI/CD automation scripts
  
## Prerequisites

### Local Development Setup
1. [Install Node.js and npm][1] (Node.js `>=20.11.0`)
1. [Install Hugo][2]
1. [Install Go][3] (at minimum, `go version` 1.21.8)
1. Install Yarn: `npm install -g yarn`

### Docker Setup
1. [Install Docker][4] (Additional instructions can be found [here][5])

### AWS Deployment Setup
1. Install [AWS CLI](https://aws.amazon.com/cli/)
1. Configure AWS credentials (`aws configure`)
1. Install [Terraform](https://developer.hashicorp.com/terraform/install)
1. Generate SSH key pair if you don't have one (`ssh-keygen -t rsa -b 4096`)

## Running Locally

### With Docker (Recommended)
The simplest way to run the entire stack locally:

```bash
docker-compose up -d
```

This command starts three services:
- `api`: The API server providing product data (accessible at http://localhost:3000)
- `image-downloader`: A service that downloads product images
- `example-site`: The Hugo website (accessible at http://localhost:1313)

### Without Docker
If you prefer to run the services individually:

1. Install dependencies:
   ```bash
   yarn install
   ```

2. Start the Hugo development server:
   ```bash
   yarn start
   ```

3. In a separate terminal, start the API server:
   ```bash
   node ./_server/api.js
   ```

4. In another terminal, run the image downloader:
   ```bash
   python3 download_images.py
   ```

## Deployment Process

This project includes a complete AWS deployment pipeline using Terraform and shell scripts.

### Deployment Architecture

When deployed to AWS, the architecture includes:
- EC2 instance running the API server
- S3 bucket for static website hosting
- CloudFront distribution for global content delivery
- Lambda function for automated image processing
- CloudWatch Event for scheduled tasks

### Deployment Scripts

To deploy to AWS:

```bash
./deploy.sh
```

This initiates the deployment process, which will:
1. Create or use an existing SSH key
2. Package the Lambda function
3. Create AWS infrastructure with Terraform
4. Build the Hugo site
5. Upload the site to S3
6. Configure CloudFront

### Script Descriptions

The project includes several utility scripts:

- **deploy.sh**: Main deployment script that orchestrates the entire process
- **build_lambda.sh**: Packages the Python Lambda function with dependencies
- **hugo_build.sh**: Builds the Hugo site and uploads it to S3
- **clean_s3.sh**: Utility to empty an S3 bucket before deletion
- **destroy.sh**: Removes all AWS resources created by Terraform

## Script Usage

### deploy.sh
The main deployment script that:
- Checks for SSH keys and generates them if missing
- Makes other scripts executable
- Builds the Lambda function package
- Initializes and applies Terraform configuration
- Builds and uploads the Hugo site to S3

```bash
./deploy.sh
```

### build_lambda.sh
Creates a deployment package for AWS Lambda:
- Installs Python dependencies to a temporary directory
- Copies the lambda handler code
- Bundles everything into a ZIP file

```bash
./build_lambda.sh
```

### hugo_build.sh
Builds and uploads the Hugo website:
- Ensures necessary Hugo directories and files exist
- Creates missing templates if needed
- Builds the site with the production environment
- Syncs the built site to the S3 bucket

```bash
./hugo_build.sh
```

### clean_s3.sh
Utility to empty S3 buckets before deletion:
- Gets bucket name from Terraform output or command line argument
- Removes all objects including versioned objects
- Handles delete markers for versioned buckets

```bash
./clean_s3.sh [bucket-name]
```

### destroy.sh
Cleans up all AWS resources:
- Empties the S3 bucket first to allow deletion
- Destroys all Terraform-managed resources

```bash
./destroy.sh
```

## Monitoring with Datadog

This project includes integration with Datadog Real User Monitoring (RUM) to track user experience on the website.

### Datadog Features Implemented

1. **Real User Monitoring (RUM)**: Tracks page loads, user interactions, and frontend performance metrics.
2. **Session Replay**: Records user sessions for playback to understand user behavior.
3. **Custom Events**: Tracks user interactions with product offerings.

### Setting Up Datadog

1. Create a free Datadog account at [https://www.datadoghq.eu/](https://www.datadoghq.eu/)
2. Create a new RUM application in Datadog
3. When running deploy.sh, you'll be prompted for your Datadog Application ID and Client Token
   - These can be found in the Datadog RUM application setup page
3. Configure your credentials:
   - Option 1: Create a `.env` file in the project root with:
     ```
     DATADOG_APPLICATION_ID=your_application_id_here
     DATADOG_CLIENT_TOKEN=your_client_token_here
     DATADOG_SITE=datadoghq.eu
     ```

After deployment, you can view performance metrics, user sessions, and custom events in your Datadog dashboard.

## Additional Information

### Accessing Deployed Resources

After a successful deployment, the script will output:
- Website URL (CloudFront distribution)
- API Server IP address

### Local Development Notes

- Any changes to Hugo files will automatically reload when using `yarn start`
- The API server must be running for the image downloader to work
- Docker Compose handles all service dependencies automatically

[1]: https://nodejs.org/en/download/package-manager#macos
[2]: https://gohugo.io/getting-started/installing/
[3]: https://golang.org/doc/install
[4]: https://www.docker.com/products/docker-desktop/
[5]: https://www.docker.com/get-started/
