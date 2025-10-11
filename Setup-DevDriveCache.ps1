#!/usr/bin/env pwsh
<#
================================================================================
Dev Drive Cache Migration Script
================================================================================

.SYNOPSIS
    Dev Drive Cache Migration Script - Interactive tool to migrate package caches to Dev Drive

.DESCRIPTION
    This script helps developers migrate their package caches to Dev Drive for improved performance.
    It provides an interactive menu to select which caches to migrate and automatically sets up directory junctions
    to redirect cache access to the Dev Drive location.

    System Requirements:
    - Windows 11 (Build 22000 or higher)
    - PowerShell 7+ (pwsh)

    Important Notes:
    - This script's purpose is to MIGRATE cache folders, NOT clean them
    - All operations require user confirmation and will not execute automatically
    - Migration process: Copy files to Dev Drive -> Delete source directory -> Create directory junction
    - Uses directory junctions only - does not modify environment variables
    - Supported cache types:
        - Node.js (npm, yarn, pnpm, global npm node_modules)
        - Python (pip, uv)
        - .NET (NuGet)
        - Java (Maven, Gradle)
        - Go (Go modules)
        - Rust (Cargo)
        - VS Code extensions
        - Windows TEMP/TMP directories
        - JetBrains IDE cache
        - Android SDK cache
        - Chocolatey cache
        - Hidden folders (.xxx)

    New Features:
    - Interactive Dev Drive detection and selection
    - Support for multiple Dev Drives with automatic selection
    - Safe migration with rollback capabilities
    - Restore functionality to return caches to original locations
    - Dry-run mode to preview actions without making changes
    - Comprehensive hidden folder scanning and migration
    - Automatic junction creation with rollback support

.PARAMETER DevDrivePath
    Specifies the path to the Dev Drive. If not provided, the script will attempt to auto-detect it.

.PARAMETER DryRun
    Perform a dry run: show planned steps and outputs without making any changes.

.PARAMETER Version
    Display script version information and exit.

.PARAMETER Lang
    Specify the language for script output. Supported values: 'zh' (Chinese) or 'en' (English). Default is 'zh'.

.EXAMPLE
    .\Setup-DevDriveCache.ps1
    Run the script in interactive mode with default settings.

.EXAMPLE
    .\Setup-DevDriveCache.ps1 -DevDrivePath "D:\"
    Specify the Dev Drive path explicitly.

.EXAMPLE
    .\Setup-DevDriveCache.ps1 -Lang "en"
    Run the script in English mode (default).

.EXAMPLE
    .\Setup-DevDriveCache.ps1 -Lang "zh"
    Run the script in Chinese mode.

.EXAMPLE
    .\Setup-DevDriveCache.ps1 -Version
    Display script version information.

.NOTES
    Requires PowerShell 7+ (pwsh) and Windows 11
    
    Author: Dev Drive Setup Script
    
    OS Requirements: Windows 11 (Build 22000 or higher)
#>

param(
    [string]$DevDrivePath = "",
    [switch]$DryRun,
    [switch]$Version,
    [ValidateSet('zh', 'en')][string]$Lang = 'en'
)

# Global language setting
$script:CurrentLanguage = $Lang

# 全局严格错误策略：将非终止错误提升为终止错误，禁用异常捕捉机制
$ErrorActionPreference = 'Stop'

# Script version
$script:ScriptVersion = "v0.0.5"

# Progress IDs used for Write-Progress so we can reliably clear stale bars
$script:ProgressIds = @{
    Copy        = 1001
    Move        = 1002
    ScanFolders = 1003
}

# Ensure any lingering progress UI from previous operations is cleared
function Reset-ProgressUI {
    Write-Progress -Id $script:ProgressIds.Copy -Completed -ErrorAction SilentlyContinue
    Write-Progress -Id $script:ProgressIds.Move -Completed -ErrorAction SilentlyContinue
    Write-Progress -Id $script:ProgressIds.ScanFolders -Completed -ErrorAction SilentlyContinue
}

