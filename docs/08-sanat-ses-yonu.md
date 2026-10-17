# 08 — Sanat ve ses yönü

**Sanat kullanıcının/sanatçının kontrolünde.** Kod tarafı yer tutucu geometrik ikonlar kullanır; nihai varlıklar sonradan aynı kimliklerle (`data/` içindeki id) değiştirilir. **[KARAR]**

## Yön **[ÖNERİ]**
- Referans (kopyalama değil ilham): Pompeii fresk paletleri, Roma mozaikleri, müze arşivleri; takım renkleri AoE2 mantığıyla; kontrast hiyerarşisi LoL gibi ("önemli olan parlak").
- Her gladyatörün siluet, renk, kalkan/miğfer dili, hareket zamanlaması farklı; hedef ikonlar harita ikonlarından ayrışır.
- İkonlar küçük ama ayırt edilebilir; harita ölçeğiyle orantılı. 2–3 karelik yürüme/idle; fazlası kodla (sıkışma/uzama, geri tepme). Murmillo ağır, Retiarius kayar, Secutor ısındıkça kızarır.
- Yapılar hasar evresiyle görünür değişir (sağlam → çatlak → duman/ateş → çöküş). Dev doğa varlıkları ve arena yaratıkları ayrı varlık.

## Ses **[ÖNERİ]**
cornu uyarıları, hidravlos/tuba, Favor ile yükselen kalabalık; her durum etkisi ayrı ses. "Epik film" klişesi yok; **ticari lisansı net veya özgün** müzik (mağazada en pahalı hata telif).

## Silüet, palet ve okunabilirlik kuralları **[ÖNERİ]** (kodda yer tutucu olarak uygulandı)
- **Takım renkleri sabit ve doygun:** oyuncu mavi-turkuaz, rakip kiremit-kırmızı (AoE2 takım rengi mantığı). Gladyatör sınıf rengi gövdede, takım rengi halkada: ikisi karışmaz.
- **Şekil önce, renk sonra:** auxiliarius daire, sagittarius üçgen, balista kare, specula kare+kalın çerçeve, Ludus büyük daire; tek renk körlüğünde de ayrışır.
- **Nötr/doğa varlıkları altın-toprak tonları:** takım renklerinden ayrı olduğu için "kimsenin değil" okunur. Gigas elmas + kırmızı halka (tehdit), kamp yaratıkları daire + açık çerçeve.
- **Hasar durumu yapıda görünür:** çatlak çizgisi → duman → ateş (AoE2). Can barı gladyatör/specula/nötrde hep, auxilia'da yalnız yaralıyken.
- **Hedef ikonu** gladyatörün sağ üstünde, birim ikonundan görsel olarak farklı (siyah dolgulu halka). Niyet metni gladyatör başının üstünde.
- Sis: soluk karartma, tam siyah değil; son görülen yapılar yarı saydam.
- Nihai sanat için referans toplanacak (kopyalama değil): Pompeii fresk paletleri (kırmızı okr, Pompeii kırmızısı, sarı okr, yeşil toprak), Roma zemin mozaiklerinin siyah-beyaz-terrakota dili, müze arşivlerinden zırh/miğfer formları. **Çizim sanatçıyla yapılacak**; kod aynı id'lerle değiştirir.
