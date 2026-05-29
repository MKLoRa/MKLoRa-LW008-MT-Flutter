import 'dart:convert';
import 'dart:typed_data';

import 'lw008_constants.dart';

class Lw008ProtocolCodec {
  Lw008ProtocolCodec._();

  static List<int> buildReadFrame({
    required int key,
    bool packet = false,
  }) {
    if (packet) {
      return [
        Lw008ProtocolConstants.headPacket,
        Lw008ProtocolConstants.flagRead,
        key,
        0x00,
      ];
    }
    return [
      Lw008ProtocolConstants.headSingle,
      Lw008ProtocolConstants.flagRead,
      key,
      0x00,
    ];
  }

  static List<int> buildWriteFrame({
    required int key,
    required List<int> data,
    bool packet = false,
    int packetCount = 1,
    int packetIndex = 0,
  }) {
    if (packet) {
      return [
        Lw008ProtocolConstants.headPacket,
        Lw008ProtocolConstants.flagWrite,
        key,
        packetCount,
        packetIndex,
        data.length,
        ...data,
      ];
    }
    return [
      Lw008ProtocolConstants.headSingle,
      Lw008ProtocolConstants.flagWrite,
      key,
      data.length,
      ...data,
    ];
  }

  static List<int> buildPasswordFrame(String password) {
    final passwordBytes = utf8.encode(password);
    return [
      Lw008ProtocolConstants.headSingle,
      Lw008ProtocolConstants.flagWrite,
      Lw008ProtocolConstants.passwordCmd,
      passwordBytes.length,
      ...passwordBytes,
    ];
  }

  static bool isPasswordSuccess(List<int> value) {
    if (value.length < 5) {
      return false;
    }
    return value[0] == Lw008ProtocolConstants.headSingle &&
        value[1] == Lw008ProtocolConstants.flagWrite &&
        value[2] == Lw008ProtocolConstants.passwordCmd &&
        value[3] == 0x01 &&
        value[4] == 0x01;
  }

  static bool isWriteAck(List<int> value, int key) {
    if (value.length < 5) {
      return false;
    }
    return value[0] == Lw008ProtocolConstants.headSingle &&
        value[1] == Lw008ProtocolConstants.flagWrite &&
        (value[2] & 0xFF) == key &&
        value[3] == 0x01;
  }

  static bool isWriteSuccess(List<int> value, int key) {
    return isWriteAck(value, key) && value[4] == 0x01;
  }

  static Lw008ParsedFrame? parseReadResponse(List<int> value) {
    if (value.isEmpty) {
      return null;
    }
    final header = value[0];
    if (header == Lw008ProtocolConstants.headSingle) {
      if (value.length < 4) {
        return null;
      }
      final key = value[2] & 0xFF;
      final length = value[3];
      if (value.length < 4 + length) {
        return null;
      }
      return Lw008ParsedFrame(
        key: key,
        data: value.sublist(4, 4 + length),
      );
    }
    if (header == Lw008ProtocolConstants.headPacket) {
      if (value.length < 6) {
        return null;
      }
      final key = value[2] & 0xFF;
      final length = value[5];
      if (value.length < 6 + length) {
        return null;
      }
      return Lw008ParsedFrame(
        key: key,
        data: value.sublist(6, 6 + length),
        packetIndex: value[4],
        packetCount: value[3],
      );
    }
    return null;
  }

  static List<int> reassemblePacketResponses(List<List<int>> packets) {
    if (packets.isEmpty) {
      return const [];
    }
    final first = packets.first;
    if (first.isEmpty || first[0] != Lw008ProtocolConstants.headPacket) {
      return const [];
    }
    final buffer = BytesBuilder();
    for (final packet in packets) {
      if (packet.length < 6) {
        continue;
      }
      final length = packet[5];
      buffer.add(packet.sublist(6, 6 + length));
    }
    final data = buffer.toBytes();
    final key = first[2] & 0xFF;
    return [
      Lw008ProtocolConstants.headSingle,
      Lw008ProtocolConstants.flagRead,
      key,
      data.length,
      ...data,
    ];
  }
}

class Lw008ParsedFrame {
  const Lw008ParsedFrame({
    required this.key,
    required this.data,
    this.packetIndex,
    this.packetCount,
  });

  final int key;
  final List<int> data;
  final int? packetIndex;
  final int? packetCount;
}
