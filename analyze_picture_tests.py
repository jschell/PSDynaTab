#!/usr/bin/env python3
"""
Analyze USB capture files from picture position tests.
Extract pixel position mapping data to understand keyboard layout.
"""

import json
import glob
import os
from collections import defaultdict

def parse_hex_data(hex_string):
    """Convert colon-separated hex string to list of integers."""
    return [int(x, 16) for x in hex_string.split(':')]

def analyze_capture(filepath):
    """Analyze a single USB capture file."""
    with open(filepath, 'r') as f:
        data = json.load(f)

    filename = os.path.basename(filepath)
    result = {
        'filename': filename,
        'set_reports': [],
        'get_reports': [],
        'data_packets': 0,
        'protocol_correct': True
    }

    for packet in data:
        try:
            layers = packet['_source']['layers']

            # Check for Setup Data (control transfers)
            if 'Setup Data' in layers:
                setup = layers['Setup Data']

                # Set_Report (0x09)
                if 'usbhid.setup.bRequest' in setup and setup['usbhid.setup.bRequest'] == '0x09':
                    if 'usb.data_fragment' in setup:
                        hex_data = setup['usb.data_fragment']
                        data_bytes = parse_hex_data(hex_data)

                        # Extract key information
                        # Byte 0: Command (0xa9 = start, 0x29 = data packet)
                        # Bytes 2-3: Packet counter
                        # Bytes 4-7: Memory address (little endian)

                        if len(data_bytes) >= 12:
                            cmd = data_bytes[0]
                            pkt_num = (data_bytes[3] << 8) | data_bytes[2]
                            addr_bytes = data_bytes[4:8]
                            addr = (addr_bytes[3] << 24) | (addr_bytes[2] << 16) | (addr_bytes[1] << 8) | addr_bytes[0]

                            # Look for RGB data (starts after address info)
                            rgb_start = 8
                            pixel_data = []
                            for i in range(rgb_start, min(len(data_bytes), 64), 3):
                                if i+2 < len(data_bytes):
                                    r, g, b = data_bytes[i], data_bytes[i+1], data_bytes[i+2]
                                    if r != 0 or g != 0 or b != 0:  # Non-black pixel
                                        pixel_data.append((r, g, b, i-rgb_start))

                            result['set_reports'].append({
                                'cmd': f'0x{cmd:02x}',
                                'packet_num': pkt_num,
                                'address': f'0x{addr:08x}',
                                'pixels': pixel_data,
                                'raw': hex_data
                            })

                            if cmd == 0x29:  # Data packet
                                result['data_packets'] += 1

                # Get_Report (0x01) - verify fixed protocol
                elif 'usbhid.setup.bRequest' in setup and setup['usbhid.setup.bRequest'] == '0x01':
                    result['get_reports'].append({
                        'bmRequestType': setup.get('usb.bmRequestType', ''),
                        'wValue': setup.get('usbhid.setup.wValue', '')
                    })

        except (KeyError, ValueError) as e:
            continue

    # Check if protocol is correct (should have Get_Report requests)
    result['protocol_correct'] = len(result['get_reports']) > 0

    return result

def main():
    # Find all picture test files from 2026-01-17
    pattern = '/home/user/PSDynaTab/usbPcap/2026-01-17-picture-*.json'
    files = sorted(glob.glob(pattern))

    print(f"Found {len(files)} picture test captures\n")
    print("=" * 100)

    for filepath in files:
        result = analyze_capture(filepath)

        print(f"\n{result['filename']}")
        print(f"  Data packets: {result['data_packets']}")
        print(f"  Set_Report count: {len(result['set_reports'])}")
        print(f"  Get_Report count: {len(result['get_reports'])}")
        print(f"  Protocol correct: {result['protocol_correct']}")

        # Show first few packets with pixel data
        packets_with_pixels = [p for p in result['set_reports'] if p['pixels']]
        if packets_with_pixels:
            print(f"  Packets with pixel data: {len(packets_with_pixels)}")
            for i, pkt in enumerate(packets_with_pixels[:3]):  # Show first 3
                print(f"    Packet {pkt['packet_num']}: addr={pkt['address']}, pixels={pkt['pixels']}")

        # Show memory address range
        if result['set_reports']:
            addresses = [int(p['address'], 16) for p in result['set_reports'] if p['address'] != '0x00000000']
            if addresses:
                min_addr = min(addresses)
                max_addr = max(addresses)
                print(f"  Address range: 0x{min_addr:08x} - 0x{max_addr:08x} (span: {max_addr - min_addr} bytes)")

    print("\n" + "=" * 100)
    print("\nSummary of findings:")
    print("-" * 100)

    # Group files by test type
    single_pixel_files = [f for f in files if '1pixel' in os.path.basename(f) and '-00-ff-00-' not in os.path.basename(f)]
    two_pixel_files = [f for f in files if ('-00-ff-00-' in os.path.basename(f) or '-ff-00-00-' in os.path.basename(f)) and 'RowSpaced' not in os.path.basename(f)]
    row_spaced_files = [f for f in files if 'RowSpaced' in os.path.basename(f)]

    print(f"\nSingle pixel corner tests: {len(single_pixel_files)}")
    print(f"Two-pixel tests: {len(two_pixel_files)}")
    print(f"Row-spaced tests: {len(row_spaced_files)}")

    # Analyze pixel positions for layout mapping
    print("\n" + "=" * 100)
    print("Pixel Position Analysis:")
    print("-" * 100)

    for test_type, files_group in [('Single Pixel', single_pixel_files),
                                     ('Two Pixel', two_pixel_files),
                                     ('Row Spaced', row_spaced_files)]:
        if not files_group:
            continue
        print(f"\n{test_type} Tests:")
        for filepath in files_group:
            result = analyze_capture(filepath)
            name = os.path.basename(filepath).replace('2026-01-17-picture-', '').replace('.json', '')

            # Find unique pixel positions and colors
            pixel_info = defaultdict(list)
            for pkt in result['set_reports']:
                if pkt['pixels']:
                    addr = int(pkt['address'], 16)
                    for r, g, b, offset in pkt['pixels']:
                        pixel_info[f'RGB({r},{g},{b})'].append((addr, offset))

            if pixel_info:
                print(f"  {name}:")
                for color, positions in pixel_info.items():
                    print(f"    {color}: {len(positions)} occurrences")
                    if len(positions) <= 5:  # Show details for small sets
                        for addr, offset in positions:
                            print(f"      addr=0x{addr:08x} offset={offset}")

if __name__ == '__main__':
    main()
