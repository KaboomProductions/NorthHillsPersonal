# Central keybind plan

Status: approved and implemented for source-owned application keybinds. Prompts were explicitly excluded by the user. Gun code removal was added to the approved scope. Studio playtesting remains outstanding.

Scope correction: pointer clicks, tool triggers, and GUI activation are not keybind-catalog entries. `ToolInput` owns one shared InputActionService action for mouse/R2/mobile activation across all tools. `Results` owns mouse/touch/R2/gamepad-confirm dismissal. Per-tool mobile actions have been removed. These actions still use the same InputActionService backend; historical audit details below describe the original snapshot.

Inventory compatibility fix: the bundled PlayerModule camera previously consumed `I` through its legacy CAS zoom handler. Per the user's follow-up, the `I`/`O` zoom bindings, associated keyboard state, and keyboard zoom calculation are now removed. The temporary inventory-key pass-through workaround and camera dependency on the keybind catalog were removed. Published-client verification remains outstanding.

## Outcome

Define application key assignments once and execute them through one system: the existing `ReplicatedStorage/SharedUtilities/InputActionService` module. Registration, action-state checks, press/release callbacks, mobile action buttons, and key hints must use that system and the catalog. Changing a hotbar key in the catalog must change both the accepted key and its badge after the next initialization.

Application controllers must not dispatch keybinds through UserInputService events/polling, ContextActionService, or ContextActionUtility. This replaces the earlier proposal to keep direct input listeners with a shared matching helper.

## Review completed

Read `CODEBASE_GUIDE.md`, `StyleGuide.md`, `CLEAN_CODE_GUIDE.md`, and the clean-code skill before preparing this plan. Traced application input definitions and consumers, the existing InputActionService adapter, mobile activation, hotbar labels, and prompt creation/display. Searched the source tree for key codes, action registration, direct input events, and configuration references.

The project-specific style guide resolves differences with the general guide: lowerCamelCase locals, functions, fields, and constants; PascalCase modules and types; direct requires; typed boundaries; small focused functions; `--//` comments only when necessary. Configuration stays separate from runtime ownership. Follow the existing controller lifecycle and track resources touched by this migration.

## Current binding inventory

Paths below are relative to `sync/ReplicatedFirst/` unless stated otherwise.

| Action | Current assignment | Current owner |
| --- | --- | --- |
| Sprint | LeftShift / ButtonL3 | `ClientData/ClientConfig.luau`; `Character/Movement/States.luau` registers and polls the same keys |
| Crouch | LeftControl, C / ButtonB | `ClientData/ClientConfig.luau`; movement controller |
| Toggle inventory | I | `ClientControllers/Character/Inventory/Input/Keybinds.luau` |
| Equip hotbar slots 1-10 | 1-9, 0 | Inventory input's `keySlots` table |
| Next / previous hotbar item | ButtonR1 / ButtonL1 | Inventory input |
| Drop / throw | Backspace / G | Inventory input |
| Toggle perspective | Q / ButtonR3 | Camera `Position/Config.luau` and a separate listener in `Position.luau` |
| Toggle mouse lock | Z | `ClientControllers/Player/Interface/Mouse.luau` |
| Activate / release equipped tool | MouseButton1 | `Character/Inventory/Input/ToolInput.luau` |
| Slider drag / decrement / increment on gamepad | ButtonA / DPadLeft / DPadRight | `Menu/Buttons/Settings/Slider.luau` |
| Dismiss results | MouseButton1 or Touch | `Player/Events/Gui/Results.luau` |
| Gun activation / aiming / reload definitions | MouseLeftButton / MouseRightButton / R | `ClientConfig`; no consumers found for these three configuration fields |
| World interaction | Prompt instance's keyboard and gamepad properties | Server `Systems/Interactables.luau` clones `ServerStorage.ServerAssets.Prefabs.ProximityPrompt`; client `Prompt/InputDisplay.luau` reads its properties |

The abbreviated `Character/`, `Player/`, and `Menu/` paths in the table are under `ClientControllers/`.

