"""Build TWILIGHT's original enhancement cues; no third-party recordings."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 22050


def build(kind, seconds):
    rng = random.Random(10421)
    samples = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        if kind == 'charge':
            # Rising glass harmonics and soft air; resolves at the reveal cue.
            phase = 2 * math.pi * (210 * t + 110 * t * t)
            envelope = min(1, t / .15) * max(0, 1 - t / seconds) ** .25
            signal = (math.sin(phase) * .25 + math.sin(phase * 2.003) * .14
                      + math.sin(phase * 4.01) * .05 + noise * .025) * envelope
        elif kind == 'success':
            signal = sum(math.sin(2 * math.pi * freq * t) * math.exp(-t * decay) * amp
                         for freq, decay, amp in [(523.25, 3, .22), (783.99, 3.5, .19),
                                                   (1046.5, 4.5, .17), (1568, 6, .08)])
            signal += (noise * .25 + math.sin(2 * math.pi * 90 * t) * .3) * math.exp(-t * 25)
        else:
            signal = (math.sin(2 * math.pi * (150 * t - 35 * t * t)) * .32
                      + noise * .30 + math.sin(2 * math.pi * 287 * t) * .1) * math.exp(-t * 6)
        # Short endpoint ramps avoid clicks when skipping between cues.
        ramp = min(1, t / .008, (seconds - t) / .025)
        samples.append(int(max(-.85, min(.85, signal * ramp)) * 32767))
    path = ROOT / 'assets/enhancement' / (kind + '.wav')
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as wav:
        wav.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        wav.writeframes(struct.pack('<' + 'h' * len(samples), *samples))


if __name__ == '__main__':
    for cue, duration in [('charge', 1.85), ('success', 1.6), ('failure', 1.0)]:
        build(cue, duration)
    print('ENHANCEMENT_AUDIO_BUILT 3 original mono cues')
