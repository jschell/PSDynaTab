# Animation Protocol Frame Count Validation

**Analysis Date:** 2026-01-16
**Source:** User-provided pcap captures (2, 4, 10 frame animations)

---

## CRITICAL DISCOVERY: Byte 2 = Frame Count

**Byte 2 encoding confirmed:**
- 0x02 = 2 frames
- 0x03 = 3 frames
- 0x04 = 4 frames
- 0x0A = 10 frames

**Phase 1 error corrected:** "Mode 0x03" was not a mode - it meant 3 frames!

---

## Frame Count & Packet Distribution

| Frames | Init Byte 2 | Total Packets | Packets/Frame | Source |
|--------|-------------|---------------|---------------|--------|
| 2 | 0x02 | 12 | 6 | User capture |
| 3 | 0x03 | 27 | 9 | Epomaker software |
| 4 | 0x04 | 24 | 6 | User capture |
| 10 | 0x0A | 60 | 6 | User capture |

**Discovery:** Two different animation variants with different packets/frame!

---

## Delay Encoding Validated

**Byte 3 = delay in milliseconds (8-bit, 0-255ms)**

| Delay | Byte 3 | Hex | Tested With |
|-------|--------|-----|-------------|
| 50ms | 50 | 0x32 | 2 frames |
| 75ms | 75 | 0x4B | 2 frames |
| 100ms | 100 | 0x64 | 2, 4, 10 frames |
| 150ms | 150 | 0x96 | 2 frames |
| 200ms | 200 | 0xC8 | 2 frames |
| 250ms | 250 | 0xFA | 2 frames |

**Maximum tested:** 250ms ✓
**Theoretical max:** 255ms (0xFF)

---

## Animation Variant Comparison

### Variant A: Epomaker Software (Original Captures)

**Init packet:**
```
a9:00:03:64:e8:05:00:02:02:00:3a:09:...
```

| Bytes | Value | Description |
|-------|-------|-------------|
| 0-1 | a9:00 | Init header |
| 2 | 0x03 | Frame count (3) |
| 3 | 0x64 | Delay (100ms) |
| 4-5 | **e8:05** | **Variant A marker** |
| 6 | 00 | Unknown |
| 7 | 02 | Checksum? |
| 8-9 | **02:00** | **Variant A flag** |
| 10-11 | 3a:09 | Start address |

**Characteristics:**
- 9 packets per frame
- Address starts at 0x3837-0x381D
- Used by official Epomaker software

### Variant B: User Captures (New)

**Init packet (2-frame example):**
```
a9:00:02:64:44:01:00:ab:01:00:0d:09:...
```

| Bytes | Value | Description |
|-------|-------|-------------|
| 0-1 | a9:00 | Init header |
| 2 | 0x02 | Frame count (2) |
| 3 | 0x64 | Delay (100ms) |
| 4-5 | **44:01** | **Variant B marker** |
| 6 | 00 | Unknown |
| 7 | varies | Checksum (changes with params) |
| 8-9 | **01:00** | **Variant B flag** |
| 10-11 | 0d:09 | Start address |

**Characteristics:**
- 6 packets per frame
- More compact than Variant A
- ~33% less data transmitted

---

## Packet Count Formula

**Variant A (Epomaker):** `total_packets = frame_count × 9`
- 3 frames = 27 packets ✓

**Variant B (User):** `total_packets = frame_count × 6`
- 2 frames = 12 packets ✓
- 4 frames = 24 packets ✓
- 10 frames = 60 packets ✓

---

## Byte 7 (Checksum?) Pattern

**Variant B observations:**

| Frames | Delay | Byte 7 |
|--------|-------|--------|
| 2 | 50ms | 0xDD |
| 2 | 75ms | 0xC4 |
| 2 | 100ms | 0xAB |
| 2 | 150ms | 0x79 |
| 2 | 200ms | 0x47 |
| 2 | 250ms | 0x15 |
| 4 | 100ms | 0xA9 |
| 10 | 100ms | 0xA3 |

**Pattern:** Decreases as delay increases (for same frame count)
**Hypothesis:** Checksum or validation byte derived from other parameters

---

## Updated Protocol Understanding

### What We Got Wrong in Phase 1

❌ **Incorrect:** "Byte 2 = mode (0x03 = animation mode)"
✓ **Correct:** Byte 2 = frame count (0x03 = 3 frames)

