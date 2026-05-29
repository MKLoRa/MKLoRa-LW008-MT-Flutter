import 'package:flutter/material.dart';

import '../../../../../ble/lw008_data_codec.dart';
import '../../../../../ble/lw008_device_session.dart';
import '../../../../../ble/lw008_param_helpers.dart';
import '../../../../../ble/lw008_protocol_named_api.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../device_detail_utils.dart';

class IndicatorSettingsPage extends StatefulWidget {
  const IndicatorSettingsPage({super.key, required this.session});
  final Lw008DeviceSession session;

  @override
  State<IndicatorSettingsPage> createState() => _IndicatorSettingsPageState();
}

class _IndicatorSettingsPageState extends State<IndicatorSettingsPage> {
  bool _lowPower = false;
  bool _networkCheck = false;
  bool _fix = false;
  bool _fixSuccess = false;
  bool _fixFail = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final result = await widget.session.protocol.readIndicatorStatus();
      if (!mounted || result.data.isEmpty) return;
      final value = Lw008ParamHelpers.bytesToInt(result.data);
      final decoded = Lw008DataCodec.decodeIndicator(value);
      setState(() {
        _lowPower = decoded['lowPower']!;
        _networkCheck = decoded['networkCheck']!;
        _fix = decoded['fix']!;
        _fixSuccess = decoded['fixSuccess']!;
        _fixFail = decoded['fixFail']!;
      });
    });
  }

  Future<void> _save() async {
    await runWithBleLoading(context, () async {
      final value = Lw008DataCodec.encodeIndicator(
        lowPower: _lowPower,
        networkCheck: _networkCheck,
        fix: _fix,
        fixSuccess: _fixSuccess,
        fixFail: _fixFail,
      );
      final ok = await widget.session.protocol.writeIndicatorStatus([value]);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Indicator Settings',
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
                  label: 'Low-power',
                  value: _lowPower,
                  onChanged: (v) => setState(() => _lowPower = v),
                ),
                const SettingsDivider(),
                SettingsSwitchRow(
                  label: 'Network Check',
                  value: _networkCheck,
                  onChanged: (v) => setState(() => _networkCheck = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsSwitchRow(
                  label: 'In Fix',
                  value: _fix,
                  onChanged: (v) => setState(() => _fix = v),
                ),
                const SettingsDivider(),
                SettingsSwitchRow(
                  label: 'Fix Successful',
                  value: _fixSuccess,
                  onChanged: (v) => setState(() => _fixSuccess = v),
                ),
                const SettingsDivider(),
                SettingsSwitchRow(
                  label: 'Fail To Fix',
                  value: _fixFail,
                  onChanged: (v) => setState(() => _fixFail = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