$script:Strings = @{
    # Script header information
    ScriptHeader = @{
        Title = @{
            zh = "Dev Drive 缓存迁移脚本"
            en = "Dev Drive Cache Migration Script"
        }
        Description = @{
            zh = "这是一个交互式工具，帮助开发者将包缓存迁移到 Dev Drive 以提升性能。"
            en = "This is an interactive tool to help developers migrate package caches to Dev Drive for improved performance."
        }
        Subtitle = @{
            zh = "将包缓存迁移到 Dev Drive（需要确认）"
            en = "Migrate package caches to Dev Drive (Confirmation Required)"
        }
        WindowsRequired = @{
            zh = "需要 Windows 11（Build 22000+）"
            en = "Windows 11 Required (Build 22000+)"
        }
        BoxTop = @{
            zh = "╔══════════════════════════════════════════════════════════════════════════════╗"
            en = "╔══════════════════════════════════════════════════════════════════════════════╗"
        }
        LineTitle = @{
            zh = "║                    {0}                          ║"
            en = "║                    {0}                          ║"
        }
        LineSubtitle = @{
            zh = "║              {0}  ║"
            en = "║              {0}  ║"
        }
        LineWindowsRequired = @{
            zh = "║                      {0}                    ║"
            en = "║                      {0}                    ║"
        }
        BoxBottom = @{
            zh = "╚══════════════════════════════════════════════════════════════════════════════╝"
            en = "╚══════════════════════════════════════════════════════════════════════════════╝"
        }
        EmptyLine = @{
            zh = ""
            en = ""
        }
    }
    
    # Main menu options
    MainMenu = @{
        Title = @{
            zh = "Dev Drive 缓存迁移工具"
            en = "Dev Drive Cache Migration Tool"
        }
        Options = @{
            MigrateCaches = @{
                zh = "将缓存迁移到 Dev Drive"
                en = "Migrate Caches to Dev Drive"
            }
            ListCaches = @{
                zh = "列出可用缓存"
                en = "List Available Caches"
            }
            RestoreCaches = @{
                zh = "将缓存恢复到原始位置"
                en = "Restore Caches to Original Locations"
            }
            RemoveDevDrive = @{
                zh = "移除 Dev Drive"
                en = "Remove Dev Drive"
            }
            CreateDevDrive = @{
                zh = "创建 Dev Drive"
                en = "Create Dev Drive"
            }
            Exit = @{
                zh = "退出"
                en = "Exit"
            }
        }
    }
    
    # System requirements check
    SystemRequirements = @{
        Checking = @{
            zh = "正在检查系统要求..."
            en = "Checking system requirements..."
        }
        PowerShell = @{
            zh = "检测 PowerShell 版本..."
            en = "Detecting PowerShell version..."
        }
        Windows = @{
            zh = "检测 Windows 版本..."
            en = "Detecting Windows version..."
        }
        Success = @{
            zh = "✅ 系统要求检查通过"
            en = "✅ System requirements check passed"
        }
        Failed = @{
            zh = "❌ 系统要求检查失败"
            en = "❌ System requirements check failed"
        }
        PowerShellVersion = @{
            zh = "当前 PowerShell 版本：{0}"
            en = "Current PowerShell Version: {0}"
        }
        PowerShellRequired = @{
            zh = "❌ 本脚本需要 PowerShell 7+（pwsh）"
            en = "❌ This script requires PowerShell 7+ (pwsh)"
        }
        InstallInstructions = @{
            zh = "请安装 PowerShell 7："
            en = "Please install PowerShell 7:"
        }
        InstallStep1 = @{
            zh = "1. 访问： https://github.com/PowerShell/PowerShell/releases/latest"
            en = "1. Visit: https://github.com/PowerShell/PowerShell/releases/latest"
        }
        InstallStep2 = @{
            zh = "2. 下载 PowerShell-*-win-x64.msi"
            en = "2. Download PowerShell-*-win-x64.msi"
        }
        InstallStep3 = @{
            zh = "3. 安装完成后，请使用 'pwsh' 命令运行此脚本"
            en = "3. After installation, run this script with 'pwsh' command"
        }
        InstallWinget = @{
            zh = "或者使用 winget 安装："
            en = "Or install with winget:"
        }
        WingetCommand = @{
            zh = "winget install --id Microsoft.PowerShell --source winget"
            en = "winget install --id Microsoft.PowerShell --source winget"
        }
        PowerShellCheckPassed = @{
            zh = "✅ PowerShell 版本检查通过"
            en = "✅ PowerShell version check passed"
        }
        Windows11Detected = @{
            zh = "✅ 检测到 Windows 11（Build {0}）"
            en = "✅ Windows 11 detected (Build {0})"
        }
        Windows11NotDetected = @{
            zh = "❌ 未检测到 Windows 11（Build {0} < 22000）"
            en = "❌ Windows 11 not detected (Build {0} < 22000)"
        }
        WindowsVersionFailed = @{
            zh = "❌ 通过注册表检测 Windows 版本失败：{0}"
            en = "❌ Failed to detect Windows version via registry: {0}"
        }
        Windows11ViaComputerInfo = @{
            zh = "✅ 通过 Get-ComputerInfo 检测到 Windows 11（Build {0}）"
            en = "✅ Windows 11 detected via Get-ComputerInfo (Build {0})"
        }
        WindowsVersionFallbackFailed = @{
            zh = "❌ 通过备用方法检测 Windows 版本失败"
            en = "❌ Failed to detect Windows version via fallback method"
        }
        Windows11Required = @{
            zh = "❌ 本脚本要求 Windows 11（Build 22000 或更高）"
            en = "❌ This script requires Windows 11 (Build 22000 or higher)"
        }
        InstallWindows11 = @{
            zh = "请升级到 Windows 11："
            en = "Please upgrade to Windows 11:"
        }
        Windows11Step1 = @{
            zh = "1. 访问： https://www.microsoft.com/zh-cn/software-download/windows11"
            en = "1. Visit: https://www.microsoft.com/en-us/software-download/windows11"
        }
        Windows11Step2 = @{
            zh = "2. 下载 Windows 11 安装助手"
            en = "2. Download the Windows 11 Installation Assistant"
        }
        Windows11Step3 = @{
            zh = "3. 运行安装程序并按照屏幕提示完成安装"
            en = "3. Run the installer and follow the on-screen instructions"
        }
        WindowsVersionCheckPassed = @{
            zh = "✅ Windows 版本检查通过"
            en = "✅ Windows version check passed"
        }
        ProductName = @{
            zh = "产品名称：{0}"
            en = "Product Name: {0}"
        }
        Windows11ViaNet = @{
            zh = "✅ 通过 .NET 检测到 Windows 11（Build {0}）"
            en = "✅ Windows 11 detected via .NET (Build {0})"
        }
        AllDetectionFailed = @{
            zh = "❌ 所有检测方法均失败，未找到 Windows 11 指示。"
            en = "❌ All detection methods failed. No Windows 11 indicators found."
        }
        ContinueDespiteFailure = @{
            zh = "是否在检测失败时仍然继续？（Y/N）"
            en = "Continue anyway despite OS detection failure? (Y/N)"
        }
        ContinuingDespiteFailure = @{
            zh = "⚠️  尽管系统检查失败，继续执行..."
            en = "⚠️  Continuing despite OS check failure..."
        }
        ExitingAsRequested = @{
            zh = "按请求退出脚本。"
            en = "Exiting script as requested."
        }
        FallbackCheckFailed = @{
            zh = "备用检查通过 {0} 失败：{1}"
            en = "Fallback check via {0} failed: {1}"
        }
    }

    # ACL permissions
    ACLPermissions = @{
        SetACLWarning = @{
            zh = "警告：设置 {0} 的 ACL 失败：{1}"
            en = "Warning: failed to set ACL on {0}: {1}"
        }
        SetSystemTempSuccess = @{
            zh = "   将系统 TEMP/TMP 设置为：{0}"
            en = "   Set system TEMP/TMP to: {0}"
        }
        SetSystemTempFailed = @{
            zh = "设置系统 TEMP/TMP 失败：{0}"
            en = "Failed setting system TEMP/TMP: {0}"
        }
        # Backup environment messages removed (symlink-only mode)
    }

    # Disk space detection
    DiskSpaceDetection = @{
        DetectingSpace = @{
            zh = "正在检测可用磁盘空间..."
            en = "Detecting available disk space..."
        }
        NoUnallocatedSpace = @{
            zh = "❌ 未找到可用的未分配空间"
            en = "❌ No available unallocated space found"
        }
        FoundDisksWithSpace = @{
            zh = "✅ 找到 {0} 个具有可用空间的磁盘"
            en = "✅ Found {0} disks with available space"
        }
        DetectionError = @{
            zh = "❌ 检测磁盘空间时出错: {0}"
            en = "❌ Error detecting disk space: {0}"
        }
        VerifyingRequirements = @{
            zh = "正在验证Dev Drive创建的系统要求..."
            en = "Verifying system requirements for Dev Drive creation..."
        }
        AdminCheckFailed = @{
            zh = "❌ 管理员权限检查失败"
            en = "❌ Administrator privileges check failed"
        }
        AdminCheckPassed = @{
            zh = "✅ 管理员权限检查通过"
            en = "✅ Administrator privileges check passed"
        }
        WindowsVersionCheckPassed = @{
            zh = "✅ Windows版本检查通过 (Build {0})"
            en = "✅ Windows version check passed (Build {0})"
        }
        WindowsVersionCheckFailed = @{
            zh = "❌ Windows版本检查失败 (Build {0})"
            en = "❌ Windows version check failed (Build {0})"
        }
        WindowsVersionDetectionFailed = @{
            zh = "❌ Windows版本检测失败"
            en = "❌ Windows version detection failed"
        }
        ReFSCheckPassed = @{
            zh = "✅ ReFS文件系统支持检查通过"
            en = "✅ ReFS filesystem support check passed"
        }
        ReFSCheckFailed = @{
            zh = "❌ ReFS文件系统支持检查失败"
            en = "❌ ReFS filesystem support check failed"
        }
        ReFSCheckWarning = @{
            zh = "⚠️  无法验证ReFS支持，继续执行"
            en = "⚠️  Unable to verify ReFS support, continuing execution"
        }
        DiskSpaceCheckPassed = @{
            zh = "✅ 磁盘空间检查通过 (总可用空间: {0} GB)"
            en = "✅ Disk space check passed (Total available space: {0} GB)"
        }
        DiskSpaceCheckFailed = @{
            zh = "❌ 磁盘空间检查失败 (可用空间: {0} GB)"
            en = "❌ Disk space check failed (Available space: {0} GB)"
        }
        DiskManagementCheckPassed = @{
            zh = "✅ 磁盘管理服务检查通过"
            en = "✅ Disk management service check passed"
        }
        DiskManagementCheckFailed = @{
            zh = "❌ 磁盘管理服务检查失败"
            en = "❌ Disk management service check failed"
        }
        DiskManagementServiceFailed = @{
            zh = "❌ 磁盘管理服务检查失败"
            en = "❌ Disk management service check failed"
        }
        AllRequirementsPassed = @{
            zh = "✅ 所有系统要求检查通过"
            en = "✅ All system requirements check passed"
        }
        RequirementsFailed = @{
            zh = "❌ 系统要求检查失败"
            en = "❌ System requirements check failed"
        }
        RequirementsError = @{
            zh = "❌ 验证系统要求时出错: {0}"
            en = "❌ Error verifying system requirements: {0}"
        }
        ErrorMessage = @{
            zh = "   - {0}"
            en = "   - {0}"
        }
        FormattingPartition = @{
            zh = "正在将分区格式化为ReFS文件系统..."
            en = "Formatting partition as ReFS filesystem..."
        }
        PartitionInfo = @{
            zh = "   磁盘: {0}, 分区: {1}"
            en = "   Disk: {0}, Partition: {1}"
        }
        DriveLetterInfo = @{
            zh = "   驱动器号: {0}, 标签: {1}"
            en = "   Drive Letter: {0}, Label: {1}"
        }
        PartitionNotExist = @{
            zh = "❌ 指定的分区不存在"
            en = "❌ Specified partition does not exist"
        }
        PartitionFormatted = @{
            zh = "✅ 分区格式化成功"
            en = "✅ Partition formatted successfully"
        }
        DriveInfo = @{
            zh = "   驱动器: {0}"
            en = "   Drive: {0}"
        }
        FileSystemInfo = @{
            zh = "   文件系统: {0}"
            en = "   File System: {0}"
        }
        LabelInfo = @{
            zh = "   标签: {0}"
            en = "   Label: {0}"
        }
        SizeInfo = @{
            zh = "   大小: {0} GB"
            en = "   Size: {0} GB"
        }
        DevDriveEnabled = @{
            zh = "✅ Dev Drive功能已启用"
            en = "✅ Dev Drive functionality enabled"
        }
        DevDriveEnableWarning = @{
            zh = "⚠️  无法启用Dev Drive功能，可能需要手动启用"
            en = "⚠️  Unable to enable Dev Drive functionality, may need manual enablement"
        }
        DevDriveEnableError = @{
            zh = "⚠️  启用Dev Drive功能时出错: {0}"
            en = "⚠️  Error enabling Dev Drive functionality: {0}"
        }
        PartitionFormatFailed = @{
            zh = "❌ 分区格式化失败"
            en = "❌ Partition formatting failed"
        }
        FormatError = @{
            zh = "❌ 格式化分区时出错: {0}"
            en = "❌ Error formatting partition: {0}"
        }
        CreatingPartition = @{
            zh = "正在创建新的磁盘分区..."
            en = "Creating new disk partition..."
        }
        DiskInfo = @{
            zh = "   磁盘: {0}"
            en = "   Disk: {0}"
        }
        SizeInfoGB = @{
            zh = "   大小: {0} GB"
            en = "   Size: {0} GB"
        }
        DriveLetterInfoSimple = @{
            zh = "   驱动器号: {0}"
            en = "   Drive Letter: {0}"
        }
        LabelInfoSimple = @{
            zh = "   标签: {0}"
            en = "   Label: {0}"
        }
        DiskNotExist = @{
            zh = "❌ 指定的磁盘不存在"
            en = "❌ Specified disk does not exist"
        }
        DiskReadOnly = @{
            zh = "❌ 磁盘为只读状态"
            en = "❌ Disk is read-only"
        }
        DriveLetterInUse = @{
            zh = "❌ 驱动器号 {0} 已被使用"
            en = "❌ Drive letter {0} is already in use"
        }
        PartitionCreated = @{
            zh = "✅ 分区创建成功"
            en = "✅ Partition created successfully"
        }
        PartitionNumber = @{
            zh = "   分区号: {0}"
            en = "   Partition Number: {0}"
        }
        DriveLetterAssigned = @{
            zh = "   驱动器号: {0}"
            en = "   Drive Letter: {0}"
        }
        PartitionSize = @{
            zh = "   大小: {0} GB"
            en = "   Size: {0} GB"
        }
        DevDriveReady = @{
            zh = "✅ Dev Drive创建完成"
            en = "✅ Dev Drive creation completed"
        }
        PartitionFormatFailedAfterCreation = @{
            zh = "❌ 分区格式化失败"
            en = "❌ Partition formatting failed"
        }
        CleanupPartition = @{
            zh = "   已清理创建的分区"
            en = "   Cleaned up created partition"
        }
        CleanupWarning = @{
            zh = "   ⚠️  无法清理创建的分区"
            en = "   ⚠️  Unable to clean up created partition"
        }
        PartitionCreationFailed = @{
            zh = "❌ 分区创建失败"
            en = "❌ Partition creation failed"
        }
        CreationError = @{
            zh = "❌ 创建分区时出错: {0}"
            en = "❌ Error creating partition: {0}"
        }
    }

    # Partition size selection
    PartitionSizeSelection = @{
        SelectingSize = @{
            zh = "选择分区大小..."
            en = "Selecting partition size..."
        }
        MinSize = @{
            zh = "   最小大小: {0} GB"
            en = "   Minimum size: {0} GB"
        }
        MaxSize = @{
            zh = "   最大大小: {0} GB"
            en = "   Maximum size: {0} GB"
        }
        DefaultSize = @{
            zh = "   默认大小: {0} GB"
            en = "   Default size: {0} GB"
        }
        RecommendedOptions = @{
            zh = "推荐大小选项:"
            en = "Recommended size options:"
        }
        SmallOption = @{
            zh = "1. 小型 (50 GB) - 适合基本开发需求"
            en = "1. Small (50 GB) - Suitable for basic development needs"
        }
        MediumOption = @{
            zh = "2. 中型 (100 GB) - 适合大多数开发场景"
            en = "2. Medium (100 GB) - Suitable for most development scenarios"
        }
        LargeOption = @{
            zh = "3. 大型 (200 GB) - 适合大型项目和多个开发环境"
            en = "3. Large (200 GB) - Suitable for large projects and multiple development environments"
        }
        CustomOption = @{
            zh = "4. 自定义大小"
            en = "4. Custom size"
        }
        SelectedSize = @{
            zh = "   选择大小: {0} GB"
            en = "   Selected size: {0} GB"
        }
        SizeOutOfRange = @{
            zh = "❌ 大小必须在 {0} 到 {1} GB之间"
            en = "❌ Size must be between {0} and {1} GB"
        }
        InvalidNumber = @{
            zh = "❌ 请输入有效的数字"
            en = "❌ Please enter a valid number"
        }
        InvalidChoice = @{
            zh = "❌ 无效选择，请重新输入"
            en = "❌ Invalid choice, please try again"
        }
        SelectionError = @{
            zh = "❌ 选择分区大小时出错: {0}"
            en = "❌ Error selecting partition size: {0}"
        }
    }

    # Dev Drive creation confirmation
    CreationConfirmation = @{
        CreationTitle = @{
            zh = "Dev Drive创建确认"
            en = "Dev Drive Creation Confirmation"
        }
        AboutToCreate = @{
            zh = "即将创建以下Dev Drive:"
            en = "About to create the following Dev Drive:"
        }
        DiskNumber = @{
            zh = "   磁盘: {0}"
            en = "   Disk: {0}"
        }
        DiskType = @{
            zh = "   磁盘类型: {0}"
            en = "   Disk Type: {0}"
        }
        TotalSize = @{
            zh = "   总大小: {0} GB"
            en = "   Total Size: {0} GB"
        }
        AvailableSpace = @{
            zh = "   可用空间: {0} GB"
            en = "   Available Space: {0} GB"
        }
        PartitionSize = @{
            zh = "   分区大小: {0} GB"
            en = "   Partition Size: {0} GB"
        }
        DriveLetter = @{
            zh = "   驱动器号: {0}"
            en = "   Drive Letter: {0}"
        }
        Label = @{
            zh = "   标签: {0}"
            en = "   Label: {0}"
        }
        Warning = @{
            zh = "⚠️  警告: 此操作将永久修改磁盘分区"
            en = "⚠️  Warning: This operation will permanently modify disk partitions"
        }
        DataLossWarning = @{
            zh = "⚠️  创建后数据将无法恢复"
            en = "⚠️  Data will be irrecoverable after creation"
        }
        CreationCancelled = @{
            zh = "已取消Dev Drive创建"
            en = "Dev Drive creation cancelled"
        }
        FinalConfirmation = @{
            zh = "最后确认:"
            en = "Final confirmation:"
        }
        WillCreatePartition = @{
            zh = "   - 将在磁盘 {0} 上创建 {1} GB 的分区"
            en = "   - Will create {1} GB partition on disk {0}"
        }
        WillAssignDriveLetter = @{
            zh = "   - 分配驱动器号 {0}"
            en = "   - Will assign drive letter {0}"
        }
        WillFormatReFS = @{
            zh = "   - 格式化为ReFS文件系统"
            en = "   - Will format as ReFS filesystem"
        }
        WillEnableDevDrive = @{
            zh = "   - 启用Dev Drive功能"
            en = "   - Will enable Dev Drive functionality"
        }
        CreationConfirmed = @{
            zh = "✅ Dev Drive创建已确认"
            en = "✅ Dev Drive creation confirmed"
        }
        ConfirmationError = @{
            zh = "❌ 确认过程中出错: {0}"
            en = "❌ Error during confirmation: {0}"
        }
    }

    # Main menu and navigation
    MenuNavigation = @{
        Step2SelectDisk = @{
            zh = "步骤 2: 选择磁盘和分区大小"
            en = "Step 2: Select Disk and Partition Size"
        }
        AvailableDiskSpace = @{
            zh = "可用磁盘空间:"
            en = "Available Disk Space:"
        }
        DiskTableHeader = @{
            zh = "编号   磁盘   类型     总计(GB)  可用(GB)  型号"
            en = "No.   Disk   Type     Total(GB)  Free(GB)  Model"
        }
        DiskTableSeparator = @{
            zh = "────   ────   ──────  ────────  ───────  ─────────────────────────"
            en = "────   ────   ──────  ────────  ───────  ─────────────────────────"
        }
        DiskTableRow = @{
            zh = " {0}    {1}   {2}  {3}  {4}  {5}"
            en = " {0}    {1}   {2}  {3}  {4}  {5}"
        }
        AutoSelectDisk = @{
            zh = "自动选择唯一可用磁盘：{0}"
            en = "Auto-selecting only available disk: {0}"
        }
        SelectedDisk = @{
            zh = "已选择磁盘：{0}"
            en = "Selected disk: {0}"
        }
        InvalidSelection = @{
            zh = "❌ 无效选择"
            en = "❌ Invalid selection"
        }
        EnterValidNumber = @{
            zh = "❌ 请输入有效数字"
            en = "❌ Please enter a valid number"
        }
        NoDriveLettersAvailable = @{
            zh = "❌ 没有可用驱动器号"
            en = "❌ No available drive letters"
        }
        PressKeyToReturnToMenu = @{
            zh = "按任意键返回主菜单..."
            en = "Press any key to return to main menu..."
        }
        AvailableDriveLetters = @{
            zh = "可用驱动器号：{0}"
            en = "Available drive letters: {0}"
        }
        DriveLetterUnavailable = @{
            zh = "❌ 驱动器号 {0} 不可用"
            en = "❌ Drive letter {0} is unavailable"
        }
        SelectedDriveLetter = @{
            zh = "已选择驱动器号：{0}"
            en = "Selected drive letter: {0}"
        }
    }
    
    # Dev Drive detection
    DevDrive = @{
        Detecting = @{
            zh = "正在检测可用的 Dev Drive..."
            en = "Detecting available Dev Drives..."
        }
        NotFound = @{
            zh = "❌ 未找到 Dev Drive（ReFS 文件系统）"
            en = "❌ No Dev Drives found (ReFS filesystem)"
        }
        Found = @{
            zh = "✅ 找到 Dev Drive：{0}"
            en = "✅ Found Dev Drive: {0}"
        }
        Using = @{
            zh = "✅ 使用 Dev Drive：{0}"
            en = "✅ Using Dev Drive: {0}"
        }
        PathProvided = @{
            zh = "✅ 使用提供的 Dev Drive 路径：{0}"
            en = "✅ Using provided Dev Drive path: {0}"
        }
        PathNotReFS = @{
            zh = "⚠️ 提供的路径不是 ReFS 文件系统（Dev Drive）：{0}"
            en = "⚠️  Provided path is not ReFS filesystem (Dev Drive): {0}"
        }
        PathNotExist = @{
            zh = "❌ 提供的路径不存在：{0}"
            en = "❌ Provided path does not exist: {0}"
        }
        CreatePrompt = @{
            zh = "您可以选择创建新的 Dev Drive，或退出脚本。"
            en = "You can choose to create a new Dev Drive, or exit the script."
        }
        CreateQuestion = @{
            zh = "是否现在创建 Dev Drive？(Y/N)"
            en = "Do you want to create a Dev Drive now? (Y/N)"
        }
        StartingCreation = @{
            zh = "正在启动 Dev Drive 创建流程..."
            en = "Starting Dev Drive creation process..."
        }
        Redetecting = @{
            zh = "重新检测 Dev Drive..."
            en = "Re-detecting Dev Drive..."
        }
        CreateFailed = @{
            zh = "❌ Dev Drive 创建失败或未找到。"
            en = "❌ Dev Drive creation failed or not found."
        }
        Cancelled = @{
            zh = "已取消 Dev Drive 创建。"
            en = "Dev Drive creation cancelled."
        }
        PressKeyToReturn = @{
            zh = "按任意键返回..."
            en = "Press any key to return..."
        }
        DevDriveCreationTool = @{
            zh = "Dev Drive 创建工具"
            en = "Dev Drive Creation Tool"
        }
        DevDriveCreationDescription = @{
            zh = "此工具将帮助您自动创建Dev Drive"
            en = "This tool will help you create a Dev Drive automatically"
        }
        Step1ValidateRequirements = @{
            zh = "步骤 1: 验证系统要求"
            en = "Step 1: Validate System Requirements"
        }
        RequirementsFailed = @{
            zh = "❌ 系统要求验证失败，无法继续"
            en = "❌ System requirements validation failed, cannot continue"
        }
        PressKeyToReturnToMenu = @{
            zh = "按任意键返回主菜单..."
            en = "Press any key to return to main menu..."
        }
        PressKeyToExit = @{
            zh = "按任意键退出..."
            en = "Press any key to exit..."
        }
        DevDriveListHeader = @{
            zh = "Drive   Label                 File System  Free(GB)  Total(GB)"
            en = "Drive   Label                 File System  Free(GB)  Total(GB)"
        }
        CurrentVersion = @{
            zh = "当前版本：{0}"
            en = "Current version: {0}"
        }
        FoundDevDrive = @{
            zh = "✅ 找到 Dev Drive：{0}（可用 {1} GB，标签：{2}）"
            en = "✅ Found Dev Drive: {0} ({1} GB free, label: {2})"
        }
        MultipleDevDrivesFound = @{
            zh = "找到多个 Dev Drive，请选择："
            en = "Multiple Dev Drives found, please select:"
        }
        DevDriveTableHeader = @{
            zh = "编号   驱动   标签                 可用空间(GB)"
            en = "No.   Drive   Label                 Free Space (GB)"
        }
        DevDriveTableSeparator = @{
            zh = "────  ──────  ─────────────────  ────────────"
            en = "────  ──────  ─────────────────  ────────────"
        }
        SelectedDevDrive = @{
            zh = "✅ 已选择 Dev Drive：{0}"
            en = "✅ Selected Dev Drive: {0}"
        }
        OpenSettings = @{ zh = "正在打开 Windows 设置: 磁盘和卷..."; en = "Opening Windows Settings: Disks & volumes..." }
        SelfCreateGuide = @{ zh = "未检测到 Dev Drive。请在 设置 > 系统 > 存储 > 磁盘和卷 中创建一个 Dev Drive（ReFS），完成后重新运行脚本。"; en = "No Dev Drive detected. Please create one in Settings > System > Storage > Disks & volumes (ReFS), then re-run this script." }
        AdminRequiredMessage = @{
            zh = "系统范围需要管理员权限。跳过系统TEMP/TMP。"
            en = "System scope requires Administrator privileges. Skipping system TEMP/TMP."
        }
        # Using message intentionally defined earlier; duplicate removed to avoid hash literal collision
        # PathProvided message intentionally defined earlier; duplicate removed to avoid hash literal collision
 
  
    
   
    
   
    
      
       
        DevDriveListSeparator = @{
            zh = "──────  ─────────────────  ────────  ───────  ───────"
            en = "──────  ─────────────────  ────────  ───────  ───────"
        }
        ListHeader = @{
            zh = "可用 Dev Drive 列表："
            en = "Available Dev Drive List:"
        }
        Creation = @{
            Step3 = @{
                zh = "步骤 3: 确认创建参数"
                en = "Step 3: Confirm Creation Parameters"
            }
            Cancelled = @{
                zh = "已取消Dev Drive创建"
                en = "Dev Drive creation cancelled"
            }
            Step4 = @{
                zh = "步骤 4: 创建Dev Drive"
                en = "Step 4: Create Dev Drive"
            }
            Creating = @{
                zh = "正在创建Dev Drive..."
                en = "Creating Dev Drive..."
            }
            Activity = @{
                zh = "Dev Drive 创建"
                en = "Dev Drive Creation"
            }
            Initializing = @{
                zh = "正在初始化..."
                en = "Initializing..."
            }
            CreatingPartition = @{
                zh = "正在创建分区..."
                en = "Creating partition..."
            }
            Completed = @{
                zh = "创建完成"
                en = "Creation completed"
            }
            Success = @{
                zh = "✅ Dev Drive创建成功"
                en = "✅ Dev Drive created successfully"
            }
            Drive = @{
                zh = "驱动器"
                en = "Drive"
            }
            Size = @{
                zh = "大小"
                en = "Size"
            }
            Label = @{
                zh = "标签"
                en = "Label"
            }
            Ready = @{
                zh = "✅ Dev Drive已准备就绪"
                en = "✅ Dev Drive is ready"
            }
            Failed = @{
                zh = "❌ Dev Drive创建失败"
                en = "❌ Dev Drive creation failed"
            }
            Error = @{
                zh = "❌ 创建过程中出错: {0}"
                en = "❌ Error during creation: {0}"
            }
            ReturnToMenu = @{
                zh = "按任意键返回主菜单..."
                en = "Press any key to return to main menu..."
            }
        }
    }
    
    # Cache migration
    CacheMigration = @{
        Starting = @{
            zh = "开始迁移缓存..."
            en = "Starting cache migration..."
        }
        Select = @{
            zh = "请选择要迁移的缓存类型："
            en = "Select cache types to migrate:"
        }
        Processing = @{
            zh = "正在处理 {0}..."
            en = "Processing {0}..."
        }
        Success = @{
            zh = "✅ {0} 迁移成功"
            en = "✅ {0} migration successful"
        }
        Failed = @{
            zh = "❌ {0} 迁移失败：{1}"
            en = "❌ {0} migration failed: {1}"
        }
    }
    
    # Error messages
    Errors = @{
        AdminRequired = @{
            zh = "❌ 此操作需要管理员权限"
            en = "❌ Administrator privileges required for this operation"
        }
        InvalidPath = @{
            zh = "❌ 无效路径：{0}"
            en = "❌ Invalid path: {0}"
        }
        DirectoryNotFound = @{
            zh = "❌ 未找到目录：{0}"
            en = "❌ Directory not found: {0}"
        }
    }
    
    # Confirmation messages
    Confirmations = @{
        Continue = @{
            zh = "是否继续操作？ (Y/N)："
            en = "Continue with operation? (Y/N): "
        }
        Migration = @{
            zh = "确认迁移 {0}？ (Y/N)："
            en = "Confirm migration of {0}? (Y/N): "
        }
        Removal = @{
            zh = "确认移除 {0}？ (Y/N)："
            en = "Confirm removal of {0}? (Y/N): "
        }
    }
    
    # Success messages
    Success = @{
        Completed = @{
            zh = "✅ 操作完成"
            en = "✅ Operation completed"
        }
        CacheRestored = @{
            zh = "✅ 缓存已恢复到原始位置"
            en = "✅ Cache restored to original location"
        }
    }
    
    # Warning messages
    Warnings = @{
        Important = @{
            zh = "⚠️  重要：此工具会迁移缓存文件夹，不会清理内容。所有操作均需确认。"
            en = "⚠️  IMPORTANT: This tool MIGRATES cache folders, it does NOT clean them. All operations require confirmation."
        }
        ContinueAnyway = @{
            zh = "是否在检测失败时仍然继续？（Y/N）"
            en = "Continue anyway despite OS detection failure? (Y/N)"
        }
    }

    CacheMenu = @{
        Title = @{
            zh = "请选择要配置的缓存类型："
            en = "Select cache types to configure:"
        }
        HeaderLine = @{
            zh = "编号     缓存类型              当前路径"
            en = "No.     Cache Type              Current Path"
        }
        Separator = @{
            zh = "────    ────────────────────  ──────────────────────────────────────────"
            en = "────    ────────────────────  ──────────────────────────────────────────"
        }
        ItemLine = @{
            zh = "{0}    {1}  {2}"
            en = "{0}    {1}  {2}"
        }
        Options = @{
            OptConfigureAll = @{ zh = "0       配置所有缓存"; en = "0       Configure All Caches" }
            OptShowAll = @{ zh = "A       显示所有缓存详情"; en = "A       Show All Cache Details" }
            OptScanHidden = @{ zh = "D       扫描隐藏文件夹(.xxx)"; en = "D       Scan Hidden Folders(.xxx)" }
            OptMigrateHidden = @{ zh = "M       迁移隐藏文件夹(.xxx)"; en = "M       Migrate Hidden Folders(.xxx)" }
              OptQuit = @{ zh = "Q       退出"; en = "Q       Quit" }
        }
        ExtraTitle = @{
            zh = "可用缓存列表："
            en = "Available Cache List:"
        }
        PressAnyKeyToReturnToMenu = @{
            zh = "按任意键返回菜单..."
            en = "Press any key to return to menu..."
        }
    }

    CacheMenuEx = @{
        Options = @{
            OptMigrateDotFolders = @{ zh = "D       用户临时文件迁移 (.xxx)"; en = "D       User Temp Files Migration (.xxx)" }
            # OptUndoAll removed from UI (no global undo in this build)
            OptQuit = @{ zh = "Q       退出"; en = "Q       Quit" }
        }
        SelectionPrompt = @{
            zh = "选择：1-{0}=按编号，D=点文件夹(.xxx)，Q=退出"
            en = "Select: 1-{0}=By number, D=Dot Folders(.xxx), Q=Quit"
        }
    }

    CacheDetails = @{
        ItemHeader = @{ zh = "📦 {0}"; en = "📦 {0}" }
        Description = @{ zh = "   描述：{0}"; en = "   Description: {0}" }
        # EnvVar display removed (no env var usage)
        DefaultPath = @{ zh = "   默认路径：{0}"; en = "   Default Path: {0}" }
        StatusMigrated = @{ zh = "   状态：已迁移（检测到链接）"; en = "   Status: Migrated (link detected)" }
        CurrentSize = @{ zh = "   当前大小：{0} GB"; en = "   Current Size: {0} GB" }
        CurrentSizeDebug = @{ zh = "   当前大小：-（调试模式）"; en = "   Current Size: - (DryRun)" }
        StatusPathNotExist = @{ zh = "   状态：路径不存在"; en = "   Status: Path does not exist" }
    }

    Migration = @{
        SourceNotExist = @{ zh = "源路径不存在：{0}"; en = "Source path does not exist: {0}" }
        AlreadyMigrated = @{ zh = "   状态：已迁移（检测到目录链接）。跳过。"; en = "   Status: Already migrated (directory link detected). Skipping." }
        OperationDetails = @{ zh = "   📂 文件夹迁移操作详情："; en = "   📂 Folder Migration Operation Details:" }
        SourcePath = @{ zh = "      源路径：{0}"; en = "      Source Path: {0}" }
        TargetPath = @{ zh = "      目标路径：{0}"; en = "      Target Path: {0}" }
        OperationLabel = @{ zh = "      操作:1) 备份源目录  2) 从备份复制到 Dev Drive  3) 创建目录链接  4) 删除备份"; en = "      Operation: 1) Rename source to backup  2) Copy backup to Dev Drive  3) Create directory junction  4) Delete backup" }
        CacheType = @{ zh = "      缓存类型：{0}"; en = "      Cache Type: {0}" }
        OperationLabelSimple = @{ zh = "      操作:1) 备份源目录  2) 从备份复制到 Dev Drive  3) 创建目录链接"; en = "      Operation: 1) Rename source to backup  2) Copy backup to Dev Drive  3) Create directory junction" }
        ConfirmFolder = @{ zh = "   确认迁移文件夹 {0}？ (Y/N)"; en = "   Confirm migration of folder {0}? (Y/N)" }
        FolderCancelled = @{ zh = "   ❌ Migration of folder {0} cancelled"; en = "   ❌ Migration of folder {0} cancelled" }
        CreatingSymbolicLink = @{ zh = "   正在创建目录联接: {0} -> {1}"; en = "   Creating directory junction: {0} -> {1}" }
        SymbolicLinkCreated = @{ zh = "   ✅ 已创建目录联接"; en = "   ✅ Directory junction created" }
        SymbolicLinkFailed = @{ zh = "   创建目录联接失败，请检查权限或目标路径"; en = "   Directory junction creation failed; verify permissions or target path." }
        JunctionCreated = @{ zh = "   ✅ Directory junction created"; en = "   ✅ Directory junction created" }
        CopyCompleted = @{ zh = "   Copy completed"; en = "   Copy completed" }
        DeletingSource = @{ zh = "   删除备份目录: {0}"; en = "   Deleting backup directory: {0}" }
        CreatingTargetDirectory = @{ zh = "   Creating target directory: {0}"; en = "   Creating target directory: {0}" }
        WarningFailedMoveCopy = @{ zh = "   Warning: Failed to move/copy contents; restored empty folder only."; en = "   Warning: Failed to move/copy contents; restored empty folder only." }
        CleaningUpCacheFolder = @{ zh = "   Cleaning up cache folder: {0}"; en = "   Cleaning up cache folder: {0}" }
        # Multi-line operation header
        OperationTitle = @{ zh = "      操作："; en = "      Operation:" }
        OperationLine1 = @{ zh = "      1) 备份源目录（改名）"; en = "      1) Rename source directory as backup" }
        OperationLine2 = @{ zh = "      2) 从备份复制到 Dev Drive"; en = "      2) Copy backup contents to Dev Drive" }
        OperationLine3 = @{ zh = "      3) 创建目录链接"; en = "      3) Create directory junction" }
        OperationLine4 = @{ zh = "      4) 删除备份目录"; en = "      4) Delete backup directory" }
        # Step plan and dry-run labels
        StepsHeader = @{ zh = "      步骤："; en = "      Steps:" }
        Step1RenameBackup = @{ zh = "      第 1/4 步: 将源目录改名为备份:{0} -> {1}"; en = "      Step 1/4: Rename source to backup: {0} -> {1}" }
        Step2CopyFromBackup = @{ zh = "      第 2/4 步: 从备份复制到目标:{0} -> {1}"; en = "      Step 2/4: Copy backup to target: {0} -> {1}" }
        Step3CreateLink = @{ zh = "      第 3/4 步: 创建目录链接:{0} -> {1}"; en = "      Step 3/4: Create directory junction: {0} -> {1}" }
        Step4DeleteBackup = @{ zh = "      第 4/4 步: 删除备份目录:{0}"; en = "      Step 4/4: Delete backup directory: {0}" }
        OperationNumbered = @{ zh = "      操作:1) 备份源目录  2) 从备份复制到 Dev Drive  3) 创建目录链接  4) 删除备份"; en = "      Operation: 1) Rename source to backup  2) Copy backup to Dev Drive  3) Create directory junction  4) Delete backup" }
        DryRunNote = @{ zh = "      （演练模式）不会进行任何更改。"; en = "      (Dry-run) No changes will be made." }
        RenamingSource = @{ zh = "   正在将源目录改名为备份: {0} -> {1}"; en = "   Renaming source to backup: {0} -> {1}" }
        RenameCompleted = @{ zh = "   已创建备份目录: {0}"; en = "   Backup directory created: {0}" }
        RestoringBackup = @{ zh = "   迁移失败, 正在恢复目录: {0}"; en = "   Migration failed, restoring directory: {0}" }
        RestoreCompleted = @{ zh = "   目录已恢复: {0}"; en = "   Directory restored: {0}" }
        RestoreFailed = @{ zh = "   恢复目录失败:{0}"; en = "   Failed to restore directory: {0}" }
        RemovingTemporaryLink = @{ zh = "   删除失败的目录链接: {0}"; en = "   Removing failed directory link: {0}" }
        RemoveLinkFailed = @{ zh = "   删除目录链接失败:{0}"; en = "   Failed to remove directory link: {0}" }
        StartingCopy = @{ zh = "   开始从备份复制:{0} -> {1}"; en = "   Starting copy from backup: {0} -> {1}" }
        # (restore-related labels moved under Restore)
    }

    Common = @{
        Cancelled = @{ zh = "已取消。"; en = "Cancelled." }
        Exit = @{ zh = "退出脚本"; en = "Exiting script" }
        Confirm = @{ zh = "确认"; en = "Confirm" }
        InvalidSelection = @{ zh = "无效选择，请重新输入"; en = "Invalid selection, please try again" }
        PressAnyKeyContinue = @{ zh = "按任意键继续配置其他缓存..."; en = "Press any key to continue configuring other caches..." }
        NoMigrationPerformed = @{ zh = "未执行迁移，已返回。"; en = "No migration performed, returned." }
        MigrationFailed = @{ zh = "   迁移失败：{0}"; en = "   Migration failed: {0}" }
        RestoreFailed = @{ zh = "   恢复失败：{0}"; en = "   Restore failed: {0}" }
        DevDriveNotFound = @{ zh = "❌ 未找到Dev Drive，无法继续。"; en = "❌ Dev Drive not found, cannot continue." }
        EnterSelection = @{ zh = "输入选择"; en = "Enter selection" }
    }

    CacheMenuTable = @{
        TableFormat = @{ zh = "{0,3}    {1}  {2,8}  {3,-10}  {4,-8}  {5}"; en = "{0,3}    {1}  {2,8}  {3,-10}  {4,-8}  {5}" }
        # Header/Detail/FolderList use placeholders; values are provided at call sites
        Header = @{ zh = "{0,3}    {1}  {2,8}  {3,-10}  {4,-8}  {5}"; en = "{0,3}    {1}  {2,8}  {3,-10}  {4,-8}  {5}" }
        Detail = @{ zh = "{0,3}    {1}  {2,8}  {3,-10}  {4,-8}  {5}"; en = "{0,3}    {1}  {2,8}  {3,-10}  {4,-8}  {5}" }
        FolderList = @{ zh = "{0,3}    {1}  {2,8}  {3,-10}  {4,-8}  {5}"; en = "{0,3}    {1}  {2,8}  {3,-10}  {4,-8}  {5}" }
    }

    CacheMenuHeadings = @{
        No = @{ zh = "序号"; en = "No." }
        Name = @{ zh = "名称"; en = "Name" }
        Size = @{ zh = "大小(GB)"; en = "Size(GB)" }
        Status = @{ zh = "状态"; en = "Status" }
        Migrated = @{ zh = "已迁移"; en = "Migrated" }
        Path = @{ zh = "路径"; en = "Path" }
    }

    CacheMenuStatus = @{
        Missing = @{ zh = "缺失"; en = "Missing" }
        Exists = @{ zh = "存在"; en = "Exists" }
        Linked = @{ zh = "已联接"; en = "Linked" }
    }

    DotFolderOperations = @{
        WillRestore = @{ zh = "将恢复 {0} 个文件夹到默认位置："; en = "Will RESTORE {0} folders to default location:" }
        WillMigrate = @{ zh = "将迁移 {0} 个文件夹，大约 {1} GB 总计："; en = "Will migrate {0} folders, approximately {1} GB total:" }
        WillMigrateSimple = @{ zh = "将迁移 {0} 个文件夹："; en = "Will migrate {0} folders:" }
        WillMigrateCaps = @{ zh = "将迁移 {0} 个文件夹，大约 {1} GB 总计："; en = "Will MIGRATE {0} folders, approximately {1} GB total:" }
        WillMigrateCapsSimple = @{ zh = "将迁移 {0} 个文件夹："; en = "Will MIGRATE {0} folders:" }
        WillRestoreSimple = @{ zh = "将恢复 {0} 个文件夹："; en = "Will RESTORE {0} folders:" }
        FolderItem = @{ zh = "  - {0}"; en = "  - {0}" }
        RestoreCancelled = @{ zh = "恢复已取消。"; en = "Restore cancelled." }
        MigrationCancelled = @{ zh = "迁移已取消。"; en = "Migration cancelled." }
        OperationCancelled = @{ zh = "操作已取消。"; en = "Operation cancelled." }
        Restoring = @{ zh = "正在恢复：{0} ..."; en = "Restoring: {0} ..." }
        Migrating = @{ zh = "正在迁移：{0} ..."; en = "Migrating: {0} ..." }
        SkippedRestore = @{ zh = "跳过恢复。"; en = "Skipped restore." }
    }

    CacheMigrationDetails = @{
        Starting = @{ zh = "开始缓存迁移..."; en = "Starting cache migration..." }
        Configuring = @{ zh = "正在配置 {0}..."; en = "Configuring {0}..." }
        CreatingTarget = @{ zh = "   创建目标目录：{0}"; en = "   Creating target directory: {0}" }
        SourceAlreadyLinked = @{ zh = "   源目录已经是链接。标记为已迁移。使用目标：{0}"; en = "   Source directory is already a link. Marked as migrated. Using target: {0}" }
        PreparingMigration = @{ zh = "   准备迁移现有缓存..."; en = "   Preparing to migrate existing cache..." }
        MigrationSuccess = @{ zh = "   ✅ 缓存已迁移到 Dev Drive"; en = "   ✅ Cache migrated to Dev Drive" }
        MigrationFailed = @{ zh = "   ⚠️  缓存迁移失败：{0}"; en = "   ⚠️  Cache migration failed: {0}" }
        ConfigurationComplete = @{ zh = "配置完成！"; en = "Configuration Complete!" }
        ConfiguredCaches = @{ zh = "已配置的缓存："; en = "Configured Caches:" }
        CacheItemSuccess = @{ zh = "  ✅ {0}"; en = "  ✅ {0}" }
        ImportantNotes = @{ zh = "重要提示："; en = "Important Notes:" }
        NoteRestartApps = @{ zh = "  • 如果应用程序在迁移过程中持有文件，请重新启动它们"; en = "  • Restart applications if they held files open during migration" }
        NoteReconfigure = @{ zh = "  • 某些应用程序可能需要在下次启动时重新配置"; en = "  • Some applications may need to be reconfigured on next launch" }
        NoteMoveProjects = @{ zh = "  • 建议将项目文件和构建输出也移动到 Dev Drive"; en = "  • It's recommended to move project files and build outputs to Dev Drive as well" }
        NoteScriptPurpose = @{ zh = "  • 本脚本仅迁移缓存，不会清理任何文件"; en = "  • This script only migrates caches, it does NOT clean any files" }
    }

  
    DevDriveList = @{
        DriveInfo = @{ zh = " {0}     {1}  {2}       {3}   {4}"; en = " {0}     {1}  {2}       {3}   {4}" }
    }

    DotFolders = @{
        Scanning = @{ zh = "扫描隐藏文件夹 (.xxx) 在 %USERPROFILE% 下..."; en = "Scanning hidden folders (.xxx) under %USERPROFILE%..." }
        NoneFound = @{ zh = "没有找到以点开头的隐藏文件夹"; en = "No hidden folders starting with dot found" }
        AllZeroSize = @{ zh = "所有隐藏文件夹大小为 0 GB，无需迁移。"; en = "All hidden folders are 0 GB in size, no migration needed." }
        SelectFoldersPrompt = @{ zh = "请选择要迁移的文件夹编号（逗号或区间，例如：1,3-5）。"; en = "Please select folder numbers to migrate (comma or range, e.g.: 1,3-5)." }
        SelectFoldersHint = @{ zh = "输入 A 表示全部，输入 Q 退出；按回车仅查看列表不迁移。"; en = "Enter A for all, Q to quit; Press Enter to view list only without migration." }
        InvalidSelection = @{ zh = "输入无效，请重新输入，例如：1,3-5 或 A / Q"; en = "Invalid input, please re-enter, e.g.: 1,3-5 or A / Q" }
    }

    Restore = @{
        RestoreStarting  = @{ zh = "开始恢复缓存..."; en = "Starting restore..." }
        RestoreInProgress= @{ zh = "正在恢复: {0}"; en = "Restoring: {0}" }
        # Detection + confirmation
        ConfirmStart     = @{ zh = "检测到默认路径为目录链接。将 {0} 恢复到原始位置？(Y/N)"; en = "Detected directory link at default. Restore {0} to original location? (Y/N)" }
        ConfirmProceed   = @{ zh = "   确认恢复到原始位置？(Y/N)"; en = "   Confirm restore to original location? (Y/N)" }

        # Labels
        OperationDetails = @{ zh = "   📂 文件夹恢复操作详情："; en = "   📂 Folder Restore Operation Details:" }
        LinkPath         = @{ zh = "      链接路径：{0}"; en = "      Link Path: {0}" }
        TargetPath       = @{ zh = "      目标路径：{0}"; en = "      Target Path: {0}" }
        RestorePath      = @{ zh = "      恢复路径：{0}"; en = "      Restore Path: {0}" }
        OperationLabel   = @{ zh = "      操作：删除目录链接，将内容移回恢复路径"; en = "      Operation: Remove directory link and move contents back to restore path" }

        # Numbered steps
        Step1RemoveLink  = @{ zh = "1) 删除目录链接：{0}"; en = "1) Remove directory link: {0}" }
        Step2EnsureDir   = @{ zh = "2) 确保恢复目录存在：{0}"; en = "2) Ensure restore directory exists: {0}" }
        Step3Restore     = @{ zh = "3) 恢复内容：{0} -> {1}"; en = "3) Restore contents: {0} -> {1}" }
        Step4Cleanup     = @{ zh = "4) 清理缓存目录：{0}"; en = "4) Clean up cache folder: {0}" }

        # Status
        SourceNotLink    = @{ zh = "Source is not a directory link, nothing to restore: {0}"; en = "Source is not a directory link, nothing to restore: {0}" }
        TargetMissing    = @{ zh = "   目标路径缺失，已在恢复位置创建空文件夹。"; en = "   Target path missing, created empty folder at restore location." }
        NoteTargetMissing= @{ zh = "      注意：目标路径不存在，将在恢复位置创建空文件夹。"; en = "      Note: Target path does not exist. Will create empty folder at restore location." }
        RestoreFailed    = @{ zh = "   恢复失败：{0}"; en = "   Restore failed: {0}" }
        RestoreComplete  = @{ zh = "   恢复完成。"; en = "   Restore complete." }
    }
}

