# AGENTS.md — working in this repository (player's fork of MacNativeGames)

You are updating the player's **Tears of the Kingdom 1.1.1** native Mac app. Read this whole file
before touching anything. The deep reference is `games/totk/docs/v1.1.1-port.md` (what the port adds,
how it was verified, the full update procedure).

## 1. What this repository is

- A fork of **upstream** `https://github.com/ly05010419/MacNativeGames.git` (remote name `upstream`).
- The player's fork is `https://github.com/Pressburg/MacNativeGames.git` (remotes `fork` and `origin`).
- The fork carries **exactly one feature**: Tears of the Kingdom **1.1.1** support (upstream removed 1.1.2
  in November 2026 and never carried 1.1.1; the player wants 1.1.1 because 1.1.2/1.4.3 regressed things
  they care about). Everything else must stay byte-for-byte upstream — Breath of the Wild 1.6.0/1.9.0,
  the Switch 2 games (Donkey Kong Bananza, Pokemon Pokopia), VR, the whole builder.
- **Never open a pull request to upstream.** The player keeps the port to themselves.
- The live branch is **`totk-1.1.1-port`** (= upstream/main + the 1.1.1 patch, ~20 files, ~160 insertions).
  Tag `port-1.1.1` marks a known-good state; the old branch `totk-1.1.1-clean2` is superseded and drifted
  (it deleted ~1,100 lines of upstream: BotW/NS2 targets, VR, scene-follows-canvas, the shared patch
  reader) — **never merge or port from it**.

## 2. The hard rules

