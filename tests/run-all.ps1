param(
    [string]$PythonPath = ""
)

$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot
$workspace = Split-Path -Parent $project
$luaJit = Join-Path $project "reference\sider7\soft\LuaJIT-2.1.0-beta3\src\luajit.exe"
$tests = Join-Path $PSScriptRoot "run.lua"
$source = Join-Path $project "modules\FLAccess.lua"
$deployed = Join-Path $workspace "SiderAddons\modules\FLAccess.lua"
$sider = Join-Path $workspace "SiderAddons"
$compatibility = Join-Path $project "tools\check_sider_compatibility.ps1"
$sourceText = Join-Path $project "modules\FLAccess-text"
$deployedText = Join-Path $sider "modules\FLAccess-text"

foreach ($pair in @(
        @($source, $deployed),
        @((Join-Path $sourceText "pt.tsv"), (Join-Path $deployedText "pt.tsv")),
        @((Join-Path $sourceText "en.tsv"), (Join-Path $deployedText "en.tsv")))) {
    $left = (Get-FileHash -LiteralPath $pair[0] -Algorithm SHA256).Hash
    $right = (Get-FileHash -LiteralPath $pair[1] -Algorithm SHA256).Hash
    if ($left -ne $right) {
        throw "Maintained and deployed files differ: $($pair[0]) / $($pair[1])"
    }
}

if (-not (Test-Path -LiteralPath $luaJit)) {
    throw "LuaJIT test runtime missing: $luaJit"
}
foreach ($module in @($source, $deployed)) {
    & $luaJit $tests $module $sider
    if ($LASTEXITCODE -ne 0) {
        throw "Lua behavioral tests failed for $module"
    }
}

& $compatibility

if (-not $PythonPath) {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) {
        $PythonPath = $python.Source
    }
    else {
        $PythonPath = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
    }
}
if (-not (Test-Path -LiteralPath $PythonPath)) {
    throw "Python test runtime missing; pass -PythonPath."
}
Push-Location $workspace
try {
    & $PythonPath -m unittest discover -s "textAssets/tests" -p "test_*.py" -v
    if ($LASTEXITCODE -ne 0) {
        throw "Text extraction/runtime tests failed."
    }
    & $PythonPath -m unittest discover -s "FLAccess/tests" -p "test_*.py" -v
    if ($LASTEXITCODE -ne 0) {
        throw "Widget structure tests failed."
    }
}
finally {
    Pop-Location
}
Write-Output "FLACCESS_OFFLINE_SUITE_OK"
