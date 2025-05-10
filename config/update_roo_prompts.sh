#!/bin/bash

# Script to update Roo system prompts with ConPort strategy

# Define paths
ROO_DIR=".roo"
STRATEGY_FILE="roo_code_conport_strategy" # Assumed to be in the same directory as this script

# Target prompt files (relative to ROO_DIR)
ARCHITECT_PROMPT="system-prompt-flow-architect"
ASK_PROMPT="system-prompt-flow-ask"
CODE_PROMPT="system-prompt-flow-code"
DEBUG_PROMPT="system-prompt-flow-debug"

# --- Error Handling ---
if [ ! -d "$ROO_DIR" ]; then
  echo "Error: Directory '$ROO_DIR' not found in the current path."
  echo "Please ensure you are running this script from your workspace root."
  exit 1
fi

if [ ! -f "$STRATEGY_FILE" ]; then
  echo "Error: Strategy file '$STRATEGY_FILE' not found in the current path."
  echo "Please ensure it is in the same directory as this script (workspace root)."
  exit 1
fi

# --- Function to process files that need replacement ---
process_replacement() {
  local target_file_path="$1"
  local temp_file=$(mktemp)

  if [ ! -f "$target_file_path" ]; then
    echo "Warning: Target file '$target_file_path' not found. Skipping."
    rm "$temp_file" # Clean up temp file if target doesn't exist
    return
  fi

  echo "Processing $target_file_path for replacement..."

  # Find the line number of "memory_bank_strategy:"
  # Using grep -n to get line number, then cut to extract it.
  # Add ^ to match start of line to be more precise.
  line_num=$(grep -n "^memory_bank_strategy:" "$target_file_path" | cut -d: -f1)

  if [ -z "$line_num" ]; then
    echo "Warning: 'memory_bank_strategy:' not found in '$target_file_path'. Skipping replacement."
    rm "$temp_file"
    return
  fi

  # Preserve lines before "memory_bank_strategy:"
  head -n $((line_num - 1)) "$target_file_path" > "$temp_file"

  # Append the new strategy content
  cat "$STRATEGY_FILE" >> "$temp_file"

  # Replace the original file
  mv "$temp_file" "$target_file_path"
  echo "Updated '$target_file_path'."
}

# --- Function to process the file that needs deletion ---
process_deletion() {
  local target_file_path="$1"
  local temp_file=$(mktemp)

  if [ ! -f "$target_file_path" ]; then
    echo "Warning: Target file '$target_file_path' not found. Skipping."
    rm "$temp_file" # Clean up temp file
    return
  fi

  echo "Processing $target_file_path for deletion..."

  line_num=$(grep -n "^memory_bank_strategy:" "$target_file_path" | cut -d: -f1)

  if [ -z "$line_num" ]; then
    echo "Warning: 'memory_bank_strategy:' not found in '$target_file_path'. Skipping deletion."
    rm "$temp_file"
    return
  fi

  # Preserve lines before "memory_bank_strategy:"
  head -n $((line_num - 1)) "$target_file_path" > "$temp_file"

  # Replace the original file (effectively deleting the section)
  mv "$temp_file" "$target_file_path"
  echo "Updated '$target_file_path' (section deleted)."
}

# --- Main processing ---
echo "Starting Roo prompt update process..."

# Process files for replacement
process_replacement "$ROO_DIR/$ARCHITECT_PROMPT"
process_replacement "$ROO_DIR/$CODE_PROMPT"
process_replacement "$ROO_DIR/$DEBUG_PROMPT"

# Process file for deletion
process_deletion "$ROO_DIR/$ASK_PROMPT"

echo "Roo prompt update process completed."