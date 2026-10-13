# HOLLOW - Milestone 7: Six-Boss Gauntlet

**Duration:** six minutes of timed survival. The clock freezes at 06:00 for
final battle, so actual elapsed real-world time can be a bit longer.

**Boss schedule:**

1. **01:30 Ash Warden** (main checkpoint) - telegraphed fan of five aimed bolts;
   always vulnerable. 365 HP.
2. **02:15 Veil Stalker** (interlude) - quick flank teleport and red-line dash;
   move sideways. 530 HP.
3. **03:00 Thorn Oracle** (main checkpoint) - dense purple ring with a safe gap;
   bonus damage when recovering. 755 HP.
4. **04:30 Rift Colossus** (main checkpoint) - two marked ground slams; armored
   except during recovery. 1050 HP.
5. **05:15 Mirror Seraph** (interlude) - crossing energy beams that rotate each
   use; more armor between attacks. 1360 HP.
6. **06:00 Hollow Sovereign** (final checkpoint) - rotates between gap-rings,
   triple slams, three crossing beams, and a fast charge; accelerates below
   half health. Heavy armor between attacks; exposed after attacking. 1980 HP.

There are four 90-second checkpoint bosses (01:30/03:00/04:30/06:00),
plus two interlude bosses to deliver six total. Only one boss can exist at once.
If you take longer to defeat one, the next encounter is queued rather than
spawned on top of you. The 6:00 clock stays fixed for the final boss.

**Shops:** 02:00, 04:00, 05:30. A shop delayed by a boss appears after the
boss is defeated and before another encounter. Spell and relic systems remain
unchanged. Non-final bosses provide gold, XP, a small heal, and score.

**Debug commands (editor builds only):**
- `K`: summon the next boss now (one at a time)
- `O`: defeat the current boss instantly
- `J`: 400 damage to the boss
- `N`: advance the clock 60 seconds
- `G`: force level-up / `H`: add gold / `B`: open shop
- `Q`: Void Lightning when charged / `L`: debug-fill its charge
- `V`: Hollow Surge

Debug actions prevent record saving. Use K then O six times for a quick
end-to-end smoke test, then play a full normal run.

**Compatibility/safety:** Previous boss.gd preserved. New logic lives in
`scripts/actors/boss_gauntlet.gd`; the boss.tscn Script reference is changed.
The installer backs up every changed file, preserves Godot-generated UIDs,
and does not duplicate its changes if run twice. No need for new sprites yet:
all six bosses reuse the existing Guardian artwork with different tints/sizes.

If a manual project customization has changed a required script anchor, the
installer will stop before modifying files; send us the relevant file rather
than deleting it or reverting your changes.
