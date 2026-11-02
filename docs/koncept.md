# Korea: The Golden Kingdom — lore i koncept

Nov 1, 2026 · @Markos Stojkovic

Lokalni folder: (F:\PROJEKTI GAME\KoreaGoldenKingdom)

REPO: https://github.com/MarkoElFuego/Korea-Golden-Kingdom

Proširena verzija sa dijagramima: https://claude.ai/artifact/XSumq2K7B8TnuFqjeiPYyF

Tekstovi igre i lore su na engleskom; komunikacija sa agentom je na srpskom.
Pravila su ovde opisana na srpskom, a sve što igrač vidi (imena, opisi, misije) je na engleskom.
Brojevi označeni kao *predlog* su početni balans: žive u `scripts/data/` i menjaju se testiranjem.

## Ideja

Izometrijski city builder u duhu Zeus: Master of Olympus. Igrač gradi Seorabeol, prestonicu
Sile, „zlatnog kraljevstva" Koreje, od sela do najvećeg grada istočne Azije. Uz ekonomiju i
šetače, tu su bogovi, duhovi i čudovišta korejskog folklora.

Šta igru čini drugačijom:

1. Prvi Zeus-stil city builder smešten u Koreju.
2. **Pungsu:** položaj četvrti u odnosu na planine i reke određuje **Gi**, energiju mesta.
3. **Jangdokdae:** fermentacija pretvara skladište u proizvodnju; hrana vremenom postaje vrednija.
4. **Folklor kao sistem:** dokkaebi, gumiho i Bulgasari su pretnje, a neki postaju saveznici.

Ton: toplo, svečano, šareno, kao korejsko narodno slikarstvo (minhwa) sa tigrom i svrakom.
Namerno suprotno mračnim survival city builderima.

## Lore (in-game, English)

Ovo su tekstovi kakvi idu u igru. Menjati samo uz dogovor sa vlasnikom.

**Opening (intro screen):**

> Before there were kingdoms, Hwanung came down from Heaven to the mountains of the East.
> With him walked three thousand followers and three great lords: the Lord of Wind,
> the Master of Rain and the Master of Clouds. Where they passed, the rice remembered how to grow.
>
> A bear and a tiger asked to become human. Both were told to wait a hundred days in a dark cave.
> The tiger left. The bear stayed, and on the twenty-first day she walked out a woman.
> Her son, Dangun, built the first kingdom.
>
> Ages later, in a valley between the mountains and the Eastern Sea, a small town called Saro
> begins to dream of gold. Build it well, and the old lords may yet return.

**The world.** The game is set in Silla, the Golden Kingdom, in a mythic age between the 7th and
9th centuries. Its capital, Seorabeol, was also called Geumseong, the City of Gold. Kings wear
crowns of gold leaf, monks raise pagodas of wood and granite, and every mountain, river and
kitchen has a spirit that expects to be remembered.

**Gi.** Every place has Gi, the breath of the land. It flows down from the mountains and gathers
where water lies before it. A city built in harmony with Gi prospers; a city that cuts its
guardian ridges for stone grows restless, and the night grows crowded.

**Closing line (victory screen):** *And in every courtyard, the jars keep ripening.*

## Svet i hronologija

- **Istorijski okvir:** Sila je jedno od tri korejska kraljevstva. U savezu sa Tang Kinom
  ujedinjuje poluostrvo (668), a zatim se okreće protiv samog Tanga. Prestonica je za vreme
  kralja Munmua (661–681) prerađena na mrežu po uzoru na Čang'an.
- **Susedi u igri:** Baekje i Goguryeo (rivalska kraljevstva), Gaya (izvor gvožđa), Tang
  (saveznik i pretnja), Sea Raiders (pirati sa mora; ne imenujemo stvarne narode kao neprijatelje).
  Goguryeo prikazujemo neutralno, jer je predmet savremenog istorijskog spora.
