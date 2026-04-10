# Memory structure validation hook
# Runs after an agent edits a file. If the file is inside .github/memory/,
# validates the memory structure and reports issues back to the agent.

$ErrorActionPreference = "Continue"

# Read hook input from stdin
try {
    $inputJson = [Console]::In.ReadToEnd()
} catch {
    exit 0
}
if (-not $inputJson -or $inputJson.Trim() -eq "") { exit 0 }

try {
    $hookInput = $inputJson | ConvertFrom-Json
} catch {
    exit 0
}

# Determine the file path that was touched
$filePath = $null
if ($hookInput.tool_input.filePath) {
    $filePath = $hookInput.tool_input.filePath
}
elseif ($hookInput.tool_input.file_path) {
    $filePath = $hookInput.tool_input.file_path
}

# Only validate if the touched file is inside .github/memory/
if (-not $filePath -or $filePath -notmatch '[/\\]\.github[/\\]memory[/\\]') {
    exit 0
}

# Resolve memory root
$memoryRoot = Join-Path (Join-Path $hookInput.cwd ".github") "memory"

if (-not (Test-Path $memoryRoot)) {
    exit 0
}

$errors = @()

# 1. Root INDEX.md must exist
$rootIndex = Join-Path $memoryRoot "INDEX.md"
if (-not (Test-Path $rootIndex)) {
    $errors += "Missing INDEX.md at memory root"
}

# 2. Root README.md must exist
$rootReadme = Join-Path $memoryRoot "README.md"
if (-not (Test-Path $rootReadme)) {
    $errors += "Missing README.md at memory root"
}

# 3. Every subfolder must have its own INDEX.md
$subfolders = Get-ChildItem -Path $memoryRoot -Directory -Recurse
foreach ($folder in $subfolders) {
    $subIndex = Join-Path $folder.FullName "INDEX.md"
    if (-not (Test-Path $subIndex)) {
        $relativePath = $folder.FullName.Substring($memoryRoot.Length + 1)
        $errors += "Missing INDEX.md in subfolder: $relativePath"
    }
}

# 4. File names must be lowercase kebab-case (except INDEX.md and README.md)
$allFiles = Get-ChildItem -Path $memoryRoot -File -Recurse
foreach ($file in $allFiles) {
    if ($file.Name -in @("INDEX.md", "README.md")) { continue }
    if ($file.Name -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*\.md$') {
        $relativePath = $file.FullName.Substring($memoryRoot.Length + 1)
        $errors += "Invalid filename (must be lowercase kebab-case): $relativePath"
    }
}

# 5. Every file and subfolder must be listed in its parent INDEX.md
function Test-IndexEntries {
    param([string]$Dir)

    $indexPath = Join-Path $Dir "INDEX.md"
    if (-not (Test-Path $indexPath)) { return }

    $indexContent = Get-Content $indexPath -Raw

    # Check files (exclude INDEX.md and README.md)
    $files = Get-ChildItem -Path $Dir -File | Where-Object { $_.Name -notin @("INDEX.md", "README.md") }
    foreach ($file in $files) {
        if ($indexContent -notmatch [regex]::Escape($file.Name)) {
            $relativePath = $file.FullName.Substring($memoryRoot.Length + 1)
            $script:errors += "File not listed in INDEX.md: $relativePath"
        }
    }

    # Check subfolders
    $folders = Get-ChildItem -Path $Dir -Directory
    foreach ($folder in $folders) {
        $folderRef = $folder.Name + "/"
        if ($indexContent -notmatch [regex]::Escape($folderRef)) {
            $relativePath = $folder.FullName.Substring($memoryRoot.Length + 1)
            $script:errors += "Subfolder not listed in INDEX.md: $relativePath"
        }
    }
}

Test-IndexEntries -Dir $memoryRoot
foreach ($folder in $subfolders) {
    Test-IndexEntries -Dir $folder.FullName
}

# Output result
if ($errors.Count -gt 0) {
    $message = "Memory validation failed:`n" + ($errors -join "`n")
    $output = @{
        hookSpecificOutput = @{
            hookEventName     = "PostToolUse"
            additionalContext = $message
        }
    } | ConvertTo-Json -Depth 3
    Write-Output $output
    exit 0
}

exit 0
