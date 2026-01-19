# Static Picture Test USB Capture Analysis Report
## Date: 2026-01-19
## Test Date: 2026-01-17

---

## Executive Summary

Analyzed 12 static picture test USB captures from 2026-01-17 covering:
- **TEST-STATIC-001**: Single Pixel Corner Validation (TC-001-A through TC-001-D)
- **TEST-STATIC-005**: Partial Screen Updates / Row Tests
- **Additional multi-corner tests** (not in formal test plan)

### Key Findings

1. ✅ **Protocol Structure Confirmed**: Static picture mode uses 0xa9 init packets followed by 0x29 data packets
2. ❌ **Critical Issue**: All tests show pixel count mismatches between init packet declarations and actual data
3. ✅ **Fixed Data Packet Size**: Each data packet contains exactly 18 RGB triplets (54 bytes), regardless of declared region size
4. ✅ **Position Encoding**: Bytes [8-11] encode position/size information, likely as bounding box coordinates

---

## Protocol Structure

### Init Packet (0xa9) - 64 bytes
```
Byte[0]      = 0xa9 (packet type identifier)
Byte[1]      = 0x00 (always)
Byte[2]      = 0x01 (always)
Byte[3]      = 0x00 (always)
Byte[4:5]    = Unknown field (little-endian 16-bit)
Byte[6:7]    = Unknown field (little-endian 16-bit) - possibly checksum or pixel count
Byte[8]      = X-start position (0-indexed)
Byte[9]      = Y-start position (0-indexed)
Byte[10]     = X-end or Width
Byte[11]     = Y-end or Height
Byte[12:63]  = Padding (all zeros)
```

### Data Packet (0x29) - 64 bytes
```
Byte[0]      = 0x29 (packet type identifier)
Byte[1]      = 0x00 (always)
Byte[2]      = 0x01 (always)
Byte[3]      = 0x00 (always)
Byte[4]      = Packet index (0, 1, 2, ... sequential)
Byte[5]      = 0x00 (always)
Byte[6:7]    = Unknown field (little-endian 16-bit)
Byte[8:63]   = RGB pixel data (18 complete RGB triplets = 54 bytes)
```

---

## Test Results

### TEST-STATIC-001: Single Pixel Corner Validation

#### TC-001-A: Top-Left Pixel (0, 0)
- **File**: `2026-01-17-picture-topLeft-1pixel-00-ff-00.json`
- **Init Packet**:
  - Position: (0, 0)
  - Bytes [10:11]: (1, 1)
  - Interpretation: Single pixel at top-left
