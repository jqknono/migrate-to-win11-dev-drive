# Script di migrazione della cache di Dev Drive

Altre lingue:
| [English](README.en-us.md) | [简体中文](README.md) | [繁体中文](README.zh-tw.md) | [日本語](README.ja-jp.md) | [한국어](README.ko-kr.md) | [Français](README.fr-fr.md) | [Deutsch](README.de-de.md) | [Italiano](README.it-it.md) | [Español](README.es-es.md) | [Русский](README.ru-ru.md) | [Português (BR)](README.pt-br.md) | [Nederlands](README.nl-nl.md) | [Türkçe](README.tr-tr.md) | [العربية](README.ar-sa.md) | [हिंदी](README.hi-in.md) | [ไทย](README.th-th.md) |

## Introduzione

[Script di migrazione della cache di Dev Drive](https://github.com/jqknono/migrate-to-win11-dev-drive) è uno strumento PowerShell interattivo progettato per aiutare gli sviluppatori a migrare le directory della cache di vari strumenti di sviluppo su Dev Drive di Windows 11 (file system ReFS) per migliorare le prestazioni, prolungare la durata del disco e ridurre l'occupazione dello spazio su disco.

### Vantaggi principali

- **Prolungamento della durata del disco**: Spostando i file della cache frequentemente letti e scritti su Dev Drive, si riduce il numero di scritte sul disco di sistema (solitamente un SSD), prolungandone così la durata.
- **Riduzione dell'occupazione dello spazio su disco**: Spostando i grandi file della cache (come la cache `node_modules` di Node.js, la cache pip di Python, ecc.) dal disco di sistema, si può liberare significativamente prezioso spazio sul disco di sistema.
- **Alte prestazioni**: Sfruttando il file system ReFS e le funzionalità di ottimizzazione di Dev Drive, è possibile migliorare la velocità di lettura e scrittura della cache, accelerando le operazioni di compilazione e la reattività degli strumenti di sviluppo.

### Tecnologia Copy-on-Write (COW)

Dev Drive si basa sul file system ReFS e sfrutta la tecnologia Copy-on-Write (COW). COW è una tecnica di gestione delle risorse il cui principio fondamentale è: quando più richiedenti accedono simultaneamente alla stessa risorsa, inizialmente condividono la stessa risorsa. Solo quando uno dei richiedenti deve modificare la risorsa, il sistema crea una copia della risorsa per quel richiedente, permettendogli di modificare la copia senza influenzare la risorsa originale utilizzata dagli altri richiedenti.

Nello scenario di Dev Drive, la tecnologia COW offre vantaggi significativi:

1.  **Copia efficiente dei file**: Quando è necessario copiare un file di grandi dimensioni, ReFS non esegue immediatamente la copia effettiva dei dati, ma crea una nuova voce di file che punta agli stessi blocchi su disco. Solo quando il file di origine o di destinazione viene modificato, i blocchi di dati modificati vengono effettivamente copiati. Ciò rende le operazioni di copia dei file molto veloci e quasi senza occupare spazio su disco aggiuntivo (fino a quando non avviene una modifica).
2.  **Risparmio di spazio su disco**: Per le directory della cache che contengono molti file simili (ad esempio, pacchetti della stessa versione dipendenti da più progetti), COW può condividere efficacemente i blocchi di dati non modificati, riducendo così l'occupazione complessiva del disco.
3.  **Miglioramento delle prestazioni**: Riducendo le operazioni di copia dei dati non necessarie, si migliora l'efficienza delle operazioni sui file.

### Caratteristiche di Dev Drive e ReFS

Windows 11 ha introdotto Dev Drive, un volume di archiviazione ottimizzato specificamente per gli sviluppatori. Dev Drive utilizza Resilient File System (ReFS) come file system e abilita funzionalità di ottimizzazione dedicate.

**ReFS (Resilient File System)** è una nuova generazione di file system sviluppato da Microsoft, che rispetto al tradizionale NTFS offre i seguenti vantaggi:

- **Integrità dei dati**: Migliora l'affidabilità dei dati attraverso funzionalità di checksum e riparazione automatica.
- **Scalabilità**: Supporta volumi e dimensioni dei file più grandi.
- **Ottimizzazione delle prestazioni**: Ottimizzato per carichi di lavoro di virtualizzazione e big data.
- **Integrazione COW**: Supporto nativo della semantica Copy-on-Write, particolarmente vantaggiosa per le operazioni sui file negli scenari di sviluppo.

**Ottimizzazioni Dev Drive**: Sulla base di ReFS, Dev Drive ottimizza ulteriormente i carichi di lavoro degli sviluppatori, ad esempio migliorando le prestazioni in scenari come la cache dei gestori di pacchetti, gli output di compilazione, ecc.

## Funzionalità dello script

Questo script fornisce le seguenti funzionalità principali:

- **Migrazione della cache**: Supporta la migrazione delle directory della cache di vari strumenti di sviluppo su Dev Drive.
  - Node.js (npm, yarn, pnpm)
  - Python (pip)
  - .NET (NuGet)
  - Java (Maven, Gradle)
  - Go (Go modules)
  - Rust (Cargo)
  - Estensioni VS Code
  - Directory TEMP/TMP di Windows
    - JetBrains IDE (IntelliJ, PyCharm, ecc.)
  - Android SDK
  - Chocolatey (gestore di pacchetti Windows)
  - Cartelle nascoste utente (.xxx)
- **Creazione di Dev Drive**: Fornisce una procedura guidata interattiva per aiutare gli utenti a creare nuove partizioni Dev Drive.
- **Rimozione di Dev Drive**: Rimuove in modo sicuro le partizioni Dev Drive, fornendo l'opzione di ripristinare le cache migrate nelle loro posizioni originali.
- **Ripristino della cache**: Ripristina le directory della cache migrate su Dev Drive nelle loro posizioni originali.
- **Migrazione tramite collegamenti**: Migra le directory della cache creando collegamenti simbolici/junction point, senza modificare alcuna variabile d'ambiente.
- **Modalità di test**: Fornisce operazioni di simulazione sicure per testare funzionalità come la rimozione di Dev Drive senza modificare effettivamente il sistema.

## Istruzioni per l'uso

1.  **Requisiti di sistema**:
    - Windows 11 (Build 22000 o successivo)
    - PowerShell 7+ (pwsh)
2.  **Esecuzione dello script**:
    - Aprire PowerShell 7 (pwsh) come amministratore.
    - Navigare fino alla directory in cui si trova lo script.
    - Eseguire `.\Setup-DevDriveCache.ps1`.
3.  **Operazioni interattive**:
    - Dopo l'avvio, lo script visualizzerà un menu interattivo che guiderà attraverso varie operazioni.
    - Selezionare l'opzione appropriata per migrare la cache, creare o rimuovere Dev Drive, ecc.
    - Tutte le operazioni critiche richiedono la conferma dell'utente per garantire la sicurezza.

## Note importanti

- **Scopo**: Lo scopo di questo script è migrare le cartelle della cache, non pulirle. Dopo la migrazione, i dati originali della cache continuano a esistere, ma la loro posizione di archiviazione è cambiata.
- **Backup**: Prima di eseguire operazioni importanti (come la rimozione di Dev Drive), si consiglia di eseguire il backup dei dati importanti.
- **Variabili d'ambiente**: Lo script non legge né scrive le variabili d'ambiente utente; la migrazione viene completata tramite collegamenti simbolici.

## Riferimenti

- [Documentazione ufficiale di Microsoft Dev Drive](https://learn.microsoft.com/en-us/windows/dev-drive/)
- [Documentazione ufficiale di Resilient File System (ReFS)](https://learn.microsoft.com/en-us/windows-server/storage/refs/refs-overview)

## Supporto

- [Nullprivate Rimuovi Pubblicità](https://www.nullprivate.com)