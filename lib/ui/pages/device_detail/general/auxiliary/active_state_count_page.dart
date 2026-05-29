import 'package:flutter/material.dart';

import '../../../../../../ble/lw008_device_session.dart';
import '../../../../../../ble/lw008_param_helpers.dart';
import '../../../../../../ble/lw008_protocol_named_api.dart';
import '../../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../device_detail_utils.dart';

class ActiveStateCountPage extends StatefulWidget {
  const ActiveStateCountPage({super.key, required this.session});
  final Lw008DeviceSession session;

  @override
  State<ActiveStateCountPage> createState() => _ActiveStateCountPageState();
}

class _ActiveStateCountPageState extends State<ActiveStateCountPage> {
  bool _enabled = false;
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
        api.readActiveStateCountEnable(),
        api.readActiveStateTimeout(),
      ]);
      if (!mounted) return;
      _enabled = Lw008ParamHelpers.uint8(results[0].data) == 1;
      _timeout.text = Lw008ParamHelpers.bytesToInt(results[1].data).toString();
      setState(() {});
    });
  }

  bool _validate() {
    final timeout = int.tryParse(_timeout.text.trim());
    return timeout != null && timeout >= 1 && timeout <= 86400;
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
        api.writeActiveStateCountEnable([_enabled ? 1 : 0]),
        api.writeActiveStateTimeout(Lw008ParamHelpers.int32Bytes(timeout)),
      ])).every((r) => r);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  @override
  void dispose() {
    _timeout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Active State Count',
      showSave: true,
      onSave: _save,
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            child: Column(
              children: [
                SettingsSwitchRow(
                  label: 'Active State Count',
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                SettingsLabelRow(
                  label: 'Active State Timeout',
                  child: SettingsTextField(
                    controller: _timeout,
                    hint: '1~86400',
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
