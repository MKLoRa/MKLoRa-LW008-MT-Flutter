import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

String hexString(List<int> data) {
  return data
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}

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

  /// MAC from advertisement Service Data (0xAA09), for iOS compatibility.
  String get advMacAddress =>
      macAddress.isNotEmpty ? macAddress : macFromAdvServiceData(rawServiceData);

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

  static bool _isLw008AdvUuid(Guid uuid) {
    return uuid.toString().toLowerCase().contains('aa09');
  }

  static List<int>? _lw008AdvPayload(AdvertisementData adv) {
    for (final entry in adv.serviceData.entries) {
      if (_isLw008AdvUuid(entry.key) && entry.value.isNotEmpty) {
        return entry.value;
      }
    }
    return null;
  }

  /// Parses the 6-byte MAC embedded in LW008 AA09 Service Data (offset 6).
  static String macFromAdvServiceData(List<int> data) {
    if (data.length < 12) {
      return '';
    }

    return data
        .sublist(6, 12)
        .map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  static String _hardwareMac(ScanResult result) {
    final remoteId = result.device.remoteId.str;
    if (remoteId.contains(':')) {
      return remoteId.toUpperCase();
    }
    return '';
  }

  static BleDeviceInfo? fromScanResult(ScanResult result) {
    final adv = result.advertisementData;
    final data = _lw008AdvPayload(adv);
    if (data == null || data.length < 4) {
      return null;
    }

    final deviceType = data[0] & 0xFF;
    final txPower = data.length > 1 ? data[1] : adv.txPowerLevel;
    final workMode = data.length > 2 ? data[2] & 0xFF : 0;
    final statusByte = data.length > 3 ? data[3] & 0xFF : 0;
    final lowPower = (statusByte & 0x01) == 0x01;
    final passwordEnabled = (statusByte & 0x02) == 0x02;
    final batteryVoltageMv = data.length > 5
        ? ((data[4] & 0xFF) << 8) | (data[5] & 0xFF)
        : 0;

    final advMac = macFromAdvServiceData(data);
    final hardwareMac = _hardwareMac(result);
    final macAddress = advMac.isNotEmpty
        ? advMac
        : (Platform.isAndroid ? hardwareMac : '');

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
