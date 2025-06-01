import potrace
import numpy as np
from PIL import Image
import sys

def png_to_svg(input_path, output_path):
    # Load the PNG image
    image = Image.open(input_path).convert('L')  # Convert to grayscale
    bitmap = potrace.Bitmap(np.array(image))

    # Trace the bitmap to vector paths
    path = bitmap.trace()

    # Write the SVG file
    with open(output_path, 'w') as f:
        f.write('<?xml version="1.0" standalone="no"?>\n')
        f.write('<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">\n')
        f.write(f'<svg width="{image.width}" height="{image.height}" xmlns="http://www.w3.org/2000/svg" version="1.1">\n')
        for curve in path:
            f.write('<path d="')
            for i, segment in enumerate(curve):
                if i == 0:
                    f.write(f'M {segment.start_point.x} {segment.start_point.y} ')
                if segment.is_corner:
                    f.write(f'L {segment.c.x} {segment.c.y} ')
                else:
                    f.write(f'C {segment.c1.x} {segment.c1.y} {segment.c2.x} {segment.c2.y} {segment.end_point.x} {segment.end_point.y} ')
            f.write('" fill="none" stroke="black" stroke-width="1"/>\n')
        f.write('</svg>')

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python png_to_svg.py <input_png> <output_svg>")
        sys.exit(1)
    input_png = sys.argv[1]
    output_svg = sys.argv[2]
    png_to_svg(input_png, output_svg)