import 'package:flutter/material.dart';

import '../../../../../ble/lw008.dart';
import '../../../../../ble/lw008_device_session.dart';
import '../../../../../ble/lw008_param_helpers.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../device_detail_utils.dart';

class PosGpsL76CFixPage extends StatefulWidget {
  const PosGpsL76CFixPage({super.key, required this.session});
  final Lw008DeviceSession session;
  @override
  State<PosGpsL76CFixPage> createState() => _PosGpsL76CFixPageState();
}

class _PosGpsL76CFixPageState extends State<PosGpsL76CFixPage> {
  final _timeout = TextEditingController();
  final _pdop = TextEditingController();
  bool _extremeMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final results = await Future.wait([
        api.readGpsPosTimeoutL76C(),
        api.readGpsPdopLimitL76C(),
        api.readGpsExtremeModeL76C(),
      ]);
      if (!mounted) return;
      _timeout.text = Lw008ParamHelpers.uint16(results[0].data).toString();
      _pdop.text = Lw008ParamHelpers.uint8(results[1].data).toString();
      _extremeMode = Lw008ParamHelpers.uint8(results[2].data) == 1;
      setState(() {});
    });
  }

  Future<void> _save() async {
    final timeout = int.tryParse(_timeout.text.trim());
    final pdop = int.tryParse(_pdop.text.trim());
    if (timeout == null ||
        timeout < 60 ||
        timeout > 600 ||
        pdop == null ||
        pdop < 25 ||
        pdop > 100) {
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
        api.writeGpsPosTimeoutL76C(Lw008ParamHelpers.uint16Bytes(timeout)),
        api.writeGpsPdopLimitL76C(Lw008ParamHelpers.single(pdop)),
        api.writeGpsExtremeModeL76C([_extremeMode ? 1 : 0]),
      ])).every((r) => r);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  @override
  void dispose() {
    _timeout.dispose();
    _pdop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'GPS Fix',
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
                    hint: '60~600',
                    suffix: 's',
                  ),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'PDOP',
                  child: SettingsTextField(
                    controller: _pdop,
                    hint: '25~100',
                    suffix: 'x0.1',
                  ),
                ),
                const SettingsDivider(),
                SettingsSwitchRow(
                  label: 'Extreme Mode',
                  value: _extremeMode,
                  onChanged: (value) => setState(() => _extremeMode = value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
