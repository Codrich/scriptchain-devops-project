"""
ScriptChain Health – AWS Lambda Handler
=======================================
Entry point for the Lambda function. Designed for API Gateway proxy integration.

Receives an HTTP event, logs the request to CloudWatch, and returns a
structured JSON response. Handles malformed input and unexpected errors
gracefully so the function never returns an unhandled exception to the caller.

Author:  Richard Kweku Addae
Runtime: Python 3.12
"""

import json
import logging
import os
from datetime import datetime, timezone

# ---------------------------------------------------------------------------
# Logger
# Lambda forwards stdout/stderr to CloudWatch Logs automatically.
# LOG_LEVEL can be overridden via Lambda environment variable.
# ---------------------------------------------------------------------------
logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


# ---------------------------------------------------------------------------
# Main handler
# ---------------------------------------------------------------------------
def handler(event: dict, context) -> dict:
    """
    AWS Lambda entry point.

    Parameters
    ----------
    event   : dict          API Gateway proxy event (or any trigger payload)
    context : LambdaContext Runtime metadata (function name, request ID, etc.)

    Returns
    -------
    dict  API Gateway-compatible response with statusCode and JSON body
    """
    logger.info("Request ID: %s | Event: %s", context.aws_request_id, json.dumps(event))

    try:
        # API Gateway sends the body as a JSON string; parse it if present
        body = {}
        if event.get("body"):
            body = json.loads(event["body"])

        response_payload = {
            "message": "ScriptChain Health Lambda – OK",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "requestId": context.aws_request_id,
            "environment": os.environ.get("ENVIRONMENT", "dev"),
            "receivedBody": body,
        }

        return _build_response(200, response_payload)

    except json.JSONDecodeError as exc:
        logger.error("Malformed JSON in request body: %s", exc)
        return _build_response(400, {"error": "Invalid JSON in request body"})

    except Exception as exc:          # pylint: disable=broad-except
        logger.exception("Unhandled exception: %s", exc)
        return _build_response(500, {"error": "Internal server error"})


# ---------------------------------------------------------------------------
# Helper – API Gateway proxy response format
# ---------------------------------------------------------------------------
def _build_response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }