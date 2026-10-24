# Refreshes assets/wppconnect-wa.js to the release pinned in
# WppConnect.defaultWppVersion. Run after bumping that constant, then commit
# both together so the bundled fallback never lags the pin.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$src = Get-Content "$root\lib\src\wpp\wpp_connect.dart" -Raw
if ($src -notmatch "defaultWppVersion\s*=\s*'([^']+)'") { throw 'defaultWppVersion not found' }
$version = $Matches[1]
$out = "$root\assets\wppconnect-wa.js"
Invoke-WebRequest "https://github.com/wppconnect-team/wa-js/releases/download/$version/wppconnect-wa.js" -OutFile $out
"Bundled wa-js $version ($((Get-Item $out).Length) bytes) -> $out"
