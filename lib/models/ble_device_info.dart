import 'package:flutter_blue_plus/flutter_blue_plus.dart';

String hexString(List<int> data) {
  return data
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}

/// LW008 scan advertisement Service Data UUID (AD type 0x16, protocol v1.0.13).
const _lw008AdvServiceUuid = '0000aa09-0000-1000-8000-00805f9b34fb';

class BleDeviceInfo {
  final DeviceIdentifier id;
  final String name;
  final String macAddress;
  final int rssi;
  final int? txPowerLevel;
  final int deviceType;
  final int workMode;
  final int batteryVoltageMv;
  final bool lowPower;
  final bool passwordEnabled;
  final bool connectable;
  final List<int> rawServiceData;
  final int lastScanMs;
  final int scanIntervalMs;

  BleDeviceInfo({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.rssi,
    required this.txPowerLevel,
    required this.deviceType,
    required this.workMode,
    required this.batteryVoltageMv,
    required this.lowPower,
    required this.passwordEnabled,
    this.connectable = true,
    required this.rawServiceData,
    this.lastScanMs = 0,
    this.scanIntervalMs = 0,
  });

  /// MAC from AD type 0x16 broadcast (last 6 bytes); used on scan list for iOS/Android.
  String get advMacAddress => macFromType16ServiceData(rawServiceData);

  String get scanIntervalLabel =>
      scanIntervalMs == 0 ? '<->N/A' : '<->${scanIntervalMs}ms';