- **Namerne slobode:** neki elementi su mlađi od Sile: Bulgasari (legenda s kraja 14. veka),
  haetae statue (Joseon), princeza Bari (šamanski epovi zapisani kasnije). Kimči u igri je
  **belo soljeno povrće u ćupovima**, bez crvene paprike (ona stiže krajem 16. veka) i bez
  kineskog kupusa.
- **Vizuelni identitet:** dancheong (obojeni šabloni ispod streha, samo na hramovima i palati),
  giwa crep i blago zakrivljeni krovovi, redovi onggi ćupova, jangseung totemi, granitne pagode,
  zlatne krune.
- **Religija:** budizam i šamanizam su žive religije. Budizam u igri nema „gnev"; daje samo mir,
  kulturu i uslove za napredak. Šamanski obredi su korisna usluga, ne ismevanje.

## Glavna petlja

Choose a site (Gi) → build roads and houses → produce and ferment → walkers deliver goods and
services → houses evolve → taxes pay for temples and wonders → expand. Pretnje (dokkaebi,
gumiho, Bulgasari, invazije) mogu da prekinu krug na bilo kom koraku.

## Vreme i valuta

- Fiksni tik: 10 tikova u sekundi na 1× (*predlog*). Pauza, 1×, 2×, 3×.
- Kalendar: 1 dan = 1 sekunda na 1×; godišnje doba = 30 dana; godina = 4 godišnja doba
  (Spring, Summer, Autumn, Winter). *predlog*
- Valuta: **Silver**. Početna riznica na MVP mapi: 1.500 Silver (*predlog*).
- Porez: u MVP-u kuće same plaćaju mali porez svakog meseca (privremeno, dok ne dođe Tax Office).

## Mapa i teren

- Kvadratni grid, polje 4 × 4 m. MVP mapa: 64 × 64 polja (*predlog*).
- Tereni: **Grass**, **Fertile Plain** (pirinač, soja, povrće), **River**, **Sea**, **Shore**, **Forest**,
  **Mountain** (ne gradi se, osim rudnika i Sansingak-a), **Rocky Hill** (kamenolom, glina).
- MVP mapa prati ideal pungsu-a (baesan-imsu): planine na severu, reka na jugu teče sa zapada i
  uliva se u more u jugoistočnom uglu (uz more je Shore, za Salt Pans), šumoviti grebeni na
  istoku (Blue Dragon) i zapadu (White Tiger), plodna ravnica u sredini.

## Stanovanje

Obične kuće su 2×2 i rastu u mestu kroz pet nivoa. Svaki nivo zadržava stare potrebe i dodaje
nove. Kuća napreduje kad su sve potrebe pokrivene, a nazaduje kad pokrivenost padne.
Hrana stiže preko pijace, pa je **Market** potreban od prvog nivoa.

| Nivo | Name (EN) | Potrebe za taj nivo | Stanovnika (*predlog*) |
| --- | --- | --- | --- |
| 1 | Choga Hut | put, voda (Well), hrana (Market) | 6 |
| 2 | Choga House | + dve vrste hrane, + Seonangdang | 12 |
| 3 | Giwa House | + Hemp Cloth, + Jang, + Physician | 20 |
| 4 | Hanok | + Kimchi, + Onggi Jars, + Music Pavilion, + Buddhist Temple | 30 |
| 5 | Grand Hanok | + Silk, + Ssireum Ring | 40 |

Plemićke kuće su poseban put, kao elitne kuće u Zeusu. U Sili je rang kostiju (golpum) zakonom
određivao veličinu kuće, pa plemićki dvor traži plac 3×3 i Palace u gradu.

| Nivo | Name (EN) | Potrebe | Stanovnika (*predlog*) |
| --- | --- | --- | --- |
| 1 | Jingol Manor | hrana, voda, Jang, Silk, Gold Jewelry, Buddhist Temple, Hwarang Training Ground | 10 |
| 2 | Golden Manor | + Ginseng Tonic, + Gukhak, + visok Gi | 16 |

**MVP pojednostavljenje (3 nivoa):** nivo 1 = voda + Rice sa pijace; nivo 2 = + Seonangdang;
nivo 3 = + Jang + Onggi Jars.

Radna snaga: zajednički fond grada; svaka kuća daje radnike = 40% stanovnika (*predlog*).
Zgrade bez dovoljno radnika rade sporije, a prozor zgrade to kaže.

**Flavor lines (EN, prikazuju se u prozoru kuće):**

| House | Line |
| --- | --- |
| Choga Hut | Straw roof, mud walls, and a jar of rice by the door. |
| Choga House | Two rooms, one fire, and a little shrine for luck. |
| Giwa House | The first tiles on the street. The neighbors noticed. |
| Hanok | A courtyard, a wooden floor, and jars older than the children. |
| Grand Hanok | Silk on the line, music in the evening, wrestling on market days. |
| Jingol Manor | The law says how big a house may be. True Bone wrote the law. |
| Golden Manor | Gold on the crown, gold on the eaves, and a view of the palace. |

## Šetači i distribucija (model iz Zeusa)

Roba putuje fizički. Dva tipa šetača:

- **Roaming walkers** (lutajući): prodavci sa pijace i šetači službi (hram, lekar, stražar,
  muzika). Kreću iz zgrade, idu putem, na raskrsnicama biraju pravac, i služe svaku zgradu
  pored koje prođu (domet 2 polja od puta, *predlog*). Posle 30 polja puta (*predlog*) vraćaju se.
- **Destination walkers** (sa ciljem): nosači i kupci. Idu najkraćim putem do cilja.
- **Jangseung** je blokada: lutajuće šetače okreće nazad, a šetače sa ciljem propušta.
- Nema šetača koji traže radnike (kao u Zeusu): radnici dolaze iz zajedničkog fonda.

Tok robe:

1. Proizvodna zgrada puni mali magacin.
2. **Carrier** (nosač sa jigeom, drvenim ramom na leđima) nosi robu do najbližeg skladišta koje
   je prima: **Granary** (hrana), **Storehouse** (ostalo), **Jangdokdae** (fermentacija).
3. Pijaca šalje **Buyer**-a u skladište po robu koja joj fali.
4. **Vendor** sa pijace obilazi ulice; svaka kuća pored koje prođe dobija robu dok ima zaliha.
5. Kuća pamti pokrivenost svake usluge; pokrivenost traje 30 dana (*predlog*), pa opada.

Vidljivost (obavezno, iz analize fanova): pri postavljanju zgrade vidi se domet; overlay za svaku
uslugu; prozor kuće kaže šta joj fali i koji šetač nije prošao.

## Roba i proizvodni lanci

| Izvor | Prerada | Roba (EN) | Ide u |
| --- | --- | --- | --- |
| Rice Paddy | — (Granary) | Rice | sve kuće |
| Soybean Field + Salt Pans | Jangdokdae | Jang | kuće 3+ |
| Vegetable Garden + Salt Pans | Jangdokdae | Kimchi | kuće 4+, zalihe za zimu |
| Fishing Hut + Salt Pans | Jangdokdae | Jeotgal | kuće, izvoz |
| Clay Pit (+ Wood kao gorivo) | Onggi Kiln / Tile Kiln | Onggi Jars / Roof Tiles | Jangdokdae, kuće 4+, gradnja |
| Hemp Field / Mulberry Farm | Weaver | Hemp Cloth / Silk | kuće 3+ / 5 |
| Iron Mine | Smelter → Smithy | Tools, Weapons | radionice, vojska |
| Gold Sluice | Goldsmith | Gold Jewelry | plemići, čuda |
| Ginseng Field | Herbalist | Ginseng Tonic | plemići, izvoz |
| Woodcutter, Quarry | — | Wood, Granite | gradnja, čuda |
| Paper Mulberry | Hanji Workshop | Hanji Paper | Gukhak, hramovi |

So je jedina sirovina koja ulazi u više lanaca, pa je Salt Pans rano usko grlo.

## Fermentacija: Jangdokdae

