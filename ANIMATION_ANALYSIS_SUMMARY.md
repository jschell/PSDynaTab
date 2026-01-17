# Animation Test USB Capture Analysis - Summary Report

## Date: 2026-01-17
## Files Analyzed: 5 animation test captures

---

## CRITICAL DISCOVERY: Unknown Mode 0x04

**The animation captures use MODE 0x04, which is neither picture nor animation mode!**

- **Picture mode (from picture tests):** 0x01
- **Animation mode (from FIXED script):** 0x03
- **Mode used in ALL 5 captures:** **0x04** ← UNDOCUMENTED MODE

This suggests either:
1. A new/experimental mode was being tested
2. The test script has a bug setting the wrong mode
3. Mode 0x04 is a variant of animation or picture mode

---

## Protocol Compliance Summary

### ✓ PASSING (5/5 animations)
1. **Get_Report handshake** - Present in all captures (118-132ms after init)
2. **Memory addresses** - Correct decrementing from 0x3836 by 1
3. **Complete data transmission** - All packets sent successfully
4. **Packet structure** - Init (0xa9) and Data (0x29) types correct

### ✗ FAILING (5/5 animations)
1. **Mode byte** - Uses 0x04 instead of expected 0x03
2. **Frame count** - Init reports 1 frame but sends 4 frames
3. **Filename accuracy** - Claims 1-3 frames but all send 4 frames

**Overall Compliance Score: 50%** (2 critical violations)

---

## Individual Animation Results

### Animation 1: "3-Frame (Red, Green, Blue) - Connected Corners"
**File:** `2026-01-17-animation-ff-00-00-00-ff-00-00-00-ff-connected-corners-1pixel-each.json`

- **Claimed frames:** 3 (red, green, blue)
- **Actual frames sent:** 4
- **Total packets:** 114 (1 init + 113 data)
- **Pattern:** Positions 0 and 8 with rotating RGB colors
- **Protocol:** Get_Report ✓, Addresses ✓, Mode ✗, Frame count ✗

### Animation 2: "2-Frame (Red, Green) - Connected Corners"  
**File:** `2026-01-17-animation-ff-00-00-00-ff-00-connected-corners-1pixel-each.json`

- **Claimed frames:** 2 (red, green)
- **Actual frames sent:** 4
- **Total packets:** 117 (1 init + 116 data)
- **Pattern:** Positions 0 and 8 with red, green, blue mix
- **Protocol:** Get_Report ✓, Addresses ✓, Mode ✗, Frame count ✗

### Animation 3: "1-Frame (Red) - Connected Corners"
**File:** `2026-01-17-animation-ff-00-00-connected-corners-1pixel-each.json`

- **Claimed frames:** 1 (red only)
- **Actual frames sent:** 4
- **Total packets:** 117 (1 init + 116 data)
- **Pattern:** Positions 0 and 8 with red and green
- **Protocol:** Get_Report ✓, Addresses ✓, Mode ✗, Frame count ✗

### Animation 4: "1-Frame (Red) - Corners"
**File:** `2026-01-17-animation-ff-00-00-corners-1pixel.json`

- **Claimed frames:** 1 (red only)
- **Actual frames sent:** 4
- **Total packets:** 117 (1 init + 116 data)
- **Pattern:** SINGLE pixel alternating between positions 0 and 8
- **Difference:** Only one pixel per frame (vs two in "connected corners")
- **Protocol:** Get_Report ✓, Addresses ✓, Mode ✗, Frame count ✗

### Animation 5: "1-Frame (Red) - Opposite Corners"
**File:** `2026-01-17-animation-ff-00-00-opposite-corners-1pixel-each.json`

- **Claimed frames:** 1 (red only)
- **Actual frames sent:** 4
- **Total packets:** 117 (1 init + 116 data)
- **Pattern:** Red + Green at same positions across all frames
- **Protocol:** Get_Report ✓, Addresses ✓, Mode ✗, Frame count ✗

---

