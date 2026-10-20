# FMOD dans Godot_Blocks : ce qu'il faut savoir et les crashs connus

Extrait (17/10/2026) des notes techniques du projet écrites en avril 2026 avec Godot 4.6 ; tout reste valable en Godot 4.7.2 avec le plugin FMOD 6.1.0. En anglais, tel quel. Les chemins `.godot/editor/editor_layout.cfg` et le script shell sont relatifs au dossier du projet.

---

## FMOD integration — things to know

- **Bank location**: `res://Sons & musiques/Fichiers FMOD/FmodBank/Desktop/Master.bank` (+ `Master.strings.bank`). Configured under `[Fmod]` in [project.godot](project.godot).
- **Events in the bank** (as of last bank refresh): `event:/Footsteps`, `event:/MusiqueNiv1`, `event:/ObjectCatch`, `event:/ObjectLoop`. `MusiqueNiv1`, `ObjectCatch`, and `Footsteps` are wired up. `ObjectLoop` exists in the bank but isn't used anywhere. `play_footstep_sound()` in [JoueurDemo.gd](Scènes/Demo_Prof/JoueurDemo.gd) is a dead placeholder — the real footstep logic is in `_physics_process` using `FmodEventEmitter2D_footsteps` (see emitter nodes below).
- The bank is loaded at runtime by the `FmodBankLoader` node inside `Demo_Prof.tscn` — **not at editor start**. This matters (see Known crashes below).
- **Event vs parameter naming** — this is the single most common source of confusion:
  - `event:/MusiqueNiv1` is the **event path** (the music track).
  - `MusiqueEtat` is the **parameter** inside that event, with labels `Vide`, `Etat1`, `Etat2`, `Etat3`, `Etat4`.
  - `set_parameter(name, value)` takes the parameter name as the first arg. Passing the event name (`"MusiqueNiv1"`) silently fails with `Cannot set parameter MusiqueNiv1 to value 0.000000` — the plugin coerces the label string to float `0.0`. Always verify in the "Fmod banks explorer" window inside Godot.
