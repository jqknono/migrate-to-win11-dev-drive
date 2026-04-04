$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $here

. (Join-Path $repoRoot 'Setup-DevDriveCache.ps1')

Describe 'Restore-FolderFromLink' {
    BeforeEach {
        Mock Reset-ProgressUI {}
        Mock Write-ColoredOutput {}
    }

    It 'restores a junction after robocopy move removes the cache folder' {
        $testRoot = Join-Path $env:TEMP ('dev-drive-restore-test-' + [guid]::NewGuid().ToString('N'))
        $restoreRoot = Join-Path $testRoot 'profile'
        $sourcePath = Join-Path $restoreRoot '.wind'
        $targetPath = Join-Path $testRoot 'devdrive\.wind'
        $nestedDir = Join-Path $targetPath 'config'
        $nestedFile = Join-Path $nestedDir 'settings.json'

        try {
            New-Item -ItemType Directory -Path $restoreRoot -Force | Out-Null
            New-Item -ItemType Directory -Path $nestedDir -Force | Out-Null
            Set-Content -LiteralPath $nestedFile -Value '{"theme":"dark"}'
            New-Item -ItemType Junction -Path $sourcePath -Target $targetPath | Out-Null

            $result = Restore-FolderFromLink -SourcePath $sourcePath -SkipConfirmation

            $result | Should Be $true
            (Test-Path -LiteralPath $sourcePath) | Should Be $true
            (Test-IsDirectoryLink -Path $sourcePath) | Should Be $false
            (Test-Path -LiteralPath $targetPath) | Should Be $false
            ((Get-Content -LiteralPath (Join-Path $sourcePath 'config\\settings.json') -Raw).Trim()) | Should Be '{"theme":"dark"}'
        } finally {
            if (Test-Path -LiteralPath $testRoot) {
                Remove-Item -LiteralPath $testRoot -Recurse -Force
            }
        }
    }
}
