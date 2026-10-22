// connect2m simple home screen.
// Copyright © 2026 Abdallah Zreik. Licensed under the GNU AGPL-3.0, like the
// rest of connect2m (based on RustDesk).
//
// A focused screen for people receiving support: it shows only what they need
// to read out to their support agent (ID and one-time password) plus the
// service status. Technicians can switch to the full view with one click.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/animated_rotation_widget.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

const String kOptionConnect2mSimpleMode = 'connect2m-simple-mode';

bool connect2mSimpleModeEnabled() =>
    bind.mainGetLocalOption(key: kOptionConnect2mSimpleMode) != 'N';

Future<void> setConnect2mSimpleMode(bool enabled) => bind.mainSetLocalOption(
    key: kOptionConnect2mSimpleMode, value: enabled ? '' : 'N');

class Connect2mSimpleHome extends StatelessWidget {
  final VoidCallback onShowFullView;
  // Install, permission and error cards from the full home page, so the
  // simple view never hides something the user must act on.
  final Widget? helpCards;

  const Connect2mSimpleHome(
      {Key? key, required this.onShowFullView, this.helpCards})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color?.withOpacity(0.75);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ChangeNotifierProvider.value(
              value: gFFI.serverModel,
              child: Consumer<ServerModel>(
                builder: (context, model, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: loadLogo()),
                    const SizedBox(height: 20),
                    Text(
                      'Get remote help',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Give the ID and password below to your support agent. '
                      'Only share them with someone you trust.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 20),
                    _InfoCard(
                      label: translate('ID'),
                      value: model.serverId.text,
                      valueStyle: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2),
                    ),
                    const SizedBox(height: 12),
                    _buildPasswordCard(context, model),
                    const SizedBox(height: 12),
                    if (helpCards != null) helpCards!,
                    const OnlineStatusWidget(),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: onShowFullView,
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          label: const Text('Connect to another computer'),
                        ),
                        if (!bind.isDisableSettings())
                          TextButton.icon(
                            onPressed: () => DesktopTabPage.onAddSetting(),
                            icon: const Icon(Icons.settings_outlined, size: 18),
                            label: Text(translate('Settings')),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordCard(BuildContext context, ServerModel model) {
    // Same rule as the full home page: a one-time password is only meaningful
    // when the user has not chosen click-to-approve or permanent-password only.
    final showOneTime = model.approveMode != 'click' &&
        model.verificationMethod != kUsePermanentPassword;
    if (!showOneTime) {
      return _InfoCard(
        label: translate('One-time Password'),
        value: '',
        hint: 'When your agent connects, a window will ask you to accept. '
            'Click "Accept" only if you are expecting them.',
      );
    }
    return _InfoCard(
      label: translate('One-time Password'),
      value: model.serverPasswd.text,
      valueStyle: const TextStyle(fontSize: 24, letterSpacing: 1.5),
      extraAction: AnimatedRotationWidget(
        onPressed: () => bind.mainUpdateTemporaryPassword(),
        child: Tooltip(
          message: translate('Refresh Password'),
          child: const Icon(Icons.refresh, size: 22),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  final String? hint;
  final Widget? extraAction;

  const _InfoCard({
    required this.label,
    required this.value,
    this.valueStyle,
    this.hint,
    this.extraAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = theme.textTheme.titleLarge?.color?.withOpacity(0.55);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MyTheme.accent.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 13, color: labelColor)),
                const SizedBox(height: 4),
                if (value.isNotEmpty)
                  SelectableText(value, style: valueStyle),
                if (hint != null)
                  Text(hint!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (extraAction != null) extraAction!.marginOnly(right: 4),
          if (value.isNotEmpty)
            IconButton(
              tooltip: translate('Copy'),
              icon: const Icon(Icons.copy_rounded, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                showToast(translate('Copied'));
              },
            ),
        ],
      ),
    );
  }
}