- **Local vs global parameters — critical distinction** (different API for each, and the banks explorer is misleading):
  - **Local parameter**: declared inside a single event, drives that event only. Set it on the emitter:
    ```gdscript
    $FmodEventEmitter2D_music.set_parameter("MusiqueEtat", "Etat1")
    ```
  - **Global parameter**: declared at Studio-project level, shared by any event that references it. Set it on the Studio system via the plugin's global API:
	```gdscript
	FmodServer.set_global_parameter_by_name("Hauteur", value_float)
	```
	Setting a global affects **every** event that references it simultaneously. If you need per-object behaviour (e.g. different objects' heights), use true local parameters or multiple distinct globals.
  - **Gotcha**: the Fmod banks explorer in Godot lists referenced globals *under the event's parameter list*, right next to true locals. You cannot tell them apart in that window. Calling `emitter.set_parameter("Hauteur", ...)` on a referenced global fails with `Cannot set parameter Hauteur to value X` — the plugin only calls `EventInstance::setParameterByName`, which refuses globals.
  - **How to tell them apart**:
	- In FMOD Studio: the truly local parameters are declared in the event's own Parameters tab; globals appear in the left-sidebar *Global Parameters* tab at project level. An event "references" a global → it shows up in both places.
	- In the banks explorer in Godot: a `Range: [0.0, 100.0]` line with no labelled `Values` is a strong hint it's numeric/continuous → usually global. A `Values: [Vide, Etat1, ...]` list is usually a labelled local (though not always — labels exist for globals too).
	- Rule of thumb: if `emitter.set_parameter(name, ...)` errors, try `FmodServer.set_global_parameter_by_name(name, ...)` before doubting the parameter exists.
  - **Plugin API reference** (extracted from `libGodotFmod` editor binary):
	- `emitter.set_parameter(name, value)` → local parameters only.
	- `FmodServer.set_global_parameter_by_name(name, float)` / `_by_name_with_label(name, String)` → globals.
	- `FmodServer.get_global_parameter_desc_list()` → enumerate declared globals at runtime (useful for debugging which ones exist).
- **Built-in automatic parameters — never set them manually**. FMOD drives these itself, and any `set_parameter("Distance", ...)` call is refused per-frame with `Cannot set parameter Distance to value X.Y`. They still *work* (the event's automation on them keeps running), so the sound is correct — the log just floods with errors from the rejected sets. The reserved names are:
  - `Distance` — auto-computed from `FmodEventEmitter3D` ↔ `FmodListener3D` distance.
  - `Direction`, `Elevation` — listener-relative direction/elevation to emitter.
  - `Event Cone Angle`, `Event Orientation`, `Listener Orientation` — orientation-driven.
  - `Speed`, `Speed (Absolute)` — driven by emitter velocity.

  If you need a distance to something other than the listener (e.g. distance to a specific object), create a **custom local** parameter under a different name — e.g. `DistancePlayer` — and set that on the emitter. It won't conflict with the built-in. Precedent: we removed a manual `set_parameter("Distance", ...)` call from [Ground_Collectible.gd](Scènes/Demo_Prof/Ground_Collectible.gd) — FMOD's built-in Distance already drove the event's automation; the manual call only served to spam the error log.
- **Emitter nodes** on `JoueurDemo` inside `Demo_Prof.tscn`:
  - `FmodEventEmitter3D_reward` — `event:/ObjectCatch`, triggered on collectible pickup via `.play()` in `Play_Feedback_Sound()`.
  - `FmodEventEmitter3D_ambiance` — old music emitter for `event:/MusiqueNiv1`. **Never played** — all `set_parameter` calls to it are commented out; the matching `.play()` call was removed when `FmodEventEmitter2D_music` was added. It's dead weight in the scene.
  - `FmodEventEmitter2D_music` — active music emitter for `event:/MusiqueNiv1`. `_ready()` sets `MusiqueEtat` to `"Etat1"` and calls `.play()`. Parameter `MusiqueEtat` (local, labeled) advances on pickups.
  - `FmodEventEmitter2D_footsteps` — added by Alexia, points to `event:/Footsteps`. `_ready()` calls `.play()` with `CharacterWalk = "CharacterFly"` (silent). `_physics_process` toggles it to `"CharacterWalk"` when `is_near_ground()` is true. Parameter `CharacterWalk` is **local** (labeled `[CharacterFly, CharacterWalk]`) → use `emitter.set_parameter`, not `FmodServer`.
- **`fmod_parameters/<name>/*` cache in the scene** — the plugin re-generates these lines when you click the emitter in the inspector. Don't be surprised if deleting them makes them come back. That's normal and usually harmless; they reflect the current bank state. They only cause crashes when the bank isn't loaded yet when the plugin tries to resolve the param id (see Known crashes).


---

## Known crashes and gotchas

### 1. Editor crashes on launch opening `Demo_Prof.tscn`

Signal 11 inside `libGodotFmod.macos.editor` → `Object::get_property_list` → `EditorFolding::_fill_folds` → `EditorNode::_load_open_scenes_from_config`.

Cause: the editor tries to restore scenes from [.godot/editor/editor_layout.cfg](.godot/editor/editor_layout.cfg)'s `open_scenes`. Before the FmodBankLoader has run, the plugin can't resolve the emitter's event GUID, logs `Cannot find event with guid {...} and path .`, then segfaults on the next property access.

Workaround: clear `open_scenes` and `current_scene` in [.godot/editor/editor_layout.cfg](.godot/editor/editor_layout.cfg). The editor then boots empty and the user opens scenes manually (first open a non-FMOD scene to load the bank, then `Demo_Prof.tscn` opens fine). Note: `.godot/` is auto-regenerated by Godot, so this fix can recur — the editor will re-add the last-opened scene to `open_scenes` on next clean exit, and if the crash happens again you have to clear it again.

A proper fix would be getting the plugin to load the bank earlier (e.g. `@tool` bank loader) but we haven't done that.

### 2. Editor crashes on `Cmd+S` save (and sometimes on launch — see 2b)

Same root cause as #1 — the scene serializer walks property lists and hits a moment where the plugin can't resolve the event/param. Intermittent; often triggered when the bank is mid-load.

### 2b. Editor crashes after every bank refresh (stale `fmod_parameters/*/id`)

Short summary here; the full investigation, fix options, and action plan live in **["FMOD bank-refresh crash — full investigation and fix plan"](#fmod-bank-refresh-crash--full-investigation-and-fix-plan)** below. Read that section before attempting any fix.

Reproducible variant of #2, triggered any time the FMOD bank is rebuilt — whether by you locally or by Tom upstream:

- FMOD assigns each parameter two identifiers: a **GUID** (stable across rebuilds) and an **internal numeric ID** (a hash that changes every build).
- The plugin caches the numeric ID into the scene file (`fmod_parameters/MusiqueEtat/id = -1166093049719065838`). This cache is written by the inspector when you click an emitter.
- After a bank rebuild, that cached ID is stale. The plugin calls `FmodEventDescription::get_parameter_by_id(stale_id)`, gets null, doesn't null-check → SIGSEGV inside `Object::get_property_list`.

Short-term workaround: delete the four `fmod_parameters/<ParamName>/*` lines from the scene's emitter section (`id`, value, `labels`, `variant_type`). Plugin regenerates them with the new ID on next emitter click.

### 3. Editor crashes when clicking an FmodEventEmitter node in the scene tree

Same root cause — inspector calls `get_property_list` on the node.

### 4. `Cannot set parameter X to value <Y>` at runtime

Four separate causes produce this same-shaped error; the value in the message tells you which:
- **Value is `0.000000` and you're not setting 0**: you passed an event path or a misspelled label as the parameter name. The plugin coerces the unknown label string to float `0.0`. Verify the real parameter name in the banks explorer.
- **Value matches what you passed, parameter is one you added yourself (e.g. `Hauteur`)**: the parameter is **global** (or a reference-to-global inside the event), not local. Use `FmodServer.set_global_parameter_by_name(name, value)` instead of the emitter API. See "Local vs global parameters" above.
- **Value matches what you passed, parameter name is one of FMOD's built-ins (`Distance`, `Direction`, `Elevation`, `Speed`, etc.)**: you cannot set built-in automatic parameters manually; FMOD drives them itself. Remove the manual set call — the built-in will keep working. See "Built-in automatic parameters" above.
- **`str()` wrapping on a numeric parameter**: calling `emitter.set_parameter("Hauteur", str(my_float))` passes a String, not a float. FMOD's `setParameterByName` expects a `float` for numeric parameters. Always pass the raw float: `emitter.set_parameter("Hauteur", my_float)` or `FmodServer.set_global_parameter_by_name("Hauteur", my_float)`. Precedent: `str(temp_hauteur_fmod)` was the original code before the fix.

### 5. `Failed to open port /dev/tty.debug-console: Device or resource busy`

Benign. The port is held by the system. With the port filter now in place, we don't try this port any more, so the error should no longer appear.

## FMOD bank-refresh crash — full investigation and fix plan

This is a self-contained write-up meant to survive context compaction. If a future session has to pick this up cold, start here.

### What the user sees and when

- The crash reproduces every time the FMOD bank is rebuilt. It happens whether the rebuild is **local** (user clicks Build in FMOD Studio) or **remote** (user pulls a new `Master.bank` that Tom built). The crash trigger is the bank rebuild itself — the git layer is not involved.
- Reliable reproducer:
  1. Open `Master.fspro` in FMOD Studio, make any trivial change (or no change), press Build (or the user clicks "Refresh Banks" in Godot's FMOD banks explorer).
  2. Open Godot. Either:
	 - It crashes immediately as soon as `Demo_Prof.tscn` is restored from `open_scenes`, **or**
	 - It boots fine, then crashes the moment the user saves (Cmd+S), **or**
	 - It boots fine, then crashes the moment the user clicks any `FmodEventEmitter*` node in the scene tree (inspector opens → property list walked → crash).
- User-facing symptom: native macOS crash dialog, Godot disappears. No error dialog in the editor — the process dies. Log goes to stderr (only visible if launched from CLI).
- User's ask: "Do we need to correct the scene manually every time? Or do you have a long-term fix?"

### Log signature (the smoking gun)

Launch Godot from CLI to capture the log:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path "/Users/mourdjenbari/Documents/Godot_Blocks" --editor 2>&1
```

The line immediately before the SIGSEGV stack is always of the form:

```
ERROR: Cannot get parameter <NUMERIC_ID> description for event event:/<EventName> with guid {<GUID>}
Ref<FmodParameterDescription> godot::FmodEventDescription::get_parameter_by_id(uint64_t) const
  src/studio/fmod_event_description.cpp:164
```

The `<NUMERIC_ID>` (e.g. `-1166093049719065838`) matches the `fmod_parameters/<Name>/id = ...` line currently in the scene file — that's the stale ID.

Representative backtrace (from one of our crashes, 2026-04-21, save-crash path):

```
[1] libsystem_platform.dylib  _sigtramp
[2] libGodotFmod.macos.editor fmod_library_init + 46772
[3] libGodotFmod.macos.editor fmod_library_init + 42568
[4] Object::get_property_list(..., bool) const           ← plugin's get_property_list dereferences null
[5] SceneState::_parse_node(...)
[6] SceneState::_parse_node(...)
[7] SceneState::_parse_node(...)
[8] SceneState::pack(Node*)
[9] EditorNode::_save_scene(String, int)                 ← save-path crash variant
[10] EditorNode::_save_scene_with_preview(...)
[11] EditorNode::_menu_option_confirm(...)               ← triggered via Cmd+S shortcut
```

The launch-time variant is almost identical; frames 9–10 are replaced by:

```
[9]  EditorFolding::_fill_folds(...)
[10] EditorFolding::save_scene_folding(...)
[11] EditorNode::_set_current_scene_nocheck(int)
[12] EditorNode::_load_open_scenes_from_config(...)
```

The inspector-click variant replaces frames 9+ with a `PropertyEditor → InspectorDock::_inspector_edit` chain. Same root bug, different caller.

### Root cause, deeper

FMOD assigns each parameter two identifiers:

| Identifier | Stable across rebuilds? | Plugin uses it for... |
|---|---|---|
| GUID, e.g. `{57ca7ceb-50fb-4a88-97d8-9fcf860de541}` | **Yes** — FMOD computes it once when you create the parameter and never changes it. | Looking up the event/parameter in banks at runtime. Stored in scene as `event_guid = "{...}"`. |
| Numeric ID (uint64, e.g. `-1166093049719065838`) | **No** — it's a hash (of the bank contents around this parameter) recomputed every build. | Fast parameter access after the first resolve. Cached into `fmod_parameters/<Name>/id = ...` in scenes. |

When you click an emitter in the inspector, the plugin's `get_property_list` does:
```
id = fmod_event_description->get_parameter_by_name("MusiqueEtat")  // returns a numeric id
cache `fmod_parameters/MusiqueEtat/id = <that id>` into the scene file
```

Next time the scene is saved / parsed, the plugin reads the cached id and does:
```
desc = fmod_event_description->get_parameter_by_id(cached_id)
```

On a stale bank, `get_parameter_by_id` returns `null`. The plugin **does not null-check** and dereferences the null reference to push its properties → SIGSEGV. This is a **plugin bug** — the `push_error` call you see in the log is the plugin's own "I couldn't find it" message, but it fires *before* the crash, meaning the plugin detects the failure but continues anyway.

Two locations in the plugin contribute:
- `src/studio/fmod_event_description.cpp:164` — returns null without aborting the caller.
- Wherever `get_property_list` calls it (not visible in our binary's strings dump) — dereferences the null Ref.

### Why simpler / obvious fixes don't work

| Attempt | Why it fails |
|---|---|
| Commit a fresh bank to git and pull. | The moment the user locally rebuilds the bank after pulling — or the moment FMOD Studio auto-rebuilds on save — IDs rotate again. |
| Git clean filter that strips `fmod_parameters/*/id` on commit (previously proposed as Option 2). | Helps with cross-user poisoning only. The user's own `Build` in Studio re-poisons their local working tree without involving git at all. Dropped from the recommendation list. |
| Clear `.godot/` and restart. | `.godot/editor_layout.cfg` re-adds `Demo_Prof.tscn` to `open_scenes` on clean exit, so the launch-time variant comes back unless you edit the cfg every time. Orthogonal anyway — doesn't address save-time or click-time variants. |
| Use only `event_guid` in scripts, skip the inspector. | The inspector still walks property lists whenever the scene tree is drawn, not just when you click. Any time the scene file is re-parsed after a bank rebuild, same crash path. |
| Downgrade plugin / switch FMOD version. | Not investigated in detail. Plugin version (libGodotFmod v6.1.0 — FMOD Studio 2.03.06) is what Tom has working on Windows, so the issue isn't a macOS-only plugin version mismatch. |

### What the user has told me they need

Direct quotes / paraphrases from recent turns (for recall without re-reading transcript):
- "Everytime we import a bank, do 'refresh bank' in the plugin, then save, Godot crashes when saving."
- "It's happening when we import a new bank ourself as well" — ruling out the git-only theory.
- "Do we need to correct the scene manually every time? Or do you have a long-term fix?"
- Implicit: a fix should also work for **Tom on Windows** (he'd hit the same class of bug if he rebuilt banks locally).
- Implicit: the user is comfortable editing scripts, running shell commands, editing `.gitattributes`. They have not expressed willingness to patch the plugin's C++ and rebuild it.

### Fix plan (recommended order)

Start small, escalate only if needed. Every step is additive — doing step 1 doesn't block adding step 2 later.

#### Step 1: deploy a strip-before-open shell script (RECOMMENDED FIRST)

A single-file `sed` script that walks every `.tscn` and deletes all `fmod_parameters/<name>/*` cache lines. The plugin regenerates them with the new ID on the next inspector click, after the new bank is loaded.

**Script content** (tested-shape, not yet deployed):

```bash
#!/usr/bin/env bash
# strip_fmod_param_cache.sh
# Deletes stale per-emitter parameter caches from all .tscn files.
# Safe to run at any time — the plugin regenerates the cache on next emitter click.
# Run this after every FMOD Studio Build, before (re)opening Godot.

set -euo pipefail
PROJECT_ROOT="/Users/mourdjenbari/Documents/Godot_Blocks"
cd "$PROJECT_ROOT"

# Match all four shapes of the cache line:
#   fmod_parameters/Foo/id = <int>
#   fmod_parameters/Foo/labels = PackedStringArray(...)
#   fmod_parameters/Foo/variant_type = <int>
#   fmod_parameters/Foo = <value>
find . -name "*.tscn" -print0 | xargs -0 sed -i '' -E \
	-e '/^fmod_parameters\/[A-Za-z_][A-Za-z0-9_]*\/(id|labels|variant_type) = /d' \
	-e '/^fmod_parameters\/[A-Za-z_][A-Za-z0-9_]*  *=/d'

echo "Stripped fmod_parameters/*/* from all .tscn — safe to open Godot."
```

Two habits to glue it into the workflow — pick one:

- **FMOD Studio post-build command**: Studio → Edit → Preferences → Build → Post-Build command → point it at `strip_fmod_param_cache.sh`. Runs automatically every time Studio finishes a Build. Zero friction afterwards.
- **Manual shell alias**: `alias fmodbuild='/path/to/strip_fmod_param_cache.sh'`. Run it after hand-building.

Caveats:
- The script is safe to run even when cache lines don't exist (sed deletes no-match lines silently).
- Run it while Godot is closed. Running while Godot is open is untested — Godot may have the scene file locked / may overwrite with its in-memory copy, undoing the strip.
- This does **not** fix the plugin null-deref. It just ensures the plugin never sees a stale ID, so the buggy code path is never taken.

#### Step 2: fswatch daemon to auto-run Step 1 on bank file change

Optional, set-and-forget variant of Step 1:

```bash
brew install fswatch
fswatch -o "Sons & musiques/Fichiers FMOD/FmodBank/Desktop/Master.bank" \
  | xargs -n1 -I{} /path/to/strip_fmod_param_cache.sh
```

Run in a terminal tab or wrap in a launchd plist. Any time `Master.bank` changes on disk, the strip runs. Works for both local rebuilds and `git pull` bringing in Tom's new bank.

Downside: another background process to remember. Worth it if the user forgets to run the script manually.

#### Step 3: Godot-side `@tool` watcher

If shell-level tooling is too fragile (e.g. forgotten on new machines, Windows setup for Tom), move the logic into a small `@tool` Godot plugin. Pseudocode:

```gdscript
@tool
extends EditorPlugin

const BANK_PATH := "res://Sons & musiques/Fichiers FMOD/FmodBank/Desktop/Master.bank"
var _last_mtime: int = 0

func _enter_tree() -> void:
	_last_mtime = FileAccess.get_modified_time(BANK_PATH)
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(_check_bank_mtime)
	add_child(timer)

func _check_bank_mtime() -> void:
	var now := FileAccess.get_modified_time(BANK_PATH)
	if now > _last_mtime:
		_last_mtime = now
		_strip_all_tscn_caches()
		print("[fmod-cache-stripper] bank changed, caches stripped.")

func _strip_all_tscn_caches() -> void:
	# walk res:// for *.tscn, run regex replace (same as the sed above),
	# save file via FileAccess.open(... WRITE). Avoid touching currently-open scene.
	...
```

Packaged as an `addons/fmod_cache_stripper/` plugin, enabled per-project. Ships with the repo, benefits Tom too (including Windows, where the shell script is harder to wire up). More work to write (~50–100 lines) but zero per-machine setup. Do this if the team grows or if Steps 1/2 keep getting forgotten.

#### Step 4 (proper root cause fix — high effort)

Two real plugin-side fixes, ranked by invasiveness:

1. **Null-check in `libGodotFmod`**: patch `FmodEventDescription::get_parameter_by_id` callers (starting with whatever `get_property_list` does internally) to bail out gracefully when the returned Ref is null. ~5–20 lines of C++. Requires building `libGodotFmod` from source for macOS (and ideally Windows) and replacing the `.dylib` / `.dll` in `addons/fmod/libs/`. Upstream PR would benefit every FMOD-Godot user. This does **not** require the other steps — it fixes the underlying crash and makes stale cache merely noisy, not fatal.

2. **Stop caching numeric IDs in scenes**: change the plugin to look up by parameter name (or GUID) each time instead of caching the numeric ID. More invasive (perf trade-off and API changes), but eliminates the failure mode entirely. Not attempted.

Neither is needed if Steps 1–3 keep running reliably; they're the "real" fix for someone willing to maintain a fork of the plugin.

### What to verify before deploying Step 1

Before committing the script, one-shot manually:

1. Back up Demo_Prof.tscn and any other scene with emitters.
2. Rebuild the bank in Studio.
3. Run the script.
4. Open Godot. Scenes should open without crash; the FMOD emitter inspector should repopulate `fmod_parameters/...` cache on click. Parameter calls at runtime (e.g. `MusiqueEtat`) should still work.
5. Save the scene. No crash.

If all five check out, wire the script into the FMOD Studio post-build hook and commit it to `scripts/strip_fmod_param_cache.sh` (or similar).

### Open questions / unknowns

- We have not verified that the plugin also poisons non-scene resources (e.g. `.tres`). The grep for `fmod_parameters/` in the current repo only hits `.tscn`, so the scope is probably limited to scenes, but worth confirming if new resource types are added.
- We have not verified Tom's Windows workflow experiences this same crash. If he does, the `.dll` has the same null-deref bug and Steps 1/2/3 would also need to run in his environment.
- We have not checked whether the plugin exposes a public "resolve all cached IDs" method that could be called at startup to re-hydrate caches without touching scene files. Worth grepping `strings libGodotFmod.macos.editor` for something like `refresh_parameter_ids` before committing to the strip approach — if it exists, a one-line `FmodServer.refresh_caches()` in an autoload could replace the whole plan.

