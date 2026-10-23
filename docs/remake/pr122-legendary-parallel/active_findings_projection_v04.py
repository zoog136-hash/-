"""Use authored clip phase IDs for technical source findings, preserving v03."""
from __future__ import annotations

import active_findings_projection_v03 as previous

hydrate_historical_records = previous.hydrate_historical_records
quality_lineages = previous.quality_lineages
annotate = previous.annotate


def authored_phase_mapping(clip, record, derivative_outputs):
    sequence = record.get('revision_source_pose_sequence') or record.get('source_pose_sequence') or [{} for _ in range(6)]
    original = record.get('source_pose_sequence', [])
    for i, selected in enumerate(clip['selected_poses']):
        pose = sequence[i]
        # Ownership proof original_phase is already the authored playback index.
        if (selected['source'], selected['source_sha256']) in derivative_outputs:
            continue
        selected['source_phase'] = pose.get('idle_phase', pose.get('original_phase', pose.get('phase', i)))
        source_pose = original[pose['original_phase']] if pose.get('original_phase') is not None and pose['original_phase'] < len(original) else pose
        if source_pose.get('new_sheet_cell') is not None:
            selected['source_sheet_cell_ordinal'] = source_pose['new_sheet_cell']
    return clip


def build_active_index(evidence, gate, ownership):
    clips, selection = previous.build_active_index(evidence, gate, ownership)
    outputs = {(claim['output'], claim['output_sha256']) for claim in ownership.values()}
    for clip in clips.values():
        record, _ = evidence.json(clip['record'], clip['record_sha256'])
        authored_phase_mapping(clip, record, outputs)
    selection['source_phase_unit'] = 'Author clip playback phase; sheet-cell ordinal is separate'
    return clips, selection
