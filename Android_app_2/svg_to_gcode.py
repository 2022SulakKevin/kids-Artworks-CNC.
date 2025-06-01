import sys
import os

# Add the svgpath directory to the Python path
sys.path.append(os.path.dirname(__file__) + "/svgpath")

from gcodeplot import main as gcodeplot_main

def svg_to_gcode(input_svg, output_gcode):
    # Configure GcodePlot for servo-based pen plotter
    args = [
        "--z-down", "0",  # Not used for servo, but required
        "--z-up", "5",    # Not used for servo, but required
        "--feedrate", "1200",
        "--pen-down", "M03",  # Servo pen down command
        "--pen-up", "M05",    # Servo pen up command
        "--header", "G21\nG90\nM05\nG00 F1200.0 X0.0 Y0.0",
        "--footer", "M05\nG00 X0.0 Y0.0",
        "--scale", "0.223",  # Scale to fit 664px (B5 width) into 210mm (machine width): 210/944
        input_svg,
        output_gcode
    ]
    gcodeplot_main(args)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python svg_to_gcode.py <input_svg> <output_gcode>")
        sys.exit(1)
    input_svg = sys.argv[1]
    output_gcode = sys.argv[2]
    svg_to_gcode(input_svg, output_gcode)