#!/usr/bin/env python3
"""Morning check for published security advisories that affect a client site.

Reads every client clone's committed composer.lock (the remote's default branch, after a
fetch, so it reflects what is deployed rather than a working copy), runs `composer audit`
on it, and ranks the clients each advisory reaches. A critical one turns the Claude Code
status line red and raises a macOS notification; everything else goes in the digest.

    release-watch.py            run the check (launchd runs this each weekday morning)
    release-watch.py show       print the last digest
    release-watch.py ack ID     silence one advisory in the status line (ID or "all")

Output lives in ~/.cache/release-watch/: status (one line, read by the status line),
digest.md, state.json. Settings: ~/.config/release-watch/config.json (all optional):
    {"projects_dir": "~/Projects", "ignore": ["oldsite"], "max_idle_days": 365, "workers": 8}
Install: templates/release-watch/install.sh.
"""

import concurrent.futures
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
CACHE = Path(os.environ.get('XDG_CACHE_HOME', Path.home() / '.cache')) / 'release-watch'
CONFIG = Path(os.environ.get('RELEASE_WATCH_CONFIG', Path.home() / '.config' / 'release-watch' / 'config.json'))
LEVELS = HERE.parent.parent / 'memory' / 'pom' / 'levels.md'

# Drupal states its rating in the advisory title; other sources may carry a severity field.
# "Moderately critical" and "Less critical" stay out of the red on purpose.
DRUPAL_RED = re.compile(r' - (Highly critical|Critical) - ')
# An exact RGB red: the terminal's basic red is the theme's, and themes draw it pink.
RED, BOLD, RESET = '\033[38;2;230;25;25m', '\033[1m', '\033[0m'


def settings():
    conf = {'projects_dir': '~/Projects', 'ignore': [], 'max_idle_days': 365, 'workers': 8}
    if CONFIG.exists():
        conf.update(json.loads(CONFIG.read_text()))
    conf['projects_dir'] = Path(conf['projects_dir']).expanduser()
    return conf


def run(cmd, cwd=None, timeout=120):
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout
    except (subprocess.TimeoutExpired, OSError):
        return None, ''


def pom_plus():
    """Client codes on POM+ (the plan memory's roster), lower-cased like project folders."""
    if not LEVELS.exists():
        return set()
    m = re.search(r'## Clients on POM\+\s+(.+?)\n', LEVELS.read_text())
    return {c.strip().lower() for c in m.group(1).split(',')} if m else set()


def remote_ref(repo):
    """The deployed branch. Pantheon deploys master, and origin/HEAD is often stale."""
    if run(['git', '-C', str(repo), 'rev-parse', '-q', '--verify', 'origin/master'])[0] == 0:
        return 'origin/master'
    code, out = run(['git', '-C', str(repo), 'symbolic-ref', '-q', '--short', 'refs/remotes/origin/HEAD'])
    if code == 0 and out.strip():
        return out.strip()
    return 'origin/main' if run(['git', '-C', str(repo), 'rev-parse', '-q', '--verify', 'origin/main'])[0] == 0 else None


def show(repo, ref, path):
    code, out = run(['git', '-C', str(repo), 'show', f'{ref}:{path}'])
    return out if code == 0 else None


def enabled_extensions(repo, ref):
    """Module and theme names from core.extension.yml, or None when it can't be found."""
    for path in ('config/core.extension.yml', 'config/sync/core.extension.yml',
                 'config/default/core.extension.yml', 'web/sites/default/config/core.extension.yml'):
        text = show(repo, ref, path)
        if text:
            return set(re.findall(r'^  ([a-z0-9_]+): ', text, re.M))
    return None


