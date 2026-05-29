import 'package:flutter/material.dart';

import '../../../../../ble/lw008_data_codec.dart';
import '../../../../../ble/lw008_device_session.dart';
import '../../../../../ble/lw008_option_lists.dart';
import '../../../../../ble/lw008_param_helpers.dart';
import '../../../../../ble/lw008_protocol_named_api.dart';
import '../../../../../ui/theme/device_detail_theme.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/common_confirm_dialog.dart';
import '../../../../../ui/widgets/device_detail/bottom_picker_dialog.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../../../../viewmodels/ble_scan_view_model.dart';
import '../device_detail_utils.dart';

class SelfTestPage extends StatefulWidget {
  const SelfTestPage({super.key, required this.session});
  final Lw008DeviceSession session;

  @override
  State<SelfTestPage> createState() => _SelfTestPageState();
}

class _SelfTestPageState extends State<SelfTestPage> {
  bool _selftestOk = true;
  bool _gpsFail = false;
  bool _axisFail = false;
  bool _flashFail = false;
  int _pcbaStatus = 0;
  Map<String, int>? _batteryInfo;
  bool _useBatteryConditions = true;

  int _condition1ThresholdIndex = 0;
  int _condition2ThresholdIndex = 0;
  final _condition1MinInterval = TextEditingController();
  final _condition1SampleTimes = TextEditingController();
  final _condition2MinInterval = TextEditingController();
  final _condition2SampleTimes = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final gatt = widget.session.deviceInfoApi;
      final firmware = await gatt.readFirmwareRevision();
      final useBatteryConditions =
          Lw008OptionLists.isFirmwareAtLeast(firmware.isEmpty ? 'V1.1.0' : firmware, 'V1.0.9');

      if (useBatteryConditions) {
        final results = await Future.wait([
          api.readSelftestStatus(),
          api.readPcbaStatus(),
          api.readCondition1VoltageThreshold(),
          api.readCondition1MinSampleInterval(),
          api.readCondition1SampleTimes(),
          api.readCondition2VoltageThreshold(),
          api.readCondition2MinSampleInterval(),
          api.readCondition2SampleTimes(),
        ]);
        if (!mounted) return;
        final selftest = Lw008DataCodec.decodeSelftestStatus(
          Lw008ParamHelpers.uint8(results[0].data),
        );
        setState(() {
          _useBatteryConditions = true;
          _selftestOk = selftest['ok']!;
          _gpsFail = selftest['gpsFail']!;
          _axisFail = selftest['axisFail']!;
          _flashFail = selftest['flashFail']!;
          _pcbaStatus = Lw008ParamHelpers.uint8(results[1].data);
          _condition1ThresholdIndex = Lw008OptionLists.voltageThresholdPickerIndex(
            Lw008ParamHelpers.uint8(results[2].data),
          );
          _condition1MinInterval.text =
              Lw008ParamHelpers.uint16(results[3].data).toString();
          _condition1SampleTimes.text =
              Lw008ParamHelpers.uint8(results[4].data).toString();
          _condition2ThresholdIndex = Lw008OptionLists.voltageThresholdPickerIndex(
            Lw008ParamHelpers.uint8(results[5].data),
          );
          _condition2MinInterval.text =
              Lw008ParamHelpers.uint16(results[6].data).toString();
          _condition2SampleTimes.text =
              Lw008ParamHelpers.uint8(results[7].data).toString();
        });
        return;
      }

