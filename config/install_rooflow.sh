#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "--- Starting RooFlow config setup ---"

# Check for Git command
if ! command -v git &> /dev/null; then
    echo "Error: git is not found in your PATH."
    echo "Please install Git using your distribution's package manager (e.g., sudo apt install git, sudo yum install git)."
    exit 1
else
    echo "Found git executable."
fi

# Check for Python 3
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is not found in your PATH."
    echo "Please install Python 3 (https://www.python.org/downloads/)."
    exit 1
else
    echo "Found python3 executable."
fi

# Check for PyYAML library
if ! python3 -c "import yaml" &> /dev/null; then
    echo "Error: PyYAML library is not found for Python 3."
    echo "Please install it using: pip install pyyaml"
    exit 1
else
    echo "Found PyYAML library."
fi

# Define a temporary directory name for clarity
CLONE_DIR="RooFlow_temp_$$" # Using $$ for process ID to add uniqueness

# Clone the repository (shallow clone for efficiency)
echo "Cloning RooFlow repository into $CLONE_DIR..."
git clone --depth 1 https://github.com/GreatScottyMac/RooFlow "$CLONE_DIR"

# --- MODIFIED COPY SECTION START ---
echo "Copying specific configuration items..."

# 1. Copy .roo directory (recursively)
echo "Copying .roo directory..."
# Use -T with cp to copy contents *into* the destination if it exists,
# but here we expect ./ to exist and ./.roo not to, so standard -r is fine.
cp -r "$CLONE_DIR/config/.roo" ./

# 2. Copy specific config files
echo "Copying .roomodes and Python script..."
cp "$CLONE_DIR/config/.roomodes" ./
cp "$CLONE_DIR/config/generate_mcp_yaml.py" ./ # Copy Python script

# --- MODIFIED COPY SECTION END ---


# Python script doesn't need execute permission set here

# Removed CLONED_PY_SCRIPT export, script is now copied locally

# --- MODIFIED CLEANUP SECTION START ---
echo "Cleaning up temporary clone directory ($CLONE_DIR)..."
rm -rf "$CLONE_DIR" # Remove the cloned repo directory

# Removed rm -f insert-variables.cmd   (never copied)
# Removed rm -rf default-mode          (never copied)
# --- MODIFIED CLEANUP SECTION END ---


# Check if essential files exist before running
if [ ! -d ".roo" ]; then
    echo "Error: .roo directory not found after specific copy. Setup failed."
    exit 1
fi
# Check if Python script was copied
if [ ! -f "generate_mcp_yaml.py" ]; then
     echo "Error: generate_mcp_yaml.py not found after specific copy. Setup failed."
     exit 1
fi


# Run the Python script to process templates
echo "Running Python script to process templates..."
# Get OS/Shell/Home/Workspace variables defined earlier
OS_VAL=$(uname -s) # Get OS name (e.g., Linux, Darwin)
if [[ "$OS_VAL" == "Darwin" ]]; then
    OS_VAL="macOS $(sw_vers -productVersion)" # For macOS, get detailed version
elif [[ "$OS_VAL" == "Linux" ]]; then
    OS_VAL="Linux $(uname -r)" # For Linux, get kernel release
else
    OS_VAL=$(uname -s -r) # Fallback for other Unix-like systems
fi
SHELL_VAL="bash"
HOME_VAL="$HOME"
WORKSPACE_VAL="$(pwd)"

echo "Debugging variables before Python script call:"
echo "OS_VAL: \"$OS_VAL\""
echo "SHELL_VAL: \"$SHELL_VAL\""
echo "HOME_VAL: \"$HOME_VAL\""
echo "WORKSPACE_VAL: \"$WORKSPACE_VAL\""
echo ""

python3 generate_mcp_yaml.py --os "$OS_VAL" --shell "$SHELL_VAL" --home "$HOME_VAL" --workspace "$WORKSPACE_VAL"
# Removed deletion of insert-variables.sh
# Removed self-deletion of install_rooflow.sh

echo "--- RooFlow config setup complete ---"
exit 0 # Explicitly exit with success code