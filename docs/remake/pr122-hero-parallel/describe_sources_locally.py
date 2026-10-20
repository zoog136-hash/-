#!/usr/bin/env python3
"""Optional local, text-only visual triage. Never emits or approves an image.

Install dependencies outside the repository. Model descriptions are fallible
triage, not identity/contact approvals or a substitute for real Main tests.
Only standard Transformers + safetensors weights are loaded; no remote code.
"""
import argparse
import hashlib
import json
from pathlib import Path

import torch
from PIL import Image
from transformers import AutoModelForVision2Seq, AutoProcessor
from huggingface_hub import model_info

ROOT = Path(__file__).resolve().parents[3]
MODEL = 'HuggingFaceTB/SmolVLM-500M-Instruct'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    revision = model_info(MODEL).sha
    processor = AutoProcessor.from_pretrained(MODEL, revision=revision, trust_remote_code=False)
    model = AutoModelForVision2Seq.from_pretrained(
        MODEL, revision=revision, torch_dtype=torch.float32,
        _attn_implementation='eager', trust_remote_code=False, use_safetensors=True)
    model.eval()
    staging = json.loads((ROOT / 'data/pr122_hero_parallel_staging.json').read_text())
    cases = []
    for sid in ['7', '11', '179', '182', '231', '260']:
        path = staging['actors']['transform:' + sid]['reference'].removeprefix('res://')
        cases.append((sid + '-catalog-reference', path, None))
    path = 'assets/actors/eight_direction/hero_parallel/baphomet_unique/r001/source-run.png'
    cases.append(('baphomet-new-run-E-frame0', path, (0, 0, 181, 181)))
    results = []
    prompt = ('Describe the visible character only. State head or horns, clothing or armor, '
              'weapon, body type, dominant colors. If something is unclear say unknown. '
              'Do not invent a name or assume identity. This is character design triage, '
              'not an approval decision.')
    output = ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    for label, relative, crop in cases:
        source = ROOT / relative
        image = Image.open(source).convert('RGBA')
        if crop:
            image = image.crop(crop)
        # In-memory preprocessing for model input only. Original file immutable.
        matte = Image.new('RGBA', image.size, (224, 224, 224, 255))
        matte.alpha_composite(image)
        image = matte.convert('RGB')
        content = [{'type': 'image'}, {'type': 'text', 'text': prompt}]
        messages = [{'role': 'user', 'content': content}]
        text = processor.apply_chat_template(messages, add_generation_prompt=True)
        inputs = processor(text=text, images=[image], return_tensors='pt')
        with torch.inference_mode():
            generated = model.generate(**inputs, max_new_tokens=128, do_sample=False)
        description = processor.batch_decode(
            generated[:, inputs['input_ids'].shape[-1]:], skip_special_tokens=True)[0]
        results.append(dict(label=label, source=relative, crop=crop,
                            source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                            description=description))
        output.write_text(json.dumps(dict(schema='hero-local-text-only-design-triage-v1',
            model=MODEL, revision=revision, prompt=prompt, trust_remote_code=False,
            final_approval=False, results=results), ensure_ascii=False, indent=2) + '\n')
        print('HERO_LOCAL_DESCRIPTION_SAVED ' + label, flush=True)


if __name__ == '__main__':
    main()
