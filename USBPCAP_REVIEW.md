# USBPcap Trace Review: Successful DynaTab Display Update

## Executive Summary

This USB packet capture shows a successful display update to an **Epomaker DynaTab 75X keyboard** (VID: 0x3151, PID: 0x4015) on USB bus 4, device address 15. The trace captures device enumeration, initialization, and a sequential display update operation using HID Feature Reports on Interface 2.

---

## Trace Timeline Analysis

### Phase 1: Device Enumeration (Frames 55-60)
**Timestamp**: 2026-01-15T23:28:40.557978000Z

#### Frame 55-56: Get Device Descriptor
```
Request:  GET_DESCRIPTOR (Device, 18 bytes)
Response: USB 2.0 Device
  - Vendor ID:     0x3151
  - Product ID:    0x4015
  - Device Ver:    0x0108 (v1.8)
  - Max Packet:    64 bytes
  - Configurations: 1
  - Class:         0x00 (Defined at interface level)
```

✅ **Matches PSDynaTab expectations** - Correct VID/PID for DynaTab 75X

#### Frame 57-58: Get Configuration Descriptor
```
Request:  GET_DESCRIPTOR (Configuration, 84 bytes)
Response: Configuration with 3 HID interfaces

Interface 0 (Boot Keyboard):
  - Class:      HID (0x03)
  - SubClass:   Boot Interface (0x01)
  - Protocol:   Keyboard (0x01)
  - Endpoint:   0x81 IN (Interrupt, 8 bytes, 1ms interval)
  - HID Report: 59 bytes

Interface 1 (Generic HID):
  - Class:      HID (0x03)
  - SubClass:   None (0x00)
  - Protocol:   None (0x00)
  - Endpoint:   0x82 IN (Interrupt, 16 bytes, 1ms interval)
  - HID Report: 177 bytes

Interface 2 (Display Control) ⭐:
  - Class:      HID (0x03)
  - SubClass:   None (0x00)
  - Protocol:   None (0x00)
  - Endpoint:   0x83 IN (Interrupt, 8 bytes, 1ms interval)
  - HID Report: 20 bytes
```

✅ **Interface 2 is the display control interface** - This is MI_02 targeted by PSDynaTab

#### Frame 59-60: Set Configuration
```
Request:  SET_CONFIGURATION (Value: 1)
Response: ACK (0 bytes, usbd_status: 0x00000000)
```

✅ **Device successfully configured** - All 3 interfaces now active

---

### Phase 2: Display Update Initialization (Frames 1941-1942)
**Timestamp**: 2026-01-15T23:28:42.901215000Z (2.343s after enumeration)

#### Frame 1941: HID Set_Report (Initialization Packet)
```
Request Type:   CLASS, Host→Device, Interface
Request:        HID SET_REPORT (0x09)
Report Type:    Feature (3)
Report ID:      0
Interface:      2 (Display Control)
Data Length:    64 bytes

Payload (hex):
a9 00 01 00 61 05 00 ef 06 00 39 09 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
```

**Packet Analysis**:
```
Byte 0:       0xA9  - Initialization command marker
Bytes 1-3:    00 01 00
Byte 4:       0x61  - Parameter (97 decimal)
Byte 5:       0x05  - Parameter (5 decimal)
Byte 6:       0x00
Byte 7:       0xEF  - Parameter (239 decimal)
Bytes 8-9:    06 00 - Little-endian 0x0006 (6)
Bytes 10-11:  39 09 - Big-endian 0x0939 (2361 decimal)
Bytes 12-63:  All 0x00 (padding)
```

⚠️ **Different from PSDynaTab FIRST_PACKET**:
- PSDynaTab uses: `0xa9, 0x00, 0x01, 0x00, 0x54, 0x06, 0x00, 0xfb, 0x00, 0x00, 0x3c, 0x09...`
- This trace uses: `0xa9, 0x00, 0x01, 0x00, 0x61, 0x05, 0x00, 0xef, 0x06, 0x00, 0x39, 0x09...`

**Differences**:
- Byte 4: `0x54` vs `0x61` (84 vs 97) - Could be width/dimension parameter
- Byte 5: `0x06` vs `0x05` (6 vs 5) - Could be height/dimension parameter
- Byte 7: `0xfb` vs `0xef` (251 vs 239) - Checksum/validation byte
- Bytes 10-11: `0x3c, 0x09` vs `0x39, 0x09` (0x093C vs 0x0939, 2364 vs 2361) - Address/counter

💡 **Hypothesis**: Different firmware version or display mode (possibly different resolution/area)

#### Frame 1942: Response
```
Response: ACK (0 bytes, 1.773ms latency)
Status:   0x00000000 (Success)
```

