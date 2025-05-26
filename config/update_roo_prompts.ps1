# Script to update Roo system prompts with ConPort strategy

# Define paths
$rooDir = ".roo"
$strategyFile = "roo_code_conport_strategy" # Assumed to be in the same directory as this script (workspace root)

# Target prompt files (relative to rooDir)
$architectPrompt = "system-prompt-flow-architect"
$askPrompt = "system-prompt-flow-ask"
$codePrompt = "system-prompt-flow-code"
$debugPrompt = "system-prompt-flow-debug"
$orchestratorPrompt = "system-prompt-flow-orchestrator"

# --- Error Handling ---
if (-not (Test-Path -Path $rooDir -PathType Container)) {
    Write-Error "Error: Directory '$rooDir' not found in the current path."
    Write-Host "Please ensure you are running this script from your workspace root."
    exit 1
}

if (-not (Test-Path -Path $strategyFile -PathType Leaf)) {
    Write-Error "Error: Strategy file '$strategyFile' not found in the current path."
    Write-Host "Please ensure it is in the same directory as this script (workspace root)."
    exit 1
}

# Read the strategy content once
try {
    $strategyContent = Get-Content -Path $strategyFile -Raw
}
catch {
    Write-Error "Error reading strategy file '$strategyFile': $($_.Exception.Message)"
    exit 1
}

# --- Function to process files that need replacement ---
function Process-Replacement {
    param (
        [string]$TargetFilePath
    )

    if (-not (Test-Path -Path $TargetFilePath -PathType Leaf)) {
        Write-Warning "Target file '$TargetFilePath' not found. Skipping."
        return
    }

    Write-Host "Processing $TargetFilePath for replacement..."

    try {
        $fileContent = Get-Content -Path $TargetFilePath -Raw
        $lines = $fileContent -split '(\r?\n)' # Split and keep newlines
        $lineNum = -1

        for ($i = 0; $i -lt $lines.Length; $i++) {
            if ($lines[$i] -match "^memory_bank_strategy:") {
                $lineNum = $i
                break
            }
        }

        if ($lineNum -eq -1) {
            Write-Warning "'memory_bank_strategy:' not found in '$TargetFilePath'. Skipping replacement."
            return
        }

        # Get content before the target line
        $contentBefore = ""
        if ($lineNum -gt 0) {
             # Join the lines before the identified line number
             # We need to reconstruct the string with newlines
            for ($j = 0; $j -lt $lineNum; $j++) {
                $contentBefore += $lines[$j]
            }
        }
        
        # Ensure there's a newline if contentBefore is not empty and doesn't end with one
        if (($contentBefore.Length -gt 0) -and (-not ($contentBefore.EndsWith("`n") -or $contentBefore.EndsWith("`r`n")))) {
            # Determine newline type from original content if possible, otherwise default
            $newlineChar = if ($fileContent -match '\r\n') { "`r`n" } else { "`n" }
            # $contentBefore += $newlineChar # This was adding an extra line, the strategy file already starts with the key
        }


        # New content is content before + strategy content
        $newFileContent = $contentBefore + $strategyContent
        
        Set-Content -Path $TargetFilePath -Value $newFileContent -NoNewline -Encoding UTF8
        Write-Host "Updated '$TargetFilePath'."
    }
    catch {
        Write-Error "Error processing file '$TargetFilePath': $($_.Exception.Message)"
    }
}

# --- Function to process the file that needs deletion ---
function Process-Deletion {
    param (
        [string]$TargetFilePath
    )

    if (-not (Test-Path -Path $TargetFilePath -PathType Leaf)) {
        Write-Warning "Target file '$TargetFilePath' not found. Skipping."
        return
    }

    Write-Host "Processing $TargetFilePath for deletion..."

    try {
        $fileContent = Get-Content -Path $TargetFilePath -Raw
        $lines = $fileContent -split '(\r?\n)' # Split and keep newlines
        $lineNum = -1

        for ($i = 0; $i -lt $lines.Length; $i++) {
            if ($lines[$i] -match "^memory_bank_strategy:") {
                $lineNum = $i
                break
            }
        }

        if ($lineNum -eq -1) {
            Write-Warning "'memory_bank_strategy:' not found in '$TargetFilePath'. Skipping deletion."
            return
        }
        
        $contentBefore = ""
        if ($lineNum -gt 0) {
            for ($j = 0; $j -lt $lineNum; $j++) {
                $contentBefore += $lines[$j]
            }
        }
        
        # Remove trailing newline from contentBefore if it exists to prevent double newlines
        # if ($contentBefore.EndsWith("`r`n")) {
        #     $contentBefore = $contentBefore.Substring(0, $contentBefore.Length - 2)
        # } elseif ($contentBefore.EndsWith("`n")) {
        #     $contentBefore = $contentBefore.Substring(0, $contentBefore.Length - 1)
        # }

        Set-Content -Path $TargetFilePath -Value $contentBefore -NoNewline -Encoding UTF8
        Write-Host "Updated '$TargetFilePath' (section deleted)."
    }
    catch {
        Write-Error "Error processing file '$TargetFilePath': $($_.Exception.Message)"
    }
}

# --- Main processing ---
Write-Host "Starting Roo prompt update process..."

# Process files for replacement
Process-Replacement -TargetFilePath (Join-Path $rooDir $architectPrompt)
Process-Replacement -TargetFilePath (Join-Path $rooDir $codePrompt)
Process-Replacement -TargetFilePath (Join-Path $rooDir $debugPrompt)
Process-Replacement -TargetFilePath (Join-Path $rooDir $orchestratorPrompt)

# Process file for deletion
Process-Deletion -TargetFilePath (Join-Path $rooDir $askPrompt)

Write-Host "Roo prompt update process completed."