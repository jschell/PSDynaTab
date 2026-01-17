#!/usr/bin/env python3
"""
Detailed analysis of packet structure to understand pixel position encoding.
"""

import json
import os

def parse_hex_data(hex_string):
    """Convert colon-separated hex string to list of integers."""
    return [int(x, 16) for x in hex_string.split(':')]

def analyze_packet_structure(filepath):
    """Analyze packet structure in detail."""
    with open(filepath, 'r') as f:
        data = json.load(f)

    filename = os.path.basename(filepath)
    print(f"\n{'='*100}")
    print(f"File: {filename}")
    print(f"{'='*100}")

    set_report_packets = []

    for packet in data:
        try:
            layers = packet['_source']['layers']
            if 'Setup Data' in layers:
                setup = layers['Setup Data']
                if 'usbhid.setup.bRequest' in setup and setup['usbhid.setup.bRequest'] == '0x09':
                    if 'usb.data_fragment' in setup:
                        hex_data = setup['usb.data_fragment']
                        data_bytes = parse_hex_data(hex_data)
                        set_report_packets.append(data_bytes)
        except (KeyError, ValueError):
            continue

    # Analyze each packet
    for i, data_bytes in enumerate(set_report_packets):
        if len(data_bytes) < 64:
            continue

        cmd = data_bytes[0]
        pkt_low = data_bytes[2]
        pkt_high = data_bytes[3]
        pkt_num = (pkt_high << 8) | pkt_low

        # Memory address (little endian)
        addr = (data_bytes[7] << 24) | (data_bytes[6] << 16) | (data_bytes[5] << 8) | data_bytes[4]

        print(f"\nPacket {i}: Cmd=0x{cmd:02x}, PktNum={pkt_num}, Addr=0x{addr:08x}")

        # Show first 20 bytes in hex
        hex_view = ' '.join(f'{b:02x}' for b in data_bytes[:20])
        print(f"  First 20 bytes: {hex_view}")

        # Decode based on command type
        if cmd == 0xa9:  # Start/header packet
            print("  Type: START/HEADER packet")
            print(f"    Bytes [0-1]: {data_bytes[0]:02x} {data_bytes[1]:02x} (cmd + reserved)")
            print(f"    Bytes [2-3]: {data_bytes[2]:02x} {data_bytes[3]:02x} (packet counter = {pkt_num})")
            print(f"    Bytes [4-7]: {data_bytes[4]:02x} {data_bytes[5]:02x} {data_bytes[6]:02x} {data_bytes[7]:02x} (address = 0x{addr:08x})")

            # Check if there's image dimension info
            if len(data_bytes) >= 12:
                dim1 = data_bytes[8]
                dim2 = data_bytes[9]
                dim3 = data_bytes[10]
                dim4 = data_bytes[11]
                print(f"    Bytes [8-11]: {dim1:02x} {dim2:02x} {dim3:02x} {dim4:02x} (possibly dimensions: {dim1}x{dim2}, {dim3}x{dim4})")

        elif cmd == 0x29:  # Data packet
            print("  Type: DATA packet")
            print(f"    Bytes [0-1]: {data_bytes[0]:02x} {data_bytes[1]:02x} (cmd + reserved)")
            print(f"    Bytes [2-3]: {data_bytes[2]:02x} {data_bytes[3]:02x} (packet counter = {pkt_num})")
            print(f"    Bytes [4-7]: {data_bytes[4]:02x} {data_bytes[5]:02x} {data_bytes[6]:02x} {data_bytes[7]:02x} (address = 0x{addr:08x})")

            # Look for RGB pixel data starting at byte 8
            print("    Pixel data (RGB triplets):")
            non_zero_pixels = []
            for j in range(8, len(data_bytes) - 2, 3):
                r, g, b = data_bytes[j], data_bytes[j+1], data_bytes[j+2]
                if r != 0 or g != 0 or b != 0:
                    pixel_pos = (j - 8) // 3
                    non_zero_pixels.append((pixel_pos, r, g, b))
                    if len(non_zero_pixels) <= 10:  # Show first 10 non-zero pixels
                        print(f"      Pixel {pixel_pos}: RGB({r:3d}, {g:3d}, {b:3d}) at bytes [{j}:{j+3}]")

            if len(non_zero_pixels) > 10:
                print(f"      ... and {len(non_zero_pixels) - 10} more non-zero pixels")

        # Show last 8 bytes (might contain checksum or terminator)
        print(f"  Last 8 bytes: {' '.join(f'{b:02x}' for b in data_bytes[-8:])}")

    print(f"\nTotal Set_Report packets: {len(set_report_packets)}")

# Analyze key files
files = [
    '/home/user/PSDynaTab/usbPcap/2026-01-17-picture-topLeft-1pixel-00-ff-00.json',
    '/home/user/PSDynaTab/usbPcap/2026-01-17-picture-topRight-1pixel-00-ff-00.json',
    '/home/user/PSDynaTab/usbPcap/2026-01-17-picture-bottomLeft-1pixel-00-ff-00.json',
    '/home/user/PSDynaTab/usbPcap/2026-01-17-picture-topLeft-00-ff-00-bottomLeft-ff-00-00.json',
    '/home/user/PSDynaTab/usbPcap/2026-01-17-picture-topRowSpaced-15pixel-ff-00-00.json',
]

for filepath in files:
    analyze_packet_structure(filepath)
