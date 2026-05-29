import 'package:flutter/material.dart';

import '../../../../../../ble/lw008_device_session.dart';
import '../../../../../../ble/lw008_param_helpers.dart';
import '../../../../../../ble/lw008_protocol_named_api.dart';
import '../../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../../ui/widgets/common_confirm_dialog.dart';
import '../../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../device_detail_utils.dart';

class ManDownDetectionPage extends StatefulWidget {
  const ManDownDetectionPage({super.key, required this.session});
  final Lw008DeviceSession session;

  @override
  State<ManDownDetectionPage> createState() => _ManDownDetectionPageState();
}

class _ManDownDetectionPageState extends State<ManDownDetectionPage> {
  bool _detection = false;
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
        api.readManDownDetectionEnable(),
        api.readManDownDetectionTimeout(),
      ]);
      if (!mounted) return;
      _detection = Lw008ParamHelpers.uint8(results[0].data) == 1;
      _timeout.text = Lw008ParamHelpers.bytesToInt(results[1].data).toString();
      setState(() {});
    });
  }

  bool _validate() {
    final timeout = int.tryParse(_timeout.text.trim());
    return timeout != null && timeout >= 1 && timeout <= 8760;
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
    final timeout = int.parse(_timeout.text.trim());
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final ok = (await Future.wait([
        api.writeManDownDetectionEnable([_detection ? 1 : 0]),
        api.writeManDownDetectionTimeout(Lw008ParamHelpers.uint16Bytes(timeout)),
      ])).every((r) => r);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  Future<void> _resetIdleStatus() async {
    final confirmed = await showCommonConfirmDialog(
      context: context,
      title: 'Reset Idle Status',
      message: 'Whether to confirm the reset',
      cancelText: 'YES',
      confirmText: 'Cancel',
    );
    if (!confirmed && mounted) {
      await runWithBleLoading(context, () async {
        final ok = await widget.session.protocol.writeManDownIdleReset(const []);
        if (mounted) await saveWithToast(context, () async => ok);
      });
    }
  }

  @override
  void dispose() {
    _timeout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'ManDown Detection',
      showSave: true,
      onSave: _save,
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsSwitchRow(
                  label: 'Man Down Detection',
                  value: _detection,
                  onChanged: (v) => setState(() => _detection = v),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Idle Detection Timeout',
                  child: SettingsTextField(
                    controller: _timeout,
                    hint: '1~8760',
                    maxLength: 4,
                    suffix: 'H',
                  ),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Idle Status',
                  child: BlueValueButton(
                    text: 'Reset',
                    onTap: _resetIdleStatus,
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
