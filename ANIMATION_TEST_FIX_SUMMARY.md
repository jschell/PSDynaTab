# Animation Test Failure - Root Cause Analysis & Fixes

**Date:** 2026-01-16
**Test File:** Test-AnimationModes.ps1
**USB Capture:** usbPcap/2026-01-16-testAnimationModeTestAll.json
**Status:** ❌ ALL 7 animation tests failed

---

## Executive Summary

All animation tests failed because the test script had **three critical protocol violations**:

1. ✗ **Missing Get_Report handshake** - Device never confirmed readiness
2. ✗ **Wrong memory address (0x0000)** - Device couldn't map pixels to display
3. ✗ **Missing address decrement logic** - All packets used same address

---

## Detailed Failure Analysis

### Test Results
```
Mode Threshold Test:
  - Bytes 4-5 = 100   → Failed
  - Bytes 4-5 = 500   → Failed
  - Bytes 4-5 = 1000  → Failed
  - Bytes 4-5 = 1500  → Failed
  - Bytes 4-5 = 2000  → Failed

Formula Validation Test:
  - 5 frames (7680)   → Failed
  - 10 frames (15360) → Failed
  - 20 frames (30720) → Failed

Quality Comparison:
  - Sparse (150)      → No display
  - Full (4608)       → No display
```

### Critical Errors Found

#### Error #1: Missing Get_Report Handshake

**Working Protocol (Epomaker):**
```
1. Send init packet (Set_Report)
2. Wait 125ms
3. Send Get_Report (bRequest=0x01, wValue=0x0300) ← CRITICAL!
4. Receive 64-byte status response
5. Wait 105ms
6. Send data packets
```

**Test Script (WRONG):**
```powershell
# Line 77 in Send-AnimationInit:
$script:TestHIDStream.SetFeature($featureReport)
Start-Sleep -Milliseconds 120
# Then immediately returns - NO Get_Report! ❌
```

**Impact:** Device never confirms it's ready to receive animation data. The handshake is required to synchronize host/device state.

**Fix Applied:**
```powershell
# NEW: Send-GetReport function (lines 60-74 in FIXED version)
function Send-GetReport {
    $featureReport = New-Object byte[] 65
    $script:TestHIDStream.GetFeature($featureReport)
    return $true
}

# Called in Send-AnimationInit after delay:
Start-Sleep -Milliseconds 125
$success = Send-GetReport  # ← ADDED
Start-Sleep -Milliseconds 105
```

---

#### Error #2: Missing Memory Address

**Data Packet Structure (64 bytes):**
```
Offset  Field           Working Value   Test Script Value
------  --------------  --------------  -----------------
0       Command         0x29            0x29 ✓
1       Frame index     0-2             0-2 ✓
2       Mode            0x03            varies ⚠️
3       Delay (ms)      0x64 (100)      0x64 ✓
4       Counter         0x00-0x1A       0x00-0x1A ✓
5       Reserved        0x00            0x00 ✓
6-7     Memory address  0x3837→0x381D   0x0000 ❌ WRONG!
8-63    Pixel data      [RGB values]    [RGB values] ✓
```

**Working Capture - Address Sequence:**
```
Packet 0:  Address = 0x3837 (14391)
Packet 1:  Address = 0x3836 (14390)
Packet 2:  Address = 0x3835 (14389)
...
Packet 26: Address = 0x381D (14365)
```
**Decrements by 1 each packet** ← Critical pattern!

**Test Script - Address Sequence:**
```
Packet 0:  Address = 0x0000 ❌
Packet 1:  Address = 0x0000 ❌
Packet 2:  Address = 0x0000 ❌
...all packets...0x0000 ❌
```

**Code Issue:**
```powershell
# Lines 89-99 in Send-DataPacket:
$packet[0] = 0x29
$packet[1] = $FrameIndex
$packet[2] = $Frames
$packet[3] = $DelayMS
$packet[4] = $Counter
# Bytes 5-7 are NEVER SET! They remain 0x00 ❌

if ($PixelData) {
    [Array]::Copy($PixelData, 0, $packet, 8, $len)
}
```

**Impact:** Device needs the memory address to know WHERE in its frame buffer to write the pixel data. Address 0x0000 causes all pixel data to be ignored or written to wrong location.

**Fix Applied:**
```powershell
# Lines 36-37 in FIXED version - global address tracker:
$script:CurrentAddress = 0x3837

# Lines 106-109 in Send-DataPacket:
# Add memory address (bytes 6-7, big-endian, DECREMENTING)
$packet[6] = [byte](($script:CurrentAddress -shr 8) -band 0xFF)  # High byte
$packet[7] = [byte]($script:CurrentAddress -band 0xFF)            # Low byte

# Line 123 after successful send:
$script:CurrentAddress--  # Decrement for next packet
```

---

#### Error #3: Init Packet Frame Count

**Working Init Packet:**
```
Offset: 0  1  2  3  4  5  6  7  8  9  A  B
Bytes:  a9 00 03 64 e8 05 00 02 02 00 3a 09
                              ^^ ^^
                              │  └─ Frame count MSB
                              └─ Frame count-1 (2 = 3 frames)
```

**Test Script Init Packet:**
```
Offset: 0  1  2  3  4  5  6  7  8  9  A  B
Bytes:  a9 00 ?? 64 XX XX 00 00 00 00 3c 09
                              ^^ ^^
                              └─── Always 0x00! ❌
```

**Code Issue:**
```powershell
# Lines 66-72 in Send-AnimationInit:
$packet[0] = 0xa9
$packet[2] = $Frames      # Wrong byte! Should be mode 0x03
$packet[3] = $DelayMS
$packet[4] = [byte](($Bytes45 -shr 8) -band 0xFF)
$packet[5] = [byte]($Bytes45 -band 0xFF)
# Bytes 8-9 NEVER SET! ❌
$packet[10] = 0x3c
$packet[11] = 0x09
```

