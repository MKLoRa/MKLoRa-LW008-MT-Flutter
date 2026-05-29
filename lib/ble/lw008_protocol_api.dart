import 'lw008_ble_client.dart';
import 'lw008_param_key.dart';

class Lw008ProtocolApi {
  Lw008ProtocolApi(this._client);

  final Lw008BleClient _client;

  Lw008BleClient get client => _client;

  Future<bool> verifyPassword(String password) {
    return _client.verifyPassword(password);
  }

  Future<Lw008ParamResult> readParam(
    Lw008ParamKey key, {
    Lw008ParamChannel channel = Lw008ParamChannel.runtime,
    bool packet = false,
  }) {
    if (!key.canRead) {
      throw Lw008ProtocolException('Parameter ${key.name} is write-only');
    }
    return _client.readParam(
      key: key.key,
      channel: channel,
      packet: packet,
    );
  }

  Future<bool> writeParam(
    Lw008ParamKey key,
    List<int> data, {
    Lw008ParamChannel channel = Lw008ParamChannel.runtime,
    bool packet = false,
    int packetCount = 1,
    int packetIndex = 0,
  }) {
    if (!key.canWrite) {
      throw Lw008ProtocolException('Parameter ${key.name} is read-only');
    }
    return _client.writeParam(
      key: key.key,
      data: data,
      channel: channel,
      packet: packet,
      packetCount: packetCount,
      packetIndex: packetIndex,
    );
  }
}

class Lw008DeviceInfoApi {
  Lw008DeviceInfoApi(this._client);

  final Lw008BleClient _client;

  Future<String> readModelNumber() => _client.readModelNumber();
  Future<String> readSerialNumber() => _client.readSerialNumber();
  Future<String> readFirmwareRevision() => _client.readFirmwareRevision();
  Future<String> readHardwareRevision() => _client.readHardwareRevision();
  Future<String> readSoftwareRevision() => _client.readSoftwareRevision();
  Future<String> readManufacturerName() => _client.readManufacturerName();
}
