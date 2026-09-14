# ELTE Fordítóprogramok — Docker fejlesztői környezet

*[English version](README.md)*

Minden, ami a **Fordítóprogramok** tárgyhoz kell — `bisonc++`, `flexc++` és
pontosan az a `g++`, ami a kari szerveren fut — egyetlen konténerbe csomagolva,
ami macOS-en, Windowson és Linuxon egyformán elindul. Nem kell csomagokat
vadászni, nincs „a pandorán megy, a gépemen nem”, és utána nincs mit
eltávolítani.

```console
$ git clone <ez-a-repo> && cd CompilersDevEnv
$ ./dev.sh test
g++ (Debian 6.3.0-18+deb9u1) 6.3.0 20170516
bisonc++ V5.02.00
flexc++ V2.05.00
example: OK
```

## Verziók

Az egésznek pontosan az a lényege, hogy ezek megegyeznek a `pandora`
verzióival. Rögzítve vannak, így meg is maradnak egyformának:

| | pandora | ez a környezet |
|---|---|---|
| `gcc` / `g++` | 6.3.0 (Debian 6.3.0-18+deb9u1) | ugyanaz |
| `bisonc++` | V5.02.00 | ugyanaz |
| `flexc++` | V2.05.00 | ugyanaz |
| Debian | 9 (stretch) | 9-es eszközlánc Debian 12 alapon — lásd [Hogyan működik](#hogyan-működik) |
| Architektúra | i686 (32 bites) | alapból x86-64, `-m32`-vel 32 bites, a `./dev.sh verify` i686 |

## Mire van szükséged

Dockerre, és semmi másra.

| Rendszer | Telepítés |
|---|---|
| **macOS** | [Docker Desktop](https://docs.docker.com/desktop/install/mac-install/) — Apple Silicon gépen olvasd el az [Apple Silicon](#apple-silicon-és-más-arm-gépek) részt is |
| **Windows** | [Docker Desktop](https://docs.docker.com/desktop/install/windows-install/) (a WSL 2 backendet kapcsold be, ha kérdezi) |
| **Linux** | [Docker Engine](https://docs.docker.com/engine/install/), majd `sudo usermod -aG docker $USER`, és jelentkezz ki-be |

A beállításaidat bármikor ellenőrizheted:

```console
$ ./dev.sh doctor
```

## Mindennapi használat

macOS-en és Linuxon a `./dev.sh`, Windows PowerShellben a `.\dev.ps1`
parancsot használd. Ugyanazokat a parancsokat ismerik, és ugyanazt csinálják.

| Parancs | Mit csinál |
|---|---|
| `./dev.sh` | Shellt nyit a konténerben, a `workspace/` mappádban |
| `./dev.sh test` | Lefordítja és teszteli a mellékelt példát — érdemes ezzel kezdeni |
| `./dev.sh new hazi1` | Létrehozza a `workspace/hazi1/` mappát a példa vázából |
| `./dev.sh run make` | Lefuttat egy parancsot a konténerben, majd kilép |
| `./dev.sh verify` | Újrafordít igazi 32 bites Debian 9-en — beadás előtt ezt futtasd |
| `./dev.sh build` | Újraépíti az image-et (csak akkor kell, ha a Dockerfile-t módosítod) |
| `./dev.sh doctor` | Ellenőrzi a Dockert, az emulációt és az eszközláncot |
| `./dev.sh clean` | Törli a projekt által létrehozott image-eket |

Az első `./dev.sh` felépíti az image-et, ez pár percig tart. Utána minden
indítás nagyjából egy másodperc.

Hasznos részlet: a `./dev.sh` tudja, hol vagy. Ha a `workspace/hazi1/`
mappából indítod, a konténerben a `/workspace/hazi1` mappában landolsz.

## Hová kerül a kódod

A repó `workspace/` mappája a konténerben a `/workspace` útvonalon érhető el.
Ez *ugyanaz* a mappa, nem másolat — a fájlokat a saját gépeden szerkeszted a
megszokott szerkesztőddel, a konténerben fordítod, és mindkét oldal azonnal
látja a változásokat.

```
CompilersDevEnv/
├── dev.sh, dev.ps1          ← ezeket futtatod
├── workspace/               ← /workspace néven becsatolva; ide kerül a kódod
│   ├── examples/calc/       ← működő scanner + parser, ezzel kezdd
│   └── hazi1/               ← amit te hozol létre
├── docker/                  ← az image-ek leírása
└── .devcontainer/           ← IDE-integráció
```

A `workspace/` mappán kívül a félév során semmihez nem kell hozzányúlnod.

## Scanner és parser írása

Nyisd meg a `workspace/examples/calc/` mappát — ez egy teljes, négy
alapműveletet ismerő kalkulátor, összesen száz sor körül, és ez a legrövidebb
magyarázat arra, hogyan illeszkednek ezek az eszközök egymáshoz.

Két fájl írja le a nyelvet, és mindkettőt te írod:

- **`lexer`** — a flexc++ specifikáció: milyen karaktermintákból milyen
  tokenek lesznek.
- **`grammar`** — a bisonc++ specifikáció: hogyan állnak össze a tokenek
  kifejezésekké, és mi történjen közben.

A generátorok ezekből C++ kódot csinálnak:

```console
$ bisonc++ grammar     # létrehozza a parserbase.h és parse.cc fájlokat
$ flexc++ lexer        # létrehozza a scannerbase.h és lex.cc fájlokat
```

**A sorrend számít.** A `bisonc++` definiálja a token-konstansokat
(`ParserBase::NUMBER` és társai) a `parserbase.h` fájlban, a scanner
akciói pedig ezeket használják, tehát a parsert kell előbb generálni. A
`Makefile` ezt már tartalmazza, így a sima `make` mindig jól csinálja.

Mindkét generátor létrehoz továbbá négy fájlt *egyszer*, és utána soha nem
nyúl hozzájuk: `parser.h`, `parser.ih`, `scanner.h`, `scanner.ih`. Ezek a
tieid — ide kerülnek a saját tagváltozóid és segédfüggvényeid, és ezeket
tartja nyilván a verziókezelő. A négy újragenerált fájl a `.gitignore`-ban
van, mert minden fordításkor felülíródik.

| Fájl | Ki írja | Szerkeszthető? |
|---|---|---|
| `lexer`, `grammar` | te | igen — tulajdonképpen ez a feladat |
| `parserbase.h`, `parse.cc` | bisonc++, minden futáskor | nem |
| `scannerbase.h`, `lex.cc` | flexc++, minden futáskor | nem |
| `parser.h`, `parser.ih` | bisonc++, egyszer | igen |
| `scanner.h`, `scanner.ih` | flexc++, egyszer | igen |

A példa megmutatja azt az egy részletet, ami tényleg trükkös: hogyan jut el egy
token *értéke* (nem csak a típusa) a scannertől a parserig. Nézd meg a
`Parser::lex()` függvényt a `parser.ih` fájlban — minden token ezen megy
keresztül, ezért ez a megfelelő hely a `d_val__` beállítására, azaz annak az
értéknek, amit a bisonc++ a veremre tesz.

## IDE használata

### CLion és más JetBrains IDE-k

A repó tartalmaz egy `.devcontainer/devcontainer.json` fájlt, így a CLion a
konténerben tudja futtatni a kódodat, teljes kódkiegészítéssel, navigációval
és debuggolással.

1. Nyisd meg a projekt mappáját a CLionban.
2. Nyisd meg a `.devcontainer/devcontainer.json` fájlt.
3. Kattints a konténer ikonra a nyitó `{` melletti margón, és válaszd a
   **Create Dev Container and Mount Sources** lehetőséget.
4. Várd meg az első build-et, majd válaszd a **CLion**-t backendnek.

A CLion egyből a `workspace/` mappát nyitja meg, és a
`workspace/examples/calc/` mappában van `CMakeLists.txt`, így a példát CMake
projektként natívan kezeli.

### VS Code

Telepítsd a **Dev Containers** bővítményt, majd a parancspalettából válaszd a
*Reopen in Container* lehetőséget. Ugyanez a `devcontainer.json` fut le.

### Bármilyen más szerkesztő

Nincs mit integrálni: a fájlokat a saját gépeden szerkeszted, és nyitva tartasz
egy `./dev.sh` shellt egy terminálban a `make` futtatásához. Ez mindenhol
működik, és a legtöbben úgyis ennél kötnek ki.

## A pandora 32 bites fordításának megfelelően

A pandora 32 bites gép, így ott a `sizeof(long)` és a `sizeof(void *)` 4, a
fejlesztői image-ben viszont 8. A tárgy feladatai közül szinte semmi nem függ
ettől, de ha a tiéd mégis, a `-m32` kapcsolóval a fejlesztői image is 32 bites
kódot állít elő:

```console
$ g++ -m32 -std=c++14 -o calc main.cc parse.cc lex.cc
$ make CXXFLAGS="-std=c++14 -Wall -m32"
```

A `-m32` a *célplatformot* változtatja meg, nem a fordítót: ugyanaz a g++ 6.3.0
x86-64 helyett x86 kódot ad ki, így a pointerek és a `long` 4 bájtosak lesznek,
a bináris pedig a pandora adatmodelljét követi. A `./dev.sh verify` ugyanezt
fedi le azzal, hogy valódi 32 bites Debian 9-en fordít, tehát a `-m32` akkor
hasznos, ha a fejlesztői image gyorsabb visszajelzését szeretnéd.

## Beadás előtt

```console
$ ./dev.sh verify
```

Ez érintetlen, 32 bites Debian 9-en fordítja újra a projektedet — ugyanaz a
rendszer, ugyanaz az architektúra és ugyanaz a fordító, mint a pandorán. Ha ez
lefut, a javításkor is le fog fordulni.

Ha nem a példát, hanem egy másik feladatot akarsz ellenőrizni, add meg a nevét:

```console
$ ./dev.sh verify hazi1
```

## Hogyan működik

Két image van, mert egyetlen image nem tudja mindkét feladatot ellátni.

**A fejlesztői image** (`docker/Dockerfile`) az, amit nap mint nap használsz.
A Debian 9 fordítója és generátorai egy Debian 12 alapra vannak kicsomagolva:
a `g++`, a `bisonc++` és a `flexc++` pontosan azok a Debian-buildek, amik a
pandorán futnak, de alattuk modern C könyvtár van.

Ez elsőre furcsa megoldásnak tűnik, és van rá konkrét ok. A Debian 9-ben
glibc 2.24 van, a JetBrains és a VS Code távoli backendje viszont **glibc 2.28
vagy újabb** verziót igényel. Egy IDE egyszerűen nem tud elindulni egy Debian 9
konténerben. A régi eszközlánc új alapra ültetése az, amitől a „pontosan az a
fordító” és az „együttműködik az IDE-ddel” egyszerre teljesülhet.

Két részlet a Dockerfile-ból, amit érdemes tudni, ha valaha módosítanád:

- A Debian 9 még a merged-`/usr` elrendezés előtti, ezért a csomagjai valódi
  `/lib` és `/bin` könyvtárakat tartalmaznak. Ha ezeket közvetlenül a Debian
  12-re csomagolnánk ki, a `/lib` → `usr/lib` szimbolikus link helyére könyvtár
  kerülne, ami elfedné a dinamikus betöltőt, és az image összes programja
  elromlana. Ezért előbb egy köztes könyvtárba kerülnek, és onnan kerülnek a
  helyükre.
- A régi Debian-kiadások negatív apt-prioritást kapnak, így csak letöltési
  forrásként szolgálnak, és normál `apt install` során soha nem kerülnek elő.

**Az ellenőrző image** (`docker/Dockerfile.pandora`) a fordítottja: egyszerű,
módosítatlan, 32 bites Debian 9. Ehhez semmilyen IDE nem tud csatlakozni, és ez
így van jól — azért van, hogy a `./dev.sh verify` őszintén meg tudjon
válaszolni egy kérdést. Csak az első `verify` futtatásakor épül fel.

Mindkét image minden csomagot pontos verzióra rögzít az `archive.debian.org`
címről, ami befagyasztott, így a ma és a jövőre készült build ugyanazt az
eszközláncot adja.

## Apple Silicon és más ARM gépek

Az eszközlánc csak x86 binárisként létezik, ezért ARM-os Macen emulálva fut. Ez
magától is működik, de érdemes bekapcsolni a **Rosettát**, amitől a fordítás
többszörösen gyorsabb és érezhetően megbízhatóbb lesz:

- **Docker Desktop** → Settings → General → *Use Rosetta for x86_64/amd64
  emulation on Apple Silicon*.
- **Colima** → indítsd így: `colima start --vm-type vz --vz-rosetta`, és adj
  neki helyet: `--cpu 8 --memory 16`. Ha ezt minden jövőbeli Colima-példány
  alapértelmezésévé szeretnéd tenni, írd bele a `colima template` fájlba.

Sima QEMU-emuláció alatt, kevés memóriával a `g++` néha elszáll
`internal compiler error: Segmentation fault` hibával. Ez az emulátor hibája,
nem a kódodé — a `make` újrafuttatása átlendít rajta, Rosettával és több
memóriával pedig elő sem fordul.

A `./dev.sh verify` 32 bites x86-ot használ, amit a Rosetta nem gyorsít, így ez
az egy parancs mindenhol lassú marad. Alkalmankénti ellenőrzésre bőven elég.

## Hibaelhárítás

**`the Docker daemon is not reachable`** — indítsd el a Docker Desktopot, vagy
futtasd a `colima start` parancsot.

**`the project folder is not visible inside the container`** — a Docker csak
azokat a mappákat tudja becsatolni, amelyek megosztására engedélyt kapott. Tartsd
a repót a home könyvtáradon belül, vagy vedd fel a helyét a Docker Desktop →
Settings → Resources → File sharing alatt.

**`./dev.sh: Permission denied`** — `chmod +x dev.sh`.

**A PowerShell nem hajlandó futtatni a `dev.ps1` fájlt** — engedélyezd egyszer
a helyi szkripteket: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

**A fájlok `root` tulajdonában vannak (csak Linuxon)** — a `./dev.sh` átadja a
felhasználói azonosítódat a konténernek, így ennek nem szabadna előfordulnia.
Ha kézzel futtattál `docker run`-t, tedd hozzá: `-e HOST_UID=$(id -u)
-e HOST_GID=$(id -g)`.

**A `make` azt mondja, minden naprakész, pedig szerkesztetted a `grammar`
fájlt** — ha a gazdagép és a konténer órája eltér, a `make clean && make`
megoldja.

**Figyelmeztetések a `lex.cc` vagy a `parse.cc` fájlból** — ezek generált
fájlok, és a `-Wextra` nem használt paramétereket talál bennük. A saját
fájljaid figyelmeztetéseit érdemes elolvasni, ezt a kettőt nem.

## Ismert eltérések a pandorától

A fejlesztői image alapértelmezésben 64 bites, a pandora 32 bites, így a
`sizeof(long)` és a pointerek mérete eltér. Ha ez számít, fordíts `-m32`
kapcsolóval, vagy futtasd a `./dev.sh verify` parancsot — lásd
[A pandora 32 bites fordításának megfelelően](#a-pandora-32-bites-fordításának-megfelelően).

A fejlesztői image C könyvtára is újabb a pandoráénál, így egy 2016 után
bekerült glibc-függvény itt lefordulna, a pandorán viszont nem. Ezt is elkapja
a `./dev.sh verify`. Beadás előtt egyszer lefuttatni — ennyi az egész
védekezés.

## Licenc

MIT — lásd a [LICENSE](LICENSE) fájlt. Használd, forkold, add tovább az
évfolyamtársaidnak.
