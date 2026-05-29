import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/ble_device_info.dart';
import 'lw008_ble_client.dart';
import 'lw008_export_data_store.dart';
import 'lw008_protocol_api.dart';

class Lw008DeviceSession {
  Lw008DeviceSession._({
    required this.deviceInfo,
    required this.client,
    required this.protocol,
    required this.deviceInfoApi,
  });

  final BleDeviceInfo deviceInfo;
  final Lw008BleClient client;
  final Lw008ProtocolApi protocol;
  final Lw008DeviceInfoApi deviceInfoApi;
  final Lw008ExportDataStore exportData = Lw008ExportDataStore();

  static Lw008DeviceSession? _active;

  static Lw008DeviceSession? get active => _active;

  static Future<Lw008DeviceSession> connect({
    required BleDeviceInfo deviceInfo,
    String? password,
  }) async {
    final bluetoothDevice = BluetoothDevice.fromId(deviceInfo.id.str);
    final client = Lw008BleClient();

    await client.connectWithRetry(bluetoothDevice);

    if (password != null && password.isNotEmpty) {
      final verified = await client.verifyPassword(password);
      if (!verified) {
        await client.disconnect();
        throw Lw008ProtocolException('Password verification failed');
      }
    }

    final session = Lw008DeviceSession._(
      deviceInfo: deviceInfo,
      client: client,
      protocol: Lw008ProtocolApi(client),
      deviceInfoApi: Lw008DeviceInfoApi(client),
    );
    _active = session;
    return session;
  }

  Future<void> disconnect() async {
    await client.disconnect();
    clearActiveIfMatches(this);
  }

  static void clearActiveIfMatches(Lw008DeviceSession session) {
    if (_active == session) {
      _active = null;
    }
  }
}
