# Quality system structure validation hook
# Runs after an agent edits a file. If the file is inside .github/quality/,
# validates the quality system structure and reports issues back to the agent.

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

# Only validate if the touched file is inside .github/quality/
if (-not $filePath -or $filePath -notmatch '[/\\]\.github[/\\]quality[/\\]') {
    exit 0
}

# Resolve quality root
$qualityRoot = Join-Path (Join-Path $hookInput.cwd ".github") "quality"

if (-not (Test-Path $qualityRoot)) {
    exit 0
}

$errors = @()

# 1. sources.md must exist and not be empty
$sourcesFile = Join-Path $qualityRoot "sources.md"
if (-not (Test-Path $sourcesFile)) {
    $errors += "Missing sources.md at quality root"
} else {
    $sourcesContent = Get-Content $sourcesFile -Raw
    if (-not $sourcesContent -or $sourcesContent.Trim().Length -lt 50) {
        $errors += "sources.md appears empty or corrupted (less than 50 characters)"
    }
}

# 2. norms/INDEX.md must exist
$normsDir = Join-Path $qualityRoot "norms"
$normsIndex = Join-Path $normsDir "INDEX.md"
if (-not (Test-Path $normsDir)) {
    $errors += "Missing norms/ subfolder"
} elseif (-not (Test-Path $normsIndex)) {
    $errors += "Missing INDEX.md in norms/"
}

# 3. Every norms .md file must be listed in norms/INDEX.md
if (Test-Path $normsIndex) {
    $indexContent = Get-Content $normsIndex -Raw
    $normsFiles = Get-ChildItem -Path $normsDir -File | Where-Object { $_.Name -ne "INDEX.md" }
    foreach ($file in $normsFiles) {
        if ($indexContent -notmatch [regex]::Escape($file.Name)) {
            $errors += "Norms file not listed in norms/INDEX.md: $($file.Name)"
        }
    }
}

# 4. Every norms .md file (except INDEX.md) must have required sections
$requiredSections = @("## Required", "## Recommended", "## Avoid")
if (Test-Path $normsDir) {
    $normsFiles = Get-ChildItem -Path $normsDir -File | Where-Object { $_.Name -ne "INDEX.md" }
    foreach ($file in $normsFiles) {
        $content = Get-Content $file.FullName -Raw
        foreach ($section in $requiredSections) {
            if ($content -notmatch [regex]::Escape($section)) {
                $errors += "Norms file '$($file.Name)' missing required section: $section"
            }
        }
    }
}

# Output result
if ($errors.Count -gt 0) {
    $message = "Quality system validation failed:`n" + ($errors -join "`n")
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