Additional findings:

- `SlotButton.luau` and `KeybindBadge.luau` independently format hotbar labels from slot indices. Neither reads the actual binding.
- Sprint, crouch, perspective, melee, flashlight, and lantern have existing mobile GUI connections. Tool controllers use mobile-only InputActionService bindings; desktop activation already belongs to `ToolInput`. Adding desktop bindings to those tool controllers would risk duplicate activation.
- `ClientConfig.input.mobileButtons` contains image references; no reads of that table were found. These are presentation assets, not additional active key assignments.
- Camera ButtonR3 currently runs only when `gameProcessed` is true. The unified design deliberately replaces that separate path with the same InputActionService action as Q. This changes its routing semantics and requires explicit UI-focus and gamepad verification.
- InputActionService caches binding objects by name. Preserve existing binding names and owners. The codebase guide also records competing character startup paths; centralizing defaults does not resolve that lifecycle issue.
- Prompt values and other Studio asset properties are absent from `sourcemap.json`. No callable Studio tool is available in this session. The current interaction keys cannot be confirmed from this checkout.

## Proposed design

### 1. One immutable catalog

Add `sync/ReplicatedStorage/SharedAssets/Keybinds.luau` as a typed, data-only module. This is runtime-neutral replicated configuration consumed by client gameplay/UI actions. Prompts remain outside this catalog at the user's request.

- Group named action definitions and ordered hotbar-slot definitions in this file.
- Each action declares typed `Enum.KeyCode` bindings accepted by InputActionService, including mouse-button key codes where appropriate; touch actions use native GUI button bindings. There is no parallel `UserInputType` dispatch configuration. GUI references are supplied by the owning controller at initialization.
- Freeze nested records/arrays as well as the returned catalog so consumers cannot accidentally change global defaults.
- Remove gun assignments and gun-specific code, as requested after plan approval.
- Store physical assignments only here. Labels are derived from those assignments. Do not maintain a second label-by-action configuration table.
- Keep callbacks, menu/inventory restrictions, hold/toggle preferences, priority, input sinking, and connection ownership in their current feature controllers.

This introduces neither runtime rebinding nor saved player keybind settings. Editing the catalog takes effect at the next binding/UI initialization.

### 2. One InputActionService registration path

Replace the keybind plumbing in `ClientUtilities/InputHelpers.luau` with a small typed `ClientUtilities/InputBindings.luau` module. Migrate callers and remove obsolete input helpers after the last caller moves. This module configures the existing InputActionService; it is not another input backend.

- Create a binding from a catalog action, attach its key codes, and apply the feature's explicit priority/sink settings.
- Return the typed binding to its owner, which subscribes to `Activated`, `Started`, or `Ended`, reads `GetState()`, and destroys it at teardown.
- Connect mobile action buttons through the wrapper's `SetUIButton` support and preserve MobileButton visibility registration. Verify hold/release and the existing melee tap-toggle behavior before replacing the manual button-event bridge.
- All application action creation goes through this module; backend-specific setup stays here. No fallback to UIS, CAS, or CAU for an action that needs additional work.

Type these boundaries using the catalog definition and the existing binding type. Register nothing at require time. Gameplay guards and action enablement remain feature-owned. Use InputActionService state/context/priority controls plus explicit menu and text-focus checks where needed. Its callbacks do not expose UIS's `gameProcessed` argument, so audit each old guard's intent and verify the replacement rather than pretending the two APIs are identical.

The existing wrapper caches bindings by name. Use one owner per action name. For multiple settings sliders, create one shared set of slider actions when the first slider registers, route callbacks to the active/hovered slider, and destroy the actions when the last slider unregisters. Do not attach identical callbacks to a reused binding from every slider instance.

Add `ClientUtilities/KeybindDisplay.luau` for hotbar key text derived from the catalog. Any key-name formatting belongs here and maps physical keys to display text, not actions to duplicate key assignments. Preserve explicit custom text supplied to `KeybindBadge`, including UI Labs previews.

