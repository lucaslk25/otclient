#!/usr/bin/env python3
"""
Generate OTClient bitmap font (.otfont + .png) without stroke/border.
Reusable: run with any TTF path and size to produce a no-outline font.

Usage:
  python tools/bitmap_font_generator.py <path_to.ttf> <size> [--output-dir DIR] [--output-name NAME] [--space-width N]

Example:
  python tools/bitmap_font_generator.py "data/fonts/ttf/Verdana Bold.ttf" 8 --output-name "verdana-8px-nostroke"
"""

import argparse
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Error: Pillow is required. Install with: pip install Pillow", file=sys.stderr)
    sys.exit(1)


def cp1252_char(i: int) -> str:
    """Return character for CP1252 code point; use replacement for invalid."""
    if i == 127 or i == 129 or (141 <= i <= 144) or i == 157:
        return "\u25A1"  # square
    try:
        return bytes([i]).decode("cp1252")
    except (UnicodeDecodeError, ValueError):
        return "\u25A1"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate OTClient bitmap font (no stroke) from a TTF file."
    )
    parser.add_argument(
        "font_path",
        help="Path to the .ttf (or .otf) font file.",
    )
    parser.add_argument(
        "size",
        type=int,
        help="Font size in pixels.",
    )
    parser.add_argument(
        "--output-dir",
        default="data/fonts/otfont",
        help="Output directory for .otfont and .png (default: data/fonts/otfont).",
    )
    parser.add_argument(
        "--output-name",
        default=None,
        help="Base name for output files (default: derived from font filename and size).",
    )
    parser.add_argument(
        "--space-width",
        type=int,
        default=4,
        help="Space character width in .otfont (default: 4).",
    )
    args = parser.parse_args()

    font_path = os.path.abspath(args.font_path)
    if not os.path.isfile(font_path):
        print(f"Error: Font file not found: {font_path}", file=sys.stderr)
        sys.exit(1)

    size = max(1, min(args.size, 128))
    output_dir = os.path.abspath(args.output_dir)
    os.makedirs(output_dir, exist_ok=True)

    if args.output_name:
        base_name = args.output_name.strip()
    else:
        base = os.path.splitext(os.path.basename(font_path))[0]
        base_clean = base.replace(" ", "-").replace("_", "-")
        base_name = f"{base_clean}-{size}px-nostroke"

    try:
        font = ImageFont.truetype(font_path, size)
    except OSError as e:
        print(f"Error loading font: {e}", file=sys.stderr)
        sys.exit(1)

    draw = ImageDraw.Draw(Image.new("RGBA", (1, 1)))

    char_begin = 32
    char_end = 256
    num_chars = char_end - char_begin
    cols = 16
    rows = (num_chars + cols - 1) // cols

    max_width = 0
    max_height = 0
    glyph_boxes = []

    for i in range(char_begin, char_end):
        ch = cp1252_char(i)
        bbox = draw.textbbox((0, 0), ch, font=font)
        w = bbox[2] - bbox[0]
        h = bbox[3] - bbox[1]
        if w < 1:
            w = 1
        if h < 1:
            h = 1
        max_width = max(max_width, w)
        max_height = max(max_height, h)
        glyph_boxes.append((bbox, w, h))

    cell_w = max_width
    cell_h = max_height
    atlas_w = cols * cell_w
    atlas_h = rows * cell_h

    image = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    for i in range(char_begin, char_end):
        ch = cp1252_char(i)
        idx = i - char_begin
        col = idx % cols
        row = idx // cols
        x = col * cell_w
        y = row * cell_h
        bbox, w, h = glyph_boxes[idx]
        off_x = -bbox[0]
        off_y = -bbox[1]
        draw.text((x + off_x, y + off_y), ch, font=font, fill=(255, 255, 255, 255))

    png_path = os.path.join(output_dir, base_name + ".png")
    image.save(png_path)

    otfont_content = (
        "Font\n"
        f"  name: {base_name}\n"
        f"  texture: {base_name}\n"
        f"  height: {cell_h}\n"
        f"  glyph-size: {cell_w} {cell_h}\n"
        f"  space-width: {args.space_width}\n"
        "  spacing: 0 0\n"
    )
    otfont_path = os.path.join(output_dir, base_name + ".otfont")
    with open(otfont_path, "w", encoding="utf-8") as f:
        f.write(otfont_content)

    print(f"Generated: {otfont_path}")
    print(f"Generated: {png_path}")
    print(f"Use in OTUI: font: {base_name}")


if __name__ == "__main__":
    main()
