# Animation Protocol - How It Works

## Overview

Based on analysis of the Python library and working USB captures, here's how animations function on the DynaTab 75X.

---

## Animation Packet Flow

### Step 1: Send Init Packet (0xa9)

**Purpose:** Tell the device to prepare for an animation with N frames

**Example: 9-frame animation, 50ms delay, full display**
```
a9 00 09 32 54 06 00 c1 00 00 3c 09 00 00 00...
│  │  │  │  │     │  │  │  │  │
│  │  │  │  │     │  │  │  │  └─ Y-end = 9 (full height)
│  │  │  │  │     │  │  │  └──── X-end = 60 (full width)
│  │  │  │  │     │  │  └─────── Y-start = 0
│  │  │  │  │     │  └────────── X-start = 0
│  │  │  │  │     └───────────── Checksum = 0xC1
│  │  │  │  └─────────────────── Data bytes = 0x0654 (1620 = 540px * 3)
│  │  │  └────────────────────── Delay = 0x32 (50ms between frames)
│  │  └───────────────────────── Frame count = 9 frames
│  └──────────────────────────── Always 0x00
└─────────────────────────────── Init packet type
```

### Step 2: Send Data Packets (0x29) for Each Frame

**Purpose:** Send pixel data for each animation frame

**Frame Structure:**
- Each frame contains the same number of pixels (defined by bounding box)
- Pixels are sent in 18-pixel chunks across multiple packets
- Full display (60×9 = 540 pixels) requires 30 packets per frame (540÷18)

---

## Data Packet Sequencing

### Key Counters (From Python Library):

**1. Frame Index (Byte 1):**
- Which frame this packet belongs to (0-based)
- Range: 0 to (frame_count - 1)

**2. Incrementing Counter (Bytes 4-5, Little-Endian):**
- Global packet sequence number
- Starts at 0 for first packet of first frame
- Increments by 1 for every packet across ALL frames
- Never resets between frames

**3. Memory Address (Bytes 6-7, Big-Endian):**
- Starts at 0x3861 for animations
- Decrements by 1 for every packet
- Forms a countdown sequence

### Example: 3-Frame Animation, Full Display

**Frame 0 (Red):** Packets 0-29
```
Packet 0:  Frame=0, Counter=0,  Address=0x3861
Packet 1:  Frame=0, Counter=1,  Address=0x3860
Packet 2:  Frame=0, Counter=2,  Address=0x385F
...
Packet 29: Frame=0, Counter=29, Address=0x3846
```

**Frame 1 (Green):** Packets 30-59
```
Packet 30: Frame=1, Counter=30, Address=0x3845
Packet 31: Frame=1, Counter=31, Address=0x3844
Packet 32: Frame=1, Counter=32, Address=0x3843
...
Packet 59: Frame=1, Counter=59, Address=0x3828
```

**Frame 2 (Blue):** Packets 60-89
```
Packet 60: Frame=2, Counter=60, Address=0x3827
Packet 61: Frame=2, Counter=61, Address=0x3826
Packet 62: Frame=2, Counter=62, Address=0x3825
...
Packet 89: Frame=2, Counter=89, Address=0x380A
```

**Key Observation:** The incrementing counter NEVER resets between frames, but the frame index DOES change.

---

## Data Packet Structure (Detailed)

### Complete 64-Byte Data Packet:

```
Offset | Bytes | Value      | Description                    | Example
-------|-------|------------|--------------------------------|----------
0      | 1     | 0x29       | Data packet type               | 0x29
1      | 1     | frame_idx  | Frame index (0-based)          | 0x01 (frame 1)
2      | 1     | frame_cnt  | Total frame count              | 0x03 (3 frames)
3      | 1     | delay      | Delay in ms (from init)        | 0x32 (50ms)
4-5    | 2     | counter    | Incrementing counter (LE)      | 0x1E 0x00 (30)
6-7    | 2     | address    | Memory address (BE, decrement) | 0x38 0x45
8-63   | 56    | RGB data   | Pixel payload (18 RGB pixels)  | FF 00 00...
```

### Pixel Data Layout (Bytes 8-63):

```
Bytes 8-10:   Pixel 0 (R, G, B)
Bytes 11-13:  Pixel 1 (R, G, B)
Bytes 14-16:  Pixel 2 (R, G, B)
...
Bytes 59-61:  Pixel 17 (R, G, B)
Bytes 62-63:  Unused (padding)
```

**Maximum:** 18 complete RGB pixels per packet (18 × 3 = 54 bytes)

---

## Python Library Implementation

### Animation Chunking Logic:

