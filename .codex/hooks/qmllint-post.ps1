# Codex PostToolUse: stdin JSON -> changed QML paths -> format/lint -> JSON context.
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$messages = [Collections.Generic.List[string]]::new()
function Find-QtTool([string]$name) {
    if ($env:QT_BIN_DIR) {
        $candidate = Join-Path $env:QT_BIN_DIR "$name.exe"
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    $cmd = Get-Command "$name.exe" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($base in @('C:/Qt_eval', 'C:/Qt', (Join-Path $env:USERPROFILE 'Qt'))) {
        $found = Get-ChildItem "$base/6.*/*/bin/$name.exe" -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}
function Run-Qt([string]$exe, [string[]]$arguments) {
    # Native warnings are diagnostics, not PowerShell terminating errors.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = (& $exe @arguments 2>&1 | Out-String).Trim()
        $code = $LASTEXITCODE
        return @{ Output = $output; Code = $code }
    } finally { $ErrorActionPreference = $previous }
}
try {
    $event = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $cwd = if ($event.cwd) { $event.cwd } else { $root }
    $paths = [Collections.Generic.List[string]]::new()
    if ($event.tool_input.file_path) { $paths.Add($event.tool_input.file_path) }
    if ($event.tool_response.filePath) { $paths.Add($event.tool_response.filePath) }
    $patch = if ($event.tool_input -is [string]) { $event.tool_input } else { $event.tool_input.command }
    if (-not $patch) { $patch = $event.tool_input.input }
    foreach ($line in ($patch -split "`r?`n")) {
        if ($line -match '^\*\*\* (?:Add File|Update File|Move to): (.+)$') { $paths.Add($Matches[1]) }
    }
    $format = Find-QtTool 'qmlformat'
    $lint = Find-QtTool 'qmllint'
    foreach ($path in ($paths | Select-Object -Unique)) {
        if ([IO.Path]::GetExtension($path) -ine '.qml') { continue }
        $file = if ([IO.Path]::IsPathRooted($path)) { [IO.Path]::GetFullPath($path) } else { [IO.Path]::GetFullPath((Join-Path $cwd $path)) }
        if (-not $file.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { continue }
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
        $details = [Collections.Generic.List[string]]::new()
        if ($format) {
            $before = [Convert]::ToBase64String([Security.Cryptography.SHA256]::Create().ComputeHash([IO.File]::ReadAllBytes($file)))
            $result = Run-Qt $format @('-i', $file)
            if ($result.Code -ne 0) { $details.Add("qmlformat failed ($($result.Code)): $($result.Output)") }
            elseif ($before -ne [Convert]::ToBase64String([Security.Cryptography.SHA256]::Create().ComputeHash([IO.File]::ReadAllBytes($file)))) { $details.Add('qmlformat: formatted') }
            else { $details.Add('qmlformat: unchanged') }
        } else { $details.Add('qmlformat missing; set QT_BIN_DIR') }
        if ($lint) {
            $build = $null
            $dir = Split-Path $file -Parent
            while ($dir -and $dir.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
                if (Test-Path -LiteralPath (Join-Path $dir 'build')) { $build = Join-Path $dir 'build'; break }
                $parent = Split-Path $dir -Parent
                if ($parent -eq $dir) { break }; $dir = $parent
            }
            $argsForLint = @($file)
            $tempRsp = $null
            if ($build) {
                $argsForLint = @('-I', $build, $file)
                foreach ($rsp in (Get-ChildItem $build -Recurse -Filter '*.rsp' -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match '[\\/]\.rcc[\\/]qmllint[\\/]' -and $_.Name -notmatch '_(json|module)\.rsp$' })) {
                    $tokens = @(Get-Content -LiteralPath $rsp.FullName | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                    $match = $tokens | Where-Object { $_.Trim('"').Replace('/', '\') -ieq $file.Replace('/', '\') }
                    if ($match) {
                        $tempRsp = [IO.Path]::GetTempFileName()
                        $flags = @($tokens | Where-Object { $_.Trim('"') -notmatch '\.qml$' })
                        [IO.File]::WriteAllLines($tempRsp, [string[]]($flags + ('"' + $file.Replace('\', '/') + '"')), [Text.UTF8Encoding]::new($false))
                        $argsForLint = @('@' + $tempRsp); break
                    }
                }
            }
            try { $result = Run-Qt $lint $argsForLint } finally { if ($tempRsp) { Remove-Item -LiteralPath $tempRsp } }
            if ($result.Output -or $result.Code -ne 0) {
                $details.Add("qmllint exit $($result.Code): $($result.Output)")
                $messages.Add("${file}: $($result.Output) (exit $($result.Code))")
            } else { $details.Add('qmllint: no warnings') }
        } else { $details.Add('qmllint missing; set QT_BIN_DIR'); $messages.Add('qmllint missing; set QT_BIN_DIR') }
        $entry = "`n## $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $path`n$($details -join "`n")`n"
        [IO.File]::AppendAllText((Join-Path $root '.codex/hook-log.md'), $entry, [Text.UTF8Encoding]::new($false))
    }
} catch { $messages.Add("qml-check hook failed: $($_.Exception.Message)") }
if ($messages.Count) {
    @{ hookSpecificOutput = @{ hookEventName = 'PostToolUse'; additionalContext = ($messages -join "`n") } } | ConvertTo-Json -Depth 5 -Compress
}
exit 0
