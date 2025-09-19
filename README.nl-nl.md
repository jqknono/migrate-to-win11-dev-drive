# Dev Drive Cachemigratiescript

其它语言:
| [English](README.en-us.md) | [简体中文](README.md) | [繁体中文](README.zh-tw.md) | [日本語](README.ja-jp.md) | [한국어](README.ko-kr.md) | [Français](README.fr-fr.md) | [Deutsch](README.de-de.md) | [Italiano](README.it-it.md) | [Español](README.es-es.md) | [Русский](README.ru-ru.md) | [Português (BR)](README.pt-br.md) | [Nederlands](README.nl-nl.md) | [Türkçe](README.tr-tr.md) | [العربية](README.ar-sa.md) | [हिंदी](README.hi-in.md) | [ไทย](README.th-th.md) |

## Inleiding

[Dev Drive Cachemigratiescript](https://github.com/jqknono/migrate-to-win11-dev-drive) is een interactieve PowerShell-tool die is ontworpen om ontwikkelaars te helpen de cachemappen van verschillende ontwikkelingstools te migreren naar de Dev Drive van Windows 11 (ReFS-bestandssysteem), om de prestaties te verbeteren, de levensduur van de harde schijf te verlengen en de schijfruimte te verminderen.

### Kernvoordelen

- **Langere levensduur van harde schijf**: Door cachebestanden die vaak worden gelezen en geschreven naar Dev Drive te verplaatsen, kan het aantal schrijfbewerkingen naar de systeemschijf (meestal een SSD) worden verminderd, waardoor de levensduur ervan wordt verlengd.
- **Minder schijfruimtegebruik**: Door grote cachebestanden (zoals de `node_modules`-cache van Node.js, de pip-cache van Python, etc.) van de systeemschijf te verplaatsen, kan waardevolle systeemschijfruimte aanzienlijk worden vrijgemaakt.
- **Hoge prestaties**: Door gebruik te maken van het ReFS-bestandssysteem en de optimalisatiefuncties van Dev Drive, kunnen de lees- en schrijfsnelheden van de cache worden verbeterd, waardoor de bouwsnelheid en de reactietijd van ontwikkelingstools worden versneld.

### Copy-on-Write (COW) Technologie

Dev Drive is gebaseerd op het ReFS-bestandssysteem en maakt gebruik van Copy-on-Write (COW) technologie. COW is een resourcemanagementtechniek waarvan het kernidee is: wanneer meerdere aanroepers tegelijkertijd om dezelfde bron vragen, delen ze aanvankelijk dezelfde bron. Alleen wanneer een aanroeper de bron moet wijzigen, maakt het systeem een kopie van de bron voor die aanroeper, waarna deze de kopie kan wijzigen zonder de oorspronkelijke bron die door andere aanroepers wordt gebruikt, te beïnvloeden.

In het scenario van Dev Drive brengt COW-technologie aanzienlijke voordelen met zich mee:

1.  **Efficiënt bestanden kopiëren**: Wanneer een groot bestand moet worden gekopieerd, voert ReFS niet onmiddellijk een daadwerkelijke gegevenskopie uit, maar creëert het een nieuwe bestandsingang die naar dezelfde schijfblokken verwijst. Alleen wanneer het bronbestand of het doelbestand wordt gewijzigd, worden de gewijzigde datablokken daadwerkelijk gekopieerd. Dit maakt bestandskopieerbewerkingen zeer snel en gebruikt bijna geen extra schijfruimte (totdat er wijzigingen optreden).
2.  **Schijfruimte besparen**: Voor cachemappen die veel vergelijkbare bestanden bevatten (bijvoorbeeld pakketten van dezelfde versie waarop meerdere projecten afhankelijk zijn), kan COW ongewijzigde datablokken effectief delen, waardoor het totale schijfgebruik wordt verminderd.
3.  **Prestaties verbeteren**: Door onnodige gegevenskopieerbewerkingen te verminderen, wordt de efficiëntie van bestandsbewerkingen verhoogd.

### Dev Drive en ReFS-functies

Windows 11 introduceerde Dev Drive, een opslagvolume dat speciaal is geoptimaliseerd voor ontwikkelaars. Dev Drive gebruikt het Resilient File System (ReFS) als bestandssysteem en heeft gespecialiseerde optimalisatiefuncties ingeschakeld.

**ReFS (Resilient File System)** is een nieuw generatie bestandssysteem ontwikkeld door Microsoft, dat in vergelijking met het traditionele NTFS de volgende voordelen biedt:

- **Gegevensintegriteit**: Verbetert de betrouwbaarheid van gegevens door middel van checksums en automatische reparatiefuncties.
- **Schaalbaarheid**: Ondersteunt grotere volumes en bestandsgroottes.
- **Prestatieoptimalisatie**: Geoptimaliseerd voor virtualisatie en big data workloads.
- **Geïntegreerde COW**: Ondersteunt Copy-on-Write semantiek natively, wat vooral gunstig is voor bestandsbewerkingen in ontwikkelingsscenario's.

**Dev Drive optimalisatie**: Op basis van ReFS is Dev Drive verder geoptimaliseerd voor ontwikkelaarsworkloads, zoals prestatieverbeteringen voor scenario's zoals pakketbeheercaches, build-outputs, etc.

## Scriptfuncties

Dit script biedt de volgende belangrijkste functies:

- **Cache migreren**: Ondersteunt het migreren van cachemappen van verschillende ontwikkelingstools naar Dev Drive.
  - Node.js (npm, yarn, pnpm)
  - Python (pip)
  - .NET (NuGet)
  - Java (Maven, Gradle)
  - Go (Go modules)
  - Rust (Cargo)
  - VS Code-extensies
  - Windows TEMP/TMP-mappen
    - JetBrains IDE (IntelliJ, PyCharm, etc.)
  - Android SDK
  - Chocolatey (Windows pakketbeheerder)
  - Verborgen gebruikersmappen (.xxx)
- **Dev Drive maken**: Biedt een interactieve wizard om gebruikers te helpen een nieuwe Dev Drive-partitie te maken.
- **Dev Drive verwijderen**: Verwijdert een Dev Drive-partitie veilig en biedt de optie om gemigreerde caches terug te zetten naar hun oorspronkelijke locaties.
- **Cache herstellen**: Zet cachemappen die naar Dev Drive zijn gemigreerd terug naar hun oorspronkelijke locaties.
- **Linkmigratie**: Migreert cachemappen door symbolische koppelingen/koppelpunten te maken, zonder enige omgevingsvariabelen te wijzigen.
- **Testmodus**: Biedt veilige simulatiebewerkingen om functies zoals Dev Drive-verwijdering te testen zonder het systeem daadwerkelijk te wijzigen.

## Gebruiksinstructies

1.  **Systeemvereisten:**
    - Windows 11 (Build 22000 of hoger)
    - PowerShell 7+ (pwsh)
2.  **Script uitvoeren:**
    - Open PowerShell 7 (pwsh) als beheerder.
    - Navigeer naar de map waar het script zich bevindt.
    - Voer `.\Setup-DevDriveCache.ps1` uit.
3.  **Interactieve bediening:**
    - Nadat het script is gestart, wordt een interactief menu weergegeven dat u door verschillende bewerkingen begeleidt.
    - Kies de corresponderende opties om caches te migreren, Dev Drive te maken of te verwijderen, etc.
    - Alle cruciale bewerkingen vereisen gebruikersbevestiging om de veiligheid te waarborgen.

## Opmerkingen

- **Doel**: Het doel van dit script is het migreren van cachemappen, niet het opschonen ervan. Na migratie bestaan de oorspronkelijke cachegegevens nog steeds, alleen de opslaglocatie is gewijzigd.
- **Back-up**: Voordat u belangrijke bewerkingen uitvoert (zoals het verwijderen van Dev Drive), wordt aanbevolen om belangrijke gegevens te back-uppen.
- **Omgevingsvariabelen**: Het script leest of schrijft geen gebruikersomgevingsvariabelen; migratie wordt uitgevoerd via symbolische koppelingen.

## Referentiemateriaal

- [Officiële Microsoft Dev Drive-documentatie](https://learn.microsoft.com/en-us/windows/dev-drive/)
- [Officiële Resilient File System (ReFS)-documentatie](https://learn.microsoft.com/en-us/windows-server/storage/refs/refs-overview)

## Ondersteuning

- [NullPrivate Advertentieblokkering](https://www.nullprivate.com)