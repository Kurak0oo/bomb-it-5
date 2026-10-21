"""candidates/review.html: original vs candidate vs diff for every job, with filters."""
import html
import json
import zipfile

import slots
from common import CANDIDATES, ROOT, write_text

PAGE = r'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Candidate Review</title>
<style>
:root { --bg:#f4f4f2; --panel:#ffffff; --ink:#1d2124; --muted:#5d666d; --line:#d9dcde; --accent:#1f6f78;
        --flag:#b3261e; --flag-bg:#fde8e6; --chip:#e9eef0; --check-a:#e6e6e6; --check-b:#ffffff; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg:#14181b; --panel:#1d2226; --ink:#e8ecee; --muted:#9aa5ad; --line:#30383e; --accent:#6cc4cc;
  --flag:#ff8a80; --flag-bg:#3a1f1d; --chip:#263036; --check-a:#2a3035; --check-b:#353c42; } }
:root[data-theme="dark"] { --bg:#14181b; --panel:#1d2226; --ink:#e8ecee; --muted:#9aa5ad; --line:#30383e;
  --accent:#6cc4cc; --flag:#ff8a80; --flag-bg:#3a1f1d; --chip:#263036; --check-a:#2a3035; --check-b:#353c42; }
* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--ink); font:14px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif; }
header { padding:20px 16px 8px; max-width:1500px; margin:0 auto; }
h1 { font-size:22px; margin:0 0 4px; }
.lede { color:var(--muted); margin:0 0 12px; max-width:900px; }
.stats { display:flex; flex-wrap:wrap; gap:8px; margin-bottom:12px; }
.stat { background:var(--panel); border:1px solid var(--line); border-radius:8px; padding:6px 10px; }
.stat b { font-variant-numeric: tabular-nums; }
.controls { position:sticky; top:0; z-index:2; background:var(--bg); border-bottom:1px solid var(--line);
  padding:10px 16px; display:flex; flex-wrap:wrap; gap:10px; align-items:center; max-width:1500px; margin:0 auto; }
.controls label { display:flex; gap:6px; align-items:center; color:var(--muted); }
select, input[type=search] { font:inherit; color:var(--ink); background:var(--panel); border:1px solid var(--line);
  border-radius:6px; padding:5px 8px; max-width:100%; }
main { max-width:1500px; margin:0 auto; padding:12px 16px 40px; }
.grid { display:grid; grid-template-columns:repeat(auto-fill, minmax(min(100%, 420px), 1fr)); gap:12px; }
.card { background:var(--panel); border:1px solid var(--line); border-radius:10px; padding:10px; min-width:0; }
.card.flag { border-color:var(--flag); }
.head { display:flex; justify-content:space-between; gap:8px; align-items:baseline; }
.name { font-weight:600; overflow-wrap:anywhere; }
.pct { font-variant-numeric:tabular-nums; white-space:nowrap; }
.flag .pct { color:var(--flag); background:var(--flag-bg); border-radius:4px; padding:0 5px; }
.meta { color:var(--muted); font-size:12px; margin:2px 0 8px; overflow-wrap:anywhere; }
.chip { display:inline-block; background:var(--chip); border-radius:4px; padding:0 5px; margin:0 4px 2px 0; }
.trio { display:grid; grid-template-columns:repeat(3, minmax(0, 1fr)); gap:6px; }
figure { margin:0; min-width:0; }
figcaption { font-size:11px; color:var(--muted); margin-bottom:2px; }
.img { background:repeating-conic-gradient(var(--check-a) 0 25%, var(--check-b) 0 50%) 0 0/12px 12px;
  border-radius:4px; display:flex; align-items:center; justify-content:center; min-height:60px; overflow:hidden; }
.img img { max-width:100%; max-height:260px; display:block; }
.links { font-size:12px; margin-top:6px; }
a { color:var(--accent); }
.pager { display:flex; gap:8px; align-items:center; justify-content:center; margin:16px 0; }
button { font:inherit; color:var(--ink); background:var(--panel); border:1px solid var(--line); border-radius:6px; padding:5px 12px; cursor:pointer; }
button:disabled { opacity:.4; cursor:default; }
.empty { color:var(--muted); padding:40px 0; text-align:center; }
</style>
</head>
<body>
<header>
  <h1>Candidate review</h1>
  <p class="lede">SWF-derived candidates for the Art Workbench. Nothing here is applied to the game. Review each one,
  then import the ones you choose with <em>Replace image…</em> in the workbench. Change % is the mean premultiplied
  pixel difference between the original and the candidate preview; it is a review aid, not approval.</p>
  <div class="stats" id="stats"></div>
