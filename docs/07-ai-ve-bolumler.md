# 07 — AI ve bölümler **[ÖNERİ]**

AoE2 DE AI eleştirileri (sayı hilesi, "tümsek" zorluk, mikro tanrısı, senaryo hissi) çözülecek sorunlar.

## Mimari
- AI, oyuncuyla **aynı komut sistemini** kullanır (duruşlar, plan, kural yuvası, Hypogeum, değişim). Kaynak hilesi yok.
- Dürüst görüş: sis kurallarına uyar, son gördüğünü hatırlar. Niyet ikonu gösterir.
- Tek sürekli zorluk değeri (0–1); kolay/orta/zor bu değerin üç noktası → bölümler arası basamaklı artış.
- Kişilik = tek AI'nın farklı ağırlıkları (5 ayrı AI yazılmaz).

## Zorluk kaldıraçları **[TASLAK]**
| | Kolay | Orta | Zor |
|---|---|---|---|
| Karar gecikmesi | 6–8 sn | 3–4 sn | 1–2 sn |
| Item planı | sabit, genel | sınıfa uygun | rakibin öncüsüne uyarlı |
| Komut dağarcığı | sadece otomatik | + duruş, geri çekilme eşiği | + pusu, tünel, değişim, çok yol baskısı |
| Bilgi | gördüğünü kullanır | son gördüğünü hatırlar | aktif keşif |
| Hata | kasıtlı hatalar | az | yok ama refleks sınırı (nişan sapması) |

## 15 bölüm = 5 bölüm × 3 madalya (bronz/gümüş/altın)
| Bölüm | AI çifti | Kişilik | Öğretilen | Oyuncu havuzu |
|---|---|---|---|---|
| I | Murmillo+Veles | temkinli, specula bekçisi | temel emirler, otomatik mod | Thraex, Secutor, Retiarius |
| II | Thraex+Retiarius | pusucu, baskıcı | duruşlar, Pusu | Murmillo, Secutor, Veles |
| III | Secutor+Murmillo | hızlı dalışçı | plan modu, kural yuvaları | Thraex, Retiarius, Veles |
| IV | Veles+Retiarius | mesafe/kontrol | Hypogeum, yedek değişimi | Murmillo, Thraex, Secutor |
| V | Thraex+Secutor | saldırgan usta komutan | hepsi | Murmillo, Retiarius, Veles |
Her bölüm istenen zorlukta açılabilir. Her bölümde kısa ipucu yönlendirmeleri gerekir.
