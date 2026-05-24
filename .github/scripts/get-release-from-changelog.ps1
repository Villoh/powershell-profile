[CmdletBinding()]
param(
    [string]$ChangelogPath = 'CHANGELOG.md',
    [string]$ReleaseNotesPath = 'release-notes.md',
    [string]$GitHubOutputPath = $env:GITHUB_OUTPUT  # used inside Add-GitHubOutput
)

if (-not (Test-Path -LiteralPath $ChangelogPath)) {
    throw "Changelog not found: $ChangelogPath"
}

$content = Get-Content -LiteralPath $ChangelogPath -Raw
$pattern = '(?m)^## \[(?!Unreleased\])(?<version>\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?)\](?:\s*-\s*(?<date>\d{4}-\d{2}-\d{2}))?\s*$'
$releaseMatches = [regex]::Matches($content, $pattern)

function Add-GitHubOutput {
    param(
        [string]$Name,
        [string]$Value
    )

    if (-not $GitHubOutputPath) {
        return
    }

    "$Name=$Value" | Add-Content -LiteralPath $GitHubOutputPath
}

if ($releaseMatches.Count -eq 0) {
    Add-GitHubOutput -Name 'release' -Value 'false'
    Add-GitHubOutput -Name 'reason' -Value 'no-version-heading'
    Write-Host 'No released version found in changelog.'
    exit 0
}

$match = $releaseMatches[0]
$version = $match.Groups['version'].Value
$releaseDate = $match.Groups['date'].Value
$tag = "v$version"
$bodyStart = $match.Index + $match.Length
$bodyEnd = if ($releaseMatches.Count -gt 1) { $releaseMatches[1].Index } else { $content.Length }
$body = $content.Substring($bodyStart, $bodyEnd - $bodyStart) -replace '(?m)^\[.*\]:.*$', '' -replace '(?:
?
){3,}', "`n`n" | ForEach-Object { $_.Trim() }
$heading = if ($releaseDate) {
    "## [$version] - $releaseDate"
} else {
    "## [$version]"
}
$releaseNotes = if ($body) {
    "$heading`n`n$body"
} else {
    $heading
}

Set-Content -LiteralPath $ReleaseNotesPath -Value $releaseNotes -Encoding utf8

$isPrerelease = if ($version -match '-') { 'true' } else { 'false' }

Add-GitHubOutput -Name 'release' -Value 'true'
Add-GitHubOutput -Name 'version' -Value $version
Add-GitHubOutput -Name 'tag' -Value $tag
Add-GitHubOutput -Name 'body_path' -Value $ReleaseNotesPath
Add-GitHubOutput -Name 'prerelease' -Value $isPrerelease

Write-Host "Prepared release metadata for $tag"
Write-Host "Release notes path: $ReleaseNotesPath"
