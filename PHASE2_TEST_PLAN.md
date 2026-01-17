# Phase 2: Animation Protocol Deep Dive Test Plan

**Status:** Ready to Execute
**Prerequisites:** Phase 1 validation complete (all tests passed)
**Objective:** Answer remaining questions about animation protocol encoding

---

## Overview

Phase 1 confirmed animation mode works. Phase 2 focuses on understanding:
1. Frame count encoding mechanism
2. Frame boundary detection
3. Frame delay timing precision
4. Protocol limits and edge cases

---

## Priority Tests

### P0: Critical Understanding

#### Test 2.1: Frame Count Validation

**Question:** Does byte 8 encode frame count as (count - 1)?

**Hypothesis:** Byte 8 = 0x02 means 3 frames (0-indexed)

**Test Cases:**

| Byte 8 | Expected Frames | Packets | Visual Test |
|--------|-----------------|---------|-------------|
| 0x00 | 1 frame | 9 | Static display (no loop?) |
| 0x01 | 2 frames | 18 | 2 alternating patterns |
| 0x02 | 3 frames | 27 | 3 cycling patterns (baseline) |
| 0x03 | 4 frames | 36 | 4 cycling patterns |
| 0x04 | 5 frames | 45 | 5 cycling patterns |

**Implementation:**
```powershell
# Test 2-frame animation
$init = New-AnimationInitPacket -FrameCount 0x01
Send-InitPacket $init
# Send 18 packets (2 frames × 9 packets)
for ($i = 0; $i -lt 18; $i++) {
    Send-AnimationDataPacket -Counter $i -Address (0x3837 - $i)
}
# Observe: Should loop between 2 frames
```

**Success Criteria:**
- Visual frame count matches byte 8 + 1
- Looping behavior confirmed for each configuration
- No errors or display corruption

---

#### Test 2.2: Frame Delay Timing

**Question:** What is the actual frame delay accuracy?

**Test Cases:**

| Delay (ms) | Byte 3 | Measurement Method |
|------------|--------|--------------------|
| 50 | 0x32 | 60fps video (frame counting) |
| 100 | 0x64 | 60fps video |
| 200 | 0xC8 | 60fps video |
| 500 | 0x1F4 (if 16-bit) | Stopwatch |
| 1000 | 0x03E8 (if 16-bit) | Stopwatch |

**Implementation:**
```powershell
# Test various delays
$delays = @(0x32, 0x64, 0xC8, 0xFF)
foreach ($delay in $delays) {
    $init = New-AnimationInitPacket -DelayMS $delay
    Send-InitPacket $init
    Send-AnimationPackets -Count 27

    Write-Host "Record video at 60fps"
    Write-Host "Count frames between transitions"
    Read-Host "Press enter when done"
}
```

**Success Criteria:**
- Measured delay matches configured value ±10ms
- Determine if byte 3 is 8-bit (max 255ms) or 16-bit
- Document actual timing precision

---

#### Test 2.3: Packet Distribution

**Question:** Must packets be evenly distributed across frames?

**Test Cases:**

| Total Packets | Frame Count | Distribution | Expected Result |
|---------------|-------------|--------------|-----------------|
| 18 | 2 | 9 + 9 | ✓ Even - should work |
| 20 | 2 | 10 + 10 | Test if 10 packets/frame works |
| 27 | 3 | 9 + 9 + 9 | ✓ Baseline |
| 30 | 3 | 10 + 10 + 10 | Test alternative packet count |
| 25 | 3 | 8 + 8 + 9 | Uneven - does device handle? |
| 36 | 4 | 9 + 9 + 9 + 9 | 4-frame even distribution |

**Implementation:**
```powershell
# Test uneven distribution
$init = New-AnimationInitPacket -FrameCount 0x02  # 3 frames
Send-InitPacket $init
# Send only 25 packets instead of 27
for ($i = 0; $i -lt 25; $i++) {
    Send-AnimationDataPacket -Counter $i -Address (0x3837 - $i)
}
# Observe visual output
```