Dvorište sa onggi ćupovima u kome hrana zri: što duže stoji, to je vrednija. Jedina zgrada koja
je i skladište i proizvodnja.

| Proizvod | Ulaz | Zrenje do sledećeg nivoa (*predlog*) | Ide u |
| --- | --- | --- | --- |
| Kimchi | Vegetables + Salt | 1 godišnje doba | kuće 4+, zima |
| Jang | Soybeans + Salt | 2 godišnja doba | kuće 3+ |
| Jeotgal | Fish + Salt | 1 godišnje doba | kuće, izvoz |

- Nivoi kvaliteta: **Fresh → Ripe → Aged**. Viši nivo zadovoljava bolje kuće i vredi više.
- Kapacitet: svaki ćup (Onggi Jars) je jedno mesto; više ćupova = veći kapacitet.
- Dilema: prodati odmah ili čekati. Leti bez senke (*predlog*: bez drveća u blizini) postoji
  rizik kvarenja; zimi roba ne propada.
- **Kimjang Festival:** u kasnu jesen ceo grad pravi kimči; bonus sreće i puni zalihe za zimu.

## Pungsu i Gi

Svako polje ima Gi (0–100). Gi teče niz glavnu planinu (baesan) i skuplja se u dolini ispred
koje je voda (imsu), zaštićenoj grebenima: **Blue Dragon** na istoku, **White Tiger** na zapadu.
Najbolje mesto je **Myeongdang**.

- Gi se računa iz terena, pa ga menjaju zgrade: rudnik ili kamenolom u grebenu smanjuje Gi okolnih
  četvrti; šuma na grebenu, Buddhist Temple, Royal Tumuli i Seonangdang ga podižu. Dim i buka
  radionica lokalno spuštaju Gi.
- Visok Gi: kuće brže napreduju, hramovi daju više naklonosti, Imugi može da postane zmaj.
- Nizak Gi: kuće stagniraju, u napuštenim četvrtima se javljaju dokkaebi i gwisin.
- Dilema: najbolji granit, gvožđe i zlato su u planinama.
- Overlay Gi je obavezan; plemići i palata traže visok Gi.

## Gradnja (odluke iz Faze 2)

- Rušenje ne vraća Silver (kao u Zeusu).
- Zgrada ne mora da dodiruje put da bi se postavila, ali dobija vidljivo upozorenje
  „No road access", jer bez puta neće raditi kad stignu šetači.
- Woodcutter traži šumu najviše 2 polja od zgrade.
- Put se vuče mišem u obliku slova L; polja na kojima put ne može da ide se preskaču, a plaćaju
  se samo izgrađena polja.
- Nova Common House je prazan plac (Vacant Lot); doseljenici dolaze u Fazi 4.
- Jangseung se gradi samo na postojećem putu i polje ostaje put. Lutajući šetači (Vendor,
  šetači službi) se kod njega vraćaju; šetači sa ciljem (Carrier, Buyer, doseljenici) prolaze.
  Radnici ne putuju na posao (zajednički fond), pa blokada ne može da ostavi zgradu bez radnika.
  Prikaz dometa pri gradnji već staje kod Jangseung-a. Rušenje prvo skida Jangseung, a put
  ostaje; drugo rušenje skida i put.

## Roba i nosači (odluke iz Faze 3)

- Privremena proizvodnja do Faze 6: Rice Paddy (Rice, 1 tovar / 8 dana), Woodcutter i Clay Pit
  (Wood, Clay, 1 tovar / 5 dana), stalnim tempom, bez radnika. *predlog*
- Proizvodna zgrada čuva najviše 2 tovara; kad je puna, proizvodnja staje dok nosač ne uzme tovar.
- Granary prima samo hranu, 32 tovara. Storehouse ima 8 mesta po 4 tovara, jedna vrsta robe po
  mestu (kao u Zeusu). *predlog*
- Svaka proizvodna zgrada ima jednog nosača; on nosi jedan tovar do najbližeg skladišta (po putu)
  koje prima tu robu i ima mesta, pa se vraća. Ide 1,5 polja u sekundi pri 1×. *predlog*
