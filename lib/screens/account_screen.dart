import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/activation_provider.dart';
import '../providers/channels_provider.dart';
import '../providers/movies_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tv_shows_provider.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final activation = Provider.of<ActivationProvider>(context, listen: false);
      await activation.ensureMacAddress();
      if (!activation.isResolved) {
        await activation.resolve(settings);
      }
    });
  }

  String _statusLabel(ActivationProvider activation) {
    if (activation.isActive) return 'Active';
    if (activation.isExpired) return 'Expired';
    if (activation.isError) return 'Error';
    return 'Pending';
  }

  Color _statusColor(ActivationProvider activation) {
    if (activation.isActive) return Colors.green;
    if (activation.isExpired) return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final dateFmt = DateFormat('MMM d, yyyy • HH:mm');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'ACCOUNT',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
      ),
      body: Consumer<ActivationProvider>(
        builder: (context, activation, _) {
          final status = _statusLabel(activation);
          final statusColor = _statusColor(activation);
          final expires = activation.expiresAt;
          final isRealMac = RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$')
              .hasMatch(activation.macAddress);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _StatusCard(
                status: status,
                color: statusColor,
                subtitle: activation.isActive
                    ? 'Your IPTV subscription is active'
                    : activation.isExpired
                        ? 'Subscription ended — default channels are shown'
                        : 'Waiting for admin to activate this device',
              ),
              const SizedBox(height: 16),
              _InfoTile(
                icon: Icons.fingerprint_rounded,
                label: isRealMac ? 'MAC Address' : 'Device ID',
                value: activation.isMacLoading
                    ? 'Loading...'
                    : (activation.macAddress.isNotEmpty
                        ? activation.macAddress
                        : 'Unavailable'),
                onCopy: activation.macAddress.isNotEmpty
                    ? () {
                        Clipboard.setData(
                          ClipboardData(text: activation.macAddress),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard')),
                        );
                      }
                    : null,
              ),
              if (!isRealMac && activation.macAddress.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                  child: Text(
                    'This device hides its hardware MAC. Send this Device ID to your admin instead.',
                    style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              _InfoTile(
                icon: Icons.event_rounded,
                label: 'Expires',
                value: expires != null ? dateFmt.format(expires) : '—',
              ),
              const SizedBox(height: 12),
              _InfoTile(
                icon: Icons.calendar_month_rounded,
                label: 'Plan',
                value: activation.planLabel ?? '—',
              ),
              const SizedBox(height: 28),
              if (activation.isPending || activation.isExpired)
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _refreshActivation(context, settings, activation),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('REFRESH STATUS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (activation.message != null && activation.message!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  activation.message!,
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _refreshActivation(
    BuildContext context,
    SettingsProvider settings,
    ActivationProvider activation,
  ) async {
    await activation.recheck(settings);
    if (!context.mounted) return;

    final channels = Provider.of<ChannelsProvider>(context, listen: false);
    final movies = Provider.of<MoviesProvider>(context, listen: false);
    final tvShows = Provider.of<TvShowsProvider>(context, listen: false);
    channels.setContentSource(settings.contentSource);
    movies.setContentSource(settings.contentSource);
    tvShows.setContentSource(settings.contentSource);
    await channels.fetchChannels();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activation.isActive
                ? 'Account activated — IPTV loaded'
                : activation.isPending
                    ? 'Still waiting for activation'
                    : 'Showing default channels',
          ),
          backgroundColor: AppTheme.surfaceColor,
        ),
      );
    }
  }
}

class _StatusCard extends StatelessWidget {
  final String status;
  final Color color;
  final String subtitle;

  const _StatusCard({
    required this.status,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, color: Colors.white54, size: 20),
              tooltip: 'Copy',
            ),
        ],
      ),
    );
  }
}