</header>
<div class="controls">
  <label>Show <select id="kind"><option value="slot">Slot candidates</option><option value="asset">Asset candidates</option><option value="all">Everything</option></select></label>
  <label>Slot <select id="slot"></select></label>
  <label>Type <select id="type"><option value="">All types</option></select></label>
  <label><input type="checkbox" id="flag"> Over __FLAG__% change only</label>
  <label>Sort <select id="sort"><option value="name">Name</option><option value="desc">Change, high first</option><option value="asc">Change, low first</option></select></label>
  <input type="search" id="q" placeholder="Search name or source" aria-label="Search">
</div>
<main>
  <div class="grid" id="grid"></div>
  <div class="pager"><button id="prev">Previous</button><span id="page"></span><button id="next">Next</button></div>
</main>
<script>
const DATA = __DATA__;
const SLOTS = __SLOTS__;
const PER_PAGE = 60;
let page = 0;
const $ = (id) => document.getElementById(id);
function remember(key, value) { try { localStorage.setItem('review.' + key, value); } catch (e) {} }
function recall(key) { try { return localStorage.getItem('review.' + key); } catch (e) { return null; } }
const slotSelect = $('slot');
[['', 'All slots'], ['__mapped', 'Any mapped slot'], ['unmapped', 'Unmapped']].concat(SLOTS.map(s => [s, s]))
  .forEach(([v, t]) => slotSelect.add(new Option(t, v)));
