import 'package:flutter/material.dart';

import '../../../../../ble/lw008.dart';
import '../../../../../ble/lw008_device_session.dart';
import '../../../../../ble/lw008_param_helpers.dart';
import '../../../../../ble/lw008_protocol_named_api.dart';
import '../../../../../ui/theme/device_detail_theme.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/device_detail/bottom_picker_dialog.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../device_detail_utils.dart';
import 'filter/filter_adv_name_page.dart';
import 'filter/filter_mac_page.dart';
import 'filter/filter_raw_data_page.dart';

class PosBleFixPage extends StatefulWidget {
  const PosBleFixPage({super.key, required this.session});
  final Lw008DeviceSession session;
  @override
  State<PosBleFixPage> createState() => _PosBleFixPageState();
}

class _PosBleFixPageState extends State<PosBleFixPage> {
  final _timeout = TextEditingController();
  final _macNumber = TextEditingController();
  int _mechanismIndex = 0;
  int _scanningTypeIndex = 0;
  int _relationshipIndex = 0;
  double _rssi = -127;

  static String rssiFilterTip(int rssi) =>
      '*The device will uplink valid ADV data with RSSI no less than ${rssi}dBm.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final results = await Future.wait([
        api.readBlePosTimeout(),
        api.readBlePosMacNumber(),
        api.readBlePosMechanism(),
        api.readFilterRssi(),
        api.readFilterBleScanPhy(),
        api.readFilterRelationship(),
      ]);
      if (!mounted) return;
      _timeout.text = Lw008ParamHelpers.uint8(results[0].data).toString();
      _macNumber.text = Lw008ParamHelpers.uint8(results[1].data).toString();
      _mechanismIndex = Lw008ParamHelpers.uint8(results[2].data).clamp(0, 1);
      _rssi = Lw008ParamHelpers.byte0(results[3].data, defaultValue: -127).toDouble();
      _scanningTypeIndex =
          Lw008ParamHelpers.uint8(results[4].data).clamp(0, Lw008OptionLists.bleScanPhyTypes.length - 1);
      _relationshipIndex = Lw008ParamHelpers.uint8(results[5].data).clamp(0, 6);
      setState(() {});
    });
  }

  Future<void> _save() async {
    final timeout = int.tryParse(_timeout.text.trim());
    final macNum = int.tryParse(_macNumber.text.trim());
    if (timeout == null ||
        timeout < 1 ||
        timeout > 10 ||
        macNum == null ||
        macNum < 1 ||
        macNum > 5) {
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
        api.writeBlePosTimeout([timeout]),
        api.writeBlePosMacNumber([macNum]),
        api.writeBlePosMechanism([_mechanismIndex]),
        api.writeFilterRssi([_rssi.round() & 0xFF]),
        api.writeFilterBleScanPhy([_scanningTypeIndex]),
        api.writeFilterRelationship([_relationshipIndex]),
      ])).every((r) => r);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  @override
  void dispose() {
    _timeout.dispose();
    _macNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Bluetooth Fix',
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
                  label: 'Positioning Timeout',
                  child: SettingsTextField(
                    controller: _timeout,
                    hint: '1~10',
                    suffix: 's',
                  ),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Number Of MAC',
                  child: SettingsTextField(
                    controller: _macNumber,
                    hint: '1~5',
                  ),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Bluetooth Fix Mechanism',
                  child: BlueValueButton(
                    text: Lw008OptionLists.bleFixMechanism[_mechanismIndex],
                    onTap: () async {
                      final i = await showBottomPicker(
                        context: context,
                        options: Lw008OptionLists.bleFixMechanism,
                        selectedIndex: _mechanismIndex,
                      );
                      if (i != null) setState(() => _mechanismIndex = i);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'RSSI Filter',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: DeviceDetailTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Text(
                          '(-127dBm~0dBm)',
                          style: TextStyle(
                            fontSize: 12,
                            color: DeviceDetailTheme.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_rssi.round()}dBm',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: DeviceDetailTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: (_rssi + 127).clamp(0, 127),
                      min: 0,
                      max: 127,
                      activeColor: DeviceDetailTheme.primary,
                      onChanged: (v) => setState(() => _rssi = v - 127),
                    ),
                    Text(
                      rssiFilterTip(_rssi.round()),
                      style: const TextStyle(
                        fontSize: 12,
                        color: DeviceDetailTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Scanning Type/PHY',
                  child: BlueValueButton(
                    text: Lw008OptionLists.bleScanPhyTypes[_scanningTypeIndex],
                    onTap: () async {
                      final i = await showBottomPicker(
                        context: context,
                        options: Lw008OptionLists.bleScanPhyTypes,
                        selectedIndex: _scanningTypeIndex,
                      );
                      if (i != null) setState(() => _scanningTypeIndex = i);
                    },
                  ),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Filter Relationship',
                  child: BlueValueButton(
                    text: Lw008OptionLists.filterRelationship[_relationshipIndex],
                    onTap: () async {
                      final i = await showBottomPicker(
                        context: context,
                        options: Lw008OptionLists.filterRelationship,
                        selectedIndex: _relationshipIndex,
                      );
                      if (i != null) setState(() => _relationshipIndex = i);
                    },
                  ),
                ),
                const SettingsDivider(),
                SettingsNavRow(
                  title: 'Filter by MAC',
                  onTap: () => pushDetailPage(context, FilterMacPage(session: widget.session)),
                ),
                const SettingsDivider(),
                SettingsNavRow(
                  title: 'Filter by ADV Name',
                  onTap: () => pushDetailPage(context, FilterAdvNamePage(session: widget.session)),
                ),
                const SettingsDivider(),
                SettingsNavRow(
                  title: 'Filter by Raw Data',
                  onTap: () => pushDetailPage(context, FilterRawDataPage(session: widget.session)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
