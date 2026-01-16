# Official Epomaker Protocol Test Suite

## Overview

This test suite validates the findings from the USBPcap trace analysis of official Epomaker software. It implements and compares three key protocol improvements:

1. **Official initialization packet** vs current PSDynaTab packet
2. **Get_Report handshake** protocol for status verification
3. **Partial display updates** for performance optimization

## Quick Start

### Run All Tests
```powershell
.\Test-OfficialProtocol.ps1 -TestAll
```

### Run Individual Tests
```powershell
# Test initialization packets
.\Test-OfficialProtocol.ps1 -TestInitPacket

# Test Get_Report handshake
.\Test-OfficialProtocol.ps1 -TestHandshake

# Test partial updates
.\Test-OfficialProtocol.ps1 -TestPartialUpdates
```

## What Gets Tested

### Test 1: Initialization Packet Comparison

Compares two initialization packets byte-by-byte:

**Current PSDynaTab:**
```
a9 00 01 00 54 06 00 fb 00 00 3c 09 00 00 ...
```

**Official Epomaker:**
```
a9 00 01 00 61 05 00 ef 06 00 39 09 00 00 ...
            ^^|^^|  ^^|^^|^^|  ^^|
```

**Key Differences:**
- Byte 4: `0x54` vs `0x61` (84 vs 97) - Possibly width parameter
- Byte 5: `0x06` vs `0x05` (6 vs 5) - Possibly height parameter
- Byte 7: `0xfb` vs `0xef` (251 vs 239) - Checksum/validation
- Bytes 8-9: `0x00, 0x00` vs `0x06, 0x00` - Additional parameter
- Bytes 10-11: `0x3c, 0x09` vs `0x39, 0x09` - Start address

**What to Watch:**
- Both packets should work without errors
- Look for any behavioral differences in display rendering
- Note any error messages or warnings

---

### Test 2: Get_Report Handshake Protocol

Official Epomaker protocol sequence:
```
1. Send initialization packet
2. Wait 120ms for device processing
3. Call Get_Report to verify device ready
4. Begin data transmission
```

Current PSDynaTab approach:
```
1. Send initialization packet
2. Immediately begin data transmission
```

**What Gets Tested:**
- Device status retrieval via `GetFeature()`
- 120ms timing delay compliance
- Response buffer analysis
- Successful data transmission after handshake

**What to Watch:**
- Get_Report response content (first 16 bytes logged)
- Whether handshake reveals device status/firmware info
- Any timing-related improvements or issues

---

### Test 3: Partial Display Update Optimization

**USBPcap Analysis Showed:**
- Official Epomaker sent **20 packets** (1120 bytes) instead of full 29 packets
- **69% partial update** vs 100% full update
- Saves ~9 packets and 35ms transmission time

**What Gets Tested:**

1. **Full Update (29 packets, 1620 bytes)**
   - Baseline performance measurement
   - Complete display refresh

2. **Partial Update (20 packets, 1120 bytes)**
   - Official Epomaker's approach
   - Expected ~30-35% speed improvement

3. **Minimal Update (10 packets, 560 bytes)**
   - Extreme optimization example
   - For very targeted changes

**Performance Comparison:**
```
Full Update:     ~90ms  (all 29 packets)
Partial Update:  ~60ms  (20 packets) ← Official approach
Minimal Update:  ~35ms  (10 packets)
```

**What to Watch:**
- Actual transmission times on your hardware
- Visual quality of partial vs full updates
- Any rendering artifacts with partial updates

---

### Test 4: Screen-to-Screen Transition Demo

Animates through 5 different screens comparing:
- **Full updates** (baseline)
- **Partial updates** (optimized)

**Screens:**
1. "FRAME 1" (Red)
2. "FRAME 2" (Orange)
3. "FRAME 3" (Yellow)
4. "FRAME 4" (Green)
5. "FRAME 5" (Cyan)

**Metrics Measured:**
- Individual frame transmission times
- Total animation transmission time
- Overall performance improvement percentage

**What to Watch:**
- Smoothness of transitions
- Visual quality consistency
- Total time savings across multiple screens

---

## Expected Results

### Initialization Packet Test
```
✓ Current initialization packet     - Works as expected
✓ Official initialization packet    - Should also work
→ Both packets functional, may have subtle differences
```

### Handshake Test
```
✓ Initialization sent               - Success
✓ Get_Report handshake              - Device status retrieved
✓ Data transmission after handshake - 5 packets sent successfully
→ Handshake provides status verification, optional but beneficial
```

