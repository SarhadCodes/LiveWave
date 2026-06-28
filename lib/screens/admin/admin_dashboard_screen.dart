import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../services/firestore_service.dart';
import '../../config/app_theme.dart';
import '../../widgets/channel_logo.dart';
import 'admin_devices_tab.dart';

/// Admin panel tab modes
enum _AdminTab { movies, tvShows, channels, devices }

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _firestoreService = FirestoreService();
  final _devicesTabKey = GlobalKey<AdminDevicesTabState>();
  _AdminTab _activeTab = _AdminTab.movies;

  // Media overrides state
  List<Map<String, dynamic>> _overrides = [];
  // Channel state
  List<Map<String, dynamic>> _channels = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    if (_activeTab == _AdminTab.channels) {
      final data = await _firestoreService.getAllChannels();
      setState(() { _channels = data; _isLoading = false; });
    } else if (_activeTab == _AdminTab.devices) {
      setState(() => _isLoading = false);
    } else {
      final data = await _firestoreService.getAllOverrides(isMovie: _activeTab == _AdminTab.movies);
      setState(() { _overrides = data; _isLoading = false; });
    }
  }

  // ─── Media Override Dialog ──────────────────────────────────────────────────

  void _showOverrideDialog({Map<String, dynamic>? existing}) {
    final titleController = TextEditingController(text: existing?['title'] ?? '');
    final idController    = TextEditingController(text: existing?['tmdbId']?.toString() ?? '');
    final mp4Controller   = TextEditingController(text: existing?['mp4'] ?? '');
    final srtController   = TextEditingController(text: existing?['srt'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          existing == null ? 'Add Override' : 'Edit Override',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField(titleController, 'Title (for reference)'),
              _buildField(idController, 'TMDB ID', keyboard: TextInputType.number),
              _buildField(mp4Controller, 'MP4 URL (use {S} {E} for TV template)'),
              _buildField(srtController, 'SRT Subtitle URL (template)'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.black),
            onPressed: () async {
              final id = int.tryParse(idController.text.trim());
              if (id == null) { _showSnack('Enter a valid TMDB ID'); return; }
              await _firestoreService.saveMediaOverride(id, {
                'title': titleController.text.trim(),
                'mp4': mp4Controller.text.trim(),
                'srt': srtController.text.trim(),
              }, isMovie: _activeTab == _AdminTab.movies);
              if (mounted) Navigator.pop(context);
              _loadData();
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  // ─── Channel Dialog ─────────────────────────────────────────────────────────

  // ─── Pick & Compress Logo from Device ────────────────────────────────────

  Future<String?> _pickAndCompressLogo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      if (picked == null) return null;

      // Read the picked file bytes
      final fileBytes = await picked.readAsBytes();

      // Compress further with flutter_image_compress for smaller size
      Uint8List compressed;
      try {
        final result = await FlutterImageCompress.compressWithList(
          fileBytes,
          minWidth: 256,
          minHeight: 256,
          quality: 60,
          format: CompressFormat.jpeg,
        );
        compressed = result;
      } catch (_) {
        // Fallback: use the image_picker output directly
        compressed = fileBytes;
      }

      // Encode as base64 data URI
      final b64 = base64Encode(compressed);
      return 'data:image/jpeg;base64,$b64';
    } catch (e) {
      debugPrint('Logo pick error: $e');
      return null;
    }
  }

  void _showChannelDialog({Map<String, dynamic>? existing}) {
    final nameController     = TextEditingController(text: existing?['name'] ?? '');
    final streamController   = TextEditingController(text: existing?['stream'] ?? '');
    final logoController     = TextEditingController(text: existing?['logo'] ?? '');
    final categoryController = TextEditingController(text: existing?['category'] ?? '');
    final kCategoryController= TextEditingController(text: existing?['Kcategory'] ?? '');
    final orderController    = TextEditingController(text: existing?['order']?.toString() ?? '');
    bool isActive = existing?['isActive'] ?? true;
    bool isLive   = existing?['isLive'] ?? true;
    bool isUploadingLogo = false;
    final existingId = existing?['docId']?.toString();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            existing == null ? 'Add Channel' : 'Edit Channel',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(nameController, 'Channel Name *'),
                _buildField(streamController, 'Stream URL (M3U8 / MP4) *'),

                // ── Logo Upload Section ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo URL text field + upload button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: logoController,
                              style: const TextStyle(color: Colors.white),
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Logo URL or tap upload →',
                                labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white30)),
                                // Show a clear button if there's content
                                suffixIcon: logoController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                                        onPressed: () => setDialogState(() => logoController.clear()),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Upload from device button
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: Material(
                              color: AppTheme.primaryColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: isUploadingLogo
                                    ? null
                                    : () async {
                                        setDialogState(() => isUploadingLogo = true);
                                        final dataUri = await _pickAndCompressLogo();
                                        if (dataUri != null) {
                                          logoController.text = dataUri;
                                        }
                                        setDialogState(() => isUploadingLogo = false);
                                      },
                                child: isUploadingLogo
                                    ? const Padding(
                                        padding: EdgeInsets.all(14),
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                                      )
                                    : const Icon(Icons.photo_library_rounded, color: AppTheme.primaryColor, size: 24),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Logo preview
                      if (logoController.text.trim().isNotEmpty)
                        Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: ChannelLogo(
                                logo: logoController.text.trim(),
                                width: 80,
                                height: 80,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                _buildField(categoryController, 'Category EN (e.g. Sports, Kids)'),
                _buildField(kCategoryController, 'Kcategory (Kurdish, e.g. وەرزش)'),
                _buildField(orderController, 'Order / Sort Number', keyboard: TextInputType.number),
                const SizedBox(height: 8),
                // isActive toggle
                Row(
                  children: [
                    const Text('Active', style: TextStyle(color: Colors.white70)),
                    const Spacer(),
                    Switch(
                      value: isActive,
                      activeColor: Colors.green,
                      onChanged: (v) => setDialogState(() => isActive = v),
                    ),
                  ],
                ),
                // isLive toggle
                Row(
                  children: [
                    const Text('Live (show LIVE badge)', style: TextStyle(color: Colors.white70)),
                    const Spacer(),
                    Switch(
                      value: isLive,
                      activeColor: AppTheme.accentRed,
                      onChanged: (v) => setDialogState(() => isLive = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
            StatefulBuilder(
              builder: (context, setSaveState) {
                bool isSaving = false;
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.black),
                  onPressed: isSaving ? null : () async {
                    if (nameController.text.trim().isEmpty || streamController.text.trim().isEmpty) {
                      _showSnack('Name and Stream URL are required');
                      return;
                    }
                    setSaveState(() => isSaving = true);
                    final success = await _firestoreService.saveChannel({
                      'name':      nameController.text.trim(),
                      'stream':    streamController.text.trim(),
                      'logo':      logoController.text.trim(),
                      'category':  categoryController.text.trim().isEmpty ? 'General' : categoryController.text.trim(),
                      'Kcategory': kCategoryController.text.trim(),
                      'order':     int.tryParse(orderController.text.trim()) ?? 999,
                      'isActive':  isActive,
                      'isLive':    isLive,
                    }, existingId: existingId);

                    if (success) {
                      if (mounted) Navigator.pop(context);
                      _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✓ Channel saved!'), backgroundColor: Colors.green),
                      );
                    } else {
                      setSaveState(() => isSaving = false);
                      _showSnack('❌ Save failed — check Firestore rules or your connection');
                    }
                  },
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('SAVE'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('ADMIN PANEL', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 18)),
        actions: [IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: Column(
        children: [
          // ── Tab Toggle ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _buildTab('🎬 MOVIES', _AdminTab.movies),
                const SizedBox(width: 8),
                _buildTab('📺 TV SHOWS', _AdminTab.tvShows),
                const SizedBox(width: 8),
                _buildTab('📡 CHANNELS', _AdminTab.channels),
                const SizedBox(width: 8),
                _buildTab('📱 DEVICES', _AdminTab.devices),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Content ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _activeTab == _AdminTab.channels
                    ? _buildChannelList()
                    : _activeTab == _AdminTab.devices
                        ? AdminDevicesTab(key: _devicesTabKey)
                        : _buildOverrideList(),
          ),
        ],
      ),
      floatingActionButton: _activeTab == _AdminTab.devices
          ? FloatingActionButton.extended(
              onPressed: () => _devicesTabKey.currentState?.openAddDialog(),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text('ADD DEVICE', style: TextStyle(fontWeight: FontWeight.w900)),
            )
          : FloatingActionButton.extended(
        onPressed: () => _activeTab == _AdminTab.channels
            ? _showChannelDialog()
            : _showOverrideDialog(),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: Text(_activeTab == _AdminTab.channels ? 'ADD CHANNEL' : 'ADD OVERRIDE',
            style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }

  // ─── Override List ──────────────────────────────────────────────────────────

  Widget _buildOverrideList() {
    if (_overrides.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 12),
            const Text('No overrides yet', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _overrides.length,
      itemBuilder: (context, index) {
        final item = _overrides[index];
        return _buildOverrideCard(item);
      },
    );
  }

  Widget _buildOverrideCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.link_rounded, color: AppTheme.primaryColor, size: 20),
        ),
        title: Text(item['title'] ?? 'Unknown',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${item['tmdbId']}', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
            if ((item['mp4'] ?? '').toString().isNotEmpty)
              Text('MP4: ${item['mp4']}', style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_rounded, color: Colors.white60, size: 20), onPressed: () => _showOverrideDialog(existing: item)),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
              onPressed: () => _confirmDelete(
                title: 'Delete Override?',
                onConfirm: () async {
                  await _firestoreService.deleteMediaOverride(item['tmdbId'], isMovie: _activeTab == _AdminTab.movies);
                  _loadData();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Channel List ───────────────────────────────────────────────────────────

  Widget _buildChannelList() {
    if (_channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.live_tv_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 12),
            const Text('No channels yet.\nTap + to add your first channel.',
                style: TextStyle(color: Colors.white38), textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _channels.length,
      itemBuilder: (context, index) {
        final ch = _channels[index];
        return _buildChannelCard(ch);
      },
    );
  }

  Widget _buildChannelCard(Map<String, dynamic> ch) {
    final logoUrl  = ch['logo']?.toString() ?? '';
    final category = ch['category']?.toString() ?? 'General';
    final categoryColor = AppTheme.getCategoryColor(category);
    final isActive = ch['isActive'] as bool? ?? true;
    final isLive   = ch['isLive'] as bool? ?? false;
    final order    = ch['order']?.toString() ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.surfaceColor : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActive ? Colors.white10 : Colors.red.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: logoUrl.isNotEmpty
                  ? ChannelLogo(
                      logo: logoUrl,
                      width: 48, height: 48, fit: BoxFit.cover,
                      fallback: _logoFallback(category, categoryColor),
                    )
                  : _logoFallback(category, categoryColor),
            ),
            if (isLive)
              Positioned(
                top: -4, right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: AppTheme.accentRed, borderRadius: BorderRadius.circular(4)),
                  child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(child: Text(ch['name'] ?? 'Unnamed', style: TextStyle(color: isActive ? Colors.white : Colors.white38, fontWeight: FontWeight.bold))),
            if (!isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: const Text('OFF', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4, right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: categoryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text(category, style: TextStyle(color: categoryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                Text('#$order', style: const TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 4),
            Text(ch['stream'] ?? ch['url'] ?? '',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.white60, size: 20),
              onPressed: () => _showChannelDialog(existing: ch),
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
              onPressed: () => _confirmDelete(
                title: 'Delete "${ch['name']}"?',
                onConfirm: () async {
                  await _firestoreService.deleteChannel(ch['docId']);
                  _loadData();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoFallback(String category, Color color) {
    return Container(
      width: 48, height: 48,
      color: color.withOpacity(0.15),
      child: Icon(Icons.live_tv_rounded, color: color, size: 24),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildTab(String label, _AdminTab tab) {
    final active = _activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () { setState(() => _activeTab = tab); _loadData(); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppTheme.primaryColor : Colors.white10,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                  color: active ? Colors.black : Colors.white60,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                )),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white12)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white30)),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade800));
  }

  Future<void> _confirmDelete({required String title, required VoidCallback onConfirm}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirm == true) onConfirm();
  }
}