      final results = await Future.wait([
        api.readSelftestStatus(),
        api.readPcbaStatus(),
        api.readBatteryInfo(),
      ]);
      if (!mounted) return;
      final selftest = Lw008DataCodec.decodeSelftestStatus(
        Lw008ParamHelpers.uint8(results[0].data),
      );
      setState(() {
        _useBatteryConditions = false;
        _selftestOk = selftest['ok']!;
        _gpsFail = selftest['gpsFail']!;
        _axisFail = selftest['axisFail']!;
        _flashFail = selftest['flashFail']!;
        _pcbaStatus = Lw008ParamHelpers.uint8(results[1].data);
        _batteryInfo = Lw008DataCodec.decodeBatteryInfo(results[2].data);
      });
    });
  }

  bool _validateConditions() {
    final c1Interval = int.tryParse(_condition1MinInterval.text.trim());
    final c1Times = int.tryParse(_condition1SampleTimes.text.trim());
    final c2Interval = int.tryParse(_condition2MinInterval.text.trim());
    final c2Times = int.tryParse(_condition2SampleTimes.text.trim());
    if (c1Interval == null || c1Interval < 1 || c1Interval > 1440) return false;
    if (c1Times == null || c1Times < 1 || c1Times > 100) return false;
    if (c2Interval == null || c2Interval < 1 || c2Interval > 1440) return false;
    if (c2Times == null || c2Times < 1 || c2Times > 100) return false;
    return true;
  }

  Future<void> _saveConditions() async {
    if (!_validateConditions()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Para error!')),
        );
      }
      return;
    }
    final c1Interval = int.parse(_condition1MinInterval.text.trim());
    final c1Times = int.parse(_condition1SampleTimes.text.trim());
    final c2Interval = int.parse(_condition2MinInterval.text.trim());
    final c2Times = int.parse(_condition2SampleTimes.text.trim());
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final ok = (await Future.wait([
        api.writeCondition1VoltageThreshold([
          Lw008OptionLists.voltageThresholdDeviceValue(_condition1ThresholdIndex),
        ]),
        api.writeCondition1MinSampleInterval(Lw008ParamHelpers.uint16Bytes(c1Interval)),
        api.writeCondition1SampleTimes([c1Times]),
        api.writeCondition2VoltageThreshold([
          Lw008OptionLists.voltageThresholdDeviceValue(_condition2ThresholdIndex),
        ]),
        api.writeCondition2MinSampleInterval(Lw008ParamHelpers.uint16Bytes(c2Interval)),
        api.writeCondition2SampleTimes([c2Times]),
      ])).every((r) => r);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  Future<void> _pickThreshold({
    required int selectedIndex,
    required ValueChanged<int> onSelected,
  }) async {
    final options = Lw008OptionLists.voltageThresholdOptions();
    final index = await showBottomPicker(
      context: context,
      options: options,
      selectedIndex: selectedIndex,
    );
    if (index != null) onSelected(index);
  }

  Future<void> _showResetSuccess() {
    return showCommonConfirmDialog(
      context: context,
      message: 'Reset Successfully！',
      confirmText: 'OK',
      actionColor: BleScanViewModel.titleBarColor,
      barrierDismissible: false,
      showCancel: false,
    );
  }

  Future<void> _batteryReset() async {
    final ok = await showCommonConfirmDialog(
      context: context,
      title: 'Warning！',
      message: 'Are you sure to reset battery?',
      actionColor: BleScanViewModel.titleBarColor,
    );
    if (!ok || !mounted) return;
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final writeOk = await api.writeBatteryResetEmpty();
      if (!writeOk) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Opps！Save failed. Please check the input characters and try again.',
              ),
            ),
          );
        }
        return;
      }
      final result = await api.readBatteryInfo();
      if (!mounted) return;
      setState(() => _batteryInfo = Lw008DataCodec.decodeBatteryInfo(result.data));
      await _showResetSuccess();
    });
  }

  Widget _batteryLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: DeviceDetailTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _conditionSection({
    required String thresholdLabel,
    required int thresholdIndex,
    required ValueChanged<int> onThresholdChanged,
    required TextEditingController minInterval,
    required TextEditingController sampleTimes,
  }) {
    final options = Lw008OptionLists.voltageThresholdOptions();
    return SettingsCard(
      child: Column(
        children: [
          SettingsLabelRow(
            label: thresholdLabel,
            child: BlueValueButton(
              text: '${options[thresholdIndex]}V',
              onTap: () => _pickThreshold(
                selectedIndex: thresholdIndex,
                onSelected: (index) {
                  setState(() => onThresholdChanged(index));
                },
              ),
            ),
          ),
          const SettingsDivider(),
          SettingsLabelRow(
            label: 'Min. Sample Interval',
            child: SettingsTextField(
              controller: minInterval,
              hint: '1~1440',
              maxLength: 4,
              suffix: 'Mins',
            ),
          ),
          const SettingsDivider(),
          SettingsLabelRow(
            label: 'Sample Times',
            child: SettingsTextField(
              controller: sampleTimes,
              hint: '1~100',
              maxLength: 3,
              suffix: 'Times',
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _condition1MinInterval.dispose();
    _condition1SampleTimes.dispose();
    _condition2MinInterval.dispose();
    _condition2SampleTimes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final battery = _batteryInfo;
    return DetailScaffold(
      title: 'Selftest Interface',
      showSave: _useBatteryConditions,
      onSave: _saveConditions,
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Selftest Status:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: DeviceDetailTheme.textPrimary,
                      ),
                    ),
                    if (_selftestOk) ...[
                      const SizedBox(width: 20),
                      const Text(
                        '0',
                        style: TextStyle(
                          fontSize: 15,
                          color: DeviceDetailTheme.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (!_selftestOk) ...[
                  if (_gpsFail)
                    const Padding(
                      padding: EdgeInsets.only(left: 20, top: 4),
                      child: Text(
                        '1',
                        style: TextStyle(
                          fontSize: 15,
                          color: DeviceDetailTheme.textPrimary,
                        ),
                      ),
                    ),
                  if (_axisFail)
                    const Padding(
                      padding: EdgeInsets.only(left: 20, top: 4),
                      child: Text(
                        '2',
                        style: TextStyle(
                          fontSize: 15,
                          color: DeviceDetailTheme.textPrimary,
                        ),
                      ),
                    ),
                  if (_flashFail)
                    const Padding(
                      padding: EdgeInsets.only(left: 20, top: 4),
                      child: Text(
                        '3',
                        style: TextStyle(
                          fontSize: 15,
                          color: DeviceDetailTheme.textPrimary,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          SettingsCard(
            child: Row(
              children: [
                const Text(
                  'PCBA Status:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: DeviceDetailTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  '$_pcbaStatus',
                  style: const TextStyle(
                    fontSize: 15,
                    color: DeviceDetailTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (_useBatteryConditions) ...[
            _conditionSection(
              thresholdLabel: 'Condition 1 Voltage Threshold',
              thresholdIndex: _condition1ThresholdIndex,
              onThresholdChanged: (index) => _condition1ThresholdIndex = index,
              minInterval: _condition1MinInterval,
              sampleTimes: _condition1SampleTimes,
            ),
            _conditionSection(
              thresholdLabel: 'Condition 2 Voltage Threshold',
              thresholdIndex: _condition2ThresholdIndex,
              onThresholdChanged: (index) => _condition2ThresholdIndex = index,
              minInterval: _condition2MinInterval,
              sampleTimes: _condition2SampleTimes,
            ),
          ] else ...[
            SettingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Battery information:',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: DeviceDetailTheme.textPrimary,
                    ),
                  ),
                  if (battery != null) ...[
                    _batteryLine('${battery['runtime']} s'),
                    _batteryLine('${battery['advTimes']} times'),
                    _batteryLine('${battery['flashTimes']} times'),
                    _batteryLine('${battery['axisDuration']} ms'),
                    _batteryLine('${battery['bleFixDuration']} ms'),
                    _batteryLine('${battery['wifiFixDuration']} ms'),
                    _batteryLine('${battery['gpsFixDuration']} s'),
                    _batteryLine('${battery['loraTransmissionTimes']} times'),
                    _batteryLine('${battery['loraPower']} mAS'),
                  ],
                ],
              ),
            ),
            SettingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsLabelRow(
                    label: 'Battery Reset',
                    child: BlueValueButton(
                      text: 'Reset',
                      minWidth: 70,
                      onTap: _batteryReset,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '*After replace with the new battery, need to click "Reset", otherwise the low power prompt will be unnormal.',
                    style: TextStyle(
                      fontSize: 12,
                      color: DeviceDetailTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
