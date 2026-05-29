import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'lw008_constants.dart';
import 'lw008_data_codec.dart';
import 'lw008_disconnect_event.dart';
import 'lw008_protocol_codec.dart';
import 'lw008_protocol_logger.dart';

class Lw008BleClient {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _passwordChar;
  BluetoothCharacteristic? _disconnectChar;
  BluetoothCharacteristic? _paramsChar;
  BluetoothCharacteristic? _storageDataNotifyChar;
  BluetoothCharacteristic? _logNotifyChar;
  BluetoothCharacteristic? _modelNumberChar;
  BluetoothCharacteristic? _serialNumberChar;
  BluetoothCharacteristic? _firmwareRevisionChar;
  BluetoothCharacteristic? _hardwareRevisionChar;
  BluetoothCharacteristic? _softwareRevisionChar;
  BluetoothCharacteristic? _manufacturerNameChar;

  final Map<String, StreamSubscription<List<int>>> _notifySubscriptions = {};
  final Map<String, Completer<List<int>>> _pendingRequests = {};
  final Map<String, List<List<int>>> _packetBuffers = {};
  final _disconnectController = StreamController<Lw008DisconnectEvent>.broadcast();
  final _storageNotifyController =
      StreamController<Lw008StorageNotifyParseResult>.broadcast();
  final _logNotifyController = StreamController<String>.broadcast();
  var _logNotifySubscribed = false;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  Future<void> _requestChain = Future<void>.value();

  Stream<Lw008DisconnectEvent> get disconnectEvents => _disconnectController.stream;

  Stream<Lw008StorageNotifyParseResult> get storageNotifyEvents =>
      _storageNotifyController.stream;

  Stream<String> get logNotifyEvents => _logNotifyController.stream;

  bool get isLogNotifyEnabled => _logNotifySubscribed;

  BluetoothDevice? get device => _device;
  bool get isConnected => _device?.isConnected ?? false;

  Future<void> connectWithRetry(BluetoothDevice device) async {
    _device = device;
    final deadline = DateTime.now().add(Lw008ProtocolConstants.connectTotalTimeout);
    Object? lastError;

    for (var attempt = 0; attempt < Lw008ProtocolConstants.connectMaxAttempts; attempt++) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw TimeoutException(
          'Connection timed out after ${Lw008ProtocolConstants.connectTotalTimeout.inSeconds}s',
        );
      }

