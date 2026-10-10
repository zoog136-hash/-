# External graphic ID audit — A3 SQL vs A2 artwork

A3 'src/l1j_remastered.sql' weapon insert first row: item_id=1, Korean item name 오크족 단검, iconId=34, spriteId=18111. A2 'appcenter/img/item/34.png' is a 128×128 RGBA stylized sword-like illustration. These sources are distinct snapshots/collections. Number 34 alone is NOT enough to assert this is the same named Orc Dagger graphic.

Therefore the importer MUST NOT join A3 item_id or A3 iconId to A2 graphic bytes and overwrite existing TWILIGHT catalog art automatically. Source-qualified IDs and manual visually verified crosswalks are required. Preview entries are marked semantic_verified=false and don't mutate the game catalog.
