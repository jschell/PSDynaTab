#!/usr/bin/env python3
"""Analyze corner pixel positions in animation frames."""

import json
import re
import sys

def parse_hex_fragment(fragment_str):
    """Parse colon-separated hex string to bytes."""
    return bytes.fromhex(fragment_str.replace(':', ''))

def main():
    filename = sys.argv[1] if len(sys.argv) > 1 else \
        '/home/user/PSDynaTab/usbPcap/2026-01-17-animation-4frame-ff-00-00-00-ff-00-00-00-ff-7f-00-00-connected-corners-1pixel-each.json'

    # Extract data fragments from JSON
    with open(filename, 'r') as f:
        content = f.read()
        fragments = re.findall(r'"usb\.data_fragment":\s*"([^"]+)"', content)

    print("=" * 80)
    print("CORNER PIXEL ANALYSIS")
    print("=" * 80)

    # Find init packet
    for frag in fragments:
        packet = parse_hex_fragment(frag)
        if packet[0] == 0xa9:
            print("\nINIT PACKET (0xa9) - Position Encoding:")
            print("-" * 80)
            print(f"Full packet: {packet.hex(':')}")
            print(f"\nBytes 8-11 (Position Info):")
            print(f"  X position: {packet[8]}")
            print(f"  Y position: {packet[9]}")
            print(f"  Width:      {packet[10]} pixels")
            print(f"  Height:     {packet[11]} pixels")

            x, y, w, h = packet[8], packet[9], packet[10], packet[11]
            print(f"\nCorner Coordinates (based on X={x}, Y={y}, W={w}, H={h}):")
            print(f"  Top-Left:     ({x}, {y})")
            print(f"  Top-Right:    ({x + w - 1}, {y})")
            print(f"  Bottom-Left:  ({x}, {y + h - 1})")
            print(f"  Bottom-Right: ({x + w - 1}, {y + h - 1})")
            print()
            break

    # Organize data packets by frame
    frames = {}
    for frag in fragments:
        packet = parse_hex_fragment(frag)
        if packet[0] == 0x29:
            frame_num = packet[1]
            packet_seq = packet[4]  # Sequence number within frame

            if frame_num not in frames:
                frames[frame_num] = []
            frames[frame_num].append((packet_seq, packet))

    print("=" * 80)
    print("DATA PACKETS BY FRAME")
    print("=" * 80)

    # For a 60x9 keyboard, we have 540 total pixels
    # Pixels are sent in row-major order (left to right, top to bottom)
    # Each data packet contains pixel data starting at byte 8

    for frame_num in sorted(frames.keys()):
        print(f"\n{'='*80}")
        print(f"FRAME {frame_num}")
        print(f"{'='*80}")

        # Sort packets by sequence number
        packets = sorted(frames[frame_num], key=lambda x: x[0])

        # Reconstruct the full frame buffer
        frame_pixels = []
        for seq, packet in packets:
            # Extract pixel data (starts at byte 8)
            pixel_data = packet[8:]
            # Parse as RGB triplets
            for i in range(0, len(pixel_data), 3):
                if i + 2 < len(pixel_data):
                    r, g, b = pixel_data[i], pixel_data[i+1], pixel_data[i+2]
                    frame_pixels.append((r, g, b))

        print(f"\nTotal pixels in frame: {len(frame_pixels)}")

        # Find non-black pixels
        non_black = []
        for idx, (r, g, b) in enumerate(frame_pixels):
            if r != 0 or g != 0 or b != 0:
                # Calculate X, Y coordinates from linear index
                # Assuming 60 pixels wide
                x = idx % 60
                y = idx // 60

                # Determine color name
                color_name = ""
                if (r, g, b) == (0xff, 0x00, 0x00):
                    color_name = "Bright Red"
                elif (r, g, b) == (0x7f, 0x00, 0x00):
                    color_name = "Dark Red"
                elif (r, g, b) == (0x00, 0xff, 0x00):
                    color_name = "Green"
                elif (r, g, b) == (0x00, 0x00, 0xff):
                    color_name = "Blue"
                else:
                    color_name = f"Other RGB({r:02x},{g:02x},{b:02x})"

                non_black.append({
                    'idx': idx,
                    'x': x,
                    'y': y,
                    'r': r,
                    'g': g,
                    'b': b,
                    'name': color_name
                })

        print(f"Non-black pixels: {len(non_black)}")
        print()

        if non_black:
            print("Active Pixels:")
            print(f"{'Coord':>12}  {'Linear Idx':>10}  {'Color':>15}  RGB")
            print("-" * 80)
            for p in non_black:
                print(f"({p['x']:2d}, {p['y']:2d})     {p['idx']:4d}        {p['name']:>15}  ({p['r']:02x}, {p['g']:02x}, {p['b']:02x})")

        # Check if these are corner positions
        corners = {
            (0, 0): "Top-Left",
            (59, 0): "Top-Right",
            (0, 8): "Bottom-Left",
            (59, 8): "Bottom-Right"
        }

        print()
        print("Corner Status:")
        for coord, corner_name in corners.items():
            idx = coord[1] * 60 + coord[0]
            if idx < len(frame_pixels):
                r, g, b = frame_pixels[idx]
                if r != 0 or g != 0 or b != 0:
                    color = f"RGB({r:02x},{g:02x},{b:02x})"
                else:
                    color = "Black (off)"
                print(f"  {corner_name:15s} {coord}: {color}")

    print("\n" + "=" * 80)
    print("ANIMATION PATTERN SUMMARY")
    print("=" * 80)

    print("\nFrame-by-Frame Color Rotation at Corners:")
    for frame_num in sorted(frames.keys()):
        print(f"\n  Frame {frame_num}:")

        # Reconstruct frame pixels
        packets = sorted(frames[frame_num], key=lambda x: x[0])
        frame_pixels = []
        for seq, packet in packets:
            pixel_data = packet[8:]
            for i in range(0, len(pixel_data), 3):
                if i + 2 < len(pixel_data):
                    frame_pixels.append((pixel_data[i], pixel_data[i+1], pixel_data[i+2]))

        corners = [
            (0, 0, "TL"),
            (59, 0, "TR"),
            (0, 8, "BL"),
            (59, 8, "BR")
        ]

        for x, y, name in corners:
            idx = y * 60 + x
            if idx < len(frame_pixels):
                r, g, b = frame_pixels[idx]
                if r != 0 or g != 0 or b != 0:
                    # Determine color
                    if (r, g, b) == (0xff, 0x00, 0x00):
                        color = "Bright Red"
                    elif (r, g, b) == (0x7f, 0x00, 0x00):
                        color = "Dark Red"
                    elif (r, g, b) == (0x00, 0xff, 0x00):
                        color = "Green"
                    elif (r, g, b) == (0x00, 0x00, 0xff):
                        color = "Blue"
                    else:
                        color = f"RGB({r:02x},{g:02x},{b:02x})"
                    print(f"    {name} ({x:2d},{y}): {color}")

if __name__ == '__main__':
    main()
