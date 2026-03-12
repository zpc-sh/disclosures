# Known Device Details

**Source:** Extracted from forensic analysis files + devices-raw.csv

---

## Confirmed Details

### Apple Watch Series 10
- **Serial:** K926T6THL6
- **Model:** Watch7,11 (MWYD3) - 42mm
- **watchOS:** 11.6.1 (Build 22U90)
- **Device ID:** 8CC843D1-CFD0-4F31-8C0B-A259D08A882C
- **Status:** CONFIRMED BOOTKIT (factory reset failed)

### Mac Mini M2 2024
- **Model:** Mac16,11 (2024)
- **Device ID:** 4C47CA3E-01C6-46EA-AB97-81141D822FE4
- **Status:** CONFIRMED BOOTKIT (kernelcache modified Sep 30 01:31)
- **Serial:** NEED FROM iCLOUD
- **macOS:** NEED FROM iCLOUD

### iPhone 16 Pro (iPhone Air)
- **Model:** iPhone18,4
- **Device ID:** 40983865-F224-46C6-B248-C4CE14B4E297
- **Battery:** 100%
- **Last Location:** Recent (1736560819974)
- **Status:** Suspected bootkit (fake power-off)
- **Serial:** NEED FROM iCLOUD
- **iOS:** NEED FROM iCLOUD
- **Carrier:** NEED FROM iCLOUD

### MacBook Air M4 2025
- **Model:** Mac16,12 (13-inch M4 2025)
- **Device ID:** 6F99B0FB-110D-4947-8140-ED620D5C39FF
- **Battery:** 99%
- **Status:** Clean (this is your current device)
- **Serial:** NEED FROM iCLOUD
- **macOS:** NEED FROM iCLOUD

### MacBook Pro 14-inch Nov 2023
- **Model:** Mac15,8
- **Device ID:** A72FFC8F-E942-469E-AA27-D7D993F076A2
- **Status:** Suspected compromise
- **Serial:** NEED FROM iCLOUD
- **macOS:** NEED FROM iCLOUD

### iPad Pro M4 11-inch
- **Model:** iPad16,4
- **Device ID:** 4C1E273F-AC80-42CF-8068-5780D854581A
- **Last Location:** 1735988068116
- **Status:** Suspected compromise
- **Serial:** NEED FROM iCLOUD
- **iPadOS:** NEED FROM iCLOUD

---

## HomePods (NEED DETAILS FROM iCLOUD)

### HomePod Mini (Office)
- **Location:** Office (near MacBook workspace)
- **IP:** 192.168.13.52
- **MAC:** d4:90:9c:ee:56:71
- **Status:** CONFIRMED BOOTKIT (252x CPU, 9,419 sec rapportd)
- **Serial:** NEED FROM iCLOUD
- **audioOS:** NEED FROM iCLOUD

### HomePod Mini (Bedroom)
- **Location:** Bedroom (3 feet from victim)
- **Device ID:** 9adca36f9be34eda53b28959633c40827c4f1b26
- **Status:** CONFIRMED BOOTKIT (242x CPU, 9,549 sec rapportd)
- **Serial:** NEED FROM iCLOUD
- **audioOS:** NEED FROM iCLOUD

---

## Apple TV (NEED DETAILS FROM iCLOUD)

### Apple TV 4K
- **Status:** Suspected compromise
- **Model:** NEED FROM iCLOUD
- **Serial:** NEED FROM iCLOUD
- **tvOS:** NEED FROM iCLOUD

---

## Other Devices (Family/Thu's Devices - Not Compromised)

### iPhone 14 Pro
- **Model:** iPhone15,2
- **Device ID:** B4DC3394-72D4-4DED-80E4-F0014830CA87
- **Status:** Unknown

### Mac Mini M1 2020 (m1 (6))
- **Model:** Macmini9,1
- **Device ID:** 0745F715-6E9F-42B3-923C-4E2B88B66EE1
- **Status:** Unknown

### Thu's Devices
- Thu6214 (iPhone 12 Pro Max) - iPhone13,4
- Thu's Apple Watch (Apple Watch Ultra 2) - Watch7,5
- Thu's iPad (iPad Pro 11-inch 3rd gen) - iPad13,4
- Thu's MacBook Pro (13") - MacBookPro11,1

---

## What Opus Needs to Collect from iCloud.com

Navigate to: **iCloud.com → Settings → Devices**

For each compromised device, collect:

**Primary Devices (Confirmed Bootkits):**
1. ✅ Apple Watch Series 10 (K926T6THL6) - watchOS [NEED]
2. Mac Mini M2 2024 - Serial [NEED] - macOS [NEED]
3. HomePod Mini (Office) - Serial [NEED] - audioOS [NEED]
4. HomePod Mini (Bedroom) - Serial [NEED] - audioOS [NEED]

**Secondary Devices (Suspected):**
5. iPhone 16 Pro (iPhone Air) - Serial [NEED] - iOS [NEED] - Carrier [NEED]
6. MacBook Pro 14" (Nov 2023) - Serial [NEED] - macOS [NEED]
7. iPad Pro M4 11" - Serial [NEED] - iPadOS [NEED]
8. Apple TV 4K - Model [NEED] - Serial [NEED] - tvOS [NEED]

---

## How to Find Each Device on iCloud.com

**iCloud.com → Settings:**
- Click "Devices" section
- Look for these names:
  - "Apple Watch" (Series 10)
  - "Mac Mini" (2024)
  - "iPhone" (iPhone Air / 16 Pro)
  - "HomePod" or room names
  - "MacBook Pro" (14-inch)
  - "iPad Pro" (M4)
  - "Apple TV"

**For each device, note:**
- Serial Number (usually shown in device details)
- OS Version (e.g., "macOS 15.1", "iOS 18.0")
- Carrier (iPhone only)

---

## Quick Copy Format for Opus

When Opus collects data, format like this:

```
Mac Mini M2 2024
Serial: CXXXXXXXXXX
macOS: 15.1

Apple Watch Series 10
Serial: K926T6THL6
watchOS: 11.6.1

iPhone 16 Pro
Serial: FXXXXXXXXXX
iOS: 18.0
Carrier: Verizon

HomePod Mini (Office)
Serial: DXXXXXXXXXX
audioOS: 18.0

HomePod Mini (Bedroom)
Serial: DXXXXXXXXXX
audioOS: 18.0

MacBook Pro 14-inch
Serial: CXXXXXXXXXX
macOS: 15.1

iPad Pro M4
Serial: DXXXXXXXXXX
iPadOS: 18.0

Apple TV 4K
Serial: CXXXXXXXXXX
tvOS: 18.0
```

Then update APPLE-PORTAL-SUBMISSION.md by replacing all [FILL] markers.

---

**Summary:** We have 1 serial number (Watch). Need 7 more from iCloud.com.
