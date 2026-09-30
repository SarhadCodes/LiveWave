import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/telegram_ingest_service.dart';

class AdminTelegramTab extends StatefulWidget {
  const AdminTelegramTab({super.key});

  @override
  State<AdminTelegramTab> createState() => _AdminTelegramTabState();
}

class _AdminTelegramTabState extends State<AdminTelegramTab> {
  final _baseUrl = TextEditingController();
  final _token = TextEditingController();
  Map<String, dynamic>? _status;
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;
  String _filter = 'review';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    await TelegramIngestService.load();
    _baseUrl.text = TelegramIngestService.baseUrl;
    _token.text = TelegramIngestService.adminToken;
    await _refresh();
  }

  Future<void> _saveConnection() async {
    await TelegramIngestService.saveConnection(baseUrl: _baseUrl.text, token: _token.text);
    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await TelegramIngestService.status();
      Map<String, dynamic> list;
      if (_filter == 'review') {
        list = await TelegramIngestService.reviewQueue();
      } else {
        list = await TelegramIngestService.imports(statusFilter: _filter == 'all' ? null : _filter);
      }
      if (!mounted) return;
      setState(() {
        _status = status;
        _items = (list['items'] as List?) ?? const [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action, String ok) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok), backgroundColor: Colors.green.shade800));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade800));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = (_status?['settings'] as Map?)?.cast<String, dynamic>() ?? {};
    final counts = (_status?['counts'] as Map?)?.cast<String, dynamic>() ?? {};
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _connectionCard(),
          const SizedBox(height: 12),
          _controls(settings, counts),
          const SizedBox(height: 12),
          _filters(),
          const SizedBox(height: 12),
          if (_loading) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          if (!_loading)
            ..._items.map((raw) => _itemCard(Map<String, dynamic>.from(raw as Map))),
          if (!_loading && _items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No Telegram imports in this queue.', style: TextStyle(color: Colors.white38), textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  Widget _connectionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('INGEST API', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 12),
          TextField(
            controller: _baseUrl,
            style: const TextStyle(color: Colors.white),
            decoration: _dec('Backend URL (https://your-vps:8787)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _token,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: _dec('Admin token'),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _saveConnection,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.black),
              child: const Text('SAVE & CONNECT'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls(Map<String, dynamic> settings, Map<String, dynamic> counts) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Channel: ${settings['channel'] ?? '—'}   Monitor: ${settings['monitoring'] == true ? 'ON' : 'OFF'}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'Published ${counts['published'] ?? 0} · Review ${counts['review'] ?? 0} · Pending ${counts['pending'] ?? 0} · Rejected ${counts['rejected'] ?? 0}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _btn('Start Import', () => _run(() => TelegramIngestService.startMonitor(), 'Monitoring started')),
              _btn('Stop Import', () => _run(() => TelegramIngestService.stopMonitor(), 'Monitoring stopped')),
              _btn('Last 10', () => _run(() => TelegramIngestService.importLimit(10), 'Imported last 10')),
              _btn('Last 50', () => _run(() => TelegramIngestService.importLimit(50), 'Imported last 50')),
              _btn('Last 100', () => _run(() => TelegramIngestService.importLimit(100), 'Imported last 100')),
              _btn('Reprocess Failed', () => _run(() => TelegramIngestService.reprocessFailed(), 'Reprocessed failed')),
              _btn('Reprocess All', () => _run(() => TelegramIngestService.reprocessAll(), 'Reprocessed all')),
              _btn('Review Queue', () {
                setState(() => _filter = 'review');
                return _refresh();
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    Widget chip(String id, String label) {
      final on = _filter == id;
      return ChoiceChip(
        label: Text(label),
        selected: on,
        onSelected: (_) {
          setState(() => _filter = id);
          _refresh();
        },
        selectedColor: AppTheme.primaryColor,
        labelStyle: TextStyle(color: on ? Colors.black : Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
        backgroundColor: Colors.white10,
      );
    }

    return Wrap(
      spacing: 8,
      children: [
        chip('review', 'Review'),
        chip('pending', 'Pending'),
        chip('published', 'Published'),
        chip('rejected', 'Rejected'),
        chip('all', 'All'),
      ],
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final poster = (item['posterUrl'] ?? '').toString();
    final absPoster = poster.startsWith('http')
        ? poster
        : (poster.isEmpty || TelegramIngestService.baseUrl.isEmpty)
            ? ''
            : '${TelegramIngestService.baseUrl}$poster';
    final confidence = (item['confidence'] is num) ? (item['confidence'] as num).toDouble() : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: absPoster.isEmpty
                    ? Container(width: 72, height: 96, color: Colors.white10, child: const Icon(Icons.movie, color: Colors.white24))
                    : CachedNetworkImage(imageUrl: absPoster, width: 72, height: 96, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['title']?.toString() ?? 'Untitled', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${item['year'] ?? '—'} · ${(item['genres'] as List?)?.join(', ') ?? ''} · ${item['language'] ?? ''}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    Text(
                      'Rating ${item['rating'] ?? '—'}  Quality ${item['quality'] ?? '—'}  ${(confidence * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                    ),
                    Text('TG ${item['telegramMessageId']} · ${item['status']}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          if ((item['originalCaption'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(item['originalCaption'].toString(), maxLines: 6, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _btn('Approve', () => _run(() => TelegramIngestService.approve(item['id'] as int), 'Approved')),
              _btn('Edit', () => _edit(item)),
              _btn('Reject', () => _run(() => TelegramIngestService.reject(item['id'] as int), 'Rejected')),
              _btn('Reprocess', () => _run(() => TelegramIngestService.reprocess(item['id'] as int), 'Reprocessed')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final title = TextEditingController(text: item['title']?.toString() ?? '');
    final year = TextEditingController(text: item['year']?.toString() ?? '');
    final genres = TextEditingController(text: ((item['genres'] as List?) ?? const []).join(', '));
    final language = TextEditingController(text: item['language']?.toString() ?? '');
    final rating = TextEditingController(text: item['rating']?.toString() ?? '');
    final quality = TextEditingController(text: item['quality']?.toString() ?? '');
    final description = TextEditingController(text: item['description']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Edit import', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, style: const TextStyle(color: Colors.white), decoration: _dec('Title')),
              TextField(controller: year, style: const TextStyle(color: Colors.white), decoration: _dec('Year'), keyboardType: TextInputType.number),
              TextField(controller: genres, style: const TextStyle(color: Colors.white), decoration: _dec('Genres (comma separated)')),
              TextField(controller: language, style: const TextStyle(color: Colors.white), decoration: _dec('Language')),
              TextField(controller: rating, style: const TextStyle(color: Colors.white), decoration: _dec('Rating')),
              TextField(controller: quality, style: const TextStyle(color: Colors.white), decoration: _dec('Quality')),
              TextField(controller: description, style: const TextStyle(color: Colors.white), decoration: _dec('Description'), maxLines: 4),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.black),
            child: const Text('SAVE & APPROVE'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => TelegramIngestService.approve(item['id'] as int, {
        'title': title.text.trim(),
        'year': int.tryParse(year.text.trim()),
        'genres': genres.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'language': language.text.trim(),
        'rating': double.tryParse(rating.text.trim()),
        'quality': quality.text.trim(),
        'description': description.text.trim(),
      }),
      'Saved correction',
    );
  }

  Widget _btn(String label, Future<void> Function() onTap) {
    return OutlinedButton(
      onPressed: () => onTap(),
      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
