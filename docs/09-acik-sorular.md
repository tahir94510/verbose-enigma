# 09 — Açık sorular ve eleştirel inceleme

Sohbetteki iddialar körü körüne alınmadı; tutarsızlıklar ve riskler:

## Düzeltilecek / doğrulanacak
1. **Gelir hesabı:** 13 dk'da her yolda 26 dalga, 2 yol → ~52 manipulus × 92 ≈ 4800 ham; sohbetteki "~2700 (%70)" bununla tutmuyor. Gerçek maç simülasyonuyla yeniden ölçülecek; 7500 hedefi ve item fiyatları buna göre ayarlanır.
2. **Taban stat tablosu eksik:** Kritik şansı ve Alan hasarı tabloda yok; Spatha/Gladius Hispaniensis bunlara dayanıyor. Eklenmeli.
3. **Karşı seçim döngüsü** net değil (Secutor↔Retiarius "yenik değil/eşit/tersi" çelişkili). Sayısal eşleşme matrisi (10 çift) simülasyonla çıkarılacak.
4. **Yüzde-stat tuzağı:** aynı % tabanı yüksek sınıfa daha çok verir (Murmillo can). Taban sayılar sabitlenince item etkileri mutlak/yüzde karışımına bakılacak.
5. **Specula dalış hesabı:** tek başına 2500 can / ~43 dps ≈ 58 sn; "27 sn" yalnızca auxilia yanındayken. Pekiştirilmiş zırh değeri tanımsız.
6. **Hypogeum kötüye kullanımı:** rakip specula'ya dürterek tüneli kapatabilir. Kapanma kuralı (kanal süresi, minimum saldırı süresi) netleşmeli.
7. **Tarihsel iddialar zayıf:** Retiarius=Neptün / Secutor=Vulcan eşlemesi modern yorum, kesin değil; Veles kaynağı ince. Oyunda "ilham" olarak kullanılacak, tarihî gerçek diye sunulmayacak.
8. **Mobil yük:** iki gladyatör + Munus düğmesi + yedek çipi + çipler + plan modu aynı ekranda; ≤2 dokunuş hedefi paper-prototype ile sınanmalı.
9. **Munus manuel/otomatik:** duruşa bağlı kural doğru ama oyuncu için ekranda "neden bekliyor" göstergesi şart.
10. **Önden/arkadan hasar (Murmillo):** gladyatör sürülmediği için yön otomatik; yönelme kuralları (hedefe dönme hızı) tanımlanmalı.
11. **Pusu istismarı:** yalnızca örtü bölgesi + yakın mesafede açığa çıkma; tek taktik olmaması testle doğrulanacak.

## Açık kararlar
- Oyun adı (marka taraması kullanıcıda). Hat/specula karakterli Latince adları.
- Merkez arena yaratıkları ve dev doğa varlıkları (Roma/Etrüsk mitolojisi araştırması, ödül/buff).
- Harita ölçüsü ve kamera yaklaşımı. Ses/müzik kaynağı. Sanat üretimi (kim çizecek).
- Yeniden doğma/değişim süreleri, ölüm serisi değeri.

## Dikey dilim ölçümleri (headless AI-vs-AI, `game/tools/balance.gd`)
- İlk sürümde maçların %60'ı **kilitlendi** (eşit dalgalar ortada birbirini yok ediyor, 40 dk'da bitmedi). Çözüm: dalga birimleri zamanla güçleniyor (+%6/dk) ve her 8 dalgada +1 auxiliarius (`wave.scale_per_min`, `wave.extra_aux_every`). Sonuç: zaman aşımı 0, ortalama maç **15–16 dk** (hedef 12–15; kolay 15,0 · orta 15,8 · zor 16,1). Biraz uzun; pasif gelir veya specula can değerleri sonra ayarlanır.
- Oyun başına gerçek toplam gelir **~8700–9300** (taslak hedef 7500). Fiyatlar sabit tutuldu; item alım hızı oyuncu planına bağlı.
- Bulunan hata: alım planı birleşip kaybolan bileşenleri yeniden satın alıyordu (altın boşa gidiyordu). Düzeltildi (`bought` kaydı), testle korunuyor.
- Manica tarifi sohbette 340 + 560 = 900; diğer epiklerin ücreti 600. Tutarsızlık bilinçli korundu, onay bekliyor.
- Sınıf galibiyet oranları (10 maç) anlamlı değil: örnek küçük ve Secutor çok maçta takım 1'de çıktı. Çift eşleşmesi dengelenmiş büyük örnekle (en az 200 maç) ölçülecek. Zor AI'nın kolay AI'yı yendiği henüz **doğrulanmadı** (iki taraf aynı zorlukta koştu).
- Web/Android export henüz denenmedi (bu ortamda export şablonları yok); yalnızca masaüstü Godot + headless test ve xvfb ekran görüntüsü doğrulandı.

