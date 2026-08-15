import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/constants.dart';

class JournalEntry {
  final String id;
  final String text;
  final String feeling;
  final List<String> photos;
  final int week;
  final String doctorName;
  final String date;
  final String createdAt;

  JournalEntry({
    required this.id,
    required this.text,
    required this.feeling,
    required this.photos,
    required this.week,
    required this.doctorName,
    required this.date,
    required this.createdAt,
  });

  bool get hasFeeling => feeling.isNotEmpty;

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      feeling: json['feeling'] ?? '',
      photos: (json['photos'] as List?)?.cast<String>() ?? [],
      week: (json['week'] as num?)?.toInt() ?? 0,
      doctorName: json['doctor_name'] ?? '',
      date: json['date'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

const _feelingChoices = [
  ('😊', 'Je me sens bien'),
  ('👶', 'Mon bébé bouge'),
  ('🦋', 'Premiers mouvements'),
  ('🌀', 'Nausées'),
  ('😴', 'Un peu fatiguée'),
  ('🤔', 'J\'ai un doute'),
  ('🩸', 'Léger saignement'),
  ('⏰', 'Contractions'),
];

class JournalScreen extends StatefulWidget {
  final String phone;
  const JournalScreen({super.key, required this.phone});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  bool _isLoading = true;
  List<JournalEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/journal/list'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data['succes'] == true) {
          final list = (data['entries'] as List? ?? []);
          setState(() {
            _entries = list.map((e) => JournalEntry.fromJson(e)).toList();
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _openNewNote() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewNoteSheet(phone: widget.phone),
    );
    if (saved == true) _loadEntries();
  }

  Future<void> _confirmDelete(JournalEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Effacer cette note ?'),
        content: const Text('Elle disparaîtra de votre journal.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFB71C1C)),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/journal/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone, 'journal_id': entry.id}),
      );
      setState(() => _entries.removeWhere((e) => e.id == entry.id));
    } catch (_) {}
  }

  void _viewPhoto(String base64) {
    final bytes = _photoBytes(base64);
    if (bytes == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _PhotoViewer(bytes: bytes),
    ));
  }

  Uint8List? _photoBytes(String base64) {
    try {
      return base64Decode(base64);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                  : _entries.isEmpty
                      ? _buildEmptyState()
                      : _buildEntries(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: _openNewNote,
        tooltip: 'Écrire une note',
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        elevation: 6,
        child: const Icon(Icons.edit_note_rounded, size: 34),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 18, bottom: 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE91E63), Color(0xFFF8BBD0)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0, left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
          Column(
            children: [
              const Text('📖', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 6),
              const Text('Mon journal',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
              const SizedBox(height: 4),
              Text('Vos pensées, en toute intimité',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📔', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('Votre journal est tout doux et vide',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D))),
            const SizedBox(height: 8),
            Text('Notez un petit moment, un ressenti,\nor une question pour votre médecin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.5)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openNewNote,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Écrire ma première note'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntries() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
      itemCount: _entries.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _buildEntryCard(_entries[i]),
      ),
    );
  }

  Widget _buildEntryCard(JournalEntry entry) {
    final bytesList = entry.photos.map(_photoBytes).whereType<Uint8List>().toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF8BBD0).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: const Color(0xFFE91E63).withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDate(entry.date),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFE91E63)),
                ),
              ),
              if (entry.week > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE91E63).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Semaine ${entry.week}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFE91E63))),
                ),
            ],
          ),
          if (entry.hasFeeling) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(entry.feeling, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _feelingLabel(entry.feeling),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D)),
                  ),
                ),
              ],
            ),
          ],
          if (entry.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              entry.text,
              style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.55),
            ),
          ],
          if (bytesList.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: bytesList.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _viewPhoto(entry.photos[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(bytesList[i], width: 92, height: 92, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (entry.doctorName.isNotEmpty)
                Text('Seul votre médecin le voit 🤍',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              const Spacer(),
              GestureDetector(
                onTap: () => _confirmDelete(entry),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: const Color(0xFFFBE9EC).withValues(alpha: 0.6), shape: BoxShape.circle),
                  child: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey[400]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _feelingLabel(String emoji) {
    for (final (e, l) in _feelingChoices) {
      if (e == emoji) return l;
    }
    return 'Ressenti';
  }

  static const _months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _NewNoteSheet extends StatefulWidget {
  final String phone;
  const _NewNoteSheet({required this.phone});

  @override
  State<_NewNoteSheet> createState() => _NewNoteSheetState();
}

class _NewNoteSheetState extends State<_NewNoteSheet> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String _feeling = '';
  final List<String> _photos = [];
  bool _saving = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      setState(() => _photos.add(base64Encode(bytes)));
    } catch (_) {}
  }

  Future<void> _save() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _feeling.isEmpty && _photos.isEmpty) return;
    setState(() => _saving = true);
    var ok = false;
    try {
      final r = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/journal/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': widget.phone,
          'text': text,
          'feeling': _feeling,
          'photos': _photos,
        }),
      );
      ok = r.statusCode == 200;
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'enregistrer pour le moment'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFDF6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 46, height: 5,
                  decoration: BoxDecoration(color: const Color(0xFFF8BBD0), borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 18),
              const Center(
                child: Text('Une petite note ?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D))),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text('C\'est votre espace. Rien n\'est obligatoire.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              ),
              const SizedBox(height: 18),
              const Text('Comment vous sentez-vous ?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D))),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _feelingChoices.map((choice) {
                  final (emoji, label) = choice;
                  final selected = _feeling == emoji;
                  return GestureDetector(
                    onTap: () => setState(() => _feeling = selected ? '' : emoji),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFFE91E63).withValues(alpha: 0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected ? const Color(0xFFE91E63) : const Color(0xFFF1E6EA),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text(label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              color: selected ? const Color(0xFFE91E63) : Colors.grey[700],
                            )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _textController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Écrivez ce que vous voulez partager (optionnel)…',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: const Color(0xFFF1E6EA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: const Color(0xFFF1E6EA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE91E63), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if (_photos.isEmpty)
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF8BBD0), width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_outlined, color: Color(0xFFE91E63), size: 20),
                        const SizedBox(width: 8),
                        Text('Ajouter une photo (optionnel)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFFE91E63))),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      if (i == _photos.length) {
                        if (_photos.length >= 3) {
                          return const SizedBox.shrink();
                        }
                        return GestureDetector(
                          onTap: _pickPhoto,
                          child: Container(
                            width: 84, height: 84,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F6),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFF8BBD0)),
                            ),
                            child: const Icon(Icons.add, color: Color(0xFFE91E63), size: 26),
                          ),
                        );
                      }
                      final base64 = _photos[i];
                      final bytes = base64Decode(base64);
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(bytes, width: 84, height: 84, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 4, right: 4,
                            child: GestureDetector(
                              onTap: () => setState(() => _photos.removeAt(i)),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.favorite_rounded, size: 20),
                  label: Text(_saving ? 'Enregistrement…' : 'Déposer ma note d\'amour'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  final Uint8List bytes;
  const _PhotoViewer({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: InteractiveViewer(
          maxScale: 4,
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}