def audit(repo, conf):
    """One client: its advisories and what decides how hard each one hits."""
    name = repo.name
    fetched = run(['git', '-C', str(repo), 'fetch', '-q', 'origin'], timeout=90)[0] == 0
    ref = remote_ref(repo)
    if not ref:
        return {'name': name, 'skip': 'no remote branch'}
    code, out = run(['git', '-C', str(repo), 'log', '-1', '--format=%ct', ref])
    if code != 0 or not out.strip():
        return {'name': name, 'skip': 'no commits on ' + ref}
    idle = (datetime.datetime.now().timestamp() - int(out.strip())) / 86400
    if idle > conf['max_idle_days']:
        return {'name': name, 'skip': f'idle {int(idle)} days'}
    lock, cjson = show(repo, ref, 'composer.lock'), show(repo, ref, 'composer.json')
    if not lock or not cjson:
        return {'name': name, 'skip': 'no composer.lock on ' + ref}
    # Our private Packagist needs a token the host doesn't have, and hosts no advisories;
    # every other repository stays, since Drupal's advisories come through its own.
    manifest = json.loads(cjson)
    repos = manifest.get('repositories')
    if isinstance(repos, list):
        manifest['repositories'] = [r for r in repos if 'packagist.com' not in str(r.get('url', ''))]
    elif isinstance(repos, dict):
        manifest['repositories'] = {k: r for k, r in repos.items()
                                    if not isinstance(r, dict) or 'packagist.com' not in str(r.get('url', ''))}
    tmp = tempfile.mkdtemp(prefix='release-watch-')
    try:
        Path(tmp, 'composer.lock').write_text(lock)
        Path(tmp, 'composer.json').write_text(json.dumps(manifest))
        # No --abandoned: it needs Composer 2.6, and abandoned packages come back under
        # their own key anyway.
        _, out = run(['composer', 'audit', '--locked', '--format=json',
                      '--no-interaction', '--no-plugins', '--no-scripts'], cwd=tmp, timeout=180)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    start = out.find('{')
    if start < 0:
        return {'name': name, 'error': 'composer audit gave no JSON', 'fetched': fetched}
    advisories = json.loads(out[start:]).get('advisories') or {}
    packages = {p['name']: p['version'] for k in ('packages', 'packages-dev')
                for p in json.loads(lock).get(k, [])}
    return {
        'name': name,
        'fetched': fetched,
        'advisories': [a for v in advisories.values() for a in (v.values() if isinstance(v, dict) else v)],
        'versions': packages,
        'enabled': enabled_extensions(repo, ref),
        'commerce': 'drupal/commerce' in packages or 'wpackagist-plugin/woocommerce' in packages,
    }


def plural(n, word):
    return f'{n} {word}' + ('' if n == 1 else 's')


def is_red(adv):
    return bool(DRUPAL_RED.search(adv.get('title', ''))) or str(adv.get('severity', '')).lower() == 'critical'


def reach(site, adv, pomplus):
    """How hard an advisory hits this client: higher is first in line."""
    pkg = adv['packageName']
    module = pkg.split('/', 1)[1] if pkg.startswith('drupal/') else None
    enabled = site['enabled']
    # Core and libraries always run; a contrib module only matters when it's switched on.
    live = module in (None, 'core') or enabled is None or module in enabled
    score = (4 if live else 0) + (2 if site['commerce'] else 0) + (1 if site['name'] in pomplus else 0)
    return score, live


def open_red(alerts, acked):
    """Critical advisories that still reach a live module and nobody has acknowledged."""
    return [a for a in alerts if a['red'] and a['id'] not in acked and any(c['live'] for c in a['clients'])]


def write_status(red):
    status = ''
    if red:
        top = red[0]
        live = [c for c in top['clients'] if c['live']]
        more = f' +{len(live) - 1}' if len(live) > 1 else ''
        lead = f'{len(red)} critical · {top["id"]}' if len(red) > 1 else f'{top["id"]} critical'
        # Double-width, so it reads at twice the size of the text around it.
        status = f'🚨 {BOLD}{RED}{lead} · {live[0]["name"]}{more}{RESET}'
    (CACHE / 'status').write_text(status)