      try {
        if (device.isConnected) {
          await device.disconnect();
        }
        await device.connect(
          timeout: remaining,
          autoConnect: false,
        );
        if (Platform.isAndroid) {
          await device.requestMtu(247);
        }
        await _discoverServices(device);
        await _enableNotifications();
        await Future<void>.delayed(const Duration(milliseconds: 500));
        _listenConnectionState(device);
        return;
      } catch (error) {
        lastError = error;
        debugPrint('LW008 connect attempt ${attempt + 1} failed: $error');
        if (attempt < Lw008ProtocolConstants.connectMaxAttempts - 1) {
          await Future<void>.delayed(
            const Duration(milliseconds: Lw008ProtocolConstants.connectRetryDelayMs),
          );
        }
      }
    }

    throw lastError ?? Exception('Connection failed');
  }

  Future<void> disconnect() async {
    await disableLogNotify();
    await _clearSubscriptions();
    final device = _device;
    _device = null;
    if (device != null && device.isConnected) {
      await device.disconnect();
    }
  }

  Future<bool> verifyPassword(String password) async {
    final characteristic = _requireCharacteristic(_passwordChar, 'password');
    final response = await _sendFrame(
      characteristic: characteristic,
      payload: Lw008ProtocolCodec.buildPasswordFrame(password),
      key: Lw008ProtocolConstants.passwordCmd,
      matcher: Lw008ProtocolCodec.isPasswordSuccess,
    );
    return Lw008ProtocolCodec.isPasswordSuccess(response);
  }

  Future<Lw008ParamResult> readParam({
    required int key,
    Lw008ParamChannel channel = Lw008ParamChannel.runtime,
    bool packet = false,
  }) async {
    final characteristic = _characteristicForChannel(channel);
    final response = await _sendFrame(
      characteristic: characteristic,
      payload: Lw008ProtocolCodec.buildReadFrame(key: key, packet: packet),
      key: key,
    );
    final parsed = Lw008ProtocolCodec.parseReadResponse(response);
    if (parsed == null) {
      throw Lw008ProtocolException(
        'Invalid read response for 0x${key.toRadixString(16)}',
      );
    }
    return Lw008ParamResult(
      key: parsed.key,
      data: parsed.data,
      raw: response,
    );
  }

  Future<bool> writeParam({
    required int key,
    required List<int> data,
    Lw008ParamChannel channel = Lw008ParamChannel.runtime,
    bool packet = false,
    int packetCount = 1,
    int packetIndex = 0,
  }) async {
    final characteristic = _characteristicForChannel(channel);
    final response = await _sendFrame(
      characteristic: characteristic,
      payload: Lw008ProtocolCodec.buildWriteFrame(
        key: key,
        data: data,
        packet: packet,
        packetCount: packetCount,
        packetIndex: packetIndex,
      ),
      key: key,
      matcher: (value) => Lw008ProtocolCodec.isWriteAck(value, key),
    );
    return Lw008ProtocolCodec.isWriteSuccess(response, key);
  }

  Future<String> readDeviceInfoString(
    BluetoothCharacteristic characteristic, {
    required String name,
  }) async {
    final value = await characteristic.read();
    Lw008ProtocolLogger.logGattRead(name: name, value: value);
    return String.fromCharCodes(value.where((b) => b != 0)).trim();
  }

  Future<String> readModelNumber() => readDeviceInfoString(
        _requireCharacteristic(_modelNumberChar, 'model number'),
        name: 'modelNumber',
      );
  Future<String> readSerialNumber() => readDeviceInfoString(
        _requireCharacteristic(_serialNumberChar, 'serial number'),
        name: 'serialNumber',
      );
  Future<String> readFirmwareRevision() => readDeviceInfoString(
        _requireCharacteristic(_firmwareRevisionChar, 'firmware revision'),
        name: 'firmwareRevision',
      );
  Future<String> readHardwareRevision() => readDeviceInfoString(
        _requireCharacteristic(_hardwareRevisionChar, 'hardware revision'),
        name: 'hardwareRevision',
      );
  Future<String> readSoftwareRevision() => readDeviceInfoString(
        _requireCharacteristic(_softwareRevisionChar, 'software revision'),
        name: 'softwareRevision',
      );
  Future<String> readManufacturerName() => readDeviceInfoString(
        _requireCharacteristic(_manufacturerNameChar, 'manufacturer name'),
        name: 'manufacturerName',
      );

  Future<void> enableLogNotify() async {
    final characteristic = _logNotifyChar;
    if (characteristic == null) {
      throw Lw008ProtocolException('Log notify characteristic unavailable');
    }
    if (_logNotifySubscribed) {
      return;
    }
    await characteristic.setNotifyValue(true);
    await _notifySubscriptions['log']?.cancel();
    _notifySubscriptions['log'] = characteristic.onValueReceived.listen(
      (value) => _handleNotification('log', value),
    );
    _logNotifySubscribed = true;
  }

  Future<void> disableLogNotify() async {
    final characteristic = _logNotifyChar;
    if (characteristic == null || !_logNotifySubscribed) {
      return;
    }
    await _notifySubscriptions['log']?.cancel();
    _notifySubscriptions.remove('log');
    await characteristic.setNotifyValue(false);
    _logNotifySubscribed = false;
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();
    final deviceInfo = _findService(services, Lw008Uuids.deviceInfoService);
    final custom = _findService(services, Lw008Uuids.customService);

    if (deviceInfo == null) {
      throw Lw008ProtocolException('Device Information Service not found');
    }
    if (custom == null) {
      throw Lw008ProtocolException('Custom service 0xAA00 not found');
    }

    _modelNumberChar = _findCharacteristic(deviceInfo, Lw008Uuids.modelNumber);
    _serialNumberChar = _findCharacteristic(deviceInfo, Lw008Uuids.serialNumber);
    _firmwareRevisionChar = _findCharacteristic(deviceInfo, Lw008Uuids.firmwareRevision);
    _hardwareRevisionChar = _findCharacteristic(deviceInfo, Lw008Uuids.hardwareRevision);
    _softwareRevisionChar = _findCharacteristic(deviceInfo, Lw008Uuids.softwareRevision);
    _manufacturerNameChar = _findCharacteristic(deviceInfo, Lw008Uuids.manufacturerName);

    _passwordChar = _findCharacteristic(custom, Lw008Uuids.password);
    _disconnectChar = _findCharacteristic(custom, Lw008Uuids.disconnectNotify);
    _paramsChar = _findCharacteristic(custom, Lw008Uuids.params);
    _storageDataNotifyChar = _findCharacteristic(custom, Lw008Uuids.storageDataNotify);
    _logNotifyChar = _findCharacteristic(custom, Lw008Uuids.logNotify);

    if (_passwordChar == null || _paramsChar == null || _disconnectChar == null) {
      throw Lw008ProtocolException('Required custom characteristics not found');
    }
  }

  Future<void> _enableNotifications() async {
    await _subscribeCharacteristic(_passwordChar!, 'password');
    await _subscribeCharacteristic(_disconnectChar!, 'disconnect');
    await _subscribeCharacteristic(_paramsChar!, 'params');
    if (_storageDataNotifyChar != null) {
      await _subscribeCharacteristic(_storageDataNotifyChar!, 'storageData');
    }
  }

  Future<void> _subscribeCharacteristic(
    BluetoothCharacteristic characteristic,
    String channelKey,
  ) async {
    await characteristic.setNotifyValue(true);
    await _notifySubscriptions[channelKey]?.cancel();
    _notifySubscriptions[channelKey] = characteristic.onValueReceived.listen(
      (value) => _handleNotification(channelKey, value),
    );
  }

  void _handleNotification(String channelKey, List<int> value) {
    if (value.isEmpty) {
      return;
    }

    if (channelKey == 'disconnect') {
      Lw008ProtocolLogger.logDisconnectNotify(value);
      final event = Lw008DisconnectEvent.fromNotificationBytes(value);
      if (event != null) {
        _disconnectController.add(event);
      }
      return;
    }

    if (channelKey == 'storageData') {
      Lw008ProtocolLogger.logRx(channel: channelKey, payload: value);
      final parsed = Lw008DataCodec.parseStorageNotify(value);
      if (parsed != null) {
        _storageNotifyController.add(parsed);
      }
      return;
    }

    if (channelKey == 'log') {
      Lw008ProtocolLogger.logRx(channel: channelKey, payload: value);
      if (value.isNotEmpty) {
        _logNotifyController.add(String.fromCharCodes(value));
      }
      return;
    }

    if (value[0] == Lw008ProtocolConstants.headPacket) {
      Lw008ProtocolLogger.logRx(channel: channelKey, payload: value, partialPacket: true);
      final requestKey = _requestKeyFromPacket(value);
      _packetBuffers.putIfAbsent(requestKey, () => []).add(value);
      final packets = _packetBuffers[requestKey]!;
      final expectedCount = value[3];
      if (packets.length >= expectedCount) {
        final merged = Lw008ProtocolCodec.reassemblePacketResponses(packets);
        _packetBuffers.remove(requestKey);
        Lw008ProtocolLogger.logRx(channel: channelKey, payload: merged);
        _completeRequest(requestKey, merged);
      }
      return;
    }

    Lw008ProtocolLogger.logRx(channel: channelKey, payload: value);
    final requestKey = _requestKeyFromFrame(value);
    _completeRequest(requestKey, value);
  }

  Future<List<int>> _sendFrame({
    required BluetoothCharacteristic characteristic,
    required List<int> payload,
    required int key,
    bool Function(List<int> value)? matcher,
  }) {
    return _enqueueRequest(() async {
      final requestKey = _requestKey(key);
      final completer = Completer<List<int>>();
      _pendingRequests[requestKey] = completer;

      try {
        Lw008ProtocolLogger.logTx(
          channel: _channelNameForCharacteristic(characteristic),
          key: key,
          payload: payload,
        );
        final withoutResponse = _shouldWriteWithoutResponse(characteristic);
        await characteristic.write(payload, withoutResponse: withoutResponse);
        final response = await completer.future.timeout(
          Lw008ProtocolConstants.requestTimeout,
          onTimeout: () {
            Lw008ProtocolLogger.logError('Request timeout for $requestKey');
            throw Lw008ProtocolTimeoutException(requestKey);
          },
        );
        if (matcher != null && !matcher(response)) {
          Lw008ProtocolLogger.logError('Unexpected response for $requestKey');
          throw Lw008ProtocolException('Unexpected response for $requestKey');
        }
        return response;
      } finally {
        _pendingRequests.remove(requestKey);
        _packetBuffers.remove(requestKey);
      }
    });
  }

  Future<T> _enqueueRequest<T>(Future<T> Function() action) {
    final task = _requestChain.then((_) => action());
    _requestChain = task.then((_) {}, onError: (_) {});
    return task;
  }

  bool _shouldWriteWithoutResponse(BluetoothCharacteristic characteristic) {
    final properties = characteristic.properties;
    if (properties.write) {
      return false;
    }
    return properties.writeWithoutResponse;
  }

  void _completeRequest(String requestKey, List<int> value) {
    final completer = _pendingRequests[requestKey];
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
  }

  BluetoothCharacteristic _characteristicForChannel(Lw008ParamChannel channel) {
    switch (channel) {
      case Lw008ParamChannel.runtime:
        return _requireCharacteristic(_paramsChar, 'params');
      case Lw008ParamChannel.storageData:
        return _requireCharacteristic(_storageDataNotifyChar, 'storage data');
    }
  }

  BluetoothService? _findService(List<BluetoothService> services, String uuid) {
    final target = Guid(uuid);
    for (final service in services) {
      if (service.uuid == target) {
        return service;
      }
    }
    return null;
  }

  BluetoothCharacteristic? _findCharacteristic(
    BluetoothService service,
    String uuid,
  ) {
    final target = Guid(uuid);
    for (final characteristic in service.characteristics) {
      if (characteristic.uuid == target) {
        return characteristic;
      }
    }
    return null;
  }

  BluetoothCharacteristic _requireCharacteristic(
    BluetoothCharacteristic? characteristic,
    String name,
  ) {
    if (characteristic == null) {
      throw Lw008ProtocolException('$name characteristic unavailable');
    }
    return characteristic;
  }

  String _channelNameForCharacteristic(BluetoothCharacteristic characteristic) {
    if (identical(characteristic, _passwordChar)) return 'password';
    if (identical(characteristic, _paramsChar)) return 'params';
    if (identical(characteristic, _storageDataNotifyChar)) return 'storageData';
    if (identical(characteristic, _logNotifyChar)) return 'log';
    return characteristic.uuid.toString();
  }

  String _requestKey(int key) => key.toRadixString(16);

  String _requestKeyFromFrame(List<int> value) {
    if (value.length < 3) {
      return 'unknown';
    }
    return _requestKey(value[2] & 0xFF);
  }

  String _requestKeyFromPacket(List<int> value) {
    if (value.length < 3) {
      return 'unknown';
    }
    return _requestKey(value[2] & 0xFF);
  }

  void _listenConnectionState(BluetoothDevice device) {
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _disconnectController.add(Lw008DisconnectEvent.generic);
      }
    });
  }

  Future<void> _clearSubscriptions() async {
    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    for (final subscription in _notifySubscriptions.values) {
      await subscription.cancel();
    }
    _notifySubscriptions.clear();
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          Lw008ProtocolException('Connection closed'),
        );
      }
    }
    _pendingRequests.clear();
    _packetBuffers.clear();
  }
}

enum Lw008ParamChannel {
  runtime,
  storageData,
}

class Lw008ParamResult {
  const Lw008ParamResult({
    required this.key,
    required this.data,
    required this.raw,
  });

  final int key;
  final List<int> data;
  final List<int> raw;
}

class Lw008ProtocolException implements Exception {
  Lw008ProtocolException(this.message);

  final String message;

  @override
  String toString() => 'Lw008ProtocolException: $message';
}

class Lw008ProtocolTimeoutException extends TimeoutException {
  Lw008ProtocolTimeoutException(String requestKey)
      : super(requestKey, Lw008ProtocolConstants.requestTimeout);

  static const userMessage = 'Failed';
}
