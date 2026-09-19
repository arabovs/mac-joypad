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
    min-height: 22px;
  }
  .brand { letter-spacing: 0.22em; font-weight: 800; font-size: 11px; }
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
    grid-template-columns: 1fr 1fr;
    gap: 12px;
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
  }
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
  .hub {
    position: absolute; width: 24%; height: 24%; left: 38%; top: 38%;
    border-radius: 50%; background: #0c1016; border: 1px solid #394155;
  }
  .mid {
    position: absolute;
    left: 50%;
    bottom: calc(min(36vw, 210px) * 0.42);
    transform: translateX(-50%);
    display: flex;
    flex-direction: row;
    gap: 10px;
    align-items: center;
    z-index: 2;
  }
  .sys {
    width: 78px; height: 26px; border: 0; border-radius: 999px;
    color: var(--muted); font-size: 8px; font-weight: 800; letter-spacing: 0.14em;
    background: linear-gradient(180deg, #2a3140, #1a2030);
    box-shadow: inset 0 1px 0 rgba(255,255,255,0.08), 0 4px 0 #0a0d13;
  }
  .sys.pressed {
    transform: translateY(3px); box-shadow: 0 1px 0 #0a0d13;
    color: #0b0d12; background: linear-gradient(180deg, #d8ff7a, var(--lime));
  }
  .sys small { display: block; font-size: 10px; letter-spacing: 0.04em; }
  .keys {
    display: grid; grid-template-rows: 1fr 1fr; gap: 9px; padding: 12px;
  }
  .row { display: grid; grid-template-columns: repeat(4, 1fr); gap: 9px; }
  .btn {
    border: 0; border-radius: 16px; color: var(--text); font-size: 17px; font-weight: 800;
    letter-spacing: 0.04em; cursor: pointer;
    -webkit-user-select: none; user-select: none; -webkit-touch-callout: none;
    -webkit-appearance: none; appearance: none;
    background: linear-gradient(180deg, #2a3140, #1a2030);
    box-shadow: inset 0 1px 0 rgba(255,255,255,0.08), 0 5px 0 #0a0d13;
    transform: translateY(0);
  }
  .btn.pressed {
    transform: translateY(4px); box-shadow: inset 0 1px 0 rgba(255,255,255,0.05), 0 1px 0 #0a0d13;
    color: #0b0d12; background: linear-gradient(180deg, #d8ff7a, var(--lime));
  }
  .btn:focus, .btn:focus-visible, .sys:focus { outline: none; }
  .btn:focus:not(.pressed) { box-shadow: inset 0 1px 0 rgba(255,255,255,0.08), 0 5px 0 #0a0d13; }
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
    <div class="pill"><span class="dot" id="dot"></span><span id="status">Connecting…</span></div>
  </header>
  <div class="stage">
    <div class="pad" id="pad">
      <div class="dpad" id="dpad">
        <div class="ring"></div>
        <div class="dir north" data-key="up">▲</div>
        <div class="dir south" data-key="down">▼</div>
        <div class="dir west" data-key="left">◀</div>
        <div class="dir east" data-key="right">▶</div>
        <div class="hub"></div>
      </div>
    </div>
    <div class="mid">
      <button class="sys btn" data-key="j">SELECT<small>J</small></button>
      <button class="sys btn" data-key="k">START<small>K</small></button>
    </div>
    <div class="keys">
      <div class="row">
        <button class="btn" data-key="q">Q</button>
        <button class="btn" data-key="w">W</button>
        <button class="btn" data-key="e">E</button>
        <button class="btn" data-key="r">R</button>
      </div>
      <div class="row">
        <button class="btn" data-key="a">A</button>
        <button class="btn" data-key="s">S</button>
        <button class="btn" data-key="d">D</button>
        <button class="btn" data-key="f">F</button>
      </div>
    </div>
  </div>
<script>
(() => {
  const held = new Map();
  let ws, ping, retry = 0;

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
    const down = (e) => { e.preventDefault(); el.setPointerCapture?.(e.pointerId); send(key, true); };
    const up = (e) => { e.preventDefault(); send(key, false); };
    el.addEventListener("pointerdown", down);
    el.addEventListener("pointerup", up);
    el.addEventListener("pointercancel", up);
    el.addEventListener("lostpointercapture", up);
  };
  document.querySelectorAll(".btn").forEach(bindButton);

  const dpad = document.getElementById("dpad");
  const allDirs = ["up", "down", "left", "right"];
  const applyDirs = (next) => {
    allDirs.forEach((k) => send(k, next.has(k)));
  };
  const fromPoint = (x, y) => {
    const r = dpad.getBoundingClientRect();
    const dx = x - (r.left + r.width / 2);
    const dy = y - (r.top + r.height / 2);
    const dist = Math.hypot(dx, dy);
    const next = new Set();
    if (dist > r.width * 0.12) {
      const adx = Math.abs(dx), ady = Math.abs(dy);
      if (adx > ady * 0.42) next.add(dx < 0 ? "left" : "right");
      if (ady > adx * 0.42) next.add(dy < 0 ? "up" : "down");
    }
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
