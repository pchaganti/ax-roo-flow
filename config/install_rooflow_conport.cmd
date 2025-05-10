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

set "PS_SCRIPT_CONTENT="
set "PS_SCRIPT_CONTENT=%PS_SCRIPT_CONTENT% $ErrorActionPreference = 'Stop'; "
set "PS_SCRIPT_CONTENT=%PS_SCRIPT_CONTENT% $currentDir = Get-Location; "
set "PS_SCRIPT_CONTENT=%PS_SCRIPT_CONTENT% $rooDir = Join-Path $currentDir '.roo'; "
set "PS_SCRIPT_CONTENT=%PS_SCRIPT_CONTENT% $strategyFile = Join-Path $currentDir 'roo_code_conport_strategy'; "
set "PS_SCRIPT_CONTENT=%PS_SCRIPT_CONTENT% $architectPrompt = 'system-prompt-flow-architect'; "
set "PS_SCRIPT_CONTENT=%PS_SCRIPT_CONTENT% $askPrompt = 'system-prompt-flow-ask'; "
set "PS_SCRIPT_CONTENT=%PS_SCRIPT_CONTENT% $codePrompt = 'system-prompt-flow-code'; "
set "PS_SCRIPT_CONTENT=%PS_SCRIPT_CONTENT% $debugPrompt = 'system-prompt-flow-debug'; "
set "PS_SCRIPT_CONTENT=%PS_SCRIPT_CONTENT% if (-not (Test-Path -Path $rooDir -PathType Container)) { Write-Error ""Error (Update Logic): Directory '$rooDir' not found.""; exit 1; } "
set "PS_SCRIPT_CONTENT=%PS_SCRIPT_CONTENT% if (-not (Test-Path -Path $strategyFile -PathType Leaf)) { Write-Error ""Error (Update Logic): Strategy file '$strategyFile' not found.""; exit 1; } "
set "PS_SCRIPT_CONTENT=%PS_SCRIPT_CONTENT% try { $strategyContent = Get-Content -Path $strategyFile -Raw } catch { Write-Error ""Error reading strategy file '$strategyFile': $($_.Exception.Message)""; exit 1; } "
set "PS_SCRIPT_CONTENT=%PS_SCRIPT_CONTENT% function Process-Replacement { param ([string]$TargetFileName) $TargetFilePath = Join-Path $rooDir $TargetFileName; if (-not (Test-Path -Path $TargetFilePath -PathType Leaf)) { Write-Warning ""Target file '$TargetFilePath' not found. Skipping.""; return; } Write-Host ""Processing (Update Logic) $TargetFilePath for replacement...""; try { $fileContent = Get-Content -Path $TargetFilePath -Raw; $lines = $fileContent -split '(\r?\n)'; $lineNum = -1; for ($i = 0; $i -lt $lines.Length; $i++) { if ($lines[$i] -match '^memory_bank_strategy:') { $lineNum = $i; break; } } if ($lineNum -eq -1) { Write-Warning ""'memory_bank_strategy:' not found in '$TargetFilePath'. Skipping.""; return; } $contentBefore = ''; if ($lineNum -gt 0) { for ($j = 0; $j -lt $lineNum; $j++) { $contentBefore += $lines[$j]; } } $newFileContent = $contentBefore + $strategyContent; Set-Content -Path $TargetFilePath -Value $newFileContent -NoNewline -Encoding UTF8; Write-Host ""Updated (Update Logic) '$TargetFilePath'.""; } catch { Write-Error ""Error processing file '$TargetFilePath': $($_.Exception.Message)""; } } "
set "PS_SCRIPT_CONTENT=%PS_SCRIPT_CONTENT% function Process-Deletion { param ([string]$TargetFileName) $TargetFilePath = Join-Path $rooDir $TargetFileName; if (-not (Test-Path -Path $TargetFilePath -PathType Leaf)) { Write-Warning ""Target file '$TargetFilePath' not found. Skipping.""; return; } Write-Host ""Processing (Update Logic) $TargetFilePath for deletion...""; try { $fileContent = Get-Content -Path $TargetFilePath -Raw; $lines = $fileContent -split '(\r?\n)'; $lineNum = -1; for ($i = 0; $i -lt $lines.Length; $i++) { if ($lines[$i] -match '^memory_bank_strategy:') { $lineNum = $i; break; } } if ($lineNum -eq -1) { Write-Warning ""'memory_bank_strategy:' not found in '$TargetFilePath'. Skipping.""; return; } $contentBefore = ''; if ($lineNum -gt 0) { for ($j = 0; $j -lt $lineNum; $j++) { $contentBefore += $lines[$j]; } } Set-Content -Path $TargetFilePath -Value $contentBefore -NoNewline -Encoding UTF8; Write-Host ""Updated (Update Logic) '$TargetFilePath' (section deleted).""; } catch { Write-Error ""Error processing file '$TargetFilePath': $($_.Exception.Message)""; } } "
set "PS_SCRIPT_CONTENT=%PS_SCRIPT_CONTENT% Process-Replacement -TargetFileName $architectPrompt; "
set "PS_SCRIPT_CONTENT=%PS_SCRIPT_CONTENT% Process-Replacement -TargetFileName $codePrompt; "
set "PS_SCRIPT_CONTENT=%PS_SCRIPT_CONTENT% Process-Replacement -TargetFileName $debugPrompt; "
set "PS_SCRIPT_CONTENT=%PS_SCRIPT_CONTENT% Process-Deletion -TargetFileName $askPrompt; "
set "PS_SCRIPT_CONTENT=%PS_SCRIPT_CONTENT% Write-Host ""--- Roo prompt update with ConPort strategy completed (PowerShell) ---""; "

powershell -NoProfile -ExecutionPolicy Bypass -Command "%PS_SCRIPT_CONTENT%"
if %errorlevel% neq 0 (
    echo Error: PowerShell script for prompt updates failed.
    if exist "%TEMP_CLONE_DIR%" rmdir /s /q "%TEMP_CLONE_DIR%" >nul 2>nul
    exit /b 1
)
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