@echo off
setlocal

echo --- Starting RooFlow config setup (with ConPort strategy update) ---

:: --- Dependency Checks ---
echo Checking dependencies...
call :CheckGit
if errorlevel 1 goto DependencyError
call :CheckPython
if errorlevel 1 goto DependencyError
call :CheckPyYAML
if errorlevel 1 goto DependencyError
echo All dependencies found.
:: --- End Dependency Checks ---

set "TEMP_CLONE_DIR=%TEMP%\RooFlowClone_%RANDOM%"
echo Cloning target: %TEMP_CLONE_DIR%

echo Cloning RooFlow repository...
git clone --depth 1 https://github.com/GreatScottyMac/RooFlow "%TEMP_CLONE_DIR%"
if %errorlevel% neq 0 (
    echo Error: Failed to clone RooFlow repository. Check your internet connection and Git setup.
    exit /b 1
)

if not exist "%TEMP_CLONE_DIR%\config" (
    echo Error: RooFlow repository clone seems incomplete. Config directory not found in temp location.
    if exist "%TEMP_CLONE_DIR%" rmdir /s /q "%TEMP_CLONE_DIR%" >nul 2>nul
    exit /b 1
)

:: --- MODIFIED COPY SECTION START ---
echo Copying specific configuration items...
set "COPY_ERROR=0"

echo Copying .roo directory...
robocopy "%TEMP_CLONE_DIR%\config\.roo" "%CD%\.roo" /E /NFL /NDL /NJH /NJS /nc /ns /np
if %errorlevel% gtr 7 (
    echo   ERROR: Failed to copy .roo directory. Robocopy Errorlevel: %errorlevel%
    set "COPY_ERROR=1"
) else (
    echo   Copied .roo directory.
)

if %COPY_ERROR% equ 0 (
    echo Copying .roomodes...
    robocopy "%TEMP_CLONE_DIR%\config" "%CD%" .roomodes /NFL /NDL /NJH /NJS /nc /ns /np
    if %errorlevel% gtr 7 (
        echo   ERROR: Failed to copy .roomodes using robocopy. Errorlevel: %errorlevel%
        set "COPY_ERROR=1"
    ) else (
        echo   Copied .roomodes.
    )
)

if %COPY_ERROR% equ 0 (
    echo Copying generate_mcp_yaml.py...
    copy /Y "%TEMP_CLONE_DIR%\config\generate_mcp_yaml.py" "%CD%\"
    if errorlevel 1 (
        echo   ERROR: Failed to copy generate_mcp_yaml.py.
        set "COPY_ERROR=1"
    ) else (
        echo   Copied generate_mcp_yaml.py.
    )
)

if %COPY_ERROR% equ 0 (
    echo Copying roo_code_conport_strategy...
    copy /Y "%TEMP_CLONE_DIR%\config\roo_code_conport_strategy" "%CD%\"
    if errorlevel 1 (
        echo   ERROR: Failed to copy roo_code_conport_strategy.
        set "COPY_ERROR=1"
    ) else (
        echo   Copied roo_code_conport_strategy.
    )
)

if %COPY_ERROR% equ 1 (
    echo ERROR: One or more essential files/directories could not be copied. Aborting setup.
    if exist "%TEMP_CLONE_DIR%" rmdir /s /q "%TEMP_CLONE_DIR%" >nul 2>nul
    exit /b 1
)
:: --- MODIFIED COPY SECTION END ---

:: Check if the essential copied items exist
if not exist "%CD%\.roo" (
    echo Error: .roo directory not found after specific copy. Setup failed.
    if exist "%TEMP_CLONE_DIR%" rmdir /s /q "%TEMP_CLONE_DIR%" >nul 2>nul
    exit /b 1
)
if not exist "%CD%\generate_mcp_yaml.py" (
    echo Error: generate_mcp_yaml.py not found after specific copy. Setup failed.
    if exist "%TEMP_CLONE_DIR%" rmdir /s /q "%TEMP_CLONE_DIR%" >nul 2>nul
    exit /b 1
)
if not exist "%CD%\roo_code_conport_strategy" (
    echo Error: roo_code_conport_strategy not found after specific copy. Setup failed.
    if exist "%TEMP_CLONE_DIR%" rmdir /s /q "%TEMP_CLONE_DIR%" >nul 2>nul
    exit /b 1
)

