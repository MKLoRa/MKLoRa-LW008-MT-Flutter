class Lw008Uuids {
  Lw008Uuids._();

  static const deviceInfoService = '0000180a-0000-1000-8000-00805f9b34fb';
  static const customService = '0000aa00-0000-1000-8000-00805f9b34fb';
  static const advServiceData = '0000aa09-0000-1000-8000-00805f9b34fb';

  static const modelNumber = '00002a24-0000-1000-8000-00805f9b34fb';
  static const serialNumber = '00002a25-0000-1000-8000-00805f9b34fb';
  static const firmwareRevision = '00002a26-0000-1000-8000-00805f9b34fb';
  static const hardwareRevision = '00002a27-0000-1000-8000-00805f9b34fb';
  static const softwareRevision = '00002a28-0000-1000-8000-00805f9b34fb';
  static const manufacturerName = '00002a29-0000-1000-8000-00805f9b34fb';

  static const password = '0000aa00-0000-1000-8000-00805f9b34fb';
  static const disconnectNotify = '0000aa01-0000-1000-8000-00805f9b34fb';
  static const params = '0000aa02-0000-1000-8000-00805f9b34fb';
  static const storageDataNotify = '0000aa03-0000-1000-8000-00805f9b34fb';
  static const logNotify = '0000aa05-0000-1000-8000-00805f9b34fb';
}

class Lw008ProtocolConstants {
  Lw008ProtocolConstants._();

  static const headSingle = 0xED;
  static const headPacket = 0xEE;
  static const flagRead = 0x00;
  static const flagWrite = 0x01;
  static const flagNotify = 0x02;

  static const passwordCmd = 0x01;

  static const connectMaxAttempts = 5;
  static const connectRetryDelayMs = 200;
  static const connectTotalTimeout = Duration(seconds: 50);
  static const requestTimeout = Duration(seconds: 10);
  static const packetDataMaxLength = 176;
}