- Roba se ne gubi: ako nestane skladište ili put, nosač traži drugo skladište ili vraća tovar
  kući. Gubi se samo roba koja je bila u srušenoj zgradi.
- Soybean Field i Salt Pans ne proizvode do Faze 7 (Jangdokdae); prozor zgrade to kaže.
- Prozor zgrade (klik na zgradu) pokazuje zalihu i jednu rečenicu o stanju ili o tome šta fali.

## Zgrade

Footprint je u poljima (4 m). Cena u Silver i radnici su *predlog* za MVP zgrade; ostalo se
balansira kasnije. „Misija" = gde se zgrada otključava u kampanji.

| Zgrada (EN) | Korean term | Kategorija | Footprint | Cena | Radnici | Šta radi | Misija |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Road** | gil | Infrastructure | 1×1 | 2 | 0 | kretanje šetača i nosača | 1 |
| **Well** | umul | Infrastructure | 1×1 | 15 | 0 | voda u radijusu 3 polja | 1 |
| **Stone Bridge** | — | Infrastructure | preko reke | — | 0 | prelaz preko reke | 2 |
| **Irrigation Canal** | — | Infrastructure | 1×1 | — | 0 | voda za pirinčana polja | 2 |
| **Jangseung** | jangseung | Infrastructure | 1×1 | 10 | 0 | blokada za lutajuće šetače; tera zle duhove | 2 |
| **Common House** (5 nivoa) | minga | Housing | 2×2 | 10 | 0 | obične kuće | 1 |
| **Noble Manor** (2 nivoa) | — | Housing | 3×3 | — | 0 | plemićke kuće | 7 |
| **Rice Paddy** | non | Food | 3×3 | 40 | 6 | Rice; traži Fertile Plain ili kanal | 1 |
| **Barley & Millet Field** | bat | Food | 3×3 | — | — | hrana na suvom terenu | 1 |
| **Vegetable Garden** | — | Food | 2×2 | — | — | Vegetables | 3 |
| **Soybean Field** | — | Food | 3×3 | 40 | 6 | Soybeans | 3 |
| **Fishing Hut** | — | Food | 2×2 | — | — | Fish; na obali | 3 |
| **Salt Pans** | yeomjeon | Food | 3×3 | 40 | 6 | Salt; na obali | 3 |
| **Granary** | gogan | Storage | 3×3 | 60 | 8 | čuva hranu | 1 |
| **Storehouse** | changgo | Storage | 3×3 | 50 | 6 | čuva ostalu robu | 2 |
| **Jangdokdae** | jangdokdae | Fermentation | 2×2 | 50 | 4 | Jang, Kimchi, Jeotgal; kvalitet raste | 3 |
| **Woodcutter** | — | Materials | 2×2 | 30 | 4 | Wood; pored šume | 1 |
| **Quarry** | — | Materials | 2×2 | — | — | Granite; Rocky Hill | 2 |
| **Clay Pit** | — | Materials | 2×2 | 30 | 4 | Clay | 2 |
| **Onggi Kiln** | onggi-gama | Crafts | 3×2 | 50 | 6 | Onggi Jars | 3 |
| **Tile Kiln** | giwa-gama | Crafts | 2×2 | — | — | Roof Tiles | 4 |
| **Hemp Field** | — | Textiles | 3×3 | — | — | Hemp | 2 |
| **Mulberry Farm** | — | Textiles | 3×3 | — | — | Silk Cocoons | 6 |
| **Weaver** | — | Textiles | 2×2 | — | — | Hemp Cloth, Silk | 2 |
| **Hanji Workshop** | — | Crafts | 2×2 | — | — | Hanji Paper | 7 |
| **Iron Mine** | — | Metal | 2×2 | — | — | Iron Ore; planina | 4 |
| **Smelter** | — | Metal | 2×2 | — | — | Iron | 4 |
| **Smithy** | — | Metal | 2×2 | — | — | Tools, Weapons | 4 |
| **Gold Sluice** | — | Metal | 2×2 | — | — | Gold; na reci | 7 |
| **Goldsmith** | — | Luxury | 2×2 | — | — | Gold Jewelry | 7 |
| **Ginseng Field** | — | Luxury | 2×2 | — | — | Ginseng; raste više godina; uz šumu | 6 |
| **Herbalist** | — | Health | 2×2 | — | — | lekovi, Ginseng Tonic | 5 |
| **Market** | sijang | Distribution | 3×3 | 40 | 6 | Buyer i Vendor raznose robu | 1 |
| **Trading Port** | — | Distribution | 3×3 | — | — | trgovina sa Gayom i Tangom | 3 |
| **Altar of Heaven** | — | Religion | 3×3 | — | — | Three Lords of Heaven | 1 |
| **Seonangdang** | seonangdang | Religion | 1×1 | 25 | 2 | seoski oltar; osnovna duhovna usluga | 2 |
| **Yongwangdang** | yongwangdang | Religion | 2×2 | — | — | svetilište Dragon King; na obali | 3 |
| **Buddhist Temple** | sachal | Religion | 4×4 | — | — | mir, kultura, uslov za više nivoe | 4 |
| **Sansingak** | sansingak | Religion | 2×2 | — | — | svetilište Mountain Spirit; uz planinu | 4 |
| **Shaman's House** | mudang | Religion | 2×2 | — | — | obredi protiv duhova i bolesti | 5 |
| **Physician** | — | Health | 2×2 | — | — | smanjuje bolesti | 3 |
| **Music Pavilion** | — | Culture | 3×3 | — | — | gayageum i ples | 4 |
| **Ssireum Ring** | — | Culture | 3×3 | — | — | rvanje; mami dokkaebije na dvoboj | 5 |
| **Gukhak** | gukhak | Education | 4×4 | — | — | akademija za plemiće | 7 |
| **Watch Post** | — | Safety | 1×1 | — | — | kriminal i požari | 2 |
| **Haetae Statue** | haetae | Safety | 1×1 | — | — | manji rizik od požara u radijusu | 4 |
| **Barracks** | — | Defense | 3×3 | — | — | vojnici | 4 |
| **Wall** / **Tower** | seong | Defense | 1×1 / 2×2 | — | — | odbrana | 4 |
| **Hwarang Training Ground** | — | Defense | 4×4 | — | — | elitni ratnici; uslov za plemiće | 6 |
| **Palace** | gung | Administration | 5×5 | — | — | riznica; uslov za plemiće | 2 |
| **Tax Office** | — | Administration | 2×2 | — | — | poreznik skuplja porez | 2 |
| **Hall of Heroes** | — | Administration | 3×3 | — | — | poziva heroje kad su uslovi ispunjeni | 4 |

