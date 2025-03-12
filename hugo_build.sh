#!/bin/bash
# Export AWS_PAGER="" to avoid opening the aws cli output in a pager
export AWS_PAGER=""

# Get the S3 bucket name from terraform output
S3_BUCKET=$(terraform output -raw s3_bucket_name)
echo "Using S3 bucket: $S3_BUCKET"

# Ensure necessary directories exist
mkdir -p assets/css
mkdir -p content
mkdir -p layouts/_default
mkdir -p static/images

# Create a minimal main.css if it doesn't exist
if [ ! -f assets/css/main.css ]; then
  echo "Creating minimal main.css file..."
  cat > assets/css/main.css << EOF
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  margin: 0;
  padding: 0;
  background-color: #f5f5f5;
  color: #333;
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

h1, h2, h3, h4 {
  color: #333;
}

a {
  color: #0066cc;
  text-decoration: none;
}

a:hover {
  text-decoration: underline;
}
EOF
fi

# Create a minimal index.html template if it doesn't exist
if [ ! -f layouts/index.html ]; then
  echo "Creating minimal index.html template..."
  cat > layouts/index.html << EOF
{{ define "main" }}
  <div class="container">
    <h1>{{ .Title }}</h1>
    {{ .Content }}
    {{ partial "product-offerings.html" . }}
  </div>
{{ end }}
EOF
fi

# Create a minimal baseof.html if it doesn't exist
if [ ! -f layouts/_default/baseof.html ]; then
  echo "Creating minimal baseof.html..."
  cat > layouts/_default/baseof.html << EOF
<!DOCTYPE html>
<html lang="en">
  {{ partial "head.html" . }}
  <body>
    <header>
      <div class="container">
        <h1>Website Platform</h1>
      </div>
    </header>
    <main>
      {{ block "main" . }}{{ end }}
    </main>
    <footer>
      <div class="container">
        <p>&copy; {{ now.Format "2006" }} Website Platform</p>
      </div>
    </footer>
  </body>
</html>
EOF
fi

# Create a minimal head.html if it doesn't exist
if [ ! -f layouts/partials/head.html ]; then
  echo "Creating minimal head.html..."
  cat > layouts/partials/head.html << EOF
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{{ if .Title }}{{ .Title }} | {{ end }}{{ .Site.Title }}</title>
  <meta name="description" content="{{ with .Description }}{{ . }}{{ else }}{{ with .Summary }}{{ . }}{{ else }}{{ .Site.Params.description }}{{ end }}{{ end }}">
  {{ partialCached "css.html" . }}
</head>
EOF
fi

# Create minimal list and single templates
if [ ! -f layouts/_default/list.html ]; then
  echo "Creating minimal list.html template..."
  cat > layouts/_default/list.html << EOF
{{ define "main" }}
  <div class="container">
    <h1>{{ .Title }}</h1>
    {{ .Content }}
    <ul>
      {{ range .Pages }}
      <li><a href="{{ .RelPermalink }}">{{ .Title }}</a></li>
      {{ end }}
    </ul>
  </div>
{{ end }}
EOF
fi

if [ ! -f layouts/_default/single.html ]; then
  echo "Creating minimal single.html template..."
  cat > layouts/_default/single.html << EOF
{{ define "main" }}
  <div class="container">
    <h1>{{ .Title }}</h1>
    {{ .Content }}
  </div>
{{ end }}
EOF
fi

if [ ! -f layouts/404.html ]; then
  echo "Creating minimal 404.html template..."
  cat > layouts/404.html << EOF
{{ define "main" }}
  <div class="container">
    <h1>Page Not Found</h1>
    <p>The requested page could not be found.</p>
    <p><a href="{{ "/" | relURL }}">Return to Home</a></p>
  </div>
{{ end }}
EOF
fi

# Create _index.md if it doesn't exist
if [ ! -f content/_index.md ]; then
  echo "Creating minimal _index.md content file..."
  cat > content/_index.md << EOF
---
title: Home
---

# Welcome to our Website Platform

This is a demonstration of our products and services.
EOF
fi

# Create config.yaml if it doesn't exist
if [ ! -f config.yaml ]; then
  echo "Creating minimal config.yaml..."
  cat > config.yaml << EOF
baseURL: "/"
languageCode: "en-us"
title: "Website Platform"
params:
  description: "A demo website platform"
EOF
fi

echo "All necessary Hugo files have been created or verified."

# Fix Hugo template issues before building
echo "Building Hugo site..."
HUGO_ENV="production" hugo --minify || {
  echo "Hugo build failed!"
  exit 1
}

# Sync the public directory to S3
echo "Uploading to S3 bucket: $S3_BUCKET"
aws s3 sync public/ s3://$S3_BUCKET/ --acl public-read

echo "Website built and uploaded to S3"
