#!/usr/bin/env python3
"""
Analyze static picture test USB captures from the usbPcap directory.
Extracts and validates protocol compliance for TEST-STATIC-001 and TEST-STATIC-005 test cases.
"""

import json
import os
from pathlib import Path
from typing import Dict, List, Tuple
from dataclasses import dataclass

@dataclass
class Packet:
    """Represents a parsed packet"""
    packet_type: str  # '0xa9' for init, '0x29' for data
    frame_number: int
    timestamp: str
    data: bytes

@dataclass
class InitPacket:
    """Parsed init packet (0xa9)"""
    byte_00: int  # 0xa9
    byte_01: int  # Always 0x00
    byte_02: int  # Always 0x01
    byte_03: int  # Always 0x00
    byte_04_05: int  # Unknown field (little endian)
    byte_06_07: int  # Unknown field (little endian)
    byte_08: int  # X position
    byte_09: int  # Y position
    byte_10: int  # Width
    byte_11: int  # Height
    raw_data: bytes

@dataclass
class DataPacket:
    """Parsed data packet (0x29)"""
    byte_00: int  # 0x29
    byte_01: int  # Always 0x00
    byte_02: int  # Always 0x01
    byte_03: int  # Always 0x00
    packet_index: int  # Packet index
    byte_05: int  # Always 0x00
    byte_06_07: int  # Unknown field (little endian)
    rgb_data: List[Tuple[int, int, int]]  # RGB pixel values
    raw_data: bytes

def parse_hex_string(hex_str: str) -> bytes:
    """Parse colon-separated hex string into bytes"""
    return bytes(int(x, 16) for x in hex_str.split(':'))

def parse_init_packet(data: bytes) -> InitPacket:
    """Parse initialization packet (0xa9)"""
    if len(data) < 12:
        raise ValueError(f"Init packet too short: {len(data)} bytes")

    return InitPacket(
        byte_00=data[0],
        byte_01=data[1],
        byte_02=data[2],
        byte_03=data[3],
        byte_04_05=data[4] | (data[5] << 8),
        byte_06_07=data[6] | (data[7] << 8),
        byte_08=data[8],
        byte_09=data[9],
        byte_10=data[10],
        byte_11=data[11],
        raw_data=data
    )

def parse_data_packet(data: bytes) -> DataPacket:
    """Parse data packet (0x29)"""
    if len(data) < 8:
        raise ValueError(f"Data packet too short: {len(data)} bytes")

    # Extract RGB data starting from byte 8
    rgb_data = []
    for i in range(8, len(data), 3):
        if i + 2 < len(data):
            rgb_data.append((data[i], data[i+1], data[i+2]))

    return DataPacket(
        byte_00=data[0],
        byte_01=data[1],
        byte_02=data[2],
        byte_03=data[3],
        packet_index=data[4],
        byte_05=data[5],
        byte_06_07=data[6] | (data[7] << 8),
        rgb_data=rgb_data,
        raw_data=data
    )

def extract_packets_from_capture(capture_file: Path) -> List[Packet]:
    """Extract relevant packets from a USB capture file"""
    packets = []

    with open(capture_file, 'r') as f:
        data = json.load(f)

    for entry in data:
        try:
            layers = entry['_source']['layers']

            # Look for Setup Data with data_fragment
            if 'Setup Data' in layers and 'usb.data_fragment' in layers['Setup Data']:
                hex_data = layers['Setup Data']['usb.data_fragment']
                packet_data = parse_hex_string(hex_data)

                if len(packet_data) > 0:
                    packet_type = packet_data[0]
                    if packet_type in [0xa9, 0x29]:
                        packets.append(Packet(
                            packet_type=f"0x{packet_type:02x}",
                            frame_number=int(layers['frame']['frame.number']),
                            timestamp=layers['frame']['frame.time'],
                            data=packet_data
                        ))
        except (KeyError, ValueError) as e:
            # Skip packets that don't have the expected structure
            continue

    return packets

