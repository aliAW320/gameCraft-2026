#!/usr/bin/env python3
"""Install Hollow original sprite art without replacing the gameplay scripts.
Uses only Python's standard library. Safe to re-run; creates backups on modifications.
"""
from pathlib import Path
from datetime import datetime
import re, shutil, sys, os, tempfile

pack = Path(sys.argv[1]).resolve()
root = Path(sys.argv[2]).expanduser().resolve()
if not (root/'project.godot').is_file():
    sys.exit('ERROR: Cannot find project.godot. Run installer from Hollow project root, or pass its path.')

# Scene identifier, art category, and attach point.
SCENES = {
 'scenes/player/player.tscn': [('HollowArt','Sprite2D','.','hollow_art_visual','hollow_art.gd','player'), ('HollowSpellArt','Node2D','SpellManager','hollow_spell_visual','hollow_spell_art.gd',None)],
 'scenes/enemies/enemy.tscn': [('HollowArt','Sprite2D','.','hollow_art_visual','hollow_art.gd','enemy')],
 'scenes/enemies/boss.tscn': [('HollowArt','Sprite2D','.','hollow_art_visual','hollow_art.gd','guardian')],
 'scenes/pickups/pickup.tscn': [('HollowArt','Sprite2D','.','hollow_art_visual','hollow_art.gd','xp')],
 'scenes/pickups/loot.tscn': [('HollowArt','Sprite2D','.','hollow_art_visual','hollow_art.gd','loot')],
 'scenes/spells/projectile.tscn': [('HollowArt','Sprite2D','.','hollow_art_visual','hollow_art.gd','needle')],
 'scenes/spells/boss_bolt.tscn': [('HollowArt','Sprite2D','.','hollow_art_visual','hollow_art.gd','boss_bolt')],
 'scenes/main.tscn': [('HollowEnvironmentArt','Node2D','World/GroundDecorations','hollow_environment_visual','hollow_environment_art.gd',None)]
}

EXPECTED_PARENT = {'scenes/player/player.tscn':'SpellManager', 'scenes/main.tscn':'GroundDecorations'}
RESOURCE_PATTERN = re.compile(r'(?m)^\[ext_resource [^\n]+\]$')

def update_scene(rel, specs, raw):
    if not re.search(r'(?m)^\[gd_scene\b[^\n]*\]$',raw):
        raise ValueError(f'{rel}: not a .tscn text scene')
    for token in (EXPECTED_PARENT.get(rel),):
        if token and not re.search(r'\[node name="'+re.escape(token)+r'"(?=[\s\]])', raw):
            raise ValueError(f'{rel}: required node {token} missing; scene structure differs from Milestone 5.')
    output = raw
    additions = []
    for node_name, node_type, parent, ext_id, gd_script, category in specs:
        node_pattern = r'(?m)^\[node name="'+re.escape(node_name)+r'"[^\n]*\]$'
        if re.search(node_pattern,output):
            # Existing installed art nodes should remain untouched.
            if f'path="res://scripts/visuals/{gd_script}"' not in output:
                raise ValueError(f'{rel}: existing {node_name} node is unrelated; not overwriting it.')
            continue
        if re.search(r'(?m)^\[ext_resource [^\n]*id="'+re.escape(ext_id)+r'"\]',output):
            if f'path="res://scripts/visuals/{gd_script}"' not in output:
                raise ValueError(f'{rel}: resource id {ext_id} conflicts with existing file.')
        else:
            additions.append(f'[ext_resource type="Script" path="res://scripts/visuals/{gd_script}" id="{ext_id}"]')
        node = f'[node name="{node_name}" type="{node_type}" parent="{parent}"]\nscript = ExtResource("{ext_id}")\n'
        if category:
            node += f'art_type = "{category}"\n'
        output += '\n' + node
    if additions:
        # Insert near the top, independent of Godot-generated UIDs / formatting.
        header = re.search(r'(?m)^\[gd_scene\b[^\n]*\]$',output)
        output = output[:header.end()] + '\n\n' + '\n'.join(additions) + output[header.end():]
    if output != raw:
        count = 1 + len(re.findall(r'(?m)^\[ext_resource\b',output)) + len(re.findall(r'(?m)^\[sub_resource\b',output))
        output = re.sub(r'(?m)^\[gd_scene([^\n]*)\]$',lambda m:'[gd_scene'+(re.sub(r'\bload_steps=\d+',f'load_steps={count}',m.group(1)) if 'load_steps=' in m.group(1) else ' load_steps='+str(count)+m.group(1))+']',output,count=1)
    return output

# Stage all changes in memory, ensuring no scene gets patched before validation.
patches = {}
for rel,specs in SCENES.items():
    dest = root/rel
    if not dest.is_file():
        sys.exit(f'ERROR: missing expected game scene {rel}. Nothing changed.')
    try:
        before = dest.read_text(encoding='utf8')
        after = update_scene(rel,specs,before)
        if before != after:
            patches[dest] = after.encode('utf8')
    except (ValueError, UnicodeError) as exc:
        sys.exit(f'ERROR: {exc}. Nothing changed.')

sources = {}
for source in (pack/'assets'/'hollow_art').rglob('*.png'):
    target = root/source.relative_to(pack)
    if not target.is_file() or source.read_bytes()!=target.read_bytes():
        sources[target]=source
for source in (pack/'scripts'/'visuals').glob('*.gd'):
    target = root/source.relative_to(pack)
    if not target.is_file() or source.read_bytes()!=target.read_bytes():
        sources[target]=source

if not patches and not sources:
    print('HOLLOW art is already installed. No changes needed.')
    sys.exit(0)

backup = root/('.hollow_backup_art_'+datetime.now().strftime('%Y%m%d_%H%M%S'))
i=1
while backup.exists():
    backup = root/('.hollow_backup_art_'+datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+str(i)); i+=1
for dest in list(patches)+list(sources):
    if dest.exists():
        backup_path=backup/dest.relative_to(root)
        backup_path.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(dest,backup_path)

# Replace atomically file by file after successful preflight.
def write_atomic(dest,content):
    dest.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=dest.parent,delete=False) as f:
        tmp=Path(f.name)
        f.write(content)
    os.replace(tmp,dest)

for dest,contents in patches.items():
    write_atomic(dest,contents)
for dest,source in sources.items():
    write_atomic(dest,source.read_bytes())

print('HOLLOW art installed!')
print(f'- Updated scenes: {len(patches)}')
print(f'- Installed/updated sprites + visual scripts: {len(sources)}')
print(f'- Backup of existing changed files: {backup if backup.exists() else "none (new files only)"}')
print('Open Godot and press F5. Press K for boss and V for Hollow Surge.')
