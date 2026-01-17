#!/usr/bin/env python3
"""Check if frames are complete and identify actual corner pixels."""

import json
import re
import sys

def parse_hex_fragment(fragment_str):
    """Parse colon-separated hex string to bytes."""
    return bytes.fromhex(fragment_str.replace(':', ''))

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
            packet_seq = packet[4]

            if frame_num not in frames:
                frames[frame_num] = []
            frames[frame_num].append((packet_seq, packet))

    print("=" * 80)
    print("FRAME COMPLETENESS CHECK")
    print("=" * 80)

    for frame_num in sorted(frames.keys()):
        packets = sorted(frames[frame_num], key=lambda x: x[0])

        print(f"\nFrame {frame_num}:")
        print(f"  Number of packets: {len(packets)}")
        print(f"  Packet sequence range: {packets[0][0]} to {packets[-1][0]}")

        # Reconstruct frame pixels
        frame_pixels = []
        for seq, packet in packets:
            pixel_data = packet[8:]
            for i in range(0, len(pixel_data), 3):
                if i + 2 < len(pixel_data):
                    frame_pixels.append((pixel_data[i], pixel_data[i+1], pixel_data[i+2]))

        print(f"  Total pixels: {len(frame_pixels)} (expected 540 for 60x9)")

        # Check if we have the corners
        expected_corners = [
            (0, 0, "Top-Left"),
            (59, 0, "Top-Right"),
            (0, 8, "Bottom-Left"),
            (59, 8, "Bottom-Right")
        ]

        print(f"\n  Corner coverage:")
        for x, y, name in expected_corners:
            idx = y * 60 + x
            if idx < len(frame_pixels):
                r, g, b = frame_pixels[idx]
                status = "✓" if (r != 0 or g != 0 or b != 0) else "  "
                print(f"    {status} {name:15s} (index {idx:3d}): Available")
            else:
                print(f"      {name:15s} (index {idx:3d}): MISSING")

    print("\n" + "=" * 80)
    print("DETAILED PIXEL POSITION ANALYSIS")
    print("=" * 80)

    # Analyze where the 4 pixels actually are
    for frame_num in sorted(frames.keys()):
        packets = sorted(frames[frame_num], key=lambda x: x[0])

        # Reconstruct frame
        frame_pixels = []
        for seq, packet in packets:
            pixel_data = packet[8:]
            for i in range(0, len(pixel_data), 3):
                if i + 2 < len(pixel_data):
                    frame_pixels.append((pixel_data[i], pixel_data[i+1], pixel_data[i+2]))

        # Find non-black pixels
        non_black = []
        for idx, (r, g, b) in enumerate(frame_pixels):
            if r != 0 or g != 0 or b != 0:
                x = idx % 60
                y = idx // 60
                non_black.append((x, y, idx, r, g, b))

        print(f"\nFrame {frame_num} - Active Pixel Locations:")
        for x, y, idx, r, g, b in non_black:
            # Check if it's near a corner
            corner_dist = {
                "TL (0,0)": ((x-0)**2 + (y-0)**2)**0.5,
                "TR (59,0)": ((x-59)**2 + (y-0)**2)**0.5,
                "BL (0,8)": ((x-0)**2 + (y-8)**2)**0.5,
                "BR (59,8)": ((x-59)**2 + (y-8)**2)**0.5,
            }
            nearest = min(corner_dist.items(), key=lambda x: x[1])

            # Color name
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

            print(f"  ({x:2d},{y}) idx={idx:3d} [{color:>18s}] - Nearest: {nearest[0]} dist={nearest[1]:.1f}")

        # Try to guess the intended corner mapping
        if len(non_black) == 4:
            print(f"\n  Hypothesis: User meant these 4 positions as 'corners':")
            print(f"    Position 1: ({non_black[0][0]:2d},{non_black[0][1]}) - Linear index {non_black[0][2]}")
            print(f"    Position 2: ({non_black[1][0]:2d},{non_black[1][1]}) - Linear index {non_black[1][2]}")
            print(f"    Position 3: ({non_black[2][0]:2d},{non_black[2][1]}) - Linear index {non_black[2][2]}")
            print(f"    Position 4: ({non_black[3][0]:2d},{non_black[3][1]}) - Linear index {non_black[3][2]}")

if __name__ == '__main__':
    main()
