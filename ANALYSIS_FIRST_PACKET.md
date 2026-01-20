# Analysis: Python Library FIRST_PACKET vs Our Test Scripts

## Python Library FIRST_PACKET

From the code:
```python
FIRST_PACKET = bytes.fromhex(
    "a9000100540600fb00003c09" + "00" * 52
)
```

Breaking down the hex:
```
a9 00 01 00 54 06 00 fb 00 00 3c 09 [00 × 52]
│  │  │  │  │     │  │  │  │  │  │
│  │  │  │  │     │  │  │  │  │  └─ Y-end = 9
│  │  │  │  │     │  │  │  │  └──── X-end = 60 (0x3C)
│  │  │  │  │     │  │  │  └─────── Y-start = 0
│  │  │  │  │     │  │  └────────── X-start = 0
│  │  │  │  │     │  └───────────── Checksum = 0xFB
│  │  │  │  │     └──────────────── Reserved = 0x00
│  │  │  │  └────────────────────── Data bytes = 0x0654 (1620 = 540 × 3)
│  │  │  └───────────────────────── Delay = 0x00
│  │  └──────────────────────────── Frame count = 1
│  └─────────────────────────────── Mode = 0x00
└────────────────────────────────── Type = 0xa9
```

**This is for FULL DISPLAY (60×9 = 540 pixels).**

## Our Test-1C Init Packet (1 Pixel at 0,0)

```powershell
$packet[0] = 0xa9
$packet[1] = 0x00
$packet[2] = 0x01
$packet[3] = 0x00
$packet[4] = 0x03  # 1 pixel = 3 bytes
$packet[5] = 0x00
$packet[6] = 0x00
$packet[7] = Calculate-Checksum  # Should be 0x52
$packet[8] = 0x00   # X-start
$packet[9] = 0x00   # Y-start
$packet[10] = 0x01  # X-end
$packet[11] = 0x01  # Y-end
```

Breaking down:
```
a9 00 01 00 03 00 00 52 00 00 01 01 [00 × 52]
│  │  │  │  │     │  │  │  │  │  │
│  │  │  │  │     │  │  │  │  │  └─ Y-end = 1 (NOT 9!)
│  │  │  │  │     │  │  │  │  └──── X-end = 1 (NOT 60!)
│  │  │  │  │     │  │  │  └─────── Y-start = 0
│  │  │  │  │     │  │  └────────── X-start = 0
│  │  │  │  │     │  └───────────── Checksum = 0x52
│  │  │  │  │     └──────────────── Reserved = 0x00
│  │  │  │  └────────────────────── Data bytes = 0x0003 (3 = 1 × 3)
│  │  │  └───────────────────────── Delay = 0x00
│  │  └──────────────────────────── Frame count = 1
│  └─────────────────────────────── Mode = 0x00
└────────────────────────────────── Type = 0xa9
```

**This is for PARTIAL DISPLAY (1×1 = 1 pixel).**

## Key Observation

**The Python library ALWAYS sends full display init packet** even if the image is smaller. It doesn't use bounding boxes for partial regions!

Let me verify this...

## Python Library Behavior

Looking at `send_image()`:
1. Calls `_encode_image()` which **always resizes to (60, 9)**
2. Sends `FIRST_PACKET` which is **hardcoded for full display**
3. Never modifies bounding box bytes (8-11)

**The Python library does NOT support partial bounding boxes for static images!**

## Working Capture Analysis

Your working capture showed:
```
Init: a9 00 01 00 03 00 00 52 00 00 01 01
Data: 29 00 01 00 00 00 03 d2 00 ff 00 ...
```

This HAS partial bounding box (1×1), which means:
1. Either you captured from different software (not the Python library)
2. Or there's a different mode/method we haven't seen
3. Or the Python library code on GitHub is incomplete

## Hypothesis: Python Library vs Epomaker Official Software

Your working captures might be from **Epomaker's official software**, not the Python library!

The Python library:
- Always uses full display (60×9)
- Sends 540 pixels regardless
- Uses base address 0x389D
- Uses last packet override 0x3485

Your working captures:
- Use partial bounding box (1×1)
- Send only 1 pixel
- Use address 0x03D2
- Unknown override pattern

## Recommendation

Let's test with FULL DISPLAY init packet like Python library does:

```powershell
# Send Python library's exact FIRST_PACKET
$initPacket = @(
    0xa9, 0x00, 0x01, 0x00, 0x54, 0x06, 0x00, 0xfb,
    0x00, 0x00, 0x3c, 0x09, ...
)

# Then send full 540-pixel data (30 packets)
# All green pixels
```

This would match the Python library exactly.
