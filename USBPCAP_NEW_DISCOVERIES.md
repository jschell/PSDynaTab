# New USBPcap Protocol Discoveries

**Analysis Date:** 2026-01-16
**Source Files:**
- `usbPcap-epmakerSuite-animation5frame-150ms.json`
- `usbPcap-epmakerSuite-keyboardLight2phase.json`
- `usbPcap-epmakerSuite-keyboardLightMultiSet.json`

---

## Major Discoveries Summary

### 1. NEW Animation Mode: 0x05 (150ms, Different Protocol)
**Critical Finding:** Animation mode is NOT just 0x03 - there's also mode 0x05 with different characteristics

### 2. Keyboard Backlight Control Protocol
**New Capability:** Individual key RGB lighting control via Interface 2

### 3. Multi-Mode Display System
The DynaTab uses multiple display modes:
- **0x01:** Static image (Phase 1 validated)
- **0x03:** Animation mode (Phase 1 validated, 100ms delay, 27 packets)
- **0x05:** Animation mode variant (NEW, 150ms delay, 29 packets)

---

## Discovery 1: Animation Mode 0x05

### Init Packet Structure

```
Frame 2862 (time: 3.650s)
a9:00:05:96:54:06:00:61:00:00:3c:09:00:00:00:00:...
```

**Byte Breakdown:**

| Bytes | Value | Decimal | Description | vs Mode 0x03 |
|-------|-------|---------|-------------|--------------|
| 0-1 | `a9 00` | 169, 0 | Init header | Same |
| **2** | **`05`** | **5** | **Animation mode 0x05** | **Different! (was 0x03)** |
| **3** | **`96`** | **150** | **150ms frame delay** | Different (was 0x64/100ms) |
| 4-5 | `54 06` | 84, 6 | Unknown | Same |
| 6 | `00` | 0 | Unknown | Same |
| 7 | `61` | 97 | Checksum? | Different (was 0x02) |
| **8-9** | **`00 00`** | **0, 0** | **Frame flags?** | **Different! (was 0x02 0x00)** |
| 10-11 | `3c 09` | 60, 9 | Address | Same (0x093C) |
| 12-63 | `00 ...` | 0 | Padding | Same |

### Key Differences from Mode 0x03

**Hypothesis A:** Mode 0x05 = Full-frame animation (all pixels updated)
- Mode 0x03: Sparse updates, 9 packets/frame
- Mode 0x05: Full updates, different packet count

**Hypothesis B:** Modes represent different animation engines
- 0x03 = Simple looping animation
- 0x05 = Complex/smooth animation

**Hypothesis C:** Byte 8-9 encoding changed
- Mode 0x03: Byte 8 = (frame_count - 1), Byte 9 = 0x00
- Mode 0x05: Bytes 8-9 = 0x00:00 (frame count encoded elsewhere?)

### Data Packet Structure

```
Packet format: 29:00:05:96:CC:00:AA:AA:DD:DD:DD...
```

| Bytes | Example | Description | vs Mode 0x03 |
|-------|---------|-------------|--------------|
| 0 | `29` | Data packet marker | Same |
| 1 | `00` | Always 0x00 | Same |
| **2** | **`05`** | **Mode byte (0x05)** | Different |
| **3** | **`96`** | **Delay (150ms)** | Different |
| 4 | `00-1C` | Packet counter (0-28) | Same concept, different range |
| 5 | `00` | Always 0x00 | Same |
| 6-7 | Varies | Address (big-endian) | **Different pattern** |
| 8-63 | RGB | 56 bytes pixel data | Same |

### Address Pattern Analysis

**Mode 0x03 (27 packets):**
```
Start: 0x3837
End:   0x381D
Decrement: Linear, 27 steps
```

**Mode 0x05 (29 packets):**
```
Counter  Address   Notes
0x00     0x3803    Start higher than mode 0x03
0x01     0x3802
0x02     0x3801
0x03     0x3800    Hits 0x...00 boundary
0x04     0x38FF    Wraps to 0xFF!
0x05     0x38FE
...
0x1B     0x38E8
0x1C     0x34EB    JUMPS to different high byte!
```

**Critical Observation:** Last packet jumps from 0x38E8 to 0x34EB
- Suggests different memory region
- May indicate completion marker
- Could be device configuration byte

### Total Packet Count: 29

If this is "5 frames":
- 29 packets ÷ 5 frames = 5.8 packets/frame (NOT even!)

**Possibilities:**
1. **Not 5 frames** - filename may be misleading
2. **Variable packets/frame** - frames can have different sizes
3. **Frame count encoded differently** - not in bytes 8-9
4. **Byte 8-9 = 0x0000** may mean "auto-detect frames from packet count"

---

## Discovery 2: Keyboard Backlight Control

### Protocol Overview

**Interface:** wIndex = "2" (same as display!)
**Packet Type:** 0x19 (vs 0x29 for display data, 0xa9 for init)

### Init/Config Packets

