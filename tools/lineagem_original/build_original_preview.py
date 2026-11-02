"""Build a private literal body/shadow preview; do not infer sc/mu blending."""
import argparse, hashlib, importlib.util, json, pathlib
import original_spr

def run(inputs, output):
    output.mkdir(parents=True,exist_ok=True)
    import original_sp2 as decode
    spr_root=inputs/'lineagem-category-source-metadata/original-spr'
    if not spr_root.is_dir(): spr_root=inputs/'full_resource_inventory/motion_text'
    ds=original_spr.read(spr_root.glob('*.spr'))
    source_paths={}
    for path in inputs.glob('transformation-*/Sprite/*.sp2'):
        source_paths.setdefault(path.name,[]).append(path)
    records={};decoded={};images={};sources={}
    for key,sid,folder,shadow,unresolved in [('transform:267',22262,'girtas_renewal_analysis',22259,[22260,22261]),('transform:393',28443,'halphas_analysis',28440,[28441,28442])]:
        body,actions=original_spr.resolve(ds,sid);_,base=original_spr.resolve(ds,body)
        selected={'walk':base[0],'run':actions[0],'idle':actions[3],'attack':actions[1]}
        tracks={}
        for role,a in selected.items():
            if a['errors'] or a['fps'] is None:raise ValueError(a)
            directions=[]
            for bit in range(8):
                frames=[]
                for group,index,ticks in a['tokens']:
                    layers=[]
                    for layer in [shadow,body]:
                        file=f'{layer}-{group}.sp2'
                        if file not in decoded:
                            paths=[p for p in [inputs/folder/'sp2'/file,*source_paths.get(file,[])] if p.is_file()]
                            if not paths: raise FileNotFoundError(file)
                            raw=paths[0].read_bytes()
                            if any(hashlib.sha256(p.read_bytes()).digest()!=hashlib.sha256(raw).digest() for p in paths[1:]):
                                raise ValueError(f'Conflicting original bytes: {file}')
                            decoded[file]=decode.parse(raw)
                            sources[file]=hashlib.sha256(raw).hexdigest()
                        pal,mask,dirs,_=decoded[file]
                        if mask!=255:raise ValueError(f'{file}: expected 8 stored directions')
                        image_key=(layer,group,bit,index)
                        if image_key not in images:
                            im,offset=decode.render(pal,*dirs[bit],index)
                            name=f'pixels/{layer}-{group}-{bit}-{index}.png';dest=output/name;dest.parent.mkdir(exist_ok=True)
                            im.save(dest);images[image_key]={'path':name,'offset':list(offset),'layer_id':layer,'source_bounds':list(dirs[bit][0][index][0]),'pixel_size':list(im.size)}
                        layers.append(images[image_key])
                    frames.append({'duration':ticks/a['fps'],'source_group':group,'source_frame':index,'source_ticks':ticks,'layers':layers})
                directions.append(frames)
            tracks[role]={'fps':a['fps'],'source_action':a['name'],'directions':directions,'loop':role!='attack'}
        records[key]={'alias_id':sid,'body_id':body,'shadow_id':shadow,'unresolved_layers':unresolved,'tracks':tracks}
    manifest={'schema':1,'mode':'literal_body_shadow_inspection_only','production_ready':False,'limits':['sc/mu attr8/128 NOT interpreted or rendered','Original coordinate offsets used directly; no foot-anchor correction','8 direction bit order mapped by visual inspection; native-world cardinal semantics unverified','Independent source time; combat damage clocks unchanged'],'source_sha256':sources,'records':records}
    (output/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,separators=(',',':'))+'\n')
    print(json.dumps({'path':str(output/'manifest.json'),'png_files':len(images),'source_files':len(sources),'production_ready':False}))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--inputs',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args();run(a.inputs,a.output)
