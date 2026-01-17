#!/usr/bin/env python3
"""Analyze animation capture focusing on position encoding."""

import json
import sys

def parse_packet(data_str):
    """Parse hex string to byte array."""
    # Remove any whitespace and split by spaces if present
    hex_str = data_str.replace(' ', '').replace('0x', '')
    return bytes.fromhex(hex_str)

def analyze_init_packet(packet_data):
    """Analyze the init packet (0xa9) for position encoding."""
    if len(packet_data) < 12:
        return None

    opcode = packet_data[0]
    if opcode != 0xa9:
        return None

    # Bytes 8-11 should contain position info
    x = packet_data[8]
    y = packet_data[9]
    width = packet_data[10]
    height = packet_data[11]

    return {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'full_packet': packet_data.hex()
    }

def analyze_data_packet(packet_data, frame_num=None):
    """Analyze data packet (0x29) for pixel colors."""
    if len(packet_data) < 8:
        return None

    opcode = packet_data[0]
    if opcode != 0x29:
        return None

    # Pixel data starts at byte 8
    pixel_data = packet_data[8:]

    # Parse RGB pixels (3 bytes each)
    pixels = []
    for i in range(0, len(pixel_data), 3):
        if i + 2 < len(pixel_data):
            r = pixel_data[i]
            g = pixel_data[i+1]
            b = pixel_data[i+2]
            pixels.append((r, g, b))

    return {
        'frame': frame_num,
        'pixel_count': len(pixels),
        'pixels': pixels,
        'header': packet_data[:8].hex()
    }

def main():
    filename = sys.argv[1] if len(sys.argv) > 1 else \
        '/home/user/PSDynaTab/usbPcap/2026-01-17-animation-4frame-ff-00-00-00-ff-00-00-00-ff-7f-00-00-connected-corners-1pixel-each.json'

    with open(filename, 'r') as f:
        data = json.load(f)

    print("=" * 80)
    print("ANIMATION CAPTURE ANALYSIS - POSITION ENCODING")
    print("=" * 80)
    print()

    # Find init packets
    init_packets = []
    data_packets = []

    for entry in data:
        if 'data' in entry:
            packet_bytes = parse_packet(entry['data'])
            if len(packet_bytes) > 0:
                opcode = packet_bytes[0]

                if opcode == 0xa9:
                    init_info = analyze_init_packet(packet_bytes)
                    if init_info:
                        init_packets.append(init_info)

                elif opcode == 0x29:
                    data_packets.append(packet_bytes)

    # Display init packet information
    print("INIT PACKETS (0xa9) - Position Encoding:")
    print("-" * 80)
    for i, init in enumerate(init_packets):
        print(f"\nInit Packet #{i+1}:")
        print(f"  Position: X={init['x']}, Y={init['y']}")
        print(f"  Size: Width={init['width']}, Height={init['height']}")
        print(f"  Full packet: {init['full_packet']}")

    print("\n" + "=" * 80)
    print("DATA PACKETS (0x29) - Frame-by-Frame Analysis:")
    print("=" * 80)

    # The file name suggests 4 frames, so group by 4
    frames_per_cycle = 4

    for i, packet_data in enumerate(data_packets):
        frame_num = (i % frames_per_cycle) + 1
        cycle_num = i // frames_per_cycle + 1

        info = analyze_data_packet(packet_data, frame_num)
        if info:
            print(f"\nCycle {cycle_num}, Frame {frame_num}:")
            print(f"  Header: {info['header']}")
            print(f"  Pixel count: {info['pixel_count']}")
            print(f"  Colors:")
            for j, (r, g, b) in enumerate(info['pixels']):
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
                    color_name = f"Custom"

                print(f"    Pixel {j}: RGB({r:02x}, {g:02x}, {b:02x}) - {color_name}")

    print("\n" + "=" * 80)
    print("CORNER POSITION MAPPING:")
    print("=" * 80)
    print("\nAssuming 60x9 keyboard (X: 0-59, Y: 0-8):")
    print("  Top-Left corner:     (0, 0)")
    print("  Top-Right corner:    (59, 0)")
    print("  Bottom-Left corner:  (0, 8)")
    print("  Bottom-Right corner: (59, 8)")
    print("\nIf the init packet defines a 4-pixel region, the X,Y,Width,Height")
    print("values should help us understand the pixel addressing scheme.")

if __name__ == '__main__':
    main()
