# Builds the website and publishes it to GitHub Pages (branch "gh-pages").
#
#   https://<user>.github.io/<repo>/      the project's home page (site/index.template.html)
#   https://<user>.github.io/<repo>/app/  the web version of the app
#
# Usage (PowerShell, from this folder):
#   powershell -ExecutionPolicy Bypass -File deploy_github_pages.ps1 -User AshiVered -Repo kitvei-harayah
#
# Git asks for your GitHub sign-in the first time.
param(
    [Parameter(Mandatory = $true)][string]$User,
    [Parameter(Mandatory = $true)][string]$Repo,
    [switch]$SkipBuild   # reuse an existing build\web (already built with -BaseHref /<repo>/app/)
)

$ErrorActionPreference = "Stop"
$proj = Split-Path -Parent $MyInvocation.MyCommand.Path

# 1. the web app, served from /<repo>/app/
if (-not $SkipBuild) {
    powershell -ExecutionPolicy Bypass -File (Join-Path $proj "build.ps1") web -BaseHref "/$Repo/app/"
    if ($LASTEXITCODE -ne 0) { throw "Web build failed" }
}

# 2. the home page, with the app inside it
$site = Join-Path $proj "build\site"
if (Test-Path $site) { Remove-Item -Recurse -Force $site }
python (Join-Path $proj "tools\build_site.py") --user $User --repo $Repo --out $site
if ($LASTEXITCODE -ne 0) { throw "Site build failed" }
New-Item -ItemType Directory -Force (Join-Path $site "app") | Out-Null
Copy-Item (Join-Path $proj "build\web\*") (Join-Path $site "app") -Recurse -Force

# 3. commit and push as the gh-pages branch
Push-Location $site
try {
    git init -q
    git checkout -q -b gh-pages
    git add -A
    git commit -q -m "Publish website"
    git remote add origin "https://github.com/$User/$Repo.git"
    git push -f origin gh-pages
    if ($LASTEXITCODE -ne 0) { throw "git push failed" }
}
finally {
    Pop-Location
}
Write-Host ""
Write-Host "Site: https://$User.github.io/$Repo/   (app: https://$User.github.io/$Repo/app/)"
