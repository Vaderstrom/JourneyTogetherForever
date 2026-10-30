// Draws the Journey Together board (docs/SAVED-DATA.md, format 1) into #board, styled by board.css. Used by
// card.html (the picture WoW Addon Webhooks for Discord posts) and docs/mockup/companion-board.html (the sample boards).
// JTFBoard.render(board, { now, art }), then JTFBoard.ready() resolves once its pictures have loaded. art:
// { chapter(name), dungeon(key, d), emblem(name), frame }, each a URL or null (then the card draws without it);
// dungeon may also give a part of a picture, { src, crop: [left, right, top, bottom], aspect } (a loading screen).
(function () {
  'use strict';
  const MIN = 60, HOUR = 3600, DAY = 86400;
  const NO_ART = { chapter: () => null, dungeon: () => null, emblem: () => null, frame: null };
  const TILE = 84 / 48; // a dungeon's picture (board.css .dun .pic)

  // ---------- Colours (the mockup's class colours, Rules/Journey.lua ROLE_COLOR) ----------
  // Light colour for the dot and bar, dark ink for the name on paper (mockup CLS / CLS_INK).
  const CLASS = {
    WARRIOR: ['#C69B6D', '#7A5230'], PALADIN: ['#F48CBA', '#A8406E'], HUNTER: ['#AAD372', '#4E7A2A'],
    ROGUE: ['#FFF468', '#7A6A00'], PRIEST: ['#E8E8E8', '#55555A'], SHAMAN: ['#2459FF', '#0A4AB8'],
    MAGE: ['#3FC7EB', '#1A6E8E'], WARLOCK: ['#8788EE', '#4A3E9A'], DRUID: ['#FF7C0A', '#A8540A'],
  };
  const ROLE = { Mandatory: ['#A8761E', '#7A5410'], Bridge: ['#2F6FAE', '#1F4F80'], Optional: ['#4F7F3F', '#3A5F2E'] };
  const STANDING = { below: 'var(--below)', ready: 'var(--ready)', cap: 'var(--cap)', over: 'var(--over)', away: 'var(--line)' };

  // ---------- Drawing ----------
  function el(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = String(text);
    return e;
  }
  function add(parent, ...kids) { kids.forEach((k) => k && parent.appendChild(k)); return parent; }
  // An image that removes itself (or calls fail) when the file is missing.
  function img(src, cls, fail) {
    if (!src) { if (fail) fail(); return null; }
    const i = el('img', cls); i.alt = ''; i.decoding = 'sync';
    i.onerror = () => { i.remove(); if (fail) fail(); };
    i.src = src;
    return i;
  }
  // Part of a picture (crop: its left, right, top and bottom, 0 to 1, shown at aspect) filling a box of shape box
  // (width / height): the middle of that part, as the game crops it (Data/Dungeons.lua crop).
  function part(p, box, fail) {
    const i = img(p.src, 'part', fail);
    if (!i) return null;
    const [l, r, t, b] = p.crop || [0, 1, 0, 1], shape = p.aspect || box;
    // The part's size in box widths and heights, then the whole picture's.
    const pw = shape > box ? shape / box : 1, ph = shape > box ? 1 : box / shape;
    const fw = pw / (r - l), fh = ph / (b - t);
    Object.assign(i.style, { width: fw * 100 + '%', height: fh * 100 + '%',
      left: -(l * fw + (pw - 1) / 2) * 100 + '%', top: -(t * fh + (ph - 1) / 2) * 100 + '%' });
    return i;
  }
  function hex(c) { return /^[0-9a-fA-F]{6}$/.test(c || '') ? '#' + c : '#4A5560'; }

  function label(text) {
    const l = el('div', 'label');
    add(l, el('span'), el('i', null, '❦'), el('h2', null, text), el('i', null, '❦'), el('span'));
    return l;
  }

  // "12 minutes ago", "3 hours ago", "1 day ago".
  function ago(sec) {
    sec = Math.max(0, sec);
    if (sec < HOUR) { const m = Math.max(1, Math.floor(sec / MIN)); return m + (m === 1 ? ' minute ago' : ' minutes ago'); }
    if (sec < DAY) { const h = Math.floor(sec / HOUR); return h + (h === 1 ? ' hour ago' : ' hours ago'); }
    const d = Math.floor(sec / DAY); return d + (d === 1 ? ' day ago' : ' days ago');
  }

  function crest(f, art) {
    const c = el('div', 'crest');
    const e = art.emblem(f.emblem);
    const glyph = () => { c.textContent = ''; add(c, el('span', 'glyph', '✦')); };
    if (e && e.sheet) {
      const cell = el('div', 'cell');
      const i = img(e.sheet, null, glyph);
      if (i) {
        i.style.left = -(e.cell % 4) * 100 + '%';
        i.style.top = -Math.floor(e.cell / 4) * 100 + '%';
        add(c, add(cell, i));
      }
    } else if (e && e.picture) {
      add(c, img(e.picture, 'pic', glyph));
    } else glyph();
    return c;
  }

  function header(b, art) {
    const h = el('div', 'head');
    if (b.chapter) add(h, img(art.chapter(b.chapter.picture), 'art'));
    add(h, el('div', 'shade'));
    const names = el('div', 'names');
    add(names, el('div', 'fname clip', b.fellowship.name));
    if (b.chapter) {
      const line = el('div', 'chline');
      add(line, el('span', 'chip t', b.title), el('span', 'chname clip', b.chapter.name));
      add(names, line);
    }
    add(h, crest(b.fellowship, art), names);
    return h;
  }

  function track(stages) {
    const t = el('div', 'track');
    stages.forEach((s, i) => {
      const n = el('div', 'node ' + (s.state === 'done' || s.state === 'current' ? s.state : 'todo'));
      add(n, el('div', 'ring', s.state === 'done' ? '✓' : i + 1), el('div', 'lbl t', s.text));
      if (i < stages.length - 1) add(n, el('div', 'link'));
      add(t, n);
    });
    return t;
  }

  // The bar from the floor to the cap (full at or over the cap, empty below the floor).
  function fill(h, ch) {
    if (!ch) return 0;
    const span = ch.cap - ch.floor;
    const v = span > 0 ? (h.level + (h.xp || 0) - ch.floor) / span : (h.level >= ch.cap ? 1 : 0);
    return Math.max(0, Math.min(1, v));
  }

  function heroRow(h, ch, small) {
    const cc = CLASS[h.class] || ['#B8A57C', '#3B2410'];
    const standing = h.group === 'counted' ? h.standing : 'muted';
    const r = el('div', 'hero s-' + (standing || 'none') + (small ? ' small' : ''));
    const dot = el('span', 'dot'); dot.style.background = cc[0];
    const nm = el('span', 'nm clip', h.short || h.name); nm.style.color = cc[1];
    const bar = el('span', 'lvbar'); const f = el('i');
    f.style.width = (fill(h, ch) * 100).toFixed(1) + '%';
    f.style.background = STANDING[h.standing] || 'var(--line)';
    add(bar, f);
    add(r, dot, nm, el('span', 'lv', h.level), bar, h.text != null ? el('span', 'note clip', h.text) : null);
    return r;
  }

  function heroesSection(b) {
    const s = el('div', 'sec');
    add(s, label('Adventurers'));
    const MAX = 10;
    const list = b.heroes || [];
    const shown = list.length > MAX ? list.slice(0, MAX) : list;
    let firstSmall = true;
    shown.forEach((h) => {
      const small = h.group === 'catching' || h.group === 'away';
      const r = heroRow(h, b.chapter, small);
      if (small && firstSmall) { r.classList.add('first-small'); firstSmall = false; }
      add(s, r);
    });
    if (list.length > shown.length) add(s, el('div', 'more', 'and ' + (list.length - shown.length) + ' more'));
    return s;
  }

  function dungeonRow(d, art) {
    const rc = ROLE[d.role] || ROLE.Optional;
    const state = d.state === 'cleared' || d.done ? 'cleared' : (d.state === 'locked' ? 'locked' : 'open');
    const r = el('div', 'dun ' + state);
    r.style.setProperty('--rolec', rc[0]); r.style.setProperty('--roleink', rc[1]);
    const pic = el('div', 'pic');
    const ph = () => add(pic, el('div', 'ph', '⚔'));
    const a = art.dungeon(d.key, d);
    add(pic, a && typeof a === 'object' ? part(a, TILE, ph) : img(a, null, ph));
    const mid = el('div', 'mid');
    add(mid, el('div', 'dn clip', d.name), el('span', 'role', d.role));
    const st = el('div', 'st t');
    if (state === 'cleared') add(st, el('span', 'mk', '✓'));
    add(st, document.createTextNode(d.text || ''));
    add(r, pic, mid, st);
    return r;
  }

  function dungeonsSection(b, art) {
    const s = el('div', 'sec');
    if (b.dungeons && b.dungeons.length) {
      add(s, label('Dungeons'));
      b.dungeons.forEach((d) => add(s, dungeonRow(d, art)));
      return s;
    }
    if (!b.level) return null;
    const box = el('div', 'levelpic');
    add(box, img(b.chapter && art.chapter(b.chapter.picture)), el('div', 'txt t', b.level));
    return add(s, box);
  }

  function waitingSection(b) {
    if (!b.waiting) return null;
    return add(el('div', 'sec'), label('Waiting for'), el('div', 'wait t', b.waiting));
  }

  function latestSection(b) {
    const list = (b.latest || []).slice(0, 3);
    if (!list.length) return null;
    const ul = el('ul', 'latest');
    list.forEach((x) => add(ul, el('li', 't', x)));
    return add(el('div', 'sec'), label('Latest'), ul);
  }

  function footer(b, now) {
    const who = (b.heroes || []).find((h) => h.name === b.by);
    const short = (who && who.short) || String(b.by || '').split('-')[0];
    const age = now - (b.saved || 0);
    const stale = age >= 3 * DAY;
    const when = stale ? 'Not updated for ' + Math.floor(age / DAY) + ' days' : 'As of ' + ago(age);
    return el('div', 'foot' + (stale ? ' stale' : ''), when + ' · from ' + short + "'s game");
  }

  // Draws board b into target (default #board). opts: { now: Unix seconds, art: { chapter, dungeon, emblem } }.
  function render(b, opts) {
    opts = opts || {};
    const target = opts.target || document.getElementById('board');
    const now = opts.now != null ? opts.now : Math.floor(Date.now() / 1000);
    const art = Object.assign({}, NO_ART, opts.art || {});
    target.textContent = '';
    target.style.setProperty('--banner', hex(b.fellowship && b.fellowship.color));
    target.style.setProperty('--frame-img', art.frame ? 'url("' + art.frame + '")' : 'none');
    target.dataset.frame = art.frame || '';
    const inner = el('div', 'inner');
    add(inner, header(b, art));
    const paper = el('div', 'paper');
    if (b.journey === 'complete' || !b.chapter) {
      const page = el('div', 'page single');
      const t = el('div', 'done-title');
      add(t, el('div', 'medal', '✦'), el('h1', 't', b.title));
      add(page, t, latestSection(b));
      add(paper, page);
    } else {
      if (b.stages && b.stages.length) add(paper, track(b.stages));
      const spread = el('div', 'spread');
      const left = add(el('div', 'page left'), heroesSection(b));
      const right = add(el('div', 'page right'), dungeonsSection(b, art), waitingSection(b), latestSection(b));
      add(paper, add(spread, left, right));
    }
    add(inner, paper, footer(b, now));
    add(target, el('div', 'edge'), inner);
    return target;
  }

  // Resolves once every picture in the card has loaded or been replaced: capture the PNG after this.
  function ready(target) {
    target = target || document.getElementById('board');
    const imgs = [...target.querySelectorAll('img')];
    // The frame is a CSS border image: load it as a picture too, so it is there before the capture.
    if (target.dataset.frame) { const f = new Image(); f.src = target.dataset.frame; imgs.push(f); }
    return Promise.all(imgs.map((i) => (i.complete ? null : new Promise((res) => {
      i.addEventListener('load', res, { once: true }); i.addEventListener('error', res, { once: true });
    })))).then(() => Promise.all(imgs.filter((i) => i.isConnected && i.decode).map((i) => i.decode().catch(() => null))))
      .then(() => target);
  }

  window.JTFBoard = { render, ready };
})();
