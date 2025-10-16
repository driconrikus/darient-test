# Security Setup Guide

## SSH Key Management

The SSH private key has been moved to GitHub Secrets for better security. Follow these steps to set up the SSH key as a secret:

### 1. Add SSH Key to GitHub Secrets

**⚠️ IMPORTANT: Never commit SSH keys to the repository!**

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `SSH_PRIVATE_KEY`
5. Value: Base64-encode your SSH private key:
   ```bash
   # On your local machine, encode your SSH key:
   cat /path/to/your/ssh/private/key | base64 -w 0
   ```
6. Paste the base64-encoded output as the secret value

### 2. Local Development Setup

For local development, you can either:

**Option A: Use environment variable**
```bash
export SSH_KEY=/path/to/your/ssh/key
bash scripts/deploy.sh
```

**Option B: Place SSH key in default location**
```bash
# Place your SSH key at ansible/ssh_key
bash scripts/deploy.sh
```

### 3. Security Benefits

- ✅ SSH private key is no longer stored in the repository
- ✅ GitHub Actions uses encrypted secrets
- ✅ SSH key is base64-encoded for safe storage
- ✅ Local scripts support both environment variables and default paths
- ✅ SSH key is added to .gitignore to prevent accidental commits

### 4. Verification

After setting up the secret, the GitHub Actions workflow will:
1. Decode the base64 SSH key
2. Set proper permissions (600)
3. Use it for secure server access
4. Clean up after deployment

The deployment pipeline is now secure and ready for production use!