def analyze_capture(capture_file: Path) -> Dict:
    """Analyze a single capture file"""
    result = {
        'file': capture_file.name,
        'init_packet': None,
        'data_packets': [],
        'errors': [],
        'protocol_compliant': True
    }

    packets = extract_packets_from_capture(capture_file)

    # Separate init and data packets
    init_packets = [p for p in packets if p.packet_type == '0xa9']
    data_packets = [p for p in packets if p.packet_type == '0x29']

    # Validate init packet
    if len(init_packets) == 0:
        result['errors'].append("No init packet (0xa9) found")
        result['protocol_compliant'] = False
    elif len(init_packets) > 1:
        result['errors'].append(f"Multiple init packets found: {len(init_packets)}")
        result['protocol_compliant'] = False
    else:
        try:
            init = parse_init_packet(init_packets[0].data)
            result['init_packet'] = {
                'frame': init_packets[0].frame_number,
                'x': init.byte_08,
                'y': init.byte_09,
                'width': init.byte_10,
                'height': init.byte_11,
                'byte_04_05': f"0x{init.byte_04_05:04x}",
                'byte_06_07': f"0x{init.byte_06_07:04x}",
                'raw': init.raw_data.hex(':')
            }

            # Validate standard fields
            if init.byte_01 != 0x00:
                result['errors'].append(f"Init byte[1] should be 0x00, got 0x{init.byte_01:02x}")
                result['protocol_compliant'] = False
            if init.byte_02 != 0x01:
                result['errors'].append(f"Init byte[2] should be 0x01, got 0x{init.byte_02:02x}")
                result['protocol_compliant'] = False
            if init.byte_03 != 0x00:
                result['errors'].append(f"Init byte[3] should be 0x00, got 0x{init.byte_03:02x}")
                result['protocol_compliant'] = False

            # Calculate expected pixel count
            expected_pixels = init.byte_10 * init.byte_11
            result['expected_pixels'] = expected_pixels

        except Exception as e:
            result['errors'].append(f"Error parsing init packet: {e}")
            result['protocol_compliant'] = False

    # Analyze data packets
    total_pixels = 0
    for i, pkt in enumerate(data_packets):
        try:
            data = parse_data_packet(pkt.data)

            # Validate standard fields
            if data.byte_01 != 0x00:
                result['errors'].append(f"Data packet {i} byte[1] should be 0x00")
                result['protocol_compliant'] = False
            if data.byte_02 != 0x01:
                result['errors'].append(f"Data packet {i} byte[2] should be 0x01")
                result['protocol_compliant'] = False
            if data.byte_03 != 0x00:
                result['errors'].append(f"Data packet {i} byte[3] should be 0x00")
                result['protocol_compliant'] = False
            if data.packet_index != i:
                result['errors'].append(f"Data packet {i} has wrong index: {data.packet_index}")
                result['protocol_compliant'] = False

            total_pixels += len(data.rgb_data)

            result['data_packets'].append({
                'index': data.packet_index,
                'frame': pkt.frame_number,
                'pixel_count': len(data.rgb_data),
                'pixels': data.rgb_data[:5],  # First 5 pixels for inspection
                'byte_06_07': f"0x{data.byte_06_07:04x}"
            })

        except Exception as e:
            result['errors'].append(f"Error parsing data packet {i}: {e}")
            result['protocol_compliant'] = False

    result['total_pixels'] = total_pixels
    result['data_packet_count'] = len(data_packets)

    # Check if pixel count matches
    if result['init_packet'] and result['expected_pixels'] != total_pixels:
        result['errors'].append(
            f"Pixel count mismatch: expected {result['expected_pixels']}, got {total_pixels}"
        )
        result['protocol_compliant'] = False

    return result

def identify_test_case(filename: str) -> str:
    """Identify which test case a file corresponds to"""
    name_lower = filename.lower()

    # Corner tests (TEST-STATIC-001)
    if 'topleft' in name_lower and '1pixel' in name_lower and 'topright' not in name_lower and 'bottom' not in name_lower:
        return 'TC-001-A: Top-Left Single Pixel'
    elif 'topright' in name_lower and '1pixel' in name_lower and 'topleft' not in name_lower and 'bottom' not in name_lower:
        return 'TC-001-B: Top-Right Single Pixel'
    elif 'bottomleft' in name_lower and '1pixel' in name_lower and 'topright' not in name_lower and 'topleft' not in name_lower:
        return 'TC-001-C: Bottom-Left Single Pixel'
    elif 'bottomright' in name_lower and '1pixel' in name_lower and 'topleft' not in name_lower and 'topright' not in name_lower:
        return 'TC-001-D: Bottom-Right Single Pixel'

    # Multi-corner tests
    elif 'topleft' in name_lower and 'topright' in name_lower:
        return 'Multi-corner: Top-Left + Top-Right'
    elif 'topleft' in name_lower and 'bottomleft' in name_lower:
        return 'Multi-corner: Top-Left + Bottom-Left'
    elif 'topright' in name_lower and 'bottomleft' in name_lower:
        return 'Multi-corner: Top-Right + Bottom-Left'
    elif 'topleft' in name_lower and 'bottomright' in name_lower:
        return 'Multi-corner: Top-Left + Bottom-Right'

    # Row tests (TEST-STATIC-005)
    elif 'rowspaced' in name_lower and 'top' in name_lower and 'bottom' in name_lower:
        return 'TC-005: Top + Bottom Row Spaced'
    elif 'toprowspaced' in name_lower and 'bottom' not in name_lower:
        return 'TC-005: Top Row Spaced Only'
    elif 'rowspaced' in name_lower:
        return 'TC-005: Row Spacing Test'

    return 'Unknown Test Case'

