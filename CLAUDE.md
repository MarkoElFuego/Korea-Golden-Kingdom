# Korea: The Golden Kingdom — uputstvo za Claude Code

Odgovaraj na srpskom (latinica). **Sve što je u igri je na engleskom**: nazivi, lore, opisi, misije,
UI tekstovi. Kod, imena fajlova, čvorova i promenljivih su takođe na engleskom.
Vlasnik projekta je 3D artist i arhitekta sa 20 godina iskustva, ali nije programer:
objašnjavaj jednostavno, bez žargona, i pre svake veće izmene ukratko predloži plan.

## Igra

Izometrijski city builder u duhu Zeus: Master of Olympus i Pharaoh (Impressions Games).
Igrač gradi Seorabeol, prestonicu Sile (mitologizovana Koreja, 7–9. vek): putevi, kuće koje
napreduju, šetači koji raznose robu i usluge, proizvodni lanci, fermentacija, Gi (pungsu),
bogovi, čudovišta, heroji, velika čuda i kampanja od osam misija.

**Izvor istine je `docs/koncept.md`**: pravila, zgrade, roba, imena i lore.
Ako nešto u konceptu nije jasno ili se kosi sa kodom, pitaj vlasnika, ne izmišljaj.
Ako neka odluka iz razgovora promeni pravilo, predloži i izmenu koncepta.

Prvi cilj je **MVP**: jedna mapa doline sa rekom i morem, 15 zgrada, i jedno pitanje:
„da li je zabavno gledati grad kako diše". Platforma: samo PC (Windows, Steam).
Igra se pravi u fazama; vlasnik u svakoj sesiji daje prompt za jednu fazu.

## Tehnički okvir

- Godot **4.7.2**, **GDScript**. Renderer: **Forward+**.
- Bez `class_name`: skripte se povezuju sa `const X = preload("res://...")`, da bi testovi
  radili i bez editora.
- Godot (editor): `C:/Users/User/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe`
- Godot (konzola, za testove): `C:/Users/User/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
- **Godot MCP** je podešen u `.mcp.json` (`@coding-solo/godot-mcp`). Koristi ga da pokreneš igru
  (`run_project`), pročitaš greške (`get_debug_output`) i zaustaviš je (`stop_project`).
  Ako MCP ne radi, reci vlasniku šta da proveri i nastavi sa headless testovima.
- **Simulacija ide na fiksni tik** (`SimClock`), ne na frame rate. Brzina igre (pauza, 1×, 2×, 3×)
  menja samo broj tikova u sekundi, ne logiku.
- **Determinizam:** sva slučajnost ide kroz jedan RNG sa seed-om. Isti seed i iste komande igrača
  daju isti grad, da testovi mogu da „odigraju" hiljade tikova bez grafike.
- Mapa je **kvadratni grid** kao u Zeusu. Jedno polje = **4 × 4 m** (`TILE_SIZE` u
  `scripts/data/balance.gd`). Sve mere su u metrima, u stvarnoj razmeri (vidi `docs/art-bible.md`).
- Kamera: ortografska, izometrijski ugao, rotacija u 4 koraka od 90° (Q/E), zum (točkić),
  pomeranje (WASD, ivica ekrana, srednji taster miša).
- Putanje: `AStarGrid2D` nad putnom mrežom; mreža se ažurira samo kad se put izgradi ili sruši.
- Svi tekstovi za igrača idu kroz `tr()` sa ključevima iz `data/text/en.csv`. Engleski je osnovni
  jezik; lokalizacija (npr. korejski) kasnije je samo novi CSV, bez izmene koda.
- Korejski termini u igri: Revised Romanization bez dijakritika (Gyeongju, Hwangnyongsa, jangdokdae).

## Struktura projekta

```
project.godot
.mcp.json
CLAUDE.md
docs/        koncept.md, art-bible.md, analiza-fanova.md
scripts/sim/   simulacija bez grafike (grid, mapa, sat, ekonomija, šetači...)
scripts/view/  prikaz: kamera, teren, modeli, UI (samo čita stanje)
scripts/data/  balance.gd, buildings.gd, goods.gd, terrain.gd (svi brojevi)
data/text/     en.csv (svi tekstovi za igrača)
scenes/        main.tscn, placeholder_gallery.tscn, ...
tests/         run_tests.gd + test_*.gd
tools/         pomoćne skripte (provera modela i sl.)
art/           vlasnikovi gotovi modeli (.glb)
art_src/       izvorni fajlovi (.max, .blend, .psd), ima .gdignore
art_templates/ šabloni za modele, ima .gdignore
```

## Pravila arhitekture

1. Pravila i stanje igre žive u skriptama bez grafike (`scripts/sim/`). Prikaz (`scripts/view/`)
   samo čita stanje i ništa ne odlučuje.
2. Svi brojevi balansa (cene, kapaciteti, domet šetača, vreme zrenja, potrebe kuća) su podaci na
   jednom mestu (`scripts/data/`), ne rasuti po kodu.
3. Svako novo ili promenjeno pravilo dobija test u `tests/`. Posle svake izmene logike pokreni:
   `<Godot console exe> --headless -s res://tests/run_tests.gd` (iz foldera projekta).
   Posao je gotov tek kad svi testovi prolaze.
