import 'package:flutter/material.dart';

import '../../../../../../ble/lw008_device_session.dart';
import '../../../../../../ble/lw008_param_helpers.dart';
import '../../../../../../ble/lw008_protocol_named_api.dart';
import '../../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../device_detail_utils.dart';

class VibrationDetectionPage extends StatefulWidget {
  const VibrationDetectionPage({super.key, required this.session});
  final Lw008DeviceSession session;

  @override
  State<VibrationDetectionPage> createState() => _VibrationDetectionPageState();
}

class _VibrationDetectionPageState extends State<VibrationDetectionPage> {
  bool _enabled = false;
  final _reportInterval = TextEditingController();
  final _timeout = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final results = await Future.wait([
        api.readShockDetectionEnable(),
        api.readShockReportInterval(),
        api.readShockTimeout(),
      ]);
      if (!mounted) return;
      _enabled = Lw008ParamHelpers.uint8(results[0].data) == 1;
      _reportInterval.text = Lw008ParamHelpers.uint8(results[1].data).toString();
      _timeout.text = Lw008ParamHelpers.uint8(results[2].data).toString();
      setState(() {});
    });
  }

  bool _validate() {
    final interval = int.tryParse(_reportInterval.text.trim());
    if (interval == null || interval < 3 || interval > 255) return false;
    final timeout = int.tryParse(_timeout.text.trim());
    return timeout != null && timeout >= 1 && timeout <= 20;
  }

  Future<void> _save() async {
    if (!_validate()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Para error!')),
        );
      }
      return;
    }
    final interval = int.parse(_reportInterval.text.trim());
    final timeout = int.parse(_timeout.text.trim());
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final ok = (await Future.wait([
        api.writeShockDetectionEnable([_enabled ? 1 : 0]),
        api.writeShockReportInterval([interval]),
        api.writeShockTimeout([timeout]),
      ])).every((r) => r);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  @override
  void dispose() {
    _reportInterval.dispose();
    _timeout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Shock Detection',
      showSave: true,
      onSave: _save,
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            child: Column(
              children: [
                SettingsSwitchRow(
                  label: 'Shock Detection',
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                SettingsLabelRow(
                  label: 'Report Interval',
                  child: SettingsTextField(
                    controller: _reportInterval,
                    hint: '3~255',
                    suffix: 's',
                  ),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Timeout',
                  child: SettingsTextField(
                    controller: _timeout,
                    hint: '1~20',
                    suffix: 's',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
