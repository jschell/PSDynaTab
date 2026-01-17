#!/usr/bin/env python3
"""Visualize the exact 4-pixel rotation pattern per frame."""

import json
import re
import sys

def parse_hex_fragment(fragment_str):
    return bytes.fromhex(fragment_str.replace(':', ''))

def color_name(r, g, b):
    colors = {
        (0xff, 0x00, 0x00): "Bright Red ",
        (0x7f, 0x00, 0x00): "Dark Red   ",
        (0x00, 0xff, 0x00): "Green      ",
        (0x00, 0x00, 0xff): "Blue       ",
        (0x00, 0x7f, 0x00): "Green(127) ",
    }
    return colors.get((r, g, b), f"RGB({r:02x},{g:02x},{b:02x})")

def main():
    filename = sys.argv[1] if len(sys.argv) > 1 else \
        '/home/user/PSDynaTab/usbPcap/2026-01-17-animation-4frame-ff-00-00-00-ff-00-00-00-ff-7f-00-00-connected-corners-1pixel-each.json'

    with open(filename, 'r') as f:
        content = f.read()
        fragments = re.findall(r'"usb\.data_fragment":\s*"([^"]+)"', content)

    # Organize data packets by frame
    frames = {}
    for frag in fragments:
        packet = parse_hex_fragment(frag)
        if packet[0] == 0x29:
            frame_num = packet[1]
            if frame_num not in frames:
                frames[frame_num] = []
            frames[frame_num].append(packet)

    print("=" * 80)
    print("4-PIXEL COLOR ROTATION PATTERN")
    print("=" * 80)

    for frame_num in sorted(frames.keys()):
        packets = sorted(frames[frame_num], key=lambda p: p[4])

        # Reconstruct frame
        frame_pixels = []
        for packet in packets:
            pixel_data = packet[8:]
            for i in range(0, len(pixel_data), 3):
                if i + 2 < len(pixel_data):
                    frame_pixels.append((pixel_data[i], pixel_data[i+1], pixel_data[i+2]))

        # Find the 4 non-black pixels in this frame
        active = []
        for idx, (r, g, b) in enumerate(frame_pixels):
            if r != 0 or g != 0 or b != 0:
                x = idx % 60
                y = idx // 60
                active.append((idx, x, y, r, g, b))

        print(f"\nFRAME {frame_num}: {len(active)} active pixels")
        print("-" * 80)

        # Assign corner labels based on position
        for idx, x, y, r, g, b in active:
            # Determine which "corner" this is
            if (x, y) == (0, 0):
                corner = "Top-Left     "
            elif y == 0 and x < 30:
                corner = f"Top-Near-Left"
            elif y == 0 and x >= 30:
                corner = f"Top-Near-Right"
            elif y == 8 and x < 30:
                corner = f"Bottom-Left  "
            elif y == 8 and x >= 30:
                corner = f"Bottom-Right "
            else:
                corner = f"Position     "

            cname = color_name(r, g, b)
            print(f"  {corner} ({x:2d},{y}) idx={idx:3d}: {cname}  RGB({r:02x}, {g:02x}, {b:02x})")

    # Now show the rotation pattern more clearly
    print("\n" + "=" * 80)
    print("COLOR ROTATION TABLE - Primary Pattern (4 positions)")
    print("=" * 80)

    # The consistent 4 positions that appear to be the user's intended corners
    # Based on the data: (0,0), (8,0), and two bottom positions
    print("\nIdentified pattern: 4 colors rotating through specific pixel positions")
    print()

    # Create rotation table
    print("Position:     (0,0)         (8,0)         Bottom-L      Bottom-R")
    print("            Top-Left    Top-Near-L    (~32-33,8)    (~40-41,8)")
    print("-" * 80)

    for frame_num in sorted(frames.keys()):
        packets = sorted(frames[frame_num], key=lambda p: p[4])
        frame_pixels = []
        for packet in packets:
            pixel_data = packet[8:]
            for i in range(0, len(pixel_data), 3):
                if i + 2 < len(pixel_data):
                    frame_pixels.append((pixel_data[i], pixel_data[i+1], pixel_data[i+2]))

        # Get colors at the 4 key positions
        colors = []
        for test_pos in [0, 8, [512, 513], [520, 521]]:
            found = False
            if isinstance(test_pos, list):
                # Check multiple indices
                for idx in test_pos:
                    if idx < len(frame_pixels):
                        r, g, b = frame_pixels[idx]
                        if r != 0 or g != 0 or b != 0:
                            colors.append(color_name(r, g, b))
                            found = True
                            break
                if not found:
                    colors.append("Black      ")
            else:
                if test_pos < len(frame_pixels):
                    r, g, b = frame_pixels[test_pos]
                    if r != 0 or g != 0 or b != 0:
                        colors.append(color_name(r, g, b))
                    else:
                        colors.append("Black      ")
                else:
                    colors.append("Black      ")

        print(f"Frame {frame_num}:  {colors[0]}  {colors[1]}  {colors[2]}  {colors[3]}")

    print("\n" + "=" * 80)
    print("KEY FINDINGS")
    print("=" * 80)
    print("""
1. POSITION ENCODING (Init packet 0xa9, bytes 8-11):
   - Byte 8:  X position = 0
   - Byte 9:  Y position = 0
   - Byte 10: Width = 60 pixels
   - Byte 11: Height = 9 pixels

2. ACTUAL ACTIVE PIXELS (from captured data):
   - Position 1: (0, 0)   - Confirmed Top-Left corner
   - Position 2: (8, 0)   - Top row, 8 pixels right
   - Position 3: (~32-33, 8) - Bottom row, left-center area
   - Position 4: (~40-41, 8) - Bottom row, right-center area

   Note: Bottom positions shift slightly (±1 pixel) between frames.
         This may be due to coordinate calculation in the animation file.

3. COLOR ROTATION:
   Each of the 4 colors (Bright Red, Green, Blue, Dark Red) rotates
   through the 4 pixel positions across the 4 frames.

   At position (0,0): Red → Dark Red → Blue → Green
   At position (8,0): Green → Red → Dark Red → Blue
   Bottom positions follow the same rotation offset by 2 steps.

4. DATA PACKET STRUCTURE (0x29):
   - Byte 1: Frame number (0-3)
   - Byte 4: Packet sequence within frame (0-28)
   - Byte 8+: RGB pixel data (3 bytes per pixel, row-major order)
""")

if __name__ == '__main__':
    main()
