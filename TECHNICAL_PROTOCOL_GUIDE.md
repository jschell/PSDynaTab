# PSDynaTab Technical Protocol Guide

**Version:** 1.0
**Last Updated:** 2026-01-17
**Device:** Epomaker DynaTab 75X (VID: 0x3151, PID: 0x4015)

This comprehensive guide documents the complete USB HID protocol for controlling the DynaTab 75X LED matrix display, based on extensive USB packet capture analysis and testing.

---

## Table of Contents

1. [Screen Coordinates and Display Layout](#screen-coordinates-and-display-layout)
2. [Color Addressing and RGB Encoding](#color-addressing-and-rgb-encoding)
3. [Packet Structure and Sequencing](#packet-structure-and-sequencing)
4. [Single Picture vs Animation Modes](#single-picture-vs-animation-modes)
5. [Lessons Learned and Key Discoveries](#lessons-learned-and-key-discoveries)
6. [Protocol Reference Tables](#protocol-reference-tables)
7. [Implementation Recommendations](#implementation-recommendations)

---

## Screen Coordinates and Display Layout

### Physical Dimensions

The DynaTab 75X features an LED matrix display with the following specifications:

- **Width:** 60 pixels (columns 0-59)
- **Height:** 9 pixels (rows 0-8)
- **Total pixels:** 540 pixels
- **Total bytes:** 1620 bytes (540 pixels × 3 bytes RGB)

### Coordinate System

```
Column: 0                                                    59
Row 0:  [0,0] ──────────────────────────────────────────► [59,0]  (Top)
Row 1:  [0,1] ──────────────────────────────────────────► [59,1]
Row 2:  [0,2] ──────────────────────────────────────────► [59,2]
  ...
Row 8:  [0,8] ──────────────────────────────────────────► [59,8]  (Bottom)
```

**Origin:** Top-left corner at [0, 0]
**X-axis:** Left to right (0-59)
**Y-axis:** Top to bottom (0-8)

### Corner Positions

| Position | Coordinates | Header Packet Bytes [8-11] |
|----------|-------------|---------------------------|
| Top Left | (0, 0) | `00 00 01 01` |
| Top Right | (59, 0) | `3B 00 3C 01` |
| Bottom Left | (0, 8) | `00 08 01 09` |
| Bottom Right | (59, 8) | `3B 08 3C 09` |

### Region Specification

The initialization packet (0xa9) uses bytes [8-11] to specify the target region:

```
Byte 8:  X position (column start)
Byte 9:  Y position (row start)
Byte 10: Width (or X_end)
Byte 11: Height (or Y_end)
```

**Example - Full screen:**
```
[8-11] = 0x00 0x00 0x3C 0x09
         X=0  Y=0  W=60 H=9
```

**Example - Single pixel at top-right:**
```
[8-11] = 0x3B 0x00 0x3C 0x01
         X=59 Y=0  W=60 H=1
```

---

## Color Addressing and RGB Encoding

### RGB Color Format

Each pixel is represented by 3 bytes in **RGB888** format:

```
Byte 0: Red channel   (0x00-0xFF, 0-255)
Byte 1: Green channel (0x00-0xFF, 0-255)
Byte 2: Blue channel  (0x00-0xFF, 0-255)
```

**Examples:**
- Pure Red: `FF 00 00`
- Pure Green: `00 FF 00`
- Pure Blue: `00 00 FF`
- White: `FF FF FF`
- Black (off): `00 00 00`
- Orange: `B8 27 27` (R=184, G=39, B=39)
- Half-brightness Red: `7F 00 00` (127 = 49.8% intensity)

### Memory Layout - Interleaved RGB

The standard PSDynaTab implementation uses **interleaved RGB** format where each pixel's RGB values are stored sequentially:

```
Pixel Data Buffer (1620 bytes):
[R0 G0 B0] [R1 G1 B1] [R2 G2 B2] ... [R539 G539 B539]
```

This matches the format expected in data packets (0x29) starting at byte 8.

### Memory Layout - Planar RGB (Discovered in Position Tests)

**CRITICAL DISCOVERY:** Some captures show the keyboard may use **planar RGB** format with separate memory addresses for each color channel:

```
Red Plane:   [R0] [R1] [R2] ... [R539] at address 0x??380000
Green Plane: [G0] [G1] [G2] ... [G539] at address 0x??380001
Blue Plane:  [B0] [B1] [B2] ... [B539] at address 0x??380002
```

**Address Pattern:**
- Red channel: Base address + 0
- Green channel: Base address + 1
- Blue channel: Base address + 2

**Note:** This planar format appears in some USB captures but may be an internal device representation. PSDynaTab successfully uses interleaved format.

### Color Brightness

The device supports full 8-bit brightness control (0-255) for each RGB channel:

- `0x00` = Off (0%)
- `0x7F` = Half brightness (~50%)
- `0xFF` = Full brightness (100%)

All intermediate values are supported, allowing for 16,777,216 possible colors per pixel.

---

## Packet Structure and Sequencing

### USB Communication

**Interface:** Interface 2 (MI_02)
**Protocol:** HID Feature Reports
**Report Size:** 64 bytes
**Direction:** Host → Device (Set_Report)

### Packet Types

The protocol uses two primary packet types:

1. **Initialization Packet (0xa9)** - Sets up display mode and parameters
2. **Data Packet (0x29)** - Contains pixel data

### Initialization Packet Structure (64 bytes)

```
Offset  Bytes       Description                     Example (Static)    Example (Animation)
------  ----------  ------------------------------  ------------------  -------------------
[0]     0xa9        Initialization marker           a9                  a9
[1]     0x00        Fixed                           00                  00
[2]     Mode        Display mode                    01                  03
[3]     Delay       Frame delay (ms, for anim)      00                  64 (100ms)
[4-5]   Params      Size/mode parameters            54 06               E8 05
[6]     0x00        Fixed                           00                  00
[7]     Checksum    Validation byte                 FB                  02
[8]     X / Flags   X position or frame flags       00                  02
[9]     Y / Flags   Y position or frame flags       00                  00
[10-11] Address     Start address (big-endian)      3C 09 (0x093C)      3C 09 (0x093C)
[12-63] Padding     All zeros                       00 00 00...         00 00 00...
```

**Official Epomaker Initialization (from USB capture):**
```
a9 00 01 00 61 05 00 ef 06 00 39 09 00 00 00...
```

**PSDynaTab Implementation:**
```
a9 00 01 00 54 06 00 fb 00 00 3c 09 00 00 00...
```

**Key Differences:**
- Byte [4]: 0x61 (official) vs 0x54 (PSDynaTab)
- Byte [5]: 0x05 (official) vs 0x06 (PSDynaTab)
- Byte [7]: 0xef (official) vs 0xfb (PSDynaTab)
- Bytes [8-9]: 0x06 0x00 (official) vs 0x00 0x00 (PSDynaTab)
- Bytes [10-11]: 0x39 0x09 (official) vs 0x3c 0x09 (PSDynaTab)

**Status:** Both versions work, PSDynaTab values validated through testing.

### Data Packet Structure (64 bytes)

```
Offset  Bytes       Description                     Example             Notes
------  ----------  ------------------------------  ------------------  ---------------------
[0]     0x29        Data packet marker              29                  Fixed
[1]     Frame       Frame index (0 for static)      00                  0-based
[2]     Mode        Display mode (echoed)           01                  Same as init byte [2]
[3]     Delay       Frame delay (echoed, anim)      00                  Same as init byte [3]
[4-5]   Counter     Packet counter (little-endian)  00 00               Increments: 0,1,2...
[6-7]   Address     Memory address (big-endian)     38 9D (0x389D)      Decrements each pkt
[8-63]  Pixel Data  RGB pixel data                  [56 bytes]          Up to 18.67 pixels
```

**Static Image Example (first packet):**
```
29 00 01 00 00 00 38 9D [27 B8 27 27 B8 27 27 B8 27...]
│  │  │  │  │  │  │  │   └─ Pixel data (orange pixels)
│  │  │  │  │  │  └──┴─── Address: 0x389D (decrements to 0x388A)
│  │  │  │  └──┴──────── Counter: 0x0000 (increments to 0x001C)
│  │  │  └────────────── Fixed 0x00
│  │  └───────────────── Mode: 0x01 (static image)
│  └──────────────────── Frame: 0x00 (single frame)
└─────────────────────── Data packet marker
```

**Animation Example (first packet):**
```
29 00 03 64 00 00 38 37 [00 FF 00 00 00 00...]
│  │  │  │  │  │  │  │   └─ Pixel data (green pixel + spacing)
│  │  │  │  │  │  └──┴─── Address: 0x3837 (animation range)
│  │  │  │  └──┴──────── Counter: 0x0000
│  │  │  └────────────── Delay: 0x64 (100ms)
│  │  └───────────────── Mode: 0x03 (animation)
│  └──────────────────── Frame: 0x00 (first frame)
└─────────────────────── Data packet marker
```

### Packet Sequencing

#### For Static Images (29 packets)

```
Initialization:
  Packet 0: [0xa9] init packet with mode 0x01
  Optional: Get_Report handshake (120ms delay)

Data Transmission:
  Packet 1:  Counter=0x0000, Address=0x389D, Pixels 0-18
  Packet 2:  Counter=0x0001, Address=0x389C, Pixels 19-37
  Packet 3:  Counter=0x0002, Address=0x389B, Pixels 38-56
  ...
  Packet 29: Counter=0x001C, Address=0x388A, Pixels 522-539

Total: 1 init + 29 data = 30 packets
Timing: ~5ms between packets = ~150ms total
```

#### For Animations (3 frames, 9 packets each)

```
Initialization:
  Packet 0: [0xa9] init with mode 0x03, delay 0x64, frames in bytes [8-9]
  Optional: Get_Report handshake (120ms delay)

Data Transmission:
  Frame 0:
    Packet 1:  Frame=0x00, Counter=0x00, Address=0x3837
    Packet 2:  Frame=0x00, Counter=0x01, Address=0x3836
    ...
    Packet 9:  Frame=0x00, Counter=0x08, Address=0x382F

  Frame 1:
    Packet 10: Frame=0x01, Counter=0x09, Address=0x382E
    Packet 11: Frame=0x01, Counter=0x0A, Address=0x382D
    ...
    Packet 18: Frame=0x01, Counter=0x11, Address=0x3826

  Frame 2:
    Packet 19: Frame=0x02, Counter=0x12, Address=0x3825
    ...
    Packet 27: Frame=0x02, Counter=0x1A, Address=0x381D

Total: 1 init + 27 data = 28 packets
Device: Loops animation automatically at 100ms/frame
```

### Counter and Address Behavior

**Counter (Bytes [4-5]):**
- Format: Little-endian 16-bit integer
- Behavior: Increments from 0x0000
- Range: 0x0000 to 0x001C (0-28) for full screen
- Purpose: Packet sequence tracking

**Address (Bytes [6-7]):**
- Format: Big-endian 16-bit integer
- Behavior: Decrements from start address
- Static range: 0x389D → 0x388A (14493 → 14474)
- Animation range: 0x3837 → 0x381D (14391 → 14365)
- Purpose: Memory location indicator

**Synchronization:** Counter increments and address decrements in lockstep:
```
Packet #  Counter (LE)  Address (BE)
   0      0x00 0x00     0x38 0x9D
   1      0x01 0x00     0x38 0x9C
   2      0x02 0x00     0x38 0x9B
   ...
  28      0x1C 0x00     0x38 0x8A
```

### Optional Get_Report Handshake

**Official Epomaker protocol includes a handshake step:**

```
1. Send initialization packet (Set_Report)
2. Wait 120ms
3. Issue Get_Report request (Feature, 64 bytes)
4. Device responds with status buffer
5. Begin data transmission
```

**PSDynaTab Status:** Currently skips Get_Report (works but not manufacturer-spec compliant)

**Recommendation:** Implement optional Get_Report for full protocol compliance and better error detection.

---

## Single Picture vs Animation Modes

### Mode Overview

The display supports multiple operating modes controlled by byte [2] in the initialization packet:

| Mode Byte | Name | Frame Count | Looping | Delay | Use Case |
|-----------|------|-------------|---------|-------|----------|
| 0x01 | Static Image | 1 | No | N/A | Single image display |
| 0x03 | Animation | 2-255 | Yes | 1-255ms | Simple animations |
| 0x05 | Animation Extended | ? | Yes | 1-255ms | Complex animations (discovered, not validated) |

### Static Image Mode (0x01)

**Characteristics:**
- Single frame display
- No looping behavior
- Image persists until overwritten
- Uses 29 packets for full screen (1620 bytes)

**Init Packet:**
```
a9 00 01 00 54 06 00 fb 00 00 3c 09 00...
      ││                 ││││
      │└─ Mode: 0x01 (static)
      └── Fixed 0x00
         Bytes [8-9]: Position or flags
```

**Data Packets:**
- Byte [1]: Always 0x00 (single frame)
- Byte [2]: 0x01 (mode echo)
- Byte [3]: 0x00 (no delay)
- Address range: 0x389D → 0x388A

**Full Screen Transmission:**
- 29 packets × 56 bytes = 1624 bytes
- Covers all 540 pixels (1620 bytes)
- Remaining 4 bytes padded with zeros

**Partial Screen Updates:**
- Possible by sending fewer packets
- Official Epomaker software sends 20 packets (1120 bytes) for partial updates
- Supports 69% partial display updates (1120/1620 bytes)

### Animation Mode (0x03)

**Characteristics:**
- Multiple frames (2-255)
- Automatic looping by device
- Configurable frame delay (1-255ms)
- Device handles timing internally

**Init Packet:**
```
a9 00 03 64 e8 05 00 02 02 00 3c 09 00...
      ││ ││             ││││
      ││ │└─ Params    ││││
      ││ └── Delay: 0x64 (100ms)
      │└──── Mode: 0x03 (animation)
      └───── Fixed 0x00
         Bytes [8-9]: 0x02 0x00 (frame count - 1?)
```

**Frame Count Encoding:**
- **DISCOVERY:** Byte [2] in DATA packets = total frame count (NOT mode!)
- For 3 frames: Init packet varies, data packet byte [2] = 0x03
- For 4 frames: Data packet byte [2] = 0x04
- Byte [8-9] in init may encode frame count differently

**Data Packets:**
- Byte [1]: Frame index (0x00, 0x01, 0x02...)
- Byte [2]: Total frame count (0x03 for 3 frames)
- Byte [3]: Frame delay in milliseconds
- Address range: 0x3837 → 0x381D (varies by implementation)

**Sparse vs Full Frame Modes:**

The animation protocol supports two transmission strategies:

#### Sparse Update Mode
- **Bytes [4-5]:** Small values (27-324)
- **Behavior:** Variable packet count per frame
- **Efficiency:** Only sends lit pixels
- **Example:** 1 pixel = 1 packet (3 bytes used, 53 bytes padding)

```
Frame 0: 1 pixel  → 1 packet (3 bytes)
Frame 1: 6 pixels → 1 packet (18 bytes)
Frame 2: 9 pixels → 1 packet (27 bytes)
Total: 3 packets for 3 frames (ultra-efficient!)
```

#### Full Frame Mode
- **Bytes [4-5]:** Large values (1512-21510)
- **Behavior:** Fixed 29 packets per frame
- **Efficiency:** Always sends full screen data
- **Example:** 1 pixel still sends 29 packets (1620 bytes total)

```
Frame 0: 1 pixel  → 29 packets (1620 bytes, mostly zeros)
Frame 1: 6 pixels → 29 packets (1620 bytes, mostly zeros)
Frame 2: 9 pixels → 29 packets (1620 bytes, mostly zeros)
Total: 87 packets for 3 frames
```

**Performance Comparison:**
- Sparse mode: 3 packets = ~15ms transmission (67% faster)
- Full mode: 87 packets = ~435ms transmission
- **Use sparse for:** Indicators, simple graphics (<100 pixels)
- **Use full for:** Complex animations, video, full-screen effects

**Looping Behavior:**
- Animation loops automatically on device
- Host sends packets once
- Device replays frames indefinitely
- Loops until new display command received
- No "stop" command needed (send static image to stop)

### Animation Mode Extended (0x05) - Discovered

**Status:** Discovered in USB captures, not yet validated in PSDynaTab

**Differences from Mode 0x03:**
```
Init Packet:
a9 00 05 96 54 06 00 61 00 00 3c 09...
      ││ ││             ││││
      ││ │└─ Params    ││││
      ││ └── Delay: 0x96 (150ms, longer than 0x03)
      │└──── Mode: 0x05 (extended animation)
      └───── Fixed
         Bytes [8-9]: 0x00 0x00 (different from 0x03!)
```

**Observations:**
- Uses 29 packets (vs 27 in mode 0x03 tests)
- Different address pattern with wrap-around
- Bytes [8-9] = 0x00 0x00 (vs 0x02 0x00 in mode 0x03)
- Last packet jumps to different address (0x34EB)
- Frame count encoding unclear

**Requires Testing:** Full validation needed to understand differences and use cases.

### Mode Comparison Table

| Feature | Static (0x01) | Animation (0x03) | Extended (0x05) |
|---------|---------------|------------------|-----------------|
| **Init byte [2]** | 0x01 | 0x03 | 0x05 |
| **Frame delay** | N/A | 1-255ms | 1-255ms |
| **Frame count** | 1 | 2-255 | ? |
| **Looping** | No | Yes (automatic) | Yes (automatic) |
| **Address start** | 0x389D | 0x3837 | 0x3803 |
| **Sparse mode** | Yes (partial) | Yes | ? |
| **Full mode** | Yes (29 pkts) | Yes | Yes (29 pkts) |
| **Bytes [8-9]** | 0x00 0x00 | 0x02 0x00 (3 frames) | 0x00 0x00 |
| **Validation** | ✓ Complete | ✓ Complete | ⚠️ Needs testing |

---

## Lessons Learned and Key Discoveries

### Major Discoveries Through USB Capture Analysis

#### 1. Official Epomaker Initialization Differs

**Finding:** The official Epomaker software uses different initialization parameters

**Impact:**
- PSDynaTab works with current packet but may lack features
- Official packet may support undiscovered capabilities
- Better firmware compatibility possible

**Evidence:**
```
Official: a9 00 01 00 61 05 00 ef 06 00 39 09...
PSDynaTab: a9 00 01 00 54 06 00 fb 00 00 3c 09...
           Differences: ↑  ↑     ↑  ↑  ↑  ↑  ↑
```

**Recommendation:** Test both packets to determine functional differences.

#### 2. Get_Report Handshake is Optional But Recommended

**Finding:** Official protocol includes Get_Report after initialization

**Timing:**
```
1. Send init packet (Set_Report)
2. Wait 120ms
3. Get_Report (request 64 bytes)
4. Device responds with status
5. Begin data transmission
```

**PSDynaTab Status:** Currently skips this step (works but not spec-compliant)

**Benefits of implementing:**
- Device status verification
- Firmware version detection
- Better error diagnostics
- Full manufacturer protocol compliance

#### 3. Partial Display Updates Are Officially Supported

**Finding:** Official software sends only 20 packets (not full 29) for some images

**Efficiency:**
- 20 packets = 1120 bytes = 69% of screen
- Saves 9 packets = ~35ms transmission time
- Perfect for scrolling, status updates, incremental changes

**Current PSDynaTab:** Always sends full screen

**Future Enhancement:** Implement `Send-DynaTabPartialImage` with region parameters

#### 4. Frame Count Encoding Corrected

**Original Belief:** Byte [2] in data packets = animation mode identifier

**Discovery:** Byte [2] = total frame count!

**Evidence:**
```
Static image:   Data packet byte [2] = 0x01 (1 frame)
3-frame anim:   Data packet byte [2] = 0x03 (3 frames)
4-frame anim:   Data packet byte [2] = 0x04 (4 frames)
```

**Lesson:** Original test scripts were correct: `$packet[2] = $Frames`

#### 5. Sparse Update Protocol Confirmed

**Finding:** Animations support variable packet counts per frame

**Validation Test (1-6-9 pixel animation):**
```
Frame 0: 1 pixel  → 1 packet  (3 bytes pixel data)
Frame 1: 6 pixels → 1 packet  (18 bytes pixel data)
Frame 2: 9 pixels → 1 packet  (27 bytes pixel data)
Total: 3 packets for entire 3-frame animation
```

**Impact:**
- Simple animations incredibly efficient
- No need for mode variants
- Protocol automatically optimizes

**Formula:** `packets_per_frame = ceil(pixel_bytes / 56)`

#### 6. Full Frame vs Sparse Modes Exist

**Finding:** Bytes [4-5] control frame transmission mode

**Sparse Mode (bytes [4-5] small):**
- Sends only packets needed for lit pixels
- Variable packet count
- Example: 0x36 0x00 (54 decimal)

**Full Frame Mode (bytes [4-5] large):**
- Always sends 29 packets per frame
- Fixed packet count regardless of content
- Example: 0x54 0x06 (21510 decimal)

**When to use:**
- Sparse: Simple graphics, LEDs, indicators
- Full: Complex animations, video, full-screen effects

#### 7. Planar RGB Discovery (May Be Internal)

**Finding:** Some captures show separate color channel addresses

**Pattern:**
```
Red channel:   0x??380000
Green channel: 0x??380001  (+1)
Blue channel:  0x??380002  (+2)
```

**Status:** May be internal device representation; PSDynaTab successfully uses interleaved RGB

**Note:** Keep monitoring for scenarios where planar format might be required

#### 8. Animation Looping is Device-Controlled

**Finding:** Device automatically loops animations indefinitely

**Behavior:**
- Host sends all frames once
- Device stores and replays
- Loops continue until new display command
- Perfect timing maintained by device firmware

**Impact:**
- Extremely efficient (no re-transmission)
- Consistent frame timing
- Low CPU usage on host

**To stop animation:** Send static image command

#### 9. Multiple Animation Modes Discovered

**Finding:** Mode 0x05 exists alongside 0x03

**Mode 0x05 characteristics:**
- Different initialization parameters
- Possibly different frame count encoding
- Different address patterns
- May support advanced features

**Status:** Requires validation testing

#### 10. Address Ranges Vary by Mode

**Finding:** Static and animation use different memory ranges

**Ranges:**
```
Static image:    0x389D → 0x388A (14493-14474)
Animation 0x03:  0x3837 → 0x381D (14391-14365)
Animation 0x05:  0x3803 → 0x34EB (14339-13547, with jump)
```

**Lesson:** Address range is mode-specific; use correct range for each mode

### Testing Insights

#### What Worked Immediately

✓ Basic HID communication to Interface 2
✓ Static image display (mode 0x01)
✓ 64-byte packet structure
✓ Counter increment / address decrement pattern
✓ RGB888 color encoding
✓ 5ms inter-packet delay

#### What Required Investigation

⚠ Animation mode discovery (through USB capture analysis)
⚠ Frame count encoding (corrected understanding)
⚠ Sparse vs full frame modes
⚠ Official initialization packet differences
⚠ Get_Report handshake usage
⚠ Multiple animation modes (0x03 vs 0x05)

#### What Still Needs Research

? Exact meaning of bytes [4-5] calculation
? Mode 0x05 full validation
? Maximum supported frame count
? Frame buffer persistence behavior
? Keyboard backlight control protocol (0x19 packets discovered)
? Multi-set keyboard lighting capabilities

### Protocol Design Insights

#### Elegant Features

1. **Automatic frame optimization** - Device calculates packets needed
2. **Built-in loop controller** - No host CPU overhead
3. **Flexible addressing** - Supports full and partial updates
4. **Simple packet structure** - Easy to implement and debug
5. **Robust timing** - Device handles all frame delays

#### Limitations Discovered

1. **No frame buffer clear command** - Must send black pixels
2. **No animation stop command** - Must send static image
3. **Fixed packet size** - 64 bytes regardless of data size
4. **Limited documentation** - Required extensive reverse engineering

### Best Practices Learned

#### For Static Images

1. Send full 29 packets for best compatibility
2. Use address range 0x389D → 0x388A
3. Consider partial updates (20 packets) for efficiency
4. Set byte [2] = 0x01 in all packets
5. Optionally implement Get_Report handshake

#### For Animations

1. Use sparse mode (<100 pixels) for efficiency
2. Use full mode (complex graphics) for reliability
3. Set byte [2] = frame count in data packets
4. Use address range 0x3837 → 0x381D
5. Let device handle looping (don't re-send)
6. To stop: send static image, don't try to "stop" animation

#### For Testing

1. Always capture USB packets from official software as reference
2. Test with minimal pixel data first (1-pixel tests)
3. Validate counter and address sequences
4. Visual confirmation beats assumption
5. Document all discoveries immediately
6. Compare official vs custom implementations

### Common Pitfalls Avoided

❌ **Don't:** Assume byte meanings without validation
✓ **Do:** Capture and analyze real USB traffic

❌ **Don't:** Mix static and animation address ranges
✓ **Do:** Use correct address range for each mode

❌ **Don't:** Hardcode frame counts in test scripts
✓ **Do:** Calculate dynamically: `$packet[2] = $Frames`

❌ **Don't:** Assume "variants" exist without proof
✓ **Do:** Test systematically to find actual behavior

❌ **Don't:** Over-engineer without requirements
✓ **Do:** Implement what's proven to work

### Performance Lessons

**Timing Observations:**
- Packet transmission: ~1.5ms per packet (device ACK)
- Inter-packet delay: 5ms recommended (3-6ms observed)
- Get_Report handshake: 120ms wait after init
- Full screen (29 pkts): ~150ms total
- Sparse animation (3 pkts): ~15ms total
- **67% faster** with sparse vs full frames

**Optimization Strategies:**
1. Use sparse mode for simple animations
2. Implement partial screen updates
3. Minimize pixel data size
4. Let device handle looping
5. Batch image updates when possible

---

## Protocol Reference Tables

### Display Modes

| Mode | Byte Value | Description | Frame Count | Looping | Validated |
|------|------------|-------------|-------------|---------|-----------|
| Static Image | 0x01 | Single frame, no loop | 1 | No | ✓ Yes |
| Animation | 0x03 | Multi-frame, auto-loop | 2-255 | Yes | ✓ Yes |
| Extended Animation | 0x05 | Advanced animation | ? | Yes | ⚠️ Partial |

### Packet Type Identification

| First Byte | Packet Type | Direction | Size | Purpose |
|------------|-------------|-----------|------|---------|
| 0xa9 | Initialization | Host→Device | 64 bytes | Set display mode and parameters |
| 0x29 | Data | Host→Device | 64 bytes | Transmit pixel data |
| 0x19 | Keyboard Light | Host→Device | 64 bytes | Control keyboard backlight (discovered) |
| 0x07 | Config | Host→Device | 64 bytes | Device configuration (discovered) |
| 0x18 | Start Marker | Host→Device | 64 bytes | Operation start (discovered) |

### Memory Address Ranges

| Mode | Start Address | End Address | Packets | Coverage |
|------|---------------|-------------|---------|----------|
| Static (full) | 0x389D | 0x388A | 29 | 540 pixels |
| Static (partial) | 0x389D | 0x3891 | 20 | ~373 pixels |
| Animation 0x03 | 0x3837 | 0x381D | 27 | Variable (3 frames × 9 pkts) |
| Animation 0x05 | 0x3803 | 0x34EB | 29 | Variable (jumps at end) |

### Timing Parameters

| Parameter | Min | Typical | Max | Unit | Notes |
|-----------|-----|---------|-----|------|-------|
| Inter-packet delay | 3 | 5 | 10 | ms | Time between packet sends |
| Packet ACK latency | 1.5 | 1.7 | 3 | ms | Device response time |
| Init handshake delay | 100 | 120 | 150 | ms | Before Get_Report |
| Frame delay | 1 | 100 | 255 | ms | Animation frame rate |
| Full screen transmission | 145 | 150 | 200 | ms | 29 packets × 5ms |

### Byte-by-Byte Field Reference

#### Initialization Packet (0xa9)

| Byte(s) | Field Name | Type | Values | Description |
|---------|------------|------|--------|-------------|
| [0] | Marker | Fixed | 0xa9 | Initialization packet identifier |
| [1] | Reserved | Fixed | 0x00 | Always zero |
| [2] | Mode | Enum | 0x01, 0x03, 0x05 | Display mode selector |
| [3] | Delay | uint8 | 0-255 | Frame delay in milliseconds |
| [4-5] | Parameters | uint16 | Varies | Mode-specific parameters |
| [6] | Reserved | Fixed | 0x00 | Always zero |
| [7] | Checksum | uint8 | Calculated | Validation byte |
| [8] | X or Flags | uint8 | 0-59 or flags | X position or frame flags |
| [9] | Y or Flags | uint8 | 0-8 or flags | Y position or frame flags |
| [10-11] | Address | uint16 BE | 0x093C typical | Start address |
| [12-63] | Padding | Fixed | 0x00... | All zeros |

#### Data Packet (0x29)

| Byte(s) | Field Name | Type | Values | Description |
|---------|------------|------|--------|-------------|
| [0] | Marker | Fixed | 0x29 | Data packet identifier |
| [1] | Frame Index | uint8 | 0-255 | Current frame number (0-based) |
| [2] | Frame Count / Mode | uint8 | 1-255 | Total frames or mode echo |
| [3] | Delay | uint8 | 0-255 | Frame delay (ms) or 0 for static |
| [4-5] | Counter | uint16 LE | 0-65535 | Incrementing packet sequence |
| [6-7] | Address | uint16 BE | Varies | Decrementing memory address |
| [8-63] | Pixel Data | byte[56] | RGB data | Up to 18 full pixels + 2 bytes |

---

## Implementation Recommendations

### For Basic Static Images

```powershell
# Minimum viable implementation
1. Connect to device (VID: 0x3151, PID: 0x4015, Interface 2)
2. Send init packet: 0xa9 with mode 0x01
3. Send 29 data packets: 0x29 with incrementing counter, decrementing address
4. Use 5ms delay between packets
5. Total: ~150ms for full screen update
```

### For Simple Animations

```powershell
# Efficient animation (sparse mode)
1. Send init packet: 0xa9 with mode 0x03, delay in byte [3]
2. For each frame:
   - Calculate packets needed: ceil(lit_pixels * 3 / 56)
   - Send only required packets
   - Set byte [1] = frame index
3. Device loops automatically
4. Total: ~5ms per packet (highly efficient for simple graphics)
```

### For Complex Animations

```powershell
# Full-frame animation (reliable mode)
1. Send init packet: 0xa9 with mode 0x03, delay in byte [3]
2. Set bytes [4-5] to large value (e.g., 0x54 0x06)
3. For each frame:
   - Send all 29 packets (full screen)
   - Set byte [1] = frame index
   - Include all pixel data (even zeros)
4. Device loops automatically
5. Total: ~150ms per frame transmission
```

### For Production Applications

**Recommended features to implement:**

1. **Connection management**
   - Device detection and enumeration
   - Error handling for device disconnect
   - Automatic reconnection

2. **Protocol compliance**
   - Optional Get_Report handshake
   - Proper packet sequencing validation
   - Checksum calculation for byte [7]

3. **Image optimization**
   - Automatic sparse/full mode selection
   - Partial screen update support
   - Pixel data compression

4. **Animation features**
   - Variable frame delays
   - Frame count calculation
   - Loop control (stop via static image)

5. **Error handling**
   - USB timeout detection
   - Packet retry mechanism
   - Invalid parameter validation

6. **Performance optimization**
   - Packet batching where possible
   - Minimal memory allocation
   - Efficient RGB conversion

### Testing Checklist

Before deploying:

- [ ] Test with official Epomaker software for comparison
- [ ] Validate all 4 corner positions display correctly
- [ ] Test full screen (540 pixels) static image
- [ ] Test single pixel at each corner
- [ ] Test sparse animation (1-10 pixels)
- [ ] Test full animation (540 pixels per frame)
- [ ] Verify frame delays (50ms, 100ms, 200ms)
- [ ] Confirm animation looping
- [ ] Test animation stop (via static image)
- [ ] Measure actual timing with timestamps
- [ ] Test on multiple devices (if available)
- [ ] Verify with different USB controllers/hubs
- [ ] Test rapid updates (stress test)
- [ ] Validate color accuracy (pure R, G, B, White)
- [ ] Check for memory leaks in long-running sessions

### Future Enhancements to Consider

1. **Keyboard backlight control** (0x19 packets discovered)
2. **Mode 0x05 validation** (extended animation features)
3. **Official initialization packet** (test benefits)
4. **Get_Report handshake** (improved reliability)
5. **Partial update API** (region-specific updates)
6. **Animation compression** (reduce packet size)
7. **Frame buffer management** (understand persistence)
8. **Multi-device support** (multiple keyboards)

---

## Conclusion

The Epomaker DynaTab 75X uses a sophisticated yet accessible USB HID protocol for controlling its LED matrix display. Through extensive USB capture analysis and systematic testing, we've documented a robust protocol supporting:

- **Flexible display modes** (static, animation, extended)
- **Efficient data transmission** (sparse and full frame modes)
- **Automatic animation looping** (device-controlled timing)
- **Partial screen updates** (optimized bandwidth)
- **Full RGB color control** (16.7M colors per pixel)

The PSDynaTab PowerShell implementation successfully replicates core functionality, with opportunities for enhancement through:
- Official packet format adoption
- Get_Report handshake implementation
- Mode 0x05 validation
- Partial update support
- Keyboard backlight control

This guide provides the foundation for building reliable, efficient applications to control the DynaTab 75X display.

---

**Document Version:** 1.0
**Last Updated:** 2026-01-17
**Contributors:** PSDynaTab project team
**Based on:** USB captures from official Epomaker software, extensive protocol testing
**Status:** Production ready for modes 0x01 and 0x03; mode 0x05 requires validation

**References:**
- USBPCAP_REVIEW.md - Official Epomaker protocol analysis
- ANIMATION_ANALYSIS_SUMMARY.md - Animation mode discoveries
- SPARSE_UPDATE_CONFIRMED.md - Sparse protocol validation
- PICTURE_POSITION_ANALYSIS.md - Screen coordinate analysis
- TEST_RESULTS_ANIMATION.md - Validation test results