echo Running Python script to process templates...
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).Caption"') do set "OS_VAL=%%a"
set "SHELL_VAL=cmd"
set "HOME_VAL=%USERPROFILE%"
set "WORKSPACE_VAL=%CD%"

python generate_mcp_yaml.py --os "%OS_VAL%" --shell "%SHELL_VAL%" --home "%HOME_VAL%" --workspace "%WORKSPACE_VAL%"
if %errorlevel% neq 0 (
    echo Error: Python script generate_mcp_yaml.py failed to execute properly.
    if exist "%TEMP_CLONE_DIR%" rmdir /s /q "%TEMP_CLONE_DIR%" >nul 2>nul
    exit /b 1
)

:: --- EMBEDDED PROMPT UPDATE LOGIC (via PowerShell inline) ---
echo --- Starting Roo prompt update with ConPort strategy (using PowerShell) ---
echo DEBUG: CHECKPOINT AFTER ECHO, BEFORE SET
set "TEMP_PS1_SCRIPT=%TEMP%\RooUpdatePrompts_%RANDOM%.ps1"

(
    echo $ErrorActionPreference = 'Stop';
    echo $currentDir = Get-Location;
    echo $rooDir = Join-Path $currentDir '.roo';
    echo $strategyFile = Join-Path $currentDir 'roo_code_conport_strategy';
    echo $architectPrompt = 'system-prompt-flow-architect';
    echo $askPrompt = 'system-prompt-flow-ask';
    echo $codePrompt = 'system-prompt-flow-code';
    echo $debugPrompt = 'system-prompt-flow-debug';
    echo if ^(-not ^(Test-Path -Path $rooDir -PathType Container^)^) { Write-Error ^('Error ^(Update Logic^): Directory ''''{0}'''' not found.' -f $rooDir^); exit 1; }
    echo if ^(-not ^(Test-Path -Path $strategyFile -PathType Leaf^)^) { Write-Error ^('Error ^(Update Logic^): Strategy file ''''{0}'''' not found.' -f $strategyFile^); exit 1; }
    echo try { $strategyContent = Get-Content -Path $strategyFile -Raw } catch { $actualErrorMessage = $_.Exception.Message; Write-Error ^('Error reading strategy file ''''{0}'''': {1}^' -f $strategyFile, $actualErrorMessage^); exit 1; }
    echo function Process-Replacement {
    echo   param ^([string]$TargetFileName^)
    echo   $TargetFilePath = Join-Path $rooDir $TargetFileName
    echo   if ^(-not ^(Test-Path -Path $TargetFilePath -PathType Leaf^)^) { Write-Warning ^('Target file ''''{0}'''' not found. Skipping.' -f $TargetFilePath^); return; }
    echo   Write-Host ^('Processing ^(Update Logic^) {0} for replacement...' -f $TargetFilePath^)
    echo   try {
    echo     $fileContent = Get-Content -Path $TargetFilePath -Raw
    echo     $lines = $fileContent -split '^^^(\r?\n^^^)'
    echo     $lineNum = -1
    echo     for ^($i = 0; $i -lt $lines.Length; $i++^) { if ^($lines[$i] -match '^^memory_bank_strategy:'^) { $lineNum = $i; break; } }
    echo     if ^($lineNum -eq -1^) { Write-Warning ^('''''memory_bank_strategy:'''' not found in ''''{0}''''. Skipping.' -f $TargetFilePath^); return; }
    echo     $contentBefore = '';
    echo     if ^($lineNum -gt 0^) { for ^($j = 0; $j -lt $lineNum; $j++^) { $contentBefore += $lines[$j]; } }
    echo     $newFileContent = $contentBefore + $strategyContent
    echo     Set-Content -Path $TargetFilePath -Value $newFileContent -NoNewline -Encoding UTF8
    echo     Write-Host ^('Updated ^(Update Logic^) ''''{0}''''.' -f $TargetFilePath^)
    echo   } catch { $actualErrorMessage = $_.Exception.Message; Write-Error ^('Error processing file ''''{0}'''': {1}^' -f $TargetFilePath, $actualErrorMessage^); }
    echo }
    echo function Process-Deletion {
    echo   param ^([string]$TargetFileName^)
    echo   $TargetFilePath = Join-Path $rooDir $TargetFileName
    echo   if ^(-not ^(Test-Path -Path $TargetFilePath -PathType Leaf^)^) { Write-Warning ^('Target file ''''{0}'''' not found. Skipping.' -f $TargetFilePath^); return; }
    echo   Write-Host ^('Processing ^(Update Logic^) {0} for deletion...' -f $TargetFilePath^)
    echo   try {
    echo     $fileContent = Get-Content -Path $TargetFilePath -Raw
    echo     $lines = $fileContent -split '^^^(\r?\n^^^)'
    echo     $lineNum = -1
    echo     for ^($i = 0; $i -lt $lines.Length; $i++^) { if ^($lines[$i] -match '^^memory_bank_strategy:'^) { $lineNum = $i; break; } }
    echo     if ^($lineNum -eq -1^) { Write-Warning ^('''''memory_bank_strategy:'''' not found in ''''{0}''''. Skipping.' -f $TargetFilePath^); return; }
    echo     $contentBefore = '';
    echo     if ^($lineNum -gt 0^) { for ^($j = 0; $j -lt $lineNum; $j++^) { $contentBefore += $lines[$j]; } }
    echo     Set-Content -Path $TargetFilePath -Value $contentBefore -NoNewline -Encoding UTF8
    echo     Write-Host ^('Updated ^(Update Logic^) ''''{0}'''' ^(section deleted^).' -f $TargetFilePath^)
    echo   } catch { $actualErrorMessage = $_.Exception.Message; Write-Error ^('Error processing file ''''{0}'''': {1}^' -f $TargetFilePath, $actualErrorMessage^); }
    echo }
    echo Process-Replacement -TargetFileName $architectPrompt
    echo Process-Replacement -TargetFileName $codePrompt
    echo Process-Replacement -TargetFileName $debugPrompt
    echo Process-Deletion -TargetFileName $askPrompt
    echo Write-Host '--- Roo prompt update with ConPort strategy completed (PowerShell) ---'
) > "%TEMP_PS1_SCRIPT%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP_PS1_SCRIPT%"
if %errorlevel% neq 0 (
    echo Error: PowerShell script for prompt updates failed.
    if exist "%TEMP_PS1_SCRIPT%" del "%TEMP_PS1_SCRIPT%" >nul 2>nul
    if exist "%TEMP_CLONE_DIR%" rmdir /s /q "%TEMP_CLONE_DIR%" >nul 2>nul
    exit /b 1
)
if exist "%TEMP_PS1_SCRIPT%" del "%TEMP_PS1_SCRIPT%" >nul 2>nul
:: --- END EMBEDDED PROMPT UPDATE LOGIC ---

