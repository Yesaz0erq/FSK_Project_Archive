import json, os, colorsys
OUT = "../assets/items"; os.makedirs(OUT, exist_ok=True)
items = json.load(open("../data/items.json"))["items"]
INK = "#2b1d14"
def shade(hexc, f):
    h = hexc.lstrip("#"); r, g, b = [int(h[i:i+2], 16)/255 for i in (0, 2, 4)]
    hh, l, s = colorsys.rgb_to_hls(r, g, b); l = max(0, min(1, l*f))
    r, g, b = colorsys.hls_to_rgb(hh, l, s); return "#%02x%02x%02x" % (int(r*255), int(g*255), int(b*255))
def shape(kind, c, dark, light):
    if kind == "log":
        return f'<path d="M10 42 l34 -22 q8 -2 10 6 q2 8 -4 12 l-34 22z" fill="{c}"/><ellipse cx="13" cy="50" rx="7" ry="9" fill="{light}" transform="rotate(-30 13 50)"/><path d="M10 50 q3 -3 6 0" fill="none" stroke="{dark}" stroke-width="1.6"/><path d="M26 40 l14 -9" stroke="{dark}" stroke-width="1.6"/><path d="M40 20 q2 -8 10 -10" fill="none" stroke="#6b7f3a" stroke-width="2.4"/>'
    if kind == "drop":
        return f'<path d="M32 6 q-20 26 -20 36 a20 18 0 0 0 40 0 q0 -10 -20 -36z" fill="{c}"/><path d="M22 40 q0 -8 6 -14" fill="none" stroke="{light}" stroke-width="3"/>'
    if kind == "pile":
        return f'<path d="M6 54 q8 -30 26 -36 q18 6 26 36z" fill="{c}"/><path d="M18 40 h2 M30 32 h2 M40 44 h2 M26 48 h2 M44 36 h1" stroke="{dark}" stroke-width="2.4"/><path d="M24 28 q6 -4 10 -2" fill="none" stroke="{light}" stroke-width="2"/>'
    if kind == "crystal":
        return f'<path d="M18 54 l-4 -22 l10 -20 l8 22z M30 56 l2 -36 l10 -14 l8 18 l-6 32z M44 56 l6 -18 l8 6 l-2 12z" fill="{c}"/><path d="M36 22 l4 26 M22 18 l4 16" fill="none" stroke="{light}" stroke-width="2"/>'
    if kind == "rock":
        return f'<path d="M10 44 q-2 -20 16 -28 q20 -6 28 10 q8 18 -6 28 q-24 8 -38 -10z" fill="{c}"/><path d="M22 28 l6 8 l10 -4 M38 40 l8 2" fill="none" stroke="{dark}" stroke-width="2"/><circle cx="34" cy="24" r="3" fill="{light}" stroke-width="1.4"/><circle cx="20" cy="42" r="2.4" fill="{light}" stroke-width="1.2"/>'
    if kind == "pod":
        return f'<path d="M32 58 q-22 -10 -16 -34 q6 -18 16 -18 q10 0 16 18 q6 24 -16 34z" fill="{c}"/><path d="M32 8 q-6 22 0 48 M22 22 q8 6 20 0" fill="none" stroke="{dark}" stroke-width="1.8"/><path d="M32 8 q4 -6 10 -4" fill="none" stroke="#6b7f3a" stroke-width="2.4"/>'
    if kind == "ingot":
        return f'<path d="M8 44 l10 -16 h32 l8 16z" fill="{c}"/><path d="M18 28 l4 -6 h24 l4 6z" fill="{light}"/><path d="M8 44 h50 v6 h-50z" fill="{dark}"/>'
    if kind == "pane":
        return f'<path d="M14 10 h36 v44 h-36z" fill="{c}" fill-opacity="0.85"/><path d="M14 10 h36 v44 h-36z M32 10 v44 M14 32 h36" fill="none" stroke="#7a5a3c" stroke-width="3"/><path d="M18 26 l8 -10" stroke="#ffffff" stroke-width="2"/>'
    if kind == "coil":
        return f'<path d="M12 46 q20 -40 40 -20 q-20 -20 -30 10 q10 -24 26 -2 q-14 -14 -22 6" fill="none" stroke="{INK}" stroke-width="7"/><path d="M12 46 q20 -40 40 -20 q-20 -20 -30 10 q10 -24 26 -2 q-14 -14 -22 6" fill="none" stroke="{c}" stroke-width="3.5"/><path d="M50 26 q6 -6 4 -14" fill="none" stroke="#6b7f3a" stroke-width="2.4"/><path d="M54 12 q6 0 6 6 q-6 0 -6 -6z" fill="#8aa04a" stroke-width="1.4"/>'
    if kind == "gear":
        teeth = "".join(f'<rect x="28" y="4" width="8" height="10" rx="1.5" fill="{c}" transform="rotate({a} 32 32)" stroke-width="2"/>' for a in range(0, 360, 45))
        return teeth + f'<circle cx="32" cy="32" r="20" fill="{c}"/><circle cx="32" cy="32" r="7" fill="{dark}"/><path d="M20 26 q4 -6 10 -8" fill="none" stroke="{light}" stroke-width="2"/>'
    if kind == "lens":
        return f'<circle cx="32" cy="32" r="22" fill="#c9963f"/><circle cx="32" cy="32" r="16" fill="{c}"/><path d="M22 28 q4 -8 12 -10" fill="none" stroke="#ffffff" stroke-width="3"/><path d="M50 50 l8 8" stroke="{INK}" stroke-width="6"/><path d="M50 50 l8 8" stroke="#7a5a3c" stroke-width="3"/>'
    if kind == "orb":
        return f'<circle cx="32" cy="32" r="26" fill="#ffcf6b" fill-opacity="0.35" stroke="none"/><path d="M32 54 q-16 0 -18 -16 q8 -2 18 8 q10 -10 18 -8 q-2 16 -18 16z" fill="#c9963f"/><circle cx="32" cy="30" r="13" fill="{c}"/><path d="M26 26 q3 -4 7 -4" fill="none" stroke="#ffffff" stroke-width="2.4"/><path d="M32 17 q-8 -8 -2 -12 q4 4 2 12 q4 -8 10 -6 q-2 6 -10 6" fill="#e49aa8" stroke-width="1.6"/>'
    return f'<circle cx="32" cy="32" r="18" fill="{c}"/>'
for iid, it in items.items():
    c = it["color"]
    body = shape(it.get("icon", "orb"), c, shade(c, 0.6), shade(c, 1.35))
    open(f"{OUT}/{iid}.svg", "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><g stroke="{INK}" stroke-width="2.6" stroke-linejoin="round" stroke-linecap="round">{body}</g></svg>')
open(f"{OUT}/_fallback.svg", "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><circle cx="32" cy="32" r="18" fill="#a08060" stroke="{INK}" stroke-width="2.6"/></svg>')
print(len(items))
