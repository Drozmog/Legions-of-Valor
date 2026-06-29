# Battlefield architecture

Target runtime: Godot 4.7, matching `project.godot`.

`BattlefieldManager` is now a scene-state facade: it owns scene nodes, shared match state,
lifecycle wiring, and compatibility wrappers. Domain controllers own behavior. Wrappers retain
the original public method surface for signal connections, `has_method`, and dynamic `call` users.

## Extracted domains

| Domain | Owner | Dependencies |
| --- | --- | --- |
| Parry chain | `ParrySystem.gd` | Battlefield host for card movement and combat completion |
| Card animation | `CardAnimationManager.gd` | Scene destinations and card visuals |
| Tribute economy | `TributeManager.gd` | None beyond emitted status events |
| Random enemy deck construction | `ai/AIRandomDeckBuilder.gd` | Injected battle-log callable |
| Enemy difficulty policy | `ai/AIDifficultyProfile.gd` | Difficulty integer only |
| Enemy diagnostics | `ai/AIDebugPanel.gd` | Read-only BattlefieldManager query/state API |
| Contextual phase help | `ui/PhaseTipPanel.gd` | Read-only phase state from BattlefieldManager |
| Insight card presentation | `ui/InsightPresentation3D.gd` | Battlefield modal lock and inspect panel |
| Board action controls | `BoardSlotActionButtons3D.gd` | Slot/action data supplied by manager |
| Phase and battleplan flow | `phase/BattlefieldPhaseController.gd` | Shared phase state, hand, AI and combat facade APIs |
| Player placement legality | `deployment/BattlefieldDeploymentController.gd` | CardRules, TributeManager, hand and board slots |
| Pointer/drag board interaction | `interaction/BattlefieldInteractionController.gd` | Camera, hand, piles and board facade APIs |
| Ability resolution | `abilities/BattlefieldAbilityController.gd` | AbilityResolver, presentation UI and combat facade APIs |
| Combat resolution | `combat/BattlefieldCombatController.gd` | ParrySystem, abilities, scoring and board state |
| Adaptive enemy logic | `ai/BattlefieldAIController.gd` | Difficulty profile and battlefield facade APIs |

## Deliberate facade boundary

Shared match state remains on `BattlefieldManager` so existing scene scripts and resources retain
their exact access paths. Controllers hold one typed host reference and do not duplicate state.
This is an intentional strangler-facade design: behavior is modular, while save/runtime identity,
signals, and dynamic Godot calls remain stable.

The refactor reduced `BattlefieldManager.gd` from 10,836 lines to about 3,370 lines. Most of the
remaining methods are lifecycle/UI ownership or thin compatibility delegates into controllers.

## Cross-reference rules

- UI classes never mutate combat, deployment or AI policy directly; they emit intent.
- AI planners consume board snapshots and return actions; the manager/controller executes them.
- Ability eligibility and ability execution stay in the same domain to avoid divergent rules.
- Lane priority and lane-resolution state stay with combat resolution.
- Card classification and setup-cost rules come only from `CardRules`.
- Domain-to-domain calls go through explicit APIs; no `get_parent()` service discovery.

## Removed dead paths

The refactor removed unreferenced prototype deployment/combat selectors, obsolete Gambit-cost
wrappers, an unused random opponent spawner, unused AI fallback action finders, and an obsolete
ability-icon polling entry point. Signal callbacks and dynamically invoked AbilityResolver APIs
were retained even when they have no direct call expression in BattlefieldManager.