4. Ne briši i ne prepisuj fajlove u `art/`, `art_src/` i `art_templates/`. To su modeli vlasnika.
   Pravila za modele (razmera, pivot, markeri, imena fajlova, budžeti) su u `docs/art-bible.md`.
5. **Privremeni modeli:** dok vlasnik ne napravi svoje, igra koristi modele koje praviš u kodu od
   osnovnih oblika (kutija, prizma za krov, valjak za ćup, kapsula za čoveka). Oni moraju da
   poštuju iste mere, pivot, markere i imena kao Art Bible, da bi vlasnikov `.glb` kasnije samo
   zamenio privremeni, bez izmene koda. Ako postoji `art/.../<id>.glb`, koristi njega.
6. Jedna faza po sesiji, male izmene. Za veće stvari prvo plan, pa kod.
7. Kad ne možeš sam da proveriš izgled ili osećaj igre, reci vlasniku tačno šta da proveri
   posle F5 u Godotu.
8. Performanse se mere od početka: teren ide kroz MultiMesh, a od faze 5 postoji test scena
   „veliki grad" (cilj: 60 FPS na srednjem PC-ju sa 3.000 stanovnika i 400 šetača).

## Lekcije iz konkurencije (obavezna pravila dizajna)

Iz analize recenzija Zeus-like igara (`docs/analiza-fanova.md`). Pre završetka svake faze
proveri da je ne kršiš.

1. **Stabilnost pre obima.** Najčešća pritužba u žanru su bagovi, rušenja i izgubljeni sejvovi.
   Ne dodaj novu funkciju dok stare nisu pokrivene testovima. Sejv ima broj verzije; automatski
   sejv rotira 3 kopije; snimanje nikad ne prepisuje jedini postojeći fajl (prvo piše novi, pa
   menja ime).
2. **Bez plitke igre.** Svaka misija ima novu mapu i novu mehaniku; kasna igra ima jasne ciljeve
   i posle velikog čuda.
3. **Bogovi, čudovišta i heroji se vide u gradu.** Dolaze fizički, uz upozorenje unapred, sa
   jasnom kontrom i vidljivom posledicom. Nikad samo broj u meniju.
4. **Čitljiv interfejs.** Minimapa, rotacija kamere, overlay za svaku uslugu (voda, hram, pijaca,
   Gi...), prozor kuće koji kaže tačno šta joj fali za sledeći nivo, opisi na prelazu mišem,
   prečice. Najvažnije radnje na najviše 2 klika.
5. **Šetači kao u Zeusu** (vidi koncept), uz vidljivost: domet se prikazuje pri postavljanju
   zgrade, a overlay pokazuje ko je pokriven.
6. **Borba je laka i jasna**: zidovi, kule, kasarna, heroji. Bez polovičnog RTS-a.
7. **Čuda rastu pred igračem**, u fazama, a radnici vidljivo nose materijal.
8. **Ekonomija je čitljiva**: većina lanaca ima jedan korak prerade, a igra uvek kaže gde je
   usko grlo (koja roba fali i zašto).
9. **Izgled nije „mobilni"**: interfejs je miran, kao papir hanji i drvo, sa dancheong akcentima,
   bez sjajnih dugmića i iskačućih nagrada.
10. **Tutorijal je prva misija**, kroz ciljeve i savete savetnika, ne zid teksta.

## Interfejs (PC)

- Kontrole za miš i tastaturu: prečice, opisi kad se miš zadrži iznad elementa.
- Brzina igre: pauza (Space), 1×, 2×, 3× (tasteri 1, 2, 3).
- Interfejs čitljiv u rezoluciji 1920×1080 i većoj; podržati promenu veličine prozora.
- Religije (budizam, korejski šamanizam) prikazujemo s poštovanjem, po pravilima iz koncepta.

## Plan faza

1. Postavka, mapa, kamera i privremeni modeli (galerija zgrada)
2. Gradnja: postavljanje zgrada, putevi, rušenje, cene, prikaz dometa
3. Putna mreža i nosači: žitnica, skladište, nosači sa jigeom (šetači sa ciljem)
4. Kuće i usluge: nivoi 1–3, bunar, pijaca, seonangdang, lutajući šetači, jangseung blokada,
   overlay, prozor kuće
5. Snimanje i stabilnost: sejv sa verzijom, autosave sa 3 kopije, test scena „veliki grad"
6. Proizvodnja: pirinač, soja, so, glina, onggi; igra pokazuje gde roba fali
7. Fermentacija: jangdokdae i nivoi kvaliteta (u MVP-u Fresh i Ripe)
8. Gi mapa (pungsu) i njen overlay
9. Prvi događaj: dokkaebi (noćna krađa; kontra: Jangseung i ponuda na Seonangdang-u)
10. MVP scenario na test mapi, sa tutorijalom kroz ciljeve (nije misija iz kampanje)
11. Art pipeline: vlasnikovi modeli umesto privremenih, provera modela

Posle MVP-a (plan se dopunjava): bogovi, čudovišta i heroji, vojska i odbrana, čuda u fazama,
ostale misije, meni i podešavanja, lokalizacija.

## Git

Posle svake faze koja radi predloži commit sa kratkom porukom na srpskom.
Veliki izvorni fajlovi (.blend, .max, .psd) idu kroz Git LFS.
