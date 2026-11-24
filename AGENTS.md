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
| `games/totk/runtime/settings_panel.h` | **no port hunk needed** — upstream (2026-11-10+) ungated `SETTINGS_SSAO` (`#define SETTINGS_SSAO 1` unconditionally) and dropped the `contrib_submit.h` include (replaced by `input_prompts.h` + the contrib-tab upload page). Resolve any conflict by taking upstream's version of the file. |
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
# IMPORTANT: generate the patch against the base the port actually sits on (the upstream commit the
# branch was built from), NOT against the moved upstream/main — otherwise the patch carries reversions
# of upstream's own newer commits and re-applying them silently reverts upstream fixes.
BASE=<the upstream commit the branch was built from>     # e.g. 71a5da8c after the 2026-11-15 update
git worktree add --detach /tmp/upd-check upstream/main
cd /tmp/upd-check
git diff $BASE..totk-1.1.1-port -- \
  games/totk/assets/expected-v1.1.1.json games/totk/runtime/game_version.h games/totk/runtime/game_patches.c \
  games/totk/Makefile games/totk/scripts/ > /tmp/port-apply.patch
git diff $BASE..totk-1.1.1-port -- build_app.py games/totk/scripts/make_output_res_overlay.py > /tmp/port-apply-builder.patch
git checkout totk-1.1.1-port -- games/totk/assets/expected-v1.1.1.json
git apply -3 /tmp/port-apply.patch && git apply -3 /tmp/port-apply-builder.patch   # -3: shared lines moved
# Files upstream DELETED or RENAMED since $BASE (the patch's hunks for them fail): drop those sections and
# take upstream's version. In the 2026-11-15 update that was collect_shader_issues.py (replaced by
# collect_shaders.py), and the whole sections for build_shader_libs.py, prompt_assets.py,
# make_button_icons.py, make_botw_button_icons.py, prepare_shader_seed.py (their port changes were
# reversion artifacts of upstream's own work, not port code — verify by asking "does this deletion have
# anything to do with 1.1.1?"; if not, take upstream's file).
# Conflicts left unmerged (Makefile, game_version.h, build_app.py in 2026-11-15): resolve by taking
# upstream's version of the file and re-adding ONLY the v111 pieces:
#   * Makefile:            the v111 rule = upstream's current *-v121 rule with V121 -> V111, plus the
#                         $(eval $(call GAME_DATA,v111,...)) line next to v121's
#   * game_version.h:      the port's #elif defined(TOTK_GAME_V111) block, inserted before the v121 block
#   * build_app.py:        UPDATED111 import, VERSIONS/UPDATES entries, the identify_update message,
#                         the --native-4k gate (add v111), the step_update_data scene-overlay gate (add v111)
ln -s "$PWD/../.venv" .venv
cd games/totk && ln -s ../../../../extracted extracted && ln -s ../../../../rewritten rewritten && ln -s ../../../../analysis analysis
# upstream's settings_panel.h needs "contrib_submit.h" (shared from games/alc/runtime/);
# build_app.py copies it during a real build, but a raw make does not, so symlink it:
ln -s ../../../../alc/runtime/contrib_submit.h runtime/contrib_submit.h
# upstream's v111 link line needs runtime/input_prompts.m (totk_prompt_icons.m's runtime_prompt_snapshot)
make build/totk-native-v111        # the proof: the port compiles on the new upstream
# then the pure-logic verifiers (they need build/game-data/v111 copied from the real tree first):
.venv/bin/python scripts/game_version_test.py --version v111
.venv/bin/python scripts/patch_sites.py --version v111
.venv/bin/python scripts/test_exclusive_windows.py --version v111 rewritten/v111 extracted/v111/exefs/main
.venv/bin/python scripts/verify_loader.py --version v111
.venv/bin/python scripts/verify_cloth_clock.py v111
./build/totk-native-v111 rewritten/v111 probe-fs     # needs build/game-data/v111 (build_app.py's tables)
# verify_rewrites.py fails in the worktree when upstream changed the rewriter scripts since $BASE —
# it regenerates the artifacts; a real build re-runs the rewrite pipeline anyway.
```

Then apply the result to the branch the same way the 2026-11-15 update did: tag the old tip
(`port-1.1.1-prev`), `git checkout -B totk-1.1.1-port upstream/main`, copy the merged files, keep
`games/totk/zeldaVR` as a real untracked directory (remove the tracked symlink; `.gitignore` has the entry),
commit, force-push the branch and move the tag.

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
.venv/bin/python scripts/test_exclusive_windows.py --version v111 rewritten/v111 extracted/v111/exefs/main
.venv/bin/python scripts/patch_sites.py --version v111     # no drift alarm
```

Then boot the built app once and check the log (`~/Library/Logs/MacNativeGames/totk.log`) shows
`1.1.1 60 FPS patch`, the version-correct patch lines, and the expected output/scene lines; the menu
and a save load must work end to end.

## 6. Known state (as of 2026-11-24)

- Branch `totk-1.1.1-port`, tag `port-1.1.1` (both pushed; prior pre-rebase tip archived at `port-1.1.1-prev` / `c8cf37b3`; `port-1.1.1` is the recovery source for `expected-v1.1.1.json` and every anchor listed in §3).
- Upstream baseline is now `97eafb63` (+334 commits over prior `71a5da8c`). Full upstream delta, 71 open PRs, 178 active forks, external projects (`iceorange-dev/manosaba-ios`, `seedds/nxnative`), integrated winners, and SKIP reasons are logged in `games/totk/docs/upstream-watch.md`.
- The `upstream` remote (`https://github.com/ly05010419/MacNativeGames.git`) is configured locally alongside `fork` (`Pressburg/MacNativeGames.git`).
- Note on `games/totk/zeldaVR`: `97eafb63` added `zeldaVR/gfx/vr_depth_stereo.{h,m}` referenced by `nvn_mtl.m`; `games/totk/zeldaVR` must remain a real untracked directory synced from repo-root `zeldaVR/` whenever updating upstream (`cp -R`).
- `v111` port specifics preserved across rebase:
  - `Makefile`: `v111` rule lists `runtime/input_prompts.m` and `$(eval $(call GAME_DATA,v111,...))`.
  - `runtime/game_patches.c`: includes `1.1.1` start-up race guard (`main+0x7f9dd8`, veneer `+0x2b282d0`, ported from `LENG-ZECHEN 83c08b27`) and `1/120 s` real-time frame-step floor (`lakuch de8d30c7`), protected by `patch_sites.py` (54 sites).
  - Shared `gfx/nvn/*` wins integrated cleanly on top of `97eafb63`: `PR #485` async/cached `totk_taa.m` scaler (`1eb7bfa4`), `20 µs` render-stream spin cap (`e884aa41` adapted via `!GAME_NS2 && !TOTK_GAME_V143`), `TOTK_RS_POOL` batched autorelease pool (`d4bb9982`), `TOTK_RES_BATCH` async removal residency commits (`76c69018`), `reduced` `pk->owned` guard (`c10eda9c`), `TOTK_ENC_LOCK1` single draw registry lock (`18a6a4ab`), `TOTK_PSO_MEMO2` per-program LRU (`51d5e36e`), `upd_shadow`/`usnap` pool lookup skip (`iceorange-dev/manosaba-ios` `80713081`, MIT, credited in `THIRD_PARTY_NOTICES.md`), and single-lookup `nvn_dirty_check` (`e9b8eafa` + `chunk_check` test in `probe-dirty-race`).
  - SSAO, scene-follows-canvas, and native 4K remain active for `1.1.1`; `games/totk/docs/v1.1.1-port.md` §8 documents intentionally skipped 1.4.3-only features.
- Built `/Users/admin/Documents/Nintendo/Tears of the Kingdom 1.1.1.app` with `--native-4k` (27,408 pipelines for `applegpu_g17g`, 0 errors) and boot/save-load verified end-to-end into Eldin Canyon with player settings intact (`1440p`, `lock-60`, `graphics-taa=1`, `picture-mode=off`, MetalFX off). Only `make PYTHON=.venv/bin/python check-c` + `v111` §5 verifiers + `probe-{fs,dirty-race,pool-index,metal-semantics,texture-auto-layout}` are gated; full `make check` still hits upstream's unrelated `games.py`/other-game catalog assertions because the fork adds `v111` and replaces the tracked `games/totk/zeldaVR` symlink.

## 7. Green tiles / MetalFX (debugging note)

If the title screen shows green square tiles on the glow lines, the shared profile has MetalFX on:
`~/Library/Application Support/MacNativeGames/TOTK/picture-mode.txt` = `metalfx` and
`graphics-output.txt` = `1`. Set them to `off` / `0` (or flip the panel's resolution row to 1080p).
The game's own upscale (`TOTK_MFX_UPSCALE=0`) is the clean path; Apple's `MTLFXSpatialScaler` tiles on
thin saturated glow lines. The settings live in the profile, not the repo, so a rebuild does not reset them.
