# Dev Drive Önbellek Taşıma Betiği

Diğer diller:
| [English](README.en-us.md) | [Basitleştirilmiş Çince](README.md) | [Geleneksel Çince](README.zh-tw.md) | [Japonca](README.ja-jp.md) | [Korece](README.ko-kr.md) | [Fransızca](README.fr-fr.md) | [Almanca](README.de-de.md) | [İtalyanca](README.it-it.md) | [İspanyolca](README.es-es.md) | [Rusça](README.ru-ru.md) | [Portekizce (BR)](README.pt-br.md) | [Felemenkçe](README.nl-nl.md) | [Türkçe](README.tr-tr.md) | [Arapça](README.ar-sa.md) | [Hintçe](README.hi-in.md) | [Tayca](README.th-th.md) |

## Giriş

[Dev Drive Önbellek Taşıma Betiği](https://github.com/jqknono/migrate-to-win11-dev-drive), geliştiricilerin çeşitli geliştirme araçlarının önbellek dizinlerini Windows 11'in Dev Drive'ına (ReFS dosya sistemi) taşımalarına yardımcı olmak için tasarlanmış etkileşimli bir PowerShell aracıdır. Bu, performansı artırmak, disk ömrünü uzatmak ve disk alanı kullanımını azaltmak için yapılır.

### Temel Avantajlar

- **Disk Ömrünü Uzatma**: Sık okunan ve yazılan önbellek dosyalarını Dev Drive'a taşıyarak, sistem diskinin (genellikle SSD) yazma sayısını azaltabilir ve böylece kullanım ömrünü uzatabilirsiniz.
- **Disk Alanı Kullanımını Azaltma**: Node.js'nin `node_modules` önbelleği, Python'un pip önbelleği gibi büyük önbellek dosyalarını sistem diskinden çıkararak değerli sistem disk alanını önemli ölçüde serbest bırakabilirsiniz.
- **Yüksek Performans**: Dev Drive'ın ReFS dosya sistemini ve optimizasyon özelliklerini kullanarak önbelleğin okuma/yazma hızını artırabilir ve yapı oluşturma ve geliştirme araçlarının yanıt hızını hızlandırabilirsiniz.

### Copy-on-Write (COW) Teknolojisi

Dev Drive, ReFS dosya sistemine dayanır ve Copy-on-Write (COW) teknolojisinden yararlanır. COW, birden çok çağıranın aynı kaynağı aynı anda istediğinde, başlangıçta aynı kaynağı paylaştığı bir kaynak yönetimi teknolojisidir. Yalnızca bir çağıran kaynağı değiştirmek istediğinde, sistem o çağıran için kaynağın bir kopyasını oluşturur ve ardından bu kopyayı değiştirmesine izin verir, bu da diğer çağıranların kullandığı orijinal kaynağı etkilemez.

Dev Drive senaryosunda, COW teknolojisi önemli avantajlar sağlar:

1.  **Verimli Dosya Kopyalama**: Büyük bir dosyayı kopyalamanız gerektiğinde, ReFS hemen gerçek veri kopyalaması yapmaz, bunun yerine aynı disk bloklarını gösteren yeni bir dosya girişi oluşturur. Yalnızca kaynak dosya veya hedef dosya değiştirildiğinde, değiştirilen veri blokları gerçekten kopyalanır. Bu, dosya kopyalama işlemlerini çok hızlı yapar ve neredeyse ek disk alanı kaplamaz (değişiklik olana kadar).
2.  **Disk Alanından Tasarruf**: Birçok benzer dosya içeren önbellek dizinleri için (örneğin, birden çok projenin bağımlı olduğu aynı sürüm paketler), COW değiştirilmemiş veri bloklarını etkili bir şekilde paylaşarak genel disk kullanımını azaltabilir.
3.  **Performansı Artırma**: Gereksiz veri kopyalama işlemlerini azaltarak dosya işlemlerinin verimliliğini artırır.

### Dev Drive ve ReFS Özellikleri

Windows 11, geliştiriciler için optimize edilmiş bir depolama birimi olan Dev Drive'ı tanıttı. Dev Drive, dosya sistemi olarak Resilient File System (ReFS) kullanır ve özel optimizasyon özelliklerini etkinleştirir.

**ReFS (Resilient File System)**, Microsoft tarafından geliştirilen yeni nesil bir dosya sistemidir ve geleneksel NTFS'ye göre aşağıdaki avantajlara sahiptir:

- **Veri Bütünlüğü**: Sağlama toplamı ve otomatik onarım özellikleriyle verilerin güvenilirliğini artırır.
- **Ölçeklenebilirlik**: Daha büyük birim ve dosya boyutlarını destekler.
- **Performans Optimizasyonu**: Sanallaştırma ve büyük veri iş yükleri için optimize edilmiştir.
- **Entegre COW**: Geliştirme senaryolarındaki dosya işlemleri için özellikle yararlı olan Copy-on-Write anlambilimini yerel olarak destekler.

**Dev Drive Optimizasyonu**: ReFS temelinde, Dev Drive, paket yöneticisi önbelleği, yapı çıktısı gibi senaryolar için performans iyileştirmeleri gibi geliştirici iş yükleri için daha da optimize edilmiştir.

## Betik Özellikleri

Bu betik aşağıdaki ana işlevleri sunar:

- **Önbelleği Taşıma**: Çeşitli geliştirme araçlarının önbellek dizinlerini Dev Drive'a taşımayı destekler.
  - Node.js (npm, yarn, pnpm)
  - Python (pip)
  - .NET (NuGet)
  - Java (Maven, Gradle)
  - Go (Go modülleri)
  - Rust (Cargo)
  - VS Code Uzantıları
  - Windows TEMP/TMP dizinleri
    - JetBrains IDE'leri (IntelliJ, PyCharm vb.)
  - Android SDK
  - Chocolatey (Windows paket yöneticisi)
  - Kullanıcı gizli klasörleri (.xxx)
- **Dev Drive Oluşturma**: Kullanıcının yeni bir Dev Drive bölümü oluşturmasına yardımcı olmak için etkileşimli bir sihirbaz sağlar.
- **Dev Drive Silme**: Dev Drive bölümünü güvenli bir şekilde kaldırır ve taşınan önbelleği orijinal konumuna geri yükleme seçeneği sunar.
- **Önbelleği Geri Yükleme**: Dev Drive'a taşınan önbellek dizinlerini orijinal konumlarına geri yükler.
- **Bağlantı ile Taşıma**: Sembolik bağlantılar/birleştirme noktaları oluşturarak önbellek dizinlerini taşır, herhangi bir ortam değişkenini değiştirmez.
- **Test Modu**: Sistemi gerçekten değiştirmeden Dev Drive silme gibi işlevleri test etmek için güvenli simülasyon işlemleri sağlar.

## Kullanım Talimatları

1.  **Sistem Gereksinimleri**:
    - Windows 11 (Build 22000 veya üzeri)
    - PowerShell 7+ (pwsh)
2.  **Betiği Çalıştırma**:
    - PowerShell 7'yi (pwsh) yönetici olarak açın.
    - Betikin bulunduğu dizine gidin.
    - `.\Setup-DevDriveCache.ps1` komutunu çalıştırın.
3.  **Etkileşimli İşlem**:
    - Betik başlatıldığında, çeşitli işlemleri tamamlamanıza yardımcı olacak etkileşimli bir menü görüntülenir.
    - Önbelleği taşımak, Dev Drive oluşturmak veya silmek gibi işlemler için ilgili seçeneği seçin.
    - Tüm önemli işlemler kullanıcı onayı gerektirir, bu da güvenliği sağlar.

## Dikkat Edilmesi Gerekenler

- **Amaç**: Bu betiğin amacı önbellek klasörlerini taşımaktır, temizlemek değildir. Taşıma işleminden sonra, orijinal önbellek verileri hala mevcuttur, sadece depolama konumu değişmiştir.
- **Yedekleme**: Önemli işlemleri (Dev Drive silme gibi) yapmadan önce önemli verilerinizi yedeklemeniz önerilir.
- **Ortam Değişkenleri**: Betik kullanıcı ortam değişkenlerini okumaz veya yazmaz; taşıma sembolik bağlantılar aracılığıyla tamamlanır.

## Referanslar

- [Microsoft Dev Drive Resmi Dokümantasyonu](https://learn.microsoft.com/en-us/windows/dev-drive/)
- [Resilient File System (ReFS) Resmi Dokümantasyonu](https://learn.microsoft.com/en-us/windows-server/storage/refs/refs-overview)

## Destek

- [Nullprivate Reklam Engelleyici](https://www.nullprivate.com)