#!/bin/bash

# Butler.AI iOS Project Setup Script
# This script generates the Xcode project using XcodeGen

set -e

echo "🤖 Butler.AI Setup"
echo "=================="

# Check for required tools
check_tool() {
    if ! command -v "$1" &> /dev/null; then
        echo "❌ $1 not found. $2"
        return 1
    else
        echo "✅ $1 found"
        return 0
    fi
}

echo ""
echo "Checking required tools..."
check_tool "xcodegen" "Install with: brew install xcodegen" || {
    echo ""
    echo "Installing XcodeGen via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install xcodegen
    else
        echo "Homebrew not found. Please install XcodeGen manually:"
        echo "  brew install xcodegen"
        echo "  OR"
        echo "  mint install yonaskolb/XcodeGen"
        exit 1
    fi
}

check_tool "xcode-select" "Please install Xcode from the App Store"

# Generate Xcode project
echo ""
echo "Generating Xcode project..."
xcodegen generate --spec project.yml

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Xcode project generated successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Open ButlerAI.xcodeproj in Xcode"
    echo "  2. Set your Development Team in project settings"
    echo "  3. Add your Anthropic API key in the app (Settings tab)"
    echo "  4. Optionally add Slack bot token for Slack monitoring"
    echo "  5. Build and run on your iPhone"
    echo ""
    echo "API Keys needed:"
    echo "  - Anthropic API key: https://console.anthropic.com"
    echo "  - Slack Bot Token: https://api.slack.com/apps"
    echo "    Required scopes: channels:history channels:read groups:history im:history users:read"
    echo ""

    # Open in Xcode if available
    if [ -d "ButlerAI.xcodeproj" ]; then
        read -p "Open in Xcode now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open ButlerAI.xcodeproj
        fi
    fi
else
    echo "❌ Project generation failed. Check project.yml for errors."
    exit 1
fi