# Junction-only mode: do not modify environment variables
$script:DisableEnvVarChanges = $true

# Get string function for specified language
function Get-LocalizedString {
    param(
        [Parameter(Mandatory=$true)][string]$Key,
        [string[]]$Arguments = @(),
        [ValidateSet('zh', 'en')][string]$Language = 'en'
    )
    
    # Split the key path into an array
    $keyPath = $Key -split '\.'
    
    # Navigate to the correct nested hashtable
    $current = $script:Strings
    foreach ($path in $keyPath) {
        if ($current -and $current.ContainsKey($path)) {
            $current = $current[$path]
        } else {
            # If key is not found, return the key itself
            return $Key
        }
    }
    
    # Check if the current object contains the string for the specified language
    if ($current -and $current.ContainsKey($Language)) {
        $formatString = $current[$Language]
        if ($Arguments.Count -gt 0) {
            return $formatString -f $Arguments
        }
        return $formatString
    }
    
    # If string for the specified language is not found, return the key itself
    return $Key
}

# Convenience function to get strings in current language
function Get-String {
    param(
        [Parameter(Mandatory=$true)][string]$Key,
        [string[]]$Arguments = @()
    )
    return Get-LocalizedString -Key $Key -Language $script:CurrentLanguage -Arguments $Arguments
}


