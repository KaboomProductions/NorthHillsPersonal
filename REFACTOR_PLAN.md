# NorthHills refactor plan

Audit date: 2026-09-15. Companion: [CODEBASE_GUIDE.md](CODEBASE_GUIDE.md). Scope: the supplied Luau/Studio sourcemap snapshot. This is a documentation-only audit; the fixes below have **not** been applied.

## Scope restriction: Shop and AI are in progress

**User instruction (2026-09-15): do not touch Shop or AI.** Both are actively being developed and are excluded from the refactor work. R07 and R10 are deferred reference notes, not executable tickets or release blockers in this plan. Their observations describe the audited snapshot and may become stale as development continues.

This restriction applies throughout the document, including security fixes, cleanup, consolidation, tests, instrumentation and performance work in mixed tickets. Preserve Shop/AI code, behavior, assets, configuration and interfaces, including shop-related dialogue/catalog/UI and current/legacy AI, entity templates and client AI effects. Do not disable unfinished features, remove stubs, migrate their callers or change shared contracts in ways that require Shop/AI changes. Keep compatibility for these consumers when working elsewhere. Reopen this scope only when the user explicitly requests it.

## 1. Executive assessment

Preserve the existing domain layout and improve its ownership boundaries. Inventory already has a useful shared protocol, private server state, request validation, per-player serialization and owner-only replication. The largest problems are integration gaps around those boundaries: duplicate character construction, destructive profile normalization, inconsistent inventory invariants, uncancelled work and unvalidated remote adapters outside the excluded Shop/AI areas.

Production readiness is not established by this source snapshot. There is no reproducible place build, pinned tool/dependency setup, application regression harness or runtime verification available here. Incomplete projectile callbacks also need a feature-scope decision. Shop and AI remain work in progress; their snapshot observations are retained below only for reference.

### Evidence labels

- **Observed:** directly established from source and caller inspection, or a reported automated check.
- **Inferred:** likely purpose or consequence, with the supporting source named.
- **Validate in Studio:** the export lacks a relevant property, scheduling/physics behavior, asset state or runtime measurement. This is not a confirmed live incident.
- **Recommendation:** proposed target behavior; any product policy choice is identified explicitly.

Paths below are relative to `sync/`. `SI` = `ServerScriptService/Systems/Inventory`; `CI` = `ReplicatedFirst/ClientControllers/Character/Inventory`; `AI` = `ServerStorage/ServerAssets/AI`. These are existing paths. Each ticket's acceptance criteria are proposed tests, not claims that those tests already passed.

## 2. Priority and sequencing

Priority is based on source impact, not an assumed current player count. P0 means resolve before trusting affected live behavior; P1 means next reliability/invariant work; P2 means planned maintainability and measured optimization. Effort: S ≈ up to 2 focused engineering days, M ≈ 3–5 days, L ≈ 1–2 weeks, excluding asset access and product decisions. These are planning estimates. Change risk is the risk of introducing a regression while fixing the issue.

| ID | Priority / impact | Effort / change risk | Dependencies |
| --- | --- | --- | --- |
| R00 | P0 foundation: reproducible checks and place contract | M / low | Access to matching Studio place for runtime checks |
| R01 | P0 correctness: one owner of character controllers | M / high | R00 lifecycle fixture; can implement alongside R02/R03 |
| R02 | P0 security/reliability: remote boundaries outside inventory | M / medium | None for validators; Studio for interaction policy |
| R03 | P0 data safety: stop destructive schema fallback and starter replenishment | M / high | Recorded profile fixtures, staging datastore |
| R04 | P1 correctness: inventory zone/record invariants | M / medium | R03 compatibility policy |
| R05 | P1 data consistency: mutation failure and request outcomes | L / high | R04; characterization before behavior change |
| R06 | P1 reliability: task and resource ownership | M / medium | R01 for client lifecycle |
| R07 | Deferred: AI work in progress, excluded by user | Not scheduled | Explicit user request to reopen AI scope |
| R08 | P1 availability: round lifecycle/results and state snapshots | M / high | R00; money persistence policy before schema change |
| R09 | P1 configuration: scalar settings and validated definitions | M / medium | R03 migration pattern |
| R10 | Deferred: Shop work in progress, excluded by user | Not scheduled | Explicit user request to reopen Shop scope |
| R11 | P2 maintainability: consolidate duplicated knowledge | M, split by cluster / medium | R01/R04/R06; no umbrella rewrite |
| R12 | P2 reduction: reachability-led legacy/vendor cleanup | M / medium | Studio reference inventory, pinned dependencies |
| R13 | P1 operational baseline, P2 optimizations | M + measured follow-ups / low–medium | R00; R01/R06 before performance comparison |

Recommended waves:

1. Establish the checked-in evidence/check harness (R00), stop destructive load fallback and unintended starter replenishment (R03), validate in-scope remotes (R02) and remove duplicate client startup (R01). These can be separate reviewable changes.
2. Enforce inventory invariants (R04), then make mutation failures explicit (R05); address delayed tasks (R06), round results (R08) and settings (R09).
3. Consolidate in-scope duplicate rule owners (R11), remove proven-unused code outside Shop/AI (R12), and optimize measured in-scope hot paths (R13). R07 and R10 are not part of these waves.

Do not combine a dependency upgrade, schema migration, hierarchy move and broad format pass in one change. Retain a staging place version and rollback-compatible persisted records for every rollout that changes data or remote shape.

## 3. Detailed execution tickets

### R00 — Establish the actual place contract and trustworthy checks

**Observed.** Only `sync/`, `sourcemap.json` and `selene.toml` existed at the root before this audit. The sourcemap maps all 617 scripts but not property values or asset contents. There is no build/dependency/test/CI configuration. An available PATH StyLua binary lacked Luau support; a directory check could appear successful without checking Luau. Direct installed tooling worked after Rokit launcher shims failed.

**Change sequence.**

1. Record the matching Studio place, Azul sync direction/configuration, source-map regeneration procedure, script Enabled/RunContext settings, required remote/GUI/template/tag hierarchy, collision groups, streaming/API-service settings and asset/package access. Keep a small startup asset validator listing exact missing paths/classes/attributes; do not attempt to reconstruct all 44,904 nodes from the sourcemap.
2. Pin Luau-capable formatter, Selene, luau-lsp and Roblox definition revision. Resolve InputActionService's `@self` imports against the actual Studio resolver before treating its diagnostics as application errors. Separate vendored tests/code from application gates without hiding application diagnostics.
3. Add a minimal test runner appropriate to the existing environment: pure Luau tests for protocols/config/rules, and a Studio fixture place for Instances, player lifecycle and remotes. Existing UI Labs stories remain useful visual fixtures. Do not introduce a second full application framework to run tests.
4. Add read-only compile/type/lint checks and targeted tests to CI once execution can be reproduced. Establish current debt baselines and ratchet changed application files; do not suppress every warning or mass-format vendor code.

**Acceptance.** A second engineer can obtain the place, sync, run the documented commands and reproduce baseline results. A deliberately invalid `.luau` fixture fails the syntax command. A missing required remote/template fails startup with its exact path. Run a two-client lifecycle smoke test before accepting gameplay changes.

### R01 — Give character controllers one lifecycle owner

**Observed.** `ReplicatedFirst/ClientControllers/Menu.hookCharacterControllers/hookCharacter` starts every cached Character module using MainController and stores the result in ClientRuntime's active list. `StarterPlayer/StarterCharacterScripts/CharacterHandler.client` waits for hasLoadedPlayerControllers and independently calls `ClientUtilities/CharacterControllers.loadControllers` for the same folder. Menu retains separate hooks while both touch the shared list. Core/ViewModel and Effects/Camera bind fixed RenderStep names and unbind those names on destruction.

