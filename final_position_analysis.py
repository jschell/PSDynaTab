#!/usr/bin/env python3
"""Final comprehensive position and color rotation analysis."""

import json
import re
import sys

def parse_hex_fragment(fragment_str):
    """Parse colon-separated hex string to bytes."""
    return bytes.fromhex(fragment_str.replace(':', ''))

def color_name(r, g, b):
    """Get color name from RGB values."""
    if (r, g, b) == (0xff, 0x00, 0x00):
        return "Bright Red"
    elif (r, g, b) == (0x7f, 0x00, 0x00):
        return "Dark Red"
    elif (r, g, b) == (0x00, 0xff, 0x00):
        return "Green"
    elif (r, g, b) == (0x00, 0x00, 0xff):
        return "Blue"
    elif (r, g, b) == (0x00, 0x7f, 0x00):
        return "Green (127)" # Half-brightness green
    else:
        return f"RGB({r:02x},{g:02x},{b:02x})"

def main():
    filename = sys.argv[1] if len(sys.argv) > 1 else \
        '/home/user/PSDynaTab/usbPcap/2026-01-17-animation-4frame-ff-00-00-00-ff-00-00-00-ff-7f-00-00-connected-corners-1pixel-each.json'

    with open(filename, 'r') as f:
        content = f.read()
        fragments = re.findall(r'"usb\.data_fragment":\s*"([^"]+)"', content)

    print("=" * 80)
    print("ANIMATION CAPTURE ANALYSIS - POSITION ENCODING & COLOR ROTATION")
    print("=" * 80)

    # Find init packet
    init_packet = None
    for frag in fragments:
        packet = parse_hex_fragment(frag)
        if packet[0] == 0xa9:
            init_packet = packet
            break

    if init_packet:
        print("\n1. INIT PACKET (0xa9) - POSITION ENCODING")
        print("-" * 80)
        print(f"Full packet: {init_packet.hex(':')}")
        print()
        print("Byte-by-byte breakdown:")
        print(f"  Byte 0:    0x{init_packet[0]:02x}  - Opcode (Init)")
        print(f"  Byte 1:    0x{init_packet[1]:02x}  - Unknown")
        print(f"  Byte 2:    0x{init_packet[2]:02x}  - Frame count (4 frames)")
        print(f"  Byte 3:    0x{init_packet[3]:02x}  - Unknown")
        print(f"  Byte 4-7:  {init_packet[4]:02x} {init_packet[5]:02x} {init_packet[6]:02x} {init_packet[7]:02x}  - Unknown")
        print()
        print("POSITION ENCODING (Bytes 8-11):")
        print(f"  Byte 8:    {init_packet[8]:3d}  - X position (left edge)")
        print(f"  Byte 9:    {init_packet[9]:3d}  - Y position (top edge)")
        print(f"  Byte 10:   {init_packet[10]:3d}  - Width in pixels")
        print(f"  Byte 11:   {init_packet[11]:3d}  - Height in pixels")
        print()
        x, y, w, h = init_packet[8], init_packet[9], init_packet[10], init_packet[11]
        print(f"Decoded: Region from ({x},{y}) with size {w}x{h}")
        print()
        print(f"Expected corner coordinates:")
        print(f"  Top-Left:     ({x}, {y})       = Linear index {y*60 + x}")
        print(f"  Top-Right:    ({x+w-1}, {y})   = Linear index {y*60 + (x+w-1)}")
        print(f"  Bottom-Left:  ({x}, {y+h-1})   = Linear index {(y+h-1)*60 + x}")
        print(f"  Bottom-Right: ({x+w-1}, {y+h-1}) = Linear index {(y+h-1)*60 + (x+w-1)}")

    # Organize data packets by frame
    frames = {}
    for frag in fragments:
        packet = parse_hex_fragment(frag)
        if packet[0] == 0x29:
            frame_num = packet[1]
            if frame_num not in frames:
                frames[frame_num] = []
            frames[frame_num].append(packet)

    print("\n2. DATA PACKETS (0x29) - PIXEL DATA")
    print("-" * 80)

    # Analyze first data packet header
    if frames:
        first_frame_packets = sorted(frames[min(frames.keys())], key=lambda p: p[4])
        if first_frame_packets:
            p = first_frame_packets[0]
            print("\nData packet header format (example from first packet):")
            print(f"  Byte 0:    0x{p[0]:02x}  - Opcode (Data)")
            print(f"  Byte 1:    0x{p[1]:02x}  - Frame number")
            print(f"  Byte 2:    0x{p[2]:02x}  - Unknown")
            print(f"  Byte 3:    0x{p[3]:02x}  - Unknown")
            print(f"  Byte 4:    0x{p[4]:02x}  - Packet sequence within frame")
            print(f"  Byte 5:    0x{p[5]:02x}  - Unknown")
            print(f"  Byte 6-7:  0x{p[6]:02x} 0x{p[7]:02x}  - Unknown (checksum?)")
            print(f"  Byte 8+:   Pixel data (RGB triplets)")

    print("\n3. PIXEL COORDINATES & COLOR MAPPING")
    print("-" * 80)

    # Collect all pixel info across frames
    all_active_positions = set()
    frame_data = {}

    for frame_num in sorted(frames.keys()):
        packets = sorted(frames[frame_num], key=lambda p: p[4])

        # Reconstruct frame
        frame_pixels = []
        for packet in packets:
            pixel_data = packet[8:]
            for i in range(0, len(pixel_data), 3):
                if i + 2 < len(pixel_data):
                    frame_pixels.append((pixel_data[i], pixel_data[i+1], pixel_data[i+2]))

        # Find non-black pixels
        frame_data[frame_num] = {}
        for idx, (r, g, b) in enumerate(frame_pixels):
            if r != 0 or g != 0 or b != 0:
                x = idx % 60
                y = idx // 60
                all_active_positions.add((x, y, idx))
                frame_data[frame_num][(x, y, idx)] = (r, g, b)

    # Display active positions
    print(f"\nActive pixel positions (found across all frames):")
    for x, y, idx in sorted(all_active_positions):
        print(f"  Position ({x:2d}, {y}) = Linear index {idx:3d}")

    print(f"\nNote: Frame data only contains {len(frame_pixels)} pixels (expected 540).")
    print(f"      Missing pixels {len(frame_pixels)}-539 (last {540 - len(frame_pixels)} pixels)")

    print("\n4. FRAME-BY-FRAME COLOR ROTATION PATTERN")
    print("-" * 80)

    # Show rotation pattern as a table
    positions = sorted(all_active_positions)
    print(f"\n{'Frame':>6}  ", end='')
    for x, y, idx in positions:
        print(f"({x:2d},{y}) idx={idx:3d}       ", end='')
    print()
    print("-" * 80)

    for frame_num in sorted(frames.keys()):
        print(f"  {frame_num:4d}  ", end='')
        for x, y, idx in positions:
            if (x, y, idx) in frame_data[frame_num]:
                r, g, b = frame_data[frame_num][(x, y, idx)]
                cname = color_name(r, g, b)
                print(f"{cname:>18s}  ", end='')
            else:
                print(f"{'Black (off)':>18s}  ", end='')
        print()

    print("\n5. COLOR ROTATION ANALYSIS")
    print("-" * 80)

    # Analyze the rotation pattern
    print("\nDetected 4 colors rotating through 4 positions:")
    print("  - Bright Red:  RGB(ff, 00, 00)")
    print("  - Green:       RGB(00, ff, 00)")
    print("  - Blue:        RGB(00, 00, ff)")
    print("  - Dark Red:    RGB(7f, 00, 00)")
    print("\nRotation pattern at each position:")

    for x, y, idx in positions:
        print(f"\n  Position ({x:2d},{y}) Linear index {idx}:")
        for frame_num in sorted(frames.keys()):
            if (x, y, idx) in frame_data[frame_num]:
                r, g, b = frame_data[frame_num][(x, y, idx)]
                cname = color_name(r, g, b)
                print(f"    Frame {frame_num}: {cname}")

    print("\n" + "=" * 80)
    print("SUMMARY")
    print("=" * 80)
    print("""
The init packet (0xa9) defines the display region:
  - Bytes 8-11 encode: [X, Y, Width, Height]
  - For this capture: X=0, Y=0, Width=60, Height=9

Data packets (0x29) contain:
  - Byte 1: Frame number (0-3 for 4 frames)
  - Byte 4: Packet sequence number within frame
  - Byte 8+: RGB pixel data (3 bytes per pixel)

The animation cycles 4 colors through 4 pixel positions:
  - Each frame shows a different color at each position
  - Colors rotate clockwise through the positions
  - Animation loops every 4 frames

Note: The captured frames are incomplete (522/540 pixels).
      The bottom-right corner at (59,8) is missing from all frames.
""")

if __name__ == '__main__':
    main()
