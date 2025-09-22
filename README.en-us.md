# Dev Drive Cache Migration Script

Other languages:
| [English](README.en-us.md) | [简体中文](README.md) | [繁体中文](README.zh-tw.md) | [日本語](README.ja-jp.md) | [한국어](README.ko-kr.md) | [Français](README.fr-fr.md) | [Deutsch](README.de-de.md) | [Italiano](README.it-it.md) | [Español](README.es-es.md) | [Русский](README.ru-ru.md) | [Português (BR)](README.pt-br.md) | [Nederlands](README.nl-nl.md) | [Türkçe](README.tr-tr.md) | [العربية](README.ar-sa.md) | [हिंदी](README.hi-in.md) | [ไทย](README.th-th.md) |

## Introduction

[Dev Drive Cache Migration Script](https://github.com/jqknono/migrate-to-win11-dev-drive) is an interactive PowerShell tool designed to help developers migrate cache directories of various development tools to Windows 11's Dev Drive (ReFS file system) to improve performance, extend disk lifespan, and reduce disk space usage.

### Core Advantages

- **Extend Disk Lifespan**: By moving frequently read and written cache files to Dev Drive, you can reduce write operations on the system drive (typically SSD), thereby extending its lifespan.
- **Reduce Disk Space Usage**: Moving large cache files (such as Node.js `node_modules` cache, Python's pip cache, etc.) from the system drive can significantly free up valuable system drive space.
- **High Performance**: Leveraging Dev Drive's ReFS file system and optimization features can improve cache read/write speeds and accelerate build and development tool responsiveness.

### Copy-on-Write (COW) Technology

Dev Drive is based on the ReFS file system and utilizes Copy-on-Write (COW) technology. COW is a resource management technique where the core idea is: when multiple callers request the same resource simultaneously, they initially share the same resource. Only when a caller needs to modify the resource does the system create a copy of the resource for that caller, allowing them to modify the copy without affecting the original resource used by other callers.

In the context of Dev Drive, COW technology brings significant advantages:

1.  **Efficient File Copying**: When copying a large file, ReFS doesn't immediately perform actual data copying but creates a new file entry pointing to the same disk blocks. Only when the source or target file is modified are the modified data blocks actually copied. This makes file copying operations very fast and almost doesn't consume additional disk space (until modifications occur).
2.  **Save Disk Space**: For cache directories containing many similar files (e.g., same version packages depended upon by multiple projects), COW can effectively share unmodified data blocks, thereby reducing overall disk usage.
3.  **Improve Performance**: Reduces unnecessary data copying operations, improving the efficiency of file operations.

### Dev Drive and ReFS Features

Windows 11 introduced Dev Drive, a storage volume specifically optimized for developers. Dev Drive uses the Resilient File System (ReFS) as its file system and enables specialized optimization features.

**ReFS (Resilient File System)** is a next-generation file system developed by Microsoft. Compared to traditional NTFS, it has the following advantages:

- **Data Integrity**: Improves data reliability through checksums and automatic repair features.
- **Scalability**: Supports larger volumes and file sizes.
- **Performance Optimization**: Optimized for virtualization and big data workloads.
- **Integrated COW**: Natively supports Copy-on-Write semantics, which is particularly beneficial for file operations in development scenarios.

**Dev Drive Optimization**: Building on ReFS, Dev Drive is further optimized for developer workloads, such as performance improvements for scenarios like package manager caches, build outputs, etc.

## Script Features

This script provides the following main features:

- **Migrate Cache**: Supports migrating cache directories of various development tools to Dev Drive.
  - Node.js (npm, yarn, pnpm)
  - Python (pip)
  - .NET (NuGet)
  - Java (Maven, Gradle)
  - Go (Go modules)
  - Rust (Cargo)
  - VS Code extensions
  - Windows TEMP/TMP directories
    - JetBrains IDEs (IntelliJ, PyCharm, etc.)
  - Android SDK
  - Chocolatey (Windows package manager)
  - User hidden folders (.xxx)
- **Restore Cache**: Restores cache directories that were migrated to Dev Drive back to their original locations.
- **Link Migration**: Migrates cache directories by creating symbolic links/junction points without modifying any environment variables.
- **Test Mode**: Provides safe simulation operations for testing functions like Dev Drive deletion without actually modifying the system.

## Usage Instructions

1.  **System Requirements**:
    - Windows 11 (Build 22000 or higher)
    - PowerShell 7+ (pwsh)
2.  **Run the Script**:
    - Open PowerShell 7 (pwsh) as an administrator.
    - Navigate to the directory where the script is located.
    - Execute `.\Setup-DevDriveCache.ps1`.
3.  **Interactive Operation**:
    - After starting, the script will display an interactive menu to guide you through various operations.
    - Select the appropriate options to migrate cache, create or delete Dev Drive, etc.
    - All critical operations require user confirmation to ensure safety.

## Notes

- **Purpose**: The purpose of this script is to migrate cache folders, not to clean them. After migration, the original cache data still exists, only the storage location has changed.
- **Backup**: Before performing major operations (such as deleting Dev Drive), it is recommended to back up important data.
- **Environment Variables**: The script does not read or write user environment variables; migration is completed through symbolic links.

## References

- [Microsoft Dev Drive Official Documentation](https://learn.microsoft.com/en-us/windows/dev-drive/)
- [Resilient File System (ReFS) Official Documentation](https://learn.microsoft.com/en-us/windows-server/storage/refs/refs-overview)

## Support

- [NullPrivate Ad Blocker](https://www.nullprivate.com)