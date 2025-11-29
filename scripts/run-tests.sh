#!/bin/bash

# Respectlytics Swift SDK Test Runner
# ===================================
# Runs integration tests with environment configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_DIR="$(dirname "$SCRIPT_DIR")"

cd "$SDK_DIR"

echo ""
echo "🚀 Respectlytics Swift SDK Test Runner"
echo "======================================="

# Check for .env.testing file
if [ -f ".env.testing" ]; then
    echo "📁 Loading .env.testing..."
    set -a
    source .env.testing
    set +a
else
    echo "⚠️  No .env.testing file found"
    echo ""
    echo "To run integration tests:"
    echo "  1. cp .env.testing.example .env.testing"
    echo "  2. Edit .env.testing and add your API key"
    echo "  3. Run this script again"
    echo ""
    echo "Running unit tests only..."
    echo ""
    swift test --filter RespectlyticsSwiftTests
    exit 0
fi

# Run tests
echo ""
echo "Running all tests..."
echo ""

if [ "$1" == "--integration-only" ]; then
    swift test --filter IntegrationTests 2>&1
elif [ "$1" == "--unit-only" ]; then
    swift test --filter RespectlyticsSwiftTests 2>&1
else
    swift test 2>&1
fi

echo ""
echo "✅ Tests complete!"