```python
def _chunk_animation_data(self, animation_data: list[bytearray]) -> list[bytearray]:
    """
    Chunks animation frames into 64-byte packets

    Args:
        animation_data: List of bytearray, one per frame (each 1620 bytes for full display)

    Returns:
        List of 64-byte packets ready to send
    """
    packets = []
    base_address = 0x3861
    incrementing_nibble = 0  # Global counter across all frames

    for frame_index, frame_data in enumerate(animation_data):
        decrementing_nibble = base_address - incrementing_nibble

        # Chunk this frame into 56-byte payloads
        for offset in range(0, len(frame_data), 56):
            chunk = frame_data[offset:offset + 56]
            packet = bytearray(64)

            # Header
            packet[0] = 0x29
            packet[1] = frame_index
            packet[2] = len(animation_data)  # Total frames
            packet[3] = 0x32  # 50ms delay (hardcoded)

            # Incrementing counter (little-endian)
            packet[4:6] = incrementing_nibble.to_bytes(2, 'little')

            # Decrementing address (big-endian)
            packet[6:8] = decrementing_nibble.to_bytes(2, 'big')

            # Pixel payload
            packet[8:8 + len(chunk)] = chunk

            packets.append(packet)

            incrementing_nibble += 1
            decrementing_nibble -= 1

    return packets
```

### Key Points:

1. **`incrementing_nibble`** is declared OUTSIDE the frame loop
   - It's a global counter across all frames
   - Never resets

2. **`decrementing_nibble`** recalculates for each packet
   - `base_address - incrementing_nibble`
   - Always synchronized with the incrementing counter

3. **Delay is hardcoded to 0x32 (50ms)**
   - Not configurable in Python library data packets
   - Init packet has configurable delay

---

## Animation Playback Behavior

### Device Logic (Inferred):

**1. Receive Init Packet:**
- Device allocates memory for N frames
- Sets frame delay timer to D milliseconds
- Prepares to receive pixel data

**2. Receive Data Packets:**
- Device uses frame_index (byte 1) to determine which frame buffer to fill
- Uses incrementing counter for sequencing verification
- Uses memory address for internal buffer management
- Fills pixel data into appropriate frame buffer

**3. Playback Loop:**
- Once all packets received, device plays frames in sequence
- Frame 0 → wait D ms → Frame 1 → wait D ms → ... → Frame N-1
- Loops continuously until new command received

### Timing Observations (From Captures):

**Init packet delay field (byte 3):**
- Controls playback speed
- Range: 0-255 ms between frames
- Example: 0x32 = 50ms → 20 FPS
- Example: 0x64 = 100ms → 10 FPS

**Data packet delay field (byte 3):**
- Python library hardcodes to 0x32 (50ms)
- May override init packet delay?
- **Needs testing to confirm behavior**

---

## Animation Variants (From Our Earlier Analysis)

### Variant A: 9 packets/frame (Epomaker official)
- Used by official Epomaker software
- Not full display - partial region
- Bounding box: ?

### Variant B: 6 packets/frame (33% faster)
- Smaller region than Variant A
- Bounding box: ?

### Variant C: 1 packet/frame (9× faster)
- Minimal region (18 pixels or less)
- Bounding box: (0,0) to (?, ?)

### Variant D: 29 packets/frame (Full frame + overhead)
- Full display (60×9 = 540 pixels = 30 packets)
- Why 29 instead of 30? Last packet optimization?

**NEW UNDERSTANDING:**
These "variants" are NOT controlled by bytes 8-9 as we thought. They're simply **different bounding boxes**:
- Larger bounding box = more pixels = more packets per frame
- Smaller bounding box = fewer pixels = fewer packets per frame

**The bounding box (bytes 8-11) controls the variant!**

---

## Animation Workflow (PowerShell)

### Example: 3-Frame RGB Animation, Full Display

```powershell
# Step 1: Send init packet
$initPacket = New-Object byte[] 64
$initPacket[0] = 0xa9
$initPacket[1] = 0x00
$initPacket[2] = 0x03  # 3 frames
$initPacket[3] = 0x64  # 100ms delay
$initPacket[4] = 0x54  # 1620 bytes low
$initPacket[5] = 0x06  # 1620 bytes high
$initPacket[6] = 0x00
$initPacket[7] = Calculate-Checksum $initPacket
$initPacket[8] = 0x00   # X-start
$initPacket[9] = 0x00   # Y-start
$initPacket[10] = 0x3C  # X-end (60)
$initPacket[11] = 0x09  # Y-end (9)

Send-Packet $initPacket

# Step 2: Send data packets for all frames
$overallCounter = 0
$baseAddress = 0x3861

# Define frame colors
$frames = @(
    @(0xFF, 0x00, 0x00),  # Red
    @(0x00, 0xFF, 0x00),  # Green
    @(0x00, 0x00, 0xFF)   # Blue
)

for ($frameIdx = 0; $frameIdx -lt 3; $frameIdx++) {
    $color = $frames[$frameIdx]

    # 540 pixels / 18 per packet = 30 packets per frame
    for ($pktIdx = 0; $pktIdx -lt 30; $pktIdx++) {
        $dataPacket = New-Object byte[] 64
        $dataPacket[0] = 0x29
        $dataPacket[1] = $frameIdx
        $dataPacket[2] = 0x03  # 3 frames total
        $dataPacket[3] = 0x64  # 100ms delay

        # Incrementing counter (little-endian)
        $dataPacket[4] = [byte]($overallCounter -band 0xFF)
        $dataPacket[5] = [byte](($overallCounter -shr 8) -band 0xFF)

        # Memory address (big-endian, decrement)
        $address = $baseAddress - $overallCounter
        $dataPacket[6] = [byte](($address -shr 8) -band 0xFF)
        $dataPacket[7] = [byte]($address -band 0xFF)

        # Fill 18 pixels with frame color
        for ($p = 0; $p -lt 18; $p++) {
            $offset = 8 + ($p * 3)
            $dataPacket[$offset] = $color[0]     # R
            $dataPacket[$offset + 1] = $color[1] # G
            $dataPacket[$offset + 2] = $color[2] # B
        }

        Send-Packet $dataPacket
        $overallCounter++
    }
}

# Total packets sent: 1 init + 90 data (30 × 3 frames) = 91 packets
# Device now plays: Red → wait 100ms → Green → wait 100ms → Blue → loop
```

