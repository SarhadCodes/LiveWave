import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_theme.dart';
import '../../models/device_activation.dart';
import '../../services/firestore_service.dart';

class AdminDevicesTab extends StatefulWidget {
  const AdminDevicesTab({super.key});

  @override
  AdminDevicesTabState createState() => AdminDevicesTabState();
}

class AdminDevicesTabState extends State<AdminDevicesTab> {
  final _firestore = FirestoreService();
  List<DeviceActivation> _devices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void openAddDialog() => _showDeviceDialog();

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _firestore.getAllDeviceActivations();
    if (mounted) {
      setState(() {
        _devices = data;
        _loading = false;
      });
    }
  }

  void _showDeviceDialog({DeviceActivation? existing}) {
    final macController = TextEditingController(text: existing?.macAddress ?? '');
    final m3uController = TextEditingController(text: existing?.m3uUrl ?? '');
    final labelController = TextEditingController(text: existing?.label ?? '');
    var selectedPlan = existing?.planEnum ?? ActivationPlan.month1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            existing == null ? 'Activate Device' : 'Edit Device',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(macController, 'MAC Address', enabled: existing == null),
                _field(labelController, 'Label (optional)'),
                _field(m3uController, 'M3U URL'),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Subscription duration',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ActivationPlan.values.map((plan) {
                    final selected = selectedPlan == plan;
                    return ChoiceChip(
                      label: Text(plan.label),
                      selected: selected,
                      onSelected: (_) => setDialogState(() => selectedPlan = plan),
                      selectedColor: AppTheme.primaryColor,
                      labelStyle: TextStyle(
                        color: selected ? Colors.black : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      backgroundColor: Colors.white10,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final mac = macController.text.trim();
                final m3u = m3uController.text.trim();
                if (mac.isEmpty) {
                  _snack('Enter MAC address');
                  return;
                }
                if (m3u.isEmpty) {
                  _snack('Enter M3U URL');
                  return;
                }
                try {
                  await _firestore.activateDevice(
                    mac: mac,
                    m3uUrl: m3u,
                    plan: selectedPlan,
                    label: labelController.text.trim().isEmpty
                        ? null
                        : labelController.text.trim(),
                  );
                  if (mounted) Navigator.pop(context);
                  _load();
                } catch (e) {
                  _snack('Save failed: $e');
                }
              },
              child: const Text('ACTIVATE'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _extendPlan(DeviceActivation device) async {
    var selectedPlan = device.planEnum ?? ActivationPlan.month1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text('Extend Subscription', style: TextStyle(color: Colors.white)),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ActivationPlan.values.map((plan) {
              final selected = selectedPlan == plan;
              return ChoiceChip(
                label: Text(plan.label),
                selected: selected,
                onSelected: (_) => setDialogState(() => selectedPlan = plan),
                selectedColor: AppTheme.primaryColor,
              );
            }).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('EXTEND'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _firestore.extendDevicePlan(mac: device.macAddress, plan: selectedPlan);
    _load();
  }

  Widget _field(TextEditingController c, String label, {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        enabled: enabled,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.primaryColor),
          ),
        ),
      ),
    );
  }

  Color _statusColor(DeviceActivation d) {
    if (d.isUsable) return Colors.green;
    if (d.status == 'expired' || d.isExpired) return Colors.red;
    return Colors.orange;
  }

  String _statusLabel(DeviceActivation d) {
    if (d.isUsable) return 'ACTIVE';
    if (d.status == 'expired' || d.isExpired) return 'EXPIRED';
    return 'PENDING';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.devices_other_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text(
              'No devices registered yet',
              style: TextStyle(color: Colors.white.withOpacity(0.4)),
            ),
            const SizedBox(height: 8),
            Text(
              'Devices appear here when users install the app',
              style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12),
            ),
          ],
        ),
      );
    }

    final dateFmt = DateFormat('MMM d, yyyy HH:mm');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      itemCount: _devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final d = _devices[index];
        final statusColor = _statusColor(d);
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.35)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              d.label?.isNotEmpty == true ? d.label! : d.macAddress,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('MAC: ${d.macAddress}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                if (d.platform?.isNotEmpty == true)
                  Text('Platform: ${d.platform}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                if (d.planEnum != null)
                  Text('Plan: ${d.planEnum!.label}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                if (d.expiresAt != null)
                  Text(
                    'Expires: ${dateFmt.format(d.expiresAt!)}',
                    style: TextStyle(
                      color: d.isExpired ? Colors.red.shade300 : Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                if (d.lastSeenAt != null)
                  Text('Last seen: ${dateFmt.format(d.lastSeenAt!)}', style: const TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white54),
              color: AppTheme.surfaceColor,
              onSelected: (value) async {
                switch (value) {
                  case 'edit':
                    _showDeviceDialog(existing: d);
                    break;
                  case 'extend':
                    await _extendPlan(d);
                    break;
                  case 'deactivate':
                    await _firestore.deactivateDevice(d.macAddress);
                    _load();
                    break;
                  case 'delete':
                    await _firestore.deleteDeviceActivation(d.id);
                    _load();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit / Activate')),
                const PopupMenuItem(value: 'extend', child: Text('Extend plan')),
                const PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  _statusLabel(d),
                  style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade800),
    );
  }
}
