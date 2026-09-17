# North Hills Agent Instructions

This file is the repository-wide operating contract for AI agents. Read it before investigating, planning, editing, or running commands. It applies to the entire repository unless a more deeply nested `AGENTS.md` supplies narrower instructions.

## 1. Source of truth and required reading

Use this precedence when instructions conflict:

1. The user's current, explicit request and approved scope.
2. This `AGENTS.md`.
3. `CODEBASE_GUIDE.md` for the current architecture, ownership boundaries, known behavior, and repository limitations.
4. Feature documentation such as `KeybindPlan.md`, the relevant portions of `REFACTOR_PLAN.md`, and any README beside the code being changed.
5. `StyleGuide.md` for North Hills-specific Luau conventions.
6. `CLEAN_CODE_GUIDE.md` for general principles only where they fit the existing codebase.

`NORTH_HILLS_CODE_INTEGRATION_AGENT_PROMPT.md` is the expanded source from which this contract was consolidated. Consult it when a rule here needs more detail. Do not let its existence excuse skipping this file.

Before non-trivial work, read `CODEBASE_GUIDE.md` and the relevant feature/supporting documentation in full. Read the files, callers, callees, tests, and nearby modules involved in the requested behavior. Source code is evidence of current behavior, not permission to broaden the task.

The style documents contain ideals that predate parts of the repository. Existing architecture and feature-specific contracts win over generic style advice. Do not perform broad rewrites merely to make old code match a guide.

## 2. Repository reality

North Hills is a Roblox/Luau multiplayer survival game. This checkout is an Azul, Studio-first source export, not a self-contained build artifact.

- `sync/` contains the mapped Luau source.
- `sourcemap.json` describes the Studio hierarchy but omits many properties, attributes, enabled states, asset contents, and permissions.
- There is no demonstrated Rojo project, place file, dependency lockfile, CI workflow, or deployment procedure. Never invent a `rojo build` command.
- Studio is required to verify hierarchy, tags, attributes, assets, runtime behavior, and publication-sensitive behavior.
- `selene.toml` and `stylua.toml` are the root static-tool configurations.
- Treat documentation audit counts as snapshots; verify facts that may have changed.

Primary runtime ownership:

- `ReplicatedFirst/ClientControllers/Player/`: session/player-lifetime client presentation and behavior.
- `ReplicatedFirst/ClientControllers/Character/`: respawn-bound client behavior.
- `ReplicatedFirst/ClientControllers/Tools/`: local equipped-tool presentation and input feedback.
- `ReplicatedStorage/SharedUtilities/`: genuinely shared contracts and reusable operations.
- `ReplicatedStorage/SharedAssets/`: shared assets and configuration dictionaries.
- `ServerScriptService/Controllers/`: authoritative player/character/tool/status/projectile adapters.
- `ServerScriptService/Systems/`: long-lived authoritative features such as inventory, rounds, interactions, dialogue, and shop.
- `ServerStorage/ServerAssets/`: server-only templates, AI, classes, dictionaries, and other private assets.
- `StarterPlayer/StarterPlayerScripts/PlayerModule*`: bundled Roblox code; preserve upstream provenance.

Put code where its runtime owner belongs. Shared storage is not a generic convenience bucket. Server-only state and authority must remain server-only.

## 3. Scope and approval

For non-trivial changes, investigate first and present a concrete plan before editing. The plan must state:

- current and requested behavior;
- owning layer and control/data flow;
- files expected to change;
- contracts and invariants to preserve;
- risks and unresolved ambiguity;
- verification to run;
- any structural or protected-scope changes.

Wait for explicit user approval of that plan before implementing non-trivial work. Approval applies only to the described scope. Stop and re-plan if implementation requires materially different files, behavior, architecture, dependencies, migrations, or protected areas.

An edit may proceed without a separate plan approval only when it is genuinely tiny, local, obvious, reversible, behavior-preserving, requires no design choice, touches no protected area, changes no structure or contract, and has a clear verification path. If any criterion is uncertain, treat it as non-trivial.

Creating, deleting, moving, or renaming files/modules/folders; changing hierarchy; adding dependencies; introducing remotes, schemas, shared configuration, or frameworks; and broad formatting/refactoring are structural changes. They require explicit task scope or plan approval.

Do not absorb nearby defects or cleanup into the task. Report out-of-scope findings instead.

## 4. Protected areas

Do not modify these areas without a task-specific request and approved plan:

- Shop and dialogue purchase behavior, which is under active development.
- Current or legacy AI behavior and templates, which are under active development.
- Persistence schemas, reconciliation, profile lifecycle, or migration behavior.
- Networking protocols, remote payloads, rate limits, and replication contracts.
- The centralized keybind/input architecture.
- Vendored dependencies and bundled PlayerModule code.
- Character lifecycle ownership, which has a documented duplicate-owner problem.

Preserve protected interfaces when changing shared neighbors. A stub, empty callback, legacy module, or documented defect is not permission to invent product behavior or delete code.

## 5. Authority and trust boundaries

The server is authoritative for inventory, item identity/ownership, materials, money, survivals, settings validation, combat, world interactions, round state, persistence, and other protected gameplay state.

At every client-triggered server boundary, validate as applicable:

- player/session readiness and lifecycle generation;
- type, shape, range, finiteness, and identifier validity;
- ownership, permissions, state, distance, and rate limits;
- stale sequence/generation behavior;
- repeated or malicious requests.

Client UI checks are presentation, not authorization. Do not directly mutate profile or replicated state as a shortcut around the owning server service, protocol, queue, lock, mutation, commit, or replication path.

Inventory-specific invariants include stable `ItemId`, configured `ItemType`, distinction between materials and slot items, server-owned models/slots, per-player serialization, generation checks, and commit-driven profile/replica updates. Do not acquire the same inventory lock recursively.

Persistence changes require compatibility analysis, an explicit migration/rollback story, and controlled verification. Profile commits are not immediate DataStore saves. Do not claim mock testing proves live persistence semantics.

## 6. Keybind and input contract

The central keybind migration is implemented.

- Defaults live only in `sync/ReplicatedStorage/SharedAssets/Keybinds.luau`.
- Application actions use `SharedUtilities/InputActionService` through `ReplicatedFirst/ClientUtilities/InputBindings`.
- Create with `InputBindings.create`, subscribe with `InputBindings.connect`, use binding state rather than `IsKeyDown`, and destroy subscriptions/actions during teardown.
- One action name has one owner. Shared slider instances reuse one action set.
- GUI action buttons use `SetUIButton`.
- UIS is for pointer/device/focus observation and generic widget mechanics, not application shortcut registration.
- Native prompts are explicitly outside the catalog.
- Tool activation and Results dismissal have their documented specialized ownership; do not replace them with a parallel dispatcher.
- PlayerModule keyboard zoom bindings for `I`/`O` were intentionally removed. Preserve that change when updating PlayerModule.

Read `KeybindPlan.md` and the keybind section of `CODEBASE_GUIDE.md` before input work.

## 7. Architecture and lifecycle rules

Prefer the existing owner and established feature path. Do not create a parallel service, lifecycle, abstraction, protocol, or input system because the current path is inconvenient.

Use a utility module for stateless reusable operations. Use a stateful object/controller when it owns runtime state, instances, connections, tasks, or children. A module should have one coherent reason to change; do not split coherent behavior into microscopic files or merge unrelated domains to satisfy DRY.

For stateful modules:

- `.new()` captures dependencies and establishes cheap synchronous state; it must not launch unowned long-running work.
- `:preload()` performs optional preparation with explicit ownership and failure behavior.
- `:init()` connects and starts runtime behavior only after dependencies are ready.
- `:destroy()` disconnects every connection, cancels/invalidates tasks, destroys owned children/resources, releases bindings, and is safe to call twice.
- Avoid meaningful side effects at require time.

Retain every connection, task, binding, child controller, and temporary instance under the correct session/character/feature lifetime. Test character-bound behavior through death and respawn.

Do not add a dependency, framework, global constants layer, generic abstraction, or new module until the existing owner cannot coherently support the requirement and the structure is approved.

## 8. Coding conventions

Match the touched area first; improve clarity locally without unrelated churn.

- Use descriptive camelCase names for variables/functions and PascalCase for modules/types/classes, following established Roblox/service naming.
- Avoid unclear abbreviations, filler words, misleading names, and multiple terms for one concept.
- Boolean names should read as conditions where practical.
- Keep functions cohesive and at one conceptual level. Prefer guard clauses over deep nesting.
- Extract meaningful constants/configuration only into the feature's established owner.
- Prefer boundary typing for parameters, meaningful returns, public APIs, constructors, stable structures, protocols, and configuration.
- Use `any` only at unavoidable legacy/engine/interop boundaries and narrow it promptly.
- Prefer direct requires where used; do not add parent modules that unpack every utility.
- Use the local `--//` application-comment form when adding comments. Explain why, workarounds, constraints, or removal conditions—not ordinary control flow.
- Never leave commented-out code. Keep TODOs specific and contextual.
- Preserve third-party style and APIs in vendored code; do not restyle it.

