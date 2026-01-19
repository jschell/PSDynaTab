# Next Testing Steps - Consolidated Action Plan

**Document Purpose:** Prioritized, actionable test plan based on validation analysis
**Created:** 2026-01-19
**Status:** Ready to execute
**Prerequisites:** TEST-ANIM-001 complete, static corner tests complete

---

## Executive Summary

Based on validation testing analysis, **3 critical gaps** block full protocol implementation:
1. **Checksum algorithm** (bytes 6-7) - Cannot generate valid packets independently
2. **Variant selection** (bytes 4-5, 8-9) - Cannot reliably choose optimal performance
3. **Position encoding** (bytes 10-11) - Uncertain region specification

**Immediate workaround:** Use Variant D (full frame) and copy bytes from working captures

**Goal:** Complete Phase 1 tests to enable independent packet generation and variant optimization

---

## Phase 1: Critical Gaps (Priority: HIGH)

**Timeline:** 1-2 weeks
**Blockers Removed:** Independent packet generation, variant selection, partial updates

### Test 1A: Checksum Algorithm Reverse Engineering

**Objective:** Derive formula for init packet byte 7 (checksum)

**Current Status:**
- ✓ Pattern observed: Byte 7 varies inversely with delay (byte 3)
- ✓ Different values for different variants
- ❌ Algorithm unknown

**Evidence:**
```
TC-001-A (2-frame, Variant B):
  Delay 50ms  (0x32) → Byte 7 = 0xDD
  Delay 100ms (0x64) → Byte 7 = 0xAB
  Delay 150ms (0x96) → Byte 7 = 0x79
  Delay 200ms (0xC8) → Byte 7 = 0x47
  Delay 250ms (0xFA) → Byte 7 = 0x15
```

**Test Procedure:**

1. **Setup:**
   ```powershell
   # Use Test-AnimationModes-FIXED.ps1 as base
   # Modify to send custom init packets
   ```

2. **Test Matrix:**
   | Test | Vary | Fixed | Observe |
   |------|------|-------|---------|
   | 1A-1 | Byte 3 (delay): 0x00, 0x32, 0x64, 0x96, 0xC8, 0xFA, 0xFF | Bytes 0-2, 4-6, 8-11 constant | Byte 7 pattern |
   | 1A-2 | Byte 2 (frames): 0x01, 0x02, 0x03, 0x04, 0x05 | Bytes 0, 1, 3-6, 8-11 constant | Byte 7 pattern |
   | 1A-3 | Bytes 4-5: 0x0000, 0x0144, 0x0654, 0xFFFF | Bytes 0-3, 6, 8-11 constant | Byte 7 pattern |
   | 1A-4 | Bytes 8-9: 0x0000, 0x0100, 0x0200 | Bytes 0-7, 10-11 constant | Byte 7 pattern |

3. **Implementation:**
   ```powershell
   # Test 1A-1: Delay variation
   $baseInit = @(0xa9, 0x00, 0x03, 0x64, 0x44, 0x01, 0x00, 0xAB, 0x01, 0x00, 0x0d, 0x09) + @(0) * 52

   foreach ($delay in @(0x00, 0x32, 0x64, 0x96, 0xC8, 0xFA, 0xFF)) {
       # Keep bytes 6-7 at 0x00 for now, observe if device accepts
       $testInit = $baseInit.Clone()
       $testInit[3] = $delay
       $testInit[6] = 0x00  # Zero out checksum
       $testInit[7] = 0x00  # Will calculate later

       # Send and capture response
       Send-HidFeatureReport -Data $testInit
       Start-Sleep -Milliseconds 120
       $response = Get-HidFeatureReport

       # Record: delay value, response, whether animation works
       Write-Log "Delay: 0x$($delay.ToString('X2')), Response: $response"
   }
   ```

4. **Analysis:**
   - Plot byte 7 vs varied parameter
   - Test hypotheses:
     - XOR of bytes 0-6?
     - Sum of bytes with wraparound?
     - CRC-8 variant?
     - Complement of specific bytes?

