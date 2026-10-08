#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-southeast-1}"
BUCKET_NAME="${BUCKET_NAME:-}"
TABLE_NAME="${TABLE_NAME:-cloudmentor-history-dev}"
CORS_ORIGIN="${CORS_ORIGIN:-*}"

if [[ -z "$BUCKET_NAME" ]]; then
  echo "BUCKET_NAME is required. Example:" >&2
  echo "AWS_REGION=ap-southeast-1 BUCKET_NAME=cloudmentor-materials-yourname TABLE_NAME=cloudmentor-history-dev ./scripts/create-ec2-aws-resources.sh" >&2
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is not installed or not in PATH." >&2
  exit 1
fi

echo "==> Creating S3 bucket: $BUCKET_NAME in $AWS_REGION"
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "Bucket already exists or is already accessible: $BUCKET_NAME"
else
  if [[ "$AWS_REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION"
  else
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$AWS_REGION" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION"
  fi
fi

aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

cat > /tmp/cloudmentor-s3-cors.json <<JSON
{
  "CORSRules": [
    {
      "AllowedOrigins": ["$CORS_ORIGIN"],
      "AllowedMethods": ["PUT", "GET", "HEAD"],
      "AllowedHeaders": ["*"],
      "ExposeHeaders": ["ETag"],
      "MaxAgeSeconds": 3000
    }
  ]
}
JSON
aws s3api put-bucket-cors --bucket "$BUCKET_NAME" --cors-configuration file:///tmp/cloudmentor-s3-cors.json

echo "==> Creating DynamoDB table: $TABLE_NAME"
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "DynamoDB table already exists: $TABLE_NAME"
else
  aws dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --region "$AWS_REGION" \
    --billing-mode PAY_PER_REQUEST \
    --attribute-definitions AttributeName=userId,AttributeType=S AttributeName=createdAtId,AttributeType=S \
    --key-schema AttributeName=userId,KeyType=HASH AttributeName=createdAtId,KeyType=RANGE
  aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$AWS_REGION"
fi

cat <<OUT

Done.
Use these values in backend/env.ec2.json or GitHub Secrets:
AWS_REGION=$AWS_REGION
MATERIALS_BUCKET=$BUCKET_NAME
TABLE_NAME=$TABLE_NAME
CORS_ORIGIN=$CORS_ORIGIN
OUT
