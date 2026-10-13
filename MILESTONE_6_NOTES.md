# HOLLOW - Milestone 6: Five Spells, Four Slots, Relic Shop

## Five normal spells, maximum four equipped
- Soul Needle: starting projectile, always counts as one slot.
- Void Pulse: area attack, unlocked from level-up.
- Orbiting Shade: rotating orb, unlocked from level-up.
- Abyssal Spear: 40 base damage, pierces 3 enemies, 3.6 sec cooldown.
  Levels: pierce 5, damage 62, cooldown 2.6 sec.
- Death Bloom: 22% kill chance for a 100px blast, 30 damage.
  Levels: 33% chance, 125px/44 damage, 44% chance/150px.
- Four of these five can be equipped in a run. The fifth does not appear
  as a new unlock after all four slots are occupied.
- Already-equipped spells can still be upgraded to level 4.
- Hollow Surge and manual Void Lightning are ULTIMATES and use no slots.

## Merchant now sells six different relics
- THORN IDOL (17): damaging nova when hit (2 sec cooldown).
- BLOOD CHALICE (14): every 12 kills restores 10 HP per copy.
- GILDED FANG (12): every 10 kills earns 2 extra gold per copy.
- SOUL BATTERY (18): every 10 kills charges Void Lightning by 4 per copy.
- MAGNET BELL (15): every 15 kills pulls dropped loot within 500/650px.
- SECOND BREATH (24): one-use rescue from death, 40 HP + 2s protection.
Shop is at 2:00/4:00/6:00 as before, one purchase per visit.
All relics last only for the current run. They are NOT stat upgrades duplicated
from level-up cards. Level-up passives remain unchanged.

## Test shortcuts (editor/debug builds only)
- G: enough XP for next level-up, then choose a card.
- 7: unlock or improve Abyssal Spear, if a spell slot is available.
- 8: unlock or improve Death Bloom, if a spell slot is available.
- H: +30 gold; B: show shop.
- L: charge Void Lightning; Q: activate.
- V: force Hollow Surge, K: summon boss.
Any debug shortcut disables high-score recording for that run.

## Smoke tests
1. Start fresh: HUD says SPELLS 1/4.
2. Press 7 and 8: HUD becomes 3/4, both spells activate automatically.
3. Unlock Pulse or Shade: HUD becomes 4/4.
4. At 4/4, unavailable new spell no longer appears; others upgrade normally.
5. Kill enemies: some deaths cause purple Bloom explosions, not infinite chains.
6. H then B: shop cards feature TRIGGER RELICS, not ordinary stat buffs.
7. Buy a relic, verify its triggered behavior, then restart; no relic persists.
8. Summon boss: spear can hit the boss; regular combat and lightning remain.

## Notes
- The installer modifies scripts in place with backups but does not touch
  existing artwork, existing player collision shapes, or Void Lightning scripts.
- New spell visuals are procedurally drawn; no additional PNG required.
- Shop purchases are intentionally run-specific. Second Breath is capped at 1.
