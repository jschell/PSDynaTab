#!/usr/bin/env python3
"""Analyze memory addresses from working captures to find the pattern."""

import json
import glob

def extract_address_from_capture(filename):
    """Extract the first data packet address from a capture file."""
    try:
        with open(filename, 'r') as f:
            data = json.load(f)
        
        for packet in data:
            layers = packet.get('_source', {}).get('layers', {})
            
            # Look for HID data
            if 'usbhid.data' in layers:
                hex_data = layers['usbhid.data'].replace(':', '')
                
                # Check if it's a data packet (starts with 29)
                if hex_data.startswith('29'):
                    # Bytes 6-7 are the address (big-endian)
                    addr_high = int(hex_data[12:14], 16)
                    addr_low = int(hex_data[14:16], 16)
                    address = (addr_high << 8) | addr_low
                    return address
    except Exception as e:
        pass
    
    return None

# Analyze all captures
captures = glob.glob('usbPcap/*.json')

results = []
for capture in sorted(captures):
    addr = extract_address_from_capture(capture)
    if addr is not None:
        name = capture.split('/')[-1]
        results.append((name, addr))
        print(f"{name}: 0x{addr:04X} ({addr} decimal)")

if results:
    print("\n=== Address Analysis ===")
    addresses = [addr for _, addr in results]
    print(f"Min: 0x{min(addresses):04X} ({min(addresses)})")
    print(f"Max: 0x{max(addresses):04X} ({max(addresses)})")
    print(f"Range: {max(addresses) - min(addresses)}")
else:
    print("No addresses found in captures")