**Type 1: Config packet**
```
Frame 25298
07:42:04:00:07:00:00:00:ab:00:00:00:...
```

**Type 2: Start marker?**
```
Frame 25752
18:00:00:00:00:00:00:e7:00:00:00:...
```

### Keyboard Light Data Packets

**Two-phase transmission observed:**

#### Phase 0 Packets (byte 2 = 0x00)
```
19:00:00:02:32:00:00:b2:ca:e9:ab:b8:e9:86:7e:d3:21:41:75:05...
19:01:00:02:32:00:00:b1:ab:b8:e9:86:b8:e9:86:41:75:05:7e:d3:21...
19:02:00:02:32:00:00:b0:ab:b8:e9:86:41:75:05:7e:d3:21:41:75:05...
```

#### Phase 1 Packets (byte 2 = 0x01)
```
19:00:01:02:32:00:00:b1:6f:d6:f4:8a:e9:65:97:39:c8:00:d0:a9...
19:01:01:02:32:00:00:b0:b7:9e:7e:d9:71:e3:b3:ca:01:de:c4:99...
19:02:01:02:32:00:00:af:f0:7c:dd:ae:e1:57:c5:33:21:eb:69:c8...
```

### Packet Structure

| Bytes | Example | Description |
|-------|---------|-------------|
| 0 | `19` | Keyboard light packet type |
| 1 | `00-06` | Packet counter within phase |
| **2** | **`00` or `01`** | **Phase number** |
| 3-4 | `02 32` | Maybe key count? (0x0232 = 562 decimal) |
| 5-6 | `00 00` | Unknown |
| 7 | `b2-ac` | Address/counter (descending) |
| 8+ | RGB data | Individual key colors |

### RGB Color Examples Found

**Common Colors in Capture:**
- `b8:e9:86` = RGB(184, 233, 134) - Light green
- `ca:e9:ab` = RGB(202, 233, 171) - Pale green
- `7e:d3:21` = RGB(126, 211, 33) - Green
- `41:75:05` = RGB(65, 117, 5) - Dark green
- `d0:02:1b` = RGB(208, 2, 27) - Red
- `3e:64:17` = RGB(62, 100, 23) - Olive green

**Pattern:** Green/red color scheme for keyboard backlighting

### Two-Phase Protocol

**Phase 0:** 7 packets (counters 0x00-0x06)
**Phase 1:** Multiple packets with different data

**Hypothesis:**
- Phase 0: Set primary/base colors
- Phase 1: Set effects/animations/secondary colors
- OR: Two different key zones (left/right, top/bottom, etc.)

---

## Discovery 3: Multi-Set Keyboard Lighting

**File:** `usbPcap-epmakerSuite-keyboardLightMultiSet.json`

_Analysis pending - likely shows multiple lighting updates in sequence_

---

## Implications for PSDynaTab

### Immediate Testing Required

1. **Test Animation Mode 0x05**
   ```powershell
   # Add to Test-AnimationPhase2.ps1
   $init = New-AnimationInitPacket -Mode 0x05 -DelayMS 150 -FrameCount 0x00
   # Send 29 packets
   # Observe visual output
   ```

2. **Verify Address Wrap Behavior**
   - Test if 0x3800 → 0x38FF wrap is required
   - Test if final packet address jump is necessary

3. **Determine Frame Count Encoding for Mode 0x05**
   - Is it still in bytes 8-9?
   - Does 0x00:00 mean "auto-detect"?
   - Or is frame count derived from packet count?

### Future Feature: Keyboard Backlight Control

**New Cmdlets to Implement:**
```powershell
Set-DynaTabKeyboardLight -Keys @{
    'A' = [RGB]::Red
    'W' = [RGB]::Green
    'S' = [RGB]::Blue
}

Set-DynaTabKeyboardEffect -Effect "Wave" -Colors @(Red, Blue)

Clear-DynaTabKeyboardLight
```

**Requirements:**
- Map physical keys to packet data positions
- Understand phase 0 vs phase 1 usage
- Reverse-engineer key position encoding
- Determine if lighting persists or needs refresh

---

## Open Questions

### Animation Mode 0x05

1. **How many frames does mode 0x05 support?**
   - Filename says "5frame" but 29 packets doesn't divide by 5
   - Is it actually 29 single-packet frames?
   - Or variable frame sizes?

2. **What does byte 8-9 = 0x00:00 mean?**
   - Frame count?
   - Flags?
   - Unused in mode 0x05?

3. **Why does address jump from 0x38E8 to 0x34EB?**
   - Memory region boundary?
   - Special completion marker?
   - Error in capture?

4. **Is mode 0x05 smoother than mode 0x03?**
   - Visual quality comparison needed
   - Frame rate comparison
   - CPU usage implications

### Keyboard Lighting

5. **What is the key mapping for byte offsets?**
   - Need to identify which byte controls which key
   - Is it row-major or column-major?
   - Are there gaps for non-existent keys?

