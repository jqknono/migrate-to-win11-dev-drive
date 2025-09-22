# Dev Drive 快取遷移腳本

其他語言:
| [English](README.en-us.md) | [简体中文](README.md) | [繁体中文](README.zh-tw.md) | [日本語](README.ja-jp.md) | [한국어](README.ko-kr.md) | [Français](README.fr-fr.md) | [Deutsch](README.de-de.md) | [Italiano](README.it-it.md) | [Español](README.es-es.md) | [Русский](README.ru-ru.md) | [Português (BR)](README.pt-br.md) | [Nederlands](README.nl-nl.md) | [Türkçe](README.tr-tr.md) | [العربية](README.ar-sa.md) | [हिंदी](README.hi-in.md) | [ไทย](README.th-th.md) |

## 簡介

[Dev Drive 快取遷移腳本](https://github.com/jqknono/migrate-to-win11-dev-drive)是一個互動式 PowerShell 工具，旨在幫助開發者將各種開發工具的快取目錄遷移到 Windows 11 的 Dev Drive (ReFS 檔案系統) 上，以提高效能、延長硬碟壽命並減少磁碟空間佔用。

### 核心優勢

- **延長硬碟壽命**: 透過將頻繁讀寫的快取檔案移動到 Dev Drive，可以減少對系統碟 (通常是 SSD) 的寫入次數，從而延長其使用壽命。
- **減少磁碟空間佔用**: 將龐大的快取檔案 (如 Node.js 的 `node_modules` 快取、Python 的 pip 快取等) 從系統碟移出，可以顯著釋放寶貴的系統碟空間。
- **高效能**: 利用 Dev Drive 的 ReFS 檔案系統和優化特性，可以提升快取的讀寫速度，加快建構和開發工具的回應速度。

### Copy-on-Write (COW) 技術

Dev Drive 基於 ReFS 檔案系統，利用了 Copy-on-Write (COW) 技術。COW 是一種資源管理技術，其核心思想是：當多個呼叫者同時請求相同資源時，它們最初會共享同一份資源。只有當某個呼叫者需要修改資源時，系統才會為該呼叫者建立一份資源的副本，然後讓其修改這個副本，而不會影響到其他呼叫者所使用的原始資源。

在 Dev Drive 的場景中，COW 技術帶來了顯著的優勢：

1.  **高效的檔案複製**: 當需要複製一個大檔案時，ReFS 不會立即進行實際的資料複製，而是建立一個新的檔案入口指向相同的磁碟區塊。只有當原始檔案或目標檔案被修改時，才真正複製被修改的資料區塊。這使得檔案複製操作變得非常快速，並且幾乎不佔用額外的磁碟空間（直到發生修改）。
2.  **節省磁碟空間**: 對於包含大量相似檔案的快取目錄（例如，多個專案依賴的相同版本的套件），COW 可以有效地共享未修改的資料區塊，從而減少整體磁碟佔用。
3.  **提高效能**: 減少了不必要的資料複製操作，提高了檔案操作的效率。

### Dev Drive 與 refs 特性

Windows 11 引入了 Dev Drive，這是一種專為開發者優化的儲存卷。Dev Drive 使用 Resilient File System (ReFS) 作為其檔案系統，並啟用了專門的優化功能。

**ReFS (Resilient File System)** 是微軟開發的新一代檔案系統，相比於傳統的 NTFS，它具有以下優勢：

- **資料完整性**: 透過校驗和和自動修復功能提高資料的可靠性。
- **可擴展性**: 支援更大的卷和檔案大小。
- **效能優化**: 針對虛擬化和大資料工作負載進行了優化。
- **整合 COW**: 原生支援 Copy-on-Write 語意，這對於開發場景中的檔案操作尤其有利。

**Dev Drive 優化**: 在 ReFS 的基礎上，Dev Drive 進一步為開發者工作負載進行了優化，例如針對套件管理器快取、建構輸出等場景的效能提升。

## 腳本功能

本腳本提供以下主要功能：

- **遷移快取**: 支援將多種開發工具的快取目錄遷移到 Dev Drive。
  - Node.js (npm, yarn, pnpm)
  - Python (pip)
  - .NET (NuGet)
  - Java (Maven, Gradle)
  - Go (Go modules)
  - Rust (Cargo)
  - VS Code 擴充功能
  - Windows TEMP/TMP 目錄
    - JetBrains IDE (IntelliJ, PyCharm 等)
  - Android SDK
  - Chocolatey (Windows 套件管理器)
  - 使用者隱藏資料夾 (.xxx)
- **恢復快取**: 將已遷移到 Dev Drive 的快取目錄恢復到其原始位置。
- **連結遷移**: 透過建立符號連結/連接點遷移快取目錄，不修改任何環境變數。
- **測試模式**: 提供安全的模擬操作，用於測試 Dev Drive 刪除等功能，而不會實際修改系統。

## 使用說明

1.  **系統需求**:
    - Windows 11 (Build 22000 或更高版本)
    - PowerShell 7+ (pwsh)
2.  **執行腳本**:
    - 以管理員身分開啟 PowerShell 7 (pwsh)。
    - 巡覽到腳本所在目錄。
    - 執行 `.\Setup-DevDriveCache.ps1`。
3.  **互動式操作**:
    - 腳本啟動後會顯示一個互動式選單，引導您完成各種操作。
    - 選擇相應的選項來遷移快取、建立或刪除 Dev Drive 等。
    - 所有关鍵操作都需要使用者確認，確保安全。

## 注意事項

- **目的**: 此腳本的目的是遷移快取資料夾，而不是清理它們。遷移後，原始快取資料仍然存在，只是儲存位置發生了變化。
- **備份**: 在進行重大操作（如刪除 Dev Drive）之前，建議備份重要資料。
- **環境變數**: 腳本不會讀取或寫入使用者環境變數；遷移透過符號連結完成。

## 參考資料

- [Microsoft Dev Drive 官方文件](https://learn.microsoft.com/en-us/windows/dev-drive/)
- [Resilient File System (ReFS) 官方文件](https://learn.microsoft.com/en-us/windows-server/storage/refs/refs-overview)

## 支援

- [寧屏去廣告](https://www.nullprivate.com)