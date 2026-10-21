"""Locate the SWF, prepare Java and JPEXS FFDec, and export vector and bitmap assets."""
from pathlib import Path
import glob
import json
import os
import shutil
import subprocess
import tarfile
import urllib.request
import zipfile

from common import (CANONICAL_SWF, EXPORT, RECORDED_SWF_SHA256, ROOT, TOOLS, log, sha256_file, write_json)

FFDEC_URL = 'https://github.com/jindrapetrik/jpexs-decompiler/releases/download/version{v}/ffdec_{v}.zip'
TEMURIN_API = 'https://api.github.com/repos/adoptium/temurin21-binaries/releases/latest'
FORMATS = 'shape:svg,sprite:svg,image:png'
ITEMS = 'shape,sprite,image,symbolClass'


class SwfMissing(Exception):
    pass


def locate_swf(argument):
    """--swf, then the canonical research path, then research/*.swf; never downloads."""
    candidates = [Path(argument).expanduser()] if argument else []
    candidates.append(CANONICAL_SWF)
    candidates += [Path(p) for p in sorted(glob.glob(str(ROOT / 'research' / '*.swf')))]
    for path in candidates:
        if path.is_file():
            source = path.resolve()
            if source != CANONICAL_SWF.resolve():
                CANONICAL_SWF.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, CANONICAL_SWF)
                log.info('Copied %s to %s', source, CANONICAL_SWF.relative_to(ROOT))
            digest = sha256_file(CANONICAL_SWF)
            if digest != RECORDED_SWF_SHA256:
                log.warning('SWF SHA-256 %s differs from the recorded publisher build %s', digest, RECORDED_SWF_SHA256)
            return CANONICAL_SWF, digest
    raise SwfMissing('No SWF found. Pass --swf, or place it at .scratch/edition-5-research/'
                     'agame-bomb-it-5-zh-fix.swf or research/*.swf. Ask the user; do not download it.')


def _download(url, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    log.info('Downloading %s', url)
    with urllib.request.urlopen(url, timeout=120) as response, open(target, 'wb') as handle:
        shutil.copyfileobj(response, handle)
    return target


def _java_works(java):
    try:
        return subprocess.run([java, '-version'], capture_output=True, timeout=60).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def ensure_java():
    """Use an existing Java, else try apt, else a Temurin JRE archive from GitHub releases."""
    local = sorted(glob.glob(str(TOOLS / 'jre' / '*' / 'bin' / 'java')))
    for java in [shutil.which('java')] + local:
        if java and _java_works(java):
            return java
    if shutil.which('apt-get'):
        log.info('Java not found; trying apt-get install openjdk-21-jre-headless')
        prefix = [] if os.geteuid() == 0 else ['sudo', '-n']
        for command in (['apt-get', 'update'], ['apt-get', 'install', '-y', 'openjdk-21-jre-headless']):
            subprocess.run(prefix + command, capture_output=True, timeout=900)
        if shutil.which('java') and _java_works(shutil.which('java')):
            return shutil.which('java')
    try:
        log.info('Trying a Temurin 21 JRE from GitHub releases')
        with urllib.request.urlopen(TEMURIN_API, timeout=60) as response:
            release = json.load(response)
        asset = next(a for a in release['assets'] if a['name'].startswith('OpenJDK21U-jre_x64_linux_hotspot')
                     and a['name'].endswith('.tar.gz'))
        archive = _download(asset['browser_download_url'], TOOLS / 'jre-download' / asset['name'])
        with tarfile.open(archive) as tar:
            tar.extractall(TOOLS / 'jre', filter='data')
        for java in sorted(glob.glob(str(TOOLS / 'jre' / '*' / 'bin' / 'java'))):
            os.chmod(java, 0o755)
            if _java_works(java):
                return java
    except Exception as error:  # Network policy or release layout; the caller falls back.
        log.warning('JRE download failed: %s', error)
    return None


def ensure_ffdec(config):
    version = config['ffdec']['version']
    folder = TOOLS / 'ffdec'
    jar = folder / 'ffdec.jar'
    stamp = folder / '.version'
    if jar.is_file() and stamp.is_file() and stamp.read_text().strip() == version:
        return jar
    archive = TOOLS / 'ffdec-dl' / f'ffdec_{version}.zip'
    if not archive.is_file():
        _download(FFDEC_URL.format(v=version), archive)
    digest = sha256_file(archive)
    if config['ffdec'].get('sha256') and digest != config['ffdec']['sha256']:
        raise RuntimeError(f'FFDec archive hash {digest} does not match config')
    shutil.rmtree(folder, ignore_errors=True)
    with zipfile.ZipFile(archive) as bundle:
        bundle.extractall(folder)
    stamp.write_text(version)
    return jar


def export(swf, digest, config):
    """Export once per SWF hash and tool version; returns the export summary."""
    stamp_path = EXPORT / '.complete.json'
    wanted = {'swf_sha256': digest, 'ffdec': config['ffdec']['version'], 'formats': FORMATS, 'items': ITEMS}
    if stamp_path.is_file():
        stamp = json.loads(stamp_path.read_text())
        if {k: stamp.get(k) for k in wanted} == wanted:
            log.info('Reusing export in %s (%s)', EXPORT.relative_to(ROOT), stamp.get('method'))
            return stamp
    java = ensure_java()
    summary = dict(wanted)
    if java:
        jar = ensure_ffdec(config)
        shutil.rmtree(EXPORT, ignore_errors=True)
        EXPORT.mkdir(parents=True)
        log.info('Exporting with FFDec %s (this takes several minutes)', config['ffdec']['version'])
        with open(EXPORT.parent / 'swf-export.log', 'w') as output:
            result = subprocess.run([java, '-Xmx6g', '-jar', str(jar), '-format', FORMATS, '-export', ITEMS,
                                     str(EXPORT), str(swf)], stdout=output, stderr=subprocess.STDOUT)
        if result.returncode == 0:
            summary.update(method='ffdec', missed=[])
        else:
            log.error('FFDec exited with %s; using the Python fallback', result.returncode)
            java = None
    if not java:
        import swf_fallback
        shutil.rmtree(EXPORT, ignore_errors=True)
        report = swf_fallback.export(swf, EXPORT)
        summary.update(method='python-fallback', missed=report['missed'], fallback=report['counts'])
        log.warning('Python fallback export: %s', report['counts'])
    write_json(stamp_path, summary)
    return summary