### 3. Preserve feature ownership

Movement, inventory, camera, mouse, tool-input, slider, and results features own their InputActionService bindings and subscriptions. Mobile gameplay buttons activate InputActionService actions. Generic widget clicks, hover animations, drag coordinates, and input-device detection remain UI mechanics; they must not become alternate routes for gameplay or shortcut key dispatch. UIS may still observe device/focus/pointer state, but must not execute a keybind or poll whether its key is held.

## Implementation sequence after review

### A. Catalog and adapters

1. Add the catalog, the typed InputBindings registration module, and the display helper.
2. Populate it with the source-verified assignments above, including all ten ordered hotbar slots.
3. Keep existing action names stable when creating InputActionService bindings.
4. Add the new ModuleScripts through the project's Azul workflow and verify their Studio placement. Source files alone do not prove Studio instances exist; do not invent Azul GUIDs or treat manual sourcemap edits as deployment.

### B. Migrate every in-scope application keybind to InputActionService

1. Movement: register sprint/crouch through InputBindings. Replace `IsKeyDown` polling with action state. Order initialization so the sprint binding exists before held-input synchronization; verify already-held keys across initialization and respawn. Preserve Hold/Toggle settings and mobile behavior.
2. Inventory: register catalog actions through InputBindings; replace inline keys and `keySlots`. Retain slot-selection behavior and inventory toggle priority/sink settings.
3. ToolInput: replace UIS InputBegan/InputEnded with an InputActionService mouse activation action and its press/release signals. Keep desktop activation owned here and preserve tool eligibility checks. Ensure an accepted press gets its release/cancellation even if the menu, selection, or equipment changes while held.
4. Camera: bind Q and ButtonR3 to one perspective action. Remove the separate UIS listener and the processed-only ButtonR3 condition. Both keys follow the same action gating and callback.
5. Mouse: replace the Z listener with the catalog's mouse-lock action; retain menu/focus restrictions.
6. Settings slider: use the shared slider action owner for gamepad drag/confirm, decrement, and increment. Remove gamepad key comparisons from UIS press/release listeners. Preserve pointer-coordinate tracking, widget dragging, and gamepad step size.
7. Results: register a native GUI-button InputActionService action while results are dismissible, with a transparent dismissal surface behind other controls. A positional touch key cannot supply a boolean press/release. Destroy the action and surface on dismissal or replacement; verify layering in Studio.
8. Mobile: migrate movement, perspective, melee, flashlight, and lantern action buttons to the common InputActionService registration/button path. Preserve melee's mobile tap-toggle semantics and avoid adding a second desktop tool activation binding.
9. Remove the old physical-key definitions from ClientConfig and camera Config and obsolete helper code after their consumers migrate. Keep unrelated settings and image assets intact.

### C. Make hints follow the binding

1. Update both `SlotButton` and `KeybindBadge` to use the same catalog-derived hotbar label function.
2. Preserve the current badge layout and custom-text behavior.
3. Ensure a test reassignment of slot 10 updates its registered input and displayed text together. Do not infer the key from the slot number anymore.

### D. Prompts excluded by user

The user explicitly excluded prompts during implementation. Leave `Systems/Interactables`, `Player/Interface/Prompt`, prompt hints, and native prompt activation unchanged. Prompt keys and native Roblox/vendor controls are outside the single-backend requirement for this change.

### E. Verify and document