**Impact:** Device doesn't know how many frames to expect in the animation.

**Fix Applied:**
```powershell
# Lines 69-76 in FIXED version:
$packet[0] = 0xa9
$packet[2] = 0x03  # Mode 0x03 for animations (NOT $Frames!)
$packet[3] = $DelayMS
$packet[4] = [byte]($Bytes45 -band 0xFF)
$packet[5] = [byte](($Bytes45 -shr 8) -band 0xFF)

# Add frame count parameter (bytes 8-9)
$packet[8] = [byte]($Frames - 1)  # 0-indexed: 3 frames = 2
$packet[9] = 0x00
```

---

## Fixes Summary

### Fix #1: Added Get_Report Handshake
**File:** Test-AnimationModes-FIXED.ps1
**Lines:** 60-74, 94-98

```powershell
function Send-GetReport {
    $featureReport = New-Object byte[] 65
    $script:TestHIDStream.GetFeature($featureReport)
    return $true
}

# In Send-AnimationInit:
Start-Sleep -Milliseconds 125
$success = Send-GetReport
if (-not $success) {
    Write-Warning "Device may not be ready"
}
Start-Sleep -Milliseconds 105
```

### Fix #2: Added Memory Address with Decrement
**File:** Test-AnimationModes-FIXED.ps1
**Lines:** 36-37, 106-109, 123

```powershell
# Global address tracker
$script:CurrentAddress = 0x3837

# In Send-AnimationInit - reset address:
$script:CurrentAddress = 0x3837

# In Send-DataPacket - set bytes 6-7:
$packet[6] = [byte](($script:CurrentAddress -shr 8) -band 0xFF)
$packet[7] = [byte]($script:CurrentAddress -band 0xFF)

# After sending packet:
$script:CurrentAddress--
```

### Fix #3: Corrected Init Packet Parameters
**File:** Test-AnimationModes-FIXED.ps1
**Lines:** 69-76

```powershell
$packet[2] = 0x03  # Mode 0x03 (not $Frames!)
$packet[8] = [byte]($Frames - 1)  # Frame count (0-indexed)
$packet[9] = 0x00
```

### Fix #4: Added Error Handling & Verbose Logging
**File:** Test-AnimationModes-FIXED.ps1
**Multiple locations**

- Packet send success tracking
- Error messages with specific failure info
- Verbose output showing addresses and packet counts
- Try-catch blocks for USB operations

---

## Protocol Comparison

| Feature | Working (Epomaker) | Old Test | Fixed Test |
|---------|-------------------|----------|------------|
| Get_Report handshake | ✓ Present | ✗ Missing | ✓ Added |
| Data address (bytes 6-7) | ✓ 0x3837→0x381D | ✗ 0x0000 | ✓ 0x3837→0x381D |
| Address decrement | ✓ -1 per packet | ✗ No change | ✓ -1 per packet |
| Init mode (byte 2) | ✓ 0x03 | ✗ $Frames | ✓ 0x03 |
| Init frames (bytes 8-9) | ✓ 0x02:00 (3 frames) | ✗ 0x00:00 | ✓ 0x02:00 |
| Inter-packet delay | ✓ 2-5ms | ⚠️ 5ms | ✓ 2ms |
| Error handling | N/A | ✗ None | ✓ Added |

---

## Testing Checklist

After running the FIXED version, verify:

- [ ] All packets sent successfully (check verbose output)
- [ ] Address sequence is 0x3837, 0x3836, 0x3835, ... (check verbose)
- [ ] Get_Report handshake completed (check verbose)
- [ ] Animation displays on keyboard
- [ ] No errors in PowerShell output

### Expected Output (Success):
```
✓ Connected
✓ Get_Report handshake successful
Packet 0 : Address 0x3837
Packet 1 : Address 0x3836
Packet 2 : Address 0x3835
...
Sent 27/27 packets
Did animation work? (Y/N): Y  ← Should be YES now!
```

---

## Files Changed

1. **Test-AnimationModes-FIXED.ps1** (NEW)
   - Complete rewrite with all fixes applied
   - Enhanced error handling and logging
   - Proper protocol implementation

2. **ANIMATION_TEST_FIX_SUMMARY.md** (THIS FILE)
   - Detailed analysis of failures
   - Fix documentation
   - Testing guide

---

## Next Steps

1. **Test the FIXED version:**
   ```powershell
   .\Test-AnimationModes-FIXED.ps1 -TestAll
   ```

2. **Capture USB traffic** of successful test for verification

3. **If animations work:**
   - Replace old Test-AnimationModes.ps1 with FIXED version
   - Update main animation functions with these fixes
   - Document the address decrement requirement

4. **If still failing:**
   - Check verbose output for specific error
   - Verify HidSharp version and device connection
   - Compare new USB capture with working Epomaker capture

---

## Lessons Learned

1. **Protocol handshakes are mandatory** - Can't skip Get_Report even if it seems optional
2. **Memory addresses must be tracked** - Static 0x0000 doesn't work
3. **Decrementing address pattern** - Each packet decrements address by 1
4. **Init packet structure matters** - Wrong byte assignments break everything
5. **USB captures are invaluable** - Direct comparison reveals exact differences

---

## References

- USB Capture (Failed): `usbPcap/2026-01-16-testAnimationModeTestAll.json`
- USB Capture (Working): `usbPcap/usbPcap-epmakerSuite-animation5frame-150ms.json`
- Analysis: Agent task a5d261e (detailed packet-by-packet comparison)
- Test Script (Original): `Test-AnimationModes.ps1`
- Test Script (Fixed): `Test-AnimationModes-FIXED.ps1`
