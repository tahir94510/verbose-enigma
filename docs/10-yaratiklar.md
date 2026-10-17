# 10 — Arena yaratıkları ve dev doğa varlıkları

Sohbetteki istek: merkez bölgede mitolojik yaratıklar (ödül/buff, LoL ormanı rolü, tek rastgelelik katmanı) ve iki köşeden çıkıp en dış yapılara yürüyen dev varlıklar (AoE'deki Gaia benzeri doğa tehdidi). Hepsi **[ÖNERİ/TASLAK]**; sayılar `game/data/creatures.json` içinde ve testle ayarlanır.

## Kaynak notları (dürüst durum)
- **Venatio** (arenada vahşi hayvan avı) gerçek Roma uygulamasıdır; sabahları gladyatör dövüşlerinden önce yapılırdı (Wikipedia: Venatio, Colosseum kaynakları). Bu yüzden en küçük kamp arena hayvanıdır.
- **Chimaera**: Etrüsk sanatında bilinir — "Arezzo Chimerası" bronzu (~MÖ 400, World History Encyclopedia). Gerçek bir Etrüsk-Roma bağı olduğu için orta kampa seçildi.
- **Hydra (Lerna)**: Hercules'in işlerinden; Romalılar Hercules'i benimsedi. Kopan başın yenilenmesi, ateşle dağlayarak durdurulması mitin kendisi (Herakles + Iolaus) — mekaniğimize doğrudan oturuyor.
- **Gigantes / Typhon**: Smith'in Greek and Roman Biography sözlüğünde Typhon "yıkıcı fırtına / ateş soluyan dev" olarak geçer. Dev doğa varlığı için genel bir "Gigas" kullanıyoruz; tek bir isimli mit değil, bilinçli genel ad.
- **Cacus** (Aeneis VIII, Hercules tarafından öldürülen ateş soluyan dev): **web aramasında doğrulanamadı**; birincil kaynakla (Vergilius, Aeneis VIII) teyit edilmeden kullanılmayacak. Aday: ileride isimli boss.
- **Charun/Vanth** (Etrüsk, ölülere yol gösteren): Wikipedia'ya göre cezalandırıcı değil kılavuz; kamp için uygun değil, ileride atmosfer/ikon motifi olabilir.
- Arama sonuçlarının çoğu Yunan odaklı ve düşük kaliteli SEO sayfalarıydı; Roma/Etrüsk'e özgü liste güvenilir biçimde bulunamadı. Mitoloji metinleri üretime girmeden önce uzman/birincil kaynak taramasından geçmeli. **[AÇIK]**

## Kamplar (merkez bölge, kulesiz)
| Yaratık | Konum | İlk doğma / yeniden | Can·Saldırı·Zırh | Ödül | Buff |
|---|---|---|---|---|---|
| Leo (arena aslanı) ×2 | her tarafın yanında | 1:30 / 2:00 | 600·35·15 | 80 altın, +15 Favor | yok |
| Chimaera ×2 | merkeze yakın | 3:00 / 3:00 | 1500·55·25 | 120, +25 Favor | **Ardor**: +%20 saldırı, 90 sn |
| Hydra Lernaea ×1 | tam merkez | 6:00 / 5:00 | 3200·70·30 | 150, +40 Favor | **Lerna kanı**: +%15 saldırı, +20 zırh, %35 can, 120 sn |

- Yaratıklar yerinde durur; 200 menzilindeki oyuncu birimine/gladyatöre saldırır, 380–420 uzaklaşınca bırakıp eve döner ve iyileşir.
- **Hydra** saniyede %2,5 yenilenir; **Kanama** (Thraex) veya **ısı** (Secutor, ısı ≥ 50) etkisi altındayken yenilenmez. Böylece sınıf kimliği kampa karşı anlam kazanır; hasarı yetersiz sınıf kampı çok geç keser.
- Ödülü yalnızca **gladyatör** vurursa tam alınır (birimler vurursa yarısı). Kampa gitmek hattı terk etmektir → LoL'deki "orman ya da hat" kararı. Gladyatör `Yaratık` emriyle gider (grup/specula emirleri gibi kurye mantığı yok, doğrudan emir).
- Sis kuralları geçerli: kamp içeriği görülmeden bilinmez.

## Gigas (dev doğa varlıkları)
- 6:00'da ve 12:00'da (en çok 2 olay) iki köşeden (üst-sağ, alt-sol) çıkar. Her köşe **iki** dev gönderir: biri kendi, biri rakip tarafın o yoldaki en dışta ayakta duran specula'sına yürür → toplam 4. İkinci olayda %25 daha güçlü.
- **Sohbetteki "kura ile hedef" fikrinden bilinçli sapma:** simetrik gönderim hem adil hem okunur; rastgelelik zaten merkez kamplardan gelir. İtirazın olursa kuraya döneriz. **[AÇIK]**
- Herkese **her zaman görünür** (sisten bağımsız) ve 20 sn önce cornu uyarısı gelir: "Köşelerden Gigas geliyor".
- 5000 can, 220 saldırı (2,5 sn'de bir), zırh 35; vuruşu çevresine %50 sıçrar (auxilia ezilir). Specula'yı yıkarsa **kimseye altın vermez**; devi öldüren taraf 200 altın (kuleler/birimler öldürürse yarısı) ve Favor alır.
- Tavan: gladyatör + auxilia ile savunmak mümkün; ihmal edilen yol dış specula'yı kaybeder. Hypogeum + Signum (emir menzili) burada anlam kazanır.

## Test edilenler
Doğma/yeniden doğma süreleri, ödül miktarı, Hydra yenilenmesi ve kanamayla durması, Gigas uyarısı/sayısı/görünürlüğü, "Gigas yıkımı altın vermez" — `game/tests/run_tests.gd`.
## Açık
Gigas'ın gerçek maçlardaki etkisi (ölçüm: 09), kamp sayısı/konumu (haritayı kalabalık yapmasın), isimli boss (Cacus teyidi), her yaratığın silueti ve sesi (08).
