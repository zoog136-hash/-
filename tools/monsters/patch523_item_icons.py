"""Exact ItemClass -> Icon -> AssetView identity; no inferred images or pixels."""
from copy import deepcopy


def _index(rows, field, table):
    result = {}
    for row in rows:
        key = row[field]
        if type(key) is not int or key in result:
            raise ValueError(f'invalid/duplicate {table}.{field}: {key}')
        result[key] = row
    return result


def compile_icon_links(tables):
    items = _index(tables['ItemClass'], 'ID', 'ItemClass')
    icons = _index(tables['Icon'], 'ID', 'Icon')
    assets = _index(tables['AssetView'], 'AssetId', 'AssetView')
    links = {}
    for item_id, item in items.items():
        if item.get('TestItem') is not False:
            continue
        icon_id = item['IconID']
        if icon_id not in icons:
            raise ValueError(f'ItemClass {item_id}: missing Icon {icon_id}')
        asset_id = icons[icon_id]['AssetID']
        if asset_id not in assets:
            raise ValueError(f'Icon {icon_id}: missing AssetView {asset_id}')
        asset = assets[asset_id]
        path = asset['FilePath']
        if not isinstance(path, str) or (path and (
                path.startswith('/') or '\\' in path or ':' in path or
                any(part in ('', '.', '..') for part in path.split('/')))):
            raise ValueError(f'unsafe source path for ItemClass {item_id}')
        kind = asset['AssetTypeId']
        if not path:
            status = 'source_empty_path'
        elif kind == 101:
            status = 'source_scene_player_required'
        elif kind == 1:
            status = 'source_pixels_not_installed'
        else:
            status = 'source_asset_type_unsupported'
        links[str(item_id)] = {
            'schema': 'patch523-item-icon-identity-v1',
            'source_snapshot': 'patch523', 'item_class_id': item_id,
            'icon_id': icon_id, 'asset_id': asset_id, 'asset_type_id': kind,
            'file_path': path, 'status': status,
            'pixel_verification': 'not_performed',
        }
    return links


def attach_icon_links(definitions, links):
    for item_id, link in links.items():
        record = definitions[item_id]['native_record']
        if record['source_item_class_id'] != link['item_class_id']:
            raise ValueError(f'icon/option identity mismatch: {item_id}')
        record['source_icon_identity'] = deepcopy(link)


def compact_icon_index(links):
    return {
        'schema': 'patch523-item-icon-index-v1',
        'items': {k: v['icon_id'] for k, v in links.items()},
        'icons': {str(v['icon_id']): {k: v[k] for k in
                  ('asset_id', 'asset_type_id', 'file_path')} for v in links.values()},
    }
