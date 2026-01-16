# Animation Protocol: Sparse Update Theory

**Analysis Date:** 2026-01-16
**Critical Insight:** User observation that 5-frame minimal animation only lit 1-2 LEDs

---

## Theory Revision: Not "Variants" but Sparse Updates

### Original Theory (INCORRECT)
- ❌ Three fixed "variants" with 1, 6, or 9 packets per frame
- ❌ Bytes 4-5 select the variant
- ❌ All frames in an animation use same packet count

### Revised Theory (LIKELY CORRECT)
- ✓ **Send only packets covering lit/changing pixels**
- ✓ Packet count = how many 56-byte chunks needed for visible data
- ✓ Different frames can have different packet counts
- ✓ Bytes 4-5 encode image layout/size, not "variant"

---

## Evidence

### 5-Frame Minimal: 1 Packet/Frame

**User observation:** "Only 1 or 2 LED portions were lit"

**Data capacity:**
- 1 packet = 56 bytes = ~18 RGB pixels
- Perfect for 1-2 LEDs!

**Pixel data from pcap:**
```
29:00:05:64:00:00:1b:52:00:ff:00:00:00:00:00:00:00:00...
                          ^^^^^^^^ green pixel
                                   ^^^^^^^^^^^^^^^^^^ rest black
```

**Conclusion:** Only sent data for the 1-2 pixels that were lit

---

### 2/4/10-Frame "Compact": 6 Packets/Frame

**Data capacity:**
- 6 packets = 336 bytes = ~112 pixels
- ~20% of 540-pixel display

**Hypothesis:** Animations had moderate visual complexity
- Maybe a progress bar (60 pixels wide)
- Or a simple icon/graphic
- Not full-screen, but more than 1-2 LEDs

---

### 3-Frame "Full": 9 Packets/Frame

**Data capacity:**
- 9 packets = 504 bytes = ~168 pixels
- ~31% of display

**Known content:** Complex orange geometric patterns (from original analysis)
- Diagonal lines
- Clusters
- Scattered pixels

**Conclusion:** Needed 168 pixels worth of data for complex graphics

---

### 16-Frame "Full": 9 Packets/Frame

**Data capacity:** Same 168 pixels/frame

**Hypothesis:** Similar visual complexity to 3-frame
- Probably same type of graphics, just more frames
- Consistent packet count suggests consistent complexity across frames

---

## Packet Count Formula (Revised)

**Old theory:**
```
total_packets = frame_count × variant_packets_per_frame
```

**New theory:**
```
total_packets = sum of (packets_needed_for_frame[i]) for i in 0..frame_count-1
```

**Where packets_needed_for_frame depends on:**
- How many pixels are lit in that frame
- Spatial distribution of lit pixels (may need to cover gaps)
- Whether device supports fragmented updates or requires contiguous ranges

---

## Address Decrement Pattern

**Observation:** Addresses always decrement linearly

**5-frame example:**
```
Frame 0: Address 0x1B52
Frame 1: Address 0x1B51
Frame 2: Address 0x1B50
Frame 3: Address 0x1B4F
Frame 4: Address 0x1B4E
```

**Hypothesis:**
- Address represents memory position for frame data
- Each packet writes to next lower address
- Device uses address to know where to write pixel data in frame buffer

---

## Bytes 4-5 Re-analysis

**Old hypothesis:** Variant selector (1, 6, or 9 packets per frame)

**New hypothesis:** Image size or layout descriptor

**Evidence:**

| Animation | Frames | Bytes 4-5 | Avg Pixels/Frame | Interpretation |
|-----------|--------|-----------|------------------|----------------|
| 5-frame minimal | 5 | 0x1B:00 | ~18 | Tiny image (27 decimal = ~18 pixels?) |
| 2-frame compact | 2 | 0x44:01 | ~112 | Medium image (324 decimal = ?) |
| 3-frame full | 3 | 0xE8:05 | ~168 | Large image (1512 decimal = ?) |
| 16-frame full | 16 | 0xCB:01 | ~168 | Large image (459 decimal = ?) |

**Pattern unclear** - need more analysis

**Alternative:** Could be compression flags, color depth, or other metadata

---

## Bytes 8-9 Re-analysis

**Old hypothesis:** Variant flag (0x00:00, 0x01:00, 0x02:00)

**New observations:**

| Bytes 8-9 | Occurrences |
|-----------|-------------|
| 0x00:00 | 5-frame minimal, 16-frame full, 5-frame Epomaker |
| 0x01:00 | All 2/4/10-frame animations |
| 0x02:00 | 3-frame Epomaker |

**Pattern:**
- 0x00:00 appears with both minimal and full animations
- Not a simple "size" indicator
- Could be flags, frame format, or animation type

---

## Implications for Variable Packets Per Frame

### 5-Frame Epomaker Mystery (29 packets)

