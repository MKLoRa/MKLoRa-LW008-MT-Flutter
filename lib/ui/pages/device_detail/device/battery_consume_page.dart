import 'package:flutter/material.dart';

import '../../../../../ble/lw008_data_codec.dart';
import '../../../../../ble/lw008_device_session.dart';
import '../../../../../ble/lw008_protocol_named_api.dart';
import '../../../../../ui/theme/device_detail_theme.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/common_confirm_dialog.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../../../../viewmodels/ble_scan_view_model.dart';

class BatteryConsumePage extends StatefulWidget {
  const BatteryConsumePage({super.key, required this.session});
  final Lw008DeviceSession session;

  @override
  State<BatteryConsumePage> createState() => _BatteryConsumePageState();
}

class _BatteryConsumePageState extends State<BatteryConsumePage> {
  Map<String, dynamic>? _current;
  Map<String, dynamic>? _all;
  Map<String, dynamic>? _last;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final results = await Future.wait([
        api.readBatteryInfoNew(),
        api.readBatteryInfoAll(),
        api.readBatteryInfoLast(),
      ]);
      if (!mounted) return;
      setState(() {
        _current = Lw008DataCodec.decodeBatteryConsumeInfo(results[0].data);
        _all = Lw008DataCodec.decodeBatteryConsumeInfo(results[1].data);
        _last = Lw008DataCodec.decodeBatteryConsumeInfo(results[2].data);
      });
    });
  }

  Future<void> _batteryReset() async {
    final ok = await showCommonConfirmDialog(
      context: context,
      title: 'Warning！',
      message: 'Are you sure to reset battery?',
      actionColor: BleScanViewModel.titleBarColor,
    );
    if (!ok || !mounted) return;
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final writeOk = await api.writeBatteryResetNewEmpty();
      if (!writeOk) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Opps！Save failed. Please check the input characters and try again.',
              ),
            ),
          );
        }
        return;
      }
      await _load();
      if (!mounted) return;
      await showCommonConfirmDialog(
        context: context,
        message: 'Reset Successfully！',
        confirmText: 'OK',
        actionColor: BleScanViewModel.titleBarColor,
        barrierDismissible: false,
        showCancel: false,
      );
    });
  }

  Widget _infoSection({
    required String title,
    required Map<String, dynamic>? info,
  }) {
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: DeviceDetailTheme.textPrimary,
            ),
          ),
          if (info == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('-', style: TextStyle(fontSize: 13)),
            )
          else ...[
            _line('Runtime', '${info['runtime']} s'),
            _line('ADV Times', '${info['advTimes']} times'),
            _line('Axis Duration', '${info['axisDuration']} s'),
            _line('BLE Fix Duration', '${info['bleFixDuration']} s'),
            _line('WiFi Fix Duration', '${info['wifiFixDuration']} s'),
            _line('GPS L76 Fix Duration', '${info['gpsL76FixDuration']} s'),
            _line('GPS LR1110 Fix Duration', '${info['gpsLrFixDuration']} s'),
            _line('Static Pos Payload', '${info['staticPosPayload']} times'),
            _line('Motion Pos Payload', '${info['motionPosPayload']} times'),
            _line('LoRa Transmission Times', '${info['loraTransmissionTimes']} times'),
            _line('LoRa Power', '${info['loraPower']} mAS'),
            _line(
              'Battery Consumption',
              '${Lw008DataCodec.formatBatteryConsumeMah(info['batteryConsumeMah'] as double)} mAH',
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 13,
          color: DeviceDetailTheme.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Battery Consumption Information',
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          _infoSection(title: 'Current Cycle Battery Information:', info: _current),
          SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsLabelRow(
                  label: 'Battery Reset',
                  child: BlueValueButton(
                    text: 'Reset',
                    minWidth: 70,
                    onTap: _batteryReset,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '*After replace with the new battery, need to click "Reset", otherwise the low power prompt will be unnormal.',
                  style: TextStyle(
                    fontSize: 12,
                    color: DeviceDetailTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          _infoSection(title: 'All Cycles Battery Information:', info: _all),
          _infoSection(title: 'Last Cycle Battery Information:', info: _last),
        ],
      ),
    );
  }
}
