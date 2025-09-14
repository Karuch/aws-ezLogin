#!/bin/bash

# ======================================================== #
# Safe shell options (don’t kill parent shell on error)
# ======================================================== #
set -uo pipefail

# ======================================================== #
# Parse flags
# ======================================================== #

usage() {
  echo "❌ Missing required arguments."
  echo
  [[ -z "$AWS_KEY" ]]     && echo "   → Missing: --aws-key"
  [[ -z "$AWS_SECRET" ]]  && echo "   → Missing: --aws-secret"
  [[ -z "$AWS_REGION" ]]  && echo "   → Missing: --region"
  [[ -z "$PROFILE" ]]     && echo "   → Missing: --profile"
  [[ -z "$ROLE_NAME" ]]   && echo "   → Missing: --role-name"
  [[ -z "$ACCOUNT_ID" ]]  && echo "   → Missing: --account-id"
  echo
  echo "👉 Example usage (must be sourced, not executed):"
  echo
  echo "source ./cli-login.sh \\"
  echo "  --aws-key <AccessKey> \\"
  echo "  --aws-secret <SecretKey> \\"
  echo "  --region <Region e.g il-central-1> \\"
  echo "  --profile <IamUserName e.g talk> \\"
  echo "  --role-name <roleName> \\"
  echo "  --account-id <accountId e.g 012345678910>"
  echo
  return 1
}

AWS_KEY=""
AWS_SECRET=""
AWS_REGION=""
PROFILE=""
ROLE_NAME=""
ACCOUNT_ID=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --aws-key) AWS_KEY="$2"; shift 2 ;;
    --aws-secret) AWS_SECRET="$2"; shift 2 ;;
    --region) AWS_REGION="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --role-name) ROLE_NAME="$2"; shift 2 ;;
    --account-id) ACCOUNT_ID="$2"; shift 2 ;;
    *) echo "❌ Unknown argument: $1"; usage; return 1 ;;
  esac
done

# Check required args
if [[ -z "$AWS_KEY" || -z "$AWS_SECRET" || -z "$AWS_REGION" || -z "$PROFILE" || -z "$ROLE_NAME" || -z "$ACCOUNT_ID" ]]; then
  usage
  return 1
fi

# ======================================================== #
# Prompt MFA code
# ======================================================== #

read -rp "🔑 Enter MFA code: " MFA_CODE

# ======================================================== #
# Build ARNs and session info
# ======================================================== #

MFA_DEVICE_NAME="$PROFILE"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
MFA_ARN="arn:aws:iam::${ACCOUNT_ID}:mfa/${MFA_DEVICE_NAME}"
SESSION_NAME="${ROLE_NAME}-$(date +%s)"

# ======================================================== #
# Configure base profile
# ======================================================== #

echo "📂 Creating profile if not exist..."
aws configure set aws_access_key_id "$AWS_KEY" --profile "$PROFILE-malamteam-infra"
aws configure set aws_secret_access_key "$AWS_SECRET" --profile "$PROFILE-malamteam-infra"
aws configure set region "$AWS_REGION" --profile "$PROFILE-malamteam-infra"
aws configure set output json --profile "$PROFILE-malamteam-infra"

# ======================================================== #
# Get MFA session token
# ======================================================== #

echo "🔑 Getting MFA session token..."
MFA_CREDS=$(aws sts get-session-token \
  --serial-number "$MFA_ARN" \
  --token-code "$MFA_CODE" \
  --profile "$PROFILE-malamteam-infra" \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text) || {
    echo "❌ Failed to get MFA session token. Check your code or profile."
    return 1
}

eval $(echo "$MFA_CREDS" | awk '{print "export AWS_ACCESS_KEY_ID="$1"\nexport AWS_SECRET_ACCESS_KEY="$2"\nexport AWS_SESSION_TOKEN="$3}')

# ======================================================== #
# Assume Role
# ======================================================== #

echo "🌀 Assuming role: $ROLE_NAME"
ROLE_CREDS=$(aws sts assume-role \
  --role-arn "$ROLE_ARN" \
  --role-session-name "$SESSION_NAME" \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text) || {
    echo "❌ Failed to assume role $ROLE_NAME"
    return 1
}

eval $(echo "$ROLE_CREDS" | awk '{print "export AWS_ACCESS_KEY_ID="$1"\nexport AWS_SECRET_ACCESS_KEY="$2"\nexport AWS_SESSION_TOKEN="$3}')

echo "✅ Role assumed successfully!"

# ======================================================== #
# Show identity
# ======================================================== #

echo "🔍 Current identity:"
aws sts get-caller-identity