def main_check():
    conf = settings()
    CACHE.mkdir(parents=True, exist_ok=True)
    state_file = CACHE / 'state.json'
    state = json.loads(state_file.read_text()) if state_file.exists() else {'seen': [], 'acked': []}
    repos = [p for p in sorted(conf['projects_dir'].iterdir())
             if (p / '.git').exists() and p.name not in conf['ignore']]
    with concurrent.futures.ThreadPoolExecutor(conf['workers']) as pool:
        results = [s for s in pool.map(lambda r: audit(r, conf), repos) if s]
    skipped = [s for s in results if s.get('skip')]
    sites = [s for s in results if not s.get('skip')]

    pomplus = pom_plus()
    found = {}
    for site in sites:
        for adv in site.get('advisories', []):
            key = adv.get('advisoryId') or adv.get('cve') or adv.get('title')
            entry = found.setdefault(key, {'id': key, 'title': adv.get('title', key), 'link': adv.get('link'),
                                           'package': adv['packageName'], 'red': is_red(adv),
                                           'reported': adv.get('reportedAt', ''), 'clients': []})
            score, live = reach(site, adv, pomplus)
            entry['clients'].append({'name': site['name'], 'score': score, 'live': live,
                                     'version': site['versions'].get(adv['packageName'], '?')})
    # Within a tie, the site with the most critical advisories open is the most exposed.
    exposure = {}
    for entry in found.values():
        if entry['red']:
            for c in entry['clients']:
                if c['live']:
                    exposure[c['name']] = exposure.get(c['name'], 0) + 1
    for entry in found.values():
        for c in entry['clients']:
            c['critical_open'] = exposure.get(c['name'], 0)
        entry['clients'].sort(key=lambda c: (-c['score'], -c['critical_open'], c['name']))
    # Critical first, then by how many sites run the affected code.
    alerts = sorted(found.values(), key=lambda e: (not e['red'], -len([c for c in e['clients'] if c['live']])))
    red = open_red(alerts, state['acked'])
    write_status(red)

    new_red = [a for a in red if a['id'] not in state['seen']]
    if new_red:
        a = new_red[0]
        live = [c for c in a['clients'] if c['live']]
        body = f'{a["id"]} · {live[0]["name"]} first, {len(live)} sites. Run release-watch.py show.'
        title = f'{len(new_red)} new critical release' + ('s' if len(new_red) > 1 else '')
        run(['osascript', '-e', f'display notification {json.dumps(body)} with title {json.dumps(title)} sound name "Basso"'])

    stamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M')
    errors = [s['name'] for s in sites if s.get('error')]
    stale = [s['name'] for s in sites if not s.get('fetched')]
    audited = len(sites) - len(errors)
    # A site that couldn't be audited is a failure of the check, never a clean result.
    summary = f'{audited} client sites audited. {len(red)} critical open, {len(alerts)} advisories in all.'
    if errors:
        summary += f' {len(errors)} COULD NOT BE AUDITED (listed at the end).'
    lines = [f'# Release watch, {stamp}', '', summary, '']
    for a in alerts:
        live = [c for c in a['clients'] if c['live']]
        mark = 'CRITICAL' if a['red'] else 'advisory'
        acked = ' (acknowledged)' if a['id'] in state['acked'] else ''
        lines += [f'## {mark}: {a["title"]}{acked}', '', a.get('link') or '', '',
                  f'{plural(len(live), "site")} {"runs" if len(live) == 1 else "run"} it, {len(a["clients"]) - len(live)} {"has" if len(a["clients"]) - len(live) == 1 else "have"} it installed but off. First in line:', '']
        lines += [f'- {c["name"]} ({a["package"]} {c["version"]}){"" if c["live"] else ", installed but off"}'
                  f'{f", {plural(c["critical_open"], "critical")} open" if c["critical_open"] > 1 else ""}'
                  for c in a['clients'][:15]]
        if len(a['clients']) > 15:
            lines.append(f'- and {len(a["clients"]) - 15} more')
        lines.append('')
    if stale:
        lines += [f'Not fetched (read from the last fetch instead): {", ".join(stale)}', '']
    if errors:
        lines += [f'Could not audit: {", ".join(errors)}', '']
    if skipped:
        lines += ['Skipped:', ''] + [f'- {s["name"]}: {s["skip"]}' for s in skipped] + ['']
    (CACHE / 'digest.md').write_text('\n'.join(lines))

    state['seen'] = sorted(set(state['seen']) | {a['id'] for a in alerts})
    # An ack only means something while the advisory is open.
    state['acked'] = [i for i in state['acked'] if i in found]
    state['checked'] = stamp
    state['alerts'] = alerts
    state_file.write_text(json.dumps(state, indent=1))
    print('\n'.join(lines[:3]))


def main():
    args = sys.argv[1:]
    if args[:1] == ['show']:
        f = CACHE / 'digest.md'
        print(f.read_text() if f.exists() else 'No check has run yet.')
    elif args[:1] == ['ack'] and len(args) == 2:
        state_file = CACHE / 'state.json'
        state = json.loads(state_file.read_text())
        ids = state['seen'] if args[1] == 'all' else [args[1]]
        state['acked'] = sorted(set(state['acked']) | set(ids))
        state_file.write_text(json.dumps(state, indent=1))
        red = open_red(state.get('alerts', []), state['acked'])
        write_status(red)
        print(f'Acknowledged. {len(red)} critical still open.' if red else 'Acknowledged. Nothing critical left open.')
    elif not args:
        main_check()
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == '__main__':
    main()