**Consequence.** Duplicate input/events/effects and teardown of another instance's bindings are possible even when only one camera update is visible. Deferred constructors can finish after another owner has already destroyed/replaced their state. The menu's hasLoadedPlayerControllers flag only means constructor calls returned.

**Recommended owner.** CharacterHandler/CharacterControllers owns exactly one generation per character; Menu owns session UI and readiness presentation. ClientRuntime may expose a read-only current-character handle, not be a second destruction authority.

**Migration.** Instrument constructor/destroy counts first. Route Menu's character need through the chosen owner's readiness signal, remove Menu's creation/destruction path, and keep Player controllers session-scoped. Add an explicit generation/destroyed check after yielding initialization. Start critical dependent children in explicit order rather than relying on alphabetical folders or deferred timing. Remove redundant shared-list mutations only after all callers are switched.

**Acceptance.** Initial join, delayed GUI/settings, menu reopen, ten respawns, death during preload and local script destruction leave one controller per feature for the current character and none for the old one. Each input fires once, camera bindings remain active after old-generation teardown, and connection/task counts return to baseline. Include `Movement/States/Sprinting.canEnter`: its second unconditional stamina comparison can dereference nil despite the preceding guarded comparison; initialize/read stamina through one defined readiness contract.

### R02 — Validate and bound every client-triggered server adapter

Inventory's gateway is a useful precedent, not evidence that other remotes are safe. Roblox's supplied Player argument establishes sender identity; clients still control payload and call timing. The following are concrete source gaps.

| Boundary and evidence | Observed gap | Target behavior / validation |
| --- | --- | --- |
| `Controllers/Events/StreamingReplication.onEvent` | Accepts arbitrary truthy input as CFrame, destroys previous focus before validating, creates a Model under Terrain on each call; storedFocuses has no PlayerRemoving cleanup. | Validate finite bounded location and allowed menu/camera mode; rate limit; create/validate replacement before destroying old focus; clear on leave. Verify focus target type/actual streaming behavior in Studio—the API type alone does not prove an empty Model is suitable. |
| `Controllers/Events/Character/Footstep.init` | Indexes `rawPayload.crouching/sprinting` without a table guard; trusts self-reported movement for noise attenuation; no cadence limit. | Reject malformed data before indexing; cap by plausible step cadence; derive consequential noise from server-observable movement/state. Test nil/table/string and burst calls. Current AI noise reachability is mixed; do not claim this proves stealth bypass in active Phil. |
| `Controllers/Events/MenuReplication` | Writes client-provided menu state without boolean validation or rate policy. | Accept boolean only, with legal transitions if gameplay depends on it. Treat menu presentation as a request, not an entitlement to immunity. |
| `GameHandler/PlayerSettings.onTransferInvoke` | Checks primitive class/type only; no finite/range/enum/string-size validation. | Definition-driven validator (R09), reject NaN/infinity and invalid option values before persistent state changes. |
| `Controllers/Events/RoundCycle` | Repeated client-ready requests resend phase/climate state without an application limit. | Idempotent readiness registration, bounded resync and player cleanup. |
| Deferred Shop integration: `Systems/Dialogue` remote handlers | String type checks, limited semantic/context validation; initial distance check exists for Zara, but session expiry/continued distance checks do not. | Cap input lengths and call rates; validate active session and NPC eligibility at each consequential choice; expire abandoned sessions (R10). |
| `Controllers/Tools/Flashlight`, `Lantern` | Sender-owner checks exist; repeated legal toggles create audio/tween work without a bounded cadence. | Preserve owner/equipped validation, add tool-specific cooldown/rate rules and replace transient effects (R06). |
| `Systems/Interactables/Doors` versus `Character/Core/DoorBashing` | Bashing checks Locked, regular prompt callback does not; prompt callback assumes a character. | One server door permission predicate for trigger/bash; validate live character, lock and allowed action. Test client-invoked prompt paths and race with removal. |
| `DoorQteTest.server` | Test script binds real remotes/prompts without an IsStudio guard; failure reporting is client-driven. | Confirm Enabled state; explicitly scope to a Studio test fixture or implement a validated gameplay controller. Filename alone is not a deployment guard. |

**Migration.** Keep validators next to each domain and use the existing protocol's finite-number function where accessible; do not route every unrelated action through the inventory service. Standardize a small rate-limit primitive only where semantics match, with per-player removal. Reject before allocation, physics work, persistence writes or fan-out. Preserve payload compatibility while deployed clients may still send the old shape.

**Acceptance.** In a controlled Studio test, malformed primitives/tables, huge strings, nonfinite components, repeated ready/streaming requests and stale characters cause no server callback exception or unbounded Instance growth. Valid interactions still work under latency. Verify server contextual checks independently of client controls. Guidance: [Roblox client/server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary).

### R03 — Make inventory/schema evolution nondestructive

**Observed.** `GameHandler/PlayerData.load` calls Reconcile before inventory load. `SI/Persistence/Hydrator` treats every `schemaVersion ~= 2` as a reason to reseed from DataTemplate; it skips invalid, duplicate, unknown-template or out-of-range records and serializes the resulting state back. `DataTemplate.Inventory` carries schemaVersion 2. A missing version can receive the template's version before a migration sees the original shape. Unknown future-version records are not safely rejected.

**Additional observed P0 issue, found in the second pass.** `ProfileStore.ReconcileTable` recursively fills absent string keys. DataTemplate seeds string-keyed hotbar slots 1 through 8 and storage slots 1 and 2; `InventoryCodec.serializeZone` omits empty slots. Every profile load therefore restores starter items into those emptied slots. A focused probe loaded the actual DataTemplate/InventoryConfig and extracted unmodified ReconcileTable/DeepCopyTable functions: an empty saved v2 inventory acquired eight hotbar items and two storage items. Explicit zero material values stayed zero. This can replenish a dropped/thrown/moved starter item on rejoin even when schemaVersion is already correct.

**Risk.** A deployment with missing templates, a downgrade, or an older/malformed profile can permanently overwrite recoverable inventory. This is an observed destructive code path; occurrence in real player data is unmeasured.

**Owner.** A small inventory migration/validation module under `SI/Persistence` owns version interpretation. Separate one-time fresh-profile starter grants from the structural template reconciled on every load; InventoryCodec owns conversion between the current saved model and runtime state. ProfileStore Reconcile is not a schema migration engine.

**Migration.** Capture representative old/current/malformed/future records before changing behavior. First separate one-time starter initialization from recursive reconciliation: an empty saved slot is meaningful, not missing schema. Do not infer "new player" from an empty inventory; use an explicit initialization/version policy that also handles existing profiles without granting again. Identify original version/shape before reconciliation obscures it. Implement explicit supported-version transitions returning a new validated record without mutating the source. Reject future versions safely; distinguish a missing asset from an invalid record. Quarantine/report rejected records or fail inventory admission without saving a replacement, according to a documented recovery policy. Commit a migrated record only after successful validation/materialization. Preserve a rollback-readable schema during rollout; a later schema bump needs an explicit downgrade/rollback decision.

