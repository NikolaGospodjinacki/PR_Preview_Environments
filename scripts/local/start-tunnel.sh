#!/bin/bash
set -e

HTTP_PORT="${HTTP_PORT:-8080}"

echo " Starting ngrok tunnel..."
echo "   Local port: $HTTP_PORT"
echo ""

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo " ngrok is not installed. Install it from:"
    echo "   https://ngrok.com/download"
    echo ""
    echo "   Then authenticate with:"
    echo "   ngrok config add-authtoken YOUR_TOKEN"
    exit 1
fi

# Check if ngrok is authenticated
if ! ngrok config check &> /dev/null; then
    echo "  ngrok is not authenticated. Run:"
    echo "   ngrok config add-authtoken YOUR_TOKEN"
    echo ""
    echo "   Get your token from: https://dashboard.ngrok.com/get-started/your-authtoken"
    exit 1
fi

echo " Starting tunnel..."
echo "   Press Ctrl+C to stop"
echo ""

# Start ngrok with host header rewriting for proper routing
ngrok http $HTTP_PORT --host-header=localhost