# Color definitions for rich text output
class Colors {
    static [string]$Header = "`e[1;36m"      # Bright Cyan
    static [string]$Success = "`e[1;32m"     # Bright Green
    static [string]$Warning = "`e[1;33m"     # Bright Yellow
    static [string]$Error = "`e[1;31m"       # Bright Red
    static [string]$Info = "`e[1;34m"        # Bright Blue
    static [string]$Menu = "`e[1;35m"        # Bright Magenta
    static [string]$Input = "`e[1;37m"       # Bright White
    static [string]$Reset = "`e[0m"          # Reset
}




# 广播环境变更到正在运行的应用程序（尽力而为）
## Env var broadcast removed: no environment changes to broadcast

# Cache configuration data - Ordered for consistent menu display
$CacheConfigs = [ordered]@{
    # Note: Dot-folders under the user profile (e.g. .cargo, .nuget, .m2, .gradle, .vscode)
    # are intentionally excluded from this main list. They are handled via
    # "User Temp Files Migration (.xxx)" (Invoke-DotFolderMigration).
    "npm" = @{
        Name = "Node.js npm Cache"
        EnvVar = "npm_config_cache"
        DefaultPath = "$env:APPDATA\npm-cache"
        Description = "Node.js npm Package Cache"
    }
    "yarn" = @{
        Name = "Yarn Cache"
        EnvVar = ""
        DefaultPath = "$env:LOCALAPPDATA\Yarn\Cache"
        Description = "Yarn Package Cache"
    }
    "pnpm" = @{
        Name = "pnpm Cache"
        EnvVar = "PNPM_HOME"
        DefaultPath = "$env:LOCALAPPDATA\pnpm"
        Description = "pnpm Package Manager Cache"
    }
    "pip" = @{
        Name = "Python pip Cache"
        EnvVar = "PIP_CACHE_DIR"
        DefaultPath = "$env:LOCALAPPDATA\pip\Cache"
        Description = "Python pip Package Cache"
    }
    "uvcache" = @{
        Name = "uv Cache"
        EnvVar = ""
        DefaultPath = "$env:LOCALAPPDATA\uv\cache"
        Description = "uv package manager cache"
    }
    "go" = @{
        Name = "Go Modules Cache"
        EnvVar = "GOPROXY"
        DefaultPath = "$env:USERPROFILE\go\pkg\mod"
        Description = "Go Modules Cache"
    }
    "temp" = @{
        Name = "Windows TEMP/TMP"
        EnvVar = "TEMP,TMP"
        # Show current TEMP path so menus/details aren't blank
        DefaultPath = "$env:TEMP"
        Description = "Windows Temporary Directory"
    }
    "jetbrains" = @{
        Name = "JetBrains IDE Cache"
        EnvVar = ""
        DefaultPath = "$env:LOCALAPPDATA\JetBrains"
        Description = "JetBrains IDE System and Plugins Cache"
    }
    "android" = @{
        Name = "Android SDK Cache"
        EnvVar = "ANDROID_HOME"
        DefaultPath = "$env:LOCALAPPDATA\Android\Sdk"
        Description = "Android SDK and Build Cache"
    }
      "chocolatey" = @{
        Name = "Chocolatey Cache"
        EnvVar = ""
        DefaultPath = "$env:ChocolateyInstall\lib"
        Description = "Chocolatey Package Manager Cache"
    }
    "npmglobalmodules" = @{
        Name = "npm Global Node Modules"
        EnvVar = ""
        DefaultPath = "$env:APPDATA\npm\node_modules"
        Description = "Global npm node_modules directory"
    }
    "npmcachelocal" = @{
        Name = "npm Local Cache"
        EnvVar = ""
        DefaultPath = "$env:LOCALAPPDATA\npm-cache"
        Description = "npm cache in LocalAppData"
    }
}

  
function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Color = [Colors]::Reset,
        [switch]$NoNewline
    )

    # 将我们的颜色标记映射到ConsoleColor以获得广泛的主机支持
    # Map our color tokens to ConsoleColor for broad host support
    $fgColor = switch ($Color) {
        ([Colors]::Header)  { 'Cyan' }
        ([Colors]::Success) { 'Green' }
        ([Colors]::Warning) { 'Yellow' }
        ([Colors]::Error)   { 'Red' }
        ([Colors]::Info)    { 'Blue' }
        ([Colors]::Menu)    { 'Magenta' }
        ([Colors]::Input)   { 'White' }
        default              { $null }
    }

    if ($fgColor) {
        if ($NoNewline) {
            Write-Host $Message -ForegroundColor $fgColor -NoNewline
        } else {
            Write-Host $Message -ForegroundColor $fgColor
        }
    } else {
        if ($NoNewline) {
            Write-Host $Message -NoNewline
        } else {
            Write-Host $Message
        }
    }
}

