# verbose-enigma

Roma arenası temalı, kuş bakışı, 1v1 komutan stratejisi (çalışma adı belirlenmedi). Motor: Godot 4.3 (GDScript).

- Tasarım: [`docs/`](docs/) — `[KARAR]` onaylı, `[ÖNERİ]` önerildi, `[TASLAK]` test edilecek sayı, `[AÇIK]` bekleyen.
- Eleştirel inceleme ve ölçümler: [`docs/09-acik-sorular.md`](docs/09-acik-sorular.md)

## Dikey dilim (oynanabilir)
`game/` klasörünü Godot 4.3 ile aç ve çalıştır. İki gladyatör + zorluk seç.
- Sol tık: grup/specula seç · Sağ tık sürükle ya da yön tuşları: kamera · Minimap'e tıkla/sürükle
- Q/W/E duruş (Saldırgan/Savunmacı/Pusu) · D iyileş · F Hypogeum (sonra çıkış yapısına tıkla) · B geri çekil
- Plan modu: emirler sıraya girer (en çok 4) · Space: gladyatöre git · P duraklat · +/- hız
- Emirler gladyatör tarafından kurye gibi iletilir (menzile girince uygulanır); gladyatör doğrudan sürülmez.
- Görseller bilinçli yer tutucu geometrik ikonlardır.

## Yapı
- `game/sim/` deterministik simülasyon (çizimden bağımsız) · `game/ai/` rakip komutan (aynı komut API'si)
- `game/data/` tüm stat/item/ekonomi sayıları · `game/view/` çizim ve arayüz
- `game/tests/run_tests.gd` testler · `game/tools/balance.gd` denge simülatörü

## Web sürümü
```
godot --headless --path game --export-release "Web" ../build/web/index.html   # export şablonları gerekir (4.3.stable)
cd build/web && python3 -m http.server 8765
```
Tek iş parçacıklı web dışa aktarma (özel başlık gerektirmez).

## Komutlar
```
godot --headless --path game -s tests/run_tests.gd        # testler
godot --headless --path game -s tools/balance.gd -- 0 50 0.5   # 50 AI-vs-AI maç (başlangıç, sayı, zorluk0 [zorluk1])
python3 game/tools/balance_report.py out.txt                    # sonuçları topla
```
