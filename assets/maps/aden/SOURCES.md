# Environment art

`props.png` and `terrain.png` were generated for this project using the built-in image generation tool
on 2026-10-07. The original outputs are copied unchanged into this folder. Godot AtlasTexture regions
select the usable object bounds; no external asset server is needed at runtime.

Prop prompt:

> Use case: stylized-concept. Production asset for a playable Godot 2D medieval MMORPG, NOT a full scene or mockup. Generate one high resolution square transparent PNG sprite atlas, exactly 4 columns by 4 rows, 16 equal cells, each isolated object fully contained in its own cell with ample transparent padding, no borders, no text. Camera: consistent classic 2.5D orthographic elevated three-quarter view from south, about 55 degrees above horizon; north vertical axes stay vertical. Realistic painterly high-detail fantasy game art, subdued olive greens, weathered warm gray limestone, warm afternoon light from upper left, soft contact shadow under each object. ROW 1: large broad oak tree with visible roots and brown trunk, narrower old oak tree, tall dark spruce tree, golden-green birch tree. ROW 2: cluster of three large gray mossy boulders, single large limestone boulder, low ruin wall stretching horizontally with broken ends, broken cylindrical stone pillar. ROW 3: rustic stone house with russet tiled roof and front door, ruined watchtower with open crumbling top, medieval waystone with teal carved rune, small roofed wooden market stall. ROW 4: thick patch of grass and ferns, small flowering shrub, wooden barrel with two crates, antique statue on stone pedestal. All whole objects shown from highest point to feet, no cropping, no connections between cells, no ground tiles. Silhouettes detailed and organic, no cartoon outlines, no low-poly, no giant solid shadow panels. This image will be directly consumed as an AtlasTexture with each of the 16 cells serving as a game object.

Terrain prompt:

> Use case: stylized-concept. Production diffuse terrain texture sheet for an orthographic 2D fantasy MMORPG. One square image, precisely four equal square quadrants in a 2 by 2 layout, boundaries at exactly halfway. No borders or gaps. Top left: natural muted olive and sage short meadow grass, detailed tiny individual blades with subtle warm soil visible. Top right: warm brown sandy earth footpath, tiny pebbles and irregular compressed soil. Bottom left: weathered gray-beige limestone cobbled paving, small uneven fitted stones with moss in seams. Bottom right: dark forest floor, olive moss and dry brown leaves with small roots. Uniform scale, microtexture, overhead view straight down, diffuse warm neutral light, no directional shadows, no perspective, no objects, no text, no signage, no large identifiable landmarks or large patches, no glossy effect. Realistic handpainted high detail old fantasy MMORPG ground, subdued colors to keep characters readable. Each quadrant should be as seamless/repeatable and even as possible.

The generation did not produce perfectly equal object cells; measured atlas rectangles are explicit
in `scripts/maps/field_renderer.gd`. Ground repetitions are blended in world coordinates by the shader.

Korean font: [Google Fonts / Noto Sans KR](https://github.com/google/fonts/tree/main/ofl/notosanskr),
original variable TTF; license shipped separately as `assets/fonts/OFL.txt`. Runtime selects weight 500.
