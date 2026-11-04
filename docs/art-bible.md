# Art Bible — Korea: The Golden Kingdom (početna verzija)

Pravila za sve modele u igri: i za vlasnikove modele i za privremene modele koje agent pravi u
kodu. Privremeni i pravi model imaju iste mere, pivot, markere i ime fajla, pa pravi model samo
zameni privremeni, bez izmene koda. Ova verzija je početna; vlasnik je dopunjuje kad krene sa
pravim modelima.

## Razmera i ose

- 1 Godot jedinica = **1 m**. Sve je u stvarnoj razmeri.
- Polje mape = **4 × 4 m** (`TILE_SIZE` u `scripts/data/balance.gd`).
- Čovek (šetač) = **1,7 m**.
- Y gore. Sever = **−Z**, istok = **+X**.
- Ulaz zgrade (vrata) okrenut je ka **+Z** (jug) u osnovnoj rotaciji. Igrač rotira zgradu u
  4 koraka od 90°, a kamera se takođe rotira u 4 koraka, pa model mora dobro da izgleda sa
  sve četiri strane.

## Pivot i footprint

- Pivot (nulta tačka modela) je u **centru footprint-a, na nivou tla (y = 0)**.
- Footprint je u poljima (npr. 2×2 = 8 × 8 m). Zidovi i temelji ostaju unutar footprint-a.
- Strehe krova smeju da izađu najviše **0,6 m** preko ivice footprint-a.
- Visinske klase (orijentacija): ravna ≤ 0,5 m (put, polja, solana, glinište), niska ≈ 3–4 m
  (koliba, bunar), srednja ≈ 6–8 m (giwa kuća, radionice), visoka ≈ 10–14 m (hram, palata).
  Čuda po potrebi (Hwangnyongsa je 68–80 m). Tačni opsezi su u `HEIGHT_CLASSES` u
  `scripts/data/buildings.gd`, a test ih proverava.

## Markeri (prazni čvorovi u modelu)

| Ime čvora | Obavezan | Značenje |
| --- | --- | --- |
| `door` | da | tačka na ivici footprint-a uz put, gde šetači ulaze i izlaze |
| `smoke` | ne | dim (kuhinja, peć) |
| `worker_1`, `worker_2`... | ne | mesta gde stoje animirani radnici |
| `fx_*` | ne | ostali efekti (vatra, para, svetlo) |
| `Stage1`, `Stage2`... | samo čuda | delovi koji se pojavljuju po fazama gradnje |

## Imena fajlova

- Zgrade: `art/buildings/<building_id>.glb` — `building_id` je iz `scripts/data/buildings.gd`,
  engleski, snake_case (npr. `rice_paddy.glb`, `jangdokdae.glb`, `onggi_kiln.glb`).
- Kuće po nivoima: `art/houses/common_tier1.glb` … `common_tier5.glb`, `noble_tier1.glb`,
  `noble_tier2.glb`. Prazan plac pre doseljenika: `art/houses/vacant_lot.glb` (ravna klasa).
- Teren: `art/terrain/<terrain_id>.glb` (npr. `grass.glb`, `forest.glb`).
- Ljudi: `art/walkers/<walker_id>.glb` (npr. `carrier.glb`, `vendor.glb`).
- Dokkaebi: `art/walkers/dokkaebi.glb`, zdepast, oko 2,2 m (1,3 × čovek), jedan rog. Plavi
  plamen (dokkaebibul) je efekat u igri, ne deo modela.
- Izvorni fajlovi (.max, .blend, .psd) idu u `art_src/`, šabloni u `art_templates/`.
- Format za igru: glTF binarni (`.glb`).

## Budžeti (predlog)

| Šta | Trouglova | Materijala |
| --- | --- | --- |
| Šetač | do 1.500 | 1 |
| Obična kuća (po nivou) | do 3.000 | 1 (najviše 2 uz razlog) |
| Velika zgrada (hram, palata) | do 8.000 | 1 (najviše 2 uz razlog) |
| Čudo (ukupno, sve faze) | do 40.000 | do 4 |
| Polje terena | do 200 | 1 |

Jedna zgrada je **jedan model, jedan materijal**. Igra crta sve iste zgrade odjednom
(MultiMesh), pa broj poziva grafičkoj karti zavisi od broja vrsta zgrada × broja
materijala, ne od broja zgrada. Svaki dodatni materijal je dodatni poziv za svaku vrstu.

