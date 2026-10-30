param(
    [string]$ModulePath = "modules\FlAccessReader\FlAccessReader.lua",
    [string]$GameExePath = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = (Resolve-Path (Join-Path $projectRoot $ModulePath)).Path
$luaJit = (Resolve-Path (Join-Path $projectRoot "reference\sider7\soft\LuaJIT-2.1.0-beta3\src\luajit.exe")).Path
$harness = (Resolve-Path (Join-Path $PSScriptRoot "test_sider_sandbox.lua")).Path
$temporarySider = Join-Path $projectRoot ".sider-compat-test"
$temporaryModules = Join-Path $temporarySider "modules"
if (-not $GameExePath) {
    $GameExePath = Join-Path (Split-Path -Parent $projectRoot) "FL_2026.exe"
}

$source = [IO.File]::ReadAllText($sourcePath)
$duplicateDefinitions = [regex]::Matches(
    $source, '(?m)^(?:local\s+)?function\s+([\w.:]+)\s*\(') |
    ForEach-Object { $_.Groups[1].Value } |
    Group-Object | Where-Object Count -gt 1
if ($duplicateDefinitions) {
    throw "Duplicate named Lua definitions: $($duplicateDefinitions.Name -join ', ')"
}
$forbiddenCalls = [regex]::Matches(
    $source,
    '(?m)(?<![\w\.:])(?:pcall|xpcall|require|dofile|loadfile|loadstring|setfenv|getfenv|rawget|rawset|rawequal|setmetatable|getmetatable)\s*\(')
$forbiddenLibraries = [regex]::Matches(
    $source,
    '(?m)(?<![\w\.])(?:package|debug|coroutine)\s*\.')
if ($forbiddenCalls.Count -gt 0 -or $forbiddenLibraries.Count -gt 0) {
    throw "The module uses globals that are unavailable in the Sider sandbox."
}
if ([regex]::IsMatch(
        $source,
        '(?m)(?<![\w\.])read_msvc_string\s*\(')) {
    throw "read_msvc_string must be called through a11y in early callbacks."
}

$topLevelLocals = ([regex]::Matches($source, '(?m)^local\s+')).Count
if ($topLevelLocals -gt 200) {
    throw "LuaJIT chunk local limit exceeded: $topLevelLocals"
}

& $luaJit -e "assert(loadfile([[$($sourcePath.Replace('\', '/'))]])); print('LUAJIT_LOADFILE_OK')"
if ($LASTEXITCODE -ne 0) {
    throw "LuaJIT syntax validation failed."
}

New-Item -ItemType Directory -Path $temporaryModules -Force | Out-Null
try {
    $prismRuntime = Join-Path $projectRoot "modules\FlAccessReader"
    if (-not (Test-Path -LiteralPath (Join-Path $prismRuntime "bin\prism.dll"))) {
        throw "Native Prism runtime is missing from modules\FlAccessReader\bin."
    }
    Copy-Item -LiteralPath $prismRuntime -Destination $temporaryModules -Recurse -Force
    $temporaryText = Join-Path $temporarySider "livecpk\FlAccessReader"
    New-Item -ItemType Directory -Path $temporaryText -Force | Out-Null
    $textRuntime = Join-Path $projectRoot "livecpk\FlAccessReader\text"
    if (-not (Test-Path -LiteralPath (Join-Path $textRuntime "pt.tsv")) -or
            -not (Test-Path -LiteralPath (Join-Path $textRuntime "en.tsv"))) {
        throw "Runtime text assets are missing from livecpk\FlAccessReader\text."
    }
    Copy-Item -LiteralPath $textRuntime -Destination $temporaryText -Recurse -Force
    & $luaJit $harness $sourcePath $temporarySider
    if ($LASTEXITCODE -ne 0) {
        throw "Sider sandbox initialization failed."
    }
}
finally {
    if (Test-Path -LiteralPath $temporarySider) {
        $resolvedProject = (Resolve-Path $projectRoot).Path
        $resolvedTemporary = (Resolve-Path $temporarySider).Path
        if (-not $resolvedTemporary.StartsWith(
                $resolvedProject + [IO.Path]::DirectorySeparatorChar)) {
            throw "Temporary compatibility directory escaped the project."
        }
        Remove-Item -LiteralPath $resolvedTemporary -Recurse -Force
    }
}

Write-Output "SIDER_COMPATIBILITY_OK locals=$topLevelLocals"

if (Test-Path -LiteralPath $GameExePath) {
    $expectedPrologues = [ordered]@{
        0x1496a3c = "488bd0488bcb488b5c24304883c420"
        0x0e59f80 = "48895c2418488974242041564883ec20"
        0x0e5a190 = "48895c241048896c2418574883ec20"
        0x0e49070 = "488bc45556574881ec0001000048c7442420feffffff"
        0x0e48af0 = "48895c24084889742410574883ec20"
        0x0e7a990 = "488bc455574156488d68d84881ec10010000"
        0x0c97408 = "458b074d8d4f40488b4c2478488bd0"
        0x0c978b5 = "904533c94533c0488d542430488bcf"
        0x0c97c32 = "904533c94533c0488d55e7488bcf"
        0x0c97ca8 = "904533c94533c0488d55e7488bcf"
        0x0b22a50 = "48895c2408574883ec308bda488bf9"
        0x0b229f0 = "48895c2408574883ec308bda488bf9"
        0x0b22871 = "488b93a8000000488bcb8bf08b3cb2"
        0x0c6d770 = "0f10020f11010f104a100f114910"
        0x08e1e47 = "488b402c488902488bc2c3cccccc"
        0x08f8392 = "488d4c2430ba0d0000000f1f4000"
    }
    $stream = [IO.File]::OpenRead((Resolve-Path $GameExePath).Path)
    $reader = [IO.BinaryReader]::new($stream)
    try {
        $stream.Position = 0x3c
        $peOffset = $reader.ReadInt32()
        $stream.Position = $peOffset + 6
        $sectionCount = $reader.ReadUInt16()
        $stream.Position = $peOffset + 20
        $optionalHeaderSize = $reader.ReadUInt16()
        $sectionTable = $peOffset + 24 + $optionalHeaderSize
        $sections = @()
        for ($index = 0; $index -lt $sectionCount; $index++) {
            $stream.Position = $sectionTable + 40 * $index + 8
            $virtualSize = $reader.ReadUInt32()
            $virtualAddress = $reader.ReadUInt32()
            $rawSize = $reader.ReadUInt32()
            $rawPointer = $reader.ReadUInt32()
            $sections += [pscustomobject]@{
                VirtualAddress = $virtualAddress
                Size = [Math]::Max($virtualSize, $rawSize)
                RawPointer = $rawPointer
            }
        }
        foreach ($entry in $expectedPrologues.GetEnumerator()) {
            $rva = [uint32]$entry.Key
            $section = $sections | Where-Object {
                $rva -ge $_.VirtualAddress -and
                $rva -lt $_.VirtualAddress + $_.Size
            } | Select-Object -First 1
            if (-not $section) {
                throw "No PE section contains hook RVA 0x$($rva.ToString('x'))."
            }
            $expected = $entry.Value
            $stream.Position = $section.RawPointer + ($rva - $section.VirtualAddress)
            $bytes = $reader.ReadBytes($expected.Length / 2)
            $actual = ([BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant()
            if ($actual -ne $expected) {
                throw "FL_2026 hook mismatch at RVA 0x$($rva.ToString('x'))."
            }
        }
    }
    finally {
        $reader.Dispose()
        $stream.Dispose()
    }
    Write-Output "FL_2026_PROLOGUES_OK count=$($expectedPrologues.Count)"
}