- **Data Packets**: 1 packet with 18 RGB triplets
- **First Pixel**: RGB(0, 255, 0) = Green (#00ff00) ✓
- **Issue**: Init declares 1x1 region but data packet contains 18 pixels
- **Status**: ❌ Pixel count mismatch

#### TC-001-B: Top-Right Pixel (59, 0)
- **File**: `2026-01-17-picture-topRight-1pixel-00-ff-00.json`
- **Init Packet**:
  - Position: (59, 0)
  - Bytes [10:11]: (60, 1)
  - Interpretation: Single pixel at top-right (display is 60 pixels wide)
- **Data Packets**: 1 packet with 18 RGB triplets
- **First Pixel**: RGB(0, 255, 0) = Green (#00ff00) ✓
- **Issue**: Init declares ambiguous region, data packet contains 18 pixels
- **Status**: ❌ Pixel count mismatch

#### TC-001-C: Bottom-Left Pixel (0, 8)
- **File**: `2026-01-17-picture-bottomLeft-1pixel-00-ff-00.json`
- **Init Packet**:
  - Position: (0, 8)
  - Bytes [10:11]: (1, 9)
  - Interpretation: Single pixel at bottom-left (display is 9 pixels tall)
- **Data Packets**: 1 packet with 18 RGB triplets
- **First Pixel**: RGB(0, 255, 0) = Green (#00ff00) ✓
- **Issue**: Init declares 1x9 region, data packet contains 18 pixels
- **Status**: ❌ Pixel count mismatch

#### TC-001-D: Bottom-Right Pixel (59, 8)
- **File**: `2026-01-17-picture-bottomRight-1pixel-00-ff-00.json`
- **Init Packet**:
  - Position: (59, 8)
  - Bytes [10:11]: (60, 9)
  - Interpretation: Single pixel at bottom-right
- **Data Packets**: 1 packet with 18 RGB triplets
- **First Pixel**: RGB(0, 255, 0) = Green (#00ff00) ✓
- **Issue**: Init declares 60x9 region, data packet contains 18 pixels
- **Status**: ❌ Pixel count mismatch

**NOTE**: User confirmed TC-001-D was **NOT executed** per test plan, but a capture exists with this name.

---

### TEST-STATIC-005: Partial Screen Updates

#### TC-005: Top Row Spaced (15 pixels)
- **File**: `2026-01-17-picture-topRowSpaced-15pixel-ff-00-00.json`
- **Init Packet**: Position (0, 0), Size: 57x1
- **Data Packets**: 4 packets = 72 RGB triplets total
- **Expected**: 57 pixels
- **Actual**: 72 pixels
- **Status**: ❌ Pixel count mismatch (excess data)

#### TC-005: Top + Bottom Row Spaced (15 pixels each)
- **File**: `2026-01-17-picture-topRowSpaced-15pixel-ff-00-00-bottomRowSpaced-15pixel-ff-00-00.json`
- **Init Packet**: Position (0, 0), Size: 60x9
- **Data Packets**: 29 packets = 522 RGB triplets total
- **Expected**: 540 pixels (60x9)
- **Actual**: 522 pixels
- **Status**: ❌ Pixel count mismatch (missing data)

#### TC-005: Mixed Row Spacing (15 + 4 pixels)
- **File**: `2026-01-17-picture-topRowSpaced-15pixel-ff-00-00-bottomRowSpaced-4pixel-ff-00-00.json`
- **Init Packet**: Position (0, 0), Size: 57x9
- **Data Packets**: 28 packets = 504 RGB triplets total
- **Expected**: 513 pixels (57x9)
- **Actual**: 504 pixels
- **Status**: ❌ Pixel count mismatch

---

### Multi-Corner Tests (Additional Testing)

#### Top-Left + Top-Right
- **File**: `2026-01-17-picture-topLeft-ff-00-00-topRight-1pixel-00-ff-00.json`
- **Init Packet**: Position (0, 0), Size: 60x1
- **Data Packets**: 4 packets = 72 RGB triplets total
- **Expected**: 60 pixels
- **Actual**: 72 pixels
- **First Pixel**: RGB(255, 0, 0) = Red (#ff0000) ✓
- **Status**: ❌ Pixel count mismatch

---

## Protocol Compliance Analysis

### ✅ Compliant Behaviors
1. **Packet Type Identifiers**: All init packets use 0xa9, all data packets use 0x29
2. **Standard Header Fields**: Bytes [1-3] are consistently 0x00, 0x01, 0x00
3. **Sequential Indexing**: Data packet indices increment correctly (0, 1, 2, ...)
4. **Color Encoding**: RGB values are correctly encoded in triplets
5. **Packet Ordering**: Init packet always precedes data packets

### ❌ Non-Compliant / Anomalous Behaviors
1. **Pixel Count Mismatches**: All 12 tests show discrepancies between declared and actual pixel counts
2. **Fixed Packet Size**: Data packets always contain 18 RGB triplets regardless of region size
3. **Unclear Position Encoding**: Bytes [10-11] interpretation is ambiguous (size vs. end coordinates)
4. **Inconsistent Padding**: Some tests send excess pixels, others send fewer than expected

---

## Position Encoding Hypothesis

Based on corner test data, the most likely interpretation of bytes [8-11]:

### Hypothesis 1: Bounding Box (Start + End Coordinates)
```
Byte[8]  = X-start (0-indexed)
Byte[9]  = Y-start (0-indexed)
Byte[10] = X-end (exclusive or inclusive?)
Byte[11] = Y-end (exclusive or inclusive?)
```

**Evidence Supporting**:
- Top-Left (0,0): [8:11] = (0, 0, 1, 1) - could be (0,0) to (1,1) exclusive = 1x1
- Top-Right (59,0): [8:11] = (59, 0, 60, 1) - could be (59,0) to (60,1) exclusive = 1x1
- Bottom-Right (59,8): [8:11] = (59, 8, 60, 9) - could be (59,8) to (60,9) exclusive = 1x1

**Evidence Against**:
- If display is 60x9 (pixels 0-59 by 0-8), then (60,9) is out of bounds
- Multi-corner test shows (0, 0, 60, 1) which would be 60x1 pixels

### Hypothesis 2: Position + Dimension
```
Byte[8]  = X-position (0-indexed)
Byte[9]  = Y-position (0-indexed)
Byte[10] = Width in pixels
Byte[11] = Height in pixels
```

**Evidence Against**:
- Top-Right shows [10]=60 for a single pixel (makes no sense as width)
- Inconsistent with observed behavior

### Hypothesis 3: Display Coordinates (Non-Standard)
The encoding may use display-specific coordinate system where [10-11] represent absolute positions on the display rather than dimensions.

---

## Comparison to Animation Mode

### Similarities
- Both use 0xa9 init packets and 0x29 data packets
- Same header structure (bytes 0-7)
- Same RGB triplet encoding
- Sequential packet indexing

### Differences

| Aspect | Animation Mode | Static Picture Mode |
|--------|---------------|---------------------|
| Init Packet [8-11] | Frame-relative position | Absolute display position |
| Pixel Count Compliance | Generally matches | Consistent mismatches |
| Data Packet Size | Variable (based on frame) | Fixed at 18 RGB triplets |
| Use Case | Multi-frame sequences | Single frame updates |

**Key Insight**: Animation mode appears to have better pixel count alignment, suggesting static picture mode may have implementation issues or undocumented behavior.

---

## Critical Issues Identified

### Issue #1: Fixed Data Packet Size
**Severity**: HIGH
**Description**: All data packets contain exactly 18 RGB triplets (54 bytes), regardless of the region size declared in the init packet.

**Impact**:
- Wastes bandwidth for small regions (e.g., single pixel sends 18 pixels)
- May cause buffer overruns or incomplete renders for large regions
- Makes the protocol less efficient

**Recommendation**: Investigate if this is:
1. A hardware limitation (fixed 64-byte USB packet size - 8 byte header - 2 byte alignment = 54 bytes max)
2. A firmware bug
3. Intended behavior with padding

### Issue #2: Pixel Count Mismatches
**Severity**: HIGH
**Description**: Declared region sizes in init packets don't match actual pixel data sent.

**Examples**:
- Single pixel (1x1) sends 18 pixels
- 57x1 region sends 72 pixels (expected 57)
- 60x9 region sends 522 pixels (expected 540)

**Recommendation**:
1. Clarify bytes [10-11] encoding with hardware vendor
2. Determine if excess pixels are ignored or cause issues
3. Test if missing pixels cause rendering artifacts

### Issue #3: Ambiguous Position Encoding
**Severity**: MEDIUM
**Description**: Bytes [10-11] can be interpreted as either:
- End coordinates (bounding box)
- Width/Height dimensions
- Display-specific coordinates

**Impact**: Impossible to implement compliant driver without vendor documentation

**Recommendation**: Request official protocol specification from Epomaker

---

## Recommendations

### For Implementation
1. **Use Epomaker's proven patterns**: Reference the Epomaker GUI captures for position encoding
2. **Always send 18 RGB triplets per data packet**: Match observed behavior
3. **Pad with zeros**: For regions smaller than 18 pixels, pad remaining space
4. **Split large regions**: For regions larger than 18 pixels, use multiple data packets

### For Testing
1. **Compare with Epomaker GUI**: Capture same test scenarios using official software
2. **Test boundary conditions**: Single pixels at all four corners
3. **Test partial updates**: Various row/column combinations
4. **Measure timing**: Check if delays between packets matter

### For Documentation
1. **Request vendor specs**: Official protocol documentation from Epomaker
2. **Document workarounds**: Record all discovered encoding quirks
3. **Create reference implementation**: Build verified test cases

---

## Test Coverage Summary

| Test Category | Tests Found | Tests Executed | Protocol Compliant | Color Correct |
|--------------|-------------|----------------|-------------------|---------------|
| TC-001 (Corners) | 4 | 3-4* | 0/4 | 4/4 |
| TC-005 (Rows) | 4 | 4 | 0/4 | 4/4 |
| Multi-Corner | 4 | 4 | 0/4 | 4/4 |
| **TOTAL** | **12** | **11-12*** | **0/12 (0%)** | **12/12 (100%)** |

*TC-001-D status unclear per user comment

---

## Conclusions

1. **Static picture mode is functional but non-compliant**: All tests successfully set pixels to correct colors, but violate declared pixel counts

2. **Fixed packet size limitation**: The 18 RGB triplet limit appears to be a hardware or firmware constraint, not a bug

3. **Position encoding needs clarification**: Without vendor documentation, the exact meaning of bytes [10-11] remains ambiguous

4. **Epomaker implementation works despite violations**: The official GUI software likely uses the same protocol with the same quirks, suggesting this is "working as designed" even if not as documented

5. **Further testing needed**: Compare these captures with Epomaker GUI captures of identical scenarios to confirm behavior

---

## Files Analyzed

All captures from `/home/user/PSDynaTab/usbPcap/`:

1. `2026-01-17-picture-topLeft-1pixel-00-ff-00.json` (TC-001-A)
2. `2026-01-17-picture-topRight-1pixel-00-ff-00.json` (TC-001-B)
3. `2026-01-17-picture-bottomLeft-1pixel-00-ff-00.json` (TC-001-C)
4. `2026-01-17-picture-bottomRight-1pixel-00-ff-00.json` (TC-001-D)
5. `2026-01-17-picture-topRowSpaced-15pixel-ff-00-00.json` (TC-005)
6. `2026-01-17-picture-topRowSpaced-15pixel-ff-00-00-bottomRowSpaced-4pixel-ff-00-00.json` (TC-005)
7. `2026-01-17-picture-topRowSpaced-15pixel-ff-00-00-bottomRowSpaced-15pixel-ff-00-00.json` (TC-005)
8. `2026-01-17-picture-RowSpaced-25percent-ff-00-00.json` (TC-005)
9. `2026-01-17-picture-topLeft-ff-00-00-topRight-1pixel-00-ff-00.json` (Multi-corner)
10. `2026-01-17-picture-topLeft-00-ff-00-bottomLeft-ff-00-00.json` (Multi-corner)
11. `2026-01-17-picture-topRight-00-ff-00-bottomLeft-ff-00-00.json` (Multi-corner)
12. `2026-01-17-picture-topLeft-00-ff-00-bottomRight-1pixel-ff-00-00.json` (Multi-corner)

---

## Appendix: Raw Data Examples

### Example 1: Single Pixel Init Packet (TC-001-A)
```
a9:00:01:00:03:00:00:52:00:00:01:01:00:00:00:00:...
│  │  │  │  │     │     │  │  │  │
│  │  │  │  │     │     │  │  │  └─ Byte[11] = 0x01 (height or Y-end)
│  │  │  │  │     │     │  │  └──── Byte[10] = 0x01 (width or X-end)
│  │  │  │  │     │     │  └─────── Byte[9]  = 0x00 (Y-start)
│  │  │  │  │     │     └────────── Byte[8]  = 0x00 (X-start)
│  │  │  │  │     └──────────────── Byte[6:7] = 0x5200 (20992 LE)
│  │  │  │  └────────────────────── Byte[4:5] = 0x0300 (3 LE)
│  │  │  └───────────────────────── Byte[3] = 0x00
│  │  └──────────────────────────── Byte[2] = 0x01
│  └─────────────────────────────── Byte[1] = 0x00
└────────────────────────────────── Byte[0] = 0xa9 (init packet)
```

### Example 2: Data Packet (All Single Pixel Tests)
```
29:00:01:00:00:00:03:d2:00:ff:00:00:00:00:00:00:00:...
│  │  │  │  │  │  │     └─────────── RGB triplets start here
│  │  │  │  │  │  └────────────────── Byte[6:7] = 0xd203 (53763 LE)
│  │  │  │  │  └───────────────────── Byte[5] = 0x00
│  │  │  │  └──────────────────────── Byte[4] = 0x00 (packet index)
│  │  │  └─────────────────────────── Byte[3] = 0x00
│  │  └────────────────────────────── Byte[2] = 0x01
│  └───────────────────────────────── Byte[1] = 0x00
└──────────────────────────────────── Byte[0] = 0x29 (data packet)

First 3 pixels:
  [0] = 00:ff:00 (Green)
  [1] = 00:00:00 (Black)
  [2] = 00:00:00 (Black)
... 15 more black pixels for padding
```

---

**Analysis performed**: 2026-01-19
**Analysis tool**: Custom Python script (`analyze_static_picture_tests.py`)
**Data source**: USB packet captures from 2026-01-17
