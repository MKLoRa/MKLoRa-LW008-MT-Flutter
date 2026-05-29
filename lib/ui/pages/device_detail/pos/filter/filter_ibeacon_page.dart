import 'package:flutter/material.dart';

import '../../../../../../ble/lw008_device_session.dart';
import '../../../../../../ble/lw008_param_helpers.dart';
import '../../../../../../ble/lw008_protocol_named_api.dart';
import '../../../../../../ui/theme/device_detail_theme.dart';
import '../../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../device_detail_utils.dart';

class FilterIbeaconPage extends StatefulWidget {
  const FilterIbeaconPage({super.key, required this.session});
  final Lw008DeviceSession session;

  @override
  State<FilterIbeaconPage> createState() => _FilterIbeaconPageState();
}

class _FilterIbeaconPageState extends State<FilterIbeaconPage> {
  bool _enable = false;
  final _uuid = TextEditingController();
  final _majorMin = TextEditingController();
  final _majorMax = TextEditingController();
  final _minorMin = TextEditingController();
  final _minorMax = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _applyRangeFields(List<int> data, TextEditingController minC, TextEditingController maxC) {
    final range = Lw008ParamHelpers.parseFilterRange(data);
    if (range.enabled) {
      minC.text = range.min.toString();
      maxC.text = range.max.toString();
    } else {
      minC.clear();
      maxC.clear();
    }
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final results = await Future.wait([
        api.readFilterIbeaconEnable(),
        api.readFilterIbeaconUuid(),
        api.readFilterIbeaconMajorRange(),
        api.readFilterIbeaconMinorRange(),
      ]);
      if (!mounted) return;
      _enable = Lw008ParamHelpers.uint8(results[0].data) == 1;
      _uuid.text = Lw008ParamHelpers.bytesToHex(results[1].data);
      _applyRangeFields(results[2].data, _majorMin, _majorMax);
      _applyRangeFields(results[3].data, _minorMin, _minorMax);
      setState(() {});
    });
  }

  bool _validateRange(TextEditingController minC, TextEditingController maxC) {
    final minStr = minC.text.trim();
    final maxStr = maxC.text.trim();
    if (minStr.isEmpty && maxStr.isEmpty) return true;
    if (minStr.isEmpty || maxStr.isEmpty) return false;
    final min = int.tryParse(minStr);
    final max = int.tryParse(maxStr);
    if (min == null || max == null || min > 65535 || max > 65535 || max < min) return false;
    return true;
  }

  bool _validate() {
    final uuid = _uuid.text.trim();
    if (uuid.isNotEmpty && uuid.length % 2 != 0) return false;
    return _validateRange(_majorMin, _majorMax) && _validateRange(_minorMin, _minorMax);
  }

  List<int> _majorRangePayload() {
    final minStr = _majorMin.text.trim();
    final maxStr = _majorMax.text.trim();
    if (minStr.isEmpty && maxStr.isEmpty) {
      return Lw008ParamHelpers.filterRangeWrite(enable: 0);
    }
    return Lw008ParamHelpers.filterRangeWrite(
      enable: 1,
      min: int.parse(minStr),
      max: int.parse(maxStr),
    );
  }

  List<int> _minorRangePayload() {
    final minStr = _minorMin.text.trim();
    final maxStr = _minorMax.text.trim();
    if (minStr.isEmpty && maxStr.isEmpty) {
      return Lw008ParamHelpers.filterRangeWrite(enable: 0);
    }
    return Lw008ParamHelpers.filterRangeWrite(
      enable: 1,
      min: int.parse(minStr),
      max: int.parse(maxStr),
    );
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
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final ok = (await Future.wait([
        api.writeFilterIbeaconUuid(Lw008ParamHelpers.hexToBytes(_uuid.text.trim())),
        api.writeFilterIbeaconMajorRange(_majorRangePayload()),
        api.writeFilterIbeaconMinorRange(_minorRangePayload()),
        api.writeFilterIbeaconEnable([_enable ? 1 : 0]),
      ])).every((r) => r);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  Widget _rangeRow({
    required String label,
    required TextEditingController minC,
    required TextEditingController maxC,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: DeviceDetailTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text(
              'Min',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: DeviceDetailTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SettingsTextField(controller: minC, hint: '0~65535'),
            ),
            const SizedBox(width: 12),
            const Text(
              '~ Max',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: DeviceDetailTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SettingsTextField(controller: maxC, hint: '0~65535'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _uuid.dispose();
    _majorMin.dispose();
    _majorMax.dispose();
    _minorMin.dispose();
    _minorMax.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Filter by Raw Data',
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
                  label: 'iBeacon',
                  value: _enable,
                  onChanged: (v) => setState(() => _enable = v),
                ),
                const SettingsDivider(),
                const Text(
                  'iBeacon UUID',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: DeviceDetailTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                SettingsHexField(
                  controller: _uuid,
                  hint: '0~16 Bytes',
                  maxLength: 32,
                ),
                const SettingsDivider(),
                _rangeRow(
                  label: 'iBeacon Major',
                  minC: _majorMin,
                  maxC: _majorMax,
                ),
                const SettingsDivider(),
                _rangeRow(
                  label: 'iBeacon Minor',
                  minC: _minorMin,
                  maxC: _minorMax,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
