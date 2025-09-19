# Dev Drive Cache Migration Script - Release Process

## Automated Release Process

This project uses GitHub Actions to automate the release process. The workflow automatically triggers on every push to main/master branch when `Setup-DevDriveCache.ps1` is modified.

### How It Works

1. **Automatic Detection**: On each push, GitHub Actions extracts the version from `$script:ScriptVersion` in `Setup-DevDriveCache.ps1`
2. **Tag Check**: Checks if a tag `v{version}` already exists
3. **Auto-Release**: If tag doesn't exist, automatically creates tag and GitHub Release
4. **Skip Existing**: If tag exists, skips release creation (avoids duplicates)

## Creating a New Release

### Method 1: Automatic Release (Simplest)

1. Update the version in `Setup-DevDriveCache.ps1`:
   ```powershell
   $script:ScriptVersion = "1.0.4"
   ```

2. Commit and push:
   ```bash
   git add Setup-DevDriveCache.ps1
   git commit -m "Update version to 1.0.4"
   git push origin main
   ```

3. **GitHub Actions will automatically:**
   - Extract version `1.0.4`
   - Create tag `v1.0.4`
   - Create GitHub Release with all files
   - Upload artifacts

### Method 2: Using the Release Script (Advanced)

```powershell
# Update version and create tag manually
.\scripts\create-release.ps1 -Version "1.0.4" -CreateTag -PushTag -UpdateScriptVersion
```

### Method 3: Force Release via GitHub UI

1. Go to the "Actions" tab in your GitHub repository
2. Select "Auto Create Release" workflow
3. Click "Run workflow"
4. Check "Force create release even if tag exists"
5. Click "Run workflow"

## Release Contents

Each release includes:
- `Setup-DevDriveCache.ps1` - Main script
- `README.md` - Project documentation
- `CLAUDE.md` - Claude-specific instructions

## Version Format

Version numbers follow semantic versioning: `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes
- **MINOR**: New features or improvements
- **PATCH**: Bug fixes or minor updates

## Trigger Conditions

The automated release workflow runs when:
- **Push to main/master** with changes to `Setup-DevDriveCache.ps1`
- **Manual trigger** via GitHub Actions UI
- **Force release** option available for manual runs

## Release Notes

Release notes are automatically generated based on the tag and commit history. You can edit them in the GitHub UI after the release is created.

## Workflow Behavior

### Normal Operation
- Push with new version → Auto-tag → Auto-release
- Push with existing version → Skip (no duplicate releases)
- Manual trigger → Force release if requested

### Error Handling
- If version extraction fails, workflow stops
- If tag creation fails, workflow stops
- Detailed logs available in Actions tab

## Troubleshooting

### Tag Already Exists
If you need to recreate a release:
1. Delete existing tag: `git tag -d v1.0.4`
2. Delete remote tag: `git push origin :v1.0.4`
3. Push your changes again or use force release option

### Version Format Issues
- Ensure version format: `X.Y.Z` (e.g., `1.0.4`)
- No letters or special characters (except dots)
- Must be quoted in the script: `"1.0.4"`

### Release Workflow Fails
Check workflow logs in Actions tab for:
- Version extraction errors
- Git permission issues
- Network connectivity problems

### Manual Release
If automated release fails:
1. Use manual trigger with "Force create release"
2. Or manually create release in GitHub UI
3. Or use the release script as fallback