import 'package:flutter/material.dart';

import '../services/hospital_catalog_cache.dart';
import '../utils/api_config.dart';
import 'auth/signin_auth_theme.dart';

class ServerSelector extends StatefulWidget {
  const ServerSelector({super.key});

  @override
  State<ServerSelector> createState() => _ServerSelectorState();
}

class _ServerSelectorState extends State<ServerSelector> {
  late final TextEditingController _emr;
  late final TextEditingController _auth;

  @override
  void initState() {
    super.initState();
    _emr = TextEditingController(text: ApiConfig.customEmr);
    _auth = TextEditingController(text: ApiConfig.customAuth);
    ApiConfig.selectedIdNotifier.addListener(_onChanged);
  }

  @override
  void dispose() {
    ApiConfig.selectedIdNotifier.removeListener(_onChanged);
    _emr.dispose();
    _auth.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _select(int index) async {
    final servers = ApiConfig.servers;
    if (index < 0 || index >= servers.length) return;
    await ApiConfig.select(servers[index].id);
    HospitalCatalogCache.instance.clear();
    if (mounted) setState(() {});
  }

  Future<void> _saveCustom() async {
    await ApiConfig.saveCustom(emr: _emr.text, auth: _auth.text);
    HospitalCatalogCache.instance.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.hasMultipleServers) return const SizedBox.shrink();

    final servers = ApiConfig.servers;
    final index = servers
        .indexWhere((s) => s.id == ApiConfig.selectedIdNotifier.value)
        .clamp(0, servers.length - 1);
    final current = servers[index];
    final max = servers.length - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          current.label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: SignInAuthTheme.textMuted,
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            showValueIndicator: ShowValueIndicator.never,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            activeTrackColor: SignInAuthTheme.primary.withValues(alpha: 0.7),
            inactiveTrackColor: SignInAuthTheme.primary.withValues(alpha: 0.15),
            thumbColor: SignInAuthTheme.primary,
          ),
          child: Slider(
            value: index.toDouble(),
            min: 0,
            max: max.toDouble(),
            divisions: max > 0 ? max : null,
            onChanged: (v) => _select(v.round()),
          ),
        ),
        if (current.isCustom) ...[
          TextField(
            controller: _emr,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'HMIS URL',
              hintText: 'https://10.0.2.2:7287',
            ),
            onSubmitted: (_) => _saveCustom(),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _auth,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Auth URL',
              hintText: 'http://10.0.2.2:5045',
            ),
            onSubmitted: (_) => _saveCustom(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _saveCustom,
              child: const Text('Save URLs'),
            ),
          ),
        ],
      ],
    );
  }
}

class HiddenServerGate extends StatelessWidget {
  const HiddenServerGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.canSwitchBackend) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: ApiConfig.unlockedNotifier,
      builder: (_, unlocked, __) {
        if (!unlocked) return const SizedBox.shrink();
        return const Padding(
          padding: EdgeInsets.only(top: 8),
          child: ServerSelector(),
        );
      },
    );
  }
}
