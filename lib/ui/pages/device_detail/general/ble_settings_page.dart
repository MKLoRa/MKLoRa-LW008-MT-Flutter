import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:lw008_flutter/ble/lw008_device_session.dart';
import 'package:lw008_flutter/ble/lw008_option_lists.dart';
import 'package:lw008_flutter/ble/lw008_param_helpers.dart';
import 'package:lw008_flutter/ble/lw008_protocol_named_api.dart';
import 'package:lw008_flutter/ui/theme/device_detail_theme.dart';
import 'package:lw008_flutter/ui/widgets/ble_change_password_dialog.dart';
import 'package:lw008_flutter/ui/widgets/ble_loading_overlay.dart';
import 'package:lw008_flutter/ui/widgets/device_detail/settings_widgets.dart';

import '../device_detail_utils.dart';

class BleSettingsPage extends StatefulWidget {
  const BleSettingsPage({super.key, required this.session});
  final Lw008DeviceSession session;

  @override
  State<BleSettingsPage> createState() => _BleSettingsPageState();
}

class _BleSettingsPageState extends State<BleSettingsPage> {
  final _advName = TextEditingController();
  final _timeout = TextEditingController();
  bool _passwordVerify = false;
  bool _passwordVerifyOnDevice = false;
  int _txPowerIndex = 6;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final results = await Future.wait([
        api.readAdvName(),
        api.readAdvTxPower(),
        api.readAdvTimeout(),
        api.readPasswordVerifyEnable(),
      ]);
      if (!mounted) return;
      _advName.text = Lw008ParamHelpers.bytesToString(results[0].data);
      final txPower = Lw008ParamHelpers.byte0(results[1].data);
      _txPowerIndex = Lw008OptionLists.txPowerLevels.indexOf(txPower);
      if (_txPowerIndex < 0) _txPowerIndex = 6;
      _timeout.text = Lw008ParamHelpers.uint8(results[2].data).toString();
      _passwordVerify = Lw008ParamHelpers.uint8(results[3].data) == 1;
      _passwordVerifyOnDevice = _passwordVerify;
      setState(() {});
    });
  }

  bool _validate() {
    final timeout = int.tryParse(_timeout.text.trim());
    return timeout != null && timeout >= 1 && timeout <= 60;
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
        api.writeAdvName(utf8.encode(_advName.text)),
        api.writeAdvTimeout([int.parse(_timeout.text.trim())]),
        api.writeAdvTxPower([Lw008OptionLists.txPowerLevels[_txPowerIndex]]),
        api.writePasswordVerifyEnable([_passwordVerify ? 1 : 0]),
      ])).every((r) => r);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  Future<void> _changePassword() async {
    if (!_passwordVerifyOnDevice && !_passwordVerify) {
      return;
    }
    final password = await showBleChangePasswordDialog(context: context);
    if (password == null || !mounted) return;
    await runWithBleLoading(context, () async {
      final ok = await widget.session.protocol.changePassword(utf8.encode(password));
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  @override
  void dispose() {
    _advName.dispose();
    _timeout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txPower = Lw008OptionLists.txPowerLevels[_txPowerIndex];
    return DetailScaffold(
      title: 'BLE Settings',
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
                  label: 'ADV Name',
                  child: Expanded(
                    child: TextField(
                      controller: _advName,
                      maxLength: 16,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[ -~]')),
                      ],
                      decoration: const InputDecoration(
                        hintText: '0 ~ 16Characters',
                        counterText: '',
                        border: UnderlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SettingsDivider(),
                const Text(
                  'Tx Power',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: DeviceDetailTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  Lw008OptionLists.txPowerRangeHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: DeviceDetailTheme.textSecondary,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _txPowerIndex.toDouble(),
                        min: 0,
                        max: (Lw008OptionLists.txPowerLevels.length - 1).toDouble(),
                        activeColor: DeviceDetailTheme.primary,
                        onChanged: (v) => setState(() => _txPowerIndex = v.round()),
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        '${txPower}dBm',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: DeviceDetailTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Broadcast Timeout',
                  child: SettingsTextField(
                    controller: _timeout,
                    hint: '1~60',
                    suffix: 'Mins',
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
                SettingsSwitchRow(
                  label: 'Login Password',
                  value: _passwordVerify,
                  onChanged: (v) => setState(() => _passwordVerify = v),
                ),
                if (_passwordVerify) ...[
                  const SettingsDivider(),
                  SettingsNavRow(
                    title: 'Change Password',
                    onTap: _changePassword,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
