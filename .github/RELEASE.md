# Dev Drive Cache Migration Script - Release Process

## Automated Release Process

This project uses GitHub Actions to automate the release process. When you create a new git tag with a version number (e.g., `v1.0.4`), GitHub Actions will automatically:

1. Extract the version number from `Setup-DevDriveCache.ps1`
2. Create a new GitHub Release with the script and documentation
3. Upload the release artifacts

## Creating a New Release

### Method 1: Using the Release Script (Recommended)

1. Update the version in `Setup-DevDriveCache.ps1` (optional, script can do it)
2. Run the release script:

```powershell
# Update version and create tag
.\scripts\create-release.ps1 -Version "1.0.4" -CreateTag -PushTag -UpdateScriptVersion

# Or step by step
.\scripts\create-release.ps1 -Version "1.0.4" -UpdateScriptVersion
.\scripts\create-release.ps1 -Version "1.0.4" -CreateTag
git push origin v1.0.4
```

### Method 2: Manual Tag Creation

1. Update the version in `Setup-DevDriveCache.ps1`:
   ```powershell
   $script:ScriptVersion = "1.0.4"
   ```

2. Commit the changes:
   ```bash
   git add Setup-DevDriveCache.ps1
   git commit -m "Update version to 1.0.4"
   ```

3. Create and push a tag:
   ```bash
   git tag -a v1.0.4 -m "Release version 1.0.4"
   git push origin v1.0.4
   ```

### Method 3: Manual Release via GitHub UI

1. Go to the "Actions" tab in your GitHub repository
2. Select "Create Release" workflow
3. Click "Run workflow"
4. Check "Create release" and click "Run workflow"

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

## Release Notes

Release notes are automatically generated based on the tag and commit history. You can edit them in the GitHub UI after the release is created.

## Troubleshooting

### Tag Already Exists
If you get an error about the tag already existing:
```bash
git tag -d v1.0.4  # Delete local tag
git push origin :v1.0.4  # Delete remote tag
```

### Release Workflow Fails
Check the workflow logs in the Actions tab. Common issues:
- Version format incorrect (must be X.Y.Z)
- Script file not found
- Git tag not pushed properly

### Manual Release
If automated release fails, you can manually create a release:
1. Go to Releases → Create a new release
2. Choose the tag
3. Upload the files manually
4. Copy the release notes from the automated workflow