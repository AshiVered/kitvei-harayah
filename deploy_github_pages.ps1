# Builds the website and publishes it to GitHub Pages (branch "gh-pages").
#
# The site lives in a separate repository of the account that owns the domain:
#   https://aiv-dev.com/kitvei-harayah/       the project's home page (site/index.template.html)
#   https://aiv-dev.com/kitvei-harayah/app/   the web version of the app
# (AIV-DEV's user site has the custom domain aiv-dev.com, so every Pages project of
#  that account is served at aiv-dev.com/<repo>/ – no DNS changes needed.)
#
# The code, releases and download files stay in <User>/<Repo>.
#
# Usage (PowerShell, from this folder):
#   powershell -ExecutionPolicy Bypass -File deploy_github_pages.ps1 -User AshiVered -SiteOwner AIV-DEV -Repo kitvei-harayah -DirectDownload
#
# Git asks for your GitHub sign-in the first time.
param(
    [Parameter(Mandatory = $true)][string]$User,   # owner of the code repository (release / download links)
    [Parameter(Mandatory = $true)][string]$Repo,
    [string]$SiteOwner = "",   # owner of the repository that serves the site; defaults to -User
    [switch]$SkipBuild,        # reuse an existing build\web (already built with -BaseHref /<repo>/app/)
    [switch]$DirectDownload    # link the download button straight to the release zip (once attached)
)

$ErrorActionPreference = "Stop"
$proj = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($SiteOwner -eq "") { $SiteOwner = $User }

# 1. the web app, served from /<repo>/app/
if (-not $SkipBuild) {
    powershell -ExecutionPolicy Bypass -File (Join-Path $proj "build.ps1") web -BaseHref "/$Repo/app/"
    if ($LASTEXITCODE -ne 0) { throw "Web build failed" }
}

# 2. the home page, with the app inside it
$site = Join-Path $proj "build\site"
if (Test-Path $site) { Remove-Item -Recurse -Force $site }
$siteArgs = @("--user", $User, "--repo", $Repo, "--out", $site)
if ($DirectDownload) { $siteArgs += "--direct-download" }
python (Join-Path $proj "tools\build_site.py") @siteArgs
if ($LASTEXITCODE -ne 0) { throw "Site build failed" }
New-Item -ItemType Directory -Force (Join-Path $site "app") | Out-Null
Copy-Item (Join-Path $proj "build\web\*") (Join-Path $site "app") -Recurse -Force

# 3. commit and push as the gh-pages branch of the site repository
Push-Location $site
try {
    git init -q
    git checkout -q -b gh-pages
    git add -A
    git commit -q -m "Publish website"
    git remote add origin "https://github.com/$SiteOwner/$Repo.git"
    git push -f origin gh-pages
    if ($LASTEXITCODE -ne 0) { throw "git push failed" }
}
finally {
    Pop-Location
}
Write-Host ""
Write-Host "Pushed to https://github.com/$SiteOwner/$Repo (branch gh-pages)."
