# Script de migration de cache pour Dev Drive

Autres langues:
| [English](README.en-us.md) | [简体中文](README.md) | [繁体中文](README.zh-tw.md) | [日本語](README.ja-jp.md) | [한국어](README.ko-kr.md) | [Français](README.fr-fr.md) | [Deutsch](README.de-de.md) | [Italiano](README.it-it.md) | [Español](README.es-es.md) | [Русский](README.ru-ru.md) | [Português (BR)](README.pt-br.md) | [Nederlands](README.nl-nl.md) | [Türkçe](README.tr-tr.md) | [العربية](README.ar-sa.md) | [हिंदी](README.hi-in.md) | [ไทย](README.th-th.md) |

## Introduction

Le [Script de migration de cache pour Dev Drive](https://github.com/jqknono/migrate-to-win11-dev-drive) est un outil PowerShell interactif conçu pour aider les développeurs à migrer les répertoires de cache de divers outils de développement vers le Dev Drive de Windows 11 (système de fichiers ReFS), afin d'améliorer les performances, de prolonger la durée de vie du disque dur et de réduire l'espace disque utilisé.

### Avantages clés

- **Prolongation de la durée de vie du disque dur**: En déplaçant les fichiers de cache fréquemment lus et écrits vers le Dev Drive, on réduit le nombre d'écritures sur le disque système (généralement un SSD), prolongeant ainsi sa durée de vie.
- **Réduction de l'espace disque utilisé**: Le déplacement des fichiers de cache volumineux (comme le cache `node_modules` de Node.js, le cache pip de Python, etc.) du disque système libère un espace précieux sur ce dernier.
- **Hautes performances**: En utilisant le système de fichiers ReFS et les fonctionnalités d'optimisation du Dev Drive, on peut améliorer la vitesse de lecture et d'écriture du cache, accélérant ainsi les constructions et la réactivité des outils de développement.

### Technologie Copy-on-Write (COW)

Le Dev Drive est basé sur le système de fichiers ReFS et utilise la technologie Copy-on-Write (COW). COW est une technique de gestion des ressources dont le principe fondamental est le suivant : lorsque plusieurs appelants demandent simultanément la même ressource, ils partagent initialement la même ressource. Ce n'est que lorsqu'un appelant a besoin de modifier la ressource que le système crée une copie de celle-ci pour cet appelant, lui permettant de modifier cette copie sans affecter la ressource originale utilisée par les autres appelants.

Dans le contexte du Dev Drive, la technologie COW apporte des avantages significatifs :

1.  **Copie de fichiers efficace**: Lorsqu'il est nécessaire de copier un gros fichier, ReFS n'effectue pas immédiatement une copie réelle des données, mais crée plutôt une nouvelle entrée de fichier pointant vers les mêmes blocs de disque. Ce n'est que lorsque le fichier source ou de destination est modifié que les blocs de données modifiés sont réellement copiés. Cela rend les opérations de copie de fichiers très rapides et n'utilise presque pas d'espace disque supplémentaire (jusqu'à ce qu'une modification se produise).
2.  **Économie d'espace disque**: Pour les répertoires de cache contenant de nombreux fichiers similaires (par exemple, des packages de même version dont dépendent plusieurs projets), COW peut partager efficacement les blocs de données non modifiés, réduisant ainsi l'occupation globale du disque.
3.  **Amélioration des performances**: La réduction des opérations de copie de données inutiles améliore l'efficacité des opérations sur les fichiers.

### Dev Drive et fonctionnalités ReFS

Windows 11 a introduit le Dev Drive, un volume de stockage spécialement optimisé pour les développeurs. Le Dev Drive utilise le Resilient File System (ReFS) comme système de fichiers et active des fonctionnalités d'optimisation dédiées.

**ReFS (Resilient File System)** est un système de fichiers de nouvelle génération développé par Microsoft, qui présente les avantages suivants par rapport au NTFS traditionnel :

- **Intégrité des données**: Améliore la fiabilité des données grâce à des fonctionnalités de checksum et de réparation automatique.
- **Évolutivité**: Prend en charge des volumes et des tailles de fichiers plus importants.
- **Optimisation des performances**: Optimisé pour les charges de travail de virtualisation et de big data.
- **Intégration COW**: Prise en charge native de la sémantique Copy-on-Write, ce qui est particulièrement avantageux pour les opérations sur les fichiers dans les scénarios de développement.

**Optimisations Dev Drive**: Sur la base de ReFS, le Dev Drive est en outre optimisé pour les charges de travail des développeurs, par exemple en améliorant les performances pour les scénarios tels que le cache des gestionnaires de packages, les sorties de construction, etc.

## Fonctionnalités du script

Ce script offre les fonctionnalités principales suivantes :

- **Migration du cache**: Prend en charge la migration des répertoires de cache de divers outils de développement vers le Dev Drive.
  - Node.js (npm, yarn, pnpm)
  - Python (pip)
  - .NET (NuGet)
  - Java (Maven, Gradle)
  - Go (Go modules)
  - Rust (Cargo)
  - VS Code extensions
  - Windows TEMP/TMP directories
    - JetBrains IDE (IntelliJ, PyCharm, etc.)
  - Android SDK
  - Chocolatey (gestionnaire de packages Windows)
  - Dossiers cachés utilisateur (.xxx)
- **Création de Dev Drive**: Fournit un assistant interactif pour aider les utilisateurs à créer de nouvelles partitions Dev Drive.
- **Suppression de Dev Drive**: Supprime en toute sécurité les partitions Dev Drive, avec une option pour restaurer les caches migrés vers leurs emplacements d'origine.
- **Restauration du cache**: Restaure les répertoires de cache qui ont été migrés vers le Dev Drive vers leurs emplacements d'origine.
- **Migration par liens**: Migre les répertoires de cache en créant des liens symboliques/jonctions, sans modifier aucune variable d'environnement.
- **Mode test**: Fournit des opérations de simulation sécurisées pour tester des fonctionnalités comme la suppression de Dev Drive sans modifier réellement le système.

## Instructions d'utilisation

1.  **Configuration système requise**:
    - Windows 11 (Build 22000 ou supérieur)
    - PowerShell 7+ (pwsh)
2.  **Exécution du script**:
    - Ouvrez PowerShell 7 (pwsh) en tant qu'administrateur.
    - Naviguez vers le répertoire où se trouve le script.
    - Exécutez `.\Setup-DevDriveCache.ps1`.
3.  **Opération interactive**:
    - Une fois le script démarré, un menu interactif s'affiche pour vous guider à travers diverses opérations.
    - Sélectionnez l'option appropriée pour migrer le cache, créer ou supprimer un Dev Drive, etc.
    - Toutes les opérations critiques nécessitent une confirmation de l'utilisateur pour garantir la sécurité.

## Remarques

- **Objectif**: L'objectif de ce script est de migrer les dossiers de cache, pas de les nettoyer. Après la migration, les données de cache d'origine existent toujours, seul leur emplacement de stockage a changé.
- **Sauvegarde**: Avant d'effectuer des opérations majeures (comme la suppression d'un Dev Drive), il est recommandé de sauvegarder les données importantes.
- **Variables d'environnement**: Le script ne lit ni n'écrit les variables d'environnement utilisateur ; la migration est effectuée via des liens symboliques.

## Références

- [Documentation officielle Microsoft Dev Drive](https://learn.microsoft.com/en-us/windows/dev-drive/)
- [Documentation officielle Resilient File System (ReFS)](https://learn.microsoft.com/en-us/windows-server/storage/refs/refs-overview)

## Support

- [NullPrivate Ad Blocker](https://www.nullprivate.com)