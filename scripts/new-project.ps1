<#
.SYNOPSIS
    Creates a new project from this template: copies it (without build output
    or git history), renames the executable, and runs `git init`.
.EXAMPLE
    ./scripts/new-project.ps1 -Name my-game
    ./scripts/new-project.ps1 -Name my-game -Destination D:\code
#>
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z][a-z0-9_-]*$')]
    [string]$Name,

    # Folder the project is created in. Defaults to the folder holding this template.
    [string]$Destination
)
$ErrorActionPreference = 'Stop'
$template = Split-Path -Parent $PSScriptRoot
if (-not $Destination) { $Destination = Split-Path -Parent $template }
$target = Join-Path $Destination $Name
if (Test-Path $target) { throw "$target already exists." }

# robocopy: /E recurse; /XD and /XF skip build output, git history, local files.
robocopy $template $target /E /NFL /NDL /NJH /NJS /NP `
    /XD target dist .git vcpkg_installed .vs .cache `
    /XF compile_commands.json .env | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }

$utf8 = New-Object Text.UTF8Encoding $false
function Edit-File([string]$relative, [string]$pattern, [string]$replacement) {
    $path = Join-Path $target $relative
    $text = [IO.File]::ReadAllText($path)
    $new = [regex]::Replace($text, $pattern, $replacement, 1)
    if ($new -eq $text) { throw "Pattern '$pattern' not found in $relative" }
    [IO.File]::WriteAllText($path, $new, $utf8)
}

# The executable is named after the project; the package stays `app`.
Edit-File 'crates\app\Cargo.toml' '(?m)(\[\[bin\]\]\r?\nname = )"app"' "`$1`"$Name`""
Edit-File 'justfile' '(?m)^bin := "app"' "bin := `"$Name`""
Edit-File '.vscode\launch.json' 'target/debug/app\.exe' "target/debug/$Name.exe"
Edit-File 'README.md' '(?m)^# .*$' "# $Name"

if (Get-Command git -ErrorAction SilentlyContinue) {
    git -C $target init --quiet --initial-branch=main
}

Write-Host "Created $target" -ForegroundColor Green
Write-Host @"

Next:
  cd "$target"
  just doctor      # check the toolchain
  just run         # builds C++ deps on first run (cached by vcpkg afterwards)

When you no longer need the example bridge, delete crates/ffi/cpp-example, its
line in Cargo.toml [workspace.dependencies], its use in crates/app, and "fmt" in vcpkg.json.
"@
