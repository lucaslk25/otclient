#!/usr/bin/env python3
"""
Generate edit_mode_dashed_border.png for the reusable edit-mode label.
9-slice compatible (image-border: 2): 12x12 with 2px corners, dashed 1px border.
"""
import os
import sys

try:
    from PIL import Image
except ImportError:
    print("Pillow required: pip install Pillow", file=sys.stderr)
    sys.exit(1)

SIZE = 12
BORDER = 2  # 9-slice border width
GRAY = (160, 160, 160, 255)  # #a0a0a0
CLEAR = (0, 0, 0, 0)


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    root = os.path.normpath(os.path.join(script_dir, ".."))
    out_dir = os.path.join(root, "data", "images", "ui")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "edit_mode_dashed_border.png")

    img = Image.new("RGBA", (SIZE, SIZE), CLEAR)
    px = img.load()

    def dash_top_bottom(y):
        for x in range(SIZE):
            if x % 2 == 0:
                px[x, y] = GRAY

    def dash_left_right(x):
        for y in range(SIZE):
            if y % 2 == 0:
                px[x, y] = GRAY

    # Top edge (dashed)
    for y in range(BORDER):
        dash_top_bottom(y)
    # Bottom edge
    for y in range(SIZE - BORDER, SIZE):
        dash_top_bottom(y)
    # Left edge
    for x in range(BORDER):
        dash_left_right(x)
    # Right edge
    for x in range(SIZE - BORDER, SIZE):
        dash_left_right(x)

    img.save(out_path)
    print("Wrote", out_path)


if __name__ == "__main__":
    main()
