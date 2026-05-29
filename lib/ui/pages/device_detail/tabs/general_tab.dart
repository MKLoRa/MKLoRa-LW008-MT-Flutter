import 'package:flutter/material.dart';

import '../../../../../ble/lw008.dart';
import '../../../../../ble/lw008_device_session.dart';
import '../../../../../ble/lw008_param_helpers.dart';
import '../../../../../ble/lw008_protocol_named_api.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../general/auxiliary_operation_page.dart';
import '../general/axis_setting_page.dart';
import '../general/ble_settings_page.dart';
import '../general/device_mode_page.dart';

class GeneralTab extends StatefulWidget {
  const GeneralTab({super.key, required this.session, required this.onSaveReady});

  final Lw008DeviceSession session;
  final void Function(Future<bool> Function() save) onSaveReady;

  @override
  State<GeneralTab> createState() => GeneralTabState();
}

class GeneralTabState extends State<GeneralTab> {
  final _heartbeatController = TextEditingController();
  bool _axisEnable = false;
  bool _showAxisSwitch = false;

  @override
  void initState() {
    super.initState();
    widget.onSaveReady(_save);
  }

  Future<void> load({bool showOverlay = true}) async {
    await runWithBleLoading(
      context,
      () async {
        final api = widget.session.protocol;
        final firmware = await widget.session.deviceInfoApi.readFirmwareRevision();
        final showAxis = Lw008OptionLists.isFirmwareAtLeast(
          firmware.isEmpty ? 'V1.1.0' : firmware,
          'V1.0.9',
        );
        final heartbeat = await api.readHeartbeatInterval();
        final axis = showAxis ? await api.readAxisEnable() : null;
        if (!mounted) return;
        _showAxisSwitch = showAxis;
        _heartbeatController.text =
            Lw008ParamHelpers.bytesToInt(heartbeat.data).toString();
        if (axis != null) {
          _axisEnable = Lw008ParamHelpers.uint8(axis.data) == 1;
        }
        setState(() {});
      },
      showOverlay: showOverlay,
    );
  }

  Future<bool> _save() async {
    final text = _heartbeatController.text.trim();
    final value = int.tryParse(text);
    if (value == null || value < 300 || value > 86400) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Heartbeat interval must be 300~86400')),
        );
      }
      return false;
    }
    final heartbeatOk = await widget.session.protocol.writeHeartbeatInterval(
      Lw008ParamHelpers.int32Bytes(value),
    );
    if (!heartbeatOk) return false;
    if (!_showAxisSwitch) return true;
    return widget.session.protocol.writeAxisEnable([_axisEnable ? 1 : 0]);
  }

  @override
  void dispose() {
    _heartbeatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        SettingsCard(
          child: SettingsNavRow(
            title: 'Device Mode',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DeviceModePage(session: widget.session),
              ),
            ),
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'Auxiliary Operation',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AuxiliaryOperationPage(session: widget.session),
              ),
            ),
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'BLE Settings',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BleSettingsPage(session: widget.session),
              ),
            ),
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: '3-axis Setting',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AxisSettingPage(session: widget.session),
              ),
            ),
          ),
        ),
        SettingsCard(
          child: SettingsLabelRow(
            label: 'Heartbeat Interval',
            child: SettingsTextField(
              controller: _heartbeatController,
              hint: '300~86400',
              maxLength: 5,
              suffix: 's',
            ),
          ),
        ),
        if (_showAxisSwitch)
          SettingsCard(
            child: SettingsSwitchRow(
              label: '3-Axis Switch',
              value: _axisEnable,
              onChanged: (value) => setState(() => _axisEnable = value),
            ),
          ),
      ],
    );
  }
}
