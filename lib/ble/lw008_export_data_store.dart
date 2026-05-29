import 'lw008_data_codec.dart';

/// In-memory export cache (mirrors native LoRaLW008MokoSupport.exportDatas).
class Lw008ExportDataStore {
  final List<Lw008ExportRecord> records = [];
  final StringBuffer exportText = StringBuffer();
  int startTimeDays = 0;
  int? totalSum;

  void clear() {
    records.clear();
    exportText.clear();
    startTimeDays = 0;
    totalSum = null;
  }

  void appendRecords(List<Lw008ExportRecord> batch, {required bool insertAtHead}) {
    final formattedBatch = batch.map(_formatRecord).toList();
    if (insertAtHead) {
      for (var i = batch.length - 1; i >= 0; i--) {
        records.insert(0, batch[i]);
      }
      final previous = exportText.toString();
      exportText
        ..clear()
        ..write(formattedBatch.join())
        ..write(previous);
    } else {
      records.addAll(batch);
      for (final formatted in formattedBatch) {
        exportText.write(formatted);
      }
    }
  }

  String _formatRecord(Lw008ExportRecord record) {
    final time = _formatTime(record.time);
    final buffer = StringBuffer('Time:$time\n');
    if (record.rawData.isNotEmpty) {
      buffer.writeln('Raw Data:${record.rawData}');
    }
    buffer.writeln();
    return buffer.toString();
  }

  String _formatTime(DateTime time) {
    final y = time.year.toString().padLeft(4, '0');
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$s';
  }
}