## Animation Patterns Explained

### "Connected Corners"
- **Positions:** 0 and 8 **simultaneously**
- **Behavior:** Both pixels lit in same frame
- **Example:** Frame 0 has pixel at pos 0 (red) AND pos 8 (green)

### "Corners"  
- **Positions:** 0 or 8 **alternating**
- **Behavior:** Only ONE pixel lit per frame
- **Example:** Frame 0 has pixel at pos 0, Frame 1 has pixel at pos 8

### "Opposite Corners"
- **Expected:** Should be positions like 0 and 17 (diagonal)
- **Actual:** Uses same positions as "connected corners" (0 and 8)
- **Conclusion:** Test may not be working as intended

---

## Common Protocol Parameters (ALL 5)

| Parameter | Value | Status |
|-----------|-------|--------|
| Init packet type | 0xa9 | ✓ |
| Data packet type | 0x29 | ✓ |
| Mode byte | 0x04 | ✗ (expected 0x03) |
| Frame delay | 100 ms | ✓ |
| Bytes 4-5 | 1620 (0x0654) | ? |
| Init address | 0x3c09 | ✓ |
| Data start address | 0x3836 | ✓ |
| Address decrement | -1 per packet | ✓ |
| Get_Report timing | 118-132 ms | ✓ |

---

## Frame Count Discrepancy

**The #1 Critical Issue:** All animations report wrong frame count

```
Filename says:   1, 2, or 3 frames
Init packet:     0 (= 1 frame in 0-indexed)
Actually sent:   4 frames (0, 1, 2, 3)
```

**Hypothesis:** 
- Device firmware may have 4-frame default/limitation
- Test script may not be correctly setting frame count
- Or captures were taken during wrong test execution

---

## Comparison to Test-AnimationModes-FIXED.ps1

The FIXED protocol script expects:

| Fix | Expected | Status in Captures |
|-----|----------|-------------------|
| Get_Report handshake | After init packet | ✓ PRESENT (118-132ms) |
| Memory addresses | Decrement from 0x3837 | ✓ CORRECT (0x3836) |
| Mode byte | 0x03 | ✗ Uses 0x04 |
| Frame count | Correct value in bytes 8-9 | ✗ Always 0 |
| Complete transmission | All packets sent | ✓ COMPLETE |

**Conclusion:** Captures implement 2 of 4 critical fixes (50%)

---

## Recommendations

### 1. **Investigate Mode 0x04** (HIGH PRIORITY)
- Determine if mode 0x04 is:
  - Valid animation mode variant
  - Picture mode variant  
  - Experimental/undocumented mode
  - Test script bug
- Compare behavior with mode 0x03

### 2. **Fix Frame Count** (HIGH PRIORITY)
- Update test script to correctly set bytes 8-9 in init packet
- Test: Does device respect frame count or default to 4?
- Verify: Can device support 1, 2, 3, or >4 frames?

### 3. **Verify Test Execution** (MEDIUM PRIORITY)
- Re-run animation tests with correct parameters
- Ensure captures match intended test (1-frame should send 1 frame!)
- Validate filename accuracy

### 4. **Additional Testing** (LOW PRIORITY)
- Capture animations with mode 0x03 to compare
- Test true 1-frame, 2-frame, 3-frame animations
- Verify "opposite corners" pattern works correctly

---

## Files Generated

1. **ANIMATION_ANALYSIS_REPORT.txt** - Full detailed report
2. **ANIMATION_ANALYSIS_SUMMARY.md** - This summary (Markdown format)

---

## Mode Reference Table

| Mode | Purpose | Source |
|------|---------|--------|
| 0x01 | Picture Mode | 2026-01-17 picture tests |
| 0x03 | Animation Mode | Test-AnimationModes-FIXED.ps1 |
| 0x04 | **UNKNOWN** | 2026-01-17 animation captures |

**Mystery:** What is mode 0x04? This requires investigation.

---

*Analysis completed: 2026-01-17*
