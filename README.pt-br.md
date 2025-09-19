# Script de Migração de Cache para Dev Drive

Outros idiomas:
| [English](README.en-us.md) | [简体中文](README.md) | [繁体中文](README.zh-tw.md) | [日本語](README.ja-jp.md) | [한국어](README.ko-kr.md) | [Français](README.fr-fr.md) | [Deutsch](README.de-de.md) | [Italiano](README.it-it.md) | [Español](README.es-es.md) | [Русский](README.ru-ru.md) | [Português (BR)](README.pt-br.md) | [Nederlands](README.nl-nl.md) | [Türkçe](README.tr-tr.md) | [العربية](README.ar-sa.md) | [हिंदी](README.hi-in.md) | [ไทย](README.th-th.md) |

## Introdução

O [Script de Migração de Cache para Dev Drive](https://github.com/jqknono/migrate-to-win11-dev-drive) é uma ferramenta interativa do PowerShell projetada para ajudar desenvolvedores a migrar diretórios de cache de várias ferramentas de desenvolvimento para o Dev Drive do Windows 11 (sistema de arquivos ReFS), melhorando o desempenho, prolongando a vida útil do disco e reduzindo o uso de espaço em disco.

### Vantagens Principais

- **Prolongar a vida útil do disco**: Ao mover arquivos de cache com leitura e escrita frequente para o Dev Drive, é possível reduzir o número de gravações no disco do sistema (geralmente um SSD), prolongando assim sua vida útil.
- **Reduzir o uso de espaço em disco**: Mover arquivos de cache volumosos (como o cache `node_modules` do Node.js, o cache pip do Python, etc.) para fora do disco do sistema pode liberar significativamente espaço valioso no disco do sistema.
- **Alto desempenho**: Utilizando o sistema de arquivos ReFS e os recursos de otimização do Dev Drive, é possível melhorar a velocidade de leitura e escrita do cache, acelerando a construção e a resposta das ferramentas de desenvolvimento.

### Tecnologia Copy-on-Write (COW)

O Dev Drive é baseado no sistema de arquivos ReFS e utiliza a tecnologia Copy-on-Write (COW). COW é uma técnica de gerenciamento de recursos cuja ideia principal é: quando vários chamadores solicitam o mesmo recurso simultaneamente, eles inicialmente compartilham o mesmo recurso. Somente quando um chamador precisa modificar o recurso, o sistema cria uma cópia do recurso para esse chamador, permitindo que ele modifique essa cópia, sem afetar o recurso original usado por outros chamadores.

No cenário do Dev Drive, a tecnologia COW traz vantagens significativas:

1.  **Cópia eficiente de arquivos**: Ao precisar copiar um arquivo grande, o ReFS não realiza imediatamente a cópia real dos dados, mas cria uma nova entrada de arquivo apontando para os mesmos blocos de disco. Somente quando o arquivo de origem ou o arquivo de destino é modificado, os blocos de dados modificados são realmente copiados. Isso torna as operações de cópia de arquivo muito rápidas e quase não consome espaço adicional em disco (até que ocorra uma modificação).
2.  **Economia de espaço em disco**: Para diretórios de cache que contêm muitos arquivos semelhantes (por exemplo, pacotes da mesma versão dos quais vários projetos dependem), o COW pode compartilhar efetivamente blocos de dados não modificados, reduzindo assim o consumo geral de disco.
3.  **Melhoria de desempenho**: Reduz operações desnecessárias de cópia de dados, aumentando a eficiência das operações de arquivo.

### Dev Drive e Recursos do ReFS

O Windows 11 introduziu o Dev Drive, um volume de armazenamento otimizado especificamente para desenvolvedores. O Dev Drive usa o Resilient File System (ReFS) como seu sistema de arquivos e habilita recursos de otimização dedicados.

**ReFS (Resilient File System)** é um sistema de arquivos de nova geração desenvolvido pela Microsoft, que possui as seguintes vantagens em comparação com o NTFS tradicional:

- **Integridade dos dados**: Melhora a confiabilidade dos dados através de somas de verificação e funções de reparo automático.
- **Escalabilidade**: Suporta volumes e tamanhos de arquivo maiores.
- **Otimização de desempenho**: Otimizado para cargas de trabalho de virtualização e big data.
- **Integração COW**: Suporte nativo para semântica Copy-on-Write, o que é particularmente benéfico para operações de arquivo em cenários de desenvolvimento.

**Otimizações do Dev Drive**: Com base no ReFS, o Dev Drive é ainda mais otimizado para cargas de trabalho de desenvolvedores, como melhorias de desempenho para cenários como cache de gerenciadores de pacotes, saídas de construção, etc.

## Funcionalidades do Script

Este script oferece as seguintes funcionalidades principais:

- **Migrar cache**: Suporta a migração de diretórios de cache de várias ferramentas de desenvolvimento para o Dev Drive.
  - Node.js (npm, yarn, pnpm)
  - Python (pip)
  - .NET (NuGet)
  - Java (Maven, Gradle)
  - Go (módulos Go)
  - Rust (Cargo)
  - Extensões do VS Code
  - Diretórios TEMP/TMP do Windows
    - JetBrains IDE (IntelliJ, PyCharm, etc.)
  - Android SDK
  - Chocolatey (gerenciador de pacotes do Windows)
  - Pastas ocultas do usuário (.xxx)
- **Criar Dev Drive**: Fornece um assistente interativo para ajudar os usuários a criar novas partições Dev Drive.
- **Excluir Dev Drive**: Remove partições Dev Drive com segurança e oferece a opção de restaurar caches migrados para seus locais originais.
- **Restaurar cache**: Restaura diretórios de cache migrados para o Dev Drive para seus locais originais.
- **Migração por link**: Migra diretórios de cache através da criação de links simbólicos/junções, sem modificar nenhuma variável de ambiente.
- **Modo de teste**: Fornece operações simuladas seguras para testar funcionalidades como exclusão do Dev Drive, sem realmente modificar o sistema.

## Instruções de Uso

1.  **Requisitos do sistema**:
    - Windows 11 (Build 22000 ou superior)
    - PowerShell 7+ (pwsh)
2.  **Executar o script**:
    - Abra o PowerShell 7 (pwsh) como administrador.
    - Navegue até o diretório onde o script está localizado.
    - Execute `.\Setup-DevDriveCache.ps1`.
3.  **Operação interativa**:
    - Após a inicialização, o script exibirá um menu interativo para guiá-lo através de várias operações.
    - Selecione a opção correspondente para migrar cache, criar ou excluir Dev Drive, etc.
    - Todas as operações críticas requerem confirmação do usuário para garantir segurança.

## Observações

- **Objetivo**: O objetivo deste script é migrar pastas de cache, não limpá-las. Após a migração, os dados de cache originais ainda existem, apenas o local de armazenamento foi alterado.
- **Backup**: Antes de realizar operações importantes (como excluir o Dev Drive), recomenda-se fazer backup de dados importantes.
- **Variáveis de ambiente**: O script não lê nem escreve variáveis de ambiente do usuário; a migração é feita através de links simbólicos.

## Referências

- [Documentação oficial do Microsoft Dev Drive](https://learn.microsoft.com/en-us/windows/dev-drive/)
- [Documentação oficial do Resilient File System (ReFS)](https://learn.microsoft.com/en-us/windows-server/storage/refs/refs-overview)

## Suporte

- [Nullprivate Remover Anúncios](https://www.nullprivate.com)