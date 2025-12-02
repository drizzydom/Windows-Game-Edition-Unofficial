#!/bin/bash
# ============================================================================
# Windows Game Edition - Build & Publish Script
# ============================================================================
# This script cross-compiles the WPF application to a single Windows EXE.
# Run from macOS, Linux, or Windows with the .NET SDK installed.
#
# Usage: ./scripts/publish.sh [--clean] [--verbose]
# ============================================================================

set -e

# Colors for pretty output (because why not make builds fun?)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_PROJECT="$PROJECT_ROOT/src/WGE.App"
DIST_DIR="$PROJECT_ROOT/dist"

# Parse arguments
CLEAN=false
VERBOSE=false
for arg in "$@"; do
    case $arg in
        --clean)
            CLEAN=true
            ;;
        --verbose)
            VERBOSE=true
            ;;
    esac
done

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     🎮 Windows Game Edition - Build Script                   ║"
echo "║     Cross-compiling for Windows from $(uname -s)                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check for .NET SDK
if ! command -v dotnet &> /dev/null; then
    echo -e "${RED}❌ .NET SDK not found!${NC}"
    echo "Please install it first:"
    echo "  - macOS: brew install dotnet-sdk"
    echo "  - Windows: winget install Microsoft.DotNet.SDK.8"
    echo "  - Linux: See https://dotnet.microsoft.com/download"
    exit 1
fi

DOTNET_VERSION=$(dotnet --version)
echo -e "${GREEN}✓${NC} .NET SDK version: ${CYAN}$DOTNET_VERSION${NC}"

# Clean if requested
if [ "$CLEAN" = true ]; then
    echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
    rm -rf "$DIST_DIR"
    rm -rf "$APP_PROJECT/bin"
    rm -rf "$APP_PROJECT/obj"
    echo -e "${GREEN}✓${NC} Clean complete"
fi

# Create dist directory
mkdir -p "$DIST_DIR"

# Build configuration
RUNTIME="win-x64"
CONFIG="Release"

echo -e "\n${BLUE}📦 Building for ${RUNTIME}...${NC}"
echo -e "   Configuration: ${CONFIG}"
echo -e "   Output: ${DIST_DIR}"

# Build arguments
BUILD_ARGS=(
    "publish"
    "-c" "$CONFIG"
    "-r" "$RUNTIME"
    "-o" "$DIST_DIR"
    "--self-contained" "true"
    "-p:PublishSingleFile=true"
    "-p:IncludeNativeLibrariesForSelfExtract=true"
    "-p:EnableCompressionInSingleFile=true"
)

if [ "$VERBOSE" = true ]; then
    BUILD_ARGS+=("-v" "normal")
else
    BUILD_ARGS+=("-v" "minimal")
fi

# Run the build
cd "$APP_PROJECT"
echo -e "${YELLOW}⏳ Compiling (this may take a minute)...${NC}"

if dotnet "${BUILD_ARGS[@]}"; then
    echo -e "\n${GREEN}✅ Build successful!${NC}"
else
    echo -e "\n${RED}❌ Build failed!${NC}"
    exit 1
fi

# List output
echo -e "\n${CYAN}📁 Output files:${NC}"
ls -lh "$DIST_DIR"/*.exe 2>/dev/null || echo "  (no .exe files found)"

# Calculate size
if [ -f "$DIST_DIR/WGE.App.exe" ]; then
    SIZE=$(ls -lh "$DIST_DIR/WGE.App.exe" | awk '{print $5}')
    echo -e "\n${GREEN}🎉 Single-file executable ready!${NC}"
    echo -e "   File: ${CYAN}$DIST_DIR/WGE.App.exe${NC}"
    echo -e "   Size: ${CYAN}$SIZE${NC}"
    echo ""
    echo -e "${YELLOW}📋 Next steps:${NC}"
    echo "   1. Copy the 'dist' folder to your Windows machine"
    echo "   2. Run WGE.App.exe as Administrator"
    echo "   3. Select a preset and click 'Apply Preset'"
    echo ""
    echo -e "${BLUE}💡 Tip:${NC} The dist/ folder is already in .gitignore"
fi

echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
