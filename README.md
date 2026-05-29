# MKLoRa LW008 Flutter

Flutter client for **LW008-MT** devices. Supports BLE scanning, connection, protocol parameter read/write, device-initiated disconnect notifications, LoRa configuration, positioning (BLE / WiFi / GPS), motion modes, auxiliary detection, beacon filter rules, local storage data sync, log export, and Nordic DFU firmware updates on Android and iOS physical devices.

Native Android reference: [`LW008_Android`]

---

## Requirements

- Flutter SDK `^3.12.0`
- Android / iOS **physical device** (simulators do not support BLE)
- iOS: grant Bluetooth permission on first launch; run `pod install` in `ios/` when using CocoaPods

---

## Quick Start

```bash
flutter pub get
flutter run
```

The app opens on the scan page. Tap **CONNECT** on a device to connect and open the detail page.

---

## Project Structure

```
lib/
├── ble/                         # BLE connection and LW008 protocol layer
│   ├── lw008_ble_client.dart          # Connect, read/write frames, Notify handling
│   ├── lw008_protocol_api.dart        # Generic readParam / writeParam
│   ├── lw008_protocol_named_api.dart  # Named helpers (readLoraMode, writeAdvName, …)
│   ├── lw008_param_key.dart           # Parameter keys (ParamsKeyEnum mirror)
│   ├── lw008_param_helpers.dart       # Byte helpers + syncTime()
│   ├── lw008_data_codec.dart          # Filter / storage-notify encode-decode
│   ├── lw008_device_session.dart      # Session wrapper (connection + API entry)
│   ├── lw008_export_data_store.dart   # In-memory tracked log cache
│   ├── lw008_tracked_file.dart        # tracked.txt persistence (Local Data Sync)
│   └── lw008_constants.dart           # GATT UUIDs and protocol constants
├── dfu/                         # Nordic DFU upgrade
├── models/                      # Scan result models (BleDeviceInfo)
├── viewmodels/                  # Scan page ViewModel
└── ui/                          # Pages and widgets
    └── pages/
        ├── ble_scan_page.dart
        ├── device_detail_page.dart
        └── device_detail/       # LoRa / Position / General / Device tabs & sub-pages
```

---


## 1. Scanning for Devices

Scanning is handled by `BleScanViewModel` via `flutter_blue_plus`, filtering LW008 advertisements by Service Data UUID `0000aa09-0000-1000-8000-00805f9b34fb`.

Parsed fields (aligned with native `AdvInfoAnalysisImpl` / `BleDeviceInfo`):

| Field | Source |
|-------|--------|
| `deviceType` | Byte 0 |
| `workMode` | Byte 2 |
| `lowPower` | Bit 0 of byte 3 |
| `passwordEnabled` | Bit 1 of byte 3 |
| `batteryVoltageMv` | Bytes 4–5 (big-endian mV) |
| `macAddress` | Bytes 6–11 in Service Data (used on iOS; Android falls back to hardware MAC) |
| `scanIntervalMs` | Derived from successive advertisement timestamps |

### Usage

```dart
final vm = BleScanViewModel();
await vm.init(context);
await vm.startScan(context: context, clearDevices: true);
vm.stopScan();

final devices = vm.filteredDevices;   // Sorted by RSSI
await vm.applyFilter(context: context, keyword: 'LW008', rssiDbm: -80);
```

```dart
for (final device in vm.filteredDevices) {
  print(device.name);
  print(device.advMacAddress);
  print('${device.rssi} dBm');
  print(device.scanIntervalLabel);    // "<->N/A" or "<->1234ms"
  print(device.passwordEnabled);
}
```

---

## 2. Connecting to a Device

Scanning stops before connecting. A GATT connection is established and the password is verified when required. Returns a `Lw008DeviceSession`.

```dart
import 'package:lw008_flutter/ble/lw008.dart';

final device = vm.filteredDevices.first;

final session = await vm.connectDevice(
  context: context,
  device: device,
  password: device.passwordEnabled ? '123456' : null,
);

// Or use the lower-level API directly
final session = await Lw008DeviceSession.connect(
  deviceInfo: device,
  password: '123456',
);
```

After a successful connection:

| Member | Description |
|--------|-------------|
| `session.protocol` | Parameter read/write API |
| `session.deviceInfoApi` | Standard Device Information characteristics |
| `session.client.disconnectEvents` | Device-initiated disconnect notifications |
| `session.client.storageNotifyEvents` | Local Data Sync notify stream (AA03) |
| `session.client.logNotifyEvents` | Debug log notify stream (AA05) |
| `session.exportData` | In-memory cache for Local Data Sync UI |

Connection details (`Lw008BleClient.connectWithRetry`):

- Up to 5 retries, 50 s total timeout
- Android requests MTU 247; iOS negotiates MTU automatically
- Waits 500 ms after connect before sending protocol frames

Entering the detail page automatically calls `protocol.syncTime()` (UTC epoch seconds, param `0x13`).

---

## 3. Reading and Writing Protocol Parameters

Frame format: `ED [flag] [cmd] [subCmd] [len] [data…]`

- `flag=0x00` read, `flag=0x01` write, `flag=0x02` notify
- Responses arrive asynchronously via Notify characteristics
- Multi-packet responses use head `0xEE` and are reassembled automatically

Parameter keys are defined in `lib/ble/lw008_param_key.dart` (mirror of native `ParamsKeyEnum`).

### 3.1 Named API (Recommended)

`Lw008ProtocolNamedReadApi` / `Lw008ProtocolNamedWriteApi` extensions on `Lw008ProtocolApi`:

```dart
final api = session.protocol;

// Read LoRa mode (ABP=1, OTAA=2)
final mode = await api.readLoraMode();
print(Lw008ParamHelpers.uint8(mode.data));

// Read LoRa region
final region = await api.readLoraRegion();

// Read advertisement name
final advName = await api.readAdvName();
print(Lw008ParamHelpers.bytesToString(advName.data));

// Write time zone (picker index → device byte)
final ok = await api.writeTimeZone(Lw008ParamHelpers.timeZoneBytesFromIndex(32));

// Write LoRa OTAA mode
await api.writeLoraMode([2]);

// Sync UTC time (also called on detail page entry)
final synced = await api.syncTime();

// Trigger reboot
await api.writeRebootEmpty();
```

Integer payloads use **big-endian** byte order (`Lw008ParamHelpers.int32Bytes`, `uint16Bytes`, `bytesToInt`), matching native `MokoUtils.toInt` / `toByteArray`.

### 3.2 Generic API

```dart
final result = await api.readParam(Lw008ParamKey.advTxPower);
final txPower = Lw008ParamHelpers.byte0(result.data);

await api.writeHeartbeatInterval(Lw008ParamHelpers.int32Bytes(300));
```

### 3.3 GATT Device Information

```dart
final info = session.deviceInfoApi;
final model = await info.readModelNumber();
final firmware = await info.readFirmwareRevision();
final serial = await info.readSerialNumber();
```

### 3.4 Return Values

| Type | Field | Description |
|------|-------|-------------|
| `Lw008ParamResult` | `data` | Parsed payload bytes |
| | `raw` | Full frame returned by the device |
| | `key` | Parameter command byte |
| `writeParam` | returns `bool` | `true` when write ACK byte is `0x01` |

Common parsing helpers: `Lw008ParamHelpers.uint8`, `uint16`, `int32`, `bytesToInt`, `bytesToString`, `hexToBytes`, etc.

---

## 4. Receiving Data (Notify)

Device responses and push data are delivered via BLE Notify. `Lw008BleClient` matches incoming frames to pending requests and completes the corresponding `Future`.

### 4.1 Protocol Responses (AA02 params)

Each `readParam` / `writeParam` call:

1. Writes a request frame to the params characteristic
2. Waits for a Notify response with the same key
3. Reassembles multi-packet responses when `head=0xEE`

You do not need to subscribe to the params characteristic manually.

### 4.2 Disconnect Notifications (AA01)

```dart
session.client.disconnectEvents.listen((event) {
  print('type=${event.type}');
  print(event.message);
  // 1=password timeout  2=password changed  3=3-min idle
  // 4=reboot  5=factory reset
});
```

Example raw notify frame: `ED 02 00 01 01 04` → type 4, device rebooted.

The detail page handles this globally: a dialog is shown and the user is returned to the scan page.

### 4.3 Local Data Sync (AA03 storage)

Storage notify frames are parsed by `Lw008DataCodec.parseStorageNotify` and exposed on `session.client.storageNotifyEvents`:

```dart
session.client.storageNotifyEvents.listen((event) {
  if (event.records != null) {
    session.exportData.appendRecords(
      event.records!,
      insertAtHead: session.exportData.startTimeDays == 65535,
    );
  }
  if (event.totalSum != null) {
    session.exportData.totalSum = event.totalSum;
  }
});
```

UI flow (**Device tab → Local Data Sync**, aligned with native `ExportDataActivity`):

1. **Start** — `startStorageDataRead(days)`; `65535` reads all stored records (newest inserted at head)
2. **Sync / Stop** — toggle `setStorageSyncEnabled(true/false)`
3. **Empty** — `writeClearStorageDataEmpty()`
4. **Export** — writes cache to `{appDocuments}/LW008/tracked.txt`, then opens the system share sheet

### 4.4 Debug Log (AA05)

**Device tab → System Information → Log Data** subscribes to `logNotifyEvents` and saves output under the app documents directory.

---

## 5. Disconnecting

### Manual Disconnect

```dart
await session.disconnect();
await vm.disconnectDevice();
await vm.onReturnedFromDetail(context);   // Disconnect + clear list and rescan
```

### Unexpected Disconnect

When the device sends a disconnect Notify or the BLE link drops, `disconnectEvents` emits an event. The detail page shows a dialog, calls `session.disconnect()`, and returns to the scan page.

Disconnect events are ignored during DFU to avoid false dialogs.

---

## 6. DFU Firmware Update

UI entry: **Device tab → System Information → DFU**

Flow (`Lw008DfuService` + `nordic_dfu`):

1. User selects a `.zip` firmware package
2. MAC address is saved; current GATT connection is closed
3. DFU progress dialog is shown
4. Nordic DFU starts using the MAC address
5. Success: *Update firmware successfully! Please reconnect the device.* → return to scan page
6. Failure: error shown via SnackBar

```dart
import 'package:lw008_flutter/dfu/lw008_dfu_coordinator.dart';
import 'package:lw008_flutter/dfu/lw008_dfu_service.dart';

Lw008DfuCoordinator.begin(mac: device.macAddress);
await session.disconnect();

await Lw008DfuService.start(
  address: device.macAddress,
  filePath: '/path/to/firmware.zip',
  onStatus: (status) => print(status),
  onProgress: (percent) => print('$percent%'),
);

Lw008DfuCoordinator.end();
```

Notes:

- Firmware package must be a **ZIP** file
- Do not rely on the original GATT session during DFU; the device reboots when done
- Swift Package Manager is disabled in `pubspec.yaml` (`enable-swift-package-manager: false`) to use the CocoaPods NordicDFU build on iOS

---

## 7. Debug Protocol Logging

In debug builds, the console prints all TX/RX frames:

```
[LW008 TX] params | READ loraMode (0x05) | frame=ED 00 05 00
[LW008 RX] params | loraMode (0x05) | frame=ED 00 05 01 02 | data=02
```

Disable logging:

```dart
Lw008ProtocolLogger.enabled = false;
```

---

## 8. Permissions

| Platform | Permissions |
|----------|-------------|
| Android | `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, location (required for scanning) |
| iOS | `NSBluetoothAlwaysUsageDescription` (configured in `Info.plist`) |

---

## 9. App UI Overview

```
Scan page
  └─ startScan → device list (Service Data AA09)
  └─ connectDevice → Lw008DeviceSession
       └─ Detail page (LoRa / Position / General / Device tabs)
            ├─ syncTime() on entry → "Time sync completed!"
            ├─ protocol.readXxx / writeXxx
            ├─ storageNotifyEvents → Local Data Sync
            ├─ disconnectEvents → dialog → back to scan page
            └─ DFU → pick zip → upgrade → back to scan page
```

| Tab | Main features |
|-----|---------------|
| LoRa | Region, OTAA/ABP, connection settings, app keys |
| Position | WiFi / BLE / GPS fix, offline fix, filter rules |
| General | Device mode, BLE settings, motion/timing/periodic modes, auxiliary detection |
| Device | Local Data Sync, indicator, timezone, payloads, system info, factory reset, power off |

---

## Repository

- GitHub: [MKLoRa/MKLoRa-LW008-Flutter](https://github.com/MKLoRa/MKLoRa-LW008-Flutter)
