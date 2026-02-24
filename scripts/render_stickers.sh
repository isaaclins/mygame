#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STICKER_DIR="${ROOT_DIR}/content/stickers"
SIZE="${STICKER_SIZE:-512}"

if [[ ! -d "${STICKER_DIR}" ]]; then
  echo "[stickers] Missing directory: ${STICKER_DIR}" >&2
  exit 1
fi

detect_renderer() {
  if command -v rsvg-convert >/dev/null 2>&1; then
    echo "rsvg-convert"
    return
  fi
  if command -v inkscape >/dev/null 2>&1; then
    echo "inkscape"
    return
  fi
  if command -v magick >/dev/null 2>&1; then
    echo "magick"
    return
  fi
  echo ""
}

render_with() {
  local renderer="$1"
  local svg="$2"
  local png="$3"
  case "${renderer}" in
    rsvg-convert)
      rsvg-convert -w "${SIZE}" -h "${SIZE}" "${svg}" -o "${png}"
      ;;
    inkscape)
      inkscape "${svg}" --export-type=png --export-filename="${png}" --export-width="${SIZE}" --export-height="${SIZE}" >/dev/null
      ;;
    magick)
      magick -background none -density 384 "${svg}" -resize "${SIZE}x${SIZE}" "${png}"
      ;;
    *)
      echo "[stickers] Unsupported renderer: ${renderer}" >&2
      exit 1
      ;;
  esac
}

RENDERER="$(detect_renderer)"
if [[ -z "${RENDERER}" ]]; then
  echo "[stickers] No SVG renderer found."
  echo "[stickers] Install one of: librsvg (rsvg-convert), inkscape, or imagemagick (magick)."
  exit 1
fi

echo "[stickers] Renderer: ${RENDERER}"
echo "[stickers] Source: ${STICKER_DIR}"
echo "[stickers] Size: ${SIZE}x${SIZE}"

shopt -s nullglob
svgs=("${STICKER_DIR}"/*.svg)
if [[ ${#svgs[@]} -eq 0 ]]; then
  echo "[stickers] No SVG files found."
  exit 0
fi

count=0
for svg in "${svgs[@]}"; do
  png="${svg%.svg}.png"
  render_with "${RENDERER}" "${svg}" "${png}"
  echo "[stickers] ${svg##*/} -> ${png##*/}"
  count=$((count + 1))
done

echo "[stickers] Rendered ${count} sticker textures."
