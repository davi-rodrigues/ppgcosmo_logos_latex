#!/bin/bash
# make-images.sh -- renders every variant of the PPGCosmo logo (ppgcosmologo.sty)
# as JPG and PNG images, one file per variant, cropped exactly to the logo.
#
# Usage:  ./make-images.sh [DPI] [OUTDIR]
#   DPI     resolution of the images (default 600; the large logo is 5 cm high,
#           the short one 2 cm, so at 600 dpi they are ~1181 and ~472 px high)
#   OUTDIR  output folder (default: images/ next to this script)
#
# Variants: version large|short  x  {black on white, white on black,
#           black on transparent, white on transparent}.
# JPG has no transparency, so the transparent variants are written only as PNG.
#
# Needs: pdflatex (TeX Live, with the opensans package) and pdftocairo (poppler).

set -euo pipefail

DPI="${1:-600}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUTDIR="${2:-$HERE/images}"
JPGQUALITY=95
HEIGHT_LARGE=5cm
HEIGHT_SHORT=2cm

# version  fontcolor  background   (one variant per line, in page order)
VARIANTS="
large black white
large white black
large black none
large white none
short black white
short white black
short black none
short white none
"

for cmd in pdflatex pdftocairo; do
  command -v "$cmd" >/dev/null || { echo "error: $cmd not found" >&2; exit 1; }
done

# build in a fixed scratch folder outside Dropbox (reused and overwritten on each run)
WORK="${TMPDIR:-/tmp}/ppgcosmologo-build"
mkdir -p "$WORK"

# ---- 1. one standalone page per variant, cropped to the logo canvas
{
  echo '\documentclass[multi=logo,border=0pt]{standalone}'
  echo '\usepackage{ppgcosmologo}'
  echo '\newenvironment{logo}{}{}'
  echo '\begin{document}'
  echo "$VARIANTS" | while read -r ver fc bg; do
    [ -z "$ver" ] && continue
    if [ "$ver" = large ]; then h=$HEIGHT_LARGE; else h=$HEIGHT_SHORT; fi
    echo "\\begin{logo}\\ppgcosmologo[version=$ver, fontcolor=$fc, background=$bg, height=$h]\\end{logo}"
  done
  echo '\end{document}'
} > "$WORK/logos.tex"

echo "Compiling logos with pdflatex..."
if ! (cd "$WORK" && TEXINPUTS="$HERE:" pdflatex -interaction=nonstopmode -halt-on-error logos.tex >/dev/null); then
  echo "error: pdflatex failed; last lines of the log:" >&2
  tail -n 30 "$WORK/logos.log" >&2
  exit 1
fi

# ---- 2. convert each page
mkdir -p "$OUTDIR"
page=0
echo "$VARIANTS" | while read -r ver fc bg; do
  [ -z "$ver" ] && continue
  page=$((page + 1))
  if [ "$bg" = none ]; then
    name="ppgcosmologo-$ver-$fc-transparent"
    pdftocairo -png -transp -r "$DPI" -f $page -l $page -singlefile \
      "$WORK/logos.pdf" "$OUTDIR/$name"
    echo "  $name.png"
  else
    name="ppgcosmologo-$ver-$fc-on-$bg"
    pdftocairo -png -r "$DPI" -f $page -l $page -singlefile \
      "$WORK/logos.pdf" "$OUTDIR/$name"
    pdftocairo -jpeg -jpegopt quality=$JPGQUALITY -r "$DPI" -f $page -l $page -singlefile \
      "$WORK/logos.pdf" "$OUTDIR/$name"
    echo "  $name.png  $name.jpg"
  fi
done

echo "Done: images in $OUTDIR (${DPI} dpi)"
