#!/usr/bin/env bash
#
# Builds the region map's tile pyramid with gdal2tiles.
#
# Why a pyramid at all: `RegionMapView` magnifies the chart up to 6x and the discovery map's
# `MKMapView` goes further still. A single PNG handed to either surface is rasterised once at its
# resting size and then *layer*-scaled, so the reader is magnifying a 402-point raster rather than
# the 1469-pixel source — which is the "pecah" this replaces. A pyramid lets each surface draw the
# level whose pixels match the pixels it is about to fill, and draw only the tiles on screen.
#
# Profile is `raster`, not `mercator`: this is a stylised drawing, not a projection. The tiles are
# in the *image's* own coordinate space, which is the space `Place.mapPoint` is authored in and the
# space `IllustratedMapGeoreference` already turns into world coordinates for the basemap overlay.
# Tiling in EPSG:3857 would bake a projection into artwork that has none.
#
# Tiles are WebP, not PNG. At 4x the pyramid is 543 tiles: 43 MB as PNG, 6.2 MB at WebP quality 90,
# and a q90 tile is indistinguishable from the PNG on this artwork (checked tile by tile, not
# assumed). Thirty-seven megabytes in every user's app bundle is not a reasonable price for a
# difference nobody can see. ImageIO has decoded WebP since iOS 14 and the deployment target is
# 18.0, so `UIImage(contentsOfFile:)` reads them with no extra code.
#
# Re-run this whenever the source artwork changes. Everything under `OUT` is generated; nothing in
# it is authored by hand.
#
# The shipped pyramid is built from a 4x super-resolution pass over the authored drawing, which is
# not in the repository because it is 45 MB and regenerable. To rebuild it:
#
#   brew install --cask upscayl
#   /Applications/Upscayl.app/Contents/Resources/bin/upscayl-bin \
#     -i challange-5/Packages/Kultara/Sources/ContentKit/Content/assets/maps/bali-illustrated.png \
#     -o /tmp/bali-4x.png -n remacri-4x -s 4 \
#     -m /Applications/Upscayl.app/Contents/Resources/models -f png
#   scripts/build-map-tiles.sh /tmp/bali-4x.png
#
# `remacri-4x` rather than the sharper models on purpose — see `docs/hisplora-tokens.md`.
#
# Usage: scripts/build-map-tiles.sh [source.png]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTENT="$ROOT/challange-5/Packages/Kultara/Sources/ContentKit/Content"
SOURCE="${1:-$CONTENT/assets/maps/bali-illustrated.png}"
OUT="$CONTENT/assets/maps/bali-illustrated-tiles"
# 90 rather than the default. Below about 85 the chart's ink lines start ringing against the paper,
# which on a drawing made almost entirely of ink lines is the one artefact that shows.
WEBP_QUALITY="${WEBP_QUALITY:-90}"

command -v gdal2tiles.py >/dev/null 2>&1 || {
  echo "gdal2tiles.py not on PATH. Install it with: brew install gdal" >&2
  exit 127
}

WIDTH=$(gdalinfo -json "$SOURCE" | python3 -c 'import json,sys; print(json.load(sys.stdin)["size"][0])')
HEIGHT=$(gdalinfo -json "$SOURCE" | python3 -c 'import json,sys; print(json.load(sys.stdin)["size"][1])')

# The deepest level whose grid holds the source at 1:1. gdal2tiles picks the same number for the
# raster profile; computing it here is what lets `tiles.json` state it rather than have the app
# discover it by probing the filesystem.
MAXZOOM=$(python3 -c "
import math
w, h = $WIDTH, $HEIGHT
print(max(0, math.ceil(math.log2(max(w, h) / 256.0))))
")

echo "Source ${WIDTH}x${HEIGHT} -> levels 0..${MAXZOOM}"
rm -rf "$OUT"

# --xyz so y counts down from the top, the way the image and every consumer here do. TMS ordering
# would flip every row and the only place that shows up is a map drawn upside down.
# lanczos because the lower levels are what the reader sees at rest; averaging softens the ink
# lines the chart is mostly made of.
gdal2tiles.py \
  --profile=raster \
  --xyz \
  --zoom="0-${MAXZOOM}" \
  --resampling=lanczos \
  --tiledriver=WEBP \
  --webp-quality="${WEBP_QUALITY}" \
  --webviewer=none \
  --processes=4 \
  --quiet \
  "$SOURCE" "$OUT"

# gdal2tiles leaves its own bookkeeping behind; none of it is read by the app and all of it would
# ship in every user's bundle.
find "$OUT" -maxdepth 1 -type f ! -name '*.webp' -delete

python3 - "$OUT" "$WIDTH" "$HEIGHT" "$MAXZOOM" <<'PY'
import json, os, sys
out, width, height, maxzoom = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
manifest = {
    "tileSize": 256,
    # Stated rather than assumed: the app addresses tiles by this extension, so re-tiling to PNG is
    # a one-word change here and nowhere else.
    "tileFormat": "webp",
    "sourceWidthPx": width,
    "sourceHeightPx": height,
    "minZoom": 0,
    "maxZoom": maxzoom,
}
with open(os.path.join(out, "tiles.json"), "w") as f:
    json.dump(manifest, f, indent=2)
    f.write("\n")
count = sum(len(files) for _, _, files in os.walk(out))
size = sum(
    os.path.getsize(os.path.join(root, name))
    for root, _, files in os.walk(out)
    for name in files
)
print(f"{count} files, {size / 1024 / 1024:.2f} MB in {out}")
PY

echo "Remember to bump manifest.json's contentBundleVersion."
