# Stanje projekta

Poslednje ažuriranje: 3. novembar 2026.

## Gde smo stali

Gotove faze 1–6, 7a, brže crtanje zgrada i pregledniji prozor zgrade. Testova: 153, svi prolaze.

| Faza | Šta je urađeno | Commit |
| --- | --- | --- |
| 1 | Postavka, mapa po pungsu-u, kamera, sat, privremeni modeli | d23e894 |
| 2 | Gradnja, putevi, rušenje, cene, prikaz dometa, Jangseung na putu | 9599745 |
| 3 | Putna mreža, Granary, Storehouse, nosači sa jigeom | 12eecac |
| 4a | Ulaz u dolinu, doseljenici, kuće koje rastu, radna snaga, porez, prozor kuće | 2fd5107 |
| 4b | Pijaca (Buyer, Vendor), šetač Seonangdang-a, ishrana iz ostave, overlay F1–F3 | fbd0553 |
| 5 | Sejv sa verzijom i kontrolnim zbirom, Ctrl+S / Ctrl+L, autosave sa 3 kopije, scena „veliki grad" | 2eef9a8 |
| 5+ | Iste zgrade se crtaju zajedno (MultiMesh): veliki grad 60 FPS, oko 220 poziva umesto 16.500 | 49171c2 |
| 6 | Soja i so (čekaju Jangdokdae), Onggi Kiln (Clay + Wood → Onggi Jars) sa donosačem, razlozi zastoja, znak „?“, prozor Goods (F4) | c0b40cf |
| 7a | Jangdokdae: ćupovi kao mesta, Jang Fresh → Ripe, dugme Release, ćupovi na terasi; Clay Pit stoji na brdu | 508fcc1 |
| 7a+ | Prozor zgrade: Show range sa stubićima kuća, šetači zgrade (linije i oznake), radnici grada, okvir izabrane zgrade | 7d34cfd |
| demo | Demo grad (`scenes/demo_town.tscn`, F6): mala dolina sa svim lancima koji rade od starta | (sledeći) |

## Sledeće: Faza 7b, pijaca i nivo 3

- Pijaca kupuje i prodaje Rice, Jang i Onggi Jars; prodavac nosi sve tri.
- Kuća ima ostavu za Jang (Ripe traje duplo duže) i ćupove koji traju godinu dana.
- Kuće rastu u Giwa House (nivo 3); overlay za Jang i ćupove; prozor kuće kaže šta fali.

Prvo plan, pa kod posle vlasnikovog „ok".

## Utisci vlasnika posle igranja (Faza 4b)

- Tempo je brži od Zeusa i tako odgovara; ne usporavati.
- Stanovnici mnogo jedu, ali je to u redu: rešenje je više njiva. Grad od oko 130 ljudi tražio je
  dve pijace.
- Kasnije će verovatno trebati veća mapa (sada 64 × 64). Plodno polje je u centru mape.
  Razgovarati o tome kod Faze 10 (MVP scenario).
- Brojeve balansa vlasnik podešava sam dok igra (`scripts/data/balance.gd`, `buildings.gd`).
