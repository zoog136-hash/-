"""Read SPR action timing and resolve aliases without losing action overrides.

This is a declaration reader, not an identity registry or layer compositor.
Unknown syntax, timing, duplicate declarations and cycles fail closed.
"""
from dataclasses import dataclass, field
from pathlib import Path
import re

HEADER = re.compile(r'^#(\d+)\s+(\d+)(?:=(\d+))?')
ACTION = re.compile(r'(?<![\w.])(\d+)\.([^()\r\n]*?)\(([^()]*)\)')
TOKEN = re.compile(r'(?<![\d.])(\d+)\.(\d+):(-?\d+)')

@dataclass
class Declaration:
    sprite_id: int
    alias_target: int | None
    source_file: str
    source_line: int
    actions: dict = field(default_factory=dict)
    directives: list = field(default_factory=list)
    references: list = field(default_factory=list)


# The client's list parser resets the rate to 24 at every '#' sprite section;
# code 110 changes it for frames parsed after it (static analysis of LineageM
# 1.10.22.0 ListSprLoader, RVA 0x035FAF49 and 0x035FBC38). Opt-in only: the
# default reader keeps an absent rate as None and invents nothing.
CLIENT_SECTION_DEFAULT_FPS = 24
CLIENT_DEFAULT_EVIDENCE = 'LineageM_1.10.22.0 ListSprLoader: fps=24 per sprite section (RVA 0x035FAF49); code110 overrides later frames (0x035FBC38)'


def read(paths, section_default_fps=None):
    if section_default_fps not in (None, CLIENT_SECTION_DEFAULT_FPS):
        raise ValueError('only the evidenced client section default (24) is supported')
    default_source = None if section_default_fps is None else {
        'kind': 'client_section_default', 'fps': section_default_fps, 'evidence': CLIENT_DEFAULT_EVIDENCE}
    declarations = {}
    for path in sorted(map(Path, paths)):
        current = None
        fps = None
        rate_source = None
        for line_number, line in enumerate(path.read_bytes().decode('cp949').splitlines(), 1):
            scan = line.lstrip()
            if scan.startswith('#'):
                match = HEADER.match(scan)
                if not match:
                    current = None
                    continue
                current = Declaration(int(match[1]), int(match[3]) if match[3] else None, path.name, line_number)
                declarations.setdefault(current.sprite_id, []).append(current)
                fps = section_default_fps  # A previous declaration's rate is not an implicit default.
                rate_source = dict(default_source) if default_source else None
                scan = scan[match.end():]
            if current is None:
                continue
            for match in ACTION.finditer(scan):
                code, name, body = int(match[1]), match[2].strip(), match[3]
                # Source uses both 'framerate' and 'frame rate' (same code110).
                # Preserve raw names/bodies; normalize whitespace only for dispatch.
                if code == 110 and ''.join(name.lower().split()) == 'framerate':
                    fps = int(body)
                    rate_source = {'source_file':path.name,'source_line':line_number,'raw_name':name,'raw_body':body}
                    if fps <= 0:
                        raise ValueError(f'{path}:{line_number}: invalid framerate')
                if (code, name.lower()) in [(101, 'shadow'), (105, 'clothes'), (105, 'clothe')]:
                    ids = list(map(int, re.findall(r'-?\d+', body)))
                    count_valid = code != 105 or bool(ids) and ids[0] == len(ids) - 1
                    if code == 105:
                        ids = ids[1:] if ids else []
                    # list_24.spr uses both spellings for code105. Consumers
                    # share one reference kind; retain the original spelling.
                    reference = {'kind':'clothes' if code == 105 else 'shadow',
                        'targets':ids, 'raw':body, 'count_valid':count_valid}
                    if code == 105 and name.lower() == 'clothe':
                        reference['source_name'] = name
                    current.references.append(reference)
                tokens = [tuple(map(int, t.groups())) for t in TOKEN.finditer(body)]
                if not tokens:
                    current.directives.append({'code': code, 'name': name, 'body': body, 'line': line_number})
                    continue
                count = re.match(r'^\s*(-?\d+)\s+(\d+)\s*,', body)
                errors = []
                if count is None or int(count[2]) != len(tokens): errors.append('frame count mismatch')
                if any(duration < 0 for _, _, duration in tokens): errors.append('negative frame duration')
                if sum(t[2] for t in tokens) <= 0: errors.append('no positive playback duration')
                if code in current.actions: errors.append('duplicate action')
                current.actions[code] = {'code':code,'name':name,'fps':fps,'tokens':tokens,
                    'raw_body':body,'source_file':path.name,'source_line':line_number,
                    'fps_provenance':dict(rate_source) if rate_source else None,
                    'declared_flag':int(count[1]) if count else None, 'errors':errors,
                    'source_annotations':source_annotations(body)}
    return declarations


def resolve(declarations, sprite_id, seen=()):
    if sprite_id in seen:
        raise ValueError(f'alias cycle: {seen + (sprite_id,)}')
    matches = declarations.get(sprite_id, [])
    if len(matches) != 1:
        raise ValueError(f'{sprite_id}: expected one declaration, found {len(matches)}')
    declaration = matches[0]
    if declaration.alias_target is None:
        return sprite_id, dict(declaration.actions)
    body, actions = resolve(declarations, declaration.alias_target, seen + (sprite_id,))
    actions.update(declaration.actions)
    return body, actions


def frame_at(action, elapsed, loop):
    if action.get('errors'): raise ValueError(action['errors'])
    fps = action['fps']
    if fps is None:
        raise ValueError('No explicit timing: refusing to invent an FPS')
    tokens = action['tokens']
    total = sum(t[2] for t in tokens)
    ticks = max(0.0, elapsed) * fps
    ticks = ticks % total if loop else min(ticks, total)
    for group, frame, duration in tokens:
        if ticks < duration:
            return group, frame
        ticks -= duration
    return tokens[-1][:2]


def resolve_references(declarations, sprite_id, seen=()):
    """Alias 101/105 declarations replace inherited layers by reference kind."""
    if sprite_id in seen:
        raise ValueError(f'alias cycle: {seen + (sprite_id,)}')
    matches = declarations.get(sprite_id, [])
    if len(matches) != 1:
        raise ValueError(f'{sprite_id}: expected one declaration, found {len(matches)}')
    d = matches[0]
    result = resolve_references(declarations, d.alias_target, seen + (sprite_id,)) if d.alias_target is not None else {}
    own = {}
    for ref in d.references:
        own.setdefault(ref['kind'], []).append(ref)
    result.update(own)
    return result


def frame_address(group, direction, directional_flag):
    """SPR frame address selects one direction slot in an eight-slot SP2 chunk.

    Flag0 is a fixed source address; flag1 adds the requested direction.
    The physical chunk number and stored mask bit must both be retained.
    """
    if directional_flag not in (0, 1):
        raise ValueError(f'unknown SPR directional flag {directional_flag}')
    address = group + (direction if directional_flag else 0)
    return address & ~7, address & 7


def source_annotations(body):
    """Retain annotations at their native token; symbols are not guessed as hit/effect/sound."""
    matches=list(TOKEN.finditer(body));result=[]
    for index,match in enumerate(matches):
        text=body[match.end():matches[index+1].start() if index+1<len(matches) else len(body)].strip()
        if text:
            result.append({'token_index':index,'raw':text,'semantics':'unverified_native_annotation'})
    return result