Teksture: zajednički atlas 2048 × 2048 po kategoriji (npr. sve kuće jedan atlas, svi hramovi
drugi), ili vertex color. Svaka mapa (Base Color, Normal, ORM, po potrebi Emission za svetla
noću) ima svoj atlas istog rasporeda. Providnost izbegavati: hanji papir na prozorima se
peče kao neproziran deo teksture. Drugi materijal je opravdan samo kad stvarno mora
(npr. providan deo koji se ne može ispeći). Jedan grad može imati hiljade objekata, pa su
budžeti strogi.

Igra pri učitavanju „peče“ model: sve delove spaja u jedan, po jedan deo za svaki
materijal. Zato se animacija i hijerarhija u `.glb` ne vide u gradu. Animirani delovi
(dim, zastavice, točak) kasnije idu kao poseban mali dodatak uz zgradu, ne u glavni model.

## Paleta

| Uloga | Boja |
| --- | --- |
| Giwa crep | #5b6470 (senka #454c56) |
| Slama (choga) | #c9a96b (senka #a88a52) |
| Malter, zidovi | #ece6d8 (senka #d3cbb8) |
| Drvo | #b07a4a (senka #8a5c35) |
| Granit | #bdb8ad (senka #9e998f) |
| Onggi ćupovi | #6b3f2a (odsjaj #8c5a40) |
| Zemlja | #a8643f |
| Lišće | #6f8f4e (senka #55703a) |
| Tlo | #e2d6bf |
| Dancheong (samo hramovi i palata) | tirkizno-zelena #3f8f7a, crvena #b8473a, oker #d1a24a |

## Korejski izgled (da se ne meša sa Kinom i Japanom)

- Krovovi blago zakrivljeni, strehe nežno podignute na uglovima: manje dramatično od kineskih,
  teže i vodoravnije od japanskih.
- Kuće na kamenom temelju, drveni stubovi i beli malter; podignut drveni pod (maru) kod hanoka.
- Redovi onggi ćupova u dvorištima, jangseung totemi na ulazima, granitne pagode.
- Dancheong boje samo na hramovima i palati, nikad na običnim kućama.

## Privremeni modeli (šta agent pravi u kodu)

- Prave se iz osnovnih oblika: kutija za zidove, prizma za giwa krov, zaobljena kupola za
  slamnati krov, valjak za ćupove i stubove, kapsula za čoveka.
- **Tačan footprint i visinska klasa** iz `buildings.gd`; pivot i `door` marker kao gore.
- Boja po kategoriji: stanovanje (malter + giwa), hrana (zelena), skladište (drvo), fermentacija
  (onggi smeđa), materijali i zanati (zemlja), religija (dancheong crvena i tirkizna),
  uprava (oker), infrastruktura (granit).
- Bez teksta na modelu u igri; natpisi (Label3D) samo u galeriji privremenih modela.
- Ako postoji `art/.../<id>.glb`, igra učitava njega umesto privremenog.

## Ikonice kuća

Pločice iznad kuća (raspoloženje i potrebe) čitaju jednu sliku: `art/ui/house_icons.png`,
256 × 256 px, 4 × 4 polja po 64 px, providna pozadina (PNG sa alfom). Ikonica je okrugla
pločica (hanji papir sa tankim tamnim rubom), mirne boje, bez sjaja. Raspored, red po red
od gornjeg levog ugla:

| Polje | Ikonica |
| --- | --- |
| 0 | lice: zadovoljno (zelena pločica) |
| 1 | lice: ravnodušno (žuta) |
| 2 | lice: tužno (crvena) |
| 3 | put |
| 4 | voda (kap) |
| 5 | hrana (činija pirinča) |
| 6 | Village Shrine (kamena gomila sa trakama) |
| 7 | Soybean Paste (ćup paste) |
| 8 | Clay Jars (onggi ćup) |
| 9 | Gi (taegeuk: crveno gore, plavo dole) |
| 10–15 | slobodno, za buduće potrebe (lekar, hram, muzika...) |

Dok slika ne postoji, igra crta privremene ikonice istog rasporeda (`scripts/view/house_icons.gd`).

## Provera modela (kasnije, faza 11)

Skripta `tools/check_models.gd` proverava modele u `art/` prema ovom dokumentu: pivot, mere
footprint-a, prekoračenje streha, markere, broj trouglova i materijala.