**Acceptance.** Golden fixtures for missing version, supported older shape, current v2, future version, missing template, duplicate ID, duplicate normalized slot keys (for example "1" and "01"), capacity overflow and invalid attributes. Hydrator currently accepts both aliases through tonumber and can overwrite one slot while leaving the earlier materialized item unreferenced. Also test dropped/moved/consumed starter items across save/load: empty slots must remain empty and fresh players must receive starters exactly once. Migration is idempotent; valid items and materials conserve identity/quantity; rejected load does not rewrite the profile. Test Studio Mock separately from a staging live-store session/leave/rejoin cycle. [ProfileStore API](https://madstudioroblox.github.io/ProfileStore/api/) describes reconciliation and session semantics; verify any change against the vendored implementation.

### R04 — Enforce inventory rules at every write path

**Observed.** `SharedUtilities/ItemUtils.canMoveToZone` permits hotbar only when an item's config has controllerClass. `SI/Actions/Move` and `CI/Drag/DragController` call it. `SI/Grants/Allocator`, `Grants/Grant.giveToSlot`, `Actions/Stacks` splitting, `Persistence/Hydrator._loadZone` and item replacement during upgrades do not consistently apply that rule. Filling storage and allocating Backpack can therefore place non-equippable gear in the hotbar. Some paths are internal APIs, not client-exploitable by themselves, but they violate the same state invariant.

Other knowledge is repeated: primitive/finite validation in InventoryProtocol, ItemFactory and ItemUtils; starter/schema/capacity assumptions in protocol, DataTemplate, Hydrator and Codec; ItemType/legacy Type/name fallback; legacy and current melee field names in ItemConfigTypes/configs.

**Owner.** Keep structural remote validation in InventoryProtocol. Put item/zone/attribute policy in ItemUtils and validated item/material definitions; all server mutations must call it. Do not create a generic rules engine. Runtime slots remain server state; SlotIndex, profile snapshot and Replica remain derived.

**Migration.** Enumerate every slot-writing call (`slot.Value =`, allocations, load, split and replace). Apply the same predicate before mutation, checking swap in both directions and capacity at the actual state. Normalize configs once, with temporary compatibility for old field names/Studio item attributes. Migrate existing invalid hotbar records using R03's recovery policy rather than silently deleting them. Add one invariant audit helper usable in tests and optionally sampled diagnostics.

**Acceptance.** Table-driven cross-product of grant/pickup/move/swap/split/load/upgrade with equippable gear, Backpack and material. Storage-full allocation never violates hotbar policy; material balances never become slots; all paths preserve unique IDs and quantities. Invalid persistent attributes use a documented reject/default policy. Include infinite stack/capacity values and extreme vector components; finite Vector3 components alone do not guarantee finite magnitude after arithmetic.

### R05 — Define mutation failures and client request outcomes

**Observed.** `SI/State/TransactionQueue` catches a callback exception and returns internalError, but does not undo Instance changes. `Service.commit` updates index, in-memory profile and replica after mutation. `Items/ItemFactory.replaceClone` releases the old ID before creation succeeds and destroys the original later; repair also releases the ID before a potentially failing replacement. Upgrade/stack/drop/capacity paths make destructive changes before all subsequent operations are guaranteed. PendingThrows commits consumption before launch.

The queue's `inCriticalSection` is a boolean for the whole queue. A second coroutine entering while a callback yields is rejected as “not reentrant,” even if it is not recursive. This requires either a strictly non-yielding callback contract or task-owner-aware locking; the existing queue is not a general yielding transaction processor.

`CI/Requests/InventoryRequests._invoke` catches InvokeServer errors and rejects stale generations, but has no application timeout and returns nil for several different conditions (busy, transport failure, destruction, malformed response). A hung invoke can retain an action's inFlight flag for that controller's lifetime. Selection has its own reconciliation timeout; other action UI does not thereby gain a request deadline.

**Migration.**

1. Characterize all mutation failure points with injected factory/controller/persistence/replication failures. Document which callbacks can yield. Keep prepare/equip waits outside the short mutation section.
2. Prepare and validate replacement assets before releasing IDs, debiting materials or destroying the original. Apply the smallest reversible slot/attribute change set; serialize/validate the resulting inventory before treating success as committed. If a remaining failure cannot be compensated, disable that player's inventory, report the operation and resynchronize from the chosen authority. Do not pretend an xpcall provides rollback.
3. Make profile and replica publication order explicit. Add a revision/full-snapshot repair path if multi-field replica updates must be observed coherently. Retain ProfileStore's durable-save responsibility; do not save on every drag.
4. Define distinct expected results for busy, unavailable, rejected and unknown outcome. An application timeout stops UI waiting, not an already-running server mutation. Ignore late replies by request/generation identity and reconcile with authoritative state. Add idempotency keys only to operations that need retry across unknown outcomes; never blindly retry a purchase or throw.
5. Specify throw failure policy: refund, world-drop, or intentional consumption. Preserve single launch/finalization and player-leave cleanup whichever policy is chosen.

**Acceptance.** Failure at every prepare/mutate/profile/replica step leaves either a valid inventory or a clearly disabled recoverable state, never duplicate IDs or negative balances. Concurrent operations, death/disconnect while waiting, queue saturation and reentrant calls resolve predictably. Lost/late replies cannot duplicate a mutation. Durable save/rejoin verifies eventual persistence separately from immediate commit.

### R06 — Make async work and resources belong to their lifetime

| Evidence | Observed failure mechanism | Incremental repair and regression |
| --- | --- | --- |
| Server `Controllers/Tools/Melee.cancelSwing` | Closes delayed coroutine only when status is `running`; a task.delay handle waiting to run is suspended. Delayed hitbox creation can run after unequip/destruction. | Retain/cancel scheduled handles and check swing generation before creation/destruction. Rapid charge/cancel/re-equip must never damage after cancellation or stop a newer hitbox. |
| `Controllers/Player.onCharacterAdded` | Memory loop captures old character but tests mutable `self.characterController`; a respawn can make that field nonnil again before the old loop resumes. | Per-character generation/task handle. After repeated respawns only the current character records visits. |
| `Controllers/Events/Character/Replication` | Client `Core/CharacterReplication` resets sequence per controller; server lastSequence persists across character death. Event-rate buckets persist beyond PlayerRemoving while state cache is cleared. | Key accepted sequences by server character generation (or explicitly reset at authoritative respawn) and clear both maps on leave. Old packets must not become valid for a new character. Test first packet and respawn after hundreds of sends. |
| Server `Controllers/Tools/Lantern` | toggleTweens cancels existing entries but assigns only a local loop variable to nil; array retains every inserted tween. | Replace/clear active tween collection; check 1,000 toggles return resource counts to baseline. |
| `ServerAssets/Classes/SpitPuddle.preload` | Clone is parented before raycast success but assigned to self.puddle only later; early self:destroy cannot remove that clone. | Register ownership immediately after cloning; failed placement leaves no Instance/task. |
| Server `Systems/Interactables/Fusebox.destroy` | Disconnects own connections, never destroys subClassInteractable; TowerLights retains Toggled listener/cache. | Destroy child exactly once, cancel child tweens, clear references. Force-off must work: TowerLights.toggle currently uses `forcedState or not current`, losing an explicit false when already off. |
| Client `Player/Events/StatusEffects` | Teardown disconnects and clears its instance map without consistently running each effect's destroy behavior. | Remove/fade/cancel visuals before releasing references; test destroy/reapply during fade and character removal. |
| `Controllers/Character/Core/Ragdoller` | Timer task observes mutable character state; destroy does not visibly dispose its main Ragdoll object. | Call the existing Ragdoll.destroy (it removes constraints/attachments/colliders/connections), terminate the timer before clearing fields, and check for destroyed character before comparing newTimer. Validate actual resource counts in Studio before calling this a measured leak. |
| Server `Systems/SoundTriggers` | Constructs trigger controllers without retaining them, despite Crows exposing destroy. | Retain by source instance and remove on destruction/tag removal; no perpetual query for a removed source. |
| Deferred client/controller `init` methods | Constructors return before WaitForChild/tasks finish; destroy often clears fields/metatable immediately. | Generation/destroyed checks after each yield and before binding. R01 establishes the owner; this ticket makes each owned object honor it. |

Use existing domain handles and small cleanup helpers. Standardize application `destroy` semantics incrementally; do not introduce a generic lifecycle state machine into every small module. Retain errors from cleanup with component context rather than silently skipping the rest. Run leave/rejoin/respawn and interrupted initialization soak tests with resource counts.

### R07 (deferred: AI work in progress) — Repair active AI before porting legacy behavior

**Reference only. Do not implement the changes, migrations or tests in this section while the user's scope restriction is in effect.**

**Observed in current code.**

- `AI/Initializer` initializes `cachedRegions = {}` and later checks `if not aiController.cachedRegions`; that discovery branch cannot run for the initialized table.
- `AI/Targeting.new` reads `self.ai.behaviorCache`, while Initializer owns `cachedBehavior`. `Targeting/Perception` uses the resulting behavior configuration on its FOV path.
- `Targeting/Registry` uses a module-level lastRefresh but stores candidates on each targeting instance. A second NPC can hit the first NPC's refresh window and return its own uninitialized/stale cache. Shared cacheLookup is keyed by target identity even though targetsFolder belongs to an agent, but the second pass found writes/clears and no reads of this map; remove it if Studio references do not require it rather than claiming it currently returns another agent's target. The active lastRefresh/cachedTargets defect was reproduced with the actual Registry module and a mocked empty Components scene: first caller returned a table, second returned nil.
- `Initializer.destroy` calls `self.targeting:destroy()`, but Targeting has no destroy method. Cleanup can stop before pathfinding/speed disposal.
- `Behaviors/Phil/States/Chasing.enter` calls `toggleAlignOrientation()` without a boolean; the behavior assigns that value to Enabled. Validate the actual engine exception in Studio; the mismatched contract is explicit in source.
- Wandering schedules retry work with task.delay without retaining a cancellation/generation token. `StateMachine.change` leaves swappingOut true if state construction/exit/enter throws. Chasing exit does not clear its Chasing attribute, and absence of a target does not transition it out. Stalking has no identified current incoming transition; Health hooks are empty.

**Owner.** Per-agent configuration and target snapshots belong to that AI instance. A shared discovery cache, if retained, must cache only truly global immutable discovery data with a matching global revision. StateMachine owns one active state; that state owns its tasks and exit cleanup.

**Migration.** First align field names and explicit start/stop contracts, add Targeting destruction and correct the boolean call. Separate candidate discovery from per-agent filtering and timestamp ownership. Then add cancellable state work and exception-safe transition recovery that reports both old/new state. Explicitly define no-target behavior before completing Stalking/Health. Test current Phil independently of AIOld; only port legacy features deliberately after behavior characterization.

**Acceptance.** Two NPCs initialized within one refresh interval both obtain valid independent target lists. Different per-agent cache folders/FOV rules never share an agent-specific result. Target dies/leaves, path computation fails, state exits during delay, initializer is destroyed twice: no stale movement or remaining Heartbeat callback. Keep an engine raycast regression, but do not label CanQuery=false alone an invisibility bug: Targeting sets RespectCanCollide=true and Controllers/Character makes Torso collidable. [Roblox documents that RespectCanCollide prefers CanCollide](https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams/RespectCanCollide); this refuted the first-pass suspicion.

### R08 — Keep rounds running and publish one phase truth

**Observed.** `Systems/RoundCycle` has require-time world mutation, a task-deferred loop and stop/resume without a retained loop handle. Countdown subtracts one per wait rather than deriving remaining time from a deadline. `RoundCycle/Results.updateForResults` processes all Players, performs sequential unprotected IsInGroupAsync calls and then arithmetic on Money/Survivals initialized only by PlayerController. This is called synchronously from the round transition. One lookup or uninitialized-player failure can terminate progression. Repeated result processing has no round identity/idempotency guard.

`Controllers/Events/RoundCycle` builds readiness snapshots separately from Systems/RoundCycle. Client `Player/Events/CycleEvents` accepts snapshots and reads replicated Values as fallback; client transition duration is read live while server CycleConfig captures Values at require time. Money/Survivals are session state; persisting them is a product decision, not an existing promise.

**Migration.** Move require-time mutation into an explicit start step and retain a single loop generation. Have server RoundCycle own a revision, phase and end timestamp; use one snapshot builder for broadcast/ready/resync. Derive display countdowns from server time. Apply dynamic config at defined phase boundaries. Process results only for admitted/initialized eligible players, protect group lookup with a bounded cache/error policy, and isolate per-player failures from round progress. Record a round ID when applying each player's result. Decide session-only versus persisted currency/survivals before R10 changes economics.

**Acceptance.** Late join, profile load delay, failed group lookup, rapid stop/resume, missed phase event and duplicated result trigger produce a single coherent round and at most one reward per player/round. All connected clients converge after resync. Countdown drift remains bounded during artificial server stalls. Roll out snapshot fields compatibly before removing fallback readers.

### R09 — Separate settings definitions from persisted values

**Observed.** `SharedAssets/PlayerSettings` defines UI type/default/options/images. `GameHandler/DataTemplate` deep-copies the entire table into Settings. `PlayerSettings.generate` accepts definition-shaped saved values and later writes scalar ValueObject values; transfer validation checks only basic types. Reconcile can restore missing definition-table fields. The result is two persisted representations of the same setting and no authoritative numerical/options policy.

**Owner.** Shared immutable setting definitions contain default, kind, allowed options and explicit numerical bounds. Profile Settings contains only scalar values keyed by stable IDs. Runtime ValueObjects and UI controls derive from those two sources. Keep display labels separate from IDs if labels need localization/renaming.

**Migration.** Extend definitions with constraints after inspecting actual slider consumers. Read legacy definition tables and current scalars through one normalizer; write only scalar values. Move normalization before generic template reconciliation where necessary. Reject nonfinite and disallowed remote values; use defaults only for a documented recoverable saved-value case. Preserve legacy setting names through an explicit mapping if renamed. Avoid introducing a schema library merely for this small dictionary.

**Acceptance.** Definition-shaped, scalar, missing, invalid-option and nonfinite fixtures produce the correct runtime class/value without persisting images/descriptions. Every setting round-trips through UI → remote → profile → reload. Video/audio sliders preserve their intended units; client limits and server constraints derive from the same definitions.

### R10 (deferred: Shop work in progress) — Make shop/dialogue results correspond to real server work

**Reference only. Do not implement the changes, migrations or tests in this section while the user's scope restriction is in effect.**

**Observed.** `Systems/Shop.handleRequest` returns nil. `Systems/Dialogue/ChoiceProcessor` sets purchaseResult to success for buyConfirm without debiting or granting. Client `Player/Interface/Shop/Options/Buy`, catalog/ItemInfo and dialogue presentation form a convincing UI around that stub. Repair/Sell option presence does not establish a server transaction. Dialogue validates initial Zara distance but has no session TTL/continued validation loop; client distance closing can be bypassed. `canTransact`, `checkImpatience`, `closeAllSessions`, `sendNightLine` have no current external callers identified.

**Catalog gap found in the second pass.** ShopCategories/Weapons defines WoodenBat; inventory ItemConfigs and the ItemTemplates sourcemap have BaseballBat and no WoodenBat. Client `Shop/Options/Buy/ItemInfo.loadCatalog` and server `Dialogue/Registry.loadItemData` independently flatten category dictionaries with last-wins duplicates; their getItemConfig methods are unrelated to ItemUtils.getItemConfig. Define an explicit offer-to-itemType relationship and validate references/duplicate IDs at load. Do not silently equate WoodenBat and BaseballBat without a content decision. Keep commercial offer fields (price, stock, minimum survivals) separate from item behavior, and derive shared display fields where appropriate.

**Deferred option, reference only.** Return an explicit unavailable result and suppress successful purchase dialogue until a transaction is implemented. Confirm whether these options should be enabled in the shipped place; do not represent a fake success as a finished feature.

**Implementation sequence.** Decide currency persistence, pricing/discount ownership, survival prerequisites and full-inventory behavior. Put the server transaction in Shop, calling inventory's supported grant/consume interface and the currency owner. Price, eligibility and session distance are revalidated server-side. Use an operation ID for retries if the UI supports them; ensure debit/grant failure compensation under R05. Dialogue consumes the transaction result instead of encoding commerce. Expire/close abandoned sessions and advance queues on death, distance, disconnect and phase transitions. Remove unused wrappers only after intended hooks are either wired or explicitly dropped.

**Acceptance.** Insufficient funds/survivals, invalid catalog ID, full inventory, duplicate confirmation, disconnect during purchase and injected grant failure never debit without the defined outcome or grant twice. UI text matches the server result. One abandoned dialogue cannot monopolize Zara forever. Stable IDs remain compatible with existing clients during deployment.

### R11 — Consolidate duplicated knowledge, preserving useful independence

The following register is based on definitions **and consumers**, not a text-similarity score. Each row names competing sources, a canonical owner, a migration and a guard. The in-scope tickets own correctness fixes; R07/R10 and Shop/AI-related rows remain deferred. Retain compatibility used by those areas.

| Concept / competing definitions | Correct owner and derivation | Safe migration / enforcement |
| --- | --- | --- |
| Character creation: Menu/ClientUtilities.MainController, CharacterHandler/ClientUtilities.CharacterControllers, ClientRuntime active list | CharacterControllers per character generation; Menu observes readiness | R01, constructor-count regression; remove the second loader path. |
| Module lifecycle: SharedUtilities/Bootstrap, ClientUtilities/ModuleLoader, MainController, server Events and Events/Character loops | Small shared discovery/contract helper only where semantics match; caller owns order/readiness/results | Compare sorting, constructor args, errors, return types and reverse teardown before moving callers. Explicitly reject duplicate module keys instead of Bootstrap.mergeModuleTables' silent last-wins. Do not erase server/client lifecycle differences. |
| Inventory zone policy: ItemUtils, Actions/Move, client Drag, omitted grant/load/split paths | ItemUtils for pure policy; server mutation entry points enforce it; client hints derive | R04 path matrix and invalid-save migration. |
| Inventory schema/default/capacity: DataTemplate, InventoryConfig, InventoryProtocol, Hydrator, Codec, client empty state | Structural template owns reconciled defaults; one-time initialization owns starter grants; migration owns versions; protocol owns transport bounds; codec/store are projections | R03/R04. Do not merge an empty UI snapshot with a new-player starter loadout merely because fields match. |
| Item metadata/rules: ItemConfigTypes, ItemConfigs, ItemUtils compatibility getters, template Type/ItemType/Name | Normalized ItemConfigs with stable ItemType; templates supply assets | Inventory and ViewModel consume ItemUtils; the compatibility getter is used by ViewModel, while Shop/ItemInfo and Dialogue have independent catalog getters. getToolConfig has no identified caller. Migrate legacy attributes/field names, then remove adapters with a call-site check and saved-record fixture. |
| Deferred Shop identity/catalog: ShopCategories, Dialogue/Registry.loadItemData, client Buy/ItemInfo.loadCatalog versus ItemConfigs/templates | Offers reference canonical inventory itemType; one shared catalog flatten/validation function; server owns price/eligibility decision | R10 maps WoodenBat deliberately, rejects duplicate IDs/missing item references and tests UI/server agreement. Keep stock/price separate from item physics. |
| Material metadata: ItemConfigs/Nails and DuctTape versus MaterialConfigs/Nails and DuctTape | MaterialConfigs for balances/display; world-template validation uses explicit material route | Audit ItemFactory.adoptWorldItem, Templates and UI consumers before deleting slot-era configs. Test world pickup and recipe display. |
| Finite/persistent primitive tests: InventoryProtocol, ItemFactory, ItemUtils | Protocol finite predicate; ItemUtils allowed persistent-attribute normalization | Share the exact invariant, retain boundary-specific messages/constraints. NaN/infinity/type tests. Do not combine remote payload and saved-record schemas into one permissive validator. |
| Inventory open state: ClientData.InInventory, ClientData.isInventoryOpen, CI/View.isOpen | View's open source (or its immediate owning Inventory controller); ToolInput subscribes/queries | Repository search found only false initializers for the ClientData flags; ToolInput reads InInventory. Switch reader, remove unused flags, test tools blocked while panel is open. |
| Equipped state: server CurrentSlot/EquipTransition, Model attributes, Replica currentSlot, client Selection | Server equipment transition owns committed equip; attributes/Replica derive; Selection owns pending intent only | Assert relationship at commit; preserve optimistic selection and stale-intent reconciliation. Do not collapse intent into committed state. |
| Character replication DTO/rates: SharedUtilities/CharacterReplication, sender Core/CharacterReplication, receiver packet/config modules, server adapter | Shared sanitized DTO; server generation/acceptance policy; client interpolation config stays local | R06 sequence reset; separate protocol limits from cosmetic smoothing; malformed/late packet test. |
| Round snapshot/time: Systems/RoundCycle, Events/RoundCycle, client CycleEvents, Values/CycleConfig | Server snapshot builder and phase deadline; clients derive presentation | R08 revision/late-join tests; retire duplicate snapshot builder after compatibility rollout. |
| Settings: definition tables, DataTemplate.Settings, ValueObjects, control-specific limits | Shared definitions + scalar persisted values | R09 migration and all-setting round-trip table. |
| Group policy: GroupChecker group/rank, Results group reward ID | Small server access/reward configuration sharing group ID; distinct eligibility decisions | Route both callers, specify lookup-failure policy and Studio bypass order. Test a membership failure does not kill admission/round loop. |
| Deferred AI caches: Initializer.cachedBehavior versus Targeting.behaviorCache; module Registry refresh versus per-instance candidates; unused cacheLookup | AI per-instance behavior/filter cache; explicitly shared discovery only; remove write-only map | R07 two-agent tests; do not mask typo with a second alias permanently. |
| Status effect state: server StatusEffects active entries, refresh/stack branches, client StatusEffectSync state | Server active entry owns stack count/expiry; apply/update/remove projections derive | Publish changed stack/expiry on refresh, define client update semantics and generation-safe fade cancellation. Test rapid refresh/reapply and loss of the character. |
| Nonlethal periodic damage: server StatusEffects/Bleeding, Burning, Corroding | Small server tick-damage policy if intended identical; effect definitions supply parameters | Characterize stacking/nonlethality then share formula. Keep different visual effects, refresh policy and sound independent. |
| Melee charge/config: client and server Melee, duplicate old/new config fields | Shared deterministic curve/config evaluation for prediction; server owns elapsed charge and damage | Compare actual field precedence and boundary outputs before extracting; test 0/min/full/overcharge. Do not trust client-reported damage. |
| Interactable motion: Default/Double doors, Drawer, Locker, PivotDoor and client Effects/Interactables | Existing SharedUtilities/InteractableMotion for protocol/defaults; each interactable owns permissions/geometry | Preserve double-door and container behavior; hydrate late/streamed instances and test target sequence changes. Don't replace geometry differences with a generic scene framework. |
| Asset preloading: client and server AssetPreloader; round MusicController direct preload | Client loader owns client warmup/cache; no current caller found for server helper | Remove server helper only after Studio references checked. Client cache marks before PreloadAsync; record success/failure and use bounded/weak lifetime where appropriate. Test failed load retries. Server preload is not a warmed client cache. |
| Sound selection/history: AudioUtils and server Footstep caller (existing good integration) | AudioUtils already owns reusable selection/history; Footstep owns noise/cadence | Preserve fetchLeastUsedSound delegation. No new abstraction is justified for this caller. |
| App connection cleanup loops versus vendor Janitor/Signal families | One documented application lifetime convention; package-local implementations remain package-owned | R06 first. No repository-wide dependency injection container or mass signal replacement. |

**Abstraction review.** `SI/Contracts` repeats wide structural interfaces; constructors in several SI modules copy methods onto instances as well as using a metatable and cast through unknown. Narrow the few collaborators a module actually uses, remove redundant per-instance method assignments after type tests, and keep ordinary module construction. `ControllerHost.reset` enumerates concrete controller methods (cleanupCharging/cancelSwing/stopActiveSound/registerToggle/cleanupRigArtifacts) with silent pcall: introduce one meaningful tool `deactivate`/destroy contract, then migrate controllers individually. The tiny `Systems/Inventory.luau` pass-through is a reasonable stable feature entry point; deleting it gains little. Do not split long ArmMotion/GuiAnimator/Packet files solely to meet a line limit—separate a cohesive behavior when it materially improves testing or ownership.

**Type correction.** `CI/InventoryStore`'s Readonly type function returns immediately when `object:is("table")`, so the intended table transformation does not occur. The `types` global inside a type function is legitimate Luau, not an undefined runtime dependency. Prefer simple explicit exported read-only view types if compatible with the pinned toolchain; otherwise fix and test the function. Read-only types do not deep-freeze runtime descriptors: clone only where mutation isolation is actually required. See [Luau type functions](https://luau.org/types/type-functions/) and [table types](https://luau.org/types/tables/).

### R12 — Remove legacy and speculative code only after proving reachability

**Scope:** all Shop/AI-related candidates below are retained reference observations and excluded from removal or migration. Names such as AIOld do not override the user's restriction.

**Observed exact-content clusters (SHA-256 over source).**

| Cluster | Interpretation and action |
| --- | --- |
| `AI/NoiseDetection` and `AIOld/NoiseDetection` | Exact copies; legacy Wandering currently requires the current AI path, legacy Searching requires an absent nested AI.StateMachine.NoiseDetection. Repair/archive callers before choosing one retained implementation. |
| `ServerAssets/Entities/Phil/Initializer.server` and `PhilOld/Initializer.server` | Both require missing Classes.AI. Determine which template can be cloned/enabled; redirect only intentionally active templates. |
| `Communication/Packet/Types/Static1`, Static2, Static3 | Exact source instances inside a custom serializer. The second pass verified Types registers each as a separate byte-indexed dictionary (Static1/2/3), with example contents. Keep separate configurable serializer identities while Packet remains; shared implementation code is optional and low priority. |
| `ReplicatedFirst/Unused/Acid/Rig/Animate.client` and `Animate__19136.client` | Exact 576-line copies under an unused asset tree; generated-looking suffix is not evidence of authorship. Confirm asset references before archiving. |
| StarterCharacterScripts/Animate.client and StarterPlayerScripts/RbxCharacterSounds.client | Identical short suppression stubs. Different execution locations and intended default suppression make this intentional, not a useful abstraction target. |
| Workspace Ignore SoundTriggers Crows/Bats Test Config | Identical scene configuration copies; they can be intentionally independently tunable. Do not introduce shared mutable config merely for textual DRY. |

**Near duplicates/alternatives.** Current `AI/Pathfinding` versus `AIOld/NewPathfinding` is about 95.7% text-similar, with meaningful pivot, typing, Compute return and route-handling differences; headers claim 1.81 and 1.811. Legacy `AIOld/Pathfinding` is a third implementation. Trace current StateMachine/behavior callers and legacy template references before selecting/updating an upstream pathfinder. Preserve local behavioral diffs. `Hitbox`, `NewHitbox` and Fastcast are different collision/casting approaches; existing Melee/MovingProp callers matter more than similar names.

**Candidates, not approved deletions.** AIOld (including undefined aiFolder in Phil/Main), ReplicatedFirst/EntitiesOld, Unused, empty Phil Health/Bats/Shop hooks, uncalled dialogue wrappers, absent Gun controllers despite Revolver/Gun config, custom Packet with no application require found, and unused server AssetPreloader. Startup scans and Studio ModuleScript/asset references can invoke modules without a literal source require. PackageLinks also carry behavior outside the export's property data.

**Sequence.** Record each candidate's direct requires, dynamic loaders, sourcemap placement, tags/attributes, clone sites and Studio references. Separate first-party active, legacy, template/demo and vendor code in a small inventory. Quarantine/disable proven dormant asset behavior in a staging place, run representative sessions, then remove one cluster at a time with the old place version retained. Record origins/licenses/versions and local patches before any package update. There is no manifest-driven vulnerability audit to run today; vendored source review is not a claim that dependencies have no vulnerabilities.

**Acceptance.** No missing requires/templates/remotes after removals, source map regenerated, UI stories and active behaviors still load, and the retained dependencies have reproducible origins and compatibility notes. Do not claim code was AI-generated; address actual symptoms—no-op methods, duplicate knowledge, stale paths and needless adapters.

### R13 — Add operational signals, then measure performance risks

**Scope:** do not add instrumentation, benchmarks or optimization changes to Shop/AI. Their rows below are deferred reference candidates.

**Observed reliability/observability gaps.** Bootstrap pcall/warn can leave partially started features; deferred init failures escape it. Many effect/tool cleanup hooks swallow errors. Only profile errors have consistent store/key context; no application readiness summary, metrics/traces or correlation IDs are configured. `PlayerData.load` supplies a Cancel callback that only checks whether the player left; review the vendored ProfileStore timeout behavior before deciding how long admission may wait. `GroupChecker` performs its yielding group call before its Studio exclusion and has no protected lookup. There is no documented release/rollback process.

**First increment.** Report startup results and durations per required/optional system, profile/inventory load result, rejected remote counts, queue depth/wait/failure, stale generation discards, active in-scope controller/task counts and round progress/result failures. Use a small structured logging adapter only if it removes repeated formatting; include action/item ID and an operation ID where useful, not full profiles or raw adversarial payloads. Bound/summarize repeated rejection logs. Expose readiness only after required initialization completes. Specify profile-load deadline and group-lookup failure policy; avoid adding retries around ProfileStore's existing retry/session management blindly.

| Measured candidate and source | Why investigate | Measurement and decision |
| --- | --- | --- |
| `Foligen.generate`, Settings, placement/spatial modules | 22,600 placement attempts before player handlers; 128-sized yielding batches; clone/geometry work and large scene | Record generation duration, accepted count and startup memory. Evaluate pre-generated/streamed foliage only if startup budget fails; preserve seed/distribution. |
| `Controllers/Player.updatePlayerMemory` | Every 0.1s per character scans mapped rooms; stale loops can multiply after respawn | Fix R06 first. Profile time versus players/rooms; use spatial lookup only if this dominates. |
| `AI/Targeting/Registry`, Perception, Pathfinding | Repeated discovery, raycasts and path computation per NPC | Fix cache correctness first; profile two/ten/target NPC counts, path requests and target update cadence. |
| `SI/Service.commit` and `SI/Replication/InventoryReplica` | Full inventory profile serialization each commit plus field replication; bounded at 10+40 slots but may be frequent | Measure request frequency, snapshot/replica bytes and lock duration. Avoid premature incremental persistence complexity for a small bounded inventory. |
| Volumetrics/Renderer, LensFlare, weather, ViewModel/ArmMotion | Per-frame scene/UI work and layered effects | Client MicroProfiler captures on target mobile/desktop settings; compare Reduced Effects. Preserve photosensitivity behavior. |
| `Player/Effects/Interactables`, PivotDoor | Springs/render updates; server fallback can keep Heartbeat after settling | Confirm which assets select server fallback. Unsubscribe/sleep settled motions only after visual/late-join tests. |
| Crows, SpitPuddle, MovingProp | Repeated overlap queries; SpitPuddle caps MaxParts at 32 | Measure query cost and crowded-scene correctness (cap can miss entities), not just average FPS. |
| Flashlight/Lantern, streaming focus, preload caches | Unbounded call-driven allocation/retention in identified paths | R02/R06 fix before baseline; soak repeated toggles/joins and verify stable Instances/memory. |
| Results group lookup | One yielding external call per surviving player in a serial result loop | Cache group status with explicit freshness/failure policy, observe round completion latency. |

**Physics security validation.** Current AI explicitly sets server ownership; MovingProp damage depends on velocity without an observed matching ownership policy. Check who simulates damaging props and whether player-owned motion can spoof impact. Keep trusted hit/damage plausibility checks and choose ownership with latency/performance tradeoffs, not a blanket transfer of every part to the server. See [Roblox network ownership](https://create.roblox.com/docs/physics/network-ownership).

**Acceptance.** A staged failure is attributable to a component/operation; no critical startup failure leaves an apparently ready game. Capture representative p50/p95 frame time, server heartbeat/script time, memory, remote traffic and round/startup latency before assigning performance targets. Use [Roblox performance identification](https://create.roblox.com/docs/performance-optimization/identify) and [MicroProfiler network data](https://create.roblox.com/docs/performance-optimization/microprofiler/network). No performance speedup is claimed by this audit.

## 4. Security and production-readiness scope

Baseline examined: remote senders/payloads/rates/context, proximity interactions, profile session ownership, item ownership and mutation, server/client state trust, physics-driven damage, dynamic require paths, dependency locations, secrets/network/configuration surface and cleanup. No numeric asset-ID requires, loadstring, or application HttpService GetAsync/PostAsync/RequestAsync call sites were found in the repository-wide search. HttpService GUID generation is ordinary identity generation, not HTTP access. No configured credentials/secret store was identified; asset IDs/place/group IDs are not secret credentials. This is a source baseline, not a penetration test or an assertion about Studio-only assets, installed plugins or external account permissions.

SQL injection, database query pagination/N+1, SSRF and web routing are not applicable to the observed application stack. Relevant analogues here are RemoteEvent spam/fan-out, untrusted physics, unbounded queues/tasks, serial group calls and destructive saved-record normalization. Foligen accepts configured output paths rooted in game/workspace/ServerStorage/etc. and may delete an existing Folder without verifying a GeneratedFoliage ownership marker. This is a privileged developer-config hazard, not a remotely reachable path traversal: constrain approved roots and verify generated ownership before destructive regeneration.

Before release, verify the place's Enabled scripts, remote hierarchy, asset permissions, API services, group policy, streaming/collision configuration and dependency PackageLinks; rehearse a place rollback and profile migration recovery. Keep these concrete checks in the release runbook created by R00/R13, not as a generic security checklist added to player-facing UI.

## 5. Verification already performed

All commands were read-only with respect to production source. Temporary scripts/logs lived under the machine's temporary `northhills-audit` directory; they are not a permanent harness. Installed executables were used; no dependency upgrades were performed.

| Check | Observed result | Limits / next use |
| --- | --- | --- |
| File/source map enumeration | 617 Luau files; all mapped file paths exist; 44,904 nodes at final verification | Does not validate missing properties, Enabled scripts or non-code assets. |
| Full source compile with Lune 0.10.5 `@lune/luau.compile` | 617 passed, 0 failed | Syntax only; no Roblox engine execution. |
| Actual InventoryProtocol loaded in isolated Lune probe | 17 assertions passed | Covered scalar request validation: unknown/empty actions, equip/slot bounds, finite/NaN/infinity, ID length, same-ID merge, selected valid upgrade/release and unexpected unequip field. No Vector3/Instances/remote integration. |
| Selene 0.31.0 `--display-style Json2 sync` | Exit 1: 579 errors, 698 warnings, zero parse errors | 547 undefined-variable diagnostics, largely vendor test globals; 308 unused variables. AIOld/Phil/Main's aiFolder is a real unresolved name; InventoryStore's type-function types is not. |
| Luau-enabled StyLua 2.5.2 `--check --syntax Luau --allow-hidden --output-format Summary sync` | Exit 1: 154 files would change | No repository formatter config. An initial PATH build lacked Luau and its directory result was discarded. No formatting applied. |
| luau-lsp 1.69.0 analyze with platform roblox, sourcemap and local cached definitions | Exit 1: 500 TypeError, 45 LocalUnused, 11 ImportUnused, 9 LocalShadow, 7 ImplicitReturn, 6 DeprecatedApi, 3 FunctionUnused, 1 UnreachableCode | 582 diagnostics total. Definitions were a local VS Code PluginSecurity cache with no pinned revision. InputActionService/@self resolution and mixed tooling contribute substantially. Do not present every diagnostic as a gameplay defect. |
| Second-pass actual-source probes | ReconcileTable + real DataTemplate restored 8 hotbar/2 storage starter records; actual Registry returned nil for a second agent in the shared refresh window | Pure reconciliation and a mocked empty scene respectively; neither is a Studio gameplay test. |
| Exact and near-duplicate searches | Six exact-content clusters; semantic comparisons and caller searches in R11/R12 | Source absence of a literal caller does not establish Studio asset unreachability. |
| Build, Studio multi-client, live DataStore, profiling, dependency vulnerability scan | Not executed | No connected Studio/full place, build manifest, test runner or lockfile. No live behavior/performance claims. |

Commands to reproduce the static baseline are in the guide. R00 should preserve a tested compiler/protocol harness and pinned definitions so these results are reproducible without this machine's temporary files.

## 6. Proposed behavioral regression suite

Add tests around externally meaningful invariants, not constructors or mocked call counts that merely mirror the implementation. Use pure fixtures where possible, Studio integration when Roblox semantics matter.

| Layer | First cases | Gates |
| --- | --- | --- |
| Pure protocol/config | Action matrix; nonfinite/bounds/huge IDs; settings scalar/legacy normalization; item zone/type/stack rules | R02/R04/R09 |
| Persistence | Migration fixtures, idempotence, future-version rejection, missing template without overwrite, starter items not regranted after save/load, duplicate normalized slot keys | R03 |
| Inventory Instances | Conservation/unique IDs across move/swap/split/merge/grant/pickup/upgrade/drop; injected replacement failure | R04/R05 |
| Queue/equip/throw | Concurrent waiters, queue full, yielding callback contract, leave/death mid-transition, duplicate/reordered release | R05/R06 |
| Multiplayer lifecycle | Two clients, ten respawns, late GUI/Replica, old packet after new character, repeated ready | R01/R02/R06 |
| AI (deferred; do not add tests now) | Two agents sharing refresh interval, distinct target folders, no target, exit during retry, destruction | R07 |
| World/rounds | Missing prop/template; locked door; rapid toggle/removal; late join and failed group call; duplicate results | R02/R06/R08 |
| Shop economics/dialogue (deferred; do not add tests now) | Real grant/debit result, full inventory, retry, abandoned/expired session | R10 |
| UI/device | Existing UI Labs stories plus real keyboard/touch/gamepad, inventory-open input gating, reduced-effects modes | R01/R11/R13 |
| Staging persistence/operation | Live store session contention/loss, shutdown save, join timeout, rollback-compatible migration | R00/R03/R13 |

Run Roblox server/client tests with controlled latency/jitter/loss, especially equip, throw, resync and death. Current official [Studio testing modes](https://create.roblox.com/docs/studio/testing-modes) and [Network Simulator](https://create.roblox.com/docs/studio/network-simulator) describe the available engine test tools. A Studio Mock profile pass does not replace the staging persistence row.

## 7. Research and version applicability

Primary sources were consulted on 2026-09-15 to validate repository-specific recommendations. They do not establish the version or behavior of an unpinned vendored copy.

| Source | Specific use / version boundary |
| --- | --- |
| [Azul documentation](https://azul.ransomwave.games/) and [per-place daemon config](https://azul.ransomwave.games/advanced/place-daemon-config/) | Confirms Studio-first sync model; local Config is empty and no Azul version is pinned. Do not substitute a fictitious Rojo build. |
| [Roblox client/server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary) | Supports type/value/context validation and server rate limits for R02. Existing inventory checks were inspected separately. |
| [ProfileStore API](https://madstudioroblox.github.io/ProfileStore/api/) and [upstream source](https://github.com/MadStudioRoblox/ProfileStore/blob/main/ProfileStore.luau) | Reconcile versus migration; Cancel/session lifetime; EndSession and final saving. Local ProfileStore is vendored without a release pin; compare relevant implementation before upgrading. OnSessionEnd is not a place to perform final profile writes. |
| [Luau type functions](https://luau.org/types/type-functions/), [table types](https://luau.org/types/tables/), [property modifier RFC](https://rfcs.luau.org/syntax-property-access-modifiers.html) | Distinguishes legitimate type-function globals/read-only types from runtime immutability and tool false positives. Pin compiler/LSP support before changing syntax. |
| [luau-lsp CLI](https://github.com/JohnnyMorganz/luau-lsp/blob/main/README.md) and [editor setup](https://github.com/JohnnyMorganz/luau-lsp/blob/main/editors/README.md) | CLI definitions and sourcemap setup for R00; audited binary 1.69.0, API definition revision unknown. |
| [StyLua](https://github.com/JohnnyMorganz/StyLua) | Luau feature availability matters; audited Luau-capable binary 2.5.2, no formatter config in repo. |
| [Lune Luau API](https://lune-org.github.io/docs/api-reference/luau/) | Actual-source compile/load probe using local Lune 0.10.5; not a Roblox runtime simulator. |
| [Roblox network ownership](https://create.roblox.com/docs/physics/network-ownership), [ReplicationFocus](https://create.roblox.com/docs/reference/engine/classes/Player/ReplicationFocus) | R02/R13 physics/streaming validation. An Instance-typed API declaration does not verify this game's empty Model focus behavior. |
| [Studio testing modes](https://create.roblox.com/docs/studio/testing-modes), [Network Simulator](https://create.roblox.com/docs/studio/network-simulator) | Engine-level multiplayer and network impairment tests absent from the current baseline. |
| [Performance identification](https://create.roblox.com/docs/performance-optimization/identify), [MicroProfiler network](https://create.roblox.com/docs/performance-optimization/microprofiler/network) | Measure actual frame/network costs before architecture changes. |

Versioned vendored paths inspected: Vide 0.4.0, Replica 1.0.3, UI Labs 2.4.2, Janitor 1.18.3, Signal 2.0.3, typed-promise 4.0.6 and evaera/promise 4.0.0. Package provenance and local modifications still need R12. No recommendation assumes that current online API documentation matches a newer installed package than these copies.

## 8. Audit coverage and review record

The first pass traced server/client startup, profiles/settings, all inventory action families and their UI/replica consumers, combat/projectiles/status, rounds/weather/results, current/legacy AI and sensing, world generation/props/interactables, dialogue/shop, camera/viewmodel/animation, input/UI/haptics, shared helpers and dependencies. It inventoried the full tree, scanned all Luau sources for relevant symbols/callers/boundaries and compiled all sources. Active first-party behavior was read more deeply than bundled vendor implementations; this is not a claim that every vendor line was manually reviewed.

### Second independent adversarial pass (after both initial drafts)

The drafts were treated as untrusted claims and checked against lower-level implementations and actual consumers, rather than merely proofread. This pass found or changed the following:

1. **New higher-priority persistence finding:** traced PlayerData.Reconcile through the vendored recursive ReconcileTable and compared string-keyed starter slots with InventoryCodec's empty-slot omission. The actual-source probe reproduced item replenishment. R03, the verification table, regression suite and guide now include it. Hydrator's numeric-key normalization also admits duplicate slot aliases; recovery tests now cover that separately from duplicate IDs.
2. **New competing catalog owner:** reread Buy/ItemInfo and Dialogue/Registry, exposing independent last-wins flattening and WoodenBat versus BaseballBat identity drift. R10/R11 now separate offers from canonical inventory items. A stale ItemUtils compatibility comment was not accepted as proof that Shop uses that helper.
3. **Refined AI finding:** ran the actual Registry against an empty mocked scene to reproduce the second-agent nil result. cacheLookup is write-only in current source; the plan no longer claims a demonstrated cross-agent read from it. Corrected target-folder terminology and retained the concrete refresh ownership fix.
4. **Refuted false-positive cleanup/startup claims:** Replica.OnNew announces existing replicas; Hitbox.Stop with default AutoDestroy disconnects hit signals; Packet Static1/2/3 are distinct registered dictionaries. Preserved intentional suppression/config copies and vendor boundaries. Confirmed Ragdoll has a destroy API and the wrapper omits it.
5. **Refuted a physics shortcut:** checked RespectCanCollide source configuration and official documentation; CanQuery=false does not by itself establish invisible player targets. Retained engine tests without presenting a false defect.
6. **Rechecked lifecycle evidence:** Menu and CharacterHandler still both create character controllers; the actual flag is hasLoadedPlayerControllers and the helpers are under ClientUtilities. Corrected the guide's ClientLoader location to StarterPlayerScripts and Bootstrap cleanup symbol to destroyModules.

Both documents were reread for source-path validity, inconsistent ownership claims, duplicate recommendations, distinction between completed checks and proposed tests, and unjustified deletion/rewrites. Final hash checks verified all 617 Luau files and selene.toml unchanged, and all document links resolve. sourcemap.json changed outside the audit edits from 44,905 to 44,904 nodes with the same 617 source mappings; its current version was preserved. The responsible process was not identified. Only CODEBASE_GUIDE.md and REFACTOR_PLAN.md were authored by this audit. Remaining limitations are the missing full Studio place/runtime access, unpinned API definitions, dynamic asset references and unmeasured live behavior; none are represented as completed runtime verification.