6. **What triggers phase 0 vs phase 1?**
   - Sequential requirement?
   - Different purposes?
   - Optional phases?

7. **How long does keyboard lighting persist?**
   - Does it need refresh packets?
   - Stored in device NVRAM?
   - Reset on USB disconnect?

8. **Can keyboard and display be controlled simultaneously?**
   - Both use interface 2
   - Potential conflicts?
   - Performance implications?

---

## Validation Test Plan

### Test 2.4: Animation Mode 0x05 Validation

```powershell
Write-Host "Testing Animation Mode 0x05" -ForegroundColor Cyan

# Test Case 1: Exact replication of captured sequence
$init = New-AnimationInitPacket -Mode 0x05 -DelayMS 150 -FrameCount 0x00
Send-InitPacket $init
Start-Sleep -Milliseconds 120
Get-DeviceStatus | Out-Null

# Send 29 packets with address pattern from capture
$startAddr = 0x3803
for ($i = 0; $i -lt 29; $i++) {
    if ($i -lt 4) {
        $addr = $startAddr - $i  # 0x3803, 0x3802, 0x3801, 0x3800
    }
    elseif ($i -lt 28) {
        $addr = 0x3800 + (0xFF - ($i - 3))  # 0x38FF down to 0x38E8
    }
    else {
        $addr = 0x34EB  # Last packet special address
    }

    $pixelData = New-FramePattern -FrameIndex ([Math]::Floor($i / 6))
    Send-AnimationDataPacket -Counter $i -Address $addr -Mode 0x05 -DelayMS 150 -PixelData $pixelData
}

Write-Host "Observe animation - count visible frames" -ForegroundColor Yellow
$frameCount = Read-Host "How many distinct frames? (number)"
$timing = Read-Host "Approximate frame delay (ms)"

Write-Host "Mode 0x05 Results:" -ForegroundColor Green
Write-Host "  Frames: $frameCount"
Write-Host "  Delay: $timing ms (expected 150ms)"
```

### Test 2.5: Keyboard Backlight Control (Basic)

```powershell
Write-Host "Testing Keyboard Backlight Control" -ForegroundColor Cyan

# Send Type 1 config
$config1 = [byte[]]@(0x07, 0x42, 0x04, 0x00, 0x07, 0x00, 0x00, 0x00, 0xAB, 0x00...)
Send-KeyboardPacket $config1

# Send Type 2 start marker
$config2 = [byte[]]@(0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xE7, 0x00...)
Send-KeyboardPacket $config2

# Send Phase 0 packets with solid red
for ($i = 0; $i -lt 7; $i++) {
    $packet = New-KeyboardLightPacket -Counter $i -Phase 0 -Color [RGB]::Red
    Send-KeyboardPacket $packet
}

Write-Host "Check keyboard - are keys lit red?" -ForegroundColor Yellow
Read-Host "Press Enter to continue"
```

---

## Comparison: Mode 0x03 vs Mode 0x05

| Feature | Mode 0x03 | Mode 0x05 |
|---------|-----------|-----------|
| **Delay byte 3** | 0x64 (100ms) | 0x96 (150ms) |
| **Byte 7 (checksum?)** | 0x02 | 0x61 |
| **Bytes 8-9** | 0x02:00 (frame count?) | 0x00:00 |
| **Total packets** | 27 | 29 |
| **Start address** | 0x3837 | 0x3803 |
| **End address** | 0x381D | 0x34EB (special) |
| **Address pattern** | Linear decrement | Decrement + wrap + jump |
| **Packets/frame** | 9 (3 frames) | ??? (unclear) |
| **Frame count** | 3 (validated) | Unknown |

---

## Next Steps

### Phase 2 Testing Updates Required

1. Add mode 0x05 tests to Test-AnimationPhase2.ps1
2. Create keyboard lighting test script
3. Analyze `keyboardLightMultiSet.json` for additional patterns
4. Test mode 0x05 with varying packet counts (18, 27, 36, 45)
5. Determine if mode 0x05 supports variable delays like mode 0x03
6. Map keyboard key positions to packet byte offsets

### Documentation Updates

1. Update PHASE2_TEST_PLAN.md with mode 0x05 tests
2. Create KEYBOARD_LIGHTING_PROTOCOL.md
3. Update TEST_RESULTS_ANIMATION.md with new discoveries
4. Add comparison matrix to USBPCAP_ANIMATION_ANALYSIS.md

### Implementation Planning

1. **Short-term:** Add mode 0x05 support to existing test scripts
2. **Mid-term:** Implement `Send-DynaTabAnimation` with mode selection
3. **Long-term:** Implement keyboard backlight control cmdlets

---

**Critical Discovery Summary:**

✓ **TWO animation modes exist (0x03 and 0x05)**
✓ **Keyboard RGB backlight is programmable**
✓ **Phase 1 validation was incomplete - missed mode 0x05**
✓ **Packet address patterns vary by mode**

These discoveries significantly expand the capabilities of PSDynaTab beyond initial Phase 1 testing!
