import os
OUT = "../assets/machines"
os.makedirs(OUT, exist_ok=True)
INK = "#2b1d14"
def svg(body, w=256, h=320):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
<defs>
<radialGradient id="glow" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#fff2b0" stop-opacity="0.95"/><stop offset="0.45" stop-color="#ffb84a" stop-opacity="0.55"/><stop offset="1" stop-color="#ff8a3c" stop-opacity="0"/></radialGradient>
<linearGradient id="brass" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#a8762e"/><stop offset="0.45" stop-color="#e3bb6a"/><stop offset="1" stop-color="#8a5f26"/></linearGradient>
<linearGradient id="rust" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#b8703f"/><stop offset="1" stop-color="#7a3f24"/></linearGradient>
<linearGradient id="wood" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#6a4a2e"/><stop offset="0.5" stop-color="#a07a4f"/><stop offset="1" stop-color="#5c3f27"/></linearGradient>
<linearGradient id="leaf" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#c3d36a"/><stop offset="1" stop-color="#5f7a34"/></linearGradient>
<linearGradient id="clay" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#d49a68"/><stop offset="1" stop-color="#8a5636"/></linearGradient>
<linearGradient id="verd" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#4f7a68"/><stop offset="0.5" stop-color="#8ab8a0"/><stop offset="1" stop-color="#466c5c"/></linearGradient>
<linearGradient id="gourd" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#9a5a22"/><stop offset="0.4" stop-color="#e2a24a"/><stop offset="1" stop-color="#8a4a1c"/></linearGradient>
<linearGradient id="pitcher" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#b24a3a"/><stop offset="0.45" stop-color="#9aa64a"/><stop offset="1" stop-color="#5a7a34"/></linearGradient>
<linearGradient id="petal" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f2b0b8"/><stop offset="1" stop-color="#b8605a"/></linearGradient>
<linearGradient id="fire" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff1a8"/><stop offset="0.5" stop-color="#ffb347"/><stop offset="1" stop-color="#e2582a"/></linearGradient>
</defs>
<ellipse cx="128" cy="300" rx="92" ry="14" fill="#140d0a" opacity="0.28"/>
<g stroke="{INK}" stroke-width="3.5" stroke-linejoin="round" stroke-linecap="round">
{body}
</g>
</svg>'''

def rivets(pts, r=2.6, fill="#e3bb6a"):
    return "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke-width="1.5"/>' for x, y in pts)
def moss(x, y, s=1.0):
    return (f'<path d="M{x-14*s} {y} q{4*s} {-10*s} {10*s} {-6*s} q{4*s} {-9*s} {11*s} {-3*s} q{7*s} {-5*s} {10*s} {4*s} q{6*s} {0} {5*s} {5*s}z" fill="#6b7f3a" stroke-width="2"/>'
            f'<path d="M{x-8*s} {y-4*s} q4 -4 8 -2" fill="none" stroke="#9fb35a" stroke-width="1.6"/>')
def leaf(x, y, ang, s=1.0, fill="url(#leaf)"):
    return (f'<g transform="translate({x} {y}) rotate({ang}) scale({s})"><path d="M0 0 C 10 -14 34 -16 48 0 C 34 14 10 14 0 0z" fill="{fill}"/>'
            f'<path d="M2 0 L44 0 M14 0 l8 -6 M26 0 l8 -6 M14 0 l8 6 M26 0 l8 6" fill="none" stroke-width="1.6" stroke="#3d4a20"/></g>')
def sprout(x, y, s=1.0):
    return (f'<path d="M{x} {y} q{-2*s} {-14*s} {2*s} {-24*s}" fill="none" stroke-width="3"/>' + leaf(x+2*s, y-24*s, -150, 0.45*s) + leaf(x+2*s, y-22*s, -30, 0.5*s))
def drops(pts, fill="#9fd0e8"):
    return "".join(f'<path d="M{x} {y} q-5 8 0 11 q5 -3 0 -11z" fill="{fill}" stroke-width="1.6"/>' for x, y in pts)
def roots(x, y, w):
    return (f'<path d="M{x-w} {y+6} q{w*0.3} -14 {w*0.55} -10 M{x+w} {y+6} q{-w*0.3} -16 {-w*0.55} -11 M{x-w*0.5} {y+12} q6 -12 14 -14 M{x+w*0.45} {y+13} q-6 -12 -13 -15" fill="none" stroke="#5c3f27" stroke-width="7"/>'
            f'<path d="M{x-w} {y+6} q{w*0.3} -14 {w*0.55} -10 M{x+w} {y+6} q{-w*0.3} -16 {-w*0.55} -11" fill="none" stroke="#a07a4f" stroke-width="2"/>')

M = {}

# 1 Taproot Drill ----------------------------------------------------------
M["taproot_drill"] = (
    roots(128, 282, 96) +
    '<ellipse cx="128" cy="276" rx="70" ry="20" fill="#4a3424"/>'
    '<path d="M58 270 a70 20 0 0 0 140 0 v-18 a70 20 0 0 1 -140 0z" fill="url(#brass)"/>'
    '<ellipse cx="128" cy="252" rx="70" ry="20" fill="#d9ad5c"/>'
    '<ellipse cx="128" cy="252" rx="40" ry="11" fill="#3a2a1e"/>' +
    rivets([(70, 262), (92, 270), (128, 274), (164, 270), (186, 262)]) +
    # twisted root auger
    '<path d="M110 252 q18 -12 36 0 q-18 -14 -32 -28 q22 -6 30 -18 q-20 0 -30 -22 q18 -4 26 -16 l-12 -6 q-14 10 -26 14 q6 14 22 22 q-14 10 -28 14 q8 14 26 22 q-20 8 -12 18z" fill="#7a5233"/>'
    '<path d="M118 240 q10 -6 22 -8 M120 214 q8 -4 18 -10 M122 186 q8 -2 14 -8" fill="none" stroke="#c49a66" stroke-width="2"/>'
    # barrel body on stilts
    '<path d="M70 190 l-6 60 M186 190 l6 60" fill="none" stroke="#5c3f27" stroke-width="9"/>'
    '<path d="M70 190 l-6 60 M186 190 l6 60" fill="none" stroke="#a07a4f" stroke-width="2.5"/>'
    '<path d="M72 92 q-10 50 0 100 h112 q10 -50 0 -100z" fill="url(#wood)"/>'
    '<path d="M96 96 q-6 46 0 92 M128 94 v98 M160 96 q6 46 0 92" fill="none" stroke="#4a321e" stroke-width="2"/>'
    '<path d="M68 112 h120 v12 h-120z M66 160 h124 v12 h-124z" fill="url(#rust)"/>' +
    rivets([(76, 118), (100, 118), (128, 118), (156, 118), (180, 118), (76, 166), (128, 166), (180, 166)], 2.2) +
    # porthole
    '<circle cx="128" cy="142" r="15" fill="url(#brass)"/><circle cx="128" cy="142" r="9" fill="#ffcf6b"/><path d="M123 138 q4 -3 8 0" fill="none" stroke="#fff4c8" stroke-width="2"/>'
    # crank wheel
    '<circle cx="196" cy="140" r="20" fill="none" stroke-width="5" stroke="#5c3f27"/><circle cx="196" cy="140" r="20" fill="none" stroke="#c9963f" stroke-width="2"/>'
    '<path d="M196 120 v40 M176 140 h40" stroke="#5c3f27" stroke-width="4"/><circle cx="196" cy="140" r="5" fill="#c9963f"/>'
    '<path d="M214 128 l12 -10" stroke-width="5"/><circle cx="228" cy="116" r="5" fill="#b0673a"/>'
    # lid + exhaust funnel
    '<path d="M66 92 q62 -26 124 0 q-62 10 -124 0z" fill="#8a4b2a"/>'
    '<path d="M150 82 q4 -30 22 -44 q10 -8 20 -4" fill="none" stroke="#2b1d14" stroke-width="12"/>'
    '<path d="M150 82 q4 -30 22 -44 q10 -8 20 -4" fill="none" stroke="#6f9a86" stroke-width="6"/>'
    '<path d="M186 22 l22 -8 l2 32 l-22 -6z" fill="url(#verd)"/>'
    '<circle cx="100" cy="78" r="11" fill="#e8d9b5"/><path d="M100 78 l6 -5" stroke-width="2"/><circle cx="100" cy="78" r="2" fill="#2b1d14"/>' +
    sprout(124, 80, 1.1) + moss(84, 112, 0.9) + moss(176, 192, 0.8)
)

# 2 Pitcher Still ----------------------------------------------------------
M["pitcher_still"] = (
    '<path d="M128 214 L80 292 M128 214 L176 292 M128 214 L128 296" fill="none" stroke="#2b1d14" stroke-width="9"/>'
    '<path d="M128 214 L80 292 M128 214 L176 292 M128 214 L128 296" fill="none" stroke="#c07a46" stroke-width="4"/>' +
    rivets([(80, 292), (176, 292), (128, 296)], 4, "#8a4b2a") +
    '<path d="M88 266 q-18 -10 -8 -30 q10 -16 -2 -30" fill="none" stroke="#5f7a34" stroke-width="4"/>' + leaf(80, 236, -160, 0.45) + leaf(86, 214, -120, 0.4) +
    # glass jar
    '<path d="M110 254 q-4 30 4 40 h28 q8 -10 4 -40z" fill="#a8d8d0" fill-opacity="0.75"/><path d="M112 274 q16 6 32 0 v14 q-16 6 -32 0z" fill="#6fa8c8"/>'
    '<path d="M106 252 h44 v6 h-44z" fill="url(#brass)"/>' +
    # pitcher body
    '<path d="M128 214 q-46 -6 -50 -60 q-4 -48 18 -80 q-8 -10 -6 -18 q38 -12 76 0 q2 8 -6 18 q22 32 18 80 q-4 54 -50 60z" fill="url(#pitcher)"/>'
    '<path d="M104 80 q-14 50 -2 110 M128 74 v132 M152 80 q14 50 2 110" fill="none" stroke="#5a2a20" stroke-width="2" opacity="0.6"/>'
    '<path d="M90 56 q38 -14 76 0 q-6 10 -38 10 q-32 0 -38 -10z" fill="#d06a4a"/>'
    '<path d="M94 58 q34 -8 68 0" fill="none" stroke="#f0b090" stroke-width="2"/>'
    # lid leaf
    '<path d="M150 50 q30 -40 66 -30 q-10 34 -60 36z" fill="#b84a3a"/><path d="M156 48 q24 -18 52 -24" fill="none" stroke="#f0a080" stroke-width="2"/>'
    '<path d="M98 120 q4 -6 8 0 M146 138 q4 -6 8 0 M114 168 q4 -6 8 0" fill="none" stroke="#f2d2a0" stroke-width="2"/>'
    # brass collar & tap
    '<path d="M96 196 q32 14 64 0 v12 q-32 14 -64 0z" fill="url(#brass)"/>' + rivets([(104, 204), (128, 210), (152, 204)], 2.2) +
    '<path d="M128 214 v22 h10" fill="none" stroke-width="8" stroke="#2b1d14"/><path d="M128 214 v22 h10" fill="none" stroke="#c9963f" stroke-width="4"/>'
    '<circle cx="128" cy="226" r="6" fill="#b0673a"/>' + drops([(132, 246)]) + moss(110, 202, 0.7)
)

# 3 Leafwing Turbine -------------------------------------------------------
blades = "".join(f'<g transform="translate(128 82) rotate({a})"><path d="M0 0 C 18 -16 64 -26 98 -6 C 70 10 22 14 0 0z" fill="url(#leaf)"/><path d="M4 0 Q 50 -8 92 -6" fill="none" stroke="#3d4a20" stroke-width="2"/><path d="M30 -4 l10 -8 M50 -6 l10 -8 M30 -3 l8 7 M52 -5 l8 7" fill="none" stroke="#3d4a20" stroke-width="1.6"/></g>' for a in (-35, 55, 145, 235))
M["leafwing_turbine"] = (
    # crate base
    '<path d="M74 236 h108 v56 h-108z" fill="url(#wood)"/><path d="M74 236 l108 56 M182 236 l-108 56" fill="none" stroke="#4a321e" stroke-width="3"/>'
    '<path d="M70 230 h116 v10 h-116z" fill="#8a4b2a"/>' + rivets([(78, 244), (178, 244), (78, 286), (178, 286)], 2.4) +
    # bamboo stalk
    '<path d="M118 236 q-4 -70 2 -150 h16 q6 80 2 150z" fill="#b6b05a"/>'
    '<path d="M118 200 h20 M117 160 h20 M118 120 h20" stroke-width="3"/>'
    '<path d="M124 232 q-2 -70 2 -144" fill="none" stroke="#e8e0a0" stroke-width="2"/>' +
    leaf(138, 184, -20, 0.5) + leaf(118, 150, 200, 0.45) +
    # copper vine down
    '<path d="M150 98 q24 30 4 60 q-18 30 8 56 q14 14 6 22" fill="none" stroke="#2b1d14" stroke-width="6"/><path d="M150 98 q24 30 4 60 q-18 30 8 56 q14 14 6 22" fill="none" stroke="#d08a55" stroke-width="2.5"/>' +
    blades +
    # tin can dynamo
    '<path d="M100 66 h56 v34 h-56z" fill="url(#verd)"/><ellipse cx="128" cy="66" rx="28" ry="7" fill="#9ac8b0"/>'
    '<path d="M100 76 h56 M100 88 h56" fill="none" stroke="#3d5a4c" stroke-width="1.8"/>' + rivets([(104, 96), (152, 96)], 2) +
    '<circle cx="128" cy="82" r="12" fill="url(#brass)"/><circle cx="128" cy="82" r="5" fill="#ffcf6b"/>'
    # tail leaf
    '<path d="M156 78 h40" stroke-width="4"/>' + leaf(194, 78, -10, 0.6, "#8aa04a") +
    moss(96, 232, 0.8) + sprout(168, 232, 0.7)
)

# 4 Seedpod Kiln -----------------------------------------------------------
M["seedpod_kiln"] = (
    roots(128, 284, 80) +
    '<path d="M128 290 q-74 -6 -76 -82 q-2 -70 50 -110 q26 -18 52 0 q52 40 50 110 q-2 76 -76 82z" fill="url(#clay)"/>'
    '<path d="M86 132 q-22 50 -10 120 M170 132 q22 50 10 120" fill="none" stroke="#6a3c22" stroke-width="2" opacity="0.7"/>'
    '<path d="M70 176 q14 4 20 -4 M176 210 q10 6 18 -2 M86 240 q10 2 12 -6" fill="none" stroke="#f0c090" stroke-width="2"/>' +
    # acorn cap
    '<path d="M86 112 q42 -48 84 0 q-42 14 -84 0z" fill="#7a5a3c"/>'
    '<path d="M96 104 l8 -10 M110 98 l6 -12 M126 96 v-12 M140 98 l4 -12 M154 104 l6 -10 M100 110 l10 -6 M120 104 l8 -6 M140 106 l8 -6" fill="none" stroke="#3e2a1a" stroke-width="2"/>'
    # chimney stem
    '<path d="M122 76 q-4 -20 6 -40 h12 q-8 20 -4 40z" fill="url(#rust)"/><path d="M124 36 h20 v6 h-20z" fill="#5c3f27"/>'
    '<path d="M140 30 q-14 -8 -4 -18 q-10 -12 6 -16 q18 2 14 14 q12 8 0 18z" fill="#c8c0b4" fill-opacity="0.8" stroke-width="2"/>' +
    # door
    '<circle cx="128" cy="210" r="38" fill="url(#rust)"/><circle cx="128" cy="210" r="28" fill="#3a2418"/>'
    '<path d="M110 202 h36 M108 212 h40 M112 222 h32" stroke="#ffb347" stroke-width="5"/>'
    '<circle cx="128" cy="210" r="30" fill="url(#glow)" stroke="none" opacity="0.8"/>' +
    rivets([(128, 174), (162, 196), (162, 224), (128, 246), (94, 224), (94, 196)], 2.6) +
    '<path d="M166 210 h14 q8 0 8 8" fill="none" stroke-width="5"/><circle cx="188" cy="222" r="5" fill="#c9963f"/>'
    + moss(92, 148, 1.0) + moss(170, 268, 0.8) + leaf(160, 100, -40, 0.45) + leaf(94, 98, 210, 0.4)
)

# 5 Spore Garden -----------------------------------------------------------
M["spore_garden"] = (
    '<path d="M80 262 l-8 30 M180 262 l8 30" stroke-width="6"/><circle cx="72" cy="294" r="6" fill="#c9963f"/><circle cx="188" cy="294" r="6" fill="#c9963f"/>'
    # small barrel and pipe
    '<path d="M196 160 h44 v80 h-44z" fill="url(#wood)"/><path d="M194 176 h48 v8 h-48z M194 216 h48 v8 h-48z" fill="#8a4b2a"/>'
    '<path d="M212 160 q0 -40 -50 -46 q-30 -2 -40 18" fill="none" stroke="#2b1d14" stroke-width="11"/><path d="M212 160 q0 -40 -50 -46 q-30 -2 -40 18" fill="none" stroke="#c07a46" stroke-width="5"/>' +
    drops([(118, 142), (124, 160)]) +
    # mushrooms behind
    '<path d="M98 214 q-2 -60 6 -86 h12 q4 30 2 86z" fill="#efe2c4"/>'
    '<path d="M70 132 q40 -54 84 0 q-42 12 -84 0z" fill="#b8604a"/>' + rivets([(92, 118), (112, 110), (132, 116), (102, 128)], 4, "#f2d2b0") +
    '<path d="M150 220 q0 -40 6 -60 h10 q4 24 2 60z" fill="#efe2c4"/>'
    '<path d="M134 164 q26 -36 56 0 q-28 8 -56 0z" fill="#d9a05a"/>'
    '<circle cx="76" cy="206" r="20" fill="#e8dcc0"/><circle cx="70" cy="200" r="4" fill="#fff" stroke="none"/>'
    '<circle cx="182" cy="212" r="16" fill="#e0d2b0"/>'
    # tub
    '<path d="M58 210 h140 q-6 58 -70 58 q-64 0 -70 -58z" fill="url(#verd)"/>'
    '<path d="M54 204 h148 v12 h-148z" fill="#e8d9b5"/>'
    '<path d="M90 236 q8 4 14 -2 M150 244 q8 2 12 -6" fill="none" stroke="#8a4b2a" stroke-width="3"/>' +
    rivets([(68, 222), (188, 222), (128, 262)], 2.4) +
    # floating spores
    "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#efe2c4" stroke-width="1.4"/>' for x, y, r in [(60, 96, 4), (152, 82, 3), (174, 120, 5), (44, 150, 3), (128, 70, 3)]) +
    moss(108, 206, 0.9) + leaf(198, 196, 20, 0.45)
)

# 6 Vine Loom --------------------------------------------------------------
M["vine_loom"] = (
    '<path d="M60 292 L104 60 M196 292 L152 60" fill="none" stroke="#2b1d14" stroke-width="16"/>'
    '<path d="M60 292 L104 60 M196 292 L152 60" fill="none" stroke="#a07a4f" stroke-width="10"/>'
    '<path d="M92 62 h72 v14 h-72z M74 210 h108 v12 h-108z" fill="url(#wood)"/>'
    # big wooden cog
    '<g transform="translate(128 142)">' + "".join(f'<rect x="-8" y="-60" width="16" height="18" rx="2" fill="#b88a4e" transform="rotate({a})"/>' for a in range(0, 360, 30)) +
    '<circle r="48" fill="#b88a4e"/><circle r="34" fill="#8a6038"/><circle r="12" fill="url(#brass)"/>'
    '<path d="M0 -34 v68 M-34 0 h68 M-24 -24 l48 48 M24 -24 l-48 48" stroke="#5c3f27" stroke-width="5"/><circle r="8" fill="#ffcf6b"/></g>'
    # vines
    '<path d="M70 280 q30 -40 10 -80 q-20 -40 30 -80 q30 -24 20 -60" fill="none" stroke="#2b1d14" stroke-width="8"/>'
    '<path d="M70 280 q30 -40 10 -80 q-20 -40 30 -80 q30 -24 20 -60" fill="none" stroke="#6b8a3a" stroke-width="4"/>'
    '<path d="M190 280 q-26 -30 -6 -70 q16 -36 -20 -64" fill="none" stroke="#2b1d14" stroke-width="8"/>'
    '<path d="M190 280 q-26 -30 -6 -70 q16 -36 -20 -64" fill="none" stroke="#6b8a3a" stroke-width="4"/>' +
    leaf(84, 196, 200, 0.5) + leaf(108, 116, -60, 0.45) + leaf(184, 214, -20, 0.5) + leaf(168, 150, 40, 0.42) + leaf(130, 60, -100, 0.4) +
    # shuttle & threads
    '<path d="M86 226 l84 0" stroke="#d08a55" stroke-width="2"/><path d="M96 232 l64 0" stroke="#d08a55" stroke-width="2"/>'
    '<path d="M110 236 q18 -10 36 0 q-18 10 -36 0z" fill="url(#brass)"/>'
    # hanging lamp
    '<path d="M164 76 v20" stroke-width="2.5"/><path d="M156 96 h16 l-2 16 h-12z" fill="url(#brass)"/><circle cx="164" cy="106" r="16" fill="url(#glow)" stroke="none"/>' +
    moss(104, 72, 0.8)
)

# 7 Gourd Kettle -----------------------------------------------------------
M["gourd_kettle"] = (
    # brick hearth
    '<path d="M64 244 h128 v50 h-128z" fill="#8a4a32"/>'
    '<path d="M64 260 h128 M64 276 h128 M90 244 v16 M130 244 v16 M170 244 v16 M110 260 v16 M150 260 v16 M90 276 v18 M130 276 v18 M170 276 v18" fill="none" stroke="#4a2418" stroke-width="2"/>'
    '<path d="M106 294 q0 -26 22 -26 q22 0 22 26z" fill="#2a1810"/><path d="M114 294 q4 -20 14 -18 q10 -2 14 18z" fill="url(#fire)" stroke-width="2"/>'
    '<circle cx="128" cy="284" r="22" fill="url(#glow)" stroke="none"/>'
    # gourd
    '<path d="M128 250 q-70 0 -70 -60 q0 -46 44 -58 q-10 -30 10 -52 q16 -14 32 0 q20 22 10 52 q44 12 44 58 q0 60 -70 60z" fill="url(#gourd)"/>'
    '<path d="M98 140 q-24 50 -6 106 M158 140 q24 50 6 106 M128 134 v114" fill="none" stroke="#7a3a14" stroke-width="2" opacity="0.6"/>'
    '<path d="M60 190 q68 20 136 0 v12 q-68 20 -136 0z M100 120 q28 10 56 0 v10 q-28 10 -56 0z" fill="url(#rust)"/>' +
    rivets([(70, 198), (98, 205), (128, 208), (158, 205), (186, 198), (110, 128), (146, 128)], 2.4) +
    # stem cap
    '<path d="M122 32 q4 -18 18 -22" fill="none" stroke="#5c3f27" stroke-width="7"/>' + leaf(130, 30, -20, 0.45) +
    # reed spout + whistle
    '<path d="M180 168 q40 -8 44 -52" fill="none" stroke="#2b1d14" stroke-width="13"/><path d="M180 168 q40 -8 44 -52" fill="none" stroke="#c9b86a" stroke-width="7"/>'
    '<path d="M216 116 h16 v-14 h-16z" fill="url(#brass)"/>'
    '<path d="M222 96 q-12 -10 0 -20 q-6 -14 10 -14 q16 0 10 14 q12 10 -2 20z" fill="#e8e4dc" fill-opacity="0.85" stroke-width="2"/>'
    # gauge
    '<circle cx="96" cy="166" r="14" fill="url(#brass)"/><circle cx="96" cy="166" r="9" fill="#e8d9b5"/><path d="M96 166 l5 -6" stroke-width="2"/>'
    + moss(150, 132, 0.8) + moss(176, 240, 0.7)
)

# 8 Ember Lily -------------------------------------------------------------
petals = "".join(f'<g transform="translate(128 112) rotate({a})"><path d="M0 0 C -14 -16 -10 -42 0 -54 C 10 -42 14 -16 0 0z" fill="url(#fire)"/><path d="M0 -6 V-46" fill="none" stroke="#c0402a" stroke-width="1.6"/></g>' for a in (-70, -35, 0, 35, 70))
M["ember_lily"] = (
    '<circle cx="128" cy="108" r="96" fill="url(#glow)" stroke="none" opacity="0.75"/>'
    # pedestal of twisted stems
    '<path d="M104 292 q10 -60 18 -110 M152 292 q-10 -60 -18 -110 M128 296 v-120" fill="none" stroke="#2b1d14" stroke-width="10"/>'
    '<path d="M104 292 q10 -60 18 -110 M152 292 q-10 -60 -18 -110 M128 296 v-120" fill="none" stroke="#6b8a3a" stroke-width="5"/>' +
    leaf(110, 238, 200, 0.6) + leaf(146, 220, -20, 0.6) +
    '<path d="M92 290 h72 v8 h-72z" fill="url(#brass)"/>'
    # cage
    '<path d="M76 176 h104 v10 h-104z" fill="url(#brass)"/>'
    '<path d="M84 176 q-12 -70 44 -122 q56 52 44 122" fill="none" stroke="#2b1d14" stroke-width="7"/>'
    '<path d="M84 176 q-12 -70 44 -122 q56 52 44 122" fill="none" stroke="#c9963f" stroke-width="3"/>'
    '<path d="M106 176 q-4 -66 22 -120 M150 176 q4 -66 -22 -120" fill="none" stroke="#c9963f" stroke-width="3"/>' +
    petals +
    '<circle cx="128" cy="112" r="14" fill="#fff2b0"/>' +
    "".join(f'<path d="M128 112 l{x} {y}" stroke="#7a3a14" stroke-width="2"/><circle cx="{128+x}" cy="{112+y}" r="3" fill="#ffcf6b" stroke-width="1.4"/>' for x, y in [(-10, -22), (0, -26), (10, -22)]) +
    '<path d="M122 54 v-20 h12 v20" fill="url(#brass)"/><circle cx="128" cy="28" r="7" fill="none" stroke-width="3"/>' + moss(120, 180, 0.7)
)

# 9 Mist Fern --------------------------------------------------------------
def frond(x, y, ang, length, s=1.0):
    pinnae = "".join(f'<path d="M{i} 0 q4 -{12*s - i*0.06} 12 -{14*s - i*0.08} q-2 8 -12 14 M{i} 0 q4 {12*s - i*0.06} 12 {14*s - i*0.08} q-2 -8 -12 -14" fill="#7a9a3e" stroke-width="1.6"/>' for i in range(8, length - 6, 11))
    return f'<g transform="translate({x} {y}) rotate({ang})"><path d="M0 0 Q {length/2} -6 {length} 0" fill="none" stroke-width="4"/>{pinnae}</g>'
M["mist_fern"] = (
    frond(128, 160, -120, 130) + frond(128, 160, -60, 130) + frond(128, 162, -150, 110) + frond(128, 162, -30, 110) + frond(128, 156, -90, 120) +
    '<path d="M128 70 q-14 -2 -14 -14 q0 -12 12 -12 q8 0 8 8 q0 6 -6 6" fill="none" stroke-width="5" stroke="#2b1d14"/><path d="M128 70 q-14 -2 -14 -14 q0 -12 12 -12 q8 0 8 8 q0 6 -6 6" fill="none" stroke="#9ab84a" stroke-width="2.5"/>'
    # pot
    '<path d="M78 236 h100 l-12 58 h-76z" fill="url(#clay)"/><path d="M72 228 h112 v14 h-112z" fill="#8a4b2a"/>'
    '<path d="M96 262 q14 6 26 -2 M136 276 q10 4 18 -4" fill="none" stroke="#f0c090" stroke-width="2"/>'
    # bellows heart
    '<path d="M98 228 q-6 -36 30 -62 q36 26 30 62z" fill="#8a5a3c"/>'
    '<path d="M100 214 q28 -8 56 0 M102 200 q26 -8 52 0 M108 186 q20 -8 40 0" fill="none" stroke="#c4946a" stroke-width="2.5"/>'
    '<path d="M110 228 h36 v-6 h-36z" fill="url(#brass)"/>'
    # nozzle + mist
    '<path d="M158 206 q24 -4 34 -20" fill="none" stroke="#2b1d14" stroke-width="10"/><path d="M158 206 q24 -4 34 -20" fill="none" stroke="#6f9a86" stroke-width="5"/>'
    '<path d="M188 188 l14 -12 l6 8 l-14 10z" fill="url(#brass)"/>' +
    "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#cfeaf2" fill-opacity="0.8" stroke-width="1.2"/>' for x, y, r in [(214, 166, 5), (226, 156, 4), (220, 144, 6), (236, 140, 3), (208, 150, 3), (232, 172, 3)]) +
    moss(96, 234, 0.8)
)

# 10 Bloom Press -----------------------------------------------------------
bpetals = "".join(f'<g transform="translate(128 112) rotate({a})"><path d="M0 0 C -30 -14 -36 -64 0 -92 C 36 -64 30 -14 0 0z" fill="url(#petal)"/><path d="M0 -8 V-80 M-12 -30 q12 6 24 0 M-14 -54 q14 6 28 0" fill="none" stroke="#7a3a34" stroke-width="2"/>' + rivets([(0, -84), (-16, -50), (16, -50)], 2.2, "#e3bb6a") + '</g>' for a in (-80, -40, 40, 80))
M["bloom_press"] = (
    # base housing with gears
    '<path d="M60 248 h136 l-10 46 h-116z" fill="url(#rust)"/><path d="M56 240 h144 v12 h-144z" fill="url(#brass)"/>' +
    rivets([(66, 262), (190, 262), (80, 286), (176, 286)], 2.6) +
    '<g transform="translate(92 272)">' + "".join(f'<rect x="-4" y="-18" width="8" height="8" fill="#c9963f" transform="rotate({a})" stroke-width="1.6"/>' for a in range(0, 360, 45)) + '<circle r="13" fill="#c9963f" stroke-width="2.4"/><circle r="4" fill="#2b1d14"/></g>'
    '<path d="M150 262 h30 v22 h-30z" fill="#3a2418"/><path d="M154 268 h22 M154 276 h22" stroke="#ffb347" stroke-width="3"/>'
    # stem
    '<path d="M118 240 q-6 -60 2 -110 h16 q8 50 2 110z" fill="url(#verd)"/>'
    '<path d="M116 200 h24 M116 168 h24" stroke-width="3"/>' +
    leaf(118, 214, 200, 0.85, "url(#brass)") + leaf(138, 190, -22, 0.85, "url(#brass)") +
    # lever
    '<path d="M196 246 l22 -60" stroke-width="6"/><circle cx="220" cy="182" r="8" fill="#b0673a"/>'
    '<circle cx="128" cy="112" r="72" fill="url(#glow)" stroke="none" opacity="0.7"/>' +
    bpetals +
    '<g transform="translate(128 112) rotate(0)"><path d="M0 0 C -30 -14 -36 -64 0 -92 C 36 -64 30 -14 0 0z" fill="url(#petal)"/><path d="M0 -8 V-80" fill="none" stroke="#7a3a34" stroke-width="2"/></g>'
    '<circle cx="128" cy="112" r="26" fill="url(#brass)"/><circle cx="128" cy="112" r="17" fill="#f0a0b8"/>'
    '<circle cx="128" cy="112" r="17" fill="url(#glow)" stroke="none"/><path d="M120 104 q6 -5 12 0" fill="none" stroke="#fff" stroke-width="2.5"/>' +
    moss(80, 248, 0.9) + sprout(176, 240, 0.8)
)

M["_fallback"] = '<circle cx="128" cy="200" r="70" fill="url(#clay)"/>' + sprout(128, 132, 1.4)

for k, body in M.items():
    open(os.path.join(OUT, k + ".svg"), "w").write(svg(body))
print("wrote", len(M))
