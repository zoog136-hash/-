"""Exact primary source families for the four verified Halpas declarations."""

HALPAS_ACTORS = frozenset((28439, 28514, 28519, 28524))
# ListSprAction identifies these ordinary ranged attacks as alter 1. Special
# attacks 75/82 have the same motion/alter values, so neither is a substitute.
HALPAS_FAMILIES = {
    3: {"walk": (20, "WalkBow", 1, 0),
        "attack": (21, "AttackBow", 2, 1),
        "idle": (23, "BreathBow", 4, 0)},
    10: {"walk": (62, "WalkGauntlet", 1, 0),
         "attack": (63, "AttackGauntlet", 2, 1),
         "idle": (65, "BreathGauntlet", 4, 0)},
}


def select_family(rows, actor, weapon, default_roles):
    """Keep legacy selection elsewhere; fail closed on absent/ambiguous rows."""
    if actor not in HALPAS_ACTORS or weapon not in HALPAS_FAMILIES:
        return default_roles
    roles = {}
    for role, (action, name, motion, alter) in HALPAS_FAMILIES[weapon].items():
        matches = [row for row in rows if row.get("ID") == action]
        if len(matches) != 1:
            raise ValueError(f"source action {action}: expected one row, got {len(matches)}")
        row = matches[0]
        if (row.get("Name"), row.get("WeaponType"), row.get("MotionType"),
                row.get("WeaponAlterType")) != (name, weapon, motion, alter):
            raise ValueError(f"source action {action}: weapon/motion/alter identity mismatch")
        roles[role] = row
    return roles
