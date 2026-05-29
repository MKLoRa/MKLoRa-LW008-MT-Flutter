import 'package:flutter/material.dart';

import '../../../../../ble/lw008.dart';
import '../../../../../ble/lw008_device_session.dart';
import '../../../../../ble/lw008_param_helpers.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/device_detail/bottom_picker_dialog.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../device_detail_utils.dart';

class PosWifiFixPage extends StatefulWidget {
  const PosWifiFixPage({super.key, required this.session});
  final Lw008DeviceSession session;

  @override
  State<PosWifiFixPage> createState() => _PosWifiFixPageState();
}

class _PosWifiFixPageState extends State<PosWifiFixPage> {
  final _timeout = TextEditingController();
  final _bssidNumber = TextEditingController();
  int _dataTypeIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final results = await Future.wait([
        api.readWifiPosTimeout(),
        api.readWifiPosBssidNumber(),
        api.readWifiPosDataType(),
      ]);
      if (!mounted) return;
      _timeout.text = Lw008ParamHelpers.uint8(results[0].data).toString();
      _bssidNumber.text = Lw008ParamHelpers.uint8(results[1].data).toString();
      _dataTypeIndex = Lw008ParamHelpers.uint8(results[2].data).clamp(0, 1);
      setState(() {});
    });
  }

  Future<void> _save() async {
    final timeout = int.tryParse(_timeout.text.trim());
    final bssidNumber = int.tryParse(_bssidNumber.text.trim());
    if (timeout == null ||
        timeout < 1 ||
        timeout > 4 ||
        bssidNumber == null ||
        bssidNumber < 1 ||
        bssidNumber > 5) {
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
        api.writeWifiPosTimeout([timeout]),
        api.writeWifiPosBssidNumber([bssidNumber]),
        api.writeWifiPosDataType([_dataTypeIndex]),
      ])).every((r) => r);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  @override
  void dispose() {
    _timeout.dispose();
    _bssidNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'WIFI Fix',
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
                    hint: '1~4',
                    suffix: 'x2.5s',
                  ),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Number Of BSSID',
                  child: SettingsTextField(
                    controller: _bssidNumber,
                    hint: '1~5',
                  ),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'WIFI Data Type',
                  child: BlueValueButton(
                    text: Lw008OptionLists.wifiDataTypes[_dataTypeIndex],
                    onTap: () async {
                      final index = await showBottomPicker(
                        context: context,
                        options: Lw008OptionLists.wifiDataTypes,
                        selectedIndex: _dataTypeIndex,
                      );
                      if (index != null) setState(() => _dataTypeIndex = index);
                    },
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
