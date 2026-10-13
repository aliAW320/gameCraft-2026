HOLLOW ORIGINAL ART PACK - GODOT 4 (AFTER MILESTONE 5)
=====================================================

INSTALL ON KALI LINUX:
1. Download hollow_art_pack.zip.
2. Run this from your existing Godot project folder (where project.godot lives):

   cd ~/hollow
   unzip -o ~/Downloads/hollow_art_pack.zip -d .
   bash hollow_art_pack/install.sh .

3. Open the project in Godot and run F5.

WHAT IS APPLIED:
- Player, Husk, Skitter, Brute, and Hollow Guardian visuals
- XP, gold, heart, cache visuals
- Soul Needle and boss orb visuals
- Void Pulse and Orbiting Shade decorative overlays
- Ruins, runestones, floor slabs, and arena sigil visual layer

WHAT REMAINS AS-IS:
- Combat, stats, hitboxes, projectile collisions, the shop and level-up systems
- Godot's drawing-based placeholder shapes behind the artwork (may show as extra glow)
- HUD and card layout (UI assets are included as individual PNGs, but aren't auto-attached)

This is an original static-sprite FIRST PASS, not animated spritesheets.
All asset art is PNG with alpha and was extracted from the generated art sheets.
Some environment textures are decorative rather than seamless tiles.

GODOT NODE LOCATIONS:
- Player/ HollowArt: res://scenes/player/player.tscn
- Player/ SpellManager/ HollowSpellArt
- Enemy/ HollowArt: res://scenes/enemies/enemy.tscn
- HollowGuardian/ HollowArt: res://scenes/enemies/boss.tscn
- World/GroundDecorations/HollowEnvironmentArt: res://scenes/main.tscn
- Pickups and projectiles each have a HollowArt sprite node.

HOW TO TUNE ART SCALE:
Edit scripts/visuals/hollow_art.gd: desired_span values control visual size.
Collision radii are unchanged. The script changes appearance only.

UNINSTALL/ROLLBACK:
If you want to undo this, use the timestamped .hollow_backup_art_* folder
created in the project root to restore the modified scenes. For new assets,
remove assets/hollow_art/ and scripts/visuals/ if desired. Keep the original
project backup or Git commit before testing changes.

TESTING:
F5 run game / K summon Guardian / V trigger Hollow Surge.
