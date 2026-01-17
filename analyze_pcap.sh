#!/bin/bash
# Quick pcap analysis for HID packets

FILE="$1"

echo "=== Analyzing: $(basename $FILE) ==="
echo "Total packets: $(jq 'length' "$FILE")"

# Find Set_Report packets (bRequest = 9) and their data
echo -e "\n--- Looking for HID Feature Report packets ---"

jq -r '.[] | select(._source.layers."Setup Data"."usb.setup.bRequest" == "9") | 
{
  frame: ._source.layers.frame."frame.number",
  time: ._source.layers.frame."frame.time_relative",  
  data_len: ._source.layers.usb."usb.data_len",
  interface: ._source.layers."Setup Data"."usb.setup.wIndex"
} | @json' "$FILE" | head -20

echo ""
echo "Total Set_Report packets: $(jq '[.[] | select(._source.layers."Setup Data"."usb.setup.bRequest" == "9")] | length' "$FILE")"

