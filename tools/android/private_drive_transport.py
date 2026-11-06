#!/usr/bin/env python3
"""Authenticated, hash-pinned Drive bundle downloads for the private installer.

No credentials are discovered or copied out of rclone configuration. Supply an
explicit OAuth access-token JSON file, or an already authorized rclone remote.
The API transport resumes only validated HTTP byte ranges. The rclone transport
reuses completed verified bundles but restarts its interrupted bundle, because
`backend copyid` does not promise byte-level download resume.

References: https://developers.google.com/workspace/drive/api/guides/manage-downloads
            https://rclone.org/drive/#copyid
"""
from concurrent.futures import ThreadPoolExecutor, wait, FIRST_COMPLETED
from pathlib import Path
import hashlib
import http.client
import json
import os
import re
import shutil
import stat
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request


class _DriveRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, newurl):
        target = urllib.parse.urlsplit(newurl)
        host = target.hostname or ''
        if (target.scheme != 'https' or target.username or target.password
                or not (host == 'www.googleapis.com' or host.endswith('.googleapis.com')
                        or host.endswith('.googleusercontent.com'))):
            raise DownloadError('Unexpected Drive redirect; credentials were not forwarded.')
        return super().redirect_request(request, response, code, message, headers, newurl)


class DownloadError(RuntimeError):
    """The download is unavailable; staged/previous installations are intact."""


def rclone_failure(returncode, stderr):
    """Classify locally without echoing account details, tokens or auth URLs.

    A category is evidence from an error string, not a credential diagnosis.
    Unknown provider errors deliberately remain unknown.
    """
    message = stderr.decode('utf-8', errors='replace').lower() if isinstance(stderr, bytes) else str(stderr).lower()
    if any(value in message for value in ('unknown command', 'command not found', 'command "copyid" not found', 'doesn\'t support backend commands', 'does not support backend commands')):
        reason = 'backend/command support: confirm the selected remote is Google Drive and check the installed rclone version'
    elif any(value in message for value in ('didn\'t find section in config file', 'not found in config', 'failed to find config')):
        reason = 'remote configuration: the selected remote is missing or unavailable'
    elif any(value in message for value in ('invalid_client', 'unauthorized_client', 'deleted_client')):
        reason = 'OAuth client configuration rejected: inspect the local rclone setup; reconnect alone may not resolve this'
    elif any(value in message for value in ('empty token', 'couldn\'t find token', 'invalid_grant', 'invalid token', 'token expired', 'oauth2:', 'unauthenticated', '401 unauthorized')):
        reason = 'authentication: complete or reconnect the existing remote using your own browser, then retry the same read'
    elif any(value in message for value in ('ratelimit', 'rate limit', 'quota', '429', 'downloadquotaexceeded')):
        reason = 'provider quota/rate limit: wait before retrying; no alternate account or limit bypass is attempted'
    elif any(value in message for value in ('403', '404', 'permission', 'insufficient', 'file not found', 'notfound', 'access denied')):
        reason = 'file access: check the selected account, existing read scope and access to the exact file; this does not prove authentication failed'
    elif any(value in message for value in ('timeout', 'timed out', 'no such host', 'network', 'connection', 'tls handshake', 'certificate')):
        reason = 'network/TLS: check the connection and device clock before retrying'
    else:
        reason = 'unclassified failure: run the same read-only command locally to inspect its error; do not share tokens, auth URLs or config dumps'
    return 'rclone stopped (exit %d); %s. Existing installation and completed cache are preserved.' % (returncode, reason)


