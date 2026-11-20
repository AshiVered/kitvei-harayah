# Builds Kitvei HaRaayah for Windows (desktop) and/or the web.
# The Windows toolchain fails on non-ASCII folder names (e.g. "תוכנה"),
# so the project folder is temporarily mapped to an ASCII drive letter.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File build.ps1 windows
#   powershell -ExecutionPolicy Bypass -File build.ps1 web -BaseHref /kitvei-harayah/
#   powershell -ExecutionPolicy Bypass -File build.ps1 all -BaseHref /kitvei-harayah/
#
# -BaseHref is the path the site is served from: "/<repository-name>/" for a GitHub Pages
# project site (https://<user>.github.io/<repository-name>/), or "/" for a custom domain
# or a <user>.github.io repository.
param(
    [string]$Target = "all",
    [string]$BaseHref = "/kitvei-harayah/"
)

$ErrorActionPreference = "Stop"
$proj = Split-Path -Parent $MyInvocation.MyCommand.Path
$drive = "K:"
if (Test-Path "$drive\") { subst $drive /D | Out-Null }
subst $drive (Split-Path -Parent $proj)
$work = Join-Path "$drive\" (Split-Path -Leaf $proj)

function Remove-Dirs([string[]]$dirs) {
    foreach ($d in $dirs) {
        $p = Join-Path $work $d
        if (Test-Path $p) { Remove-Item -Recurse -Force $p }
    }
}

try {
    Push-Location $work
    # CMake caches the absolute path; drop it if it was generated from another path.
    $cache = Join-Path $work "build\windows\x64\CMakeCache.txt"
    if ((Test-Path $cache) -and -not (Select-String -Path $cache -SimpleMatch "$drive/" -Quiet)) {
        Remove-Dirs @("build\windows", "windows\flutter\ephemeral", ".dart_tool\flutter_build")
    }
    flutter pub get
    if ($Target -in @("windows", "all")) {
        # Start clean: debug/test builds leave kernel_blob.bin and stale assets behind.
        Remove-Dirs @("build\windows\x64\runner\Release", "build\flutter_assets")
        flutter build windows --release
        Write-Host "Windows: $proj\build\windows\x64\runner\Release\kitvei_harayah.exe"
    }
    if ($Target -in @("web", "all")) {
        if (-not $BaseHref.StartsWith("/")) { $BaseHref = "/$BaseHref" }
        if (-not $BaseHref.EndsWith("/")) { $BaseHref = "$BaseHref/" }
        Remove-Dirs @("build\web")
        # --no-web-resources-cdn: load the rendering engine (CanvasKit) from the site itself
        # rather than from Google's CDN – one host to reach, and nothing for a filter to block.
        flutter build web --release --base-href $BaseHref --no-wasm-dry-run --no-web-resources-cdn
        # GitHub Pages runs Jekyll by default, which skips some files; turn it off.
        New-Item -ItemType File -Force (Join-Path $work "build\web\.nojekyll") | Out-Null
        Write-Host "Web ($BaseHref): $proj\build\web"
    }
}
finally {
    Pop-Location
    subst $drive /D | Out-Null
}
