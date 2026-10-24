#!/usr/bin/env python3
"""Encode private actual-Main phase readbacks with original relative tick timing.

This is a silent chronological replay of atomic Main captures, not a wall-time
gameplay/FPS recording. It never interpolates or repaints source poses.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def subtitle_time(seconds):
    value = round(seconds * 1000)
    return f'{value // 3600000:02}:{value // 60000 % 60:02}:{value // 1000 % 60:02},{value % 1000:03}'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preview', type=Path, required=True)
    parser.add_argument('--actor', choices=('21624', '21653'), required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--crf', type=int, choices=range(16, 25), default=22,
                        help='Video encoding only; all source/Main PNG bytes remain unchanged')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    assert not args.preview.resolve().is_relative_to(root) and not args.output.resolve().is_relative_to(root)
    fixture = json.loads((args.preview / 'private-preview.json').read_text())
    report = json.loads((args.preview / 'report.json').read_text())
    process = json.loads((args.preview / 'process-result.json').read_text())
    assert process['returncode'] == 0 and not report['failures'] and report['checks'] > 0
    assert report['completed_added'] == 0 and not report['production_applied']
    assert not fixture['public_artifacts_allowed'] and fixture['target_identity'] == 'UNMAPPED'
    args.output.parent.mkdir(parents=True, exist_ok=True)
    assert not args.output.exists()
    build = args.output.parent / (args.output.stem + '-encode')
    build.mkdir(exist_ok=False)
    lines = ['ffconcat version 1.0']
    subtitles, clips = [], []
    seconds = 0.0
    verified = set()
    for trial in report['actors'][args.actor]['tracks']:
        key, ratio = trial['track'], trial['ratio']
        source = fixture['actors'][args.actor]['tracks'][key]
        captures = {capture['phase']: capture for capture in trial['captures']}
        assert set(captures) == set(range(len(source['frames'])))
        start = seconds
        repeats = 2 if source['role'] in ('idle', 'walk', 'run', 'run_right') else 1
        for _cycle in range(repeats):
            for phase, frame in enumerate(source['frames']):
                capture = captures[phase]
                path = Path(capture['path']).resolve()
                assert path.is_relative_to(args.preview.resolve())
                if str(path) not in verified:
                    assert sha(path) == capture['sha256'], path
                    verified.add(str(path))
                duration = frame['ticks'] / (24.0 * ratio)
                quoted = str(path).replace("'", "'\\''")
                lines.extend([f"file '{quoted}'", f'duration {duration:.9f}'])
                seconds += duration
        label = f"Native {args.actor} UNMAPPED | {key} | {ratio:.2f}x | source ticks, Main readbacks | NOT APPROVED"
        subtitles.append(f'{len(subtitles) + 1}\n{subtitle_time(start)} --> {subtitle_time(seconds)}\n{label}\n')
        clips.append({'track': key, 'ratio': ratio, 'start_seconds': start, 'end_seconds': seconds,
                      'native_frames': len(source['frames']), 'source_ticks': source['total_ticks'],
                      'complete_cycle_repeats': repeats})
    assert verified and clips
    # concat requires a final file entry to honor the preceding duration.
    lines.append(lines[-2])
    concat = build / 'main.ffconcat'
    subtitle = build / 'labels.srt'
    concat.write_text('\n'.join(lines) + '\n')
    subtitle.write_text('\n'.join(subtitles))
    assert all(char not in str(subtitle) for char in "'\\:,"), 'Use a simple private output path'
    video_filter = f"pad=iw:ih+64:0:0:black,subtitles=filename='{subtitle}':force_style='Alignment=2,FontSize=14,MarginV=12'"
    command = ['ffmpeg', '-hide_banner', '-nostdin', '-f', 'concat', '-safe', '0', '-i', str(concat),
               '-vf', video_filter, '-r', '30', '-t', f'{seconds:.6f}', '-an', '-c:v', 'libx264',
               '-threads', '2', '-preset', 'veryfast', '-crf', str(args.crf), '-pix_fmt', 'yuv420p', str(args.output)]
    with (build / 'ffmpeg.log').open('x') as log:
        subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT)
    probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-show_format',
                                              '-of', 'json', str(args.output)], text=True))
    stream = next(item for item in probe['streams'] if item['codec_type'] == 'video')
    assert stream['width'] == 1280 and stream['height'] == 784
    assert abs(float(probe['format']['duration']) - seconds) < 0.1
    receipt = {'file': args.output.name, 'bytes': args.output.stat().st_size, 'SHA256': sha(args.output),
               'actor': args.actor, 'target_identity': 'UNMAPPED', 'Main_PNGs_SHA_verified': len(verified),
               'source_kit_SHA256': fixture['source_kit_sha256'], 'clips': clips,
               'original_Main_viewport': [1280, 720], 'subtitle_band_outside_Main': [1280, 64],
               'seconds': float(probe['format']['duration']), 'silent': True,
               'video_CRF': args.crf, 'source_and_Main_PNGs_unchanged': True,
               'scope': 'Atomic actual Main phase readbacks replayed in source order and relative ticks; not wall-time performance or continuous real Input capture',
               'public_artifacts_allowed': False, 'completed_added': 0, 'Android_real_device': 'NOT_RUN'}
    args.output.with_suffix('.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({key: value for key, value in receipt.items() if key != 'clips'}))


if __name__ == '__main__':
    main()
