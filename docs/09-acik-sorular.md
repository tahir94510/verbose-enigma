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
