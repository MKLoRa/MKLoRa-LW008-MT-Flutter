import 'package:flutter/material.dart';

import '../../../../../../ble/lw008_device_session.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import 'auxiliary/active_state_count_page.dart';
import 'auxiliary/downlink_for_pos_page.dart';
import 'auxiliary/man_down_detection_page.dart';
import 'auxiliary/vibration_detection_page.dart';

class AuxiliaryOperationPage extends StatelessWidget {
  const AuxiliaryOperationPage({super.key, required this.session});
  final Lw008DeviceSession session;

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Auxiliary Operation',
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(child: SettingsNavRow(title: 'Downlink for Position', onTap: () => push(context, DownlinkForPosPage(session: session)))),
          SettingsCard(child: SettingsNavRow(title: 'Shock Detection', onTap: () => push(context, VibrationDetectionPage(session: session)))),
          SettingsCard(child: SettingsNavRow(title: 'Man Down Detection', onTap: () => push(context, ManDownDetectionPage(session: session)))),
          SettingsCard(child: SettingsNavRow(title: 'Active State Count', onTap: () => push(context, ActiveStateCountPage(session: session)))),
        ],
      ),
    );
  }

  void push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}