# 检查目录路径是否为链接（符号链接或目录联接）
# Check if a directory path is a link (symbolic link or junction)
function Test-IsDirectoryLink {
    param(
        [Parameter(Mandatory=$true)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (-not $item.PSIsContainer) { return $false }
    # 优先使用LinkType（PS 7+可用时），否则回退到ReparsePoint属性
    # Prefer LinkType when available (PS 7+), otherwise fall back to ReparsePoint attribute
    if ($null -ne $item.LinkType) {
        return ($item.LinkType -in @('SymbolicLink','Junction'))
    }
    return (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
}

# 将字符串格式化为固定宽度，可选择省略号
# Format a string to fixed width with optional ellipsis
function Format-FixedWidth {
    param(
        [Parameter(Mandatory=$true)][string]$Text,
        [Parameter(Mandatory=$true)][int]$Width,
        [ValidateSet('Left','Right')][string]$Align = 'Left'
    )

    if ($null -eq $Text) { $Text = '' }
    $t = [string]$Text
    if ($t.Length -le $Width) {
        if ($Align -eq 'Right') { return ("{0,$Width}" -f $t) }
        return ("{0,-$Width}" -f $t)
    }
    if ($Width -le 1) { return $t.Substring(0, [Math]::Max(0,$Width)) }
    if ($Align -eq 'Right') { return ('…' + $t.Substring($t.Length-($Width-1))) }
    return ($t.Substring(0, $Width-1) + '…')
}

# Env var backup removed: script does not back up environment variables

function Show-Header {
    Reset-ProgressUI
    Clear-Host
    Write-ColoredOutput (Get-String -Key "ScriptHeader.BoxTop") [Colors]::Header
    Write-ColoredOutput (Get-String -Key "ScriptHeader.LineTitle" -Arguments @(Get-String -Key "ScriptHeader.Title")) [Colors]::Header
    Write-ColoredOutput (Get-String -Key "ScriptHeader.LineSubtitle" -Arguments @(Get-String -Key "ScriptHeader.Subtitle")) [Colors]::Header
    Write-ColoredOutput (Get-String -Key "ScriptHeader.LineWindowsRequired" -Arguments @(Get-String -Key "ScriptHeader.WindowsRequired")) [Colors]::Header
    Write-ColoredOutput (Get-String -Key "ScriptHeader.BoxBottom") [Colors]::Header
    Write-ColoredOutput (Get-String -Key "ScriptHeader.EmptyLine") [Colors]::Warning
    Write-ColoredOutput (Get-String -Key "DevDrive.CurrentVersion" -Arguments @($script:ScriptVersion)) [Colors]::Info
    if ($DryRun) { Write-ColoredOutput "DRY-RUN MODE: No changes will be made" [Colors]::Warning }
    Write-Host ""
}

function Test-PowerShellVersion {
    $psVersion = $PSVersionTable.PSVersion

    Write-ColoredOutput (Get-String -Key "SystemRequirements.PowerShell") [Colors]::Info
    Write-ColoredOutput (Get-String -Key "SystemRequirements.PowerShellVersion" -Arguments @("$($psVersion.Major).$($psVersion.Minor)")) [Colors]::Info

    if ($psVersion.Major -lt 7) {
        Write-ColoredOutput (Get-String -Key "SystemRequirements.PowerShellRequired") [Colors]::Error
        Write-ColoredOutput (Get-String -Key "SystemRequirements.PowerShellVersion" -Arguments @("$($psVersion.Major).$($psVersion.Minor)")) [Colors]::Error
        Write-Host ""
        Write-ColoredOutput (Get-String -Key "SystemRequirements.InstallInstructions") [Colors]::Warning
        Write-ColoredOutput (Get-String -Key "SystemRequirements.InstallStep1") [Colors]::Warning
        Write-ColoredOutput (Get-String -Key "SystemRequirements.InstallStep2") [Colors]::Warning
        Write-ColoredOutput (Get-String -Key "SystemRequirements.InstallStep3") [Colors]::Warning
        Write-Host ""
        Write-ColoredOutput (Get-String -Key "SystemRequirements.InstallWinget") [Colors]::Info
        Write-ColoredOutput (Get-String -Key "SystemRequirements.WingetCommand") [Colors]::Info
        exit 1
    } else {
        Write-ColoredOutput (Get-String -Key "SystemRequirements.PowerShellCheckPassed") [Colors]::Success
    }
}

function Test-WindowsVersion {
    Write-ColoredOutput (Get-String -Key "SystemRequirements.Windows") [Colors]::Info

    # Primary: registry CurrentBuildNumber
    $regKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    $regProps = Get-ItemProperty -Path $regKey -ErrorAction SilentlyContinue
    $buildNumber = if ($regProps) { [int]$regProps.CurrentBuildNumber } else { $null }
    $productName = if ($regProps) { $regProps.ProductName } else { $null }
    if ($buildNumber -ge 22000) {
        Write-ColoredOutput (Get-String -Key "SystemRequirements.Windows11Detected" -Arguments @($buildNumber)) [Colors]::Success
        if ($productName) { Write-ColoredOutput (Get-String -Key "SystemRequirements.ProductName" -Arguments @($productName)) [Colors]::Info }
        return $true
    }

    if ($buildNumber) {
        Write-ColoredOutput (Get-String -Key "SystemRequirements.Windows11NotDetected" -Arguments @($buildNumber)) [Colors]::Error
        if ($productName) { Write-ColoredOutput (Get-String -Key "SystemRequirements.ProductName" -Arguments @($productName)) [Colors]::Info }
    } else {
        Write-ColoredOutput (Get-String -Key "SystemRequirements.WindowsVersionFailed" -Arguments @("Registry query returned no data")) [Colors]::Error
    }

    # Fallback: Get-ComputerInfo
    $osInfo = Get-ComputerInfo -ErrorAction SilentlyContinue
    if ($osInfo -and [int]$osInfo.WindowsCurrentBuildNumber -ge 22000) {
        Write-ColoredOutput (Get-String -Key "SystemRequirements.Windows11ViaComputerInfo" -Arguments @($osInfo.WindowsCurrentBuildNumber)) [Colors]::Success
        return $true
    }
    if (-not $osInfo) { Write-ColoredOutput (Get-String -Key "SystemRequirements.FallbackCheckFailed" -Arguments @("Get-ComputerInfo", "No data")) [Colors]::Warning }

    # Final fallback: .NET Environment
    $netVersion = [System.Environment]::OSVersion.Version
    if ($netVersion.Build -ge 22000) {
        Write-ColoredOutput (Get-String -Key "SystemRequirements.Windows11ViaNet" -Arguments @($netVersion.Build)) [Colors]::Success
        return $true
    }

    Write-ColoredOutput (Get-String -Key "SystemRequirements.AllDetectionFailed") [Colors]::Error

    # Single user confirmation prompt if all checks fail
    Write-Host ""
    $continue = Read-Host (Get-String -Key "SystemRequirements.ContinueDespiteFailure")
    if ($continue.Trim().ToUpper() -eq 'Y') {
        Write-ColoredOutput (Get-String -Key "SystemRequirements.ContinuingDespiteFailure") [Colors]::Warning
        return $true
    } else {
        Write-ColoredOutput (Get-String -Key "SystemRequirements.ExitingAsRequested") [Colors]::Info
        exit 1
    }
}

function Get-DevDrivePath {
    param([string]$ProvidedPath = "")

    if ($ProvidedPath) {
        if (Test-Path $ProvidedPath) {
            $driveLetter = Split-Path $ProvidedPath -Qualifier
            $driveInfo = Get-Volume -DriveLetter $driveLetter.TrimEnd(':')
            if ($driveInfo -and $driveInfo.FileSystem -eq "ReFS") {
                Write-ColoredOutput (Get-String -Key "DevDrive.PathProvided" -Arguments @($ProvidedPath)) [Colors]::Success
                return $ProvidedPath
            } else {
                Write-ColoredOutput (Get-String -Key "DevDrive.PathNotReFS" -Arguments @($ProvidedPath)) [Colors]::Warning
            }
        } else {
            Write-ColoredOutput (Get-String -Key "DevDrive.PathNotExist" -Arguments @($ProvidedPath)) [Colors]::Error
            return $null
        }
    }

    Write-ColoredOutput (Get-String -Key "DevDrive.Detecting") [Colors]::Info

    # Ensure result is always an array to avoid null indexing
    $devDrives = @(
        Get-Volume | Where-Object {
        $_.FileSystem -eq "ReFS" -and
        $_.DriveType -eq "Fixed" -and
        $_.DriveLetter
        } | Sort-Object DriveLetter
    )

    if ($devDrives.Count -eq 0) {
        Write-ColoredOutput (Get-String -Key "DevDrive.NotFound") [Colors]::Error
        Write-Host ""
        Write-ColoredOutput (Get-String -Key "DevDrive.OpenSettings") [Colors]::Info
        Start-Process "ms-settings:disksandvolumes" -ErrorAction SilentlyContinue | Out-Null
        Write-Host ""
        Write-ColoredOutput (Get-String -Key "DevDrive.SelfCreateGuide") [Colors]::Warning
        exit 1
    }

    if ($devDrives.Count -eq 1) {
        $devDrivePath = "$($devDrives[0].DriveLetter):\"
        $freeGB = [math]::Round($devDrives[0].SizeRemaining / 1GB, 2)
        $label = $devDrives[0].FileSystemLabel
        Write-ColoredOutput (Get-String -Key "DevDrive.FoundDevDrive" -Arguments @($devDrivePath, $freeGB, $label)) [Colors]::Success
        return $devDrivePath
    }

    Write-ColoredOutput (Get-String -Key "DevDrive.MultipleDevDrivesFound") [Colors]::Info
    Write-ColoredOutput (Get-String -Key "DevDrive.DevDriveTableHeader") [Colors]::Header
    Write-ColoredOutput (Get-String -Key "DevDrive.DevDriveTableSeparator") [Colors]::Header
    for ($i = 0; $i -lt $devDrives.Count; $i++) {
        $d = $devDrives[$i]
        $freeGB = [math]::Round($d.SizeRemaining / 1GB, 2)
        $label = if ($d.FileSystemLabel) { $d.FileSystemLabel } else { "(None)" }
        $num = "{0,2}" -f ($i + 1)
        $drv = "{0}:" -f $d.DriveLetter
        $lab = "{0,-18}" -f $label
        $free = "{0,10}" -f $freeGB
        Write-ColoredOutput (Get-String -Key "DevDrive.TableRow" -Arguments @(" $num    $drv     $lab  $free")) [Colors]::Menu
    }

    do {
        $choice = Read-Host "Please select Dev Drive (1-$($devDrives.Count))"
        $index = [int]$choice - 1
    } while ($index -lt 0 -or $index -ge $devDrives.Count)

    $devDrivePath = "$($devDrives[$index].DriveLetter):\"
    Write-ColoredOutput (Get-String -Key "DevDrive.Selected" -Arguments @($devDrivePath)) [Colors]::Success
    return $devDrivePath
}

function Show-CacheMenuEx {
    param([hashtable]$Configs, [string]$DevDrivePath)

    Write-ColoredOutput (Get-String -Key "CacheMenu.ExtraTitle") [Colors]::Menu
    Write-Host ""
    $idxH = Get-String -Key "CacheMenuHeadings.No"
    $nameH = Format-FixedWidth -Text (Get-String -Key "CacheMenuHeadings.Name") -Width 27 -Align Left
    $sizeH = Get-String -Key "CacheMenuHeadings.Size"
    $statusH = Get-String -Key "CacheMenuHeadings.Status"
    $migrH = Get-String -Key "CacheMenuHeadings.Migrated"
    $pathH = Format-FixedWidth -Text (Get-String -Key "CacheMenuHeadings.Path") -Width 60 -Align Left
    Write-ColoredOutput (Get-String -Key "CacheMenuTable.Header" -Arguments @($idxH, $nameH, $sizeH, $statusH, $migrH, $pathH)) [Colors]::Header
    $dash = '-'
    $idxD = $dash * 3
    $nameD = $dash * 27
    $sizeD = $dash * 8
    $statusD = $dash * 10
    $migrD = $dash * 8
    $pathD = $dash * 60
    Write-ColoredOutput (Get-String -Key "CacheMenuTable.Detail" -Arguments @($idxD, $nameD, $sizeD, $statusD, $migrD, $pathD)) [Colors]::Header

    # Create a sorted list of keys based on cache name for consistent menu ordering
    $sortedKeys = $Configs.Keys | Sort-Object { $Configs[$_].Name }
    for ($i = 0; $i -lt $sortedKeys.Count; $i++) {
        $key = $sortedKeys[$i]
        $config = $Configs[$key]
        $index = $i + 1
        $exists = Test-Path -LiteralPath $config.DefaultPath
        $isLinked = $false
        if ($exists) { $isLinked = Test-IsDirectoryLink -Path $config.DefaultPath }
        # Junction-only mode: treat as migrated only when directory link is detected
        $statusKey = if (-not $exists) { 'CacheMenuStatus.Missing' } elseif ($isLinked) { 'CacheMenuStatus.Linked' } else { 'CacheMenuStatus.Exists' }
        $statusText = Get-String -Key $statusKey
        # compute display fields
        $isMigrated = $isLinked
        $migratedText = $isMigrated ? 'Yes' : 'No'
        $nameDisp = Format-FixedWidth -Text $config.Name -Width 27 -Align Left
        $pathRaw = if ($exists) {
            $config.DefaultPath
        } else {
            $missingTag = Get-String -Key "CacheMenuStatus.Missing"
            "[{0}] {1}" -f $missingTag, $config.DefaultPath
        }
        $pathDisp = Format-FixedWidth -Text $pathRaw -Width 60 -Align Left
        $sizeValue = '-'
        if (-not $DryRun -and $exists -and -not $isLinked) {
            $sizeBytes = Get-FolderSizeBytes -Path $config.DefaultPath
            if ($sizeBytes -gt 0) {
                $sizeGB = [math]::Round($sizeBytes / 1GB, 2)
                $sizeValue = "{0:N2}" -f $sizeGB
            } elseif ($null -ne $sizeBytes) {
                $sizeValue = "0.00"
            }
        } else {
            if ($DryRun) { $sizeValue = '-' }
            elseif ($isLinked) { $sizeValue = '-' }
        }
        Write-ColoredOutput (Get-String -Key "CacheMenuTable.TableFormat" -Arguments @($index, $nameDisp, $sizeValue, $statusText, $migratedText, $pathDisp)) [Colors]::Info
    }

  
    Write-Host ""
    Write-ColoredOutput (Get-String -Key "CacheMenuEx.Options.OptMigrateDotFolders") [Colors]::Menu
    Write-ColoredOutput (Get-String -Key "CacheMenuEx.Options.OptQuit") [Colors]::Menu
    Write-Host ""
}

function Show-CacheDetails {
    param([hashtable]$Configs)

    Write-ColoredOutput (Get-String -Key "CacheDetails.Title") [Colors]::Header
    Write-Host ""

    foreach ($key in $Configs.Keys) {
        $config = $Configs[$key]
        Write-ColoredOutput (Get-String -Key "CacheDetails.ItemHeader" -Arguments @($config.Name)) [Colors]::Menu
        Write-ColoredOutput (Get-String -Key "CacheDetails.Description" -Arguments @($config.Description)) [Colors]::Info
        # Env var details intentionally omitted
        Write-ColoredOutput (Get-String -Key "CacheDetails.DefaultPath" -Arguments @($config.DefaultPath)) [Colors]::Info

        if (Test-Path $config.DefaultPath) {
            if (Test-IsDirectoryLink -Path $config.DefaultPath) {
                Write-ColoredOutput (Get-String -Key "CacheDetails.StatusMigrated") [Colors]::Success
            } elseif (-not $DryRun) {
                $size = (Get-ChildItem $config.DefaultPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                if ($size) {
                    $sizeGB = [math]::Round($size / 1GB, 2)
                    Write-ColoredOutput (Get-String -Key "CacheDetails.CurrentSize" -Arguments @($sizeGB)) [Colors]::Success
                }
            } else {
                Write-ColoredOutput (Get-String -Key "CacheDetails.CurrentSizeDebug") [Colors]::Warning
            }
        } else {
            Write-ColoredOutput (Get-String -Key "CacheDetails.StatusPathNotExist") [Colors]::Warning
        }
        Write-Host ""
    }
}

function Get-DotFolders {
    param()
    # Use $HOME directly (read-only automatic variable); avoid assigning to it
    $userHome = $HOME
    if (-not (Test-Path -LiteralPath $userHome)) { return @() }
    Get-ChildItem -LiteralPath $userHome -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '.*' } |
        Sort-Object Name
}

function Get-FolderSizeBytes {
    param([string]$Path)
    $measure = Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
    if ($null -eq $measure) { return 0 }
    return $measure.Sum
}

# 安全的相对路径计算：严格校验，失败即抛错
function Get-SafeRelativePath {
    param(
        [Parameter(Mandatory=$true)][string]$BasePath,
        [Parameter(Mandatory=$true)][string]$ChildPath
    )

    $baseFull = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\','/')
    $childFull = [System.IO.Path]::GetFullPath($ChildPath)

    $baseRoot = [System.IO.Path]::GetPathRoot($baseFull)
    $childRoot = [System.IO.Path]::GetPathRoot($childFull)
    if ($baseRoot -ne $childRoot) {
        throw "Failed to compute relative path from '$BasePath' to '$ChildPath': different roots '$baseRoot' vs '$childRoot'"
    }

    $rel = [System.IO.Path]::GetRelativePath($baseFull, $childFull)
    if ([string]::IsNullOrWhiteSpace($rel)) { throw "Failed to compute relative path from '$BasePath' to '$ChildPath': empty relative path" }

    $relNorm = ($rel -replace '[\\/]+','\')
    if ($relNorm.StartsWith('..')) { throw "Failed to compute relative path from '$BasePath' to '$ChildPath': outside base path" }

    $resolved = [System.IO.Path]::GetFullPath((Join-Path $baseFull $relNorm))
    if (-not $resolved.Equals($childFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Failed to compute relative path from '$BasePath' to '$ChildPath': resolution mismatch"
    }
    return $relNorm
}

# Copy directory contents with a progress bar using Write-Progress
function Copy-DirectoryWithProgress {
    param(
        [Parameter(Mandatory=$true)][string]$SourcePath,
        [Parameter(Mandatory=$true)][string]$DestinationPath
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) { return }
    if (-not (Test-Path -LiteralPath $DestinationPath)) { New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null }

    # Collect all files first to compute progress
    $files = @(Get-ChildItem -LiteralPath $SourcePath -Recurse -File -ErrorAction SilentlyContinue)

    # Ensure full directory structure exists at destination (including empty directories)
    $dirs = @(Get-ChildItem -LiteralPath $SourcePath -Recurse -Directory -ErrorAction SilentlyContinue)
    foreach ($d in $dirs) {
        $relDir = Get-SafeRelativePath -BasePath $SourcePath -ChildPath $d.FullName
        $destDirFull = Join-Path $DestinationPath $relDir
        if (-not (Test-Path -LiteralPath $destDirFull)) { New-Item -ItemType Directory -Path $destDirFull -Force | Out-Null }
    }
    $total = if ($files) { $files.Count } else { 0 }
    if ($total -eq 0) { return }

    $progressId = $script:ProgressIds.Copy
    for ($i = 0; $i -lt $total; $i++) {
        $f = $files[$i]
        $rel = Get-SafeRelativePath -BasePath $SourcePath -ChildPath $f.FullName
        $destFile = Join-Path $DestinationPath $rel
        $destDir = Split-Path -Path $destFile -Parent
        if ($destDir -and -not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

        $pct = [int]((($i + 1) / $total) * 100)
        Write-Progress -Id $progressId -Activity "Copying files..." -Status ("{0}/{1} {2}" -f ($i+1), $total, $rel) -PercentComplete $pct

        Copy-Item -LiteralPath $f.FullName -Destination $destFile -Force -ErrorAction Stop
    }
    Write-Progress -Id $progressId -Activity "Copying files..." -Completed
}

# Move directory contents with a progress bar using Write-Progress
function Move-DirectoryContentsWithProgress {
    param(
        [Parameter(Mandatory=$true)][string]$SourcePath,
        [Parameter(Mandatory=$true)][string]$DestinationPath
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) { return }
    if (-not (Test-Path -LiteralPath $DestinationPath)) { New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null }

    $files = @(Get-ChildItem -LiteralPath $SourcePath -Recurse -File -ErrorAction SilentlyContinue)

    # Ensure full directory structure exists at destination (including empty directories)
    $dirs = @(Get-ChildItem -LiteralPath $SourcePath -Recurse -Directory -ErrorAction SilentlyContinue)
    foreach ($d in $dirs) {
        $relDir = Get-SafeRelativePath -BasePath $SourcePath -ChildPath $d.FullName
        $destDirFull = Join-Path $DestinationPath $relDir
        if (-not (Test-Path -LiteralPath $destDirFull)) { New-Item -ItemType Directory -Path $destDirFull -Force | Out-Null }
    }
    $total = if ($files) { $files.Count } else { 0 }
    if ($total -eq 0) {
        # attempt to move empty directories structure
        Get-ChildItem -LiteralPath $SourcePath -Recurse -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $rel = Get-SafeRelativePath -BasePath $SourcePath -ChildPath $_.FullName
            $destDir = Join-Path $DestinationPath $rel
            if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        }
        return
    }

    $progressId = $script:ProgressIds.Move
    for ($i = 0; $i -lt $total; $i++) {
        $f = $files[$i]
        $rel = $f.FullName.Substring($SourcePath.Length).TrimStart('\\','/')
        if ([string]::IsNullOrWhiteSpace($rel)) { $rel = $f.Name }
        $destFile = Join-Path $DestinationPath $rel
        $destDir = Split-Path -Path $destFile -Parent
        if ($destDir -and -not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

        $pct = [int]((($i + 1) / $total) * 100)
        Write-Progress -Id $progressId -Activity "Moving files..." -Status ("{0}/{1} {2}" -f ($i+1), $total, $rel) -PercentComplete $pct

        Move-Item -LiteralPath $f.FullName -Destination $destFile -Force -ErrorAction Stop
    }
    Write-Progress -Id $progressId -Activity "Moving files..." -Completed
}

function New-MigrationBackupPath {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath
    )

    $parent = Split-Path -Path $SourcePath -Parent
    $leaf = Split-Path -Path $SourcePath -Leaf
    if ([string]::IsNullOrWhiteSpace($leaf) -or [string]::IsNullOrWhiteSpace($parent)) {
        throw "Unable to determine parent or name for source path: $SourcePath"
    }

    $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
    $backupName = "$leaf.bak_mig_$timestamp"
    $candidate = Join-Path $parent $backupName
    $counter = 1
    while (Test-Path -LiteralPath $candidate) {
        $backupName = "{0}.bak_mig_{1}_{2}" -f $leaf, $timestamp, $counter
        $candidate = Join-Path $parent $backupName
        $counter++
    }

    return [pscustomobject]@{
        Name = $backupName
        Path = $candidate
    }
}

function Move-FolderWithLink {
    param(
        [string]$SourcePath,
        [string]$DevDrivePath,
        [string]$TargetPath,
        [switch]$SkipConfirmation
    )

    Reset-ProgressUI

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        Write-ColoredOutput (Get-String -Key "Migration.SourceNotExist" -Arguments @($SourcePath)) [Colors]::Warning
        return $false
    }

    # If the source directory is already a link, treat as migrated
    if (Test-IsDirectoryLink -Path $SourcePath) {
        Write-ColoredOutput (Get-String -Key "Migration.AlreadyMigrated") [Colors]::Success
        return $true
    }

    $name = Split-Path -Path $SourcePath -Leaf
    if ($TargetPath -and $TargetPath.Trim()) {
        $targetPath = $TargetPath
    } else {
        # If migrating a user dot-folder (e.g., C:\Users\<name>\.folder), place it under Dev Drive\<name>\
        $userHome = $HOME
        $userName = Split-Path -Path $userHome -Leaf
        $isUnderHome = $false
        try { $isUnderHome = $SourcePath.StartsWith($userHome, [System.StringComparison]::OrdinalIgnoreCase) } catch { $isUnderHome = ($SourcePath -like (Join-Path $userHome '*')) }
        if ($isUnderHome -and $name.StartsWith('.')) {
            $targetPath = Join-Path $DevDrivePath (Join-Path $userName $name)
        } else {
            $targetPath = Join-Path $DevDrivePath $name
        }
    }

    $backupInfo = New-MigrationBackupPath -SourcePath $SourcePath
    $backupPath = $backupInfo.Path
    $backupName = $backupInfo.Name

    # Show migration operation details
    Write-ColoredOutput (Get-String -Key "Migration.OperationDetails") [Colors]::Warning
    Write-ColoredOutput (Get-String -Key "Migration.SourcePath" -Arguments @($SourcePath)) [Colors]::Info
    Write-ColoredOutput (Get-String -Key "Migration.TargetPath" -Arguments @($targetPath)) [Colors]::Info
    # Operation summary split across lines
    Write-ColoredOutput (Get-String -Key "Migration.OperationTitle") [Colors]::Info
    Write-ColoredOutput (Get-String -Key "Migration.OperationLine1") [Colors]::Info
    Write-ColoredOutput (Get-String -Key "Migration.OperationLine2") [Colors]::Info
    Write-ColoredOutput (Get-String -Key "Migration.OperationLine3") [Colors]::Info
    Write-ColoredOutput (Get-String -Key "Migration.OperationLine4") [Colors]::Info

    # Secondary confirmation (skippable)
    if (-not $SkipConfirmation) {
        $confirm = Read-Host (Get-String -Key "Migration.ConfirmFolder" -Arguments @($name))
        if ($confirm.Trim().ToUpper() -ne 'Y') {
            Write-ColoredOutput (Get-String -Key "Migration.FolderCancelled" -Arguments @($name)) [Colors]::Warning
            return $false
        }
    }

    # Dry-run: show the planned steps and exit without changes
    if ($DryRun) {
        # Dry-run note first
        Write-ColoredOutput (Get-String -Key "Migration.DryRunNote") [Colors]::Warning
        Write-ColoredOutput (Get-String -Key "Migration.StepsHeader") [Colors]::Info
        Write-ColoredOutput (Get-String -Key "Migration.Step1RenameBackup" -Arguments @($SourcePath, $backupPath)) [Colors]::Info
        Write-ColoredOutput (Get-String -Key "Migration.Step2CopyFromBackup" -Arguments @($backupPath, $targetPath)) [Colors]::Info
        Write-ColoredOutput (Get-String -Key "Migration.Step3CreateLink" -Arguments @($SourcePath, $targetPath)) [Colors]::Info
        Write-ColoredOutput (Get-String -Key "Migration.Step4DeleteBackup" -Arguments @($backupPath)) [Colors]::Info
        return $true
    }

    $leaf = Split-Path -Path $SourcePath -Leaf
    $renameComplete = $false
    $linkCreated = $false

    try {
        Write-ColoredOutput (Get-String -Key "Migration.RenamingSource" -Arguments @($SourcePath, $backupPath)) [Colors]::Info
        Rename-Item -LiteralPath $SourcePath -NewName $backupName -ErrorAction Stop
        $renameComplete = $true
        Write-ColoredOutput (Get-String -Key "Migration.RenameCompleted" -Arguments @($backupPath)) [Colors]::Success

        if (-not (Test-Path -LiteralPath $targetPath)) {
            $parentDir = Split-Path -Path $targetPath -Parent
            if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
            Write-ColoredOutput (Get-String -Key "Migration.CreatingTargetDirectory" -Arguments @($targetPath)) [Colors]::Success
        }

        Write-ColoredOutput (Get-String -Key "Migration.StartingCopy" -Arguments @($backupPath, $targetPath)) [Colors]::Info
        Copy-DirectoryWithProgress -SourcePath $backupPath -DestinationPath $targetPath
        Write-ColoredOutput (Get-String -Key "Migration.CopyCompleted") [Colors]::Success

        Write-ColoredOutput (Get-String -Key "Migration.CreatingSymbolicLink" -Arguments @($SourcePath, $targetPath)) [Colors]::Info
        New-Item -ItemType Junction -Path $SourcePath -Target $targetPath -ErrorAction Stop | Out-Null
        $linkCreated = $true
        Write-ColoredOutput (Get-String -Key "Migration.SymbolicLinkCreated") [Colors]::Success

        Write-ColoredOutput (Get-String -Key "Migration.DeletingSource" -Arguments @($backupPath)) [Colors]::Info
        Remove-Item -LiteralPath $backupPath -Recurse -Force -ErrorAction Stop -Confirm:$false

        return $true
    } catch {
        $err = $_
        Write-ColoredOutput (Get-String -Key "Migration.MigrationFailed" -Arguments @($err.Exception.Message)) [Colors]::Error

        if ($linkCreated -and (Test-IsDirectoryLink -Path $SourcePath)) {
            Write-ColoredOutput (Get-String -Key "Migration.RemovingTemporaryLink" -Arguments @($SourcePath)) [Colors]::Warning
            try {
                $null = & cmd /c rmdir "$SourcePath"
                if ($LASTEXITCODE -ne 0) {
                    Remove-Item -LiteralPath $SourcePath -Force -ErrorAction Stop -Confirm:$false
                }
            } catch {
                Write-ColoredOutput (Get-String -Key "Migration.RemoveLinkFailed" -Arguments @($_.Exception.Message)) [Colors]::Error
            }
        }

        if ($renameComplete -and (Test-Path -LiteralPath $backupPath)) {
            Write-ColoredOutput (Get-String -Key "Migration.RestoringBackup" -Arguments @($SourcePath)) [Colors]::Warning
            try {
                Rename-Item -LiteralPath $backupPath -NewName $leaf -ErrorAction Stop
                Write-ColoredOutput (Get-String -Key "Migration.RestoreCompleted" -Arguments @($SourcePath)) [Colors]::Success
            } catch {
                Write-ColoredOutput (Get-String -Key "Migration.RestoreFailed" -Arguments @($_.Exception.Message)) [Colors]::Error
            }
        }

        return $false
    }
}

function Restore-FolderFromLink {
    param(
        [Parameter(Mandatory=$true)][string]$SourcePath,
        [string]$DisplayName,
        [switch]$SkipConfirmation
    )

    Reset-ProgressUI

    if (-not (Test-IsDirectoryLink -Path $SourcePath)) {
        Write-ColoredOutput (Get-String -Key "Restore.SourceNotLink" -Arguments @($SourcePath)) [Colors]::Warning
        return $false
    }

    $it = Get-Item -LiteralPath $SourcePath -Force -ErrorAction Stop
    $linkTarget = $null
    if ($it.PSObject.Properties['Target']) { $linkTarget = $it.Target }
    if (-not $linkTarget -and $it.PSObject.Properties['LinkTarget']) { $linkTarget = $it.LinkTarget }
    if (-not $linkTarget) {
        Write-ColoredOutput (Get-String -Key "Restore.RestoreFailed" -Arguments @($SourcePath)) [Colors]::Error
        return $false
    }

    $dest = $SourcePath
    $targetExists = Test-Path -LiteralPath $linkTarget

    if ($DisplayName) {
        Write-ColoredOutput (Get-String -Key "Restore.RestoreInProgress" -Arguments @($DisplayName)) [Colors]::Menu
    }
    Write-ColoredOutput (Get-String -Key "Restore.OperationDetails") [Colors]::Warning
    Write-ColoredOutput (Get-String -Key "Restore.LinkPath" -Arguments @($SourcePath)) [Colors]::Info
    Write-ColoredOutput (Get-String -Key "Restore.TargetPath" -Arguments @($linkTarget)) [Colors]::Info
    Write-ColoredOutput (Get-String -Key "Restore.RestorePath" -Arguments @($dest)) [Colors]::Info
    Write-ColoredOutput (Get-String -Key "Restore.OperationLabel") [Colors]::Info
    if (-not $targetExists) { Write-ColoredOutput (Get-String -Key "Restore.NoteTargetMissing") [Colors]::Warning }

    if (-not $SkipConfirmation) {
        $confirm = Read-Host (Get-String -Key "Restore.ConfirmProceed")
        if ($confirm.Trim().ToUpper() -ne 'Y') {
            Write-ColoredOutput (Get-String -Key "Common.Cancelled") [Colors]::Warning
            return $false
        }
    }

    if ($DryRun) {
        Write-ColoredOutput (Get-String -Key "Restore.Step1RemoveLink" -Arguments @($SourcePath)) [Colors]::Info
        Write-ColoredOutput (Get-String -Key "Restore.Step2EnsureDir" -Arguments @($dest)) [Colors]::Info
        Write-ColoredOutput (Get-String -Key "Restore.Step3Restore" -Arguments @($linkTarget, $dest)) [Colors]::Info
        if ($targetExists) { Write-ColoredOutput (Get-String -Key "Restore.Step4Cleanup" -Arguments @($linkTarget)) [Colors]::Info }
        Write-ColoredOutput "      (Dry-run) No changes will be made." [Colors]::Warning
        return $true
    }

    Write-ColoredOutput (Get-String -Key "Restore.Step1RemoveLink" -Arguments @($SourcePath)) [Colors]::Info
    $null = & cmd /c rmdir "$SourcePath"
    if ($LASTEXITCODE -ne 0) {
        Remove-Item -LiteralPath $SourcePath -Force -ErrorAction Stop -Confirm:$false
    }

    if (-not (Test-Path -LiteralPath $dest)) {
        Write-ColoredOutput (Get-String -Key "Restore.Step2EnsureDir" -Arguments @($dest)) [Colors]::Info
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
    } else {
        Write-ColoredOutput (Get-String -Key "Restore.Step2EnsureDir" -Arguments @($dest)) [Colors]::Info
    }

    if ($targetExists) {
        Write-ColoredOutput (Get-String -Key "Restore.Step3Restore" -Arguments @($linkTarget, $dest)) [Colors]::Info
        $moveFrom = Join-Path $linkTarget '*'
        Move-Item -Path $moveFrom -Destination $dest -Force -ErrorAction Stop

        Write-ColoredOutput (Get-String -Key "Restore.Step4Cleanup" -Arguments @($linkTarget)) [Colors]::Info
        Remove-Item -LiteralPath $linkTarget -Recurse -Force -ErrorAction Stop -Confirm:$false
    } else {
        Write-ColoredOutput (Get-String -Key "Restore.TargetMissing") [Colors]::Info
    }

    Write-ColoredOutput (Get-String -Key "Restore.RestoreComplete") [Colors]::Success
    return $true
}


 
function Invoke-DotFolderMigration {
    param([string]$DevDrivePath)

    Reset-ProgressUI

    # 1) Scan and display
    Write-ColoredOutput (Get-String -Key "DotFolders.Scanning") [Colors]::Info
    $folders = @(Get-DotFolders)
    if ($folders.Count -eq 0) {
        Write-ColoredOutput (Get-String -Key "DotFolders.NoneFound") [Colors]::Warning
        return
    }

    # Aligned header for: No. (3) + 4sp, Name (27), Size(GB) (8), Status (10), Migrated (8), Path (60)
    $idxH = Get-String -Key "CacheMenuHeadings.No"
    $nameH = Format-FixedWidth -Text (Get-String -Key "CacheMenuHeadings.Name") -Width 27 -Align Left
    $sizeH = Get-String -Key "CacheMenuHeadings.Size"
    $statusH = Get-String -Key "CacheMenuHeadings.Status"
    $migrH = Get-String -Key "CacheMenuHeadings.Migrated"
    $pathH = Format-FixedWidth -Text (Get-String -Key "CacheMenuHeadings.Path") -Width 60 -Align Left
    Write-ColoredOutput (Get-String -Key "CacheMenuTable.Header" -Arguments @($idxH, $nameH, $sizeH, $statusH, $migrH, $pathH)) [Colors]::Header
    $dash = '-'
    $idxD = $dash * 3; $nameD = $dash * 27; $sizeD = $dash * 8; $statusD = $dash * 10; $migrD = $dash * 8; $pathD = $dash * 60
    Write-ColoredOutput (Get-String -Key "CacheMenuTable.Detail" -Arguments @($idxD, $nameD, $sizeD, $statusD, $migrD, $pathD)) [Colors]::Header

    $nonEmpty = @()
    if (-not $DryRun) {
        # Calculate size and show scanning progress
        $sizes = @()
        $progressId = $script:ProgressIds.ScanFolders
        for ($i=0; $i -lt $folders.Count; $i++) {
            $dir = $folders[$i]
            $pct = [int]((($i + 1) / $folders.Count) * 100)
            Write-Progress -Id $progressId -Activity "Scanning hidden folders..." -Status ("{0}/{1} {2}" -f ($i+1), $folders.Count, $dir.Name) -PercentComplete $pct
            if (Test-IsDirectoryLink -Path $dir.FullName) {
                $sizes += 0
            } else {
                $sizes += (Get-FolderSizeBytes -Path $dir.FullName)
            }
        }
        Write-Progress -Id $progressId -Activity "Scanning hidden folders..." -Completed

        # Filter out folders with 0 GB size or migrated folders
        for ($i=0; $i -lt $folders.Count; $i++) {
            $isMigrated = Test-IsDirectoryLink -Path $folders[$i].FullName
            if ([long]$sizes[$i] -gt 0 -or $isMigrated) {
                $nonEmpty += [PSCustomObject]@{
                    Dir = $folders[$i];
                    SizeBytes = if ($isMigrated) { $null } else { [long]$sizes[$i] }
                    IsMigrated = $isMigrated
                }
            }
        }

        if ($nonEmpty.Count -eq 0) {
            Write-ColoredOutput (Get-String -Key "DotFolders.AllZeroSize") [Colors]::Warning
            return
        }

        for ($j=0; $j -lt $nonEmpty.Count; $j++) {
            $dir = $nonEmpty[$j].Dir
            $indexVal = $j + 1
            $name = Format-FixedWidth -Text $dir.Name -Width 27 -Align Left
            if ($nonEmpty[$j].IsMigrated) {
                $sizeText = "-"
                $statusText = Get-String -Key "CacheMenuStatus.Linked"
                $migratedText = "Yes"
            } else {
                $sizeBytes = [long]$nonEmpty[$j].SizeBytes
                $sizeText = if ($sizeBytes -gt 0) { "{0:N2}" -f ([math]::Round($sizeBytes/1GB, 2)) } else { "0.00" }
                $statusText = Get-String -Key "CacheMenuStatus.Exists"
                $migratedText = "No"
            }
            $pathText = Format-FixedWidth -Text $dir.FullName -Width 60 -Align Left
            Write-ColoredOutput (Get-String -Key "CacheMenuTable.FolderList" -Arguments @($indexVal, $name, $sizeText, $statusText, $migratedText, $pathText)) [Colors]::Info
        }
    } else {
        # Dry-run: don't calculate sizes, list all
        for ($i=0; $i -lt $folders.Count; $i++) {
            $dir = $folders[$i]
            $isMigrated = Test-IsDirectoryLink -Path $dir.FullName
            $nonEmpty += [PSCustomObject]@{ Dir = $dir; SizeBytes = $null; IsMigrated = $isMigrated }
            $indexVal = $i + 1
            $name = Format-FixedWidth -Text $dir.Name -Width 27 -Align Left
            $sizeText = "-"
            $statusText = if ($isMigrated) { Get-String -Key "CacheMenuStatus.Linked" } else { Get-String -Key "CacheMenuStatus.Exists" }
            $migratedText = if ($isMigrated) { "Yes" } else { "No" }
            $pathText = Format-FixedWidth -Text $dir.FullName -Width 60 -Align Left
            Write-ColoredOutput (Get-String -Key "CacheMenuTable.FolderList" -Arguments @($indexVal, $name, $sizeText, $statusText, $migratedText, $pathText)) [Colors]::Info
        }
    }

    Write-Host ""
    # 2) Select migration targets
    Write-ColoredOutput (Get-String -Key "DotFolders.SelectFoldersPrompt") [Colors]::Info
    Write-ColoredOutput (Get-String -Key "DotFolders.SelectFoldersHint") [Colors]::Warning

    $selectedIndices = @()
    while ($true) {
        $inputSel = Read-Host (Get-String -Key "Common.EnterSelection")
        if ([string]::IsNullOrWhiteSpace($inputSel)) { Write-ColoredOutput (Get-String -Key "Common.NoMigrationPerformed") [Colors]::Warning; return }
        switch ($inputSel.Trim().ToUpper()) {
            'Q' { Write-ColoredOutput (Get-String -Key "Common.Cancelled") [Colors]::Warning; return }
            'A' { $selectedIndices = 1..$nonEmpty.Count; break }
            default {
                $set = New-Object System.Collections.Generic.HashSet[int]
                $tokens = $inputSel -split "[，,]"
                foreach ($t in $tokens) {
                    $tok = $t.Trim()
                    if ($tok -match '^(\d+)$') {
                        $n = [int]$matches[1]
                        if ($n -ge 1 -and $n -le $nonEmpty.Count) { $set.Add($n) | Out-Null }
                    } elseif ($tok -match '^(\d+)\s*-\s*(\d+)$') {
                        $a = [int]$matches[1]; $b = [int]$matches[2]
                        if ($a -gt $b) { $tmp = $a; $a = $b; $b = $tmp }
                        $a = [Math]::Max(1, $a); $b = [Math]::Min($nonEmpty.Count, $b)
                        for ($n=$a; $n -le $b; $n++) { $set.Add($n) | Out-Null }
                    }
                }
                # Convert to array safely for both single values and collections
                if ($set.Count -gt 0) { $selectedIndices = @($set) | Sort-Object; break }
                Write-ColoredOutput (Get-String -Key "DotFolders.InvalidSelection") [Colors]::Error
            }
        }
        # If we have a valid selection, leave the input loop and continue
        if ($selectedIndices -and $selectedIndices.Count -gt 0) { break }
    }

    # 3) Confirm and perform actions (Restore for migrated links; Migrate for normal folders)
    $toRestore = @()
    $toMigrate = @()
    foreach ($n in $selectedIndices) {
        $dir = $nonEmpty[$n-1].Dir
        if (Test-IsDirectoryLink -Path $dir.FullName) { $toRestore += $dir } else { $toMigrate += $dir }
    }

    # selected item count (unused variable removed)
    $totalText = "-"
    if (-not $DryRun -and $toMigrate.Count -gt 0) {
        $totalBytes = 0
        foreach ($dir in $toMigrate) {
            $size = (Get-ChildItem -LiteralPath $dir.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            if ($size) { $totalBytes += [long]$size }
        }
        $totalGB = if ($totalBytes) { [math]::Round($totalBytes/1GB,2) } else { 0 }
        $totalText = "$totalGB"
    }

    Write-Host ""
    if ($toRestore.Count -gt 0 -and $toMigrate.Count -eq 0) {
        Write-ColoredOutput (Get-String -Key "DotFolderOperations.WillRestore" -Arguments @($toRestore.Count)) [Colors]::Menu
        foreach ($d in $toRestore) { Write-ColoredOutput (Get-String -Key "DotFolderOperations.FolderItem" -Arguments @($d.FullName)) [Colors]::Info }
        $confirm = Read-Host "Confirm to start restore? (Y/N)"
        if ($confirm.Trim().ToUpper() -ne 'Y') { Write-ColoredOutput (Get-String -Key "DotFolderOperations.RestoreCancelled") [Colors]::Warning; return }
        foreach ($d in $toRestore) {
            Write-ColoredOutput (Get-String -Key "DotFolderOperations.Restoring" -Arguments @($d.FullName)) [Colors]::Menu
            [void](Restore-FolderFromLink -SourcePath $d.FullName)
            Write-Host ""
        }
        return
    }

    if ($toRestore.Count -eq 0 -and $toMigrate.Count -gt 0) {
        if (-not $DryRun) {
            Write-ColoredOutput (Get-String -Key "DotFolderOperations.WillMigrate" -Arguments @($toMigrate.Count, $totalText)) [Colors]::Menu
        } else {
            Write-ColoredOutput (Get-String -Key "DotFolderOperations.WillMigrateSimple" -Arguments @($toMigrate.Count)) [Colors]::Menu
        }
        foreach ($d in $toMigrate) { Write-ColoredOutput (Get-String -Key "DotFolderOperations.FolderItem" -Arguments @($d.FullName)) [Colors]::Info }
        foreach ($d in $toMigrate) {
            Write-ColoredOutput (Get-String -Key "DotFolderOperations.Migrating" -Arguments @($d.FullName)) [Colors]::Menu
            [void](Move-FolderWithLink -SourcePath $d.FullName -DevDrivePath $DevDrivePath)
            Write-Host ""
        }
        return
    }

    # Mixed: both restore and migrate
    if ($toRestore.Count -gt 0 -and $toMigrate.Count -gt 0) {
        Write-ColoredOutput (Get-String -Key "DotFolderOperations.WillRestoreSimple" -Arguments @($toRestore.Count)) [Colors]::Menu
        foreach ($d in $toRestore) { Write-ColoredOutput (Get-String -Key "DotFolderOperations.FolderItem" -Arguments @($d.FullName)) [Colors]::Info }
        if (-not $DryRun) {
            Write-ColoredOutput (Get-String -Key "DotFolderOperations.WillMigrateCaps" -Arguments @($toMigrate.Count, $totalText)) [Colors]::Menu
        } else {
            Write-ColoredOutput (Get-String -Key "DotFolderOperations.WillMigrateCapsSimple" -Arguments @($toMigrate.Count)) [Colors]::Menu
        }
        foreach ($d in $toMigrate) { Write-ColoredOutput (Get-String -Key "DotFolderOperations.FolderItem" -Arguments @($d.FullName)) [Colors]::Info }
        foreach ($d in $toRestore) {
            Write-ColoredOutput (Get-String -Key "DotFolderOperations.Restoring" -Arguments @($d.FullName)) [Colors]::Menu
            [void](Restore-FolderFromLink -SourcePath $d.FullName)
            Write-Host ""
        }
        foreach ($d in $toMigrate) {
            Write-ColoredOutput (Get-String -Key "DotFolderOperations.Migrating" -Arguments @($d.FullName)) [Colors]::Menu
            [void](Move-FolderWithLink -SourcePath $d.FullName -DevDrivePath $DevDrivePath)
            Write-Host ""
        }
        return
    }
}




## Reset-CacheEnvironment removed: script no longer manipulates environment variables

function Move-CacheToDevDrive {
    param(
        [string]$CacheKey,
        [hashtable]$Config,
        [string]$DevDrivePath
    )
    Reset-ProgressUI

    $cacheName = $Config.Name
    $sourcePath = $Config.DefaultPath
    $targetPath = Join-Path $DevDrivePath "Cache\$CacheKey"

    Write-ColoredOutput (Get-String -Key "CacheMigrationDetails.Configuring" -Arguments @($cacheName)) [Colors]::Info

    # Create target directory
    $targetCreated = $false
    if (!(Test-Path $targetPath)) {
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
        }
        $targetCreated = $true
        Write-ColoredOutput (Get-String -Key "CacheMigrationDetails.CreatingTarget" -Arguments @($targetPath)) [Colors]::Success
    }

    # If the source is already a directory link (junction or symbolic link), mark as migrated and skip moving
    $skipMove = $false
    if ((Test-Path -LiteralPath $sourcePath) -and (Test-IsDirectoryLink -Path $sourcePath)) {
        $it = Get-Item -LiteralPath $sourcePath -Force -ErrorAction SilentlyContinue
        $linkTarget = $null
        if ($it -and $it.PSObject.Properties['Target']) { $linkTarget = $it.Target }
        if (-not $linkTarget -and $it -and $it.PSObject.Properties['LinkTarget']) { $linkTarget = $it.LinkTarget }
        if ($linkTarget) { $targetPath = $linkTarget }
        $replyRestore = Read-Host ("   Detected directory link. Restore {0} to default location? (Y/N)" -f $cacheName)
        if ($replyRestore.Trim().ToUpper() -eq 'Y') {
            [void](Restore-FolderFromLink -SourcePath $sourcePath)
            return $true
        }
        Write-ColoredOutput (Get-String -Key "CacheMigrationDetails.SourceAlreadyLinked" -Arguments @($targetPath)) [Colors]::Success
        $skipMove = $true
    }

    # Move existing cache if it exists (transactional with rollback)
    if ((-not $skipMove) -and (Test-Path -LiteralPath $sourcePath)) {
        Write-ColoredOutput (Get-String -Key "CacheMigrationDetails.PreparingMigration") [Colors]::Info

        Write-ColoredOutput (Get-String -Key "CacheMigrationDetails.Starting") [Colors]::Info
        $backupInfo = New-MigrationBackupPath -SourcePath $sourcePath
        $backupPath = $backupInfo.Path
        $backupName = $backupInfo.Name
        $migrationSucceeded = $false

        if ($DryRun) {
            Write-ColoredOutput (Get-String -Key "Migration.DryRunNote") [Colors]::Warning
            Write-ColoredOutput (Get-String -Key "Migration.StepsHeader") [Colors]::Info
            Write-ColoredOutput (Get-String -Key "Migration.Step1RenameBackup" -Arguments @($sourcePath, $backupPath)) [Colors]::Info
            Write-ColoredOutput (Get-String -Key "Migration.Step2CopyFromBackup" -Arguments @($backupPath, $targetPath)) [Colors]::Info
            Write-ColoredOutput (Get-String -Key "Migration.Step3CreateLink" -Arguments @($sourcePath, $targetPath)) [Colors]::Info
            Write-ColoredOutput (Get-String -Key "Migration.Step4DeleteBackup" -Arguments @($backupPath)) [Colors]::Info
            $migrationSucceeded = $true
        } else {
            $renameComplete = $false
            $linkCreated = $false
            try {
                Write-ColoredOutput (Get-String -Key "Migration.RenamingSource" -Arguments @($sourcePath, $backupPath)) [Colors]::Info
                Rename-Item -LiteralPath $sourcePath -NewName $backupName -ErrorAction Stop
                $renameComplete = $true
                Write-ColoredOutput (Get-String -Key "Migration.RenameCompleted" -Arguments @($backupPath)) [Colors]::Success

                if (-not (Test-Path -LiteralPath $targetPath)) {
                    New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
                    Write-ColoredOutput (Get-String -Key "CacheMigrationDetails.CreatingTarget" -Arguments @($targetPath)) [Colors]::Success
                }

                Write-ColoredOutput (Get-String -Key "Migration.StartingCopy" -Arguments @($backupPath, $targetPath)) [Colors]::Info
                $backupItem = Get-Item -LiteralPath $backupPath -Force
                if ($backupItem -and $backupItem.PSIsContainer) {
                    Copy-DirectoryWithProgress -SourcePath $backupPath -DestinationPath $targetPath
                } else {
                    Copy-Item -LiteralPath $backupPath -Destination $targetPath -Force -ErrorAction Stop
                }
                Write-ColoredOutput (Get-String -Key "Migration.CopyCompleted") [Colors]::Success

                Write-ColoredOutput (Get-String -Key "Migration.CreatingSymbolicLink" -Arguments @($sourcePath, $targetPath)) [Colors]::Info
                New-Item -ItemType Junction -Path $sourcePath -Target $targetPath -ErrorAction Stop | Out-Null
                $linkCreated = $true
                Write-ColoredOutput (Get-String -Key "Migration.SymbolicLinkCreated") [Colors]::Success

                Write-ColoredOutput (Get-String -Key "Migration.DeletingSource" -Arguments @($backupPath)) [Colors]::Info
                Remove-Item -LiteralPath $backupPath -Recurse -Force -ErrorAction Stop -Confirm:$false

                $migrationSucceeded = $true
            } catch {
                $err = $_
                Write-ColoredOutput (Get-String -Key "Migration.MigrationFailed" -Arguments @($err.Exception.Message)) [Colors]::Error

                if ($linkCreated -and (Test-IsDirectoryLink -Path $sourcePath)) {
                    Write-ColoredOutput (Get-String -Key "Migration.RemovingTemporaryLink" -Arguments @($sourcePath)) [Colors]::Warning
                    try {
                        $null = & cmd /c rmdir "$sourcePath"
                        if ($LASTEXITCODE -ne 0) {
                            Remove-Item -LiteralPath $sourcePath -Force -ErrorAction Stop -Confirm:$false
                        }
                    } catch {
                        Write-ColoredOutput (Get-String -Key "Migration.RemoveLinkFailed" -Arguments @($_.Exception.Message)) [Colors]::Error
                    }
                }

                if ($renameComplete -and (Test-Path -LiteralPath $backupPath)) {
                    Write-ColoredOutput (Get-String -Key "Migration.RestoringBackup" -Arguments @($sourcePath)) [Colors]::Warning
                    try {
                        $originalName = Split-Path -Path $sourcePath -Leaf
                        Rename-Item -LiteralPath $backupPath -NewName $originalName -ErrorAction Stop
                        Write-ColoredOutput (Get-String -Key "Migration.RestoreCompleted" -Arguments @($sourcePath)) [Colors]::Success
                    } catch {
                        Write-ColoredOutput (Get-String -Key "Migration.RestoreFailed" -Arguments @($_.Exception.Message)) [Colors]::Error
                    }
                }

                return $false
            }
        }

        if ($migrationSucceeded) {
            Write-ColoredOutput (Get-String -Key "CacheMigrationDetails.MigrationSuccess") [Colors]::Success
        }
    }

    # Ensure source path points to the target through a directory link
    if (-not (Test-IsDirectoryLink -Path $sourcePath)) {
        if (Test-Path -LiteralPath $sourcePath) {
            if (-not $DryRun) {
                Remove-Item -LiteralPath $sourcePath -Recurse -Force -ErrorAction SilentlyContinue -Confirm:$false
            }
        }
        Write-ColoredOutput (Get-String -Key "Migration.CreatingSymbolicLink" -Arguments @($sourcePath, $targetPath)) [Colors]::Info
        if (-not $DryRun) {
            New-Item -ItemType Junction -Path $sourcePath -Target $targetPath -ErrorAction Stop | Out-Null
            Write-ColoredOutput (Get-String -Key "Migration.SymbolicLinkCreated") [Colors]::Success
        } else {
            Write-ColoredOutput "      (Dry-run) Skipping link creation" [Colors]::Warning
        }
    }

    # Junction-only: skip environment variable backup

    # Junction-only: do not modify any environment variables

    # Junction-only: environment backup not applicable

    # Junction-only mode: no special cache handling or environment variable changes
}



function Show-Summary {
    param([array]$ConfiguredCaches)

    Write-ColoredOutput (Get-String -Key "CacheMigrationDetails.ConfigurationComplete") [Colors]::Success
    Write-ColoredOutput (Get-String -Key "CacheMigrationDetails.ConfiguredCaches") [Colors]::Header

    foreach ($cache in $ConfiguredCaches) {
        Write-ColoredOutput (Get-String -Key "CacheMigrationDetails.CacheItemSuccess" -Arguments @($cache.Name)) [Colors]::Success
    }

    Write-Host ""
    Write-ColoredOutput (Get-String -Key "CacheMigrationDetails.ImportantNotes") [Colors]::Warning
    Write-ColoredOutput (Get-String -Key "CacheMigrationDetails.NoteRestartApps") [Colors]::Warning
    Write-ColoredOutput (Get-String -Key "CacheMigrationDetails.NoteReconfigure") [Colors]::Warning
    Write-ColoredOutput (Get-String -Key "CacheMigrationDetails.NoteMoveProjects") [Colors]::Info
    Write-ColoredOutput (Get-String -Key "CacheMigrationDetails.NoteScriptPurpose") [Colors]::Info
}

# Main execution
function Invoke-Main {
    # Handle version parameter
    if ($Version) {
        Write-ColoredOutput "Dev Drive Cache Migration Script v$script:ScriptVersion" [Colors]::Info
        Write-ColoredOutput "Dev Drive Migration Version" [Colors]::Info
        return
    }

    Show-Header
    Test-PowerShellVersion
    Test-WindowsVersion

  
    $devDrivePath = Get-DevDrivePath $DevDrivePath
    if (!$devDrivePath) {
        Write-ColoredOutput (Get-String -Key "Common.DevDriveNotFound") [Colors]::Error
        exit 1
    }

    $configuredCaches = @()

    do {
        Show-CacheMenuEx $CacheConfigs $devDrivePath
        # Use sorted keys for consistent menu max calculation
        $keys = $CacheConfigs.Keys | Sort-Object { $CacheConfigs[$_].Name }
        $max = $keys.Count
        $choice = Read-Host (Get-String -Key "CacheMenuEx.SelectionPrompt" -Arguments @($max))

        if ([string]::IsNullOrEmpty($choice)) {
            continue
        }

        switch ($choice.ToUpper()) {
            "Q" {
                Write-ColoredOutput (Get-String -Key "Common.Exit") [Colors]::Info
                return
            }
            default {
                if ($choice -match '^[dD]$') { Invoke-DotFolderMigration -DevDrivePath $devDrivePath; Read-Host "$(Get-String -Key 'CacheMenu.PressAnyKeyToReturnToMenu')" | Out-Null; continue }
                if ($choice -match '^[mM]$') { Invoke-DotFolderMigration -DevDrivePath $devDrivePath; Read-Host "$(Get-String -Key 'CacheMenu.PressAnyKeyToReturnToMenu')" | Out-Null; continue }

                # Parse numeric selection separately to avoid masking runtime errors as input errors
                $sel = $null
                if (-not [int]::TryParse($choice, [ref]$sel)) {
                    Write-ColoredOutput (Get-String -Key "Common.InvalidSelection") [Colors]::Error
                    Start-Sleep -Seconds 1
                    continue
                }

                # Use the same sorted keys as in Show-CacheMenuEx for consistent ordering
                $keys = $CacheConfigs.Keys | Sort-Object { $CacheConfigs[$_].Name }

                $index = $sel - 1
                if ($index -ge 0 -and $index -lt $keys.Count) {
                    $selectedKey = $keys[$index]
                    $cfg = $CacheConfigs[$selectedKey]
                    $srcPath = $cfg.DefaultPath
                    # Junction-only mode: do not inspect environment variables
                    if (Test-IsDirectoryLink -Path $srcPath) {
                        $reply = Read-Host (Get-String -Key "Restore.ConfirmStart" -Arguments @($cfg.Name))
                        if ($reply.Trim().ToUpper() -eq 'Y') {
                            [void](Restore-FolderFromLink -SourcePath $srcPath -DisplayName $cfg.Name)
                        } else {
                            Write-ColoredOutput (Get-String -Key "DotFolderOperations.SkippedRestore") [Colors]::Info
                        }
                    } else {
                        # Junction-only mode: proceed to migration details
                        # Display migration operation details before proceeding
                        $targetPath = if ($selectedKey -eq 'temp') { (Join-Path $DevDrivePath 'Temp') } else { (Join-Path $DevDrivePath ("Cache/" + $selectedKey)) }

                        Write-ColoredOutput (Get-String -Key "Migration.OperationDetails") [Colors]::Warning
                        Write-ColoredOutput (Get-String -Key "Migration.CacheType" -Arguments @($cfg.Name)) [Colors]::Info
                        Write-ColoredOutput (Get-String -Key "Migration.SourcePath" -Arguments @($cfg.DefaultPath)) [Colors]::Info
                        Write-ColoredOutput (Get-String -Key "Migration.TargetPath" -Arguments @($targetPath)) [Colors]::Info
                        # Operation summary split across lines
                        Write-ColoredOutput (Get-String -Key "Migration.OperationTitle") [Colors]::Info
                        Write-ColoredOutput (Get-String -Key "Migration.OperationLine1") [Colors]::Info
                        Write-ColoredOutput (Get-String -Key "Migration.OperationLine2") [Colors]::Info
                        Write-ColoredOutput (Get-String -Key "Migration.OperationLine3") [Colors]::Info
                        Write-ColoredOutput (Get-String -Key "Migration.OperationLine4") [Colors]::Info
                        $backupPreview = New-MigrationBackupPath -SourcePath $cfg.DefaultPath
                        $previewBackupPath = $backupPreview.Path
                        # Refined step plan
                        if ($DryRun) { Write-ColoredOutput (Get-String -Key "Migration.DryRunNote") [Colors]::Warning }
                        Write-ColoredOutput (Get-String -Key "Migration.StepsHeader") [Colors]::Info
                        Write-ColoredOutput (Get-String -Key "Migration.Step1RenameBackup" -Arguments @($cfg.DefaultPath, $previewBackupPath)) [Colors]::Info
                        Write-ColoredOutput (Get-String -Key "Migration.Step2CopyFromBackup" -Arguments @($previewBackupPath, $targetPath)) [Colors]::Info
                        Write-ColoredOutput (Get-String -Key "Migration.Step3CreateLink" -Arguments @($cfg.DefaultPath, $targetPath)) [Colors]::Info
                        Write-ColoredOutput (Get-String -Key "Migration.Step4DeleteBackup" -Arguments @($previewBackupPath)) [Colors]::Info

                        # Secondary confirmation
                        $confirm = Read-Host (Get-String -Key "Migration.ConfirmFolder" -Arguments @($cfg.Name))
                        if ($confirm.Trim().ToUpper() -ne 'Y') {
                            Write-ColoredOutput (Get-String -Key "Migration.FolderCancelled" -Arguments @($cfg.Name)) [Colors]::Warning
                        } else {
                            Move-CacheToDevDrive $selectedKey $cfg $devDrivePath
                            if (-not $DryRun) { $configuredCaches += $cfg }
                        }

                        Write-ColoredOutput (Get-String -Key "Common.PressAnyKeyContinue") [Colors]::Info
                        Read-Host | Out-Null
                    }
                }
            }
        }
    } while ($true)

    if ($configuredCaches.Count -gt 0) {
        Show-Summary $configuredCaches
    }
}

# Run main function
Invoke-Main