**Success Criteria:**
- Determine if packet count must equal (frame_count × 9)
- Test if device calculates packets_per_frame = total / frame_count
- Document error behavior if counts don't match

---

### P1: Important Details

#### Test 2.4: Maximum Delay Value

**Question:** What is the maximum frame delay supported?

**Test Cases:**
- 255ms (0xFF) - max 8-bit
- 500ms (0x01F4) - test if 16-bit (bytes 3-4)
- 1000ms (0x03E8)
- 5000ms (0x1388)

**Implementation:**
```powershell
# Test max delay
$delays = @(255, 500, 1000, 5000)
foreach ($delayMs in $delays) {
    if ($delayMs -gt 255) {
        # Test if bytes 3-4 form 16-bit value
        $byte3 = [byte]($delayMs -band 0xFF)
        $byte4 = [byte](($delayMs -shr 8) -band 0xFF)
        # Custom packet construction
    } else {
        $init = New-AnimationInitPacket -DelayMS $delayMs
        Send-InitPacket $init
        Send-AnimationPackets -Count 27

        Write-Host "Delay: ${delayMs}ms - Timing test"
        Start-Sleep -Seconds 10
    }
}
```

**Success Criteria:**
- Identify maximum working delay value
- Determine if delay is 8-bit or 16-bit
- Document device behavior at limits

---

#### Test 2.5: Address Range Testing

**Question:** Does animation require specific address range?

**Test Cases:**

| Start Address | End Address | Mode | Expected |
|---------------|-------------|------|----------|
| 0x3837 | 0x381D | Animation | ✓ Baseline |
| 0x389D | 0x3883 | Animation | Test static range |
| 0x0000 | 0x001A | Animation | Test low addresses |
| 0xFFFF | 0xFFE5 | Animation | Test high addresses |

**Implementation:**
```powershell
# Test different address ranges
$ranges = @(
    @{ Start = 0x3837; Name = "Official animation" },
    @{ Start = 0x389D; Name = "Static mode range" },
    @{ Start = 0x1000; Name = "Low range" }
)

foreach ($range in $ranges) {
    Write-Host "Testing: $($range.Name)"
    $init = New-AnimationInitPacket -StartAddress $range.Start
    Send-InitPacket $init

    for ($i = 0; $i -lt 27; $i++) {
        Send-AnimationDataPacket -Counter $i -Address ($range.Start - $i)
    }

    Read-Host "Visual confirmation"
}
```

**Success Criteria:**
- Determine if address range is mode-specific
- Document working vs non-working ranges
- Understand address calculation requirements

---

### P2: Edge Cases

#### Test 2.6: Single Frame Animation

**Question:** What happens with frame count = 0x00 (1 frame)?

**Test:**
- Send init with byte 8 = 0x00
- Send 9 packets
- Observe if it behaves like static image or loops

**Expected:**
- Either: Static display (no looping)
- Or: Single-frame loop (pointless but valid)

---

#### Test 2.7: Maximum Frame Count

**Question:** What is the maximum number of frames?

**Test Cases:**
- 10 frames (0x09): 90 packets
- 20 frames (0x13): 180 packets
- 32 frames (0x1F): 288 packets

**Limits:**
- USB packet counter is 8-bit (0x00-0xFF = 256 packets max)
- 256 packets ÷ 9 per frame = 28 frames theoretical max
- Test if device has lower limit

---

#### Test 2.8: Zero Delay Animation

**Question:** What happens with 0ms delay (byte 3 = 0x00)?

**Test:**
- Send animation init with delay = 0x00
- Send 27 packets
- Observe frame rate

**Expected:**
- Maximum frame rate (device-limited)
- May appear as blur or flicker
- Helps determine hardware refresh rate

---

## Test Execution Order

### Week 1: Core Understanding
1. ✓ Test 2.1: Frame count validation (2, 3, 4, 5 frames)
2. ✓ Test 2.3: Packet distribution (even vs uneven)
3. Test 2.2: Delay timing (50, 100, 200ms with video)

### Week 2: Limits & Edge Cases
4. Test 2.4: Maximum delay value
5. Test 2.6: Single frame animation
6. Test 2.7: Maximum frame count
7. Test 2.8: Zero delay animation