## Tur 2 ölçümleri (200 maçlık dengeli koşu + zorluk testleri)
`game/tools/balance.gd` + `balance_report.py`: 10 gladyatör çiftinin 100 eşleşmesi, orta zorluk AI-vs-AI, yaratıklar ve Gigas açık.
- **Süre:** 200/200 maç bitti, ortalama **17,5 dk** (min 10,4 · maks 23,6). Hedef 12–15 dk → **hâlâ uzun**; Gigas/kamplar maçı biraz uzattı. Ayar adayları: pasif gelir, specula canı, dalga büyümesi. **[AÇIK]**
- **Yan yanlılığı:** takım0 99/200 → yan avantajı yok.
- **Gelir:** oyuncu başı ortalama **~10 600** altın (taslak hedef 7500; yaratıklar ve uzun maç etkili). Item fiyatları gelire göre yeniden ayarlanmalı veya gelir düşürülmeli. **[AÇIK]**
- **Gladyatör galibiyet oranı (çift içinde):** Thraex %54,4 · Secutor %51,2 · Murmillo %50,6 · Retiarius %47,5 · Veles %46,2. Aralık dar (160 maç/sınıf, ±%4 gürültü); Veles ve Retiarius hafif geride, henüz müdahale gerektirmiyor.
- **AI zorluğu çalışmıyor (önemli bulgu):** zor-vs-kolay ilk ölçümde zor AI **kaybediyordu** (11/40). Nedeni ablasyonla bulundu: AI'nın kamp avı (hattı bırakıp yaratığa gitmek) onu zayıflatıyordu; kapatınca 16/30'a çıktı. Kamp avı artık varsayılan AI'da **kapalı** (`camp` bayrağı). Düzeltmeden sonra zor-vs-kolay **32/60 (%53)**, orta-vs-kolay **30/60 (%50)** → zorluk seviyeleri pratikte **ayırt edilemiyor**. Sebep: gladyatör savaş/pozisyon mantığı ortak; zorluk yalnızca karar gecikmesi, item planı ve birkaç düğmeyi etkiliyor. Sohbetteki beş kaldıraç (gecikme, item planı, komut dağarcığı, bilgi kullanımı, hata payı) gerçek davranışa henüz bağlanmadı. **Sıradaki iş:** zorluk → gladyatör kararlarına (hedef seçimi gecikmesi, geri çekilme eşiği, kule dalışı güvenliği, kasıtlı hatalar) bağla, ölçümle doğrula.
- Kamp avı sorunu: AI yaratığa giderken hat boşalıyor ve auxilia desteksiz kalıyor; oyuncu için de "orman ya da hat" kararının maliyetli olduğunu doğrular (tasarım amacına uygun), ama AI için güvenli bir kural (yakınlık, sağlık, düşman gladyatör yok) ölçümde yetmedi.
- **Web export doğrulandı:** Godot 4.3 web (tek iş parçacıklı) şablonu ile derlendi (wasm ~35 MB, pck <0,1 MB), Chromium'da açılıyor ve menüden oyuna geçiliyor. İlk denemede menü/HUD sabit koordinatlarla ekran dışına taşıyordu — hata bulunup çapalı yerleşime çevrilerek düzeltildi. wasm boyutu mobil web için büyük (sıkıştırmayla ~9 MB beklenir, ölçülmedi). Android export denenmedi (SDK/şablon yok).
- Cacus, isimli boss ve Charun/Vanth kullanımı: birincil kaynak teyidi bekliyor (bkz. 10).