5. **Validation:**
   - Derive formula
   - Generate init packet with calculated byte 7
   - Test: Does device accept packet?
   - Test: Does animation display correctly?

**Success Criteria:**
- [ ] Formula derived for byte 7 calculation
- [ ] Test animation with calculated checksum displays correctly
- [ ] Formula validated across all 4 variants

**Deliverables:**
- Checksum calculation function
- Test results spreadsheet
- Updated DYNATAB_PROTOCOL_SPECIFICATION.md

---

### Test 1B: Variant Selection Rules

**Objective:** Understand how bytes 4-5 and 8-9 determine animation variant

**Current Status:**
- ✓ 4 variants identified (A, B, C, D)
- ✓ Different bytes 4-5 and 8-9 values observed per variant
- ❌ Selection mechanism unknown

**Evidence:**
```
Variant A (Official): Bytes 4-5 = varies, Bytes 8-9 = 0x0200, 9 pkt/frame
Variant B (Sparse):   Bytes 4-5 = 0x0144, Bytes 8-9 = 0x0100, 6 pkt/frame
Variant C (Ultra):    Bytes 4-5 = 0x0036, Bytes 8-9 = 0x0000, 1 pkt/frame
Variant D (Full):     Bytes 4-5 = varies, Bytes 8-9 = 0x0000, 29 pkt/frame
```

**Test Procedure:**

1. **Test Matrix:**
   | Test | Bytes 4-5 | Bytes 8-9 | Expected Variant | Measure |
   |------|-----------|-----------|------------------|---------|
   | 1B-1 | 0x0144 | 0x0100 | Variant B | Packet count |
   | 1B-2 | 0x0036 | 0x0000 | Variant C | Packet count |
   | 1B-3 | 0x0654 | 0x0000 | Variant D | Packet count |
   | 1B-4 | varies | 0x0200 | Variant A | Packet count |
   | 1B-5 | 0x0144 | 0x0000 | ? | Packet count |
   | 1B-6 | 0x0036 | 0x0100 | ? | Packet count |
   | 1B-7 | 0x0000 | 0x0000 | ? | Packet count |
   | 1B-8 | 0xFFFF | 0x0000 | ? | Packet count |

2. **Implementation:**
   ```powershell
   function Test-VariantSelection {
       param(
           [uint16]$Bytes45,
           [uint16]$Bytes89,
           [string]$TestName
       )

       # Build init packet
       $init = New-Object byte[] 64
       $init[0] = 0xa9
       $init[2] = 0x03  # 3 frames
       $init[3] = 0x64  # 100ms delay
       $init[4] = [byte]($Bytes45 -band 0xFF)
       $init[5] = [byte](($Bytes45 -shr 8) -band 0xFF)
       # Byte 6-7: Copy from working capture or calculate
       $init[8] = [byte]($Bytes89 -band 0xFF)
       $init[9] = [byte](($Bytes89 -shr 8) -band 0xFF)
       $init[10] = 0x0d
       $init[11] = 0x09

       # Send init + data packets, count how many needed
       Send-HidFeatureReport -Data $init
       Start-Sleep -Milliseconds 120
       Get-HidFeatureReport | Out-Null
       Start-Sleep -Milliseconds 105

       # Send data packets until complete
       $packetsSent = 0
       for ($frame = 0; $frame -lt 3; $frame++) {
           # Send packets for this frame
           # (implementation depends on variant discovery)
       }

       Write-Log "$TestName : Bytes4-5=0x$($Bytes45.ToString('X4')), Bytes8-9=0x$($Bytes89.ToString('X4')), Packets=$packetsSent"

       return $packetsSent
   }

   # Run all test cases
   Test-VariantSelection -Bytes45 0x0144 -Bytes89 0x0100 -TestName "1B-1_VariantB"
   Test-VariantSelection -Bytes45 0x0036 -Bytes89 0x0000 -TestName "1B-2_VariantC"
   # etc.
   ```

