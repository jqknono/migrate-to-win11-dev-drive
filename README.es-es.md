# Script de Migración de Caché de Dev Drive

Otros idiomas:
| [English](README.en-us.md) | [简体中文](README.md) | [繁体中文](README.zh-tw.md) | [日本語](README.ja-jp.md) | [한국어](README.ko-kr.md) | [Français](README.fr-fr.md) | [Deutsch](README.de-de.md) | [Italiano](README.it-it.md) | [Español](README.es-es.md) | [Русский](README.ru-ru.md) | [Português (BR)](README.pt-br.md) | [Nederlands](README.nl-nl.md) | [Türkçe](README.tr-tr.md) | [العربية](README.ar-sa.md) | [हिंदी](README.hi-in.md) | [ไทย](README.th-th.md) |

## Introducción

El [Script de Migración de Caché de Dev Drive](https://github.com/jqknono/migrate-to-win11-dev-drive) es una herramienta interactiva de PowerShell diseñada para ayudar a los desarrolladores a migrar los directorios de caché de varias herramientas de desarrollo al Dev Drive de Windows 11 (sistema de archivos ReFS) para mejorar el rendimiento, prolongar la vida útil del disco y reducir el espacio en disco utilizado.

### Ventajas Principales

- **Prolongar la vida útil del disco**: Al mover los archivos de caché de lectura/escritura frecuente al Dev Drive, se reduce el número de escrituras en el disco del sistema (generalmente SSD), extendiendo así su vida útil.
- **Reducir el espacio en disco**: Mover los archivos de caché grandes (como la caché `node_modules` de Node.js, la caché pip de Python, etc.) fuera del disco del sistema puede liberar significativamente valioso espacio en el disco del sistema.
- **Alto rendimiento**: Aprovechando el sistema de archivos ReFS y las características de optimización del Dev Drive, se puede mejorar la velocidad de lectura/escritura de la caché, acelerando la construcción y la respuesta de las herramientas de desarrollo.

### Tecnología Copy-on-Write (COW)

Dev Drive se basa en el sistema de archivos ReFS y utiliza la tecnología Copy-on-Write (COW). COW es una técnica de gestión de recursos cuya idea principal es: cuando múltiples solicitantes solicitan el mismo recurso simultáneamente, inicialmente comparten la misma copia del recurso. Solo cuando un solicitante necesita modificar el recurso, el sistema crea una copia del recurso para ese solicitante, luego le permite modificar esta copia, sin afectar al recurso original utilizado por otros solicitantes.

En el escenario de Dev Drive, la tecnología COW ofrece ventajas significativas:

1.  **Copia eficiente de archivos**: Cuando se necesita copiar un archivo grande, ReFS no realiza inmediatamente la copia real de datos, sino que crea una nueva entrada de archivo que apunta a los mismos bloques de disco. Solo cuando el archivo fuente o destino se modifica, se copian realmente los bloques de datos modificados. Esto hace que la operación de copia de archivos sea muy rápida y casi no ocupa espacio adicional en disco (hasta que se produce una modificación).
2.  **Ahorro de espacio en disco**: Para directorios de caché que contienen muchos archivos similares (por ejemplo, paquetes de la misma versión de los que dependen múltiples proyectos), COW puede compartir eficazmente bloques de datos no modificados, reduciendo así el uso general de disco.
3.  **Mejora del rendimiento**: Reduce las operaciones innecesarias de copia de datos, mejorando la eficiencia de las operaciones de archivo.

### Dev Drive y características de ReFS

Windows 11 introdujo Dev Drive, un volumen de almacenamiento optimizado específicamente para desarrolladores. Dev Drive utiliza Resilient File System (ReFS) como su sistema de archivos y habilita funciones de optimización especializadas.

**ReFS (Resilient File System)** es un sistema de archivos de nueva generación desarrollado por Microsoft, que tiene las siguientes ventajas en comparación con el NTFS tradicional:

- **Integridad de datos**: Mejora la fiabilidad de los datos mediante sumas de comprobación y funciones de reparación automática.
- **Escalabilidad**: Admite volúmenes y tamaños de archivo más grandes.
- **Optimización del rendimiento**: Optimizado para cargas de trabajo de virtualización y big data.
- **Integración de COW**: Admite nativamente la semántica Copy-on-Write, lo que es particularmente beneficioso para las operaciones de archivo en escenarios de desarrollo.

**Optimización de Dev Drive**: Sobre la base de ReFS, Dev Drive se optimiza aún más para las cargas de trabajo de los desarrolladores, como mejoras de rendimiento para escenarios como la caché del administrador de paquetes, la salida de compilación, etc.

## Funciones del Script

Este script proporciona las siguientes funciones principales:

- **Migrar caché**: Admite la migración de directorios de caché de varias herramientas de desarrollo al Dev Drive.
  - Node.js (npm, yarn, pnpm)
  - Python (pip)
  - .NET (NuGet)
  - Java (Maven, Gradle)
  - Go (módulos Go)
  - Rust (Cargo)
  - Extensiones de VS Code
  - Directorios TEMP/TMP de Windows
    - JetBrains IDE (IntelliJ, PyCharm, etc.)
  - Android SDK
  - Chocolatey (gestor de paquetes de Windows)
  - Carpetas ocultas de usuario (.xxx)
- **Restaurar caché**: Restaura los directorios de caché migrados al Dev Drive a su ubicación original.
- **Migración por enlace**: Migra los directorios de caché creando enlaces simbólicos/puntos de unión, sin modificar ninguna variable de entorno.
- **Modo de prueba**: Proporciona operaciones de simulación seguras para probar funciones como la eliminación de Dev Drive sin modificar realmente el sistema.

## Instrucciones de Uso

1.  **Requisitos del sistema**:
    - Windows 11 (Build 22000 o superior)
    - PowerShell 7+ (pwsh)
2.  **Ejecutar el script**:
    - Abra PowerShell 7 (pwsh) como administrador.
    - Navegue hasta el directorio donde se encuentra el script.
    - Ejecute `.\Setup-DevDriveCache.ps1`.
3.  **Operación interactiva**:
    - Después de iniciar el script, se mostrará un menú interactivo que lo guiará a través de varias operaciones.
    - Seleccione la opción correspondiente para migrar la caché, crear o eliminar Dev Drive, etc.
    - Todas las operaciones críticas requieren confirmación del usuario para garantizar la seguridad.

## Consideraciones

- **Propósito**: El propósito de este script es migrar carpetas de caché, no limpiarlas. Después de la migración, los datos de caché originales todavía existen, solo ha cambiado su ubicación de almacenamiento.
- **Copia de seguridad**: Antes de realizar operaciones importantes (como eliminar Dev Drive), se recomienda hacer una copia de seguridad de los datos importantes.
- **Variables de entorno**: El script no lee ni escribe variables de entorno del usuario; la migración se realiza mediante enlaces simbólicos.

## Referencias

- [Documentación oficial de Microsoft Dev Drive](https://learn.microsoft.com/en-us/windows/dev-drive/)
- [Documentación oficial de Resilient File System (ReFS)](https://learn.microsoft.com/en-us/windows-server/storage/refs/refs-overview)

## Soporte

- [Nullprivate Eliminar Anuncios](https://www.nullprivate.com)