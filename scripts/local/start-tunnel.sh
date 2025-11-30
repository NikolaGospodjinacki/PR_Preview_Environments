#!/bin/bash
set -e

echo "🌐 Starting ngrok tunnel..."

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "❌ ngrok is not installed. Install it from: https://ngrok.com/download"
    echo "   Or: brew install ngrok (macOS) / choco install ngrok (Windows) / snap install ngrok (Linux)"
    exit 1
fi

# Check if NGROK_AUTH_TOKEN is set
if [ -z "$NGROK_AUTH_TOKEN" ]; then
    echo "⚠️  NGROK_AUTH_TOKEN not set."
    echo "   Get your token from: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo ""
    echo "   Set it with: export NGROK_AUTH_TOKEN=your_token_here"
    echo "   Or add to ~/.bashrc or ~/.zshrc"
    echo ""
    read -p "Enter your ngrok auth token (or Ctrl+C to exit): " token
    ngrok authtoken "$token"
fi

echo ""
echo "🚀 Starting tunnel to localhost:80..."
echo "   This will expose your k3d cluster to the internet"
echo ""
echo "📋 Preview URLs will be accessible at:"
echo "   https://<random>.ngrok.io/pr-<number>/"
echo ""
echo "Press Ctrl+C to stop the tunnel"
echo ""

# Start ngrok with HTTP on port 80
ngrok http 80 --log=stdout