### Week 3: Advanced
8. Test 2.5: Address range testing
9. Document all findings
10. Create Phase 3 plan (implementation)

---

## Success Criteria

### Minimum Viable Understanding
- [ ] Frame count encoding confirmed (byte 8 relationship)
- [ ] Packet distribution rules understood
- [ ] Frame delay timing measured accurately
- [ ] Working ranges documented (frames, delays, packets)

### Complete Understanding
- [ ] All test cases executed
- [ ] Edge cases documented
- [ ] Protocol limits identified
- [ ] Byte 4 calculation reverse-engineered
- [ ] Ready for PSDynaTab implementation

---

## Test Script Template

```powershell
# Phase 2 Test Template
param(
    [int]$FrameCount = 3,
    [int]$DelayMS = 100,
    [int]$PacketsPerFrame = 9
)

function Test-AnimationConfiguration {
    param($Config)

    Write-Host "`n=== Testing: $($Config.Description) ===" -ForegroundColor Cyan

    # Build init packet
    $init = New-AnimationInitPacket `
        -Mode 0x03 `
        -DelayMS $Config.Delay `
        -FrameCount $Config.FrameCountByte

    # Send init
    Send-InitPacket $init
    Start-Sleep -Milliseconds 120
    Get-DeviceStatus | Out-Null

    # Send data packets
    $totalPackets = $Config.FrameCount * $Config.PacketsPerFrame
    Write-Host "Sending $totalPackets packets ($($Config.FrameCount) frames × $($Config.PacketsPerFrame) packets)"

    for ($i = 0; $i -lt $totalPackets; $i++) {
        $pixelData = New-TestFrameData -FrameIndex ([Math]::Floor($i / $Config.PacketsPerFrame))
        Send-AnimationDataPacket -Counter $i -Address (0x3837 - $i) -PixelData $pixelData
    }

    # Observation
    Write-Host "`nVisual confirmation:" -ForegroundColor Yellow
    Write-Host "  Frame count: $($Config.FrameCount)"
    Write-Host "  Expected delay: $($Config.Delay)ms"
    Write-Host "  Total cycle: $($Config.FrameCount * $Config.Delay)ms"

    $result = Read-Host "Did animation display correctly? (Y/N)"
    return $result -eq 'Y'
}

# Example usage
$testConfigs = @(
    @{ Description = "2 frames, 100ms"; FrameCount = 2; FrameCountByte = 0x01; Delay = 100; PacketsPerFrame = 9 },
    @{ Description = "4 frames, 100ms"; FrameCount = 4; FrameCountByte = 0x03; Delay = 100; PacketsPerFrame = 9 },
    @{ Description = "3 frames, 50ms"; FrameCount = 3; FrameCountByte = 0x02; Delay = 50; PacketsPerFrame = 9 }
)

foreach ($config in $testConfigs) {
    Test-AnimationConfiguration $config
    Start-Sleep -Seconds 2
}
```

---

## Expected Outcomes

### Frame Count Encoding
**Hypothesis:** Byte 8 = (frame_count - 1)
- 0x00 = 1 frame
- 0x01 = 2 frames
- 0x02 = 3 frames
- etc.

### Packet Distribution
**Hypothesis:** Total packets = frame_count × packets_per_frame
- Device divides total packets evenly across frames
- Packets per frame may be variable (9, 10, 15, etc.)
- Or fixed at 9 packets per frame

### Delay Encoding
**Hypothesis:** Byte 3 = delay in milliseconds (8-bit, max 255ms)
- Alternative: Bytes 3-4 = 16-bit delay value
- Test results will confirm

---

## Deliverables

1. **Test-AnimationPhase2.ps1** - Automated test suite
2. **PHASE2_TEST_RESULTS.md** - Complete findings
3. **ANIMATION_PROTOCOL_SPEC.md** - Final protocol specification
4. Updated **USBPCAP_ANIMATION_ANALYSIS.md** with confirmed encoding

---

**Next Steps:** Begin with Test 2.1 (Frame Count Validation)
