#!/usr/bin/env bash
# Render the brand skin against the REAL booking page, without a build.
#
# Why this exists: Docker and Elixir are not installed on the machine this fork
# is developed on, so `mix phx.server` is not available and the skin cannot be
# checked the obvious way. But the skin's whole job is to override a stylesheet
# we do not control, and every failure mode is visual — a selector that no
# longer matches, a colour that loses the cascade, white text on a cream card.
# Reasoning about those in the abstract is exactly how they ship.
#
# So: pull the live page's own markup and its compiled theme stylesheet, point
# every asset back at the origin, drop the LiveView bundles (no server here),
# and link the skin last — the same order scheduling_root.html.heex produces.
# What renders is what production renders, minus interactivity.
#
# Found this way, after the static audit had already passed: the page has no
# background at all (only .video-background-container is painted, sized to
# content); "selected" on a day or time slot degraded to a thin border once the
# palette went light; the primary CTA was styled identically to Back; and four
# rules put white text on the cream payment and awaiting-payment cards.
#
#   ./dev/skinlab.sh && open http://localhost:8791
#
# Two pages: / is the real overview step, /gallery.html is a component gallery
# of the later steps, which LiveView would otherwise be required to reach.

set -euo pipefail
ORIGIN="${SKINLAB_ORIGIN:-https://the booking host}"
USER_SLUG="${SKINLAB_USER:-vincent}"
OUT="${SKINLAB_OUT:-/tmp/skinlab}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$OUT/fonts"
echo "==> Fetching $ORIGIN/$USER_SLUG"
curl -fsS "$ORIGIN/$USER_SLUG?embed=1&layout=column" -o "$OUT/raw.html"

python3 - "$OUT" <<'PY'
import re, sys, os
out = sys.argv[1]
h = open(os.path.join(out, 'raw.html')).read()
h = re.sub(r'(src|href)="/(?!/)', r'\1="' + os.environ.get('SKINLAB_ORIGIN', 'https://the booking host') + '/', h)
h = re.sub(r'<script[^>]*type="module"[^>]*>\s*</script>', '', h)
h = h.replace('</head>', '<link rel="stylesheet" href="./slate-skin.css">\n</head>')
h = h.replace('<html ', '<html data-embedded ')   # what iframe_embed.js sets when framed
open(os.path.join(out, 'index.html'), 'w').write(h)
PY

cp "$HERE/priv/static/css/slate-skin.css" "$OUT/"
cp "$HERE/priv/static/fonts/"*.woff2 "$OUT/fonts/"
# the skin references /fonts/… ; serve them relatively here
sed -i '' "s#url('/fonts/#url('./fonts/#g" "$OUT/slate-skin.css" 2>/dev/null \
  || sed -i "s#url('/fonts/#url('./fonts/#g" "$OUT/slate-skin.css"

echo "==> Serving $OUT on :8791"
echo "    Ctrl-C to stop."
cd "$OUT" && exec npx --yes serve --listen 8791 .
