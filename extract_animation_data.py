#!/usr/bin/env python3
"""Extract and analyze animation data from Wireshark JSON."""

import json
import re
import sys

def parse_hex_fragment(fragment_str):
    """Parse colon-separated hex string to bytes."""
    return bytes.fromhex(fragment_str.replace(':', ''))

def analyze_init_packet(packet_data):
    """Analyze the init packet (0xa9) for position encoding."""
    if len(packet_data) < 12:
        return None

    opcode = packet_data[0]
    if opcode != 0xa9:
        return None

    return {
        'opcode': f'0x{opcode:02x}',
        'byte1': f'0x{packet_data[1]:02x}',
        'byte2': f'0x{packet_data[2]:02x}',
        'byte3': f'0x{packet_data[3]:02x}',
        'byte4': f'0x{packet_data[4]:02x}',
        'byte5': f'0x{packet_data[5]:02x}',
        'byte6': f'0x{packet_data[6]:02x}',
        'byte7': f'0x{packet_data[7]:02x}',
        'x_pos': packet_data[8],
        'y_pos': packet_data[9],
        'width': packet_data[10],
        'height': packet_data[11],
        'full_hex': packet_data.hex(':')
    }

def analyze_data_packet(packet_data):
    """Analyze data packet (0x29) for pixel colors."""
    if len(packet_data) < 8:
        return None

    opcode = packet_data[0]
    if opcode != 0x29:
        return None

    # Header bytes
    header = {
        'opcode': f'0x{packet_data[0]:02x}',
        'byte1': f'0x{packet_data[1]:02x}',
        'byte2': f'0x{packet_data[2]:02x}',
        'byte3': f'0x{packet_data[3]:02x}',
        'byte4': f'0x{packet_data[4]:02x}',
        'byte5': f'0x{packet_data[5]:02x}',
        'byte6': f'0x{packet_data[6]:02x}',
        'byte7': f'0x{packet_data[7]:02x}',
    }

    # Pixel data starts at byte 8
    pixel_data = packet_data[8:]

    # Parse RGB pixels (3 bytes each)
    pixels = []
    for i in range(0, len(pixel_data), 3):
        if i + 2 < len(pixel_data):
            r = pixel_data[i]
            g = pixel_data[i+1]
            b = pixel_data[i+2]

            # Skip all-black pixels
            if r != 0 or g != 0 or b != 0:
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
                    color_name = "Other"

                pixels.append({
                    'position': i // 3,
                    'r': r,
                    'g': g,
                    'b': b,
                    'name': color_name
                })

    return {
        'header': header,
        'pixels': pixels
    }

def main():
    filename = sys.argv[1] if len(sys.argv) > 1 else \
        '/home/user/PSDynaTab/usbPcap/2026-01-17-animation-4frame-ff-00-00-00-ff-00-00-00-ff-7f-00-00-connected-corners-1pixel-each.json'

    # Extract data fragments from JSON
    data_fragments = []

    with open(filename, 'r') as f:
        content = f.read()
        # Find all usb.data_fragment entries
        fragments = re.findall(r'"usb\.data_fragment":\s*"([^"]+)"', content)
        data_fragments = fragments

    print("=" * 80)
    print("ANIMATION CAPTURE ANALYSIS - POSITION ENCODING")
    print("=" * 80)
    print(f"\nFound {len(data_fragments)} data fragments")
    print()

    # Parse and categorize packets
    init_packets = []
    data_packets = []

    for frag in data_fragments:
        packet_bytes = parse_hex_fragment(frag)
        if len(packet_bytes) > 0:
            opcode = packet_bytes[0]

            if opcode == 0xa9:
                init_info = analyze_init_packet(packet_bytes)
                if init_info:
                    init_packets.append(init_info)

            elif opcode == 0x29:
                data_info = analyze_data_packet(packet_bytes)
                if data_info:
                    data_packets.append(data_info)

    # Display init packet information
    print("INIT PACKETS (0xa9) - Position Encoding:")
    print("=" * 80)
    for i, init in enumerate(init_packets):
        print(f"\nInit Packet #{i+1}:")
        print(f"  Bytes 0-7:  {init['opcode']} {init['byte1']} {init['byte2']} {init['byte3']} {init['byte4']} {init['byte5']} {init['byte6']} {init['byte7']}")
        print(f"  Bytes 8-11: X={init['x_pos']}, Y={init['y_pos']}, Width={init['width']}, Height={init['height']}")
        print(f"  Full packet: {init['full_hex']}")

    # Calculate corner positions
    if init_packets:
        init = init_packets[0]
        x = init['x_pos']
        y = init['y_pos']
        w = init['width']
        h = init['height']

        print(f"\n  Corner Coordinates (based on X={x}, Y={y}, W={w}, H={h}):")
        if w > 0 and h > 0:
            print(f"    Top-Left:     ({x}, {y})")
            print(f"    Top-Right:    ({x + w - 1}, {y})")
            print(f"    Bottom-Left:  ({x}, {y + h - 1})")
            print(f"    Bottom-Right: ({x + w - 1}, {y + h - 1})")

    print("\n" + "=" * 80)
    print("DATA PACKETS (0x29) - Frame-by-Frame Color Analysis:")
    print("=" * 80)

    for i, packet in enumerate(data_packets):
        print(f"\nData Packet #{i+1}:")
        h = packet['header']
        print(f"  Header: {h['opcode']} {h['byte1']} {h['byte2']} {h['byte3']} {h['byte4']} {h['byte5']} {h['byte6']} {h['byte7']}")
        print(f"  Non-black pixels: {len(packet['pixels'])}")

        if packet['pixels']:
            print(f"  Colors found:")
            for p in packet['pixels']:
                print(f"    Position {p['position']:2d}: RGB({p['r']:02x}, {p['g']:02x}, {p['b']:02x}) = {p['name']}")

    print("\n" + "=" * 80)
    print("COLOR ROTATION PATTERN:")
    print("=" * 80)

    # Group into frames (assuming 4 frames based on filename)
    print("\nAssuming 4-pixel region with colors rotating across 4 frames:")
    for i, packet in enumerate(data_packets):
        frame_num = (i % 4) + 1
        cycle_num = i // 4 + 1

        print(f"\n  Cycle {cycle_num}, Frame {frame_num}:")
        if packet['pixels']:
            for p in packet['pixels']:
                print(f"    Pixel position {p['position']:2d}: {p['name']}")

if __name__ == '__main__':
    main()
