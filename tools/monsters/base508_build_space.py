"""Cooperative, per-filesystem build reservations. POSIX flock is mandatory.

Reserve once per independent writer (not again for the same budget in its parent).
BASE508_SPACE_STATE_DIR must be shared by participating builders; the default is
one task-specific directory in the shared temporary directory. No output, source,
finished result, or uncommitted payload is ever removed by this module.
"""
from contextlib import contextmanager
from dataclasses import dataclass
import errno
import fcntl
import json
import os
from pathlib import Path
import shutil
import tempfile
import time
import uuid

DEFAULT_RESERVE_BYTES = 512 * 1024**2
DEFAULT_STATE_DIR = Path(tempfile.gettempdir()) / f"base508-build-space-{os.getuid()}"

class BuildSpaceError(RuntimeError):
    exit_code = 75
    def __init__(self, details):
        self.details = {"event":"build_space_paused", "exit_code":75,
                        "source_failure":False, **details}
        super().__init__(json.dumps(self.details, sort_keys=True))

@dataclass(frozen=True)
class Reservation:
    reservation_id: str
    pid: int
    process_start: str | None
    output_dir: str
    state_file: str
    lock_file: str
    details: dict
    def as_dict(self):
        return {"event":"build_space_reserved", "reservation_id":self.reservation_id,
                "pid":self.pid, "output_dir":self.output_dir, **self.details}

def _integer(value, name):
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise ValueError(f"{name} must be a nonnegative integer byte count")
    return value

def _existing_directory(path):
    path = Path(path).resolve()
    while not path.exists():
        if path.parent == path: raise ValueError("No existing output filesystem ancestor")
        path = path.parent
    if not path.is_dir(): raise ValueError(f"Output ancestor is not a directory: {path}")
    return path

def _process_identity(pid):
    try:
        # comm may contain spaces/parentheses; fields after the last ')' start at state (3).
        fields = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
        return fields[19], fields[0]
    except (OSError, IndexError, ValueError):
        return None, None

def _alive(entry):
    pid = entry["pid"]
    try: os.kill(pid, 0)
    except ProcessLookupError: return False
    except PermissionError: return True  # Cannot prove death: retain the reservation.
    token, state = _process_identity(pid)
    if state == "Z": return False
    # PID reuse does not revive the lease of an exited process incarnation.
    return not (entry.get("process_start") is not None and token is not None
                and entry["process_start"] != token)

def _read(state_file):
    if not state_file.exists(): return []
    data = json.loads(state_file.read_text())
    if not isinstance(data, dict) or data.get("schema") != 1 or not isinstance(data.get("reservations"), list):
        raise ValueError("Invalid reservation state; refusing to reset unknown live reservations")
    for row in data["reservations"]:
        if not isinstance(row, dict) or not isinstance(row.get("id"), str):
            raise ValueError("Malformed reservation entry")
        _integer(row.get("reserved_bytes"), "reserved_bytes")
        _integer(row.get("reserve_bytes",0), "reserve_bytes")
        if type(row.get("pid")) is not int or row["pid"] <= 0:
            raise ValueError("Malformed owner PID")
        if row.get("process_start") is not None and not isinstance(row["process_start"], str):
            raise ValueError("Malformed process identity")
    return data["reservations"]

def _publish(state_file, entries):
    # Only reservation metadata is replaced. On failure preserve its temporary
    # metadata too: no speculative payload cleanup or broad unlink is performed.
    temporary = state_file.with_name(f".{state_file.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp")
    with temporary.open("x", encoding="utf-8") as stream:
        json.dump({"schema":1, "reservations":entries}, stream, sort_keys=True)
        stream.write("\n"); stream.flush(); os.fsync(stream.fileno())
    os.replace(temporary, state_file)

@contextmanager
def _locked(lock_file):
    with lock_file.open("a+") as stream:
        fcntl.flock(stream.fileno(), fcntl.LOCK_EX)
        try: yield
        finally: fcntl.flock(stream.fileno(), fcntl.LOCK_UN)

