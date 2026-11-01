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


def read(paths):
    declarations = {}
    for path in sorted(map(Path, paths)):
        current = None
        fps = None
        for line_number, line in enumerate(path.read_bytes().decode('cp949').splitlines(), 1):
            scan = line
            if line.startswith('#'):
                match = HEADER.match(line)
                if not match:
                    current = None
                    continue
                current = Declaration(int(match[1]), int(match[3]) if match[3] else None, path.name, line_number)
                declarations.setdefault(current.sprite_id, []).append(current)
                fps = None  # A previous declaration's rate is not an implicit default.
                scan = line[match.end():]
            if current is None:
                continue
            for match in ACTION.finditer(scan):
                code, name, body = int(match[1]), match[2].strip(), match[3]
                if code == 110 and name.lower() == 'framerate':
                    fps = int(body)
                    if fps <= 0:
                        raise ValueError(f'{path}:{line_number}: invalid framerate')
                if (code, name.lower()) in [(101, 'shadow'), (105, 'clothes')]:
                    ids = list(map(int, re.findall(r'-?\d+', body)))
                    count_valid = code != 105 or bool(ids) and ids[0] == len(ids) - 1
                    if code == 105:
                        ids = ids[1:] if ids else []
                    current.references.append({'kind':name.lower(), 'targets':ids, 'raw':body, 'count_valid':count_valid})
                tokens = [tuple(map(int, t.groups())) for t in TOKEN.finditer(body)]
                if not tokens:
                    current.directives.append({'code': code, 'name': name, 'body': body, 'line': line_number})
                    continue
                count = re.match(r'^\s*(-?\d+)\s+(\d+)\s*,', body)
                errors = []
                if count is None or int(count[2]) != len(tokens): errors.append('frame count mismatch')
                if any(duration <= 0 for _, _, duration in tokens): errors.append('nonpositive frame duration')
                if code in current.actions: errors.append('duplicate action')
                current.actions[code] = {'code':code,'name':name,'fps':fps,'tokens':tokens,
                    'raw_body':body,'source_file':path.name,'source_line':line_number,
                    'declared_flag':int(count[1]) if count else None, 'errors':errors}
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
