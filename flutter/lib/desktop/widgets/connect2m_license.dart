// connect2m licensing: a license key per technician PC, validated with
// Lemon Squeezy. Copyright © 2026 Abdallah Zreik. Licensed under the GNU
// AGPL-3.0.
//
// The Technician app asks for a license key on first run and activates it
// against the seller's Lemon Squeezy store. Lemon Squeezy caps how many PCs a
// key can activate, so one purchase covers the number of PCs the product
// allows. The key and its activation are remembered locally, so the app opens
// straight away afterwards; when online it re-checks the key so a refunded or
// disabled key stops working.
//
// Licensing is off unless the app was built with a store and product id
// (see consts.dart). Then every build is free to run.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher_string.dart';

const _kKey = 'connect2m-license-key';
const _kInstance = 'connect2m-license-instance';
const _kOk = 'connect2m-license-ok';
const _base = 'https://api.lemonsqueezy.com/v1/licenses';

bool _storedOk() {
  try {
    return bind.mainGetLocalOption(key: _kOk) == 'Y';
  } catch (_) {
    return false;
  }
}

/// The Technician app needs a license when licensing is built in and no valid
/// key is stored yet. The Client edition (incoming only) is never gated.
bool connect2mNeedsLicense() {
  if (!kLicensingEnabled) return false;
  if (bind.isIncomingOnly()) return false;
  return !_storedOk();
}

Future<void> _save(String key, String instanceId) async {
  await bind.mainSetLocalOption(key: _kKey, value: key);
  await bind.mainSetLocalOption(key: _kInstance, value: instanceId);
  await bind.mainSetLocalOption(key: _kOk, value: 'Y');
}

bool _metaMatches(Map body) {
  final meta = body['meta'];
  if (meta is! Map) return false;
  final store = '${meta['store_id']}';
  final product = '${meta['product_id']}';
  return store == kLicenseStoreId && product == kLicenseProductId;
}

/// Activates a key. Returns null on success, or a message to show the user.
Future<String?> activateLicense(String key) async {
  key = key.trim();
  if (key.isEmpty) return 'Enter your license key.';
  String instanceName = 'connect2m';
  try {
    instanceName = Platform.localHostname;
  } catch (_) {}
  try {
    final resp = await http
        .post(Uri.parse('$_base/activate'),
            headers: {'Accept': 'application/json'},
            body: {'license_key': key, 'instance_name': instanceName})
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(resp.body);
    if (body is! Map) return 'Unexpected response from the licensing server.';
    if (body['activated'] == true) {
      if (!_metaMatches(body)) {
        return 'This key is for a different product.';
      }
      final instance = body['instance'];
      final id = (instance is Map ? instance['id'] : null)?.toString() ?? '';
      await _save(key, id);
      return null;
    }
    final err = body['error'];
    return err is String && err.isNotEmpty
        ? err
        : 'That key could not be activated.';
  } on SocketException {
    return 'No internet connection. Activation needs internet once.';
  } catch (e) {
    return 'Could not reach the licensing server. Please try again.';
  }
}

/// Re-checks a stored key when online. A key that the server reports invalid
/// is cleared, so the app asks for a key again next time. Network problems are
/// ignored, so the app keeps working offline.
Future<void> revalidateLicense() async {
  if (!kLicensingEnabled || bind.isIncomingOnly() || !_storedOk()) return;
  try {
    final key = bind.mainGetLocalOption(key: _kKey);
    final instance = bind.mainGetLocalOption(key: _kInstance);
    if (key.isEmpty) return;
    final resp = await http
        .post(Uri.parse('$_base/validate'),
            headers: {'Accept': 'application/json'},
            body: {'license_key': key, 'instance_id': instance})
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(resp.body);
    if (body is Map && body['valid'] == false) {
      await bind.mainSetLocalOption(key: _kOk, value: '');
    }
  } catch (_) {
    // Offline or server error: keep the current state.
  }
}

/// Full-window screen shown instead of the home page until a key is activated.
class Connect2mLicenseGate extends StatefulWidget {
  final VoidCallback onActivated;
  const Connect2mLicenseGate({Key? key, required this.onActivated})
      : super(key: key);

  @override
  State<Connect2mLicenseGate> createState() => _Connect2mLicenseGateState();
}

class _Connect2mLicenseGateState extends State<Connect2mLicenseGate> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _activate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await activateLicense(_controller.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      widget.onActivated();
    } else {
      setState(() => _error = err);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasBuy = !kLicenseBuyUrl.startsWith('__') && kLicenseBuyUrl.isNotEmpty;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 60, child: loadLogo()),
                const SizedBox(height: 22),
                Text('Activate connect2m',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text(
                  'Enter the license key from your purchase. One key activates connect2m on this computer.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  enabled: !_busy,
                  onSubmitted: (_) => _busy ? null : _activate(),
                  decoration: InputDecoration(
                    labelText: 'License key',
                    hintText: 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX',
                    border: const OutlineInputBorder(),
                    errorText: _error,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _activate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Activate'),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (hasBuy)
                  TextButton(
                    onPressed: () => launchUrlString(kLicenseBuyUrl),
                    child: const Text("Don't have a key? Buy connect2m"),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