def _release(lease):
    if os.getpid() != lease.pid: return  # A fork child must not release its live parent's lease.
    state_file, lock_file = Path(lease.state_file), Path(lease.lock_file)
    with _locked(lock_file):
        entries = _read(state_file)
        kept = [row for row in entries if not (row["id"] == lease.reservation_id and row["pid"] == lease.pid and row.get("process_start") == lease.process_start) and _alive(row)]
        _publish(state_file, kept)

@contextmanager
def reserve_budget(output_dir, expected_new_bytes, temporary_peak_bytes,
                   reserve_bytes=DEFAULT_RESERVE_BYTES, *, state_dir=None):
    """Atomically check actual free minus all live reservations, then reserve.

    expected/temporary are caller estimates, not measured/proven output sizes.
    The safety reserve is a free-space floor, not multiplied by the writer count.
    Independent nested/thread calls in one PID also count to prevent double booking.
    The output directory is not created. Normal exit and exceptions release this
    lease; terminated owners are pruned on the next successful ledger update.
    """
    expected = _integer(expected_new_bytes, "expected_new_bytes")
    temporary = _integer(temporary_peak_bytes, "temporary_peak_bytes")
    floor = _integer(reserve_bytes, "reserve_bytes")
    output = Path(output_dir).resolve(); anchor = _existing_directory(output)
    directory = Path(state_dir or os.environ.get("BASE508_SPACE_STATE_DIR") or DEFAULT_STATE_DIR).resolve()
    state_file = directory / f"reservations-{anchor.stat().st_dev}.json"
    lock_file = directory / f"reservations-{anchor.stat().st_dev}.lock"
    base = {"output_dir":str(output), "expected_new_bytes":expected,
            "temporary_peak_bytes":temporary, "reserve_bytes":floor,
            "other_reserved":None, "shortfall":None,
            "actual_free":shutil.disk_usage(anchor).free}
    try:
        directory.mkdir(parents=True, exist_ok=True)
        with _locked(lock_file):
            entries = _read(state_file)
            active = [row for row in entries if _alive(row)]
            other = sum(row["reserved_bytes"] for row in active)
            effective_floor = max([floor] + [row.get("reserve_bytes",0) for row in active])
            # Measure while holding the same lock used for check-and-register.
            actual = shutil.disk_usage(anchor).free
            details = {**base, "actual_free":actual, "other_reserved":other,
                       "shortfall":max(0, expected + temporary + effective_floor + other - actual),
                       "effective_reserve_bytes":effective_floor,
                       "estimates_are_not_measured_output":True,
                       "ignored_dead_reservations":len(entries)-len(active)}
            if details["shortfall"]:
                raise BuildSpaceError({**details, "reason":"insufficient_free_space"})
            pid = os.getpid(); token, _ = _process_identity(pid); ident = uuid.uuid4().hex
            active.append({"id":ident, "pid":pid, "process_start":token,
                           "reserved_bytes":expected+temporary,
                           "expected_new_bytes":expected, "temporary_peak_bytes":temporary, "reserve_bytes":floor,
                           "created_unix":time.time(), "output_dir":str(output)})
            _publish(state_file, active)
            lease = Reservation(ident,pid,token,str(output),str(state_file),str(lock_file),details)
    except BuildSpaceError: raise
    except (OSError, ValueError, json.JSONDecodeError) as error:
        raise BuildSpaceError({**base, "reason":"reservation_state_unavailable",
                               "state_file":str(state_file), "detail":str(error)}) from error
    try:
        yield lease
    except OSError as error:
        if error.errno in (errno.ENOSPC, errno.EDQUOT):
            actual = shutil.disk_usage(anchor).free
            raise BuildSpaceError({**lease.details, "reason":"write_capacity_error",
                 "actual_free":actual, "shortfall":max(0, expected+temporary+lease.details["effective_reserve_bytes"]+lease.details["other_reserved"]-actual),
                 "other_reserved_sample":"acquisition_snapshot", "errno":error.errno}) from error
        raise
    finally:
        try: _release(lease)
        except (OSError, ValueError, json.JSONDecodeError) as error:
            raise BuildSpaceError({**lease.details, "reason":"reservation_release_failed",
                                  "state_file":str(state_file), "detail":str(error)}) from error
