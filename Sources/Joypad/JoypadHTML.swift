enum JoypadHTML {
    static let page = #"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="mobile-web-app-capable" content="yes">
<meta name="screen-orientation" content="landscape">
<meta name="theme-color" content="#0b0d12">
<title>Joypad</title>
<style>
  :root {
    --bg: #0b0d12;
    --panel: #141821;
    --line: #2a3140;
    --text: #f4f6fb;
    --muted: #8b93a7;
    --lime: #b6ff3b;
    --glow: rgba(182, 255, 59, 0.35);
  }
  * {
    box-sizing: border-box;
    -webkit-tap-highlight-color: transparent;
    -webkit-touch-callout: none;
    -webkit-user-select: none;
    -webkit-user-drag: none;
    user-select: none;
    touch-action: none;
    outline: none;
  }
  *::selection { background: transparent; color: inherit; }
  html, body {
    margin: 0; height: 100%; background: var(--bg); color: var(--text);
    font-family: ui-rounded, -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
    overscroll-behavior: none; overflow: hidden;
    -webkit-user-select: none; user-select: none;
  }
  body {
    padding: calc(6px + env(safe-area-inset-top)) calc(10px + env(safe-area-inset-right)) calc(8px + env(safe-area-inset-bottom)) calc(10px + env(safe-area-inset-left));
    display: flex; flex-direction: column; gap: 6px;
  }
  header {
    display: flex; align-items: center; justify-content: space-between;
    gap: 8px; min-height: 28px;
  }
  .brand { letter-spacing: 0.22em; font-weight: 800; font-size: 11px; flex: 0 0 auto; }
  .modes {
    display: flex; gap: 4px; padding: 3px;
    border: 1px solid var(--line); background: var(--panel);
    border-radius: 999px;
  }
  .mode {
    border: 0; border-radius: 999px; padding: 5px 10px;
    background: transparent; color: var(--muted);
    font-size: 10px; font-weight: 800; letter-spacing: 0.08em;
  }
  .mode.on {
    background: var(--lime); color: #0b0d12;
  }
  .pill {
    display: flex; align-items: center; gap: 6px;
    border: 1px solid var(--line); background: var(--panel);
    border-radius: 999px; padding: 4px 8px; font-size: 10px; color: var(--muted);
  }
  .dot { width: 7px; height: 7px; border-radius: 50%; background: #ff5f57; }
  .dot.on { background: var(--lime); box-shadow: 0 0 12px var(--glow); }
  .stage {
    flex: 1; min-height: 0;
    display: grid;
    grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
    gap: 8px;
    align-items: end;
    position: relative;
    padding-bottom: 4px;
  }
  .pad, .keys {
    background: linear-gradient(180deg, #171c26, #10141c);
    border: 1px solid var(--line); border-radius: 20px;
    box-shadow: inset 0 1px 0 rgba(255,255,255,0.04);
  }
  .pad {
    display: grid; place-items: center; position: relative;
    justify-self: start; align-self: end;
    width: min(36vw, 210px); height: min(36vw, 210px);
    padding: 10px;
  }
  .keys {
    justify-self: end; align-self: end;
    width: min(48vw, 280px);
    height: min(34vw, 168px);
    display: grid; gap: 9px; padding: 12px;
    grid-auto-rows: 1fr;
  }
  .keys[data-style="8"] { grid-template-columns: repeat(4, 1fr); }
  .keys[data-style="6"] {
    width: min(56vw, 360px);
    height: min(42vw, 232px);
    grid-template-columns: repeat(3, 1fr);
    gap: 16px;
    padding: 18px 16px 14px;
    border-radius: 28px;
  }
  .keys[data-style="4"] {
    width: min(44vw, 248px);
    height: min(44vw, 248px);
    grid-template-columns: 1fr 1fr 1fr;
    grid-template-rows: 1fr 1fr 1fr;
    gap: 8px;
    padding: 10px;
    border-radius: 50%;
    background: radial-gradient(circle at 50% 40%, #1c2230, #10141c 72%);
  }
  .keys[data-style="4"] [data-min="6"],
  .keys[data-style="4"] [data-min="8"],
  .keys[data-style="6"] [data-min="8"] { display: none; }
  .keys[data-style="4"] [data-key="w"] { grid-area: 1 / 2; }
  .keys[data-style="4"] [data-key="q"] { grid-area: 2 / 1; }
  .keys[data-style="4"] [data-key="s"] { grid-area: 2 / 3; }
  .keys[data-style="4"] [data-key="a"] { grid-area: 3 / 2; }
  .btn {
    border: 0; border-radius: 16px; color: #fff; font-size: 17px; font-weight: 800;
    letter-spacing: 0.04em; cursor: pointer;
    -webkit-user-select: none; user-select: none; -webkit-touch-callout: none;
    -webkit-appearance: none; appearance: none;
    background: linear-gradient(180deg, var(--btn-hi), var(--btn));
    box-shadow: inset 0 1px 0 rgba(255,255,255,0.28), 0 5px 0 var(--btn-lip);
    text-shadow: 0 1px 0 rgba(0,0,0,0.35);
    transform: translateY(0);
  }
  .btn[data-key="q"] { --btn-hi: #6ee7a8; --btn: #22a05a; --btn-lip: #0f5c34; }
  .btn[data-key="w"] { --btn-hi: #7eb6ff; --btn: #2b6fe0; --btn-lip: #163a86; }
  .btn[data-key="e"] { --btn-hi: #ff8a80; --btn: #e24b4b; --btn-lip: #8f1f1f; }
  .btn[data-key="r"] { --btn-hi: #d4a5ff; --btn: #8b5cf6; --btn-lip: #4c1d95; }
  .btn[data-key="a"] { --btn-hi: #ffe566; --btn: #e0b000; --btn-lip: #8a6a00; }
  .btn[data-key="s"] { --btn-hi: #ff7a6e; --btn: #d63b32; --btn-lip: #7a1510; }
  .btn[data-key="d"] { --btn-hi: #7ee0ff; --btn: #1a9bb8; --btn-lip: #0b5366; }
  .btn[data-key="f"] { --btn-hi: #ff8ac4; --btn: #db2777; --btn-lip: #831843; }
  .keys[data-style="6"] .btn {
    border-radius: 50%;
    font-size: 18px;
  }
  .keys[data-style="6"] .btn:nth-child(1),
  .keys[data-style="6"] .btn:nth-child(2),
  .keys[data-style="6"] .btn:nth-child(3) {
    transform: translate(12px, -8px);
  }
  .keys[data-style="4"] .btn {
    border-radius: 50%;
    font-size: 18px;
  }
  .btn.pressed {
    transform: translateY(4px);
    filter: brightness(1.18);
    box-shadow: inset 0 3px 8px rgba(0,0,0,0.35), 0 1px 0 var(--btn-lip);
  }
  .keys[data-style="6"] .btn:nth-child(1).pressed,
  .keys[data-style="6"] .btn:nth-child(2).pressed,
  .keys[data-style="6"] .btn:nth-child(3).pressed {
    transform: translate(12px, -4px);
  }
  .btn:focus, .btn:focus-visible, .sys:focus { outline: none; }
  .dpad {
    width: 100%; aspect-ratio: 1; position: relative;
  }
  .ring {
    position: absolute; inset: 0; border-radius: 50%;
    background: radial-gradient(circle at 50% 35%, #222836, #0e1219 68%);
    border: 1px solid #303848;
    box-shadow: inset 0 12px 20px rgba(0,0,0,0.35), 0 6px 14px rgba(0,0,0,0.28);
  }
  .dir {
    position: absolute; width: 32%; height: 32%; display: grid; place-items: center;
    color: #9aa3b8; font-size: 21px; font-weight: 700;
  }
  .dir.pressed { color: var(--lime); text-shadow: 0 0 18px var(--glow); }
  .north { top: 6%; left: 34%; }
  .south { bottom: 6%; left: 34%; }
  .west { left: 6%; top: 34%; }
  .east { right: 6%; top: 34%; }
  .diag { display: none; font-size: 11px; width: 22%; height: 22%; }
  .ne { top: 8%; right: 8%; left: auto; }
  .se { bottom: 8%; right: 8%; left: auto; top: auto; }
  .sw { bottom: 8%; left: 8%; top: auto; }
  .nw { top: 8%; left: 8%; }
  .stage[data-style="6"] .diag { display: grid; }
  .stage[data-style="6"] .ring {
    clip-path: polygon(29% 0%, 71% 0%, 100% 29%, 100% 71%, 71% 100%, 29% 100%, 0% 71%, 0% 29%);
  }
  .stage[data-style="6"] .dir { font-size: 18px; }
  .mid {
    display: flex;
    flex-direction: column;
    gap: 8px;
    align-items: center;
    justify-content: flex-end;
    z-index: 2;
    padding-bottom: 52px;
    min-width: 72px;
  }
  .stage[data-style="6"] {
    grid-template-columns: auto 1fr;
    grid-template-rows: auto auto;
    justify-content: space-between;
    column-gap: 16px;
    row-gap: 0;
  }
  .stage[data-style="6"] .pad {
    grid-column: 1;
    grid-row: 1 / span 2;
  }
  .stage[data-style="6"] .mid {
    grid-column: 2;
    grid-row: 1;
    justify-self: end;
    align-self: end;
    flex-direction: row;
    justify-content: flex-end;
    width: min(56vw, 360px);
    min-width: 0;
    padding: 0 18px 10px 0;
    gap: 12px;
  }
  .stage[data-style="6"] .keys {
    grid-column: 2;
    grid-row: 2;
  }
  .stage[data-style="6"] .sys {
    width: 72px;
    height: 22px;
  }
  .stage[data-style="4"] .mid {
    padding-bottom: 36px;
    gap: 10px;
  }
  .stage[data-style="4"] .sys {
    width: 58px;
    height: 20px;
    letter-spacing: 0.1em;
  }
  .stage[data-style="4"] .sys[data-key="j"] {
    transform: rotate(-18deg);
    margin-right: 14px;
  }
  .stage[data-style="4"] .sys[data-key="k"] {
    transform: rotate(-18deg);
    margin-left: 14px;
  }
  .stage[data-style="4"] .sys[data-key="j"].pressed,
  .stage[data-style="4"] .sys[data-key="k"].pressed {
    transform: rotate(-18deg) translateY(2px);
  }
  .sys {
    width: 78px; height: 26px; border: 0; border-radius: 999px;
    color: var(--muted); font-size: 8px; font-weight: 800; letter-spacing: 0.14em;
    background: linear-gradient(180deg, #2a3140, #1a2030);
    box-shadow: inset 0 1px 0 rgba(255,255,255,0.08), 0 4px 0 #0a0d13;
    text-shadow: none;
    filter: none;
  }
  .sys.pressed {
    transform: translateY(3px); box-shadow: 0 1px 0 #0a0d13;
    color: #0b0d12; background: linear-gradient(180deg, #d8ff7a, var(--lime));
    filter: none;
  }
  .sys small { display: block; font-size: 10px; letter-spacing: 0.04em; }
  .rotate {
    display: none; position: fixed; inset: 0; z-index: 20;
    background: rgba(11,13,18,0.92); color: var(--text);
    align-items: center; justify-content: center; text-align: center;
    font-size: 18px; font-weight: 700; padding: 24px;
  }
  @media (orientation: portrait) {
    .rotate { display: flex; }
  }
</style>
</head>
<body>
  <div class="rotate">Turn the iPhone sideways</div>
  <header>
    <div class="brand">JOYPAD</div>
    <div class="modes" id="modes">
      <button class="mode on" data-style="8">8</button>
      <button class="mode" data-style="6">6</button>
      <button class="mode" data-style="4">4</button>
    </div>
    <div class="pill"><span class="dot" id="dot"></span><span id="status">Connecting…</span></div>
  </header>
  <div class="stage" id="stage" data-style="8">
    <div class="pad" id="pad">
      <div class="dpad" id="dpad">
        <div class="ring"></div>
        <div class="dir north" data-key="up">▲</div>
        <div class="dir ne diag" data-diag="ne">◆</div>
        <div class="dir east" data-key="right">▶</div>
        <div class="dir se diag" data-diag="se">◆</div>
        <div class="dir south" data-key="down">▼</div>
        <div class="dir sw diag" data-diag="sw">◆</div>
        <div class="dir west" data-key="left">◀</div>
        <div class="dir nw diag" data-diag="nw">◆</div>
        <div class="hub"></div>
      </div>
    </div>
    <div class="mid">
      <button class="sys btn" data-key="j">SELECT<small>J</small></button>
      <button class="sys btn" data-key="k">START<small>K</small></button>
    </div>
    <div class="keys" id="keys" data-style="8">
      <button class="btn" data-key="q" data-min="4">Q</button>
      <button class="btn" data-key="w" data-min="4">W</button>
      <button class="btn" data-key="e" data-min="6">E</button>
      <button class="btn" data-key="r" data-min="8">R</button>
      <button class="btn" data-key="a" data-min="4">A</button>
      <button class="btn" data-key="s" data-min="4">S</button>
      <button class="btn" data-key="d" data-min="6">D</button>
      <button class="btn" data-key="f" data-min="8">F</button>
    </div>
  </div>
<script>
(() => {
  const held = new Map();
  const pointers = new Map();
  let ws, ping, retry = 0;
  const keysEl = document.getElementById("keys");

  const applyStyle = (count) => {
    const style = String(count) === "4" || String(count) === "6" ? String(count) : "8";
    keysEl.dataset.style = style;
    document.getElementById("stage").dataset.style = style;
    document.querySelectorAll(".mode").forEach((el) => el.classList.toggle("on", el.dataset.style === style));
    document.querySelectorAll("#keys .btn").forEach((el) => {
      const min = Number(el.dataset.min || 4);
      if (min > Number(style) && held.get(el.dataset.key)) send(el.dataset.key, false);
    });
    try { localStorage.setItem("joypad.style", style); } catch (_) {}
  };

  const setStatus = (ok, text) => {
    document.getElementById("dot").classList.toggle("on", ok);
    document.getElementById("status").textContent = text;
  };

  const send = (key, down) => {
    const prev = held.get(key) || false;
    if (prev === down) return;
    held.set(key, down);
    document.querySelectorAll(`[data-key="${key}"]`).forEach((el) => el.classList.toggle("pressed", down));
    if (ws && ws.readyState === 1) ws.send(JSON.stringify({ k: key, s: down ? 1 : 0 }));
  };

  const connect = () => {
    const proto = location.protocol === "https:" ? "wss" : "ws";
    ws = new WebSocket(`${proto}://${location.host}/ws`);
    ws.onopen = () => {
      retry = 0;
      setStatus(true, "Linked to Mac");
      ping = setInterval(() => { if (ws.readyState === 1) ws.send('{"k":"ping"}'); }, 12000);
    };
    ws.onclose = () => {
      clearInterval(ping);
      setStatus(false, "Reconnecting…");
      [...held.keys()].forEach((k) => send(k, false));
      setTimeout(connect, Math.min(4000, 400 + retry++ * 400));
    };
    ws.onerror = () => ws.close();
  };

  const bindButton = (el) => {
    const key = el.dataset.key;
    el.addEventListener("pointerdown", (e) => {
      e.preventDefault();
      pointers.set(e.pointerId, key);
      send(key, true);
    });
  };
  document.querySelectorAll(".btn").forEach(bindButton);
  const releasePointer = (e) => {
    const key = pointers.get(e.pointerId);
    if (!key) return;
    pointers.delete(e.pointerId);
    send(key, false);
  };
  window.addEventListener("pointerup", releasePointer);
  window.addEventListener("pointercancel", releasePointer);

  document.querySelectorAll(".mode").forEach((el) => {
    el.addEventListener("pointerdown", (e) => {
      e.preventDefault();
      e.stopPropagation();
      applyStyle(el.dataset.style);
    });
  });
  try { applyStyle(localStorage.getItem("joypad.style") || "8"); } catch (_) { applyStyle("8"); }

  const dpad = document.getElementById("dpad");
  const allDirs = ["up", "down", "left", "right"];
  const octants = [
    ["right"],
    ["down", "right"],
    ["down"],
    ["down", "left"],
    ["left"],
    ["up", "left"],
    ["up"],
    ["up", "right"]
  ];
  const applyDirs = (next) => {
    allDirs.forEach((k) => send(k, next.has(k)));
    const up = next.has("up"), down = next.has("down"), left = next.has("left"), right = next.has("right");
    document.querySelector(".ne")?.classList.toggle("pressed", up && right);
    document.querySelector(".se")?.classList.toggle("pressed", down && right);
    document.querySelector(".sw")?.classList.toggle("pressed", down && left);
    document.querySelector(".nw")?.classList.toggle("pressed", up && left);
  };
  const fromPoint = (x, y) => {
    const r = dpad.getBoundingClientRect();
    const dx = x - (r.left + r.width / 2);
    const dy = y - (r.top + r.height / 2);
    const dist = Math.hypot(dx, dy);
    const next = new Set();
    if (dist <= r.width * 0.12) return next;
    const eightWay = document.getElementById("stage").dataset.style === "6";
    if (eightWay) {
      let deg = Math.atan2(dy, dx) * 180 / Math.PI;
      if (deg < 0) deg += 360;
      const oct = Math.round(deg / 45) % 8;
      octants[oct].forEach((k) => next.add(k));
      return next;
    }
    const adx = Math.abs(dx), ady = Math.abs(dy);
    if (adx > ady * 0.28) next.add(dx < 0 ? "left" : "right");
    if (ady > adx * 0.28) next.add(dy < 0 ? "up" : "down");
    return next;
  };
  let dpadOn = false;
  dpad.addEventListener("pointerdown", (e) => {
    e.preventDefault();
    dpadOn = true;
    dpad.setPointerCapture(e.pointerId);
    applyDirs(fromPoint(e.clientX, e.clientY));
  });
  dpad.addEventListener("pointermove", (e) => {
    if (!dpadOn) return;
    e.preventDefault();
    applyDirs(fromPoint(e.clientX, e.clientY));
  });
  const endPad = (e) => {
    e.preventDefault();
    dpadOn = false;
    applyDirs(new Set());
  };
  dpad.addEventListener("pointerup", endPad);
  dpad.addEventListener("pointercancel", endPad);

  document.addEventListener("visibilitychange", () => {
    if (document.hidden) {
      [...held.keys()].forEach((k) => send(k, false));
    }
  });
  connect();
  ["selectstart","contextmenu","copy","cut","dragstart","gesturestart"].forEach((type) => {
    document.addEventListener(type, (e) => e.preventDefault(), { passive: false });
  });
})();
</script>
</body>
</html>
"""#
}