**MVP zgrade (15):** Road, Common House (3 nivoa), Well, Rice Paddy, Granary, Storehouse,
Market, Seonangdang, Jangseung, Woodcutter, Clay Pit, Onggi Kiln, Soybean Field, Salt Pans,
Jangdokdae.

## Bogovi, duhovi i svetilišta

Kao u Zeusu: svetilišta, blagoslovi i gnev. Naklonost raste od svetilišta, prinosa i festivala.
Bogovi i duhovi se pojavljuju u gradu (vidljivi, sa upozorenjem unapred).

| God / spirit (EN) | Domen | Svetilište | Blessing | Wrath | Line (EN) |
| --- | --- | --- | --- | --- | --- |
| The Three Lords of Heaven (Pungbaek, Usa, Unsa) | wind, rain, clouds | Altar of Heaven | rich rice harvest | drought or flood | Wind to winnow, rain to plant, clouds to shade the harvest. |
| Sansin, the Mountain Spirit | mountains, tigers, ginseng | Sansingak | faster ginseng, safe mines | tigers, rockfalls | The mountain has an old man and a tiger. Feed one, and the other stays fed. |
| Yongwang, the Dragon King | sea, fishing | Yongwangdang | rich catch, safe trade | storms, lost ships | The sea gives fish to those who remember to bow. |
| Samsin Halmeoni | birth, family | Buddhist Temple shrine | more settlers | settlers stop coming | Every child in the city has a grandmother no one can see. |
| Gashin (Seongju, Jowangsin, Teoju) | house, hearth, land | sami se javljaju u kućama 3+ | fewer fires, slower decay | house fires | Every room has a spirit. Every spirit has an opinion. |

