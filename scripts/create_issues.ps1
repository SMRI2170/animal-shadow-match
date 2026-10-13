$ErrorActionPreference = 'Stop'
$repo = 'SMRI2170/animal-shadow-match'
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'Install GitHub CLI (gh) first.' }
gh auth status
if ($LASTEXITCODE -ne 0) { throw 'Authenticate gh first: gh auth login' }
Get-ChildItem 'docs/issues/*-task.md' | Sort-Object Name | ForEach-Object {
    $title = (Get-Content $_.FullName -TotalCount 1) -replace '^# ',''
    Write-Host "Creating: $title"
    gh issue create --repo $repo --title $title --body-file $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "Could not create issue: $title" }
}
