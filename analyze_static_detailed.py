#!/usr/bin/env python3
"""
Detailed analysis of static picture protocol - investigating position encoding
"""

import json
from pathlib import Path

def parse_hex_string(hex_str: str) -> bytes:
    """Parse colon-separated hex string into bytes"""
    return bytes(int(x, 16) for x in hex_str.split(':'))

def analyze_packet_spacing(filename: str):
    """Analyze a specific file in detail"""
    filepath = Path(f'/home/user/PSDynaTab/usbPcap/{filename}')

    with open(filepath, 'r') as f:
        data = json.load(f)

    print(f"\n{'=' * 80}")
    print(f"Detailed analysis: {filename}")
    print('=' * 80)

    init_packet = None
    data_packets = []

    for entry in data:
        try:
            layers = entry['_source']['layers']
            if 'Setup Data' in layers and 'usb.data_fragment' in layers['Setup Data']:
                hex_data = layers['Setup Data']['usb.data_fragment']
                packet_data = parse_hex_string(hex_data)

                if len(packet_data) > 0 and packet_data[0] == 0xa9:
                    init_packet = packet_data
                elif len(packet_data) > 0 and packet_data[0] == 0x29:
                    data_packets.append(packet_data)
        except:
            continue

    if init_packet:
        print("\nINIT PACKET (0xa9):")
        print(f"  Raw bytes: {init_packet.hex(':')}")
        print(f"\n  Byte-by-byte breakdown:")
        print(f"    [0]      = 0x{init_packet[0]:02x} (packet type)")
        print(f"    [1]      = 0x{init_packet[1]:02x}")
        print(f"    [2]      = 0x{init_packet[2]:02x}")
        print(f"    [3]      = 0x{init_packet[3]:02x}")
        print(f"    [4:5]    = 0x{init_packet[4]:02x}{init_packet[5]:02x} = {init_packet[4] | (init_packet[5] << 8)} (LE)")
        print(f"    [6:7]    = 0x{init_packet[6]:02x}{init_packet[7]:02x} = {init_packet[6] | (init_packet[7] << 8)} (LE)")
        print(f"    [8]      = 0x{init_packet[8]:02x} = {init_packet[8]:3d} (X or X-start)")
        print(f"    [9]      = 0x{init_packet[9]:02x} = {init_packet[9]:3d} (Y or Y-start)")
        print(f"    [10]     = 0x{init_packet[10]:02x} = {init_packet[10]:3d} (Width or X-end)")
        print(f"    [11]     = 0x{init_packet[11]:02x} = {init_packet[11]:3d} (Height or Y-end)")

        x = init_packet[8]
        y = init_packet[9]
        w_or_xend = init_packet[10]
        h_or_yend = init_packet[11]

        print(f"\n  Interpretation 1 (Position + Size):")
        print(f"    Top-left: ({x}, {y})")
        print(f"    Size: {w_or_xend}x{h_or_yend}")
        print(f"    Expected pixels: {w_or_xend * h_or_yend}")

        print(f"\n  Interpretation 2 (Bounding Box):")
        print(f"    Top-left: ({x}, {y})")
        print(f"    Bottom-right: ({w_or_xend}, {h_or_yend})")
        width = w_or_xend - x + 1 if w_or_xend >= x else 0
        height = h_or_yend - y + 1 if h_or_yend >= y else 0
        print(f"    Size: {width}x{height}")
        print(f"    Expected pixels: {width * height}")

    print(f"\nDATA PACKETS (0x29): {len(data_packets)} packets")

    total_rgb_triplets = 0
    for i, pkt in enumerate(data_packets):
        rgb_count = (len(pkt) - 8) // 3  # Subtract 8-byte header, divide by 3 for RGB
        total_rgb_triplets += rgb_count

        if i < 3:  # Show first 3 packets in detail
            print(f"\n  Packet {i}:")
            print(f"    Total bytes: {len(pkt)}")
            print(f"    Header: {pkt[:8].hex(':')}")
            print(f"    Index: {pkt[4]}")
            print(f"    Byte[6:7]: 0x{pkt[6]:02x}{pkt[7]:02x}")
            print(f"    RGB triplets: {rgb_count}")
            print(f"    First 3 pixels:")
            for j in range(min(3, rgb_count)):
                offset = 8 + j * 3
                r, g, b = pkt[offset], pkt[offset+1], pkt[offset+2]
                print(f"      [{j}] RGB({r:3d}, {g:3d}, {b:3d}) = #{r:02x}{g:02x}{b:02x}")

    print(f"\n  TOTAL RGB triplets across all data packets: {total_rgb_triplets}")

# Analyze key test cases
print("STATIC PICTURE PROTOCOL - DETAILED POSITION ENCODING ANALYSIS")
print("=" * 80)

analyze_packet_spacing('2026-01-17-picture-topLeft-1pixel-00-ff-00.json')
analyze_packet_spacing('2026-01-17-picture-topRight-1pixel-00-ff-00.json')
analyze_packet_spacing('2026-01-17-picture-bottomLeft-1pixel-00-ff-00.json')
analyze_packet_spacing('2026-01-17-picture-bottomRight-1pixel-00-ff-00.json')
analyze_packet_spacing('2026-01-17-picture-topLeft-ff-00-00-topRight-1pixel-00-ff-00.json')