Budizam nema gnev: hramovi daju mir, kulturu i uslov za više nivoe kuća i čuda.

## Čudovišta i pretnje

| Creature (EN) | Šta radi | Kontra | Line (EN) |
| --- | --- | --- | --- |
| Dokkaebi | noću krade robu i pravi nered | ponudi memilmuk (buckwheat jelly) ili ih pobedi u Ssireum Ring; zadovoljni ostavljaju srebro | They steal your salt at night, and leave silver if you share your buckwheat jelly. |
| Gumiho | lisica sa devet repova; odvodi stanovnike iz četvrti | Watch Post i obred u Shaman's House | A beautiful stranger walks the night market. Count her tails. |
| Bulgasari | jede gvožđe: prazni kovačnice i oružarnice | ne može se ubiti; mami se gvožđem van grada | It cannot be killed. It can only be fed, and led away. |
| Imugi | zmija u reci; izaziva poplave | visok Gi i zadovoljan Yongwang: postaje zmaj-zaštitnik | A serpent that wants to be a dragon. The city decides which. |
| Horangi (Tiger) | napada drvoseče i lovce u planini | zadovoljan Sansin, Watch Post | The tiger keeps the mountain's accounts. |
| Gwisin | nemirni duhovi posle rata ili bolesti; četvrt postaje ukleta | obred u Shaman's House, Princess Bari | Those who die without rites do not leave the street. |
| Invasions | Baekje, Goguryeo, Tang, Sea Raiders | Wall, Tower, Barracks, Hwarang, heroji | — |

## Heroji

Dolaze u Hall of Heroes kad grad ispuni uslove, kao u Zeusu.

| Hero (EN) | Uslov | Šta radi | Line (EN) |
| --- | --- | --- | --- |
| Kim Yu-sin | Barracks, Wall, dovoljno Weapons | pobeđuje invazije i Bulgasarija | A general who never lost the thread of a war. |
| Cheoyong | Yongwangdang, Music Pavilion | tera bolest i gwisin plesom | The Dragon King's son, who danced the plague out of the house. |
| Princess Bari | Shaman's House, Herbalist | vodi duše; čisti uklete četvrti | Abandoned at birth, she walked to the underworld and back for the father who left her. |

## Čuda (Great Works)

Grade se u fazama, vidljivo; radnici nose materijal. Svako daje trajni efekat.

| Wonder (EN) | Faze | Footprint | Glavni resursi | Efekat | Misija | Line (EN) |
| --- | --- | --- | --- | --- | --- | --- |
| Royal Tumuli | 3 | 4×4 | earth, Granite, Gold | mir predaka, viši Gi u četvrti | 3 | The old kings sleep under hills of grass, and the city grows around them. |
| Cheomseongdae | 2 | 3×3 | Granite | najava suše i oluje, bolja žetva | 4 | A bottle of stone that holds the sky. |
| Bulguksa | 4 | 8×6 | Wood, Roof Tiles, Granite, Hanji Paper | kultura, brži napredak kuća | 7 | A Buddha land built on earth, one stair at a time. |
| Wolji Palace | 3 | 8×8 | Wood, Roof Tiles, Granite | zabava plemića, diplomatija sa Tangom | 7 | A palace that watches itself in a pond. |
| Seokguram | 3 | 5×5 | Granite | zaštita istočne obale | 8 | Carved in the mountain, facing the sunrise and the sea. |
| Hwangnyongsa Nine-Story Pagoda | 9 | 6×6 | Wood, Roof Tiles, Gold, Iron | svaki sprat štiti od jedne vrste pretnje | 8 | Nine stories of wood, and on each one a prayer against a different fear. |