---

## Bounding Box Effects on Animation

### Example: Smaller Bounding Box

**Init packet for top row only (60×1 = 60 pixels):**
```powershell
$initPacket[8] = 0x00   # X-start = 0
$initPacket[9] = 0x00   # Y-start = 0
$initPacket[10] = 0x3C  # X-end = 60 (full width)
$initPacket[11] = 0x01  # Y-end = 1 (one row only)
$initPacket[4] = 0xB4   # 180 bytes low (60 pixels × 3)
$initPacket[5] = 0x00   # 180 bytes high
```

**Result:**
- 60 pixels ÷ 18 per packet = 4 packets per frame (rounded up)
- 3 frames × 4 packets = 12 data packets total
- **Animation plays in top row only, rest of display unchanged**

### Example: Single Pixel Animation (Variant C)

**Init packet for 1 pixel at (0,0):**
```powershell
$initPacket[8] = 0x00   # X-start = 0
$initPacket[9] = 0x00   # Y-start = 0
$initPacket[10] = 0x01  # X-end = 1 (1 pixel wide)
$initPacket[11] = 0x01  # Y-end = 1 (1 pixel tall)
$initPacket[4] = 0x03   # 3 bytes (1 pixel × 3)
$initPacket[5] = 0x00
```

**Result:**
- 1 pixel per frame = 1 packet per frame
- 3 frames × 1 packet = 3 data packets total
- **Blazing fast animation (Variant C) because minimal data transfer**

---

## Animation Performance Analysis

### Full Display Animation (60×9):
- Init: 1 packet
- Data: 30 packets × N frames
- Total: 1 + 30N packets

**Example frame rates:**
- 3 frames: 91 packets, ~200ms transfer → 5 FPS (limited by USB transfer)
- With 100ms delay: ~3 FPS effective

### Single Row Animation (60×1):
- Init: 1 packet
- Data: 4 packets × N frames
- Total: 1 + 4N packets

**Example frame rates:**
- 3 frames: 13 packets, ~30ms transfer → 33 FPS (USB limited)
- With 50ms delay: ~20 FPS effective

### Single Pixel Animation (1×1):
- Init: 1 packet
- Data: 1 packet × N frames
- Total: 1 + N packets

**Example frame rates:**
- 3 frames: 4 packets, ~10ms transfer → 100 FPS (USB limited)
- With 50ms delay: ~20 FPS effective

**Conclusion:** Smaller bounding boxes enable faster, smoother animations.

---

## Key Insights

1. **"Variants" are just bounding boxes**
   - Not a separate protocol mode
   - Controlled entirely by bytes 8-11 in init packet

2. **Incrementing counter is global**
   - Never resets between frames
   - Enables device to verify packet ordering

3. **Frame index determines frame buffer**
   - Device stores each frame separately
   - Frame index tells device which buffer to write to

4. **Memory address is complementary**
   - Synchronized with incrementing counter
   - Likely used for internal device memory management

5. **Delay appears in two places**
   - Init packet byte 3: Playback delay between frames
   - Data packet byte 3: May override? (Python library uses 0x32)
   - **Needs testing to determine precedence**

---

## Remaining Questions

1. **Does data packet delay override init packet delay?**
   - Python library hardcodes data packet delay to 0x32
   - Init packet has configurable delay
   - Which takes precedence?

2. **Last packet override behavior**
   - Python library shows special address for last packet
   - Is this required or optional?
   - Pattern: Static=0x3485, Anim=0x34(0x49-frame_idx)

3. **Maximum frame count**
   - Byte 2 is 8-bit (0-255)
   - Practical limit based on device memory?
   - Our captures show up to 21 frames working

4. **Frame buffer behavior**
   - Does device wait for all frames before playing?
   - Or does it start playing as frames arrive?
   - Loop behavior: Continuous or one-shot?

---

## Testing Recommendations

1. **Test delay precedence:**
   - Init delay = 100ms, data delay = 50ms → observe actual timing
   - Init delay = 50ms, data delay = 100ms → observe actual timing

2. **Test partial bounding boxes:**
   - Animate top row while bottom row stays static
   - Animate single pixel in center of display

3. **Test maximum frames:**
   - Try 50, 100, 200 frames
   - Find device memory limit

4. **Test last packet override:**
   - Send animation with correct override
   - Send animation without override
   - Compare behavior