✅ **Device acknowledged initialization**

---

### Phase 3: Status Read-Back (Frames 2096-2099)
**Timestamp**: 2026-01-15T23:28:43.023391000Z (120ms after init)

#### Frame 2096: HID Get_Report
```
Request Type:   CLASS, Device→Host, Interface
Request:        HID GET_REPORT (0x01)
Report Type:    Feature (3)
Report ID:      0
Interface:      2
Data Length:    64 bytes requested
```

#### Frame 2099: Response
```
Response:   64 bytes received (1.584ms latency)
Status:     0x00000000 (Success)
```

✅ **Device responded to status query** - Confirms device is ready for data

📝 **Note**: PSDynaTab PowerShell implementation doesn't use Get_Report (unlike Python implementation), but it works without handshake protocol.

---

### Phase 4: Sequential Data Transmission (Frames 2197-2238)

13 data packets transmitted in sequence, each following the same pattern:

| Frame | Counter | Address | Timing (ms) | Status |
|-------|---------|---------|-------------|--------|
| 2197  | 0x0000  | 0x389D  | 0           | ✅ ACK |
| 2199  | 0x0001  | 0x389C  | +3.5        | ✅ ACK |
| 2201  | 0x0002  | 0x389B  | +5.7        | ✅ ACK |
| 2209  | 0x0003  | 0x389A  | +4.4        | ✅ ACK |
| 2211  | 0x0004  | 0x3899  | +4.5        | ✅ ACK |
| 2213  | 0x0005  | 0x3898  | +3.6        | ✅ ACK |
| 2221  | 0x0006  | 0x3897  | +3.5        | ✅ ACK |
| 2223  | 0x0007  | 0x3896  | +2.9        | ✅ ACK |
| 2225  | 0x0008  | 0x3895  | +2.5        | ✅ ACK |
| 2227  | 0x0009  | 0x3894  | +4.8        | ✅ ACK |
| 2233  | 0x000A  | 0x3893  | +4.0        | ✅ ACK |
| 2235  | 0x000B  | 0x3892  | +3.7        | ✅ ACK |
| 2237  | 0x000C  | 0x3891  | +5.0        | ✅ ACK |

**Packet Structure Example (Frame 2197)**:
```
Header (8 bytes):
29 00 01 00 00 00 38 9d

Byte 0:       0x29  - Data packet marker
Byte 1:       0x00  - Frame index (static image)
Byte 2:       0x01  - Image mode
Byte 3:       0x00  - Fixed
Bytes 4-5:    00 00 - Counter (little-endian)
Bytes 6-7:    38 9d - Address (big-endian 0x389D = 14493)

Pixel Data (56 bytes):
27 b8 27 27 b8 27 27 b8 27 27 b8 27 27 b8 27 27
b8 27 27 b8 27 27 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 b8 27 27 00 00 00 00 00 00
```

✅ **Matches PSDynaTab packet structure** (from `New-PacketChunk.ps1`)

