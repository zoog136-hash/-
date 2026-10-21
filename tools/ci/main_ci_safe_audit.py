#!/usr/bin/env python3
"""Safety policy for main CI: never dispatch historical main-publishing jobs."""
from __future__ import annotations

from copy import deepcopy
from pathlib import Path

PUBLISHING_WORKFLOWS = {
    'restore-pr80-original-assets.yml': 'Historical resource installation with git push to main; not a validation-only CI',
    'restore-pr80-visual-assets.yml': 'Historical generated-resource installation with git push to main; not a validation-only CI',
}
REQUIRED_REPAIRS = {
    'equipment-collections-runtime.yml', 'ground-full-matte.yml',
    'hit-feedback-validate.yml', 'potion-feedback-validate.yml',
    'shop-consumables-validate.yml', 'termux-zip-update-check.yml',
}


def safe_inventory(result: tuple[list[dict], list[dict]]) -> tuple[list[dict], list[dict]]:
    """Retain every validation and every failure; separate publishers explicitly."""
    rows, excluded = deepcopy(result)
    selected = []
    for row in rows:
        reason = PUBLISHING_WORKFLOWS.get(row['file'])
        if reason:
            excluded.append({'file': row['file'], 'name': row.get('name', row['file']),
                             'reason': reason, 'category': 'publishing_not_ci'})
        else:
            selected.append(row)
    missing = REQUIRED_REPAIRS - {row['file'] for row in selected}
    if missing:
        raise ValueError('Required repaired CI omitted: ' + ', '.join(sorted(missing)))
    return selected, excluded


def main() -> int:
    import main_ci_audit as audit
    original = audit.inventory

    def checked(root: Path) -> tuple[list[dict], list[dict]]:
        return safe_inventory(original(root))

    audit.inventory = checked
    return audit.main()


if __name__ == '__main__':
    raise SystemExit(main())
