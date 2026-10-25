"""Strict plaintext A3 action reader. Numeric IDs never imply game identities.

Zero-tick records are retained, including their events. They consume no time.
No encrypted metadata or executable input is accepted.
"""
import re


def parse_entry(text, sprite_id):
    match = re.search(r'^#' + re.escape(str(sprite_id)) + r'\s[^\n]*\n.*?(?=^#|\Z)', text, re.M | re.S)
    if not match:
        raise ValueError(f'No plaintext entry for {sprite_id}')
    lines = match.group().splitlines()
    entry = {'source_header': lines[0], 'attributes': {}, 'actions': {}}
    for line in lines[1:]:
        if not line.strip():
            continue
        action = re.fullmatch(r'\s*(\d+(?:-\d+)?)\.([^()]+)\((.*)\)\s*', line)
        if not action:
            raise ValueError(f'Unsupported plaintext line: {line}')
        aid, name, body = action.groups()
        if int(aid.split('-')[0]) >= 100:
            entry['attributes'][name] = body
            continue
        header = re.fullmatch(r'\s*([01])\s+(\d+)\s*,(.*)', body)
        if not header:
            raise ValueError(f'Unsupported action: {sprite_id}/{aid}')
        directional, count, tokens = header.groups()
        frames = []
        for token in tokens.split():
            frame = re.fullmatch(r'(\d+)\.(\d+):(\d+)([^\s]*)', token)
            if not frame:
                raise ValueError(f'Unsupported source token: {token}')
            seq, index, ticks, markers = frame.groups()
            frames.append({'sequence_base': int(seq), 'frame': int(index), 'ticks': int(ticks),
                           'hit_marker': '!' in markers, 'raw_markers': markers,
                           'sound_ids': re.findall(r'<(\d+)', markers)})
        if aid in entry['actions'] or len(frames) != int(count) or not sum(f['ticks'] for f in frames):
            raise ValueError(f'Duplicate/count/zero-total action: {sprite_id}/{aid}')
        entry['actions'][aid] = {'source_name': name, 'directional': directional == '1',
                                 'frames': frames, 'total_ticks': sum(f['ticks'] for f in frames)}
    return entry


def children(entry):
    value = entry['attributes'].get('clothes', '').split()
    if not value:
        return []
    if int(value[0]) != len(value) - 1 or any(not x.isdigit() for x in value):
        raise ValueError('Invalid clothes references')
    return value[1:]


def role_for(name):
    """Only explicit A3 names. In particular runL/runR are never special/kick."""
    base, *weapon = name.split(maxsplit=1)
    role = {'walk': 'walk', 'runL': 'run', 'runR': 'run_right', 'breath': 'idle',
            'damage': 'hit', 'damageshuriken': 'hit_shuriken', 'death': 'death',
            'attack': 'attack', 'spell': 'cast'}.get(base)
    if role is None:
        return None
    suffix = {'onehand sword': 'onehand', 'ondhand sword': 'onehand', 'largesword': 'largesword',
              'axe': 'axe', 'spear': 'spear', 'chainsword': 'chain', 'shuriken': 'shuriken',
              'direction': '', 'no direction': 'nondirectional'}.get(weapon[0] if weapon else '', '')
    return role + ('_' + suffix if suffix else '')
