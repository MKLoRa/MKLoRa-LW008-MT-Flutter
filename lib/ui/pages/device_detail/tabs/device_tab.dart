import 'package:flutter/material.dart';

import '../../../../../ble/lw008.dart';
import '../../../../../ble/lw008_device_session.dart';
import '../../../../../ble/lw008_param_helpers.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/common_confirm_dialog.dart';
import '../../../../../ui/widgets/device_detail/bottom_picker_dialog.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../../../../viewmodels/ble_scan_view_model.dart';
import '../device/export_data_page.dart';
import '../device/indicator_settings_page.dart';
import '../device/system_info_page.dart';
import '../device_detail_utils.dart';

class DeviceTab extends StatefulWidget {
  const DeviceTab({super.key, required this.session});

  final Lw008DeviceSession session;

  @override
  State<DeviceTab> createState() => DeviceTabState();
}

class DeviceTabState extends State<DeviceTab> {
  int _timeZoneIndex = 40;
  bool _shutdownPayload = false;
  bool _lowPowerPayload = false;

  Future<void> reload({bool showOverlay = true}) async {
    await runWithBleLoading(
      context,
      () async {
        final api = widget.session.protocol;
        final results = await Future.wait([
          api.readTimeZone(),
          api.readShutdownPayloadEnable(),
          api.readLowPowerPayloadEnable(),
        ]);
        if (!mounted) return;
        setState(() {
          _timeZoneIndex = Lw008ParamHelpers.timeZoneIndexFromBytes(results[0].data);
          _shutdownPayload = Lw008ParamHelpers.uint8(results[1].data) == 1;
          _lowPowerPayload = Lw008ParamHelpers.uint8(results[2].data) == 1;
        });
      },
      showOverlay: showOverlay,
    );
  }

  Future<void> _pickTimeZone() async {
    final zones = Lw008OptionLists.timeZones();
    final index = await showBottomPicker(
      context: context,
      options: zones,
      selectedIndex: _timeZoneIndex,
    );
    if (index == null || !mounted) return;
    setState(() => _timeZoneIndex = index);
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      await api.writeTimeZone(Lw008ParamHelpers.timeZoneBytesFromIndex(index));
      await reload(showOverlay: false);
    });
  }

  Future<void> _toggleShutdownPayload(bool value) async {
    setState(() => _shutdownPayload = value);
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final ok = await api.writeShutdownPayloadEnable([value ? 1 : 0]);
      if (!mounted) return;
      if (!ok) {
        setState(() => _shutdownPayload = !value);
        return;
      }
      await reload(showOverlay: false);
    });
  }

  Future<void> _toggleLowPowerPayload(bool value) async {
    setState(() => _lowPowerPayload = value);
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final ok = await api.writeLowPowerPayloadEnable([value ? 1 : 0]);
      if (!mounted) return;
      if (!ok) {
        setState(() => _lowPowerPayload = !value);
        return;
      }
      await reload(showOverlay: false);
    });
  }

  Future<void> _factoryReset() async {
    final ok = await showCommonConfirmDialog(
      context: context,
      title: 'Factory Reset!',
      message: 'After factory reset,all the data will be reseted to the factory values.',
      confirmText: 'OK',
      showCancel: false,
      actionColor: BleScanViewModel.titleBarColor,
    );
    if (!ok || !mounted) return;
    await runWithBleLoading(context, () => widget.session.protocol.writeResetEmpty());
  }

  Future<void> _powerOff() async {
    final ok = await showCommonConfirmDialog(
      context: context,
      title: 'Warning!',
      message:
          'Are you sure to turn off the device? Please make sure the device has a button to turn on!',
      cancelText: 'Cancel',
      confirmText: 'OK',
      actionColor: BleScanViewModel.titleBarColor,
    );
    if (!ok || !mounted) return;
    await runWithBleLoading(context, () => widget.session.protocol.writeCloseEmpty());
  }

  @override
  Widget build(BuildContext context) {
    final zones = Lw008OptionLists.timeZones();
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        SettingsCard(
          child: SettingsNavRow(
            title: 'Local Data Sync',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExportDataPage(session: widget.session),
              ),
            ),
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'Indicator Settings',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => IndicatorSettingsPage(session: widget.session),
              ),
            ),
          ),
        ),
        SettingsCard(
          child: SettingsLabelRow(
            label: 'Current Time Zone',
            child: BlueValueButton(
              text: zones[_timeZoneIndex.clamp(0, zones.length - 1)],
              onTap: _pickTimeZone,
            ),
          ),
        ),
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsSwitchRow(
                label: 'Shutdown Payload',
                value: _shutdownPayload,
                onChanged: _toggleShutdownPayload,
              ),
              const SettingsDivider(),
              SettingsSwitchRow(
                label: 'Low-power Payload',
                value: _lowPowerPayload,
                onChanged: _toggleLowPowerPayload,
              ),
            ],
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'Device Information',
            onTap: () async {
              final result = await Navigator.of(context).push<SystemInfoDfuResult>(
                MaterialPageRoute(
                  builder: (_) => SystemInfoPage(session: widget.session),
                ),
              );
              if (!context.mounted) return;
              if (result == SystemInfoDfuResult.success ||
                  result == SystemInfoDfuResult.failed) {
                Navigator.of(context).pop(true);
              }
            },
          ),
        ),
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsNavRow(
                title: 'Factory Reset',
                onTap: _factoryReset,
              ),
              const SettingsDivider(),
              SettingsSwitchRow(
                label: 'Power Off',
                value: false,
                onChanged: (_) => _powerOff(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