Clean-code principles are judgment tools, not numeric mandates. Do not force arbitrary function/file length limits, maximum argument counts, blanket immutability, or abstraction solely to satisfy a rule.

## 9. Feature integration expectations

- Inventory: follow protocol → gateway/router → player queue/lock/generation → mutation → commit → replica/store/UI. Never shortcut it.
- Items/materials: preserve template/factory/allocation paths, stable identity, and the balance-vs-slot distinction.
- Settings: UI options are not server validation; preserve saved representation compatibility.
- Interactables: preserve authoritative permission/state/distance validation and handle destruction/streaming lifetimes.
- Session UI belongs to the player/session owner; respawn behavior belongs to the character owner.
- Shop or AI: protected unless the explicit task reopens the area.
- Gun code was intentionally removed. Do not restore firearm definitions, types, aiming, recoil, or viewmodel branches incidentally. General projectiles, Fastcast support, melee, thrown items, AI projectiles, flashlight/lantern, and grip tracking remain valid.

## 10. Verification

Verification is mandatory and proportional to the change. Run every applicable check actually available, and report only what ran.

Known repository-side commands include:

```powershell
selene --display-style Json2 sync
stylua --check --syntax Luau --allow-hidden --output-format Summary sync
luau-lsp analyze --platform roblox --sourcemap sourcemap.json --definitions <Roblox-definitions-file> sync
```

Confirm tool capability before relying on it. Do not claim formatting passed if the installed StyLua lacks Luau support. Use existing focused tests and feature-specific regression commands where present. Do not fabricate missing tools, test coverage, build commands, or results.

Keep formatting and diagnostics scoped. Distinguish:

- checks that pass;
- diagnostics introduced by the change (fix these);
- known or measured pre-existing diagnostics;
- checks unavailable or not run.

Choose behavioral cases from the affected flow: happy path, invalid/not-ready state, repeated activation, cleanup, death/respawn, leave/rejoin, multiple clients, latency, device modes, partial failure, and backward compatibility as relevant.

If Studio verification is needed but unavailable, run all repo-side checks, provide exact manual Studio steps and expected results, and report: **Implementation complete; manual Studio verification remains. This task is not fully done until the listed Studio checks pass.** Never imply Studio behavior was verified when it was not.

## 11. Documentation

Update documentation in the same task when an approved change alters an architectural/public contract, shared configuration, input action, remote protocol, persistence schema, migration, integration path, or required verification procedure.

Do not duplicate detailed facts unnecessarily. Keep this file stable and operational; put evolving feature detail in its owning guide and link it here when it changes agent behavior.

## 12. Required final report

After implementation, report exactly these sections:

## Changed

Concrete behavior/code changes.

## Why this location / architecture

Why the chosen owner and flow fit the existing system.

## Files affected

Every modified/created/moved/renamed/deleted file and its change.

## Contracts / invariants preserved

Important authority, ownership, API, protocol, persistence, identity, and lifecycle guarantees retained or intentionally changed.

## Tests run + results

Exact checks and outcomes, including introduced, pre-existing, and unavailable diagnostics.

## Manual Studio verification remaining

`None`, or exact steps and expected results plus the not-fully-done status.

## Known issues intentionally untouched

Out-of-scope defects or opportunities, or `None`.

## 13. Before every edit

Confirm all of the following:

- the edit is inside the user's approved scope;
- the relevant guides and code flow have been read;
- the actual runtime owner and cleanup lifetime are known;
- structural/protected changes are explicitly approved;
- server authority, public contracts, stable IDs, and known behavior are preserved;
- no incidental cleanup or speculative abstraction is included;
- the verification path is known.

When material facts remain uncertain after investigation, explain the uncertainty and ask the smallest necessary question. Do not guess about Studio state, product behavior, persistence compatibility, remote contracts, lifecycle ownership, or legacy reachability.

The operating principle is simple: understand the existing system, preserve its ownership and contracts, change the smallest justified surface, verify honestly, and leave unrelated behavior alone.