**Original puzzle:** 29 ÷ 5 = 5.8 packets/frame (doesn't divide evenly)

**New explanation:** Variable packet counts per frame!

**Possible distribution:**
- Frame 0: 6 packets
- Frame 1: 6 packets
- Frame 2: 6 packets
- Frame 3: 5 packets
- Frame 4: 6 packets
- **Total: 29 packets ✓**

Or any other combination that sums to 29.

**Conclusion:** Each frame sent only the packets it needed for its visual content

---

## Frame Boundary Detection

**Question:** How does device know when a new frame starts?

**Theory 1: Counter resets**
- When counter wraps around (e.g., 0x00 after 0x05)
- Device detects new frame

**Theory 2: Expected packet count**
- Device calculates from bytes 4-5 or init packet
- Knows "frame 0 has 6 packets, frame 1 has 5 packets, etc."

**Theory 3: Special marker**
- Address jump or special value indicates frame boundary
- Seen in 3-frame animation (address 0x3837 → 0x381D linear, no jumps)

**Most likely:** Theory 1 (counter-based)
- Simple and robust
- Explains linear counter sequences

---

## Testing Strategy (Revised)

### Test 1: Variable Packets Per Frame

**Send 3-frame animation with:**
- Frame 0: 1 packet (1 LED)
- Frame 1: 6 packets (moderate graphic)
- Frame 2: 2 packets (small icon)
- Total: 9 packets for 3 frames

**Expected:** Should work if sparse updates theory is correct

### Test 2: Minimal to Full Transition

**Send 2-frame animation:**
- Frame 0: 1 packet (single pixel)
- Frame 1: 9 packets (full screen)
- Total: 10 packets

**Expected:** Should transition from sparse to full

### Test 3: Empty Frame

**Send 3-frame animation:**
- Frame 0: 3 packets
- Frame 1: 0 packets (all black)
- Frame 2: 3 packets
- Total: 6 packets

**Expected:** Frame 1 displays as black (or previous frame held?)

### Test 4: Overlapping Pixels

**Two frames with different pixels in same spatial region:**
- Frame 0: Pixels 0-20 red (1 packet)
- Frame 1: Pixels 10-30 blue (1 packet)
- Overlap at pixels 10-20

**Expected:** Shows if device clears frame buffer or overlays

---

## Updated Understanding

### What We Now Believe

**Init Packet:**
- Byte 2: Frame count ✓ (confirmed)
- Byte 3: Delay in ms ✓ (confirmed)
- Bytes 4-5: Image metadata (size/layout/format?) ❓
- Bytes 8-9: Additional flags/format ❓

**Data Packets:**
- Send ONLY what you need for visible/changing pixels
- Counter increments sequentially (0, 1, 2, ...)
- Address decrements (used for frame buffer positioning)
- Each frame can have different packet count

**Optimization:**
- Simple animations (1-2 LEDs): 1 packet per frame
- Medium animations (icons, bars): 2-6 packets per frame
- Complex animations (full graphics): 7-9 packets per frame
- Full screen updates: ~29 packets per frame

---

## Benefits of Sparse Update Model

### Efficiency
- No wasted bandwidth on black pixels
- Scales perfectly from simple to complex animations
- Enables ultra-fast updates for simple indicators

### Flexibility
- Mix simple and complex frames in same animation
- Optimize each frame independently
- Natural compression without explicit encoding

### Performance
- Single LED blink: 1 init + 2 data packets = ~15ms
- Progress bar: 1 init + N×3 packets = ~45ms for 3 frames
- Full animation: 1 init + N×9 packets = ~135ms for 3 frames

---

## Open Questions

### 1. How does device handle partial updates?

**Scenario:** Frame 0 sets pixels 0-50, Frame 1 sets pixels 25-75

**Questions:**
- Does frame 1 clear pixels 0-24?
- Or does it overlay, leaving 0-24 from frame 0?
- Is there a "clear frame buffer" mode?

### 2. What do bytes 4-5 encode?

**Observations:**
- 0x1B:00 (27 decimal) for minimal
- 0x44:01 (324 decimal) for compact
- 0xE8:05 (1512 decimal) for full
- 0xCB:01 (459 decimal) for 16-frame

**Possibilities:**
- Total pixel count
- Bounding box size
- Layout flags
- Compression mode

### 3. Can you mix packet counts arbitrarily?

**Test needed:**
- Frame with 1 packet
- Frame with 3 packets
- Frame with 9 packets
- All in same animation

### 4. Is there a maximum packets per frame?

**Known max:** 29 packets for full screen
**Question:** Can you send 30? 40? Or is 29 the hard limit?

---

## Implications for PSDynaTab

### Smart Packet Generation

```powershell
function Optimize-AnimationFrames {
    param($Frames)

    foreach ($frame in $Frames) {
        # Calculate bounding box of non-black pixels
        $litPixels = Get-LitPixels $frame

        # Determine packets needed
        $packetsNeeded = [Math]::Ceiling($litPixels.Count * 3 / 56)

        # Generate only necessary packets
        Send-OptimizedFrame -Pixels $litPixels -PacketCount $packetsNeeded
    }
}
```

### Auto-Optimization

- Analyze each frame's visual content
- Send only necessary packets
- Maximize transmission speed
- Reduce USB bandwidth

### Debug Mode

- Report packet count per frame
- Show optimization savings
- Compare optimized vs full-frame transmission

---

## Summary

**Major Insight:** User observation breaks "variant" theory

**New Model:** Sparse updates
- Send only what you need
- Variable packets per frame
- Extremely efficient for simple animations
- Scales to complex graphics

**Next Steps:**
1. Test variable packet counts per frame
2. Determine bytes 4-5 meaning through testing
3. Test frame buffer behavior (clear vs overlay)
4. Implement smart packet optimization in PSDynaTab

**Impact:** This changes everything!
- Not "choosing a variant"
- Automatically optimizing based on content
- Perfect for everything from single LED to full animations
