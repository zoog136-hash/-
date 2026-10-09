# Original monster plates

Six transparent 4×4 plates contain 96 independently drawn family silhouettes.
Created with the built-in ImageGen on 2026-10-09 for this TWILIGHT branch.
No downloaded Lineage/LineageM sprites, textures, paid assets or extracted game
resources were used as inputs. Reference facts informed species descriptions.

Prompts requested original hand-painted isometric full-body fantasy creatures,
consistent light, clear anatomical/weapon differences, transparent cell gutters,
and no labels, game marks, existing sprites or logos. The atlas cell identities
are listed in `data/monsters/monster_world_catalog.json:bodies`; their original
pixel rectangles are in `data/monsters/art_atlases.json`. PNG pixels are retained
unchanged. Runtime AtlasTexture views crop the alpha bounds and cache textures.

Species may share a family plate body. Proportions, heraldry, weapon motion,
element effects, movement, attack timing and behaviour are separate profiles.
The shader's limb/stance offsets and actor rig implement procedural eight-facing
poses; they are not independently authored eight-view sprite animations. This
remaining art limitation is explicitly included in the implementation report.
