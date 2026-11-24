import importlib.util
from pathlib import Path
import unittest

SOURCE = Path(__file__).resolve().parents[1] / "tools" / "android" / "analyze_hitch_alignment.py"
SPEC = importlib.util.spec_from_file_location("alignment", SOURCE)
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)
WALL = 1_795_500_000_000_000


def fixture():
    return {"clock_sync":{"start":{"ticks_before_usec":100,"realtime_usec":WALL+110,"ticks_after_usec":120},
                          "capture":{"ticks_before_usec":100000,"realtime_usec":WALL+100010,"ticks_after_usec":100020}},
            "hitch_log":{"worst":[{"ms":98,"frame":7,"diagnostics":{
                "draw_callbacks":{"status":"ordered_synchronous_pair","probe_usec":2000,"pre_usec":2250,"post_usec":2500,"next_probe_usec":100000},
                "next_scene_dispatch":{"status":"ordered_signal","dispatch_usec":95000}}}]}}


class Alignment(unittest.TestCase):
    def test_same_clock(self):
        report = MOD.windows(fixture())
        self.assertEqual(report["clock_offset_span_usec"],20)
        frame = report["windows"][0]
        self.assertEqual(frame["realtime_range_usec"][0],[WALL+1990,WALL+2010])
        self.assertEqual(frame["observed_phases_usec"]["post_draw_to_signal"],92500)

    def test_clock_step(self):
        f = fixture()
        f["clock_sync"]["capture"]["realtime_usec"] += 100_000
        self.assertEqual(MOD.windows(f)["matching_basis"],"relative_only")
        self.assertNotIn("realtime_range_usec",MOD.windows(f)["windows"][0])

    def test_missing_clock(self):
        f = fixture()
        del f["clock_sync"]
        self.assertEqual(len(MOD.windows(f)["windows"]),1)

    def test_disordered_signals(self):
        f = fixture()
        f["hitch_log"]["worst"][0]["diagnostics"]["next_scene_dispatch"]["dispatch_usec"] = 1800
        self.assertEqual(MOD.windows(f)["windows"],[])

    def test_reject_preempted_bracket_and_outside_capture(self):
        f = fixture()
        f["clock_sync"]["start"]["ticks_after_usec"] += 3000
        self.assertEqual(MOD.windows(f)["matching_basis"],"relative_only")
        f = fixture()
        f["hitch_log"]["worst"][0]["diagnostics"]["draw_callbacks"]["next_probe_usec"] = 120_000
        self.assertNotIn("realtime_range_usec",MOD.windows(f)["windows"][0])

    def test_accept_json_integer_floats_and_respect_bounds(self):
        self.assertEqual(MOD.exact(2.0),2)
        self.assertIsNone(MOD.exact(True))
        self.assertEqual(MOD.windows(fixture(),maximum_us=98_000)["windows"],[])


if __name__ == "__main__":
    unittest.main()