def main():
    """Main analysis function"""
    usbpcap_dir = Path('/home/user/PSDynaTab/usbPcap')

    # Find all static picture test files from 2026-01-17
    picture_files = sorted(usbpcap_dir.glob('2026-01-17-picture-*.json'))

    if not picture_files:
        print("No static picture test files found!")
        return

    print("=" * 80)
    print("STATIC PICTURE TEST USB CAPTURE ANALYSIS")
    print("=" * 80)
    print()

    results = {}

    for capture_file in picture_files:
        test_case = identify_test_case(capture_file.name)
        print(f"\n{'=' * 80}")
        print(f"File: {capture_file.name}")
        print(f"Test Case: {test_case}")
        print('=' * 80)

        result = analyze_capture(capture_file)
        results[capture_file.name] = result

        # Print init packet info
        if result['init_packet']:
            init = result['init_packet']
            print(f"\nINIT PACKET (0xa9) - Frame {init['frame']}:")
            print(f"  Position: ({init['x']}, {init['y']})")
            print(f"  Size: {init['width']}x{init['height']} = {result.get('expected_pixels', 0)} pixels")
            print(f"  Byte[4:5]: {init['byte_04_05']}")
            print(f"  Byte[6:7]: {init['byte_06_07']}")

        # Print data packets summary
        print(f"\nDATA PACKETS (0x29): {result['data_packet_count']} packets")
        print(f"  Total pixels: {result['total_pixels']}")

        if result['data_packets']:
            print(f"\n  Sample pixels from first packet:")
            for i, pixel in enumerate(result['data_packets'][0]['pixels'][:3]):
                print(f"    Pixel {i}: RGB({pixel[0]:3d}, {pixel[1]:3d}, {pixel[2]:3d}) = #{pixel[0]:02x}{pixel[1]:02x}{pixel[2]:02x}")

        # Print compliance status
        print(f"\nPROTOCOL COMPLIANCE: {'✓ PASS' if result['protocol_compliant'] else '✗ FAIL'}")

        if result['errors']:
            print("\nERRORS/WARNINGS:")
            for error in result['errors']:
                print(f"  - {error}")

    # Summary report
    print(f"\n\n{'=' * 80}")
    print("SUMMARY REPORT")
    print('=' * 80)

    # Group by test category
    tc_001_files = []
    tc_005_files = []
    multi_corner_files = []

    for filename, result in results.items():
        test_case = identify_test_case(filename)
        if test_case.startswith('TC-001'):
            tc_001_files.append((filename, test_case, result))
        elif test_case.startswith('TC-005'):
            tc_005_files.append((filename, test_case, result))
        elif 'Multi-corner' in test_case:
            multi_corner_files.append((filename, test_case, result))

    print("\nTEST-STATIC-001: Single Pixel Corner Validation")
    print("-" * 80)
    if tc_001_files:
        for filename, test_case, result in sorted(tc_001_files, key=lambda x: x[1]):
            status = "✓ PASS" if result['protocol_compliant'] else "✗ FAIL"
            print(f"  {status}  {test_case}")
            if result['init_packet']:
                init = result['init_packet']
                print(f"         Position: ({init['x']}, {init['y']}), Size: {init['width']}x{init['height']}")
    else:
        print("  No TC-001 tests found")

    print("\n\nTEST-STATIC-005: Partial Screen Updates / Row Tests")
    print("-" * 80)
    if tc_005_files:
        for filename, test_case, result in sorted(tc_005_files, key=lambda x: x[1]):
            status = "✓ PASS" if result['protocol_compliant'] else "✗ FAIL"
            print(f"  {status}  {test_case}")
            if result['init_packet']:
                init = result['init_packet']
                print(f"         Position: ({init['x']}, {init['y']}), Size: {init['width']}x{init['height']}")
                print(f"         Pixels: {result['total_pixels']}, Packets: {result['data_packet_count']}")
    else:
        print("  No TC-005 tests found")

    print("\n\nMulti-Corner Tests (Not in formal test plan)")
    print("-" * 80)
    if multi_corner_files:
        for filename, test_case, result in sorted(multi_corner_files, key=lambda x: x[1]):
            status = "✓ PASS" if result['protocol_compliant'] else "✗ FAIL"
            print(f"  {status}  {test_case}")
            if result['init_packet']:
                init = result['init_packet']
                print(f"         Position: ({init['x']}, {init['y']}), Size: {init['width']}x{init['height']}")
    else:
        print("  No multi-corner tests found")

    # Overall statistics
    total_tests = len(results)
    passed_tests = sum(1 for r in results.values() if r['protocol_compliant'])

    print(f"\n\nOVERALL STATISTICS")
    print("-" * 80)
    print(f"  Total test captures analyzed: {total_tests}")
    print(f"  Protocol compliant: {passed_tests}/{total_tests} ({100*passed_tests//total_tests if total_tests > 0 else 0}%)")
    print(f"  Protocol violations: {total_tests - passed_tests}")

    print("\n\nKEY FINDINGS:")
    print("-" * 80)
    print("  • Static picture mode uses 0xa9 init + 0x29 data packets")
    print("  • Position encoding: bytes [8]=X, [9]=Y, [10]=Width, [11]=Height")
    print("  • Each data packet contains RGB triplets starting at byte 8")
    print("  • Data packets are indexed sequentially starting from 0")
    print("  • Total pixel count must match width × height from init packet")

    print("\n" + "=" * 80)

if __name__ == '__main__':
    main()