### Partial Update Test
```
✓ Full update to Screen 1           - Time: ~90ms
✓ Partial update to Screen 2 (20p)  - Time: ~60ms (33% faster)
✓ Full update to Screen 2           - Time: ~90ms
✓ Minimal update (10p)              - Time: ~35ms (61% faster)

Performance Gain:
  Partial vs Full: 30ms saved (33% faster)
  Minimal vs Full: 55ms saved (61% faster)
```

### Screen Transition Test
```
Animation with full updates:     ~450ms (5 × ~90ms)
Animation with partial updates:  ~300ms (5 × ~60ms)
Time saved:                      ~150ms (33% faster)

→ Partial updates significantly improve animation performance
```

---

## Troubleshooting

### Device Not Found
```
ERROR: Device not initialized. Call Connect-DynaTab first.
```
**Solution:** Ensure DynaTab keyboard is connected via USB (not Bluetooth/2.4GHz)

### Module Not Found
```
ERROR: PSDynaTab module not found at: ...
```
**Solution:** Run from PSDynaTab repository root directory

### Get_Report Fails
```
Get_Report failed: Exception...
```
**Solution:** This is informational - handshake is optional. Test continues.

### Display Artifacts with Partial Updates
**Solution:**
- Some pixel data may persist from previous display
- Use full update first, then partial updates
- Official software likely manages this internally

---

## Interpreting Results

### If Official Init Packet Shows Differences
- Document any behavioral changes
- Test extensively with various content types
- May unlock undocumented features or better compatibility

### If Get_Report Returns Meaningful Data
- Could contain firmware version, device status, error codes
- Analyze response buffer for patterns
- Implement status checking in production code

### If Partial Updates Work Well
- **Implement in PSDynaTab** for performance boost
- Add `-StartColumn`/`-EndColumn` parameters to functions
- Enable smoother animations and scrolling text
- Reduce USB bandwidth usage

---

## Next Steps After Testing

### 1. If Official Init Packet Beneficial
```powershell
# Update PSDynaTab module
$script:FIRST_PACKET = [byte[]]@(
    0xa9, 0x00, 0x01, 0x00, 0x61, 0x05, 0x00, 0xef,
    0x06, 0x00, 0x39, 0x09, 0x00, 0x00, ...
)
```

### 2. Implement Get_Report Handshake
```powershell
function Get-DynaTabStatus {
    $statusBuffer = New-Object byte[] 65
    $script:HIDStream.GetFeature($statusBuffer)
    return $statusBuffer
}

# Use in Connect-DynaTab:
Send-FeaturePacket $script:FIRST_PACKET
Start-Sleep -Milliseconds 120
$status = Get-DynaTabStatus
# Parse status...
```

### 3. Add Partial Update Support
```powershell
function Send-DynaTabImage {
    param(
        [byte[]]$PixelData,
        [int]$StartColumn = 0,
        [int]$EndColumn = 59
    )

    # Calculate packet range from column range
    $startPacket = [int]($StartColumn * 9 * 3 / 56)
    $endPacket = [int](($EndColumn * 9 * 3 + 55) / 56)

    # Send only needed packets
    ...
}
```

---

## Performance Optimization Guidelines

Based on test results:

### When to Use Full Updates (29 packets)
- Completely different content from previous screen
- First display after Connect-DynaTab
- When display state is unknown

### When to Use Partial Updates (15-20 packets)
- Updating text or graphics in center area
- Scrolling content (update only scrolled region)
- Status indicators (update specific columns)

### When to Use Minimal Updates (5-10 packets)
- Single column changes
- Small animations (progress bars, indicators)
- Real-time data displays (clocks, counters)

---

## Related Files

- **USBPCAP_REVIEW.md** - Full USBPcap trace analysis
- **Test-OfficialProtocol.ps1** - This test suite (main script)
- **PSDynaTab.psm1** - Module to be potentially updated based on findings

---

## Questions to Answer During Testing

- [ ] Do both init packets produce identical display results?
- [ ] Does Get_Report response contain useful information?
- [ ] What's the actual performance gain from partial updates on your system?
- [ ] Are there any visual artifacts with partial updates?
- [ ] Does the official init packet enable any new features?
- [ ] What's the optimal packet count for different use cases?

---

## Contributing

After running tests, please document your findings:

1. Hardware details (keyboard firmware version if known)
2. System details (Windows version, PowerShell version)
3. Test results (timings, observations, screenshots)
4. Any unexpected behavior or discoveries

This helps improve PSDynaTab for everyone!

---

## References

- **USBPcap Analysis:** See `USBPCAP_REVIEW.md` for detailed protocol documentation
- **Official Protocol:** Captured from Epomaker DynaTab software (2026-01-15)
- **Device:** Epomaker DynaTab 75X (VID: 0x3151, PID: 0x4015)