**Pixel Data Analysis**:
- Pattern `b8 27 27` appears repeatedly
  - RGB values: R=0xB8 (184), G=0x27 (39), B=0x27 (39)
  - Color: **Orange/amber** (#B82727)
- Pattern `00 00 00` represents **black** (off pixels)

💡 **Visual Pattern**: Displays orange pixels in specific positions with black background

**Counter & Address Behavior**:
```
Frame  Counter  Address   Counter Δ   Address Δ
2197   0x0000   0x389D    -           -
2199   0x0001   0x389C    +1          -1
2201   0x0002   0x389B    +1          -1
2209   0x0003   0x389A    +1          -1
...
2237   0x000C   0x3891    +1          -1
```

✅ **Expected behavior**: Counter increments, address decrements (confirmed in PSDynaTab code)

**Timing Analysis**:
- Average latency: **1.5ms per packet** (Set_Report to ACK)
- Packet interval: **3-5ms** (matches 5ms delay in `Send-FeaturePacket.ps1`)
- Total transmission: **~40ms for 13 packets**

✅ **Timing matches PSDynaTab implementation**

**All Transactions Successful**:
- `usbd_status: 0x00000000` on every response
- No NAKs, STALLs, or errors
- Device acknowledged every packet

---

## Key Findings

### ✅ Successes
1. **Device enumeration**: Clean detection and configuration
2. **Interface targeting**: Correct use of Interface 2 (MI_02)
3. **Protocol compliance**: Valid HID Feature Reports
4. **Packet structure**: Matches expected format with header + data
5. **Sequencing**: Proper counter increment / address decrement
6. **Error-free**: All transactions completed successfully
7. **Timing**: Appropriate delays between packets

### ⚠️ Observations
1. **Initialization packet differs** from PSDynaTab FIRST_PACKET
   - Could indicate firmware version difference
   - Or different display mode/resolution
   - Suggest investigating byte 4-7 parameters

2. **Get_Report used** (frame 2096) but not strictly necessary
   - PSDynaTab works without it
   - May provide status/handshake confirmation

3. **Only 13 data packets** transmitted
   - Full display = 1620 bytes = 29 packets (56 bytes each)
   - This update likely sent **728 bytes** (13 × 56)
   - Suggests **partial display update** or smaller image

### 📊 Expected vs Actual

| Metric | Expected (PSDynaTab) | Actual (Trace) | Match |
|--------|---------------------|----------------|-------|
| VID/PID | 0x3151/0x4015 | 0x3151/0x4015 | ✅ |
| Interface | MI_02 (Interface 2) | Interface 2 | ✅ |
| Report Type | Feature (3) | Feature (3) | ✅ |
| Report Size | 64 bytes | 64 bytes | ✅ |
| Header Byte | 0x29 | 0x29 | ✅ |
| Counter Start | 0x0000 | 0x0000 | ✅ |
| Address Start | 0x389D | 0x389D | ✅ |
| Packet Delay | 5ms | 3-5ms avg | ✅ |
| Init Packet | 0xa9... (specific) | 0xa9... (variant) | ⚠️ |

---

## Recommendations

### 1. **Investigate Initialization Packet Variants**
Compare the two initialization packets to understand parameter meanings:

```powershell
# Current PSDynaTab
$FIRST_PACKET = @(0xa9, 0x00, 0x01, 0x00, 0x54, 0x06, 0x00, 0xfb, ...)

# Trace variant
$ALTERNATE_INIT = @(0xa9, 0x00, 0x01, 0x00, 0x61, 0x05, 0x00, 0xef, ...)
```

**Action**: Create test function to try different init parameters and observe behavior.

### 2. **Add Optional Get_Report Handshake**
While not required, adding Get_Report after initialization could:
- Verify device readiness
- Read firmware version
- Detect error conditions

**Action**: Add `Test-DynaTabStatus` function using Get_Report.

### 3. **Document Packet Count Optimization**
This trace shows only 13 packets for partial update.

**Action**: Consider implementing:
- `Send-DynaTabPartialImage` - Update only changed region
- Delta compression for animations
- Dirty rectangle tracking

### 4. **Validate Timing Under Load**
Trace shows 3-5ms intervals (vs 5ms Sleep in code).

**Action**: Profile actual timing on different systems:
- Windows PowerShell vs PowerShell Core
- Different USB controllers
- Hub vs direct connection

### 5. **Add Packet Loss Detection**
Current implementation has no retry mechanism.

**Action**:
- Monitor for STALL/NAK responses
- Implement packet retry on timeout
- Add CRC/checksum validation if protocol supports it

---

## Protocol Summary

```
┌─────────────────────────────────────────────────────────┐
│ DynaTab Display Update Protocol (via HID Feature Reports) │
└─────────────────────────────────────────────────────────┘

1. ENUMERATION
   ├─ Get Device Descriptor (VID:0x3151, PID:0x4015)
   ├─ Get Configuration Descriptor (3 interfaces)
   └─ Set Configuration 1

2. INITIALIZATION
   ├─ Set_Report(Interface 2, Feature, 64 bytes)
   │  └─ Header: 0xa9 00 01 00 [params] [address] ...
   └─ [Optional] Get_Report(Interface 2, Feature)

3. DATA TRANSMISSION (for each packet)
   ├─ Set_Report(Interface 2, Feature, 64 bytes)
   │  ├─ Header (8 bytes):
   │  │  ├─ 0x29 (marker)
   │  │  ├─ 0x00 (frame index)
   │  │  ├─ 0x01 (image mode)
   │  │  ├─ 0x00 (fixed)
   │  │  ├─ Counter (2 bytes, LE, incrementing)
   │  │  └─ Address (2 bytes, BE, decrementing from 0x389D)
   │  └─ Pixel Data (56 bytes RGB888)
   └─ Wait 5ms

4. COMPLETION
   └─ Device renders after all packets received
```

---

## Conclusion

This USBPcap trace demonstrates a **fully successful display update** to the DynaTab keyboard with:
- ✅ Correct device identification and enumeration
- ✅ Proper HID Feature Report usage
- ✅ Valid packet structure and sequencing
- ✅ Zero errors or retransmissions
- ✅ Appropriate timing between operations

The trace validates the PSDynaTab implementation's protocol design. The minor initialization packet difference suggests either a firmware variant or an undocumented display mode worth investigating.

**Overall Assessment**: 🟢 **SUCCESSFUL UPDATE** - Protocol operating as designed.
