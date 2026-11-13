"""Bind an imported stage to its source checkout, without requiring stage .git."""
import hashlib, subprocess
from pathlib import Path


def provenance(project, source):
    project=Path(project).resolve(); source=Path(source).resolve()
    files={}
    for folder in ['scripts','data','tools/boot','tests/fixtures/loading']:
        for path in sorted((source/folder).rglob('*')):
            if not path.is_file() or '.godot' in path.parts or '__pycache__' in path.parts: continue
            relative=path.relative_to(source)
            # Imported UID files do not change runtime source identity.
            if path.suffix=='.uid': continue
            other=project/relative
            digest=hashlib.sha256(path.read_bytes()).hexdigest()
            if not other.is_file() or hashlib.sha256(other.read_bytes()).hexdigest()!=digest:
                raise ValueError('stage/source bytes differ: '+str(relative))
            files[str(relative)]={'bytes':path.stat().st_size,'sha256':digest}
    def git(*words): return subprocess.check_output(['git','-C',str(source),*words],text=True).strip()
    return {'source_project':str(source),'stage_project':str(project),'revision':git('rev-parse','HEAD'),'status':git('status','--short'),'runtime_files':files,'project_godot':{'source_sha256':hashlib.sha256((source/'project.godot').read_bytes()).hexdigest(),'stage_sha256':hashlib.sha256((project/'project.godot').read_bytes()).hexdigest()},'project_setting_caveat':'stage project.godot may have explicit platform/import overrides; inspect both hashes'}