- Add focused regression coverage under `Tests/`, mirroring the modules being checked. Use actual catalog/adapter code with minimal input stubs where engine execution is unavailable.
- Verify every action registers its catalog keys through InputActionService; mouse activation pairs press/release; slot 10 remains bound to Zero by default; a changed slot key changes its hint; nested catalog mutation is rejected.
- Exercise consumer routing to catch duplicate activation, especially multiple slider instances and equipped tools. Preserve inventory priority/sink settings; verify the unified camera route and focus/menu gating. Test teardown/recreation and cancellation where the harness can faithfully represent them.
- Compile changed Luau files, check formatting with a Luau-capable StyLua binary, and run focused lint/type checks with available Roblox definitions. Report existing tool/repository diagnostics separately.
- Scan for remaining application-owned physical assignments outside the catalog AND alternate key dispatch: UIS key InputBegan/InputEnded branches, IsKeyDown, CAS/CAU action registration, and manual mobile action-event bridges. Also verify direct InputActionService creation lives only in InputBindings. Classify generic widget mechanics and observation separately from actual keybinds; document vendor and excluded prompt boundaries.
- Studio acceptance: keyboard hotbar 1-0, inventory, drop/throw, sprint/crouch Hold and Toggle, mouse lock, camera keyboard/gamepad paths, tool press/release, slider controls, results dismissal, mobile buttons, text focus, menu restrictions, and death/respawn. Confirm one action per input and unchanged cleanup. These checks remain unverified until Studio execution is available.
- Update the input section of `CODEBASE_GUIDE.md` with the catalog location, ownership contract, migration status, and how to add an assignment.

## Scope boundaries

Honor the codebase guide's existing Shop and AI exclusions. Preserve vendor InputActionService, ContextActionUtility, PlayerModule, and TopbarPlus internals. Their presence on disk does not authorize using multiple backends for application actions. Roblox movement/jump/camera navigation defaults remain vendor-owned; rewriting those would be a separate vendor-control migration. Do not add new gamepad/mobile controls, rebind settings, persistence, another global input dispatcher, or unrelated controller-startup repairs in this change.

The intentional behavior changes in this migration are unified camera gamepad routing, paired release/cancellation for accepted actions, and InputActionService-based focus/priority handling in place of raw processed-input flags. Verify these explicitly rather than claiming a mechanically identical extraction.

## Acceptance criteria

1. A source-defined application assignment has one authoritative physical-key definition.
2. Every migrated application keybind registers through InputBindings using the existing InputActionService; no UIS/CAS/CAU dispatch or held-key polling remains for those actions.
3. Hotbar and hotbar hints derive from the same assignments that InputActionService registers.
4. Defaults, Hold/Toggle preferences, feature restrictions, and callback ownership are preserved, with the intentional routing/cancellation changes above tested explicitly.
5. No duplicate desktop tool bindings, per-slider duplicate callbacks, or competing native prompt activation is introduced. Owned bindings and subscriptions are released on teardown.
6. Prompt handling and vendor-owned controls remain outside the approved scope. Unrun Studio checks are explicitly reported.

## Implementation record

- Added immutable `SharedAssets/Keybinds`, client `InputBindings`, and `KeybindDisplay`.
- Migrated movement, inventory, desktop tool input, mobile tool actions, camera perspective, mouse lock, slider shortcuts, and results dismissal to InputActionService.
- Removed `InputHelpers`; SlotButton reuses KeybindBadge, which derives its hint from the catalog.
- InputBindings owns cancellation subscriptions, unregisters mobile controls, and replaces an old action owner safely. Late old-owner destruction cannot destroy its replacement.
- Removed client/server gun Template modules, Revolver configuration, Bullet definition, firearm config types/attributes/defaults, viewmodel aiming/recoil/camera-relative gun positioning, and camera recoil/aiming bob effects. Shared projectile code and non-gun arm/grip behavior remain.
- Prompt, Shop, AI, and vendored code are unchanged.
- The workspace's sourcemap updated externally with new module GUIDs and deleted module entries; no GUIDs were invented or sourcemap content manually authored.
- Validation: 204 assertions using actual source modules with mocked input services and Lune CFrame/Vector3 for remaining tool viewmodels; all 621 current source files compile. Focused Selene: zero errors/parse errors, seven existing UI table warnings. Type analysis reports dependency/tool-definition failures in InputActionService and external libraries, with no diagnostics in changed application modules. Studio input/GUI integration is not exercised by these checks.

Run `lune run Tests/RunKeybinds.luau` and `lune run Tests/Compile.luau` from the repository root. Use direct installed binaries if Rokit shims fail on this machine.