3. **Analysis:**
   - Map bytes 4-5, 8-9 values to resulting packet counts
   - Identify which byte(s) determine variant
   - Test if bytes 4-5 = pixel/packet count indicator
   - Test if bytes 8-9 = variant selector

4. **Validation:**
   - Intentionally select each variant
   - Verify packet count matches expected
   - Verify animation displays correctly

**Success Criteria:**
- [ ] Variant selection rules documented
- [ ] Can reliably trigger Variant B (6 pkt/frame)
- [ ] Can reliably trigger Variant C (1 pkt/frame)
- [ ] Can reliably trigger Variant D (29 pkt/frame)

**Deliverables:**
- Variant selection decision tree
- Test results table
- Updated DYNATAB_PROTOCOL_SPECIFICATION.md

---

### Test 1C: Position Encoding Validation

**Objective:** Confirm meaning of init packet bytes 10-11 for static mode

**Current Status:**
- ✓ Bytes 8-9 appear to be X-start, Y-start
- ⚠ Bytes 10-11 suspected to be X-end, Y-end (exclusive) or Width, Height
- ❌ Not confirmed

**Evidence:**
```
Single pixel (0,0):    Bytes [8-11] = 0, 0, 1, 1
Single pixel (59,0):   Bytes [8-11] = 59, 0, 60, 1
Single pixel (59,8):   Bytes [8-11] = 59, 8, 60, 9
Full screen:           Bytes [8-11] = 0, 0, 60, 9
```

**Hypothesis:** Bytes 10-11 = X-end (exclusive), Y-end (exclusive)

**Test Procedure:**

1. **Test Matrix:**
   | Test | X-start | Y-start | Byte 10 | Byte 11 | Expected Region | Pixels |
   |------|---------|---------|---------|---------|-----------------|--------|
   | 1C-1 | 0 | 0 | 10 | 1 | (0,0) to (9,0) | 10 pixels, row 0 |
   | 1C-2 | 0 | 0 | 1 | 5 | (0,0) to (0,4) | 5 pixels, column 0 |
   | 1C-3 | 10 | 2 | 20 | 5 | (10,2) to (19,4) | 30 pixels (10×3) |
   | 1C-4 | 25 | 4 | 35 | 5 | (25,4) to (34,4) | 10 pixels, row 4 |
   | 1C-5 | 0 | 0 | 30 | 9 | (0,0) to (29,8) | 270 pixels (half) |