[...new Set(DATA.map(d => d.type))].sort().forEach(t => $('type').add(new Option(t, t)));
const flagged = DATA.filter(d => d.flag).length;
const slotJobs = DATA.filter(d => d.kind === 'slot');
$('stats').innerHTML = [
  ['Slot candidates', slotJobs.length], ['Asset candidates', DATA.length - slotJobs.length],
  ['Over __FLAG__%', flagged],
  ['Median change (slots)', median(slotJobs.map(d => d.change_pct)).toFixed(1) + '%'],
  ['Median change (assets)', median(DATA.filter(d => d.kind === 'asset').map(d => d.change_pct)).toFixed(1) + '%']
].map(([k, v]) => `<div class="stat">${k}: <b>${v}</b></div>`).join('');
function median(values) { if (!values.length) return 0; const s = [...values].sort((a, b) => a - b); return s[Math.floor(s.length / 2)]; }
function esc(text) { return String(text).replace(/[&<>"]/g, c => ({'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;'}[c])); }
function filtered() {
  const kind = $('kind').value, slot = $('slot').value, type = $('type').value, q = $('q').value.toLowerCase();
  let rows = DATA.filter(d => (kind === 'all' || d.kind === kind)
    && (!slot || (slot === '__mapped' ? d.slots.length > 0 : slot === 'unmapped' ? d.slots.length === 0 : d.slots.includes(slot)))
    && (!type || d.type === type) && (!$('flag').checked || d.flag)
    && (!q || (d.id + ' ' + d.sources.join(' ')).toLowerCase().includes(q)));
  const sort = $('sort').value;
  rows.sort(sort === 'name' ? (a, b) => a.id.localeCompare(b.id) : sort === 'desc' ? (a, b) => b.change_pct - a.change_pct : (a, b) => a.change_pct - b.change_pct);
  return rows;
}
function card(d) {
  const f = d.folder;
  const chips = d.slots.length ? d.slots.map(s => `<span class="chip">${esc(s)}</span>`).join('') : '<span class="chip">unmapped</span>';
  const layout = d.rows === 4 ? `${d.columns} across × 4 rows (Down, Right, Up, Left)` : `${d.columns} across × ${d.rows} row`;
  return `<article class="card${d.flag ? ' flag' : ''}">
    <div class="head"><span class="name">${esc(d.id)}</span><span class="pct">${d.change_pct.toFixed(1)}%${d.flag ? ' · over __FLAG__%' : ''}</span></div>
    <div class="meta">${chips}<br>${esc(d.type)} · ${layout} · cell ${d.cell[0]}×${d.cell[1]} · from ${esc(d.sources.join(', '))}</div>
    <div class="trio">
      <figure><figcaption>Original</figcaption><div class="img"><img loading="lazy" src="${f}/before.png" alt="Original ${esc(d.id)}"></div></figure>
      <figure><figcaption>Candidate</figcaption><div class="img"><img loading="lazy" src="${f}/after.png" alt="Candidate ${esc(d.id)}"></div></figure>
      <figure><figcaption>Difference</figcaption><div class="img"><img loading="lazy" src="${f}/diff.png" alt="Difference ${esc(d.id)}"></div></figure>
    </div>
    <div class="links"><a href="${f}/candidate.png">candidate.png</a> (import this) · <a href="${f}/meta.json">meta.json</a> · <a href="${f}/palette.json">palette</a></div>
  </article>`;
}
function draw() {
  const rows = filtered();
  const pages = Math.max(1, Math.ceil(rows.length / PER_PAGE));
  page = Math.min(page, pages - 1);
  $('grid').innerHTML = rows.length ? rows.slice(page * PER_PAGE, (page + 1) * PER_PAGE).map(card).join('') : '<p class="empty">No candidates match these filters.</p>';
  $('page').textContent = `${rows.length} shown · page ${page + 1} of ${pages}`;
  $('prev').disabled = page === 0; $('next').disabled = page >= pages - 1;
  ['kind', 'slot', 'type', 'sort'].forEach(k => remember(k, $(k).value)); remember('flag', $('flag').checked ? '1' : '');
}
['kind', 'slot', 'type', 'sort'].forEach(k => { const v = recall(k); if (v !== null && [...$(k).options].some(o => o.value === v)) $(k).value = v; });
$('flag').checked = recall('flag') === '1';
['kind', 'slot', 'type', 'sort', 'flag'].forEach(k => $(k).addEventListener('change', () => { page = 0; draw(); }));
$('q').addEventListener('input', () => { page = 0; draw(); });
$('prev').addEventListener('click', () => { page--; draw(); window.scrollTo(0, 0); });
$('next').addEventListener('click', () => { page++; draw(); window.scrollTo(0, 0); });
draw();
</script>
</body>
</html>
'''


def build(metas, flag_pct):
    rows = []
    for meta in metas:
        rows.append({'id': meta['id'], 'kind': meta['kind'], 'folder': meta['folder'], 'type': meta['type'],
                     'slots': meta.get('slots', []), 'sources': meta['sources'], 'rows': meta['rows'],
                     'columns': meta['columns'], 'cell': meta['cell'], 'change_pct': meta['change_pct'],
                     'flag': meta['flag']})
    data = json.dumps(sorted(rows, key=lambda r: r['id']), separators=(',', ':')).replace('</', '<\\/')
    page = (PAGE.replace('__DATA__', data).replace('__SLOTS__', json.dumps([s['id'] for s in slots.entries()]))
            .replace('__FLAG__', html.escape(f'{flag_pct:g}')))
    write_text(CANDIDATES / 'review.html', page)
    return CANDIDATES / 'review.html'


def slots_zip(metas, flag_pct):
    """A small download: slot candidates and a review page listing only them."""
    target = ROOT / 'candidates-slots.zip'
    slot_metas = [m for m in metas if m['kind'] == 'slot']
    build(slot_metas, flag_pct)
    page = (CANDIDATES / 'review.html').read_text(encoding='utf-8')
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as bundle:
        for path in sorted((CANDIDATES / 'slots').rglob('*')):
            if path.is_file():
                bundle.write(path, path.relative_to(ROOT).as_posix())
        for name in ('summary.json', 'failures.json', '.gdignore'):
            if (CANDIDATES / name).is_file():
                bundle.write(CANDIDATES / name, f'candidates/{name}')
        bundle.writestr('candidates/review.html', page)
    build(metas, flag_pct)
    return target
