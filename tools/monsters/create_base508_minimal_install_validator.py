"""Create a small isolated Godot project for the existing offline monster installer.
Copies project code and identity tables only. No pixels, game saves or network.
"""
import argparse,hashlib,json,shutil
from pathlib import Path
FILES=[
 'scripts/lineagem_pack_install.gd','scripts/lineagem_base508.gd',
 'scripts/cards/patch523_slot_data.gd',
 'scripts/monsters/base508_authoritative_catalog.gd',
 'scripts/monsters/base508_monster_context.gd',
 'data/lineagem_base508/monster_bindings.json',
 'data/lineagem_base508/monster_batch02/runtime_registry.json',
 'data/lineagem_base508/npc_classes.json',
 'data/lineagem_base508/monster_contexts.bin',
 'data/lineagem_base508/monster_full/authoritative_catalog.bin',
 'tests/base508_minimal_installer_test.gd']
def build(project,output):
 if output.exists():raise ValueError('Choose a new output directory; existing files are preserved')
 for name in FILES:
  if not(project/name).is_file():raise ValueError(('Required identity/code input missing',name))
 output.mkdir(parents=True);entries=[]
 for name in FILES:
  target=output/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(project/name,target)
  entries.append({'path':name,'bytes':target.stat().st_size,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
 (output/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Base508 Installer Isolated Validation"\nconfig/features=PackedStringArray("4.7")\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
 (output/'INPUT_FILES.json').write_text(json.dumps({'schema':1,'files':entries,'source_pixels_included':False,'separate_user_data_identity':True},indent=2)+'\n')
 print(json.dumps({'output':str(output),'files':len(entries)+2,'bytes':sum(x['bytes']for x in entries),'full_game_boot':False}))
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--project-root',type=Path,default=Path(__file__).resolve().parents[2]);p.add_argument('--output',type=Path,required=True);a=p.parse_args();build(a.project_root.resolve(),a.output.resolve())