2. **Implementation:**
   ```powershell
   function Test-PositionEncoding {
       param(
           [byte]$XStart,
           [byte]$YStart,
           [byte]$Byte10,
           [byte]$Byte11,
           [string]$TestName
       )

       # Build init packet
       $init = New-Object byte[] 64
       $init[0] = 0xa9
       $init[2] = 0x01  # Static mode
       $init[8] = $XStart
       $init[9] = $YStart
       $init[10] = $Byte10
       $init[11] = $Byte11
       # Bytes 4-7: Copy from working static capture

       Send-HidFeatureReport -Data $init
       Start-Sleep -Milliseconds 120
       Get-HidFeatureReport | Out-Null
       Start-Sleep -Milliseconds 105

       # Send data packets with red pixels (easy to see)
       $dataPacket = New-Object byte[] 64
       $dataPacket[0] = 0x29
       $dataPacket[2] = 0x01
       $dataPacket[4] = 0x00

       # Fill with red pixels
       for ($i = 0; $i -lt 18; $i++) {
           $dataPacket[8 + ($i * 3) + 0] = 0xFF  # Red
           $dataPacket[8 + ($i * 3) + 1] = 0x00
           $dataPacket[8 + ($i * 3) + 2] = 0x00
       }

       Send-HidFeatureReport -Data $dataPacket

       # Visual verification
       Write-Host "`n$TestName : Region ($XStart,$YStart) to ($Byte10,$Byte11)"
       Write-Host "Expected: Red pixels in specified region"
       $result = Read-Host "Did pixels appear in correct region? (Y/N)"

       return $result -eq 'Y'
   }

   # Run tests
   Test-PositionEncoding 0 0 10 1 "1C-1_TopRow10px"
   Test-PositionEncoding 0 0 1 5 "1C-2_LeftColumn5px"
   # etc.
   ```

3. **Visual Verification:**
   - Take photo of each test
   - Count actual lit pixels
   - Verify position matches expected

4. **Analysis:**
   - If hypothesis correct: Pixels appear at (X-start, Y-start) to (Byte10-1, Byte11-1)
   - If Width/Height: Pixels appear in region starting at (X-start, Y-start) with size (Byte10, Byte11)
   - Document actual behavior

**Success Criteria:**
- [ ] Bytes 10-11 meaning confirmed (end coordinates vs size)
- [ ] 5/5 test cases display pixels in expected positions
- [ ] Formula validated for arbitrary regions

**Deliverables:**
- Position encoding documentation
- Photos of test results
- Updated DYNATAB_PROTOCOL_SPECIFICATION.md

---

## Phase 2: Validate Assumptions (Priority: MEDIUM)

**Timeline:** 2-3 weeks
**Blockers Removed:** Protocol reliability, performance limits understood

### Test 2A: Get_Report Response Analysis

**Objective:** Understand device status response and whether handshake is optional

**From:** PHASE2_TEST_PLAN.md, TEST-PROTO-001

**Test Procedure:**

1. **Capture Response Content:**
   ```powershell
   # Send init packet
   Send-HidFeatureReport -Data $initPacket
   Start-Sleep -Milliseconds 120

   # Get response
   $response = Get-HidFeatureReport

   # Log all 64 bytes
   for ($i = 0; $i -lt 64; $i++) {
       Write-Host "Byte[$i] = 0x$($response[$i].ToString('X2'))"
   }
   ```

2. **Decode Response:**
   - Look for status codes
   - Check for error indicators
   - Identify firmware version fields
   - Document known vs unknown bytes

3. **Test Without Handshake:**
   ```powershell
   # Skip Get_Report
   Send-HidFeatureReport -Data $initPacket
   Start-Sleep -Milliseconds 225  # Same total delay
   Send-HidFeatureReport -Data $dataPacket

   # Does it still work?
   ```

4. **Reliability Test:**
   - 100 animations with handshake → count successes
   - 100 animations without handshake → count successes
   - Compare reliability

**Success Criteria:**
- [ ] Response bytes decoded
- [ ] Handshake optional vs required determined
- [ ] Reliability difference quantified

---

### Test 2B: Maximum Frame Count

**Objective:** Find maximum supported frame count

**From:** PHASE2_TEST_PLAN.md (Test 2.7)

**Current Limit:** Tested up to 20 frames

**Test Procedure:**

1. **Incremental Test:**
   ```
   Test: 30, 50, 75, 100, 150, 200, 255 frames
   Expected limit: ~28 frames (packet counter is 8-bit)
   ```

2. **Implementation:**
   ```powershell
   foreach ($frameCount in @(30, 50, 75, 100, 150, 200, 255)) {
       # Build animation with $frameCount frames
       # Use minimal pixels per frame (1 pixel = Variant C)
       # Observe: Does device accept? Display correctly?
   }
   ```

**Success Criteria:**
- [ ] Maximum frame count identified
- [ ] Device behavior at limit documented

---

### Test 2C: Delay Range Limits

**Objective:** Test minimum (0ms) and maximum (>255ms) delays

**From:** PHASE2_TEST_PLAN.md (Test 2.2, 2.4)

**Current Range:** Tested 50-250ms

**Test Procedure:**

1. **Minimum Delay:**
   ```powershell
   # Test 0ms delay (byte 3 = 0x00)
   # Measure actual frame rate with high-speed camera
   ```

2. **Maximum Delay:**
   ```powershell
   # Test if byte 3 = 0xFF (255ms) works
   # Test if bytes 3-4 form 16-bit value (e.g., 500ms, 1000ms)
   ```

**Success Criteria:**
- [ ] Minimum working delay identified
- [ ] Maximum delay determined (8-bit vs 16-bit)
- [ ] Actual frame rate measured

---

## Phase 3: Optimization (Priority: LOW)

**Timeline:** 3-4 weeks
**Goal:** Performance optimization, not functionality

### Test 3A: Variant Performance Benchmarking

**Objective:** Measure upload time and playback performance for each variant

**Test Procedure:**
- Upload same animation in all 4 variants
- Measure transmission time
- Verify visual output identical
- Document bandwidth savings

---

### Test 3B: Partial Update Strategies

**Objective:** Test sequential partial updates

**Test Procedure:**
- Update region A (static)
- Update region B (static) without clearing region A
- Verify: Does region A persist?

---

### Test 3C: Performance Limits

**Objective:** Find maximum throughput

**Test Procedure:**
- Static image updates as fast as possible (no delays)
- Measure updates per second
- Find saturation point

---

## Test Execution Checklist

### Before Starting

- [ ] USB capture tool ready (USBPcap/Wireshark)
- [ ] Test-AnimationModes-FIXED.ps1 available
- [ ] Working capture files available for reference
- [ ] Camera ready for visual verification
- [ ] Test log spreadsheet prepared

### During Testing

- [ ] Capture USB traffic for every test
- [ ] Take photos of visual results
- [ ] Log all byte values and results
- [ ] Note any anomalies or unexpected behavior

### After Each Test

- [ ] Save USB capture with descriptive name
- [ ] Update test results spreadsheet
- [ ] Document findings in test report
- [ ] Update DYNATAB_PROTOCOL_SPECIFICATION.md if applicable

---

## Quick Reference: Test Files

| Test | Source Document | Section | Status |
|------|----------------|---------|--------|
| 1A (Checksum) | DYNATAB_PROTOCOL_SPECIFICATION.md | Phase 1, Priority 1A | Not started |
| 1B (Variants) | DYNATAB_PROTOCOL_SPECIFICATION.md | Phase 1, Priority 1B | Not started |
| 1C (Position) | DYNATAB_PROTOCOL_SPECIFICATION.md | Phase 1, Priority 1C | Not started |
| 2A (Get_Report) | PHASE2_TEST_PLAN.md | TEST-PROTO-001 | Not started |
| 2B (Frame Count) | PHASE2_TEST_PLAN.md | Test 2.7 | Not started |
| 2C (Delay Range) | PHASE2_TEST_PLAN.md | Test 2.2, 2.4 | Not started |

---

## Success Metrics

### Phase 1 Complete When:
- Checksum formula derived and validated
- Variant selection rules documented
- Position encoding confirmed
- **Result:** Can generate any packet independently

### Phase 2 Complete When:
- Get_Report response understood
- Maximum frame count identified
- Delay range limits documented
- **Result:** Protocol fully characterized

### Phase 3 Complete When:
- All 4 variants benchmarked
- Partial update strategy validated
- Performance envelope mapped
- **Result:** Optimal implementation strategy defined

---

## Estimated Effort

| Phase | Tests | Time per Test | Total Time |
|-------|-------|---------------|------------|
| Phase 1 | 3 | 1-3 days | 1-2 weeks |
| Phase 2 | 3 | 2-3 days | 2-3 weeks |
| Phase 3 | 3 | 3-5 days | 2-3 weeks |

**Total:** 5-8 weeks for complete protocol characterization

**Critical Path:** Phase 1 tests (1-2 weeks) unlock independent implementation

---

## Next Immediate Action

**START HERE:** Test 1A - Checksum Algorithm Reverse Engineering

1. Set up test environment
2. Modify Test-AnimationModes-FIXED.ps1 to vary byte 3
3. Run delay variation test (1A-1)
4. Capture results in spreadsheet
5. Analyze pattern and derive formula

**Expected outcome:** Checksum calculation function within 1-3 days

---

**END OF CONSOLIDATED TEST PLAN**