Hwangnyongsa je bila visoka 68–80 m (izvori se razlikuju); podigao ju je 645. majstor Abiji iz
Baekjea, a Mongoli su je spalili 1238. U igri spratovi štite od vrsta pretnji (sea, fire,
plague, spirits...), ne od konkretnih naroda.

## Kampanja: The Golden Capital

| # | Mission (EN) | Novo u igri | Pretnja | Cilj | Briefing (EN) |
| --- | --- | --- | --- | --- | --- |
| 1 | Son of Heaven | putevi, kuće, bunar, pirinač, pijaca, Altar of Heaven | blaga suša | 200 stanovnika | Three lords came down with the rain. Give them a town worth visiting. |
| 2 | Saro by the River | kanali, Seonangdang, Jangseung, Palace, Tax Office | dokkaebi šale | kuće nivoa 2 | The river is generous. The goblins are curious. |
| 3 | The Eastern Sea | so, riba, soja, Jangdokdae, Trading Port, Physician | Imugi i poplave | trgovina sa Gayom, Royal Tumuli | Salt from the sea, patience in a jar. |
| 4 | Iron of Gaya | rudnik, kovač, zid, kasarna, Buddhist Temple, Tile Kiln | Bulgasari, napad Baekjea | Cheomseongdae, heroj Kim Yu-sin | Iron makes plows and swords. Something in the hills is hungry for both. |
| 5 | The Long Winter | Herbalist, Shaman's House, Ssireum Ring, Kimjang | gumiho, bolest | preživeti zimu, heroj Cheoyong | Fill the jars before the snow. Count the lanterns after dark. |
| 6 | Three Kingdoms | svila, ginseng, Hwarang, trgovina sa Tangom | invazije, gwisin | savez ili rat, heroina Bari | Three kingdoms, one peninsula. Not all of them can stay. |
| 7 | The Golden City | plemići, zlato, Hanji, Gukhak | požari, intrige na dvoru | Bulguksa i Wolji Palace | Gold on every crown. Keep the fires away from the eaves. |
| 8 | Nine Stories | sve zgrade | velika invazija sa mora | Hwangnyongsa i Seokguram | Raise nine stories against every fear, and look to the sea. |

**Kraj:** kralj Munmu je po predanju želeo da posle smrti postane morski zmaj i čuva kraljevstvo.
Ako je Gi grada visok, Imugi u finalu postaje taj zmaj i odlučuje poslednju bitku.
Ending line (EN): *The king became the sea, and the sea kept the kingdom.*

## MVP

Jedna mapa doline sa rekom koja se uliva u more, 15 MVP zgrada, i sistemi: grid i gradnja,
putevi i šetači (model iz Zeusa), skladišta i ekonomija, evolucija kuća (3 nivoa), jednostavna
Gi mapa, fermentacija sa dva nivoa (Fresh, Ripe), jedan događaj (dokkaebi), snimanje i
učitavanje. Cilj: proveriti da li je zabavno gledati grad kako diše.

MVP događaj: dokkaebi noću kradu robu iz skladišta u četvrtima sa niskim Gi. Jangseung u
blizini smanjuje šansu; ponuda na Seonangdang-u (Silver) ih umiri, pa ponekad ostave srebro.

MVP proizvodnja: Onggi Kiln troši Clay i Wood (gorivo). Soybeans i Salt idu pravo u Jangdokdae.
Rice ide u Granary, a Wood, Clay i Onggi Jars u Storehouse.

## Otvorena pitanja

- [ ] Provera žiga i domena za ime igre pre izlaska.
- [ ] Tačan balans (cene, radnici, domet, potrebe) posle prvog igranja MVP-a.
- [ ] Da li na kraju mape kampanje dolazi i sandbox sa editorom mapa (fanovi to cene).
