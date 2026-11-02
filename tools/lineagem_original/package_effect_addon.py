"""Package only new original effects/corrected metadata; retain the installed v2 base."""
import argparse,hashlib,json,pathlib,zipfile
from package_install_zip import encoded,digest,safe

def build(stage,base,output):
    base_bytes=(base/'manifest.json').read_bytes();manifest=json.loads((stage/'manifest.json').read_text())
    selected=['manifest.json','registered_effect_layers.json','source_effect_bindings.json','overlay-status.json','attachment-status.json','source_timing_corrections.json']
    selected += [f'overlays/{sid}.json' for sid in [6082,20889,28559,28583]]
    corrections=json.loads((stage/'source_timing_corrections.json').read_text())
    # Corrected actor JSON is an optional compact overlay over the immutable base pixels.
    actor_ids={int(k.split(':')[1]) for k,v in manifest['records'].items() if k.startswith('sprite:') and any(c['source_sprite_id']==int(k.split(':')[1]) or v['manifest']==f'actors/{c["source_body_id"]}.json' for c in corrections['corrections'].values())}
    # Include only the13 actors whose timing repair is documented; run aliases are not separate card actors.
    actor_ids={sid for sid in actor_ids if (base/'actors'/f'{sid}.json').exists() and any(t.get('source_timing_provenance') for t in json.loads((base/'actors'/f'{sid}.json').read_text())['tracks'].values())}
    selected += [f'actors/{sid}.json' for sid in sorted(actor_ids)]
    selected += [str(p.relative_to(stage)) for p in sorted((stage/'pixels').glob('*.png'))]
    rows=[];payload=bytearray();chunks=[];total=0
    if output.exists():raise FileExistsError(output)
    with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=1) as z:
        def flush():
            if not rows:return
            idx=len(chunks);name=f'inventory/{idx:04d}.json';blob=f'payload/{idx:04d}.bin';data=encoded(rows)
            z.writestr(name,data);z.writestr(blob,payload)
            chunks.append({'path':name,'bytes':len(data),'sha256':digest(data),'count':len(rows),'payload':blob,'payload_bytes':len(payload),'payload_sha256':digest(payload)})
            rows.clear();payload.clear()
        for name in selected:
            assert safe(name)
            path=(base/name) if name.startswith('actors/') else (stage/name)
            data=path.read_bytes()
            if rows and (len(rows)>=1024 or len(payload)+len(data)>32*1024*1024):flush()
            rows.append({'path':name,'bytes':len(data),'offset':len(payload),'sha256':digest(data)})
            payload.extend(data);total+=len(data)
        flush()
        header={'schema':2,'kind':'twilight-lineagem-offline-runtime-addon','source_snapshot':'base508','release_id':'base508-original-effects-addon-v1','base_manifest_sha256':digest(base_bytes),'files':len(selected),'bytes':total,'sprite_records':743,'card_definitions':701,'chunks':chunks,'source_input_library_id':'libfile_619c52d24b7081918599610e3c480d1a','source_input_sha256':'a4c3e1cb611ea259c3255bc20f1a4697f1ee0bcc0fb645fb41d8decc3763679f','limits':'Original pixels and native tokens retained. Unspecified clocks and attr8/128 use explicitly unverified compatibility; no Android/visual-equivalence claim.'}
        z.writestr('pack.json',encoded(header))
    receipt={'file':str(output),'bytes':output.stat().st_size,'sha256':digest(output.read_bytes()),'files':len(selected),'installed_bytes':total,'base_manifest_sha256':digest(base_bytes),'corrected_actors':len(actor_ids),'new_original_pixel_files':len([x for x in selected if x.startswith('pixels/')])}
    output.with_suffix('.receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
if __name__=='__main__':
    p=argparse.ArgumentParser()
    for k in ['stage','base','output']:p.add_argument('--'+k,type=pathlib.Path,required=True)
    a=p.parse_args();build(a.stage,a.base,a.output)