❌ **Incorrect:** "Bytes 8-9 encode frame count-1"
✓ **Correct:** Bytes 8-9 = variant selector (0x02:00 or 0x01:00)

❌ **Incorrect:** "9 packets per frame is standard"
✓ **Correct:** Depends on variant (A=9, B=6)

### What Phase 1 Got Right

✓ Byte 3 = delay in milliseconds
✓ Linear address decrement
✓ Device-controlled looping
✓ 56 bytes pixel data per packet

---

## Variant Selection

**Question:** How to select Variant A vs B?

**Hypothesis 1:** Bytes 4-5 control variant
- 0xE8:05 = Variant A (9 packets/frame)
- 0x44:01 = Variant B (6 packets/frame)

**Hypothesis 2:** Bytes 8-9 control variant
- 0x02:00 = Variant A
- 0x01:00 = Variant B

**Hypothesis 3:** Both bytes must match
- A: bytes 4-5=0xE8:05 AND bytes 8-9=0x02:00
- B: bytes 4-5=0x44:01 AND bytes 8-9=0x01:00

**Test needed:** Mix parameters to determine which bytes control the variant

---

## 5-Frame "Mode 0x05" Re-Analysis

**Original analysis assumption:** Mode 0x05 was a different mode
**New understanding:** Likely 5 frames with different variant

Need to re-examine:
```
a9:00:05:96:54:06:00:61:00:00:3c:09:...
```

- Byte 2: 0x05 = 5 frames ✓
- Byte 3: 0x96 = 150ms ✓
- Bytes 4-5: 0x54:06 = **Variant C?**
- Bytes 8-9: 0x00:00 = **Variant C?**
- Total packets: 29

**29 ÷ 5 = 5.8 packets/frame** - doesn't match A or B!

**Hypothesis:** Variant C with different packet distribution or variable packets/frame

---

## Testing Priority

### P0: Critical Validation

1. **Test Variant B parameters:**
   - 2, 4, 10 frames at 100ms (replicate captures)
   - 2 frames at 50, 75, 150, 200, 250ms (replicate)
   - Confirm visual output matches expected frame count

2. **Test variant switching:**
   - Send init with bytes 4-5=0xE8:05, bytes 8-9=0x02:00 (Variant A)
   - Send init with bytes 4-5=0x44:01, bytes 8-9=0x01:00 (Variant B)
   - Mix bytes to determine which controls variant

3. **Re-analyze 5-frame capture:**
   - Determine if 29 packets = 5 frames + metadata
   - Or variable packets per frame
   - Or Variant C with different distribution

### P1: Extended Range

4. **Test max values:**
   - 255ms delay (0xFF)
   - 16+ frames
   - Determine practical limits

---

## Implications for Test Scripts

**Test-AnimationPhase2.ps1 needs updates:**

```powershell
function New-AnimationInitPacket {
    param(
        [byte]$FrameCount = 3,
        [byte]$DelayMS = 100,
        [ValidateSet('A', 'B')]
        [string]$Variant = 'B'
    )

    $packet = New-Object byte[] 64
    $packet[0] = 0xa9
    $packet[1] = 0x00
    $packet[2] = $FrameCount  # NOT mode!
    $packet[3] = $DelayMS

    if ($Variant -eq 'A') {
        $packet[4] = 0xe8
        $packet[5] = 0x05
        $packet[8] = 0x02
        $packet[9] = 0x00
    }
    else {  # Variant B
        $packet[4] = 0x44
        $packet[5] = 0x01
        $packet[8] = 0x01
        $packet[9] = 0x00
    }

    # Byte 7 checksum calculation TBD
    # ...

    return $packet
}
```

---

## Summary

**Confirmed:**
- ✓ Byte 2 = frame count (2-10 tested)
- ✓ Byte 3 = delay in ms (50-250 tested)
- ✓ Two variants: A (9 pkt/frame) and B (6 pkt/frame)
- ✓ Total packets = frame_count × packets_per_frame_variant

**Open Questions:**
- ? How to select variant (bytes 4-5? bytes 8-9? both?)
- ? What is byte 7 calculation?
- ? What is 5-frame variant (29 packets)?
- ? Maximum supported frame count?
- ? Can variants be mixed in one session?

**Phase 1 conclusion:** ❌ Partially incorrect - missed variant distinction
**Phase 2 goal:** ✓ Validate all variants and frame counts
