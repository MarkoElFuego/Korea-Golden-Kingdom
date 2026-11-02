# Prompt za Fazu 1 (kopiraj u Claude Code)

Pročitaj `CLAUDE.md`, `docs/koncept.md`, `docs/art-bible.md` i `docs/analiza-fanova.md`.
Radimo **Fazu 1: postavka, mapa, kamera i privremeni modeli**. Pre koda mi ukratko napiši plan
(koje fajlove praviš i zašto), sačekaj moje „ok", pa kreni.

Podsetnik: odgovaraš na srpskom, a sve u igri (imena, tekstovi, kod) je na engleskom.

## Šta treba da uradiš

1. **Projekat.** Novi Godot 4.7.2 projekat u ovom folderu, Forward+, ime projekta
   „Korea: The Golden Kingdom". Folderi iz `CLAUDE.md`. `art_src/` i `art_templates/` dobijaju
   `.gdignore`. U `art/` stavi kratak `README.md` koji upućuje na `docs/art-bible.md`.
2. **MCP.** Proveri da Godot MCP radi: `get_godot_version`, pa `run_project` sa glavnom scenom i
   `get_debug_output`. Ako ne radi, reci mi tačno šta da proverim (Node.js, putanja do Godota).
3. **Testovi.** `tests/run_tests.gd` pokreće sve `tests/test_*.gd`, ispiše rezultat svakog testa
   i završi sa izlaznim kodom 1 ako bilo šta padne.
4. **Podaci** (`scripts/data/`):
   - `balance.gd`: `TILE_SIZE = 4.0`, veličina mape 64×64, tikovi u sekundi, kalendar, početna
     riznica, ostali brojevi koje ova faza koristi.
   - `terrain.gd`: tipovi terena iz koncepta i gde se šta sme graditi.
   - `buildings.gd`: svih 15 MVP zgrada iz koncepta: id (snake_case), English name, Korean term,
     kategorija, footprint, visinska klasa, cena, radnici. Ostale zgrade još ne.
   - `data/text/en.csv`: ključevi i engleski tekstovi za imena zgrada i terena.
5. **Simulacija bez grafike** (`scripts/sim/`):
   - `grid.gd`: polje ↔ svet (metri), zauzetost polja, provera da li footprint staje
     (u granicama mape, ne preklapa se, dozvoljen teren).
   - `map_generator.gd`: mapa iz seed-a po idealu pungsu-a: planine na severu, reka na jugu teče
     sa zapada i uliva se u more u jugoistočnom uglu (uz more Shore), šumoviti grebeni na istoku i
     zapadu, plodna ravnica u sredini, malo Rocky Hill.
   - `sim_clock.gd`: fiksni tik, pauza, 1×/2×/3×, kalendar (dan, godišnje doba, godina).
     Još ništa drugo ne simulira.
6. **Prikaz** (`scripts/view/`, `scenes/main.tscn`):
   - teren preko MultiMesh-a po tipu terena, privremeni materijali iz palete u Art Bible-u;
   - kamera: ortografska izometrija, Q/E rotacija za 90°, zum točkićem (sa granicama), WASD i
     ivica ekrana za pomeranje, srednji taster miša za vuču;
   - gornja traka: datum (dan, godišnje doba, godina), brzina igre (Space, 1, 2, 3), riznica.
     Svi tekstovi preko `tr()`.
7. **Privremeni modeli.** `scripts/view/placeholder_factory.gd` pravi model zgrade iz podataka,
   tačno po Art Bible-u (footprint, visinska klasa, pivot, `door` marker, boja po kategoriji,
   krov kao prizma ili slamnata kupola) i čoveka (kapsula 1,7 m). Ako postoji
   `art/buildings/<id>.glb`, koristi njega umesto privremenog.
8. **Galerija.** `scenes/placeholder_gallery.tscn` postavlja svih 15 MVP zgrada na grid, sa
   engleskim imenom iznad svake (Label3D) i jednim čovekom pored, da vidim razmere. Kuću prikaži
   u sva tri MVP nivoa.
9. **Testovi za ovu fazu:** konverzije grid ↔ svet; footprint (preklapanje, granice, zabranjen
   teren); isti seed daje istu mapu; reka postoji i stiže od zapadne ivice do mora;
   postoji Shore; planine su
   na severu; sat broji dane i godišnja doba tačno i pri 3×; svaka MVP zgrada ima sve podatke i
   ključ prevoda.
10. Pokreni testove i igru preko MCP-a, pročitaj greške i popravi ih.

## Šta još ne radiš

Gradnju, puteve, šetače, ekonomiju, sejv. To su sledeće faze.

## Na kraju mi napiši

- šta je urađeno, jednostavno, bez žargona;
- šta da proverim posle F5 u `main.tscn` i u `placeholder_gallery.tscn`;
- šta nisi mogao sam da proveriš;
- predlog commit poruke na srpskom.
