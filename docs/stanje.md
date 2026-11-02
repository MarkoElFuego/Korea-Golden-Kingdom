# Stanje projekta

Poslednje ažuriranje: 2. novembar 2026.

## Gde smo stali

Gotove faze 1–4 (commit `fbd0553`, poslato na GitHub). Testova: 111, svi prolaze.

| Faza | Šta je urađeno | Commit |
| --- | --- | --- |
| 1 | Postavka, mapa po pungsu-u, kamera, sat, privremeni modeli | d23e894 |
| 2 | Gradnja, putevi, rušenje, cene, prikaz dometa, Jangseung na putu | 9599745 |
| 3 | Putna mreža, Granary, Storehouse, nosači sa jigeom | 12eecac |
| 4a | Ulaz u dolinu, doseljenici, kuće koje rastu, radna snaga, porez, prozor kuće | 2fd5107 |
| 4b | Pijaca (Buyer, Vendor), šetač Seonangdang-a, ishrana iz ostave, overlay F1–F3 | fbd0553 |

## Sledeće: Faza 5, snimanje i stabilnost

- Sejv sa brojem verzije.
- Automatski sejv sa 3 kopije; snimanje nikad ne prepisuje jedini postojeći fajl.
- Test scena „veliki grad" (cilj: 60 FPS sa 3.000 stanovnika i 400 šetača).

Prvo plan, pa kod posle vlasnikovog „ok".

## Utisci vlasnika posle igranja (Faza 4b)

- Tempo je brži od Zeusa i tako odgovara; ne usporavati.
- Stanovnici mnogo jedu, ali je to u redu: rešenje je više njiva. Grad od oko 130 ljudi tražio je
  dve pijace.
- Kasnije će verovatno trebati veća mapa (sada 64 × 64). Plodno polje je u centru mape.
  Razgovarati o tome kod Faze 10 (MVP scenario).
- Brojeve balansa vlasnik podešava sam dok igra (`scripts/data/balance.gd`, `buildings.gd`).
