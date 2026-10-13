"""Fail-closed result parsing and bounded process execution for test_project.py.

The subprocess tests for this module use controlled programs, not the Godot engine.
"""
from __future__ import annotations

import json
import os
import re
import signal
import subprocess
from collections.abc import Mapping, Sequence

ERROR = re.compile(
    r'SCRIPT ERROR:|ERROR:|FAIL:|^\s*(?:[A-Z][A-Z0-9_]*_)?FAIL(?:ED)?(?=[:\s]|$)',
    re.MULTILINE,
)
REPORT = re.compile(r'\b[A-Z][A-Z0-9_]*_RESULT\s+(.+)$')
SUCCESS = re.compile(r'\b[A-Z][A-Z0-9_]*_OK\b')
SKIP = re.compile(r'\b[A-Z][A-Z0-9_]*_SKIP:')
OPTIONAL_RENDER_ENV = re.compile(
    r'^\s*#\s*TWILIGHT_OPTIONAL_RENDER_ENV:\s*([A-Z][A-Z0-9_]*)\s*$',
    re.MULTILINE,
)


def requires_renderer(source: str, env: Mapping[str, str]) -> bool:
    """Only explicitly annotated, environment-gated captures may use headless."""
    if 'RenderingServer.frame_post_draw' not in source:
        return False
    optional = OPTIONAL_RENDER_ENV.findall(source)
    if len(optional) == 1:
        return bool(env.get(optional[0], '').strip())
    # Missing/ambiguous annotations retain mandatory real-render validation.
    return True


def classify_result(name: str, returncode: int, output: str) -> tuple[bool, bool]:
    """Return (passed, skipped); errors always override success/skip markers."""
    if returncode != 0 or ERROR.search(output):
        return False, False
    reports = []
    for line in output.splitlines():
        match = REPORT.search(line)
        if match:
            try:
                report = json.loads(match.group(1))
            except json.JSONDecodeError:
                return False, False
            if not isinstance(report, dict) or report.get('failures') != []:
                return False, False
            reports.append(report)
    # Import/boot must actually run; a synthetic SKIP cannot authorize the suite.
    if SKIP.search(output):
        return (False, False) if name in ('import', 'boot') else (True, True)
    return name in ('import', 'boot') or bool(reports) or bool(SUCCESS.search(output)), False


def _stop_tree(process: subprocess.Popen) -> None:
    """Kill only the process tree/session created by this runner."""
    if os.name == 'posix':
        # The leader can already be dead while descendants still own its pipes.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    elif process.poll() is None:
        try:
            subprocess.run(
                ['taskkill', '/PID', str(process.pid), '/T', '/F'],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                check=False, timeout=5,
            )
        except (OSError, subprocess.TimeoutExpired):
            pass
        if process.poll() is None:
            process.kill()


def run_isolated(command: Sequence[str], *, env: Mapping[str, str], timeout: float,
                 cwd: str | None = None) -> subprocess.CompletedProcess:
    """Capture logs loss-tolerantly and clean up descendant processes on timeout."""
    kwargs = {'start_new_session': True} if os.name == 'posix' else {
        'creationflags': subprocess.CREATE_NEW_PROCESS_GROUP,
    }
    with subprocess.Popen(
        command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, encoding='utf-8', errors='replace', env=env, cwd=cwd, **kwargs,
    ) as process:
        try:
            stdout, stderr = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired as original:
            _stop_tree(process)
            try:
                stdout, stderr = process.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                # An escaped descendant may retain a pipe. Never hang on it.
                process.stdout.close()
                process.stderr.close()
                stdout, stderr = original.stdout, original.stderr
            raise subprocess.TimeoutExpired(command, timeout, output=stdout, stderr=stderr) from None
        except BaseException:
            _stop_tree(process)
            raise
    return subprocess.CompletedProcess(command, process.returncode, stdout, stderr)
