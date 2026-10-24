// connect2m home screen parts.
// Copyright © 2026 Abdallah Zreik. Licensed under the GNU AGPL-3.0.

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/dialog.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Technician edition: rename this computer's ID (e.g. "Abdallah-PC").
Widget connect2mChangeIdButton(BuildContext context) {
  final color = Theme.of(context).textTheme.titleLarge?.color;
  return Tooltip(
    message: translate('Change ID'),
    child: InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: changeIdDialog,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(Icons.edit_outlined,
            size: 18, color: color?.withOpacity(0.55)),
      ),
    ),
  );
}

/// Client edition: the password is fixed by IT, so it is never shown or
/// editable here; only the ID needs to be read out.
Widget connect2mClientPasswordBoard(BuildContext context) {
  final textColor = Theme.of(context).textTheme.titleLarge?.color;
  return Container(
    margin: const EdgeInsets.only(left: 20.0, right: 16, top: 13, bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 2,
          height: 52,
          decoration: const BoxDecoration(color: MyTheme.accent),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(translate('Password'),
                    style: TextStyle(
                        fontSize: 14, color: textColor?.withOpacity(0.5))),
                const SizedBox(height: 6),
                const Text('••••••••',
                    style: TextStyle(fontSize: 18, letterSpacing: 2)),
                const SizedBox(height: 4),
                Text('Set by your IT team',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _showAbout(context),
                  child: Text('About connect2m',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          decoration: TextDecoration.underline,
                          fontSize: 10)),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

void _showAbout(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('connect2m'),
      content: SelectableText(
          '$kConnect2mCopyright\n$kConnect2mUpstreamNotice\n\n$kConnect2mSourceUrl'),
      actions: [
        TextButton(
          onPressed: () => launchUrlString(kConnect2mSourceUrl),
          child: const Text('Source code'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(translate('OK')),
        ),
      ],
    ),
  );
}
