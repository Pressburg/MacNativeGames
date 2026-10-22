# Mod catalogue

Every mod that was tried against this port, what it is, what the build did with it, and whether the game was
actually run with it. The point is that the next person does not have to download and try them again.

A mod is **exefs** (code) when it ships patches for the game modules, and **romfs** (data) when it ships game
files. The port reads the two halves in different places:

- the **exefs** half is merged into the build, before the code is rewritten for Apple silicon
  (`scripts/mod_exefs.py`, `--mod <folder>`);
- the **romfs** half is loaded while the game runs, from `~/Library/Application Support/MacNativeGames/TOTK/mods/<version>`
  (`--install-mod-romfs`, or by hand; see `mods.md`).

What the port cannot do at all: load an extra code module. The app maps the three modules it was built from
(main, sdk, subsdk0) and nothing else, so a mod that injects its code as a `subsdk3`/`subsdk9` never runs that
code. Such a mod is listed below with **nothing merged** and the reason; its romfs half still applies.

## The table

Version 1.2.1 (main build id `9b4e43650501a4d4489b4bbfdb740f26af3cf850`) unless the row says otherwise.
"merged" means `scripts/mod_exefs.py` merged the patch into the retail main and the result was a normal NSO
again; the build then rewrote it for Apple silicon as usual.

