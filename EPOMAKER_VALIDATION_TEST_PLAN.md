# Epomaker Software Validation Test Plan

**Purpose:** Systematic testing using official Epomaker software to validate protocol discoveries and capabilities
**Target Device:** Epomaker DynaTab 75X (VID: 0x3151, PID: 0x4015)
**Date Created:** 2026-01-17
**Status:** Ready for execution

---

## Table of Contents

1. [Test Environment Setup](#test-environment-setup)
2. [Static Picture Mode Tests](#static-picture-mode-tests)
3. [Animation Mode Tests](#animation-mode-tests)
4. [Protocol Validation Tests](#protocol-validation-tests)
5. [Performance and Timing Tests](#performance-and-timing-tests)
6. [Edge Case and Stress Tests](#edge-case-and-stress-tests)
7. [Capture Analysis Procedures](#capture-analysis-procedures)

---

## Test Environment Setup

### Required Tools

- **Epomaker DynaTab Configuration Software** (official)
- **USBPcap** or **Wireshark** with USB capture capability
- **USB 3.0 port** (recommended for stable capture)
- **DynaTab 75X keyboard** connected directly (no hubs)
- **Visual camera** for recording display output (smartphone camera works)
- **Timestamp tool** for performance measurements

### Capture Configuration

```
Filter: Interface 2 (MI_02) only
Device: VID=0x3151, PID=0x4015
Packet types: Set_Report, Get_Report
Buffer size: 1 MB minimum
```

### Pre-Test Checklist

- [ ] Epomaker software installed and launches successfully
- [ ] DynaTab 75X keyboard connected and recognized
- [ ] USBPcap running and filtering correctly
- [ ] Camera positioned to record keyboard display
- [ ] Test log document ready for recording results
- [ ] Baseline capture taken (idle state, no commands)

---

## Static Picture Mode Tests

### TEST-STATIC-001: Single Pixel Corner Validation

**Objective:** Confirm screen coordinate system and pixel positioning

**Test Cases:**

#### TC-001-A: Top-Left Pixel
- **Action:** Create image with single red pixel at position (0,0)
- **Expected USB:** Init packet with bytes [8-11] = `00 00 01 01`
- **Expected Display:** Red pixel in top-left corner only
- **Validation:** Position matches coordinate (0,0)

#### TC-001-B: Top-Right Pixel
- **Action:** Create image with single green pixel at position (59,0)
- **Expected USB:** Init packet with bytes [8-11] = `3B 00 3C 01`
- **Expected Display:** Green pixel in top-right corner only
- **Validation:** Position matches coordinate (59,0)

#### TC-001-C: Bottom-Left Pixel
- **Action:** Create image with single blue pixel at position (0,8)
- **Expected USB:** Init packet with bytes [8-11] = `00 08 01 09`
- **Expected Display:** Blue pixel in bottom-left corner only
- **Validation:** Position matches coordinate (0,8)

#### TC-001-D: Bottom-Right Pixel
- **Action:** Create image with single white pixel at position (59,8)
- **Expected USB:** Init packet with bytes [8-11] = `3B 08 3C 09`
- **Expected Display:** White pixel in bottom-right corner only
- **Validation:** Position matches coordinate (59,8)

**Success Criteria:**
- All 4 corners display correctly
- USB packets contain predicted position values
- No stray pixels appear

**Capture Files:**
- `validation-static-corner-topleft-red.json`
- `validation-static-corner-topright-green.json`
- `validation-static-corner-bottomleft-blue.json`
- `validation-static-corner-bottomright-white.json`

---

### TEST-STATIC-002: RGB Color Accuracy

**Objective:** Validate RGB888 color encoding and display accuracy

**Test Cases:**

#### TC-002-A: Primary Colors
- **Red:** Create 3×3 pixel block with RGB (255, 0, 0)
- **Green:** Create 3×3 pixel block with RGB (0, 255, 0)
- **Blue:** Create 3×3 pixel block with RGB (0, 0, 255)
- **Expected USB:** Each pixel = `FF 00 00`, `00 FF 00`, `00 00 FF`
- **Expected Display:** Pure primary colors, no color bleeding

#### TC-002-B: Secondary Colors
- **Cyan:** RGB (0, 255, 255)
- **Magenta:** RGB (255, 0, 255)
- **Yellow:** RGB (255, 255, 0)
- **Expected Display:** Accurate secondary color reproduction

#### TC-002-C: Grayscale Gradient
- **Test pixels:** RGB (0,0,0), (64,64,64), (128,128,128), (192,192,192), (255,255,255)
- **Expected Display:** 5 pixels showing black to white gradient
- **Validation:** Brightness increases proportionally

#### TC-002-D: Custom Colors
- **Orange:** RGB (184, 39, 39) - matches USB captures
- **Purple:** RGB (128, 0, 128)
- **Teal:** RGB (0, 128, 128)
- **Expected Display:** Accurate custom color reproduction

**Success Criteria:**
- All colors display accurately
- No unexpected color shifts
- Pixel data in USB matches RGB values

**Capture Files:**
- `validation-static-color-primary-RGB.json`
- `validation-static-color-secondary-CMY.json`
- `validation-static-color-grayscale-gradient.json`
- `validation-static-color-custom-mix.json`

---

### TEST-STATIC-003: Brightness Control

**Objective:** Validate 8-bit brightness control per RGB channel

**Test Cases:**

#### TC-003-A: Red Channel Brightness Ramp
- **Pixels:** RGB values (32,0,0), (64,0,0), (128,0,0), (192,0,0), (255,0,0)
- **Expected Display:** 5 pixels with increasing red brightness
- **Validation:** Visual brightness proportional to value

#### TC-003-B: Green Channel Brightness Ramp
- **Pixels:** RGB values (0,32,0), (0,64,0), (0,128,0), (0,192,0), (0,255,0)
- **Expected Display:** 5 pixels with increasing green brightness

#### TC-003-C: Blue Channel Brightness Ramp
- **Pixels:** RGB values (0,0,32), (0,0,64), (0,0,128), (0,0,192), (0,0,255)
- **Expected Display:** 5 pixels with increasing blue brightness

#### TC-003-D: Mixed Brightness Control
- **Pixel 1:** RGB (255, 128, 64) - bright red, medium green, dim blue
- **Pixel 2:** RGB (64, 255, 128) - dim red, bright green, medium blue
- **Pixel 3:** RGB (128, 64, 255) - medium red, dim green, bright blue
- **Validation:** Independent brightness control per channel

**Success Criteria:**
- Brightness increases proportionally with value
- Each channel controls independently
- All 256 brightness levels supported (0-255)

**Capture Files:**
- `validation-static-brightness-red-ramp.json`
- `validation-static-brightness-green-ramp.json`
- `validation-static-brightness-blue-ramp.json`
- `validation-static-brightness-mixed-control.json`

---

### TEST-STATIC-004: Full Screen Coverage

**Objective:** Validate complete 60×9 pixel grid addressing

**Test Cases:**

#### TC-004-A: Full Screen Single Color
- **Action:** Fill all 540 pixels with single color (e.g., orange RGB 184,39,39)
- **Expected USB:** 29 data packets with 1620 bytes total
- **Expected Display:** Entire display uniformly colored
- **Validation:** All pixels lit, no gaps or dead pixels

#### TC-004-B: Checkerboard Pattern
- **Action:** Create alternating pattern (pixel on/off)
- **Pattern:** (0,0)=white, (1,0)=black, (2,0)=white, etc.
- **Expected Display:** Checkerboard across entire display
- **Validation:** Confirms all pixel positions addressable

#### TC-004-C: Horizontal Stripes
- **Row 0:** Red
- **Row 1:** Black
- **Row 2:** Green
- **Row 3:** Black
- **Row 4:** Blue
- **Row 5:** Black
- **Row 6:** White
- **Row 7:** Black
- **Row 8:** Yellow
- **Validation:** Row-by-row addressing works correctly

#### TC-004-D: Vertical Stripes
- **Columns 0-9:** Red
- **Columns 10-19:** Green
- **Columns 20-29:** Blue
- **Columns 30-39:** Yellow
- **Columns 40-49:** Cyan
- **Columns 50-59:** Magenta
- **Validation:** Column-by-column addressing works correctly

**Success Criteria:**
- All 540 pixels addressable
- No dead pixels or gaps
- Patterns display accurately
- Full screen uses 29 packets

**Capture Files:**
- `validation-static-fullscreen-singlecolor-orange.json`
- `validation-static-fullscreen-checkerboard.json`
- `validation-static-fullscreen-horizontal-stripes.json`
- `validation-static-fullscreen-vertical-stripes.json`

---

### TEST-STATIC-005: Partial Screen Updates

**Objective:** Validate partial display update capability (discovered: 20 packets)

**Test Cases:**

#### TC-005-A: Top Half Update
- **Action:** Update only rows 0-4 (300 pixels)
- **Expected USB:** ~11 packets (300 pixels × 3 = 900 bytes ÷ 56 = 16.07 → 17 packets)
- **Expected Display:** Top 5 rows updated, bottom 4 rows unchanged
- **Validation:** Partial update successful

#### TC-005-B: Left Half Update
- **Action:** Update only columns 0-29 (270 pixels)
- **Expected USB:** ~15 packets
- **Expected Display:** Left half updated, right half unchanged

#### TC-005-C: Center Region Update
- **Action:** Update 10×5 pixel region in center
- **Expected USB:** ~3 packets (150 bytes)
- **Expected Display:** Center region updated, edges unchanged

#### TC-005-D: Official 20-Packet Update
- **Action:** Send exactly 1120 bytes (20 packets)
- **Coverage:** 373 pixels (68.9% of screen)
- **Expected USB:** Exactly 20 data packets
- **Validation:** Matches official Epomaker behavior

**Success Criteria:**
- Partial updates work without full screen refresh
- Unchanged regions remain stable
- Packet count matches pixel count calculation
- Official 20-packet mode confirmed

**Capture Files:**
- `validation-static-partial-tophalf-300px.json`
- `validation-static-partial-lefthalf-270px.json`
- `validation-static-partial-center-50px.json`
- `validation-static-partial-official-20pkt.json`

---

### TEST-STATIC-006: Initialization Packet Variants

**Objective:** Compare official vs PSDynaTab initialization packets

**Test Cases:**

#### TC-006-A: Official Epomaker Init Packet
- **Expected:** `a9 00 01 00 61 05 00 ef 06 00 39 09 00...`
- **Action:** Capture official software sending static image
- **Validation:** Document exact byte sequence

#### TC-006-B: Checksum Byte [7] Analysis
- **Official value:** 0xef
- **PSDynaTab value:** 0xfb
- **Action:** Send multiple images, observe if byte [7] changes
- **Validation:** Determine if checksum calculated or fixed

#### TC-006-C: Bytes [4-5] Parameter Study
- **Official:** 0x61 0x05 (1377 decimal)
- **PSDynaTab:** 0x54 0x06 (21510 decimal, LE) or (1620 decimal, BE)
- **Action:** Test different image sizes, observe parameter changes
- **Validation:** Understand parameter meaning

#### TC-006-D: Bytes [8-9] Position/Flags
- **Official:** 0x06 0x00
- **PSDynaTab:** 0x00 0x00
- **Action:** Test positioned images (not full screen)
- **Validation:** Confirm these bytes specify position

**Success Criteria:**
- Official packet sequence fully documented
- All byte meanings understood
- Functional differences identified (if any)
- Checksum algorithm discovered

**Capture Files:**
- `validation-static-init-official-sequence.json`
- `validation-static-init-checksum-analysis.json`
- `validation-static-init-parameters-study.json`
- `validation-static-init-position-flags.json`

---

## Animation Mode Tests

### TEST-ANIM-001: Basic Animation Validation

**Objective:** Confirm animation mode 0x03 basic functionality

**Test Cases:**

#### TC-001-A: 2-Frame Animation
- **Frame 0:** Red full screen
- **Frame 1:** Blue full screen
- **Delay:** 100ms per frame
- **Expected USB:** Init with mode 0x03, delay 0x64
- **Expected USB:** Data packets with byte [1] = 0x00, 0x01
- **Expected USB:** Data packets with byte [2] = 0x02 (frame count)
- **Expected Display:** Alternating red/blue at 10 FPS
- **Validation:** Device loops automatically

#### TC-001-B: 3-Frame Animation
- **Frame 0:** Red
- **Frame 1:** Green
- **Frame 2:** Blue
- **Delay:** 150ms per frame
- **Expected USB:** Init delay 0x96 (150ms)
- **Expected USB:** Byte [2] in data = 0x03 (3 frames)
- **Expected Display:** R→G→B→R loop at 6.67 FPS

#### TC-001-C: 4-Frame Animation
- **Frames:** Red, Yellow, Green, Cyan
- **Delay:** 200ms per frame
- **Expected USB:** Byte [2] = 0x04 (4 frames)
- **Expected Display:** 4-color sequence loops continuously

#### TC-001-D: Maximum Frame Count Test
- **Frames:** Create 10 different colored frames
- **Expected USB:** Byte [2] = 0x0A (10 frames)
- **Validation:** Determine practical maximum frame count

**Success Criteria:**
- Animation loops continuously without host intervention
- Frame count byte [2] matches actual frame count
- Timing accurate to specified delay
- All frames display correctly

**Capture Files:**
- `validation-anim-basic-2frame-redblue-100ms.json`
- `validation-anim-basic-3frame-RGB-150ms.json`
- `validation-anim-basic-4frame-multicolor-200ms.json`
- `validation-anim-basic-10frame-maximum.json`

---

### TEST-ANIM-002: Frame Delay Timing

**Objective:** Validate frame delay accuracy and range

**Test Cases:**

#### TC-002-A: Fast Animation (Minimum Delay)
- **Frames:** 2 frames (white/black strobe)
- **Delay:** 1ms (0x01)
- **Action:** Measure actual frame rate with high-speed camera
- **Validation:** Determine minimum achievable delay

#### TC-002-B: Slow Animation (Maximum Delay)
- **Frames:** 2 frames (red/blue)
- **Delay:** 255ms (0xFF)
- **Action:** Measure actual frame rate with timer
- **Validation:** Confirm maximum delay supported

#### TC-002-C: Standard Delays
- **Test delays:** 50ms, 100ms, 150ms, 200ms, 250ms
- **Frames:** 2 frames (contrasting colors)
- **Action:** Time 10 complete loops for each delay
- **Validation:** Actual timing matches specified delay ±5%

#### TC-002-D: Per-Frame Delay Variation
- **Question:** Does delay apply per-frame or globally?
- **Action:** Check if data packets can have different delays
- **Validation:** Determine delay scope (global vs per-frame)

**Success Criteria:**
- Delay range: 1-255ms confirmed
- Actual timing within ±5% of specified
- Delay applies consistently
- Delay scope understood (global or per-frame)

**Capture Files:**
- `validation-anim-delay-minimum-1ms.json`
- `validation-anim-delay-maximum-255ms.json`
- `validation-anim-delay-standard-50-250ms.json`
- `validation-anim-delay-variation-test.json`

---

### TEST-ANIM-003: Sparse Update Mode

**Objective:** Validate sparse animation protocol for efficiency

**Test Cases:**

#### TC-003-A: Single Pixel Animation (1-6-9 Pattern)
- **Frame 0:** 1 red pixel at (0,0)
- **Frame 1:** 6 green pixels at (0,0) to (5,0)
- **Frame 2:** 9 blue pixels at (0,0) to (8,0)
- **Expected USB:**
  - Frame 0: 1 packet (3 bytes pixel data)
  - Frame 1: 1 packet (18 bytes pixel data)
  - Frame 2: 1 packet (27 bytes pixel data)
- **Total:** 3 packets for entire animation
- **Validation:** Confirms sparse protocol efficiency

#### TC-003-B: Bouncing Ball (20 pixels per frame)
- **Frames:** Single pixel moving across screen
- **Action:** 60-frame animation (1 pixel per frame)
- **Expected USB:** 60 packets total (1 per frame)
- **Expected Display:** Smooth pixel movement
- **Validation:** Sparse mode for simple animations

#### TC-003-C: Progress Bar (Variable Pixel Count)
- **Frame 0:** 10 pixels
- **Frame 1:** 20 pixels
- **Frame 2:** 30 pixels
- **Frame 3:** 40 pixels
- **Frame 4:** 50 pixels
- **Expected USB:** Variable packet count (1, 2, 2, 3, 3 packets)
- **Validation:** Packet count = ceil(pixels × 3 / 56)

#### TC-003-D: Sparse vs Full Comparison
- **Test:** Same animation in sparse and full mode
- **Animation:** 5 pixels per frame, 3 frames
- **Sparse expected:** ~1 packet per frame (3 total)
- **Full expected:** 29 packets per frame (87 total)
- **Validation:** 96.6% bandwidth savings confirmed

**Success Criteria:**
- Sparse mode uses minimal packets
- Formula confirmed: packets = ceil(pixel_bytes / 56)
- Visual output identical between sparse and full
- Massive efficiency gains demonstrated

**Capture Files:**
- `validation-anim-sparse-1pixel-1-6-9.json`
- `validation-anim-sparse-bouncing-ball-60frame.json`
- `validation-anim-sparse-progress-bar-variable.json`
- `validation-anim-sparse-vs-full-comparison.json`

---

### TEST-ANIM-004: Full Frame Mode

**Objective:** Validate full frame animation transmission

**Test Cases:**

#### TC-004-A: Full Screen Animation (3 frames)
- **Frame 0:** All pixels red
- **Frame 1:** All pixels green
- **Frame 2:** All pixels blue
- **Expected USB:** 87 packets (29 per frame)
- **Expected USB:** Each frame = 1620 bytes
- **Validation:** Full frame mode for complex content

#### TC-004-B: Video Playback Simulation
- **Frames:** 10 frames of complex patterns
- **Each frame:** ~500 lit pixels (complex)
- **Expected USB:** 290 packets (29 × 10)
- **Validation:** Suitable for video-like content

#### TC-004-C: Fade Transition
- **Frames:** 5 frames fading red to blue
- **Frame 0:** RGB (255, 0, 0)
- **Frame 1:** RGB (192, 0, 64)
- **Frame 2:** RGB (128, 0, 128)
- **Frame 3:** RGB (64, 0, 192)
- **Frame 4:** RGB (0, 0, 255)
- **Expected USB:** 145 packets (29 × 5)
- **Validation:** Smooth color transitions

#### TC-004-D: Mixed Content Animation
- **Frames:** Combination of simple and complex
- **Question:** Can sparse and full modes mix in one animation?
- **Action:** Try varying packet counts per frame
- **Validation:** Determine protocol flexibility

**Success Criteria:**
- Full frame mode always sends 29 packets per frame
- All 540 pixels update each frame
- Suitable for complex graphics
- Consistent packet structure

**Capture Files:**
- `validation-anim-full-3frame-RGB-fullscreen.json`
- `validation-anim-full-10frame-video-simulation.json`
- `validation-anim-full-5frame-fade-transition.json`
- `validation-anim-full-mixed-content-test.json`

---

### TEST-ANIM-005: Animation Mode 0x05 Discovery

**Objective:** Investigate extended animation mode 0x05

**Test Cases:**

#### TC-005-A: Mode 0x05 Initialization
- **Action:** Search Epomaker software for mode 0x05 triggers
- **Expected:** Find feature that uses mode 0x05
- **Capture:** Full init packet sequence
- **Validation:** Document differences from mode 0x03

#### TC-005-B: Mode 0x05 Frame Count
- **Action:** Create animations with various frame counts in mode 0x05
- **Expected:** Determine if frame count encoding differs
- **Validation:** Compare bytes [8-9] to mode 0x03

#### TC-005-C: Mode 0x05 Address Pattern
- **Known:** Mode 0x05 uses 0x3803 → 0x34EB
- **Action:** Capture full address sequence
- **Observation:** Address jumps at end of sequence
- **Validation:** Document complete address pattern

#### TC-005-D: Mode 0x05 Capabilities
- **Question:** What features does mode 0x05 enable?
- **Tests:** More frames? Higher frame rate? Different looping?
- **Action:** Systematic comparison with mode 0x03
- **Validation:** Identify unique capabilities

**Success Criteria:**
- Mode 0x05 successfully triggered in Epomaker software
- Complete packet structure documented
- Functional differences identified
- Use cases for mode 0x05 understood

**Capture Files:**
- `validation-anim-mode05-initialization.json`
- `validation-anim-mode05-framecount-encoding.json`
- `validation-anim-mode05-address-pattern.json`
- `validation-anim-mode05-capabilities-test.json`

---

### TEST-ANIM-006: Animation Looping Behavior

**Objective:** Validate device-controlled automatic looping

**Test Cases:**

#### TC-006-A: Continuous Loop Confirmation
- **Action:** Send 3-frame animation
- **Observation:** Monitor for 5 minutes
- **Expected:** Animation loops without host re-transmission
- **Validation:** Device handles looping internally

#### TC-006-B: Loop Timing Accuracy
- **Action:** 2-frame animation, 100ms delay
- **Measurement:** Time 100 complete loops
- **Expected:** 100 loops × 2 frames × 100ms = 20 seconds ±1%
- **Validation:** Timing remains accurate over time

#### TC-006-C: Animation Stop Method
- **Action:** Send static image while animation running
- **Expected:** Animation stops, static image displays
- **Validation:** Confirm no "stop" command needed

#### TC-006-D: Animation Replace
- **Action:** Send new animation while previous one running
- **Expected:** Old animation stops, new one starts
- **Validation:** Seamless animation switching

**Success Criteria:**
- Animation loops indefinitely without host intervention
- Timing accurate over extended periods
- Static image stops animation
- New animation replaces old animation
- No explicit stop command required

**Capture Files:**
- `validation-anim-loop-continuous-5min.json`
- `validation-anim-loop-timing-100loops.json`
- `validation-anim-loop-stop-static-image.json`
- `validation-anim-loop-replace-animation.json`

---

## Protocol Validation Tests

### TEST-PROTO-001: Get_Report Handshake

**Objective:** Validate optional Get_Report handshake protocol

**Test Cases:**

#### TC-001-A: Official Handshake Sequence
- **Expected sequence:**
  1. Set_Report (init packet)
  2. Wait 120ms
  3. Get_Report (request 64 bytes)
  4. Device response
  5. Set_Report (data packets)
- **Action:** Capture official Epomaker sequence
- **Validation:** Confirm handshake pattern

#### TC-001-B: Handshake Timing
- **Measurement:** Time between init and Get_Report
- **Expected:** ~120ms delay
- **Variation test:** Does timing vary by operation type?
- **Validation:** Document precise timing requirements

#### TC-001-C: Get_Report Response Content
- **Action:** Capture device response to Get_Report
- **Analysis:** Decode response bytes
- **Expected:** Status information, firmware version?, ready flag?
- **Validation:** Understand response meaning

#### TC-001-D: Handshake Optional Test
- **Question:** What happens without Get_Report?
- **Action:** Compare operations with/without handshake
- **Validation:** Confirm handshake is optional but recommended

**Success Criteria:**
- Complete handshake sequence documented
- Timing requirements understood
- Response content decoded
- Optional nature confirmed

**Capture Files:**
- `validation-proto-handshake-sequence.json`
- `validation-proto-handshake-timing.json`
- `validation-proto-handshake-response.json`
- `validation-proto-handshake-optional-test.json`

---

### TEST-PROTO-002: Counter and Address Validation

**Objective:** Confirm counter increment and address decrement patterns

**Test Cases:**

#### TC-002-A: Counter Increment Pattern
- **Action:** Full screen static image (29 packets)
- **Expected:** Counter bytes [4-5] increment: 0x0000 → 0x001C
- **Format:** Little-endian 16-bit
- **Validation:** Counter = packet_number - 1 (0-based)

#### TC-002-B: Address Decrement Pattern
- **Action:** Same 29-packet transmission
- **Expected:** Address bytes [6-7] decrement: 0x389D → 0x388A
- **Format:** Big-endian 16-bit
- **Validation:** Address decrements by 1 per packet

#### TC-002-C: Synchronization Verification
- **Check:** Counter up, address down, in lockstep
- **Formula:** Address = StartAddress - Counter
- **Validation:** Relationship holds for all packets

#### TC-002-D: Mode-Specific Ranges
- **Static:** 0x389D → 0x388A
- **Animation 0x03:** 0x3837 → 0x381D
- **Animation 0x05:** 0x3803 → 0x34EB (with jump)
- **Validation:** Document all mode-specific ranges

**Success Criteria:**
- Counter increments correctly (little-endian)
- Address decrements correctly (big-endian)
- Synchronization confirmed
- All mode ranges documented

**Capture Files:**
- `validation-proto-counter-increment-pattern.json`
- `validation-proto-address-decrement-pattern.json`
- `validation-proto-sync-verification.json`
- `validation-proto-mode-ranges.json`

---

### TEST-PROTO-003: Packet Timing and Performance

**Objective:** Measure actual transmission timing and performance

**Test Cases:**

#### TC-003-A: Inter-Packet Delay Measurement
- **Action:** Capture timestamps for 29-packet sequence
- **Measurement:** Time between consecutive packets
- **Expected:** ~5ms between packets
- **Validation:** Document actual delay (min, avg, max)

#### TC-003-B: Full Screen Transmission Time
- **Action:** Time complete static image transmission
- **Expected:** 29 packets × 5ms = ~145-150ms
- **Measurement:** Actual start to finish time
- **Validation:** Confirm total transmission time

#### TC-003-C: Animation Transmission Time
- **Action:** 3-frame full animation (87 packets)
- **Expected:** 87 × 5ms = ~435ms
- **Measurement:** Complete animation upload time
- **Validation:** Time before device starts looping

#### TC-003-D: Device ACK Latency
- **Measurement:** Time from host send to device ACK
- **Expected:** ~1.5-3ms per packet
- **Validation:** Understand USB round-trip time

**Success Criteria:**
- Inter-packet delay: 3-6ms typical, 5ms recommended
- Full screen: <200ms total
- Device ACK: <3ms per packet
- Performance predictable and consistent

**Capture Files:**
- `validation-proto-timing-interpacket-delay.json`
- `validation-proto-timing-fullscreen-transmission.json`
- `validation-proto-timing-animation-upload.json`
- `validation-proto-timing-device-ack-latency.json`

---

### TEST-PROTO-004: Checksum and Validation

**Objective:** Understand byte [7] checksum in init packet

**Test Cases:**

#### TC-004-A: Checksum Correlation Test
- **Action:** Send 10 different images
- **Observation:** Record byte [7] value for each
- **Analysis:** Look for patterns (XOR? Sum? Fixed?)
- **Validation:** Determine if calculated or fixed

#### TC-004-B: Checksum Algorithm Discovery
- **Given examples:**
  - Official: 0xef
  - PSDynaTab: 0xfb
- **Action:** Vary bytes [1-6], observe byte [7]
- **Analysis:** Reverse engineer calculation
- **Validation:** Derive checksum formula

#### TC-004-C: Invalid Checksum Test
- **Action:** Intentionally send wrong checksum
- **Expected:** Device rejects packet? Or accepts anyway?
- **Validation:** Determine if checksum validated

#### TC-004-D: Checksum Scope
- **Question:** Does checksum cover all 64 bytes or just header?
- **Action:** Test with different packet contents
- **Validation:** Identify which bytes are checksummed

**Success Criteria:**
- Checksum algorithm understood
- Checksum validation confirmed or disproven
- Correct calculation documented
- Scope identified (header only vs full packet)

**Capture Files:**
- `validation-proto-checksum-correlation.json`
- `validation-proto-checksum-algorithm.json`
- `validation-proto-checksum-invalid-test.json`
- `validation-proto-checksum-scope.json`

---

## Performance and Timing Tests

### TEST-PERF-001: Bandwidth Efficiency

**Objective:** Measure actual bandwidth usage for different modes

**Test Cases:**

#### TC-001-A: Sparse Mode Efficiency
- **Test:** 10 pixel animation (3 frames)
- **Sparse:** 3 packets = 192 bytes total
- **Full:** 87 packets = 5568 bytes total
- **Efficiency:** 96.6% bandwidth savings
- **Validation:** Confirm efficiency gains

#### TC-001-B: Partial Update Efficiency
- **Test:** Update 25% of screen (135 pixels)
- **Partial:** 8 packets = 512 bytes
- **Full:** 29 packets = 1856 bytes
- **Efficiency:** 72.4% bandwidth savings
- **Validation:** Partial updates worthwhile

#### TC-001-C: Overhead Analysis
- **Packet overhead:** 8 bytes header per packet
- **Static full:** 29 × 8 = 232 bytes overhead (14.3%)
- **Data payload:** 29 × 56 = 1624 bytes (85.7%)
- **Validation:** Understand protocol overhead

#### TC-001-D: Optimal Packet Utilization
- **Question:** What pixel counts maximize efficiency?
- **Analysis:** pixels per packet vs overhead
- **Best case:** 18.67 pixels per packet (56 bytes)
- **Validation:** Identify sweet spots

**Success Criteria:**
- Sparse mode efficiency quantified
- Partial update benefits confirmed
- Protocol overhead understood
- Optimization opportunities identified

---

### TEST-PERF-002: Frame Rate Limits

**Objective:** Determine maximum achievable frame rates

**Test Cases:**

#### TC-002-A: Maximum Static Update Rate
- **Action:** Send static images as fast as possible
- **Measurement:** Updates per second
- **Expected:** Limited by 150ms transmission time = ~6.7 FPS
- **Validation:** Maximum refresh rate for static

#### TC-002-B: Maximum Animation Frame Rate
- **Action:** Create 2-frame animation with 1ms delay
- **Measurement:** Actual frame rate achieved
- **Expected:** Limited by device processing or 1ms minimum
- **Validation:** True maximum FPS

#### TC-002-C: Sparse Animation Speed
- **Action:** 1-pixel animation, 60 frames, 1ms delay
- **Upload time:** 60 packets × 5ms = 300ms
- **Playback:** 60 frames × 1ms = 60ms per loop
- **Validation:** Upload vs playback timing

#### TC-002-D: Practical Frame Rate
- **Complex animation:** Full frames, realistic content
- **Delay:** 33ms (30 FPS attempt)
- **Measurement:** Actual achieved frame rate
- **Validation:** Realistic performance expectations

**Success Criteria:**
- Maximum static update rate: ~6-7 FPS
- Maximum animation rate: >100 FPS (with 1ms delay)
- Practical full-frame rate: ~30 FPS
- Upload time separate from playback time

---

### TEST-PERF-003: Device Stress Testing

**Objective:** Test device limits and stability

**Test Cases:**

#### TC-003-A: Continuous Operation
- **Action:** Run animation continuously for 24 hours
- **Observation:** Monitor for degradation, crashes, resets
- **Validation:** Device stability over time

#### TC-003-B: Rapid Mode Switching
- **Action:** Alternate between static and animation modes
- **Frequency:** Every 5 seconds for 1 hour
- **Validation:** Mode switching stability

#### TC-003-C: Maximum Frame Count
- **Action:** Create animations with increasing frame counts
- **Test:** 10, 50, 100, 200, 255 frames
- **Validation:** Find actual maximum supported

#### TC-003-D: Maximum Brightness
- **Action:** All pixels full white (255,255,255)
- **Duration:** 1 hour continuous
- **Observation:** Heat, brightness stability, power draw
- **Validation:** Maximum power handling

**Success Criteria:**
- Device stable over extended operation
- No memory leaks or crashes
- Maximum frame count identified
- Thermal limits understood

---

## Edge Case and Stress Tests

### TEST-EDGE-001: Boundary Conditions

**Objective:** Test protocol limits and edge cases

**Test Cases:**

#### TC-001-A: Zero Pixels
- **Action:** Send animation with all black pixels
- **Expected:** Display turns off
- **Validation:** Black pixels vs no transmission

#### TC-001-B: Single Pixel
- **Action:** Minimal possible transmission
- **Expected:** 1 packet with 3 bytes pixel data
- **Validation:** Minimum viable transmission

#### TC-001-C: Maximum Pixels
- **Action:** All 540 pixels lit
- **Expected:** 29 packets, 1620 bytes
- **Validation:** Maximum transmission

#### TC-001-D: Coordinates Out of Range
- **Action:** Try to address pixel (60,9) - outside bounds
- **Expected:** Ignored? Error? Wrap around?
- **Validation:** Bounds checking behavior

**Success Criteria:**
- All boundary conditions handled gracefully
- No crashes or undefined behavior
- Edge cases documented

---

### TEST-EDGE-002: Invalid Inputs

**Objective:** Test error handling and recovery

**Test Cases:**

#### TC-002-A: Invalid Mode Value
- **Action:** Send init with mode 0x02 (undefined)
- **Expected:** Rejected? Default behavior?
- **Validation:** Mode validation

#### TC-002-B: Mismatched Frame Count
- **Action:** Init says 3 frames, send 4 frames of data
- **Expected:** Uses 3 frames? Uses 4? Errors?
- **Validation:** Frame count validation

#### TC-002-C: Incomplete Transmission
- **Action:** Send init + 10 packets, then stop (incomplete)
- **Expected:** Partial display? Error? Waits for more?
- **Validation:** Incomplete transmission handling

#### TC-002-D: Counter Sequence Error
- **Action:** Send packets with wrong counter sequence
- **Expected:** Rejected? Accepted out of order?
- **Validation:** Sequence validation

**Success Criteria:**
- Error handling understood
- Recovery methods documented
- Invalid inputs don't crash device

---

## Capture Analysis Procedures

### Standard Analysis Workflow

For each test:

1. **Pre-capture checklist**
   - [ ] USBPcap running with correct filter
   - [ ] Baseline capture taken
   - [ ] Camera ready to record display
   - [ ] Test log ready

2. **Capture execution**
   - [ ] Start USBPcap
   - [ ] Start camera recording
   - [ ] Perform test action in Epomaker software
   - [ ] Wait for display to stabilize
   - [ ] Stop camera recording
   - [ ] Stop USBPcap
   - [ ] Save capture with descriptive name

3. **Analysis steps**
   - [ ] Export to JSON format
   - [ ] Identify init packet (0xa9)
   - [ ] Count data packets (0x29)
   - [ ] Extract counter and address sequences
   - [ ] Verify pixel data matches expectation
   - [ ] Compare video to expected display

4. **Documentation**
   - [ ] Record results in test log
   - [ ] Note any discrepancies
   - [ ] Save capture file with test ID
   - [ ] Update validation status

### Key Metrics to Capture

- **Packet count:** Total Set_Report calls
- **Init packet:** Complete 64 bytes
- **Data packets:** Count and byte [1-2] values
- **Counter range:** First and last values
- **Address range:** First and last values
- **Timing:** Timestamps for performance
- **Display output:** Photo/video of result
- **Anomalies:** Any unexpected behavior

---

## Test Execution Schedule

### Priority 1 - Critical Validation (Week 1)
- TEST-STATIC-001: Corner positioning
- TEST-STATIC-002: RGB color accuracy
- TEST-ANIM-001: Basic animations
- TEST-PROTO-001: Get_Report handshake
- TEST-PROTO-002: Counter/address patterns

### Priority 2 - Protocol Discovery (Week 2)
- TEST-STATIC-006: Init packet variants
- TEST-ANIM-005: Mode 0x05 discovery
- TEST-PROTO-004: Checksum algorithm
- TEST-ANIM-003: Sparse mode validation

### Priority 3 - Performance (Week 3)
- TEST-PERF-001: Bandwidth efficiency
- TEST-PERF-002: Frame rate limits
- TEST-PROTO-003: Timing measurements
- TEST-STATIC-005: Partial updates

### Priority 4 - Edge Cases (Week 4)
- TEST-EDGE-001: Boundary conditions
- TEST-EDGE-002: Invalid inputs
- TEST-PERF-003: Stress testing
- TEST-ANIM-006: Looping behavior

---

## Success Criteria Summary

### Overall Test Suite Success
- [ ] All corner pixels position correctly (TEST-STATIC-001)
- [ ] All RGB colors display accurately (TEST-STATIC-002)
- [ ] Animations loop automatically (TEST-ANIM-001)
- [ ] Sparse mode efficiency confirmed >90% (TEST-ANIM-003)
- [ ] Counter/address patterns validated (TEST-PROTO-002)
- [ ] Get_Report handshake documented (TEST-PROTO-001)
- [ ] Mode 0x05 discovered and validated (TEST-ANIM-005)
- [ ] Checksum algorithm understood (TEST-PROTO-004)
- [ ] Performance metrics within expectations (TEST-PERF-001-003)
- [ ] No edge case crashes (TEST-EDGE-001-002)

### Documentation Deliverables
- [ ] All capture files saved with consistent naming
- [ ] Test log completed with results and observations
- [ ] Updated TECHNICAL_PROTOCOL_GUIDE.md with findings
- [ ] Comparison document: Official vs PSDynaTab protocols
- [ ] Performance benchmarks documented
- [ ] Edge case behavior guide created

---

## Appendix: Capture File Naming Convention

Format: `validation-[category]-[test]-[description]-[date].json`

Examples:
- `validation-static-corner-topleft-red-20260117.json`
- `validation-anim-sparse-1pixel-1-6-9-20260117.json`
- `validation-proto-handshake-sequence-20260117.json`

Categories:
- `static` - Static picture mode tests
- `anim` - Animation mode tests
- `proto` - Protocol validation tests
- `perf` - Performance tests
- `edge` - Edge case tests

---

**END OF TEST PLAN**

**Total Test Cases:** 80+ individual tests
**Estimated Execution Time:** 40-60 hours
**Expected Captures:** 100+ USB packet capture files
**Expected Output:** Comprehensive protocol validation and documentation updates

**Status:** Ready for execution
**Next Action:** Begin with Priority 1 tests