  BleDeviceInfo copyWith({
    DeviceIdentifier? id,
    String? name,
    String? macAddress,
    int? rssi,
    int? txPowerLevel,
    int? deviceType,
    int? workMode,
    int? batteryVoltageMv,
    bool? lowPower,
    bool? passwordEnabled,
    bool? connectable,
    List<int>? rawServiceData,
    int? lastScanMs,
    int? scanIntervalMs,
  }) {
    return BleDeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      rssi: rssi ?? this.rssi,
      txPowerLevel: txPowerLevel ?? this.txPowerLevel,
      deviceType: deviceType ?? this.deviceType,
      workMode: workMode ?? this.workMode,
      batteryVoltageMv: batteryVoltageMv ?? this.batteryVoltageMv,
      lowPower: lowPower ?? this.lowPower,
      passwordEnabled: passwordEnabled ?? this.passwordEnabled,
      connectable: connectable ?? this.connectable,
      rawServiceData: rawServiceData ?? this.rawServiceData,
      lastScanMs: lastScanMs ?? this.lastScanMs,
      scanIntervalMs: scanIntervalMs ?? this.scanIntervalMs,
    );
  }

  static BleDeviceInfo mergeScanUpdate({
    required BleDeviceInfo? previous,
    required BleDeviceInfo parsed,
    required int lastScanMs,
    required int scanIntervalMs,
  }) {
    final raw = _preferLongerPayload(
      previous?.rawServiceData ?? const [],
      parsed.rawServiceData,
    );
    final mac = macFromType16ServiceData(raw);
    return parsed.copyWith(
      macAddress: mac,
      rawServiceData: raw,
      lastScanMs: lastScanMs,
      scanIntervalMs: scanIntervalMs,
    );
  }

  static List<int> _preferLongerPayload(List<int> a, List<int> b) {
    if (b.length > a.length) {
      return b;
    }
    if (a.length > b.length) {
      return a;
    }
    final macA = macFromType16ServiceData(a);
    final macB = macFromType16ServiceData(b);
    if (macB.isNotEmpty && macA.isEmpty) {
      return b;
    }
    return a.isNotEmpty ? a : b;
  }

  static bool _isLw008AdvUuid(Guid uuid) {
    return uuid.toString().toLowerCase().contains('aa09');
  }

  static bool _isLw008DeviceType(int deviceType) {
    return deviceType == 0x00 || deviceType == 0x10;
  }

  /// Skip 16-bit UUID prefix (0xAA09) when embedded in the service-data value.
  static int _payloadOffset(List<int> data) {
    if (data.length >= 9 && data[0] == 0xAA && data[1] == 0x09) {
      return 2;
    }
    if (data.length >= 9 && data[0] == 0x09 && data[1] == 0xAA) {
      return 2;
    }
    return 0;
  }

  /// AD type 0x16 (Service Data 0xAA09): last 6 bytes are device MAC.
  static String macFromType16ServiceData(List<int> data) {
    if (data.length < 6) {
      return '';
    }
    final macBytes = data.sublist(data.length - 6);
    if (macBytes.every((b) => b == 0)) {
      return '';
    }
    return _macFromBytes(macBytes);
  }

  static String _macFromBytes(List<int> macBytes) {
    return macBytes
        .map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  static List<int>? _lw008Type16Payload(AdvertisementData adv) {
    final byUuid = adv.serviceData[Guid(_lw008AdvServiceUuid)];
    if (byUuid != null && byUuid.isNotEmpty) {
      return byUuid;
    }

    for (final entry in adv.serviceData.entries) {
      if (_isLw008AdvUuid(entry.key) && entry.value.isNotEmpty) {
        return entry.value;
      }
    }

    // iOS may expose service data under a different map key.
    for (final data in adv.serviceData.values) {
      if (data.length >= 12) {
        final offset = _payloadOffset(data);
        if (_isLw008DeviceType(data[offset] & 0xFF)) {
          return data;
        }
      }
    }

    for (final bytes in adv.msd) {
      final embedded = _type16FromMsd(bytes);
      if (embedded != null) {
        return embedded;
      }
    }

    return null;
  }

  /// Search manufacturer-specific data for AD type 0x16 + UUID 0xAA09 block.
  static List<int>? _type16FromMsd(List<int> bytes) {
    for (var i = 0; i + 8 <= bytes.length; i++) {
      if (bytes[i] == 0x16 &&
          i + 3 < bytes.length &&
          ((bytes[i + 1] == 0x09 && bytes[i + 2] == 0xAA) ||
              (bytes[i + 1] == 0xAA && bytes[i + 2] == 0x09))) {
        final block = bytes.sublist(i + 1);
        if (block.length >= 8) {
          return block;
        }
      }
      if ((bytes[i] == 0x09 && bytes[i + 1] == 0xAA) ||
          (bytes[i] == 0xAA && bytes[i + 1] == 0x09)) {
        final block = bytes.sublist(i);
        if (block.length >= 8 && _isLw008DeviceType(block[_payloadOffset(block)] & 0xFF)) {
          return block;
        }
      }
    }
    return null;
  }

  static BleDeviceInfo? fromScanResult(ScanResult result) {
    final adv = result.advertisementData;
    final data = _lw008Type16Payload(adv);
    if (data == null) {
      return null;
    }

    final offset = _payloadOffset(data);
    if (data.length < offset + 4) {
      return null;
    }

    final deviceType = data[offset] & 0xFF;
    if (!_isLw008DeviceType(deviceType)) {
      return null;
    }

    final txPower = data.length > offset + 1
        ? data[offset + 1]
        : adv.txPowerLevel;
    final workMode =
        data.length > offset + 2 ? data[offset + 2] & 0xFF : 0;
    final statusByte =
        data.length > offset + 3 ? data[offset + 3] & 0xFF : 0;
    final lowPower = (statusByte & 0x01) == 0x01;
    final passwordEnabled = (statusByte & 0x02) == 0x02;
    final batteryVoltageMv = data.length >= offset + 6
        ? ((data[offset + 4] & 0xFF) << 8) | (data[offset + 5] & 0xFF)
        : 0;

    final macAddress = macFromType16ServiceData(data);

    return BleDeviceInfo(
      id: result.device.remoteId,
      name: adv.advName.isNotEmpty ? adv.advName : result.device.advName,
      macAddress: macAddress,
      rssi: result.rssi,
      txPowerLevel: txPower,
      deviceType: deviceType,
      workMode: workMode,
      batteryVoltageMv: batteryVoltageMv,
      lowPower: lowPower,
      passwordEnabled: passwordEnabled,
      connectable: result.advertisementData.connectable,
      rawServiceData: data,
    );
  }
}
