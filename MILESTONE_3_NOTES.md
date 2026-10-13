# HOLLOW - Milestone 3

Adds three enemy archetypes, scaled enemy waves, Fractured elites,
gold/heart/cache drops, and a merchant shop.

## During play
- Move: WASD / arrow keys.
- Every enemy drops XP; normal enemies also have a 25% chance of gold and 1% chance of a heart.
- Fractured elites have purple auras and drop a guaranteed 8 XP + 8 gold cache.
- Merchant visits: 02:00, 04:00, and 06:00 (unpaused gameplay time).
- Buy one of three randomly chosen items or skip. Each item can be purchased twice per run.

## Debug shortcuts (editor / debug builds only)
- G: grant enough XP for a level-up.
- H: grant 30 gold.
- B: open a test merchant without consuming a scheduled visit.
- N: advance the clock by one minute for shop/spawn testing.
- R: restart after death.

## Source files
- scripts/actors/enemy.gd: three enemy types and Fractured modifiers.
- scripts/systems/spawn_director.gd: timed/weighted spawns and elite encounters.
- scripts/systems/loot_pickup.gd: gold/heart/cache pickups.
- scripts/managers/run_manager.gd: gold, XP, scheduled shop interactions.
- scripts/managers/shop_manager.gd: item options and their effects.
- scripts/ui/shop_panel.gd: shop UI and buttons.
