#!/bin/bash

# Butler.AI iOS Project Setup Script
# Run this from INSIDE the butler.ai/ directory

set -e

# Make sure we're in the right directory
if [ ! -f "project.yml" ]; then
    echo "❌ project.yml not found."
    echo "   Please run this script from inside the butler.ai/ folder:"
    echo "   cd butler.ai && ./setup.sh"
    exit 1
fi

echo "🤖 Butler.AI Setup"
echo "=================="
echo "Working directory: $(pwd)"
echo ""

# Install XcodeGen if missing
if ! command -v xcodegen &> /dev/null; then
    echo "XcodeGen not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install xcodegen
    else
        echo "❌ Homebrew not found."
        echo "   Install Homebrew first: https://brew.sh"
        echo "   Then re-run this script."
        exit 1
    fi
else
    echo "✅ XcodeGen $(xcodegen version) found"
fi

# Generate Xcode project
echo ""
echo "Generating ButlerAI.xcodeproj..."
xcodegen generate --spec project.yml

echo ""
echo "✅ Done! ButlerAI.xcodeproj is ready."
echo ""
echo "Next steps:"
echo "  1. Open ButlerAI.xcodeproj in Xcode"
echo "  2. Select your iPhone as the run target"
echo "  3. Go to Signing & Capabilities → set your Apple ID team"
echo "  4. Press Cmd+R to build and run"
echo "  5. In the app: Settings → add your Anthropic API key"
echo ""
echo "API keys needed:"
echo "  Anthropic:  https://console.anthropic.com"
echo "  Slack:      https://api.slack.com/apps  (Bot Token, xoxb-...)"
echo ""

if [ -d "ButlerAI.xcodeproj" ]; then
    read -p "Open in Xcode now? [y/N]: " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && open ButlerAI.xcodeproj
fi