1. **Never commit game content, keys, saves, or firmware.** Only source, scripts and hash manifests.
   (`extracted/`, `rewritten/`, `build/`, the game NSPs and `prod.keys` all stay out of git — they are
   already ignored; don't force-add anything.)
2. **The diff to upstream stays minimal.** If a change is not needed by the 1.1.1 port, don't make it.
   Restoring upstream content that an older fork branch deleted is always correct.
3. Every runtime patch checks the original instruction word and **refuses to boot on a mismatch**. A
   botched port therefore fails loudly (the app won't start) instead of corrupting the game. Don't
   "fix" a boot refusal by loosening a guard; find the right address for 1.1.1's build.
4. `games/totk/zeldaVR` must be a **real directory**, not the symlink upstream tracks (macOS clang
   resolves the symlink before `..`, so the sources cannot compile through it).
5. Saves and settings live in `~/Library/Application Support/MacNativeGames/TOTK/` (shared by every
   app you build), not in the repo and not inside the app bundle. Rebuilding never touches them.

## 3. Updating the port to a newer upstream (the task antigravity is asked to do)

```bash
cd ~/Documents/Nintendo/MacNativeGames
git fetch upstream
git log --oneline upstream/main -5            # the new tip
git checkout -B totk-1.1.1-port upstream/main # start from the new upstream tip
```

Then **re-apply the 1.1.1 patch** onto that tree. The patch is small and each piece sits next to the
version key it belongs to, so `grep -n v121 <file>` finds the anchor even if upstream moved things:

| File | Re-apply |
| --- | --- |
| `games/totk/assets/expected-v1.1.1.json` | `git checkout port-1.1.1 -- games/totk/assets/expected-v1.1.1.json` (pure data; **checking out upstream removes it**, so always restore it first) |
| `games/totk/runtime/game_version.h` | insert the `#elif defined(TOTK_GAME_V111)` block (33 `GAME_ADDR_*` sites, actor offsets, swkbd stub/GOT, the `0xce3fec` slow-motion note) before `#elif defined(TOTK_GAME_V121)` |
| `games/totk/runtime/game_patches.c` | the v111 `#elif` blocks: cloth table (`0xa53780…`, `cloth_call 0xa54174`), cursor sites (`0xf54028, 0x1d50954, 0x1d500d4`), pool offsets (`0xae5260, 0xae527c`), benchmark camera (`0xce3994, 0x884e08, 0xbc6b08`), aspect stubs (`0xce403c, 0x12624f4, 0x19c013c, 0x1ed6710`); widen the three shared guards to `defined(TOTK_GAME_V121) \|\| defined(TOTK_GAME_V111)` |
| `build_app.py` | `UPDATED111 = json.loads((GAME / 'assets/expected-v1.1.1.json').read_text())`, `'v111': UPDATED111` in `VERSIONS`, `'v111'` in `UPDATES`, `'v111'` in the scene-overlay step list and the `--native-4k` gates, and 1.1.1 in the unsupported-update error message |
| `games/totk/Makefile` | the `game-data-v111` eval and the `runtime-v111` / `binary-v111` targets. **Copy upstream's current `*-v121` rule verbatim** (new source files like `runtime/input_prompts.m` arrive via the wildcard; a stale copied list breaks the link) then swap the identifiers and add `-DTOTK_GAME_V111=1` |
| `games/totk/scripts/*` | add `v111` to every version-choice list where `v121` appears: `patch_sites.py` (VERSIONS/GUARDS/PATCHER), `prepare_runtime.py` (+ the 1.1.1 main-hash assert `d16accd1…`), `prepare_romfs_backend.py`, `prepare_shared_fonts.py`, `make_romfs_patches.py` (COMMON `'v111': '110'`), `make_mod_manifest.py`, `make_output_res_overlay.py` (choices + the `--scene` assert), `game_version_test.py`, `verify_boot.py` (+ checkpoint `0xecaf64`), `verify_loader.py`, `verify_romfs.py`, `verify_rewrites.py`, `verify_cloth_clock.py` (+ the v111 row), `test_exclusive_windows.py` (`[0x728948]`) |
| `games/totk/runtime/settings_panel.h` | `SETTINGS_SSAO` also compiles for `defined(TOTK_GAME_V111)` (the 1.2.1-gated SSAO row, ported 2026-11-06) |
| `games/totk/zeldaVR` | real directory (see rule 4) |

Conflict cues: a conflict in `game_version.h` / `game_patches.c` means upstream changed a shared table's
shape — port 1.1.1's *addresses* into the new shape, never delete the other versions' rows. `patch_sites.py`
failing with "unresolved" means upstream removed a `GAME_ADDR` the v111 block needs — map it with
`scripts/map_version_sites.py --from v121 --to v111`.

Then build and verify (§4–5), then:

```bash
git add -A && git commit -m "feat: 1.1.1 port on upstream <new-tip-short-sha>"
git push fork totk-1.1.1-port
git tag -f port-1.1.1 totk-1.1.1-port && git push -f fork port-1.1.1   # keep the recovery tag current
```

**Then prove the branch actually carries the port** (2026-11-10: a partial `git add` once left the
`game_version.h` v111 block, the Makefile targets and the scripts' version entries uncommitted while
everything still worked from the working tree — the app was fine, the branch was not):

```bash
for f in games/totk/runtime/game_version.h games/totk/Makefile games/totk/scripts/verify_boot.py; do
  printf "%-46s %s\n" "$f" "$(git show HEAD:$f | grep -c V111)"; done   # every count must be > 0
git status --porcelain                                                  # must be empty
```

Also check the remotes exist before anything else — the `upstream` remote has been lost from this
clone's config once already (nothing works without it):

```bash
git remote -v | grep upstream || git remote add upstream https://github.com/ly05010419/MacNativeGames.git
```

**Dry-run the whole update before touching the real branch** (2026-11-10 recipe; a strict-context
apply on one file needed the 3-way fallback, which the dry run shows without leaving the branch
half-updated):

```bash
git worktree add --detach /tmp/upd-check upstream/main
cd /tmp/upd-check
git diff upstream/main..totk-1.1.1-port -- \
  games/totk/assets/expected-v1.1.1.json games/totk/runtime/game_version.h games/totk/runtime/game_patches.c \
  games/totk/Makefile games/totk/runtime/settings_panel.h games/totk/scripts/ > /tmp/port-apply.patch
git diff upstream/main..totk-1.1.1-port -- build_app.py games/totk/scripts/make_output_res_overlay.py > /tmp/port-apply-builder.patch
git apply -3 /tmp/port-apply.patch && git apply -3 /tmp/port-apply-builder.patch   # -3: one file's context moves
ln -s "$PWD/../.venv" .venv
cd games/totk && ln -s ../../../../extracted extracted && ln -s ../../../../rewritten rewritten && ln -s ../../../../analysis analysis
# upstream's settings_panel.h now includes "contrib_submit.h" (shared from games/alc/runtime/);
# build_app.py copies it during a real build, but a raw make does not, so symlink it:
ln -s ../../../../alc/runtime/contrib_submit.h runtime/contrib_submit.h
make build/totk-native-v111        # the proof: the port compiles on the new upstream
```

Only when that passes, do the real re-apply on `totk-1.1.1-port` (§3), then §4–§5.

## 4. Building the player's 1.1.1 app

```bash
cd ~/Documents/Nintendo/MacNativeGames
.venv/bin/python build_app.py \
  "/Users/admin/Documents/Nintendo/TOTK roms/The Legend of Zelda Tears of the Kingdom [0100F2C0115B6000][v0].nsp" \
  --update "/Users/admin/Documents/Nintendo/TOTK roms/The Legend of Zelda Tears of the Kingdom [0100F2C0115B6800][v196608].nsp" \
  -k "/Users/admin/Documents/Nintendo/Keys-22.1.0/prod.keys" \
  --shared-fonts games/totk/extracted/firmware/shared-fonts \
  --work "/Users/admin/Documents/Nintendo/TOTK_build.noindex" \
  --native-4k \
  -o "/Users/admin/Documents/Nintendo/Tears of the Kingdom 1.1.1.app"
```

Notes: the game/update NSPs and the keys are the player's own files (never committed). `--work` and
`extracted/firmware/shared-fonts` are already populated — keep them, they make rebuilds take minutes.
Always pass `-o` with the final location: the Metal shader cache is keyed to the app path (moving the
app afterwards costs one longer boot). The shader chain (`~/Library/Application Support/MacNativeGames/
TOTK/shader-cache/rt-totk-native-v9-unverified`) carries over between rebuilds — never delete it.
The player's config: realtime + 60 fps + cloth clock, 1440p output, MetalFX stages off (their panel
setting lives in the profile, not the repo). First launch from Finder shows a Gatekeeper "Verifying…"
dialog — harmless; right-click → Open once registers it.

## 5. Verify before you call it done

```bash
make check                                          # the repo's source gate (mirrors CI)
cd games/totk && make binary-v111                   # compiles clean (0 errors)
.venv/bin/python scripts/game_version_test.py --version v111
.venv/bin/python scripts/verify_loader.py  --version v111
.venv/bin/python scripts/verify_boot.py   --version v111   # 2 trials; nnMain PC must be 0xecaf64
.venv/bin/python scripts/verify_cloth_clock.py v111        # 140 Unicorn cases
.venv/bin/python scripts/verify_romfs.py  --version v111
.venv/bin/python scripts/test_exclusive_windows.py rewritten/v111 extracted/v111/exefs/main --version v111
.venv/bin/python scripts/patch_sites.py --version v111     # no drift alarm
```

Then boot the built app once and check the log (`~/Library/Logs/MacNativeGames/totk.log`) shows
`1.1.1 60 FPS patch`, the version-correct patch lines, and the expected output/scene lines; the menu
and a save load must work end to end.

## 6. Known state (as of 2026-11-10)

- Branch `totk-1.1.1-port` @ `4bd74707`, tag `port-1.1.1` (both pushed; the tag is the recovery source
  for `expected-v1.1.1.json` and every anchor listed in §3).
- The `upstream` remote was missing from this clone's config on 2026-11-10 and was restored
  (`https://github.com/ly05010419/MacNativeGames.git`) — §3 checks for it first.
- The port pieces were once half-committed (2026-11-10, commit `4bd74707` fixed it): a checkout of the
  branch alone must be complete. The verification loop in §3 proves it.
- Upstream's tip was `adc0e199` on 2026-11-10 (it added an Ocarina of Time port, ~1,500 files, plus VR,
  iOS and shader-list changes). The §3 re-apply was validated against that tip: every port file,
  including `build_app.py`, applies clean (3-way) and `games/totk/build/totk-native-v111` compiles
  with 0 errors. A raw `git diff upstream/main..HEAD` will show ~1,700 files and ~400k deletions right
  after the checkout — that is only upstream's new content the branch does not have yet; after the
  re-apply the *port* diff is the ~20 files of the table.
- 1.1.1 has the 1.2.1-gated features too (scene-follows-canvas, native 4K, SSAO row) — see
  `games/totk/docs/v1.1.1-port.md` §8. The 1.4.3-only features (effects page, VR, 5K, the >60 FPS fade
  fix, AA-method row, pt-BR, HDR frontend, frame-step) are analyzed and deliberately not ported, with
  the evidence, in the same section.
- The 1.2.1 app (`~/Documents/Nintendo/Tears of the Kingdom 1.2.1.app`) is built from this branch too
  and behaves as upstream 1.2.1 (all v111 code is preprocessor-excluded from it).
