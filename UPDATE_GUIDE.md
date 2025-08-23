# App Update Setup Guide

## Step 1: Create a GitHub Release

1. Go to your repository: https://github.com/officialprakashkumarsingh/ahamai-landingpage
2. Click on "Releases" (on the right side)
3. Click "Create a new release"
4. Create a tag (e.g., `v1.2.0`)
5. Upload your APK file
6. Publish the release

## Step 2: Get the Correct Download URL

After creating the release, your APK download URL will be:
```
https://github.com/officialprakashkumarsingh/ahamai-landingpage/releases/download/{tag}/{filename.apk}
```

For example:
```
https://github.com/officialprakashkumarsingh/ahamai-landingpage/releases/download/v1.2.0/ahamai_v1.2.0.apk
```

## Step 3: Update your app-update.json

Create or update the `app-update.json` file in your repository with:

```json
{
  "latest_version": "1.2.0",
  "download_url": "https://github.com/officialprakashkumarsingh/ahamai-landingpage/releases/download/v1.2.0/ahamai_v1.2.0.apk",
  "force_update": false,
  "release_date": "2024-01-15",
  "file_size_mb": 25,
  "improvements": [
    "Your improvement list here"
  ]
}
```

## Step 4: Test the Download URL

Before updating the JSON, test the download URL by:
1. Opening it in a browser - it should start downloading the APK
2. Using curl: `curl -L -o test.apk "YOUR_DOWNLOAD_URL"`

## Alternative: Using Direct File Upload

If you want to host the APK directly in your repository (not recommended for large files):

1. Upload the APK to your repository
2. Get the raw URL:
```
https://github.com/officialprakashkumarsingh/ahamai-landingpage/raw/main/releases/ahamai_v1.2.0.apk
```

Note: GitHub has a 100MB file size limit for repository files.

## Troubleshooting

If download fails, check:
1. The URL is publicly accessible
2. The file exists at that URL
3. No authentication is required
4. The URL returns a 200 status code

You can test with:
```bash
curl -I "YOUR_DOWNLOAD_URL"
```

This should return `HTTP/2 200` or `HTTP/1.1 200 OK`.