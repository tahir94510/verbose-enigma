#!/usr/bin/env python3
"""balance.gd çıktılarını (R satırları) toplar: python3 tools/balance_report.py out1.txt out2.txt ..."""
import sys, collections
rows = []
for f in sys.argv[1:]:
    for line in open(f, encoding="utf-8"):
        if line.startswith("R "):
            _, k, p0, p1, win, t, g0, g1, ne = line.split()
            rows.append((int(k), p0.split(","), p1.split(","), int(win), float(t), float(g0), float(g1)))
n = len(rows)
done = [r for r in rows if r[3] >= 0]
print(f"maç: {n}, biten: {len(done)}, zaman aşımı: {n - len(done)}")
if done:
    ts = sorted(r[4] for r in done)
    print(f"süre ort {sum(ts)/len(ts)/60:.1f} dk, medyan {ts[len(ts)//2]/60:.1f}, min {ts[0]/60:.1f}, maks {ts[-1]/60:.1f}")
    print(f"takım0 galibiyet {sum(1 for r in done if r[3]==0)}/{len(done)}  (yan yanlılığı)")
    inc = [(r[5] + r[6]) / 2 for r in done]
    print(f"ort. oyuncu geliri {sum(inc)/len(inc):.0f}")
    gw, gg = collections.Counter(), collections.Counter()
    for r in done:
        for c in r[1]: gg[c] += 1; gw[c] += (r[3] == 0)
        for c in r[2]: gg[c] += 1; gw[c] += (r[3] == 1)
    print("gladyatör galibiyet oranı (çift içinde yer aldığı maçlar):")
    for c in sorted(gg, key=lambda c: -gw[c] / gg[c]):
        print(f"  {c:10s} {gw[c]/gg[c]*100:5.1f}%  ({gw[c]}/{gg[c]})")