def sha256_file(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def _validate_row(row):
    file_id = row.get('file_id')
    size = row.get('bytes')
    pin = row.get('sha256')
    if (not isinstance(file_id, str) or not re.fullmatch(r'[A-Za-z0-9_-]+', file_id)
            or isinstance(size, bool) or not isinstance(size, int) or size < 0
            or not isinstance(pin, str) or not re.fullmatch(r'[0-9a-f]{64}', pin)):
        raise DownloadError('Drive bundle requires an exact file ID, byte length and SHA256.')
    return {'file_id': file_id, 'bytes': size, 'sha256': pin}


def _regular(path):
    if path.is_symlink():
        raise DownloadError('A symlink occupies an installer cache path.')
    if path.exists() and not stat.S_ISREG(path.lstat().st_mode):
        raise DownloadError('A non-file occupies an installer cache path.')


def _atomic_json(path, document):
    # A fresh file avoids overwriting an unrelated manually placed *.tmp file.
    descriptor, name = tempfile.mkstemp(prefix='.marker-', dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, 'w', encoding='utf-8') as destination:
            json.dump(document, destination, separators=(',', ':'))
            destination.write('\n')
            destination.flush()
            os.fsync(destination.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


class DriveTransport:
    """Download ZIPs/parts by exact ID, with at most three active bundles.

    ``token_file`` explicitly names an access-token JSON file with an
    ``access_token`` property (or a raw bearer token text file). Store it in the
    Termux private HOME, not shared Download storage. Tokens are never printed,
    persisted to the cache, or placed in a subprocess argument.

    ``remote`` is a configured rclone remote name, e.g. ``twilight-drive``.
    Authentication/refresh remains entirely inside rclone. Neither configuration
    dumps nor credential files are inspected.
    """
    def __init__(self, cache, *, token_file=None, remote=None, workers=2,
                 progress=None):
        if not 1 <= workers <= 3:
            raise DownloadError('Drive bundle concurrency must be between one and three.')
        if bool(token_file) == bool(remote):
            raise DownloadError('Choose one explicit OAuth token file or one rclone remote.')
        self.cache = Path(cache).expanduser()
        if self.cache.is_symlink():
            raise DownloadError('Installer cache cannot itself be a symlink.')
        self.cache.mkdir(parents=True, exist_ok=True)
        self.cache = self.cache.resolve()
        self.token_file = Path(token_file).expanduser() if token_file else None
        self.remote = remote.rstrip(':') if remote else None
        if self.remote and not re.fullmatch(r'[A-Za-z0-9_. -]+', self.remote):
            raise DownloadError('Supply a configured rclone remote NAME, without a path.')
        if self.remote and shutil.which('rclone') is None:
            raise DownloadError('rclone is not installed; install it with pkg install rclone.')
        self._opener = urllib.request.build_opener(_DriveRedirects())
        self.workers = workers
        self.progress = progress or (lambda message: print(message, flush=True))

    def _bearer(self):
        # Only the explicit caller-supplied token file is read. There is no token
        # discovery, refresh-token extraction, or rclone configuration dump.
        if not self.token_file or self.token_file.is_symlink():
            raise DownloadError('An explicit, regular OAuth token file is required.')
        try:
            details = self.token_file.stat()
            if not stat.S_ISREG(details.st_mode) or details.st_size > 65536:
                raise ValueError()
            if details.st_mode & 0o077:
                raise DownloadError('OAuth token file must be private; use chmod 600 in Termux HOME.')
            value = self.token_file.read_text(encoding='utf-8').strip()
            token = json.loads(value).get('access_token') if value.startswith('{') else value
            if not isinstance(token, str) or not token or any(c.isspace() for c in token):
                raise ValueError()
            return token
        except DownloadError:
            raise
        except (OSError, ValueError, AttributeError):
            raise DownloadError('OAuth token file is unreadable or invalid.') from None

    def _request(self, file_id, *, offset=0, etag=None):
        headers = {'Authorization': 'Bearer ' + self._bearer(),
                   'Accept-Encoding': 'identity',
                   'User-Agent': 'TWILIGHT-Private-Bundle-Installer/1'}
        if offset:
            headers['Range'] = 'bytes=%d-' % offset
            if etag and not etag.startswith('W/'):
                headers['If-Range'] = etag
        url = ('https://www.googleapis.com/drive/v3/files/' +
               urllib.parse.quote(file_id, safe='') + '?alt=media&supportsAllDrives=true')
        return urllib.request.Request(url, headers=headers)

    def _api_download(self, row, partial, marker):
        identity = _validate_row(row)
        offset = partial.stat().st_size if partial.exists() else 0
        if offset > identity['bytes']:
            raise DownloadError('Owned partial bundle exceeds the pinned length; retained for inspection.')
        for attempt in range(3):
            offset = partial.stat().st_size if partial.exists() else 0
            if offset == identity['bytes']:
                return
            metadata = json.loads(marker.read_text(encoding='utf-8'))
            try:
                request = self._request(identity['file_id'], offset=offset, etag=metadata.get('etag'))
                with self._opener.open(request, timeout=60) as response:
                    status = response.getcode()
                    content_range = response.headers.get('Content-Range', '')
                    if status == 206:
                        expected = 'bytes %d-%d/%d' % (offset, identity['bytes'] - 1, identity['bytes'])
                        if content_range != expected:
                            raise DownloadError('Server returned an unexpected byte range; nothing appended.')
                    elif status == 200:
                        # The server may ignore Range or reject If-Range. A full
                        # response replaces only our marked, incomplete copy.
                        if content_range:
                            raise DownloadError('Unexpected range on a full response.')
                        if offset:
                            self.progress('Drive server did not resume; restarting this bundle only.')
                        offset = 0
                    else:
                        raise DownloadError('Unexpected Drive download status %d.' % status)
                    remaining = identity['bytes'] - offset
                    declared = response.headers.get('Content-Length')
                    if declared is not None and (not declared.isdecimal() or int(declared) != remaining):
                        raise DownloadError('Drive response length differs from the pinned bundle.')
                    etag = response.headers.get('ETag')
                    _atomic_json(marker, dict(identity, etag=etag))
                    with partial.open('ab' if offset else 'wb') as destination:
                        count = offset
                        while True:
                            block = response.read(1024 * 1024)
                            if not block:
                                break
                            if count + len(block) > identity['bytes']:
                                raise DownloadError('Drive stream exceeded the pinned length.')
                            destination.write(block)
                            count += len(block)
                        destination.flush()
                        os.fsync(destination.fileno())
                    if count == identity['bytes']:
                        return
                    # A short response retains only received bytes and tries a
                    # bounded authenticated Range request on the next attempt.
            except urllib.error.HTTPError as error:
                code = error.code
                error.close()
                if code in (401, 403, 429):
                    raise DownloadError('Drive HTTP %d: authentication, permission or quota requires attention; no bypass attempted.' % code) from None
                if code < 500 or attempt == 2:
                    raise DownloadError('Drive HTTP %d; download remains resumable.' % code) from None
            except DownloadError:
                raise
            except (OSError, urllib.error.URLError, TimeoutError, http.client.HTTPException):
                if attempt == 2:
                    raise DownloadError('Drive connection interrupted; marked partial bundle was retained.') from None
            if attempt < 2:
                time.sleep(2 ** attempt)
        raise DownloadError('Drive bundle is incomplete; partial bytes were retained.')

    def _rclone_download(self, row, partial):
        # backend copyid delegates normal Google authorization and refresh to
        # rclone. This command reads Drive and writes a LOCAL owned cache file.
        # Do not add copy-to-Drive, server-side copies, alt account rotation,
        # acknowledge-abuse or download-limit workarounds here.
        command = ['rclone', 'backend', 'copyid', self.remote + ':',
                   row['file_id'], str(partial), '--transfers', '1', '--checkers', '1',
                   '--multi-thread-streams', '0', '--retries', '1',
                   '--low-level-retries', '1', '--stats', '0', '--log-level', 'ERROR']
        result = subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        if result.returncode:
            # Avoid echoing raw process stderr: authorization URLs and account
            # details belong to rclone's explicit configuration flow.
            raise DownloadError(rclone_failure(result.returncode, result.stderr))

    def download(self, row):
        """Return a SHA256-named cached file only after full length/hash match."""
        identity = _validate_row(row)
        complete = self.cache / (identity['sha256'] + '.bundle')
        partial = self.cache / (identity['sha256'] + '.partial')
        marker = self.cache / (identity['sha256'] + '.partial.json')
        for path in (complete, partial, marker):
            _regular(path)
        if complete.exists():
            if complete.stat().st_size != identity['bytes'] or sha256_file(complete) != identity['sha256']:
                raise DownloadError('A completed cache file changed; it was preserved and not reused.')
            self.progress('Reusing verified bundle: ' + identity['sha256'][:12])
            return complete
        if marker.exists():
            try:
                saved = json.loads(marker.read_text(encoding='utf-8'))
                if {key: saved.get(key) for key in identity} != identity:
                    raise ValueError()
            except (OSError, ValueError, AttributeError):
                raise DownloadError('Partial cache ownership does not match this bundle; retained without modification.') from None
        elif partial.exists():
            raise DownloadError('Unmarked file occupies a partial cache path; retained without modification.')
        else:
            _atomic_json(marker, identity)
        if partial.exists() and partial.stat().st_size == identity['bytes']:
            if sha256_file(partial) == identity['sha256']:
                os.replace(partial, complete)
                marker.unlink()
                self.progress('Reusing completed partial bundle: ' + identity['sha256'][:12])
                return complete
            raise DownloadError('Completed partial bundle failed SHA256; retained without activation.')
        self.progress(('Downloading Drive bundle: ' if self.token_file else
                       'Downloading Drive bundle with rclone (in-flight bundle restarts on retry): ') +
                      identity['sha256'][:12])
        if self.token_file:
            self._api_download(identity, partial, marker)
        else:
            self._rclone_download(identity, partial)
        if partial.stat().st_size != identity['bytes'] or sha256_file(partial) != identity['sha256']:
            raise DownloadError('Drive bundle failed its pinned length/SHA256; retained without activation.')
        os.replace(partial, complete)
        marker.unlink()
        self.progress('Verified bundle: ' + identity['sha256'][:12])
        return complete

    def download_many(self, rows):
        """Bound active bundles and stop scheduling after the first error."""
        unique = {}
        for row in rows:
            identity = _validate_row(row)
            key = identity['sha256']
            if key in unique and unique[key] != identity:
                raise DownloadError('Conflicting metadata for one pinned bundle.')
            unique[key] = identity
        results = {}
        iterator = iter(unique.values())
        with ThreadPoolExecutor(max_workers=self.workers) as executor:
            futures = {}
            for _ in range(min(len(unique), self.workers)):
                row = next(iterator)
                futures[executor.submit(self.download, row)] = row
            try:
                while futures:
                    done, _ = wait(tuple(futures), return_when=FIRST_COMPLETED)
                    for future in done:
                        row = futures.pop(future)
                        results[row['sha256']] = future.result()
                    for _ in done:
                        row = next(iterator, None)
                        if row is not None:
                            futures[executor.submit(self.download, row)] = row
            except BaseException:
                for future in futures:
                    future.cancel()
                raise
        return results
