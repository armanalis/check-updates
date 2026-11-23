# Windows test kontrol listesi

Süre: yaklaşık 20 dakika. Her maddeyi işaretle, sorun olanın ekran görüntüsünü al.

## 1. Çalıştırmadan önce: güvenlik (3 dk)

- [ ] Başlat menüsünde **PowerShell**'i aç, sitedeki komutu yapıştır:
      `irm https://check-updates.armanalis.workers.dev/install.ps1 | iex`
      "Kuruldu" yazmalı ve uygulama uyarı vermeden açılmalı. Başlat menüsünde "Check Updates" aranınca çıkmalı.
- [ ] Aynı PowerShell penceresinde şunu çalıştır:
      `Get-FileHash $env:LOCALAPPDATA\Programs\CheckUpdates\CheckUpdates.exe`
      Çıkan kod tam olarak şu olmalı:
      `973E770602E5E7FBD0D3F351604F0DC873B16EBAE90473CDC00C03F6D50A5F8F`
      Aynıysa dosya, Mac'te derlenen dosyanın birebir aynısı demek.
- [ ] Dosyaya sağ tıkla → **Microsoft Defender ile tara**. "Tehdit bulunamadı" demeli.
- [ ] Defender bir şey bulursa çalıştırma. Uyarının ekran görüntüsünü al.

## 2. Açılış (2 dk)

- [ ] Çift tıkla. "Windows bilgisayarınızı korudu" çıkarsa: **Ek bilgi** → **Yine de çalıştır**. Bu normal, dosya imzasız olduğu için çıkıyor.
- [ ] Pencere açılıyor, başlıkta **Check Updates** yazıyor, yeşil ikon görünüyor.
- [ ] Yazılar net, bulanık değil. Pencereyi büyütüp küçültünce düzgün duruyor.

## 3. Kontrol (3 dk)

- [ ] Açılınca başlıkta dönen çark (◐◓◑◒) ve "Kontrol ediliyor…" görünüyor.
- [ ] 10–60 saniye içinde liste doluyor ve başlık "N güncelleme var" ya da "Hepsi güncel" diyor.
- [ ] Listedeki uygulama adları ve sürümler doğru görünüyor (Türkçe karakterler bozuk değil).
- [ ] Sağlama: Başlat menüsünde **Terminal**'i aç, `winget upgrade` yaz. Çıkan liste uygulamadakiyle aynı olmalı.
- [ ] "winget bulunamadı" çıkarsa: o bilgisayarda winget yok, bunu not et.

## 4. Güncelleme (5 dk)

- [ ] Listeden küçük bir uygulamayı seç (Chrome gibi açık olmayan bir şey) → **Seçileni Güncelle**.
- [ ] Durum sütununda dönen çark ve **%** yüzde görünüyor, sonra "✓ Güncellendi" yazıyor.
- [ ] Yönetici izni (UAC) sorarsa **Evet** de, güncelleme devam etmeli.
- [ ] Güncellenen uygulama listeden kalkıyor (yeniden kontrolden sonra).
- [ ] **Hepsini Güncelle**: önce onay soruyor mu? İptal'e basınca hiçbir şey olmamalı.

## 5. Yeni özellikler (5 dk)

- [ ] Sağ üstte, butonların üstünde küçük gri `github.com/armanalis/check-updates` linki var; tıklayınca repo açılıyor.
- [ ] Bir uygulamaya sağ tık → **Listeden Kaldır**. Listeden çıkmalı. ⚙ → "Kaldırılan uygulamalar"da görünmeli; işareti kaldırıp Tamam'a basınca geri gelmeli.
- [ ] ⚙ → Dil: **English** seç, Tamam. Butonlar ve başlık İngilizce olmalı. **Türkçe**'ye geri al.
- [ ] Güncelleme hata verirse satır turuncu olmalı ve sebebi Türkçe yazmalı (ör. "Uygulama açık. Kapatıp tekrar dene"). Üstüne gelince ayrıntı çıkmalı.
- [ ] Hatalı satıra sağ tık → **Yönetici Olarak Dene**. Windows izin sorar (UAC), **Evet** de; güncelleme bitmeli.

## 6. Sorun olursa bana gönder

- Ekran görüntüsü
- Durum sütunundaki hata kodu (ör. `⚠ Hata (0x8A150011)`)
- Terminal'de `winget --version` çıktısı
- Windows sürümü: Ayarlar → Sistem → Hakkında