:: Clean up the strategy file from the workspace root
if exist "%CD%\roo_code_conport_strategy" (
    echo Cleaning up roo_code_conport_strategy from workspace root...
    del /F /Q "%CD%\roo_code_conport_strategy" >nul 2>nul
)

:: --- MODIFIED CLEANUP SECTION START ---
echo Cleaning up temporary clone directory...
if exist "%TEMP_CLONE_DIR%" (
    rmdir /s /q "%TEMP_CLONE_DIR%" >nul 2>nul
    if errorlevel 1 (
       echo   Warning: Failed to completely remove temporary clone directory: %TEMP_CLONE_DIR%
    ) else (
       echo   Removed temporary clone directory.
    )
) else ( echo Temp clone directory not found to remove. )
:: --- MODIFIED CLEANUP SECTION END ---

echo --- RooFlow config setup (with ConPort strategy update) complete ---
goto ScriptEnd

:DependencyError
echo A required dependency (Git, Python, or PyYAML) was not found or failed check. Aborting.
if exist "%TEMP_CLONE_DIR%" rmdir /s /q "%TEMP_CLONE_DIR%" >nul 2>nul
exit /b 1

:ScriptEnd
goto :EOF

:: --- Subroutines ---
:CheckGit
where git >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: git is not found in your PATH.
    echo Please install Git and ensure it's added to your system's PATH.
    echo You can download Git from: https://git-scm.com/download/win
    exit /b 1
)
echo   - Git found.
goto :EOF

:CheckPython
where python >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: python is not found in your PATH.
    echo Please install Python 3 ^(https://www.python.org/downloads/^) and ensure it's added to PATH.
    exit /b 1
)
echo   - Python found.
goto :EOF

:CheckPyYAML
python -c "import yaml" >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: PyYAML library is not found for Python.
    echo Please install it using: pip install pyyaml
    exit /b 1
)
echo   - PyYAML library found.
goto :EOF
:: --- End Subroutines ---

endlocal
exit /b 0