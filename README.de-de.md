# Dev Drive Cache-Migrationsskript

Andere Sprachen:
| [English](README.en-us.md) | [简体中文](README.md) | [繁体中文](README.zh-tw.md) | [日本語](README.ja-jp.md) | [한국어](README.ko-kr.md) | [Français](README.fr-fr.md) | [Deutsch](README.de-de.md) | [Italiano](README.it-it.md) | [Español](README.es-es.md) | [Русский](README.ru-ru.md) | [Português (BR)](README.pt-br.md) | [Nederlands](README.nl-nl.md) | [Türkçe](README.tr-tr.md) | [العربية](README.ar-sa.md) | [हिंदी](README.hi-in.md) | [ไทย](README.th-th.md) |

## Einführung

Das [Dev Drive Cache-Migrationsskript](https://github.com/jqknono/migrate-to-win11-dev-drive) ist ein interaktives PowerShell-Tool, das Entwicklern dabei hilft, verschiedene Cache-Verzeichnisse von Entwicklungstools auf das Dev Drive von Windows 11 (ReFS-Dateisystem) zu migrieren, um die Leistung zu verbessern, die Lebensdauer der Festplatte zu verlängern und den Speicherplatz zu reduzieren.

### Kernvorteile

- **Verlängerte Festplattenlebensdauer**: Durch das Verschieben von häufig gelesenen und beschriebenen Cachedateien auf das Dev Drive wird die Anzahl der Schreibvorgänge auf die Systemfestplatte (in der Regel eine SSD) reduziert, wodurch deren Lebensdauer verlängert wird.
- **Reduzierter Speicherplatzbedarf**: Das Verschieben großer Cachedateien (wie z.B. den `node_modules`-Cache von Node.js, den pip-Cache von Python usw.) von der Systemfestplatte kann wertvollen Speicherplatz auf der Systemfestplatte freigeben.
- **Hohe Leistung**: Durch die Nutzung des ReFS-Dateisystems und der Optimierungsmerkmale von Dev Drive können die Lese- und Schreibgeschwindigkeiten des Caches verbessert werden, was die Build-Zeiten und die Reaktionsfähigkeit der Entwicklungstools beschleunigt.

### Copy-on-Write (COW)-Technologie

Dev Drive basiert auf dem ReFS-Dateisystem und nutzt die Copy-on-Write (COW)-Technologie. COW ist eine Ressourcenverwaltungstechnologie, deren Kernidee darin besteht: Wenn mehrere Aufrufer gleichzeitig dieselbe Ressource anfordern, teilen sie zunächst dieselbe Ressource. Nur wenn ein Aufrufer die Ressource ändern muss, erstellt das System eine Kopie der Ressource für diesen Aufrufer und lässt ihn dann diese Kopie ändern, ohne die ursprüngliche Ressource zu beeinflussen, die von anderen Aufrufern verwendet wird.

Im Szenario von Dev Drive bringt die COW-Technologie erhebliche Vorteile:

1.  **Effizientes Dateikopieren**: Beim Kopieren einer großen Datei führt ReFS nicht sofort eine tatsächliche Datenkopie durch, sondern erstellt einen neuen Dateieintrag, der auf dieselben Datenträgerblöcke verweist. Erst wenn die Quelldatei oder die Zieldatei geändert wird, werden tatsächlich die geänderten Datenblöcke kopiert. Dies macht Dateikopiervorgänge sehr schnell und belegt fast keinen zusätzlichen Speicherplatz (bis eine Änderung auftritt).
2.  **Speicherplatzersparnis**: Für Cache-Verzeichnisse mit vielen ähnlichen Dateien (z.B. Pakete derselben Version, von denen mehrere Projekte abhängen), kann COW effektiv unveränderte Datenblöcke gemeinsam nutzen, wodurch der gesamte Speicherbedarf reduziert wird.
3.  **Leistungssteigerung**: Reduziert unnötige Datenkopiervorgänge und verbessert die Effizienz von Dateioperationen.

### Dev Drive und ReFS-Funktionen

Windows 11 führte Dev Drive ein, ein speziell für Entwickler optimiertes Speichervolume. Dev Drive verwendet das Resilient File System (ReFS) als Dateisystem und aktiviert spezielle Optimierungsfunktionen.

**ReFS (Resilient File System)** ist ein von Microsoft entwickeltes Dateisystem der nächsten Generation, das im Vergleich zum herkömmlichen NTFS folgende Vorteile bietet:

- **Datenintegrität**: Erhöhte Zuverlässigkeit der Daten durch Prüfsummen und automatische Reparaturfunktionen.
- **Skalierbarkeit**: Unterstützung für größere Volumes und Dateigrößen.
- **Leistungsoptimierung**: Optimiert für Virtualisierungs- und Big-Data-Workloads.
- **Integrierte COW-Unterstützung**: Native Unterstützung für Copy-on-Write-Semantik, was für Dateioperationen in Entwicklungsszenarien besonders vorteilhaft ist.

**Dev Drive-Optimierung**: Aufbauend auf ReFS optimiert Dev Drive die Workloads von Entwicklern weiter, z.B. durch Leistungssteigerungen für Szenarien wie Paketmanager-Caches, Build-Ausgaben usw.

## Skriptfunktionen

Dieses Skript bietet die folgenden Hauptfunktionen:

- **Cache-Migration**: Unterstützung für die Migration von Cache-Verzeichnissen verschiedener Entwicklungstools auf das Dev Drive.
  - Node.js (npm, yarn, pnpm)
  - Python (pip)
  - .NET (NuGet)
  - Java (Maven, Gradle)
  - Go (Go modules)
  - Rust (Cargo)
  - VS Code-Erweiterungen
  - Windows TEMP/TMP-Verzeichnisse
    - JetBrains IDEs (IntelliJ, PyCharm usw.)
  - Android SDK
  - Chocolatey (Windows-Paketmanager)
  - Versteckte Benutzerordner (.xxx)
- **Dev Drive erstellen**: Bietet einen interaktiven Assistenten, der Benutzern hilft, neue Dev Drive-Partitionen zu erstellen.
- **Dev Drive löschen**: Sicher entfernen von Dev Drive-Partitionen mit der Option, migrierte Caches an ihre ursprünglichen Positionen wiederherzustellen.
- **Cache wiederherstellen**: Wiederherstellen von auf das Dev Drive migrierten Cache-Verzeichnissen an ihre ursprünglichen Positionen.
- **Link-Migration**: Migrieren von Cache-Verzeichnissen durch Erstellen symbolischer Links/Junction Points, ohne Umgebungsvariablen zu ändern.
- **Testmodus**: Bietet sichere Simulationsvorgänge zum Testen von Funktionen wie dem Löschen von Dev Drive, ohne das System tatsächlich zu ändern.

## Verwendungshinweise

1.  **Systemanforderungen**:
    - Windows 11 (Build 22000 oder höher)
    - PowerShell 7+ (pwsh)
2.  **Skript ausführen**:
    - Öffnen Sie PowerShell 7 (pwsh) als Administrator.
    - Navigieren Sie zum Verzeichnis des Skripts.
    - Führen Sie `.\Setup-DevDriveCache.ps1` aus.
3.  **Interaktive Bedienung**:
    - Nach dem Start des Skripts wird ein interaktives Menü angezeigt, das Sie durch die verschiedenen Vorgänge führt.
    - Wählen Sie die entsprechende Option, um Caches zu migrieren, ein Dev Drive zu erstellen oder zu löschen usw.
    - Alle wichtigen Vorgänge erfordern eine Bestätigung durch den Benutzer, um die Sicherheit zu gewährleisten.

## Wichtige Hinweise

- **Zweck**: Der Zweck dieses Skripts ist das Migrieren von Cache-Ordnern, nicht das Bereinigen derselben. Nach der Migration sind die ursprünglichen Cache-Daten weiterhin vorhanden, nur der Speicherort hat sich geändert.
- **Sicherung**: Es wird empfohlen, wichtige Daten zu sichern, bevor Sie wichtige Vorgänge (wie das Löschen eines Dev Drive) durchführen.
- **Umgebungsvariablen**: Das Skript liest oder schreibt keine Benutzerumgebungsvariablen; die Migration erfolgt über symbolische Links.

## Referenzmaterialien

- [Offizielle Microsoft Dev Drive-Dokumentation](https://learn.microsoft.com/en-us/windows/dev-drive/)
- [Offizielle Dokumentation zum Resilient File System (ReFS)](https://learn.microsoft.com/en-us/windows-server/storage/refs/refs-overview)

## Unterstützung

- [Nullprivate Werbefreiheit](https://www.nullprivate.com)