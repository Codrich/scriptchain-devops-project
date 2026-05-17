#!/usr/bin/env bash
# =============================================================================
# ScriptChain Health – Lambda Package Builder & Deployer
#
# Usage:
#   ./build.sh              Build only → produces function.zip
#   ./build.sh deploy       Build + deploy (create or update the Lambda function)
#
# Prerequisites: python3, pip, zip, aws-cli configured with valid credentials
# Author: Richard Kweku Addae
# =============================================================================

set -euo pipefail   # exit immediately on error, undefined variable, or pipe failure

# ---------------------------------------------------------------------------
# Configuration – override via environment variables as needed
# ---------------------------------------------------------------------------
FUNCTION_NAME="${LAMBDA_FUNCTION_NAME:-scriptchain-health-api}"
RUNTIME="python3.12"
HANDLER="handler.handler"            # <filename>.<function_name>
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
ROLE_ARN="${LAMBDA_ROLE_ARN:-}"      # required only when creating a new function
ZIP_FILE="function.zip"
BUILD_DIR="build"

# ---------------------------------------------------------------------------
# Step 1: Clean previous build artifacts
# ---------------------------------------------------------------------------
echo ">>> [1/4] Cleaning previous build..."
rm -rf "$BUILD_DIR" "$ZIP_FILE"
mkdir -p "$BUILD_DIR"

# ---------------------------------------------------------------------------
# Step 2: Install runtime dependencies into the build directory
# boto3 is excluded from requirements.txt (provided by Lambda runtime)
# so the deployment package stays as small as possible.
# ---------------------------------------------------------------------------
echo ">>> [2/4] Installing dependencies into $BUILD_DIR/..."
pip install \
  --quiet \
  --requirement requirements.txt \
  --target "$BUILD_DIR"

# ---------------------------------------------------------------------------
# Step 3: Copy the handler and create the deployment zip
# ---------------------------------------------------------------------------
echo ">>> [3/4] Packaging Lambda function..."
cp handler.py "$BUILD_DIR/"

(cd "$BUILD_DIR" && zip -r9 ../"$ZIP_FILE" . --quiet)

PACKAGE_SIZE=$(du -sh "$ZIP_FILE" | cut -f1)
echo "    Package ready: $ZIP_FILE ($PACKAGE_SIZE)"

# ---------------------------------------------------------------------------
# Step 4 (optional): Deploy to AWS Lambda
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "deploy" ]]; then
  echo ">>> [4/4] Deploying to AWS Lambda ($FUNCTION_NAME in $REGION)..."

  if aws lambda get-function \
       --function-name "$FUNCTION_NAME" \
       --region "$REGION" > /dev/null 2>&1; then

    # Function exists – update code and configuration
    aws lambda update-function-code \
      --function-name "$FUNCTION_NAME" \
      --zip-file "fileb://$ZIP_FILE" \
      --region "$REGION" \
      --output table

    aws lambda update-function-configuration \
      --function-name "$FUNCTION_NAME" \
      --runtime "$RUNTIME" \
      --handler "$HANDLER" \
      --region "$REGION" \
      --output table

    echo "    Function updated successfully."

  else
    # Function does not exist – create it (LAMBDA_ROLE_ARN required)
    if [[ -z "$ROLE_ARN" ]]; then
      echo "ERROR: Set LAMBDA_ROLE_ARN to create a new function." >&2
      exit 1
    fi

    aws lambda create-function \
      --function-name "$FUNCTION_NAME" \
      --runtime "$RUNTIME" \
      --handler "$HANDLER" \
      --role "$ROLE_ARN" \
      --zip-file "fileb://$ZIP_FILE" \
      --region "$REGION" \
      --environment "Variables={ENVIRONMENT=dev,LOG_LEVEL=INFO}" \
      --timeout 30 \
      --memory-size 256 \
      --output table

    echo "    Function created successfully."
  fi

else
  echo ">>> [4/4] Skipping deploy (run './build.sh deploy' to push to AWS)."
fi

echo ""
echo "Done. Artifact: $ZIP_FILE"