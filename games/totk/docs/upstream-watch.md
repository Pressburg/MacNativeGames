# Upstream & Ecosystem Watch Log (TOTK 1.1.1 Port)

**Last updated:** 2026-11-24
**Recorded upstream baseline:** `97eafb63` (`upstream/main`, +334 commits since previous baseline `71a5da8c`)
**Port branch:** `totk-1.1.1-port` (`fork` = `Pressburg/MacNativeGames`, tag `port-1.1.1`; prior pre-rebase tip archived at tag `port-1.1.1-prev` / `695afd88`)

Everything marked **EVALUATED** below has been audited against `upstream/main` (`97eafb63`) and `games/totk/rewritten/v111/main.patched.bin` and must not be re-researched from scratch on future runs unless new commits arrive.

---

## 1. Upstream Delta Since `71a5da8c` (`71a5da8c..97eafb63`, 334 commits)

### (a) Lands directly in 1.1.1 (shared graphics layer, runtime, builder, shader lists)

| Commit | Area | Summary / upstream measured impact | Status |
| --- | --- | --- | --- |
| `634fe525` (`PR #2295` / `ee5eda73`) | `nvn_mtl.m` | Builds prompt font-atlas copy in upload staging and blits into private texture — measured saving **7–11 ms** on submit thread (eliminates 8 MB/atlas re-upload). | EVALUATED — INHERITED |
| `c5200bbc` (`PR #2293`) | `nvn_mtl.m` | Pending-write overlays skip already-completed prefix. | EVALUATED — INHERITED |
| `b177ea53` (`PR #2341`, + `671fb2c2`) | `romfs.c` / runtime | Persistent mods verification record for BotW & TOTK — measured cold **61 s** / warm **25 s** on M2 Air -> **0.23 s** cached. | EVALUATED — INHERITED |
| `9c85d5c3` (`PR #2338`) | `nvn_mtl.m` | Storage-buffer copy no longer reused within a submission after a GPU write to its bytes. | EVALUATED — INHERITED |
| `3657c12f` (`PR #2305`) | `nvn_mtl.m` | Copies colour target when a draw samples the target it writes at offset coords (fixes Rauru's ghost in Ukouh Shrine). | EVALUATED — INHERITED |
| `7d3803ce` (`PR #2107`) | `nvn_mtl.m` / archive | Re-compiles dropped Metal 4 archive periods after compiler service death instead of omitting them. | EVALUATED — INHERITED |
| `49ab152e` | `nvn_mtl.m` | Mesh pipelines rejected by Metal skip draw cleanly on Mac without recompiling each draw. | EVALUATED — INHERITED |
| `7933568a` (`PR #2267`) | `totk_shader_rt.*` | Fixes `TOTK_SHADER_PREFETCH=1` boot deadlock (`totk_rt_dir()` before `g_rt_lock`). | EVALUATED — INHERITED |
| `8a5dbc4a` | `totk_shader_seed.*` | Reads seed variant indexes in background instead of disk I/O on replay thread. | EVALUATED — INHERITED |
| `4ffc2374` | `nvn_mtl.m` / upload | Prefetches paged-out guest texture pages across worker threads before upload. | EVALUATED — INHERITED |
| `78cf9896` | `nvn_mtl.m` / present | Present-ring slot holds displayed sub-image rather than full drawable. | EVALUATED — INHERITED |
| `2b93ebaa` | `nvn_mtl.m` / pacing | Present beat follows display-link pacing frame accurately (avoids stale sleep lead). | EVALUATED — INHERITED |
| `0cedee77` (`PR #2219`) | `nvn_mtl.m` | Fixes GPU watchdog spurious abort on raced monotonic clock read. | EVALUATED — INHERITED |
| `e884aa41` + follow-up | `nvn_render_stream.h` | Lowers `RS_SPIN_DEFAULT_US` from `200` to `20` µs for OOT (spin **77% -> 48%**) and BotW 1.9.0 M4 Max (spin **62% -> 51%**, CPU pkg **10.7 -> 10.3 W**, p50 **9.5 -> 9.25 ms**). Left TOTK/NS2 at `200`. | EVALUATED — **ADAPT** for Switch 1 TOTK (`!GAME_NS2 && !TOTK_GAME_V143`, since `GFX_OBJECTS` compiles without `-DTOTK_GAME_V111`). Integrated (`d6d9dff2`). |
| `e7cb8ebd`, `f86d2baf`, `6668ce7d`, `0581c1ef` (`PR #2297`), `84392376`, `96687dfa`, `cee07b61` | `assets/` / shader-libs | Updated `pso_manifest.tsv` / shader lists, express shader-lib updates. | EVALUATED — INHERITED |
| `d08b4afb` (`PR #2227`), `12adc714` (`PR #2222`), `20e9eda0` (`PR #2145`), `a415ae73` (`PR #2303`), `97eafb63` | input / HDR / RomFS / Launcher | Optional DSU controller, HDR Auto mode, ellipsis layout fix, express HUD mask index check, Launcher 1.1.4. | EVALUATED — INHERITED |

### (b) Other games / platforms only (no action needed beyond keeping shared tree synced)

- OOT mesh/task stages, v28/v29 translator changes (`778ab5f9`, `02989095`, `f361b840`, `d47c358b`), OOT VR arms/head-look (`ef59fa72`, `c734e0fe`), OOT AV1 `dav1d` (`39d05533`), OOT Metal 4 archive (`9b666aa0`) -> **EVALUATED — SKIP (OOT only)**.
- BotW 1.6.0/1.9.0 fixes (`437c66d0`, `6ecb27c1` `#2264` 8 allocator slots, `71f2dc51` `#2261`) -> **EVALUATED — SKIP (BotW only)**.
- Switch 2 / ACNH / XC3 / Odyssey / LM3 / TMNT / Skyward Sword / Witcher 3 / iOS picture profiles -> **EVALUATED — SKIP (other games / iOS)**.
- **Note on `zeldaVR/`**: upstream `97eafb63` added `zeldaVR/gfx/vr_depth_stereo.{h,m}` referenced by `nvn_mtl.m`; `games/totk/zeldaVR` MUST stay a synced real untracked directory (not a symlink).

### (c) 1.4.3-only changes (`71a5da8c..97eafb63`)

- `8d2c4321` (`feat(vr): TotK 1.4.3 depth stereo on key U`), VR depth reprojection -> **EVALUATED — SKIP (`1.4.3` + Quest VR only)**.

---

## 2. Upstream Open Pull Requests (`ly05010419/MacNativeGames`, 71 open as of 2026-11-24)

| PR | Author | Title / Scope | Split | Verdict | Reason |
| --- | --- | --- | --- | --- | --- |
| `#485` | `@lakuch` | `perf(totk): key 5 MetalFX TAA scaler built in background & cached per size` (`totk_taa.m`) | (a) | **ADAPT** (`ec9defe1`) | Eliminates 133–218 ms submit-thread hitches & rebuilds across dynamic/menu res switches; adapted onto upstream's reactive-mask + `dh[2]` `ensure_scaler` signature (`97eafb63`). |
| `#185` | `@lakuch` | `fix: CPU texel reads/writes copy only the region` (`nvn_deswizzle.{c,h}`, `nvn_mtl.m`) | (a) | **SKIP** | Upstream already has `texels_gpu_region` (>=1 MiB) + `texels_unpack_guarded` (`sigsetjmp` fault guard); `#185` edits `shared/`/`tex` without fault guard and risks provenance checks. |
| `#791` | `@humanperzeus` | `fix: release type views unused for 64 submissions` | (a) | **SKIP** | Measured on Odyssey; PR author explicitly notes *"Tears of the Kingdom and Bayonetta 3 do not rebuild views this way, so for them this is a guard"* (TOTK log shows 0 churn). |
| `#2191` | `@Enokine` | `perf: mid-pass split while GPU idles` | (a) | **SKIP** | Tested on BotW 1.9.0; maintainer `@ly05010419` closed/parked it because at 60 fps cap it gains zero frame time and costs **~2 W more power** with keep-alive on. |
| `#753` | `@HopeSuffers` | `perf: frame pipelining (TOTK_PIPELINE=1, draft, off)` | (a) | **SKIP** | Large 16-file draft still unbenchmarked against upstream preemption `#488` / `TOTK_SYNC_LAG`; high complexity/risk for locked 60 fps. |
| `#1255` | `@Flowershangfromthebranches` | `perf(totk): TOTK_BLOOM_NATIVE=1 compute bloom chain` | (a) | **SKIP** | Opt-in off by default, M3 Air -0.7 ms GPU at 1080p, relies on shader-key / format assumptions; unnecessary at locked 60 fps on M5 with GPU p95 < 15 ms. |
| `#1326` | `@LENG-ZECHEN` | `fix(totk): start-up race guard (1.0.0 / 1.2.1)` | (c)/(a) | **ADAPT (via `83c08b27`)** | Exact `v111` equivalent mapped and integrated in `game_patches.c` (`main+0x7f9dd8` -> `0x7fa320`, veneer `+0x2b282d0`, caller `0x7ece5c`). |
| `#1328` | `@subyoung` | `feat: TOTK_FPS_RECORD=<file.csv>` | (a) | **SKIP** | Diagnostic CSV logger; existing `totk.log` + `TOTK_TIMELINE` already measure frame stats without extra code surface. |
| `#589` | `@relay4` | `Fix macOS Game Mode activation for packaged games` | (a) | **SKIP** | Largely superseded (`launcher.m` already links directly into `totk-native-v111`), remaining bundle startup refactor adds high conflict churn. |
| `#2359`, `#2315`, `#2302`, `#2281`, `#2280`, `#2276`, `#2257`, `#2156`, `#2064`, `#1474`, `#1457`, `#1374`, `#1632`, `#1006`, `#800`, `#638`, `#545`, `#68`, `#22` | various | Switch 2 Pro BLE, spatial audio, stick cal, notch fullscreen, auto aspect, inventory/merchant UI aspect, Cmd+P pause, virtual amiibo, async-shaders UI, progress sync, 1.4.3 mouse/auto-attach/cheats, hub app | (a)/(b)/(c) | **SKIP** | Non-perf features, UI/controller features outside scope, unreviewed/unmerged WIP, or 1.4.3/1.0.0-specific. |
| `#2353`, `#2339`, `#2324`, `#2272`, `#2266`, `#2245`, `#2243`, `#2231`, `#2210`, `#2193`, `#2169`, `#2164`, `#2151`–`#2147`, `#2128`, `#2080`, `#2076`, `#2031`–`#2025`, `#1906`, `#1890`, `#1852`, `#1752`, `#1689`, `#1679`, `#1585`, `#1543`, `#1427`, `#1354`, `#1297`, `#647`, `#645`, `#627`, `#617`, `#509`, `#342`, `#325` | various | LM3 / NUP / OOT / Emio / Dread / BotW / XC3 / Engage / Kirby / Odyssey / By3 / DKB / AOC / NS2 / iOS / launcher visuals | (b) | **SKIP** | Other games / iOS / launcher UI only. |

**Merged PRs checked (`71a5da8c..97eafb63`)**: `#2295` (`634fe525`), `#2293` (`c5200bbc`), `#2341` (`b177ea53` / `671fb2c2`), `#2338` (`9c85d5c3`), `#2305` (`3657c12f`), `#2107` (`7d3803ce`), `#2267` (`7933568a`), `#2297` (`0581c1ef`), `#2227` (`d08b4afb`), `#2222` (`12adc714`), `#2145` (`20e9eda0`), `#2219` (`0cedee77`), `#2264` (`6ecb27c1`), `#2261` (`71f2dc51`) — all already landed cleanly via rebase onto `97eafb63`.

---

## 3. Fork Network (`178` forks ahead; `Pressburg` = 0 forks) & External Projects

### Fork network scan findings (no independent `1.1.1` / `v111` port found anywhere except `Pressburg`)

| Source / Commit | What it does | Verdict | Reason |
| --- | --- | --- | --- |
| `lakuch` `de8d30c7` | Restores `1/120 s` floor on real-time `frame_step` (`8333333 ns`). | **TAKE** (`ac230426`) | Prevents ultra-short present deltas from collapsing physics step below 1/120 s; 1-line safe guard in `game_patches.c`. |
| `LENG-ZECHEN` `83c08b27` (also PR `#1326`) | Null-check guard on startup race (`ldr x22, [x0, #0x2b0]` vs `cbz x0` trampoline). | **ADAPT** (`ac230426`) | Exact `v111` instruction sequence verified at `main+0x7f9dd8` (`0xf9415816`, prologue `sub sp, #0x8b0` @ `0x7f9da8`, epilogue @ `0x7fa320`, caller `0x7ece5c`), veneer at `+0x2b282d0`. |
| `HopeSuffers` `d4bb9982` | `TOTK_RS_POOL` (default on): batch up to 256 packets per `@autoreleasepool` in `rs_worker` (`nvn_render_stream.h`). | **TAKE** (`5cfe32fa`) | Removes per-draw/packet `objc_autoreleasePoolPush/Pop` (~50/750 busy worker samples in Kakariko profile) while draining before final packet consumption on `rs_sync`. |
| `BennettStaley` `76c69018` | `TOTK_RES_BATCH` (default on): atomic split `RES_DIRTY_ADD` / `RES_DIRTY_REMOVE` residency dirty flag; removal-only commits deferred off chunk-split path to end-of-submission background serial queue (`nvn_mtl.m`). Skipped `TOTK_MATH_MODE` half. | **ADAPT** (`daf8e480`) | Eliminated synchronous `[g_res commit]` kernel calls during chunk splits (measured **4.38–8.71** deferred/clean commit points/frame in play); kept `stor_alias_collect()` + `#if NVN_FILE_WIRE` safety. Skipped `TOTK_MATH_MODE` (non-safe math breaks TOTK shaders). |
| `HopeSuffers` `c10eda9c` | Guard `reduced` (`mipmapLevelCount` / `pixelFormat`) behind `pk->owned` in `tex_mtl` (`nvn_mtl.m`). | **TAKE** (`a860ef5a`) | Skips 2 ObjC property sends per CPU-written texture lookup; both consumers already check `pk->owned`. |
| `HopeSuffers` `18a6a4ab` | `TOTK_ENC_LOCK1`: wrap both vertex & fragment `encode_args` calls in `draw_inner` under one re-entrant `registry_lock()`. | **TAKE** (`a8078238`) | Reduces 4 lock/unlock pairs per draw down to 1 (~40 samples including wait contention in Kakariko profile). |
| `HopeSuffers` `51d5e36e` | `TOTK_PSO_MEMO2`: per-`NvProg` 2-entry LRU `(gen, key, ps)` cache eliminating 256-slot global collisions (`nvn_mtl.m`). | **TAKE** (`6243cbba`) | Lifted `pso-memo` hit rate to **94.0%–96.6%** in our verified run (vs ~37% reported in `HopeSuffers` pre-fix Kakariko trace); `=2` verification mode retained. |
| `BennettStaley` `e9b8eafa` | `nvn_dirty_check`: single `find()` lookup returning `-1` untracked or `0/1` dirty status in `tex_mtl_p`. | **ADAPT** (`d483f47d`) | Upstream already had `BLK_SHIFT`/`r->blk` chunk skipping + `FIND_HASH`, so adapted to reuse `pages_since` (zero extra per-MB allocation + `#if NVN_DIRTY_SPLIT` fallback) + added `chunk_check` test in `probe-dirty-race` (`24/24` pass). |
| `HopeSuffers` `7c344d78` | `mtl_pool_add` retry | **SKIP** | Already present verbatim in `upstream/main` (`nvn_mtl.m:1324-1330`). |
| `HopeSuffers` `9af845fa` | `TOTK_BORDER_PLAN` | **SKIP** | Superseded by `upstream/main`'s `NvBorderKeyCache` (`nvn_mtl.m:10293`). |
| `HopeSuffers` `126a880d`, `b5df2c2f`, `291d407a`, `751b3b5e`, `b32b7032` | `tex_mtl_p`/ARC trim (`rp_begin_ex`), `TOTK_USNAP_BATCH`, `TOTK_SPLIT_EARLY`, 8-byte `nvn_hmap`, `TOTK_FLATTEN_FAST` | **SKIP** | Already superseded/present in `upstream/main` (`97eafb63`: `nvn_mtl.m`, `nvn_hmap.h:24`, `hle_nvn.c:1248`). |
| `HopeSuffers` `3b82c516` (`archive/perf/gamehot`) | `TOTK_GAMEHOT` (1.2.1): host-side hinted RSDB `Row *find_first(Query *)` veneer | **SKIP** | High-surface unmerged guest C++ vtable hook (~670 lines, mapped only for `1.2.1` `main+0x7f3688`, requires full `1.1.1` disassembly & struct layout verification). |
| `BennettStaley` `1e1c8b20` | `ea_bind_loop` optimization | **SKIP** | High diff churn in `encode_args`; mostly subsumed by upstream `arg_epoch` + `tex_slots` caching. |
| `tvc97` `03233fa5` / `3a5d46f6` | `g_pso_guess` drain + Oct-21 `nxnative` perf bundle | **SKIP** | `SignalToAddress -2` (`threads.c`), `nvn_depth_clear.h`, `0006` texel fix, and `pso_pend_reclaim` are already upstream; remaining full-pass color lazy-clear had serial-vs-memory aliasing risk and `nvnQueueFinish` skipping queued presents carried swapchain-pool UAF risk. |
| `lakuch` `5017066c` | Default `TOTK_ASYNC_REPLAY=1` on Mac | **SKIP** | Upstream evaluated 2026-11-03 after Oct 24 and kept `TOTK_ASYNC_REPLAY` off by default (`hle_nvn.c:2688`). |
| `DavidZande` `6a87c040` | `TOTK_LAG_READBACK=2` | **SKIP** | Targeted old 1.0.0 readback lag regression; unnecessary overhead with current upstream readback fencing. |
| `luiszimmermann` `a26c3976` | `TOTK_CS_HOIST` compute-dispatch hoist | **SKIP** | Experimental/parked (-1.1% GPU by campfire only), touches shader/table scheduling with regression risk. |
| `Pressburg` `44f57d65` | Default 60 fps patch branch | **SKIP** | Upstream already supports `graphics-frame.txt` `lock-60` (and user profile already sets `lock-60`). |
| `alabastida` `e40a7c7e` / `LENG-ZECHEN` `731e36d1` / `TAKAGIVEGETA` `f64be6fe` / `oneincase` `f5fc7dd8` / `liafonx` `36581152` | 1.0.0 heap / 1.2.1 build / 1.4.3 clarity filters / scenecap / BotW+TOTK button icon overlay | **SKIP** | Version-specific, diagnostic, or cosmetic only. |

### External / Web-Search Projects Evaluated

| Project / Commit | What it does | Verdict | Reason |
| --- | --- | --- | --- |
| `iceorange-dev/manosaba-ios` `80713081` (MIT, Batch 191) | Skip `mtl_gpu_addr` pool lookup on `NVN_RB_CBUF` when `upd_shadow` or `usnap_find` already resolved the GPU address (`encode_args`). Measured **-1% replay instructions** and **5.19–5.25 -> 5.04–5.13 ms/frame** on Great Sky Island M5. | **ADAPT** (`0feb4aa1`) | Ported with safety guards keeping `mtl_gpu_addr` active whenever `ui_mat`, `bl` (`passdump`/`CBDUMP`), `g_res_check_on`, `watch_fs_prefix()`, or `g_vr_ui_ray_draw` needs `mb`/`mo`; MIT attribution added to `THIRD_PARTY_NOTICES.md`. |
| `iceorange-dev/manosaba-ios` `8cbad37e`, `e683f231`, `abf039b4` (Batches 188, 194, 195) | Memoryless depth targets (`manosaba` only), dynamic-res shrine diagnostic (`305`), split `mtl/present.m` translation unit + `DM_FRAME_STEP=vsync` (`321`) | **SKIP** | Explicitly leaves TOTK unchanged (TOTK loads/samples depth); `321` (`vsync` frame step) is `manosaba`/`DM_FRAME_STEP` specific; `264` refactor is internal file layout only. |
| `seedds/nxnative` (`4f4d23a8`, `3a7e53d3`, `e49e4814`, `c1bd080a`, `a359f9e6`, `5ccb82ad`, `0b09b66d`, `685d2aec`, `973f2d73`) & `ChiefSZ13/nxnative` | Lock-free `tid_ser` passdump, `fb_view`, `sh_lists_make`, `vs_streams`, `t_pc.w`, raw pointers, Switch 2 mesh/depth experiments | **SKIP** | Core wins (`stor_sampling_view`, `texture_slots`/`guard_idx`, `vertex_stream_mask`, `pool_tls_find`, `prog_get_p`/`pso_get_p`/`tex_fast_rid`, `registry_lock` in `encode_args`, `0006`/`0007`) are already superseded upstream in `97eafb63`; remainder are NS2/experimental. |

---

## 4. Integrated Stack & Port Surface on `totk-1.1.1-port`

Commits on top of `upstream/main` (`97eafb63`):

1. `7af40e4f` `feat: 1.1.1 port on upstream 97eafb63`
2. `ac230426` `fix(totk): guard 1.1.1 boot race (LENG-ZECHEN 83c08b27) and 1/120 s frame-step floor (lakuch de8d30c7)`
3. `ec9defe1` `perf(totk): build TAA scalers off submit thread and cache last 4 sizes (PR #485)`
4. `d6d9dff2` `perf(totk): reduce render-stream empty spin cap to 20 us (upstream e884aa41)`
5. `5cfe32fa` `perf(totk): batch render-stream autorelease pool up to 256 packets (HopeSuffers d4bb9982)`
6. `daf8e480` `perf(totk): batch removal-only residency commits off chunk-split path (BennettStaley 76c69018)`
7. `a860ef5a` `perf(totk): guard reduced-copy texture checks behind pk->owned (HopeSuffers c10eda9c)`
8. `a8078238` `perf(totk): wrap vertex+fragment encode_args under single registry lock (HopeSuffers 18a6a4ab)`
9. `6243cbba` `perf(totk): add per-program 2-entry PSO memoization (HopeSuffers 51d5e36e)`
10. `0feb4aa1` `perf(totk): skip uniform pool lookup when upd_shadow or usnap supplies GPU addr (manosaba-ios 80713081, MIT)`
11. `d483f47d` `perf(totk): combine tracked and since into single-lookup nvn_dirty_check (BennettStaley e9b8eafa)`

Core port & optimization files modified relative to `97eafb63`:
- Upstream-watch & docs/policy: `AGENTS.md`, `THIRD_PARTY_NOTICES.md`, `games/totk/docs/v1.1.1-port.md`, `games/totk/docs/upstream-watch.md`, `.gitignore`, `games/totk/zeldaVR` (kept as real untracked synced directory; symlink removal tracked)
- 1.1.1 rewriter/runtime/builder surface: `build_app.py`, `games/totk/Makefile`, `games/totk/assets/expected-v1.1.1.json`, `games/totk/runtime/game_version.h`, `games/totk/runtime/game_patches.c`, `games/totk/scripts/{game_version_test.py,make_mod_manifest.py,make_output_res_overlay.py,make_romfs_patches.py,patch_sites.py,prepare_romfs_backend.py,prepare_runtime.py,prepare_shared_fonts.py,test_exclusive_windows.py,verify_boot.py,verify_cloth_clock.py,verify_loader.py,verify_rewrites.py,verify_romfs.py}`
- Shared graphics / probe improvements: `games/totk/third_party/d2r_gfx/gfx/nvn/{totk_taa.m,nvn_render_stream.h,nvn_mtl.m,nvn_dirty.h,nvn_dirty.c}`, `games/totk/tests/dirty_race/probe.c`

---

## 5. Verification Snapshot (`2026-11-24`)

- Built `/Users/admin/Documents/Nintendo/Tears of the Kingdom 1.1.1.app` (`--native-4k`, 27,408 `applegpu_g17g` pipelines in 59 s, 0 failed).
- Verified clean title screen (`Continue / New Game / Options / amiibo`) and end-to-end save load into **Eldin Canyon** (`1642, 3408, 0318`) using isolated profile copy (`TOTK_PROFILE_DIR`) + `TOTK_CLOUD_SAVE_DIR=0`.
- Player preferences preserved untouched (`1440p`, `lock-60`, `graphics-taa=1`, `picture-mode=off`, MetalFX upscaling/interpolation/TAA key 5 off).
- Observed in-run metrics: `TOTK_PSO_MEMO2` **96.35%** hit rate (`344,539 / 357,575`); `TOTK_RES_BATCH=1` avoided **8.71** synchronous commits/frame on spawn frames 1200–1800; PR `#485` moved **218.5 ms** (`2560x1440`) & **177.4 ms** (`2048x1152`) TAA scaler builds off the submit thread and served subsequent switches from cache (`0 ms`).
