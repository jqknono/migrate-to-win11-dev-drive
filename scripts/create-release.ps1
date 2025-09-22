#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Create a new release for the Dev Drive Cache Migration Script

.DESCRIPTION
    This script creates a new git tag and optionally triggers the GitHub Actions release workflow.

.PARAMETER Version
    The version number for the new release (e.g., "1.0.4")

.PARAMETER CreateTag
    Create a git tag for the specified version

.PARAMETER PushTag
    Push the tag to remote repository (will trigger GitHub Actions)

.PARAMETER UpdateScriptVersion
    Update the version in Setup-DevDriveCache.ps1 script

.EXAMPLE
    .\create-release.ps1 -Version "1.0.4" -CreateTag -PushTag -UpdateScriptVersion

.EXAMPLE
    .\create-release.ps1 -Version "1.0.4" -CreateTag -UpdateScriptVersion
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,

    [switch]$CreateTag,
    [switch]$PushTag,
    [switch]$UpdateScriptVersion
)

# Validate version format
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    Write-Error "Version must be in format X.Y.Z (e.g., 1.0.4)"
    exit 1
}

# Check if Setup-DevDriveCache.ps1 exists
if (-not (Test-Path "Setup-DevDriveCache.ps1")) {
    Write-Error "Setup-DevDriveCache.ps1 not found in current directory"
    exit 1
}

# Update script version if requested
if ($UpdateScriptVersion) {
    Write-Host "Updating version in Setup-DevDriveCache.ps1 to $Version..." -ForegroundColor Cyan

    $content = Get-Content "Setup-DevDriveCache.ps1" -Raw
    $newContent = $content -replace '\$script:ScriptVersion = "[^"]+"', "`$script:ScriptVersion = `"$Version`""

    if ($content -ne $newContent) {
        Set-Content "Setup-DevDriveCache.ps1" $newContent -NoNewline
        Write-Host "✅ Version updated successfully" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Version already set to $Version" -ForegroundColor Yellow
    }
}

# Create git tag if requested
if ($CreateTag) {
    $tagName = "v$Version"

    # Check if tag already exists
    $existingTag = git tag -l $tagName
    if ($existingTag) {
        Write-Error "Tag $tagName already exists"
        exit 1
    }

    Write-Host "Creating git tag $tagName..." -ForegroundColor Cyan

    # Check if there are uncommitted changes
    $status = git status --porcelain
    if ($status) {
        Write-Host "⚠️  There are uncommitted changes:" -ForegroundColor Yellow
        Write-Host $status
        $response = Read-Host "Do you want to commit changes first? (Y/N)"
        if ($response -eq 'Y' -or $response -eq 'y') {
            git add .
            git commit -m "Update version to $Version"
            Write-Host "✅ Changes committed" -ForegroundColor Green
        }
    }

    git tag -a $tagName -m "Release version $Version"
    Write-Host "✅ Git tag $tagName created successfully" -ForegroundColor Green

    # Push tag if requested
    if ($PushTag) {
        Write-Host "Pushing tag to remote repository..." -ForegroundColor Cyan
        git push origin $tagName
        Write-Host "✅ Tag pushed successfully" -ForegroundColor Green
        Write-Host "🚀 GitHub Actions release workflow will be triggered automatically" -ForegroundColor Green
    }
}

Write-Host "`nRelease preparation completed!" -ForegroundColor Green
Write-Host "Version: $Version" -ForegroundColor Cyan

if ($CreateTag) {
    Write-Host "Tag: v$Version" -ForegroundColor Cyan
    if ($PushTag) {
        Write-Host "Status: Pushed to remote (GitHub Actions triggered)" -ForegroundColor Green
    } else {
        Write-Host "Status: Local only" -ForegroundColor Yellow
        Write-Host "To trigger GitHub Actions, run: git push origin v$Version" -ForegroundColor Cyan
    }
}