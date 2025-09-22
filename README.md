# Dev Drive 缓存迁移脚本

其它语言:
| [English](README.en-us.md) | [简体中文](README.md) | [繁体中文](README.zh-tw.md) | [日本語](README.ja-jp.md) | [한국어](README.ko-kr.md) | [Français](README.fr-fr.md) | [Deutsch](README.de-de.md) | [Italiano](README.it-it.md) | [Español](README.es-es.md) | [Русский](README.ru-ru.md) | [Português (BR)](README.pt-br.md) | [Nederlands](README.nl-nl.md) | [Türkçe](README.tr-tr.md) | [العربية](README.ar-sa.md) | [हिंदी](README.hi-in.md) | [ไทย](README.th-th.md) |

## 简介

[Dev Drive 缓存迁移脚本](https://github.com/jqknono/migrate-to-win11-dev-drive)是一个交互式 PowerShell 工具，旨在帮助开发者将各种开发工具的缓存目录迁移到 Windows 11 的 Dev Drive (ReFS 文件系统) 上，以提高性能、延长硬盘寿命并减少磁盘空间占用。

### 核心优势

- **延长硬盘寿命**: 通过将频繁读写的缓存文件移动到 Dev Drive，可以减少对系统盘 (通常是 SSD) 的写入次数，从而延长其使用寿命。
- **减少磁盘空间占用**: 将庞大的缓存文件 (如 Node.js 的 `node_modules` 缓存、Python 的 pip 缓存等) 从系统盘移出，可以显著释放宝贵的系统盘空间。
- **高性能**: 利用 Dev Drive 的 ReFS 文件系统和优化特性，可以提升缓存的读写速度，加快构建和开发工具的响应速度。

### Copy-on-Write (COW) 技术

Dev Drive 基于 ReFS 文件系统，利用了 Copy-on-Write (COW) 技术。COW 是一种资源管理技术，其核心思想是：当多个调用者同时请求相同资源时，它们最初会共享同一份资源。只有当某个调用者需要修改资源时，系统才会为该调用者创建一份资源的副本，然后让其修改这个副本，而不会影响到其他调用者所使用的原始资源。

在 Dev Drive 的场景中，COW 技术带来了显著的优势：

1.  **高效的文件复制**: 当需要复制一个大文件时，ReFS 不会立即进行实际的数据复制，而是创建一个新的文件入口指向相同的磁盘块。只有当源文件或目标文件被修改时，才真正复制被修改的数据块。这使得文件复制操作变得非常快速，并且几乎不占用额外的磁盘空间（直到发生修改）。
2.  **节省磁盘空间**: 对于包含大量相似文件的缓存目录（例如，多个项目依赖的相同版本的包），COW 可以有效地共享未修改的数据块，从而减少整体磁盘占用。
3.  **提高性能**: 减少了不必要的数据复制操作，提高了文件操作的效率。

### Dev Drive 与 refs 特性

Windows 11 引入了 Dev Drive，这是一种专为开发者优化的存储卷。Dev Drive 使用 Resilient File System (ReFS) 作为其文件系统，并启用了专门的优化功能。

**ReFS (Resilient File System)** 是微软开发的新一代文件系统，相较于传统的 NTFS，它具有以下优势：

- **数据完整性**: 通过校验和和自动修复功能提高数据的可靠性。
- **可扩展性**: 支持更大的卷和文件大小。
- **性能优化**: 针对虚拟化和大数据工作负载进行了优化。
- **集成 COW**: 原生支持 Copy-on-Write 语义，这对于开发场景中的文件操作尤其有利。

**Dev Drive 优化**: 在 ReFS 的基础上，Dev Drive 进一步为开发者工作负载进行了优化，例如针对包管理器缓存、构建输出等场景的性能提升。

## 脚本功能

本脚本提供以下主要功能：

- **迁移缓存**: 支持将多种开发工具的缓存目录迁移到 Dev Drive。
  - Node.js (npm, yarn, pnpm)
  - Python (pip)
  - .NET (NuGet)
  - Java (Maven, Gradle)
  - Go (Go modules)
  - Rust (Cargo)
  - VS Code 扩展
  - Windows TEMP/TMP 目录
    - JetBrains IDE (IntelliJ, PyCharm 等)
  - Android SDK
  - Chocolatey (Windows 包管理器)
  - 用户隐藏文件夹 (.xxx)
- **恢复缓存**: 将已迁移到 Dev Drive 的缓存目录恢复到其原始位置。
- **链接迁移**: 通过创建符号链接/联接点迁移缓存目录，不修改任何环境变量。
- **测试模式**: 提供安全的模拟操作，用于测试 Dev Drive 删除等功能，而不会实际修改系统。

## 使用说明

### 快速开始（推荐）

以管理员身份运行 PowerShell 7 (pwsh)，然后执行以下命令直接下载并运行最新版本的脚本：

```powershell
iex "& { $(irm https://raw.githubusercontent.com/jqknono/migrate-to-win11-dev-drive/main/Setup-DevDriveCache.ps1)} -Lang zh"
```

### 手动安装

1.  **系统要求**:
    - Windows 11 (Build 22000 或更高版本)
    - PowerShell 7+ (pwsh)
2.  **运行脚本**:
    - 以管理员身份打开 PowerShell 7 (pwsh)。
    - 导航到脚本所在目录。
    - 执行 `.\Setup-DevDriveCache.ps1`。
3.  **交互式操作**:
    - 脚本启动后会显示一个交互式菜单，引导您完成各种操作。
    - 选择相应的选项来迁移缓存、创建或删除 Dev Drive 等。
    - 所有关键操作都需要用户确认，确保安全。

## 注意事项

- **目的**: 此脚本的目的是迁移缓存文件夹，而不是清理它们。迁移后，原始缓存数据仍然存在，只是存储位置发生了变化。
- **备份**: 在进行重大操作（如删除 Dev Drive）之前，建议备份重要数据。
- **环境变量**: 脚本不会读取或写入用户环境变量；迁移通过符号链接完成。

## 参考资料

- [Microsoft Dev Drive 官方文档](https://learn.microsoft.com/en-us/windows/dev-drive/)
- [Resilient File System (ReFS) 官方文档](https://learn.microsoft.com/en-us/windows-server/storage/refs/refs-overview)

## 支持

- [宁屏去广告](https://www.nullprivate.com)