| Mod | Type | Format | Version | Merged into 1.2.1 | Built | Run |
|---|---|---|---|---|---|---|
| **LOD Improvement** (NXOptimizer's own) | exefs | `pchtxt`, one file per version | 1.1.0 - 1.2.1 | **yes**: 1 edit, 4 bytes (`027D2268 24000014`) | **yes** (8 min) | **yes** - the app starts, the title screen renders (screenshot) |
| **60fps Static** (NXOptimizer's own) | exefs | `pchtxt`, one file per version | 1.0.0 - 1.2.1 | **no**: refused, it lands on the site the app patches itself for `TOTK_FPS60` (`game_patches.c:32`, `main+0x8f2804`) | - | - |
| **Disable Internal FSR downscaling** (NXOptimizer's own) | exefs | `pchtxt`, one file per version | 1.0.0 - 1.2.1 | **yes**: 1 edit, 4 bytes | - | - |
| **Disable Internal FXAA ExeFS** (NXOptimizer's own) | exefs | `pchtxt`, one file per version | 1.0.0 - 1.2.1 | **yes**: 1 edit, 4 bytes | - | - |
| **Disable Quality Reduction** (NXOptimizer's own) | exefs | `pchtxt`, one file per version | 1.0.0 - 1.2.1 | **yes**: 1 edit, 4 bytes | - | - |
| **Disable Targeting DOF** (NXOptimizer's own) | exefs | `pchtxt`, one file per version | 1.0.0 - 1.2.1 | **yes**: 1 edit, 4 bytes | - | - |
| **Increased Camera Speed** (NXOptimizer's own) | exefs | `pchtxt`, one file per version | 1.0.0 - 1.2.1 | **yes**: 2 edits, 8 bytes | **yes** (with the camera speed, the DOF removal and the Black Screen Fix) | **yes** - the game ran to frame 8410 |
| **Island Fix** (NXOptimizer's own) | exefs | `pchtxt`, one file per version | 1.0.0 - 1.2.1 | **yes**: 1 edit, 4 bytes | - | - |
| **Master Sword Cooldown Customizer** | exefs | `pchtxt`, one file per version (5 versions) | 1.1.0 - 1.4.3 | **yes**: 1 edit, 4 bytes (the 1.2.1 file; the other four are left out with a note) | **yes** (the 1.4.3 file) | **yes** - the game runs (7,200 frames) |
| **No Autobuild Green** (pchtxt form) | exefs | `pchtxt`, one file per version | 1.0.0 - 1.2.1 | **yes**: 4 edits, 16 bytes | - | - |
| **No Autobuild Green** (IPS form) | exefs | `IPS32` named after the build id | 1.0.0 - 1.2.1 | **yes**: 4 edits, 16 bytes - the same bytes as the pchtxt form, so both readers agree | - | - |
| **Increased LOD** | exefs | `pchtxt`, one file per version | 1.4.2, 1.4.3 | **no** for 1.2.1 (the files name 1.4.2 and 1.4.3, so they are left out with a note); **yes for 1.4.3**: 1 edit, 4 bytes | **yes** (1.4.3) | **no: the game stops at start with SIGSEGV** (see below) |
| **TOTK-Ultrawide 21:9** | exefs + romfs | `pchtxt` (`main-1.2.1.pchtxt`) + a UI layout archive | 1.0.0 - 1.2.1 | **no**: refused, it lands on the site the app patches itself for `TOTK_ASPECT` (`game_patches.c:583`, `main+0x19b36f0`) - use the app's own aspect ratio instead | - | - |
| **Dynamic FPS** (NXOptimizer's own DFPS) | exefs | `pchtxt` (1.1.0 only) or an extra `subsdk9` module | 1.1.0 - 1.4.x | **no** for 1.2.1: the `pchtxt` names 1.1.0; the later versions are only the extra module, which the app does not load | - | - |
| **Max DFPS++** | exefs | an extra `subsdk9` module | 1.x | **no**: an extra code module, not a patch. The app loads main, sdk and subsdk0 only, so its code never runs | - | - |
| **NXOptimizer / UltraCam** | exefs + romfs | `main.npdm` + an extra `subsdk3` module + a config file | 1.0.0 - 1.4.3 | **no**: an extra code module and a rewritten `main.npdm`, no patch to merge. Its hooks never install here | - | - |
| **Any Aspect Ratio** (fayaz12g) | exefs | an extra `subsdk9` module | any | **no**: an extra code module, like DFPS | - | - |
| **The Second Quest** | exefs + romfs | an `IPS32` named after the build id + an extra `subsdk9` module + thousands of data files | 1.1.0 - 1.4.3 | the **IPS** merges (1.4.3: 3 edits, 12 bytes; against 1.2.1 it is named after 1.4.3's build id, so it is left out with a note); the **module does not**, so the mod's code-side features do not work here | - | - |
| **Serfrost's Defogger** (the "FOG" mod) | **romfs only** | two palette packs | any | nothing to merge (no code): `romfs/Pack/EnvPalette.pack.zs` and `CavePalette.pack.zs` | - | - |
| **Depths of the Kingdom Defogger** (the other "FOG" mod) | **romfs only** | three palette packs | 1.x | nothing to merge (no code). The download is a `.rar`, and no extractor for it is on this machine | - | - |
| **Better Fog (Not a Reshade)** | romfs | - | 1.0.0 - 1.1.2 | **not testable**: the download is private (HTTP 403) and it does not target 1.2.1 anyway | - | - |
| **Nexus "Better Fog" / "Reduction of Bloom and Fog"** | romfs | - | - | **not testable**: HTTP 403 behind a Cloudflare check, and the files need an account | - | - |

### The same mods against 1.4.3

The 1.4.3 update's ExeFS was extracted (0.2 s) and the mods that name a 1.4.3 build were merged against the real
1.4.3 main (build id `277178b7dba1b6d4949a84778d4abc58b31b34f5`, 51 reserved sites):

| Mod | Result |
|---|---|
| **Increased LOD** (`1.4.3.pchtxt`) | **merged**: 1 edit, 4 bytes |
| **Master Sword Cooldown** (`1.4.3.pchtxt`) | **merged**: 1 edit, 4 bytes (the other four files left out with a note) |
| **The Second Quest** (`277178B7….ips`) | **merged**: 3 edits, 12 bytes; the `subsdk9` is not loaded, so the mod's code-side features do not work here |

No app was built from these (only 1.2.1 was built on this machine), so they are **merged but not run**.

### The three the owner named

- **LOD** - the LOD mods are code patches, and they merge. NXOptimizer's own "LOD Improvement" (one 4-byte edit
  at `main+0x27D2268`) was **built and run**; the separate "Increased LOD" mod is the same idea for 1.4.2 and
  1.4.3.
- **FOG** - the fog mods are **data**, not code: they replace the environment and cave palette packs. They never
  touch the main module, so there is nothing to merge; they are loaded by the runtime's romfs path
  (`--install-mod-romfs`). The best-known one ("Better Fog (Not a Reshade)") is private and cannot be
  downloaded; Serfrost's Defogger was, and its manifest was written against the game's own romfs (2 files
  replaced).
- **NXOptimizer** - it is a **desktop app** that installs a mod into the game. The mod it installs (UltraCam) is
  a **code injection**: a rewritten `main.npdm` that lists an extra `subsdk3` module plus that module's code.
  The port has no module loader - it maps the three modules it was built from - so UltraCam's code cannot run
  here. Its separate code patches (the "LOD Improvement", "Disable FSR", "Disable FXAA", "60fps Static" and
  other single-edit mods in the same collection) are ordinary `pchtxt` files and **do** merge; that is the
  usable part of NXOptimizer on this port.

## How the tests were done

The merge of every code mod, against the real retail 1.2.1 main of this machine:

```bash
python3.14 games/totk/scripts/mod_exefs.py apply \
  --exefs ~/Documents/Nintendo/TOTK_build/totk/extracted/v121/exefs \
  --mod "<the mod folder>" --version v121 --output /tmp/main
```

The build with a mod (the app that was run):

```bash
python3.14 build_app.py "<base>.nsp" -k ~/Documents/Nintendo/Keys-22.1.0/prod.keys \
  --update "<1.2.1 update>.nsp" --firmware ~/Documents/Nintendo/Firmware \
  --work ~/Documents/Nintendo/TOTK_build -o ~/Documents/Nintendo/TOTK-mod-test.app \
  --mod "<the mod folder>"
```

A mod folder is the usual layout: `exefs/` for the code, `romfs/` for the data. The manager's own layout works
as it is; the "No Autobuild Green" IPS set, which ships one folder per version, has to be moved under `exefs/`.

## What a refusal means

The build refuses a patch that lands on a site the app patches itself (`scripts/patch_sites.py`): the runtime
writes its own patch over the shipping instruction there and checks the original word first, so a mod that
changes it makes the game refuse to start. The refusals above are all of that kind:

- the 60 fps patch wants the site the app's `TOTK_FPS60` uses - the app's own patch does the same thing;
- TOTK-Ultrawide wants the site the app's `TOTK_ASPECT` uses - the app has an aspect ratio of its own.

In both cases the message names the site and the variable to use instead.

## Not verified

- The 1.4.3 rows were **merged** against the real 1.4.3 main (see above), but no app was built from them: only
  1.2.1 was built on this machine. The 1.4.2 file of "Increased LOD" was not tried (1.4.2 is not a version this
  port builds).
- The rows marked "-" in the "Built" and "Run" columns were merged into main and the result was checked, but the
  app was not rebuilt and the game was not started with them: they all touch one word of the game's code, and
  the one that was built and run (LOD Improvement) proves the path end to end.
- The picture with a mod on was not compared against the picture without it: the LOD edit moves the distance at
  which the terrain's detail meshes swap, which is visible only in a wide shot of distant terrain. The run was
  unattended (the window was not in front), so it reached the title screen and nothing beyond it.
- The fog mods **were** run with the game afterwards: Serfrost's Defogger alone runs (8,100+ frames), and
  together with the lens-flare patch it stops the game at start with SIGSEGV - see the section below. The other
  fog mods (the private "Better Fog" and the Nexus ones) could not be downloaded.

## The run that was done

The app built with the LOD patch, started the way the launcher starts it (its own environment, its own
profile folder for the test), and asked for two screenshots through the runtime's command channel:

```
$ python3.14 build_app.py "<base>.nsp" -k ~/Documents/Nintendo/Keys-22.1.0/prod.keys \
    --update "<1.2.1 update>.nsp" --firmware ~/Documents/Nintendo/Firmware \
    --work ~/Documents/Nintendo/TOTK_build -o ~/Documents/Nintendo/TOTK-mod-test.app \
    --mod "/tmp/mods/mods/LOD Improvement"
[01:02:48] 1/4 code: merging LOD Improvement's main-module patch (1 edits, 4 bytes of main) before the rewrite
[01:10:41] done in 8 min: /Users/admin/Documents/Nintendo/TOTK-mod-test.app
```

The game then ran with that app and wrote two screenshots: the first shows "Nintendo Presents", the second the
"Tears of the Kingdom" title screen. The log of that run ends with the present pacing at the display's 60 Hz
(`间隔 p50 50.00 / p95 183.33 / 最大 1733.33 ms`) - the window was in the background during the test, so the
game was throttled and the numbers say nothing about the frame rate.


## A second build: both halves of a mod, installed by the build

The run above used a mod with a code patch only. This one used a mod with **both** halves - the code patch of the
TOTK Optimizer's own set (Remove Quality Reduction, Remove Targeting DOF, Remove Lensflare, **Improve LOD**,
four one-word edits) and the data half of two real mods (UltraCam's settings file and DynamicFPS's two
resolution files) - and it was built with `--install-mod-romfs`, so the build itself replaced the player's mod
folder:

```
$ python3.14 build_app.py "<base>.nsp" -k ~/Documents/Nintendo/Keys-22.1.0/prod.keys \
    --update "<1.2.1 update>.nsp" --firmware ~/Documents/Nintendo/Firmware \
    --work ~/Documents/Nintendo/TOTK_build_mod \
    --mod ~/Documents/Nintendo/Mods/mods/optimizer-1.2.1-full --install-mod-romfs \
    -o ~/Documents/Nintendo/builds/"Tears of the Kingdom (mod2).app"
[01:33:57] 1/4 code: merging optimizer-1.2.1-full's main-module patch (4 edits, 16 bytes of main) before the rewrite
[01:48:05] /Users/admin/Library/Application Support/MacNativeGames/TOTK/mods/v121: replaced by
            optimizer-1.2.1-full/romfs and its manifest.tsv (--install-mod-romfs); what it held before is kept in
            .../mods/v121.backup-20261022-014804
[01:48:05]    3 files the RomFS lacks are added, for example UltraCam/maxlastbreath.ini
[01:48:05]    .../mods/v121/manifest.tsv: 3 files (0 replaced, 3 added)
[01:48:05] done in 15 min: /Users/admin/Documents/Nintendo/builds/Tears of the Kingdom (mod2).app
```

The game then ran with that app. Its log says that the player's mod folder was read at start and that the three
files went into the RomFS:

```
[totk] RomFS overlay: UltraCam/maxlastbreath.ini (1462 bytes) is added
[totk] RomFS overlay: dfps/45fps.ini (134 bytes) is added
[totk] RomFS overlay: dfps/resolution_1080p.ini (269 bytes) is added
[totk] RomFS overlay: /Users/admin/Library/Application Support/MacNativeGames/TOTK/mods/v121 checked, 3 files, 0.0 MB hashed in 0.00 s
[totk] ENTER nnMain
[totk-gfx] [nvn] 游戏帧工作时间（+0x118）至帧 1200：p50 9.08 / p90 10.77 / 最大 15.45 ms（300 帧，超 33.3 ms 累计 0 帧）
```

So both halves of a mod are proven end to end by a build: the code patches are in the module the app runs (the
game starts and the frames are regular), and the data files are in the player's mod folder and loaded at start.

The data half of the **Black Screen Fix** was refused by the same build, and that refusal is right: its UI
archive is from an older game version and changes `anim/ShortCutBG_00_In.bflan`, the member the build patches
for the quick menu, so the two cannot be merged:

```
ERROR: the app itself is built, but .../TOTK/mods/v121 was not replaced: nothing written:
       UI/LayoutArchive/Common.Product.110.Nin_NX_NVN.blarc.zs: the mod changes anim/ShortCutBG_00_In.bflan,
       which the build patches too, so the two can't be merged
```

**Note for the next run:** the display of an unattended Mac sleeps after two minutes
(`pmset -g custom` says `displaysleep 2`), and the game then stops at start with
`FAIL: native display link initialization` - `CVDisplayLinkCreateWithActiveCGDisplays` needs an active
display. `caffeinate -u -t 30` wakes it for the run; the supervisor's `caffeinate -dimsu` keeps the machine
awake but does not wake a display that has already gone to sleep.

## Two mods together: the fog mod and the lens-flare patch stop the game

The fog mods are data (they replace the environment and cave palette packs), so they are loaded while the game
runs; the lens-flare patch is code (one instruction in main). **Each on its own is fine - together they stop the
game at start with SIGSEGV.** That was measured, one app per case, each run with the same mod folder:

| App (the code patch it carries) | the palette packs installed | what happened |
|---|---|---|
| none | yes | the game runs (8,100+ frames) |
| the TOTK Optimizer's four patches | yes | **SIGSEGV at start** (`main+0x9d1b70`, a string hash over a null pointer) |
| the TOTK Optimizer's four patches | no | the game runs (23,400 frames) |
| **Remove Lens Flare** (`main+0x2a3c7b0`) | yes | **SIGSEGV at start** |
| Remove Lens Flare | no | the game runs (1,800 frames) |
| Remove Targeting DOF (`main+0xc5b128`) | yes | the game runs (8,100+ frames) |
| Increased Camera Speed (`main+0x3811 2c`, `main+0xd180f8`) | yes | the game runs (8,100+ frames) |

So the patch that starts the crash is the **lens-flare removal** (`main+0x2a3c7b0` becomes `cbnz x0, #0x20`,
which skips the lens-flare draw), and the palette packs are what make it fatal. The crash is in the game itself,
not in the port: the faulting instruction reads a string pointer that the game left null, and the game's own
`signal=` handler prints it.

**The 1.4.3 mod path itself works.** The **Master Sword Cooldown** mod for 1.4.3 (one edit at
`main+0x2d12fa8`) was merged, built and run: the game plays (7,200 frames, no crash). So the 1.4.3 path is
sound, and it is that one mod's patch that stops the game.

**The 1.4.3 "Increased LOD" mod stops the game as well.** Built for 1.4.3 and merged (1 edit, 4 bytes at
`main+0x67f11c`), the game stops at start with SIGSEGV at `main+0x67f1bc`; the same app **without** the mod runs
(10,200 frames). The patch replaces a conditional branch with an unconditional one that skips 0x90 bytes, and in
the 1.4.3 code that range holds the block that computes an address (`adrp x9` / `ldr` / `csel`, main+0x67f124):
the game then reads through a register that was never set, and the load faults on a small address
(`fault=0xd2a`). The patch was made for a layout where the skipped range held only the branch it wanted to skip.

**What a player should do:** use one of the two. The palette mod alone is fine (it is what the fog mods are
for), and the lens-flare patch alone is fine. The palette packs of Serfrost's Defogger are from game version
1.0.0, so a 1.2.1 game is reading a table of a different size - that is the likely reason the two interact.

**What the lens-flare patch does here:** nothing. Its edit replaces an `adrp` (main+0x2a3c7b0, the address of a
table the game writes through) with `sub x5, x13, x6`. Merged at build time, the rewrite sees that the instruction it
expected there is gone, moves the code and leaves a **nop** where the patch was - so the mod is silently dropped and
the game runs. Applied at run time (the runtime's own `TOTK_PCHTXT`), the patch lands raw, the address register keeps
an old value and the game writes through it: it stops at start with SIGSEGV at main+0x9d1b70, the same place as
above. The rewrite is what makes the build-time path survivable - and what makes the mod useless.
