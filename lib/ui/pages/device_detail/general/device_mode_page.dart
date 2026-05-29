import 'package:flutter/material.dart';

import '../../../../../ble/lw008_device_session.dart';
import '../../../../../ble/lw008_option_lists.dart';
import '../../../../../ble/lw008_param_helpers.dart';
import '../../../../../ble/lw008_protocol_named_api.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/device_detail/bottom_picker_dialog.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../device_detail_utils.dart';
import 'mode/motion_mode_page.dart';
import 'mode/periodic_mode_page.dart';
import 'mode/timing_mode_page.dart';

class DeviceModePage extends StatefulWidget {
  const DeviceModePage({super.key, required this.session});
  final Lw008DeviceSession session;

  @override
  State<DeviceModePage> createState() => _DeviceModePageState();
}

class _DeviceModePageState extends State<DeviceModePage> {
  int _modeIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final result = await widget.session.protocol.readDeviceMode();
      if (!mounted) return;
      setState(() => _modeIndex = Lw008ParamHelpers.uint8(result.data).clamp(0, 3));
    });
  }

  Future<void> _pickMode() async {
    final index = await showBottomPicker(
      context: context,
      options: Lw008OptionLists.deviceModes,
      selectedIndex: _modeIndex,
    );
    if (index == null || !mounted) return;
    setState(() => _modeIndex = index);
    await runWithBleLoading(context, () async {
      final ok = await widget.session.protocol.writeDeviceMode([index]);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return DetailScaffold(
      title: 'Device Mode',
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            child: SettingsLabelRow(
              label: 'Device Mode',
              child: BlueValueButton(
                text: Lw008OptionLists.deviceModes[_modeIndex],
                onTap: _pickMode,
              ),
            ),
          ),
          SettingsCard(child: SettingsNavRow(title: 'Timing Mode', onTap: () => pushDetailPage(context, TimingModePage(session: session)))),
          SettingsCard(child: SettingsNavRow(title: 'Periodic Mode', onTap: () => pushDetailPage(context, PeriodicModePage(session: session)))),
          SettingsCard(child: SettingsNavRow(title: 'Motion Mode', onTap: () => pushDetailPage(context, MotionModePage(session: session)))),
        ],
      ),
    );
  }
}
