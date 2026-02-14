#!/usr/bin/env python3
"""
Generate app icon from the wobby spiral design.
Ported from Spiral-static.jsx
"""

import math
from PIL import Image, ImageDraw

def generate_spiral_icon(size=1024, output_path="appicon_source.png"):
    """Generate a spiral app icon at the specified size."""

    # Create image with white background
    img = Image.new('RGBA', (size, size), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)

    # Scale factor from original 550x550 design
    scale = size / 550.0

    # Spiral parameters (from JSX)
    center_x = size / 2
    center_y = size / 2
    total_turns = 5.2
    total_steps = 800
    max_radius = 180 * scale
    min_radius = 6 * scale

    # Draw two passes for depth effect
    for pass_num in range(2):
        off = (pass_num - 0.5) * 0.7 * scale
        line_width = max(1, int((1.8 - pass_num * 0.4) * scale))
        alpha = int(255 * (0.85 - pass_num * 0.15))
        color = (30, 30, 30, alpha)

        # Generate spiral points
        points = []
        for i in range(total_steps + 1):
            t = i / total_steps
            angle = t * total_turns * math.pi * 2
            radius = min_radius + (max_radius - min_radius) * t

            # Wobble effect
            wobble = (
                math.sin(angle * 3.1 + t * 5) * 2.2 +
                math.sin(angle * 7.3 + t * 11) * 1.0 +
                math.sin(angle * 13.7) * 0.6
            ) * scale

            r = radius + wobble
            x = center_x + math.cos(angle) * r + off * math.cos(angle + math.pi / 2)
            y = center_y + math.sin(angle) * r + off * math.sin(angle + math.pi / 2)
            points.append((x, y))

        # Draw the spiral line
        if len(points) > 1:
            draw.line(points, fill=color, width=line_width, joint="curve")

    # Save the image
    img.save(output_path, 'PNG')
    print(f"Generated app icon: {output_path} ({size}x{size})")
    return output_path

if __name__ == "__main__":
    generate_spiral_icon(1024, "appicon_source.png")
