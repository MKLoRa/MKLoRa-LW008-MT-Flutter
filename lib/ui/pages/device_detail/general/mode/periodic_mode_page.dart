import 'package:flutter/material.dart';

import '../../../../../../ble/lw008_device_session.dart';
import '../../../../../../ble/lw008_option_lists.dart';
import '../../../../../../ble/lw008_param_helpers.dart';
import '../../../../../../ble/lw008_protocol_named_api.dart';
import '../../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../../ui/widgets/device_detail/bottom_picker_dialog.dart';
import '../../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../device_detail_utils.dart';

class PeriodicModePage extends StatefulWidget {
  const PeriodicModePage({super.key, required this.session});
  final Lw008DeviceSession session;

  @override
  State<PeriodicModePage> createState() => _PeriodicModePageState();
}

class _PeriodicModePageState extends State<PeriodicModePage> {
  int _strategyIndex = 0;
  final _interval = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final results = await Future.wait([
        widget.session.protocol.readPeriodicModePosStrategy(),
        widget.session.protocol.readPeriodicModeReportInterval(),
      ]);
      if (!mounted) return;
      _strategyIndex =
          Lw008ParamHelpers.uint8(results[0].data).clamp(0, Lw008OptionLists.posStrategy7.length - 1);
      _interval.text = Lw008ParamHelpers.bytesToInt(results[1].data).toString();
      setState(() {});
    });
  }

  Future<void> _pickStrategy() async {
    final index = await showBottomPicker(
      context: context,
      options: Lw008OptionLists.posStrategy7,
      selectedIndex: _strategyIndex,
    );
    if (index != null) setState(() => _strategyIndex = index);
  }

  Future<void> _save() async {
    final value = int.tryParse(_interval.text.trim());
    if (value == null || value < 30 || value > 86400) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Para error!')),
        );
      }
      return;
    }
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final ok = (await Future.wait([
        api.writePeriodicModePosStrategy([_strategyIndex]),
        api.writePeriodicModeReportInterval(Lw008ParamHelpers.int32Bytes(value)),
      ])).every((r) => r);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  @override
  void dispose() {
    _interval.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Periodic Mode',
      showSave: true,
      onSave: _save,
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsLabelRow(
                  label: 'Positioning Strategy',
                  child: BlueValueButton(
                    text: Lw008OptionLists.posStrategy7[_strategyIndex],
                    onTap: _pickStrategy,
                  ),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Report Interval',
                  child: SettingsTextField(
                    controller: _interval,
                    hint: '30~86400',
                    maxLength: 5,
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
