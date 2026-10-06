import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/contact_store.dart';
import '../services/email_service.dart';
import '../services/gemini_service.dart';
import '../services/profile_store.dart';
import '../services/search_service.dart';
import '../widgets/api_key_dialog.dart';
import '../widgets/email_result_dialog.dart';
import '../widgets/index_builder_dialog.dart';
import '../widgets/profile_dialog.dart';
import '../utils/professor_utils.dart';

enum StatusFilter { all, notContacted, emailed, replied, noEmail }

enum _DraftStatus { queued, generating, ready, failed }

class _DraftEntry {
  final Map<String, dynamic> professor;
  _DraftStatus status;
  EmailDraft? draft;
  String? error;

  _DraftEntry(this.professor, this.status);
}

const List<String> quickCountries = [
  'China',
  'USA',
  'UK',
  'Australia',
  'Canada',
  'Germany',
  'Hong Kong',
  'Singapore',
  'South Korea',
  'Japan',
  'New Zealand',
];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const int maxParallel = 4;

  UserProfile profile =
  const UserProfile(name: defaultName, text: defaultProfile);

  final searchController = TextEditingController();
  String searchText = '';
  List<Map<String, dynamic>> results = [];
  bool searching = false;
  bool hitLimit = false;
  String? searchError;
  int searchId = 0;
  Timer? debounce;

  Map<String, ContactInfo> contacts = {};
  StatusFilter statusFilter = StatusFilter.all;
  bool favoritesFirst = true;

  final Map<String, _DraftEntry> drafts = {};
  final List<String> queue = [];
  int running = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadKey();
    _loadContacts();
    _runSearch('');
  }

  @override
  void dispose() {
    debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final p = await ProfileStore.load();
    if (!mounted) return;
    setState(() => profile = p);
  }

  Future<void> _loadKey() async {
    final k = await ProfileStore.loadGeminiKey();
    if (!mounted) return;
    setState(() => GeminiService.runtimeKey = k);
  }

  Future<void> _loadContacts() async {
    final c = await ContactStore.load();
    if (!mounted) return;
    setState(() => contacts = c);
  }

  Future<void> _openProfile() async {
    final p = await showProfileDialog(context, profile);
    if (p != null && mounted) setState(() => profile = p);
  }

  Future<void> _openApiKey() async {
    await showApiKeyDialog(context);
    if (mounted) setState(() {});
  }

  Future<void> _runSearch(String raw) async {
    final id = ++searchId;
    setState(() {
      searching = true;
      searchError = null;
    });
    try {
      final outcome = await SearchService.search(raw);
      if (!mounted || id != searchId) return;
      setState(() {
        results = outcome.results;
        hitLimit = outcome.hitLimit;
        searching = false;
      });
    } catch (e) {
      if (!mounted || id != searchId) return;
      setState(() {
        searchError = '$e';
        searching = false;
      });
    }
  }

  void _onSearchTyped(String value) {
    searchText = value;
    debounce?.cancel();
    debounce =
        Timer(const Duration(milliseconds: 450), () => _runSearch(value));
  }

  void _onQuickCountryTap(String country) {
    final isActive = searchText.trim().toLowerCase() == country.toLowerCase();
    final next = isActive ? '' : country;
    debounce?.cancel();
    searchController.text = next;
    searchController.selection =
        TextSelection.collapsed(offset: next.length);
    searchText = next;
    _runSearch(next);
  }

  Future<void> _buildIndex() async {
    final ran = await showIndexBuilder(context);
    if (ran && mounted) _runSearch(searchText);
  }

  String _idOf(Map<String, dynamic> p) =>
      (p['id'] ?? '${p['name']}_${p['affiliation']}').toString();

  ContactInfo _infoOf(Map<String, dynamic> p) =>
      contacts[_idOf(p)] ?? const ContactInfo();

  Future<void> _setStatus(Map<String, dynamic> p, ContactStatus s) async {
    final map = await ContactStore.setStatus(_idOf(p), s);
    if (!mounted) return;
    setState(() => contacts = map);
  }

  Future<void> _toggleFavorite(Map<String, dynamic> p) async {
    final map = await ContactStore.toggleFavorite(_idOf(p));
    if (!mounted) return;
    setState(() => contacts = map);
  }

  void _cycleStatus(Map<String, dynamic> p) {
    final cur = _infoOf(p).status;
    final next = switch (cur) {
      ContactStatus.none => ContactStatus.emailed,
      ContactStatus.emailed => ContactStatus.replied,
      ContactStatus.replied => ContactStatus.noEmail,
      ContactStatus.noEmail => ContactStatus.none,
    };
    _setStatus(p, next);
  }

  void _snack(String msg, {VoidCallback? onOpen, int seconds = 4}) {
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(msg),
      duration: Duration(seconds: seconds),
      action: onOpen == null
          ? null
          : SnackBarAction(label: 'Kholein', onPressed: onOpen),
    ));
  }

  String _short(String? s) {
    final t = (s ?? '').replaceAll('\n', ' ').trim();
    return t.length > 140 ? '${t.substring(0, 140)}...' : t;
  }

  Future<bool> _ensureReady() async {
    if (GeminiService.runtimeKey.isEmpty && apiKey.isEmpty) {
      await _openApiKey();
      if (!mounted) return false;
      if (GeminiService.runtimeKey.isEmpty) return false;
    }
    if (profile.isEmpty) {
      await _openProfile();
      if (profile.isEmpty || !mounted) return false;
    }
    return true;
  }

  Future<void> _onEmailTap(Map<String, dynamic> professor) async {
    final entry = drafts[_idOf(professor)];
    if (entry != null) {
      if (entry.status == _DraftStatus.ready) {
        _openDraft(entry);
        return;
      }
      if (entry.status != _DraftStatus.failed) {
        _snack('${cleanName(professor['name'])} ki email ban rahi hai...');
        return;
      }
    }
    if (!await _ensureReady()) return;
    _enqueue(professor);
  }

  Future<void> _regenerate(Map<String, dynamic> professor) async {
    if (!await _ensureReady()) return;
    _enqueue(professor);
  }

  void _enqueue(Map<String, dynamic> professor) {
    final id = _idOf(professor);
    setState(() {
      drafts[id] = _DraftEntry(professor, _DraftStatus.queued);
      queue.add(id);
    });
    _pump();
  }

  void _pump() {
    if (!mounted) return;
    while (running < maxParallel && queue.isNotEmpty) {
      final id = queue.removeAt(0);
      final entry = drafts[id];
      if (entry == null) continue;
      running++;
      setState(() => entry.status = _DraftStatus.generating);
      unawaited(_runDraft(entry));
    }
  }

  Future<void> _runDraft(_DraftEntry entry) async {
    final name = cleanName(entry.professor['name'] ?? 'Professor');
    try {
      final draft = await EmailService.generate(
        professor: entry.professor,
        profile: profile,
      );
      if (draft == null) {
        entry.status = _DraftStatus.failed;
        entry.error =
        'Google ke servers busy hain, thodi der baad dobara try karein.';
      } else {
        entry.draft = draft;
        entry.status = _DraftStatus.ready;
      }
    } catch (e) {
      entry.status = _DraftStatus.failed;
      entry.error = '$e';
    }

    running--;
    if (!mounted) return;
    setState(() {});

    if (entry.status == _DraftStatus.ready) {
      _snack('$name ki email tayyar hai', onOpen: () => _openDraft(entry));
    } else {
      _snack('$name ki email fail hui: ${_short(entry.error)}', seconds: 7);
    }
    _pump();
  }

  void _openDraft(_DraftEntry e) {
    final d = e.draft;
    if (d == null) return;
    showEmailResultDialog(
      context,
      e.professor,
      d.info,
      d.text,
          () => _setStatus(e.professor, ContactStatus.emailed),
          () => _setStatus(e.professor, ContactStatus.noEmail),
    );
  }

  Widget _emailButton(Map<String, dynamic> data) {
    final entry = drafts[_idOf(data)];

    if (entry == null) {
      return IconButton(
        tooltip: 'Email banayein',
        icon: const Icon(Icons.email, color: Colors.blueAccent),
        onPressed: () => _onEmailTap(data),
      );
    }
    if (entry.status == _DraftStatus.queued) {
      return IconButton(
        tooltip: 'Line mein hai, jaldi shuru hogi',
        icon: const Icon(Icons.hourglass_empty, color: Colors.orange),
        onPressed: () => _onEmailTap(data),
      );
    }
    if (entry.status == _DraftStatus.generating) {
      return IconButton(
        tooltip: 'Email ban rahi hai...',
        icon: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        onPressed: () => _onEmailTap(data),
      );
    }
    if (entry.status == _DraftStatus.ready) {
      return IconButton(
        tooltip: 'Email tayyar hai, kholne ke liye tap karein',
        icon: const Icon(Icons.drafts, color: Colors.green),
        onPressed: () => _onEmailTap(data),
      );
    }
    return IconButton(
      tooltip: 'Fail hui: ${_short(entry.error)}\nDobara try ke liye tap karein',
      icon: const Icon(Icons.error_outline, color: Colors.red),
      onPressed: () => _onEmailTap(data),
    );
  }

  List<Map<String, dynamic>> get _displayed {
    var list = results.where((p) {
      final s = _infoOf(p).status;
      return switch (statusFilter) {
        StatusFilter.all => true,
        StatusFilter.notContacted => s == ContactStatus.none,
        StatusFilter.emailed => s == ContactStatus.emailed,
        StatusFilter.replied => s == ContactStatus.replied,
        StatusFilter.noEmail => s == ContactStatus.noEmail,
      };
    }).toList();

    if (favoritesFirst) {
      list.sort((a, b) {
        final fa = _infoOf(a).favorite ? 0 : 1;
        final fb = _infoOf(b).favorite ? 0 : 1;
        if (fa != fb) return fa - fb;
        final sa = _infoOf(a).status == ContactStatus.none ? 0 : 1;
        final sb = _infoOf(b).status == ContactStatus.none ? 0 : 1;
        return sa - sb;
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final emailedCount =
        contacts.values.where((c) => c.status == ContactStatus.emailed).length;
    final repliedCount =
        contacts.values.where((c) => c.status == ContactStatus.replied).length;
    final noEmailCount =
        contacts.values.where((c) => c.status == ContactStatus.noEmail).length;
    final pendingDrafts = drafts.values
        .where((d) =>
    d.status == _DraftStatus.queued ||
        d.status == _DraftStatus.generating)
        .length;
    final readyDrafts =
        drafts.values.where((d) => d.status == _DraftStatus.ready).length;
    final shown = _displayed;
    final activeCountry = searchText.trim().toLowerCase();
    final keyMissing = GeminiService.runtimeKey.isEmpty && apiKey.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CSC Professors Dashboard & AI Agent'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip:
            'Logout (${FirebaseAuth.instance.currentUser?.email ?? ''})',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
          IconButton(
            tooltip: keyMissing
                ? 'Gemini API key set nahi hai'
                : 'Gemini API key',
            icon: Icon(Icons.vpn_key, color: keyMissing ? Colors.red : null),
            onPressed: _openApiKey,
          ),
          IconButton(
            tooltip: 'Search index banayein (ek dafa)',
            icon: const Icon(Icons.manage_search),
            onPressed: _buildIndex,
          ),
          TextButton.icon(
            onPressed: _openProfile,
            icon: const Icon(Icons.person),
            label: Text(profile.isEmpty ? 'My Profile (bharein)' : 'My Profile'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText:
                'Search: naam, university ya country (multiple words bhi chalenge)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchText.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _onQuickCountryTap(searchText),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: _onSearchTyped,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: quickCountries.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final c = quickCountries[i];
                  final active = activeCountry == c.toLowerCase();
                  return ChoiceChip(
                    label: Text(c, style: const TextStyle(fontSize: 12)),
                    selected: active,
                    onSelected: (_) => _onQuickCountryTap(c),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                const Text('Filter:', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                DropdownButton<StatusFilter>(
                  value: statusFilter,
                  underline: const SizedBox(),
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  items: const [
                    DropdownMenuItem(
                        value: StatusFilter.all, child: Text('Sab')),
                    DropdownMenuItem(
                        value: StatusFilter.notContacted,
                        child: Text('Not contacted')),
                    DropdownMenuItem(
                        value: StatusFilter.emailed, child: Text('Emailed')),
                    DropdownMenuItem(
                        value: StatusFilter.replied, child: Text('Replied')),
                    DropdownMenuItem(
                        value: StatusFilter.noEmail,
                        child: Text('Email nahi mili')),
                  ],
                  onChanged: (v) =>
                      setState(() => statusFilter = v ?? StatusFilter.all),
                ),
                const SizedBox(width: 16),
                FilterChip(
                  label: const Text('⭐ Favorites pehle'),
                  selected: favoritesFirst,
                  onSelected: (v) => setState(() => favoritesFirst = v),
                ),
                const Spacer(),
                Text(
                    '$emailedCount emailed • $repliedCount replied • $noEmailCount no email',
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          if (searching) const LinearProgressIndicator(minHeight: 2),
          if (!searching && searchError == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${shown.length} / ${results.length} professors'
                      '${hitLimit ? ' (bohat zyada match, search ko aur specific karein)' : ''}'
                      '${pendingDrafts > 0 ? '   •   ⏳ $pendingDrafts emails ban rahi hain' : ''}'
                      '${readyDrafts > 0 ? '   •   ✅ $readyDrafts tayyar' : ''}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            ),
          Expanded(
            child: searchError != null
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText('Search error: $searchError'),
              ),
            )
                : shown.isEmpty && !searching
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  results.isEmpty
                      ? (searchText.trim().isEmpty
                      ? 'No data found'
                      : 'Koi professor nahi mila.\nAgar pehli dafa hai to upar "Search index" (manage_search) icon dabayein.')
                      : 'Is filter mein koi professor nahi.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
                : ListView.builder(
              itemCount: shown.length,
              itemBuilder: (context, index) {
                final data = shown[index];
                final country = (data['country'] ?? '').toString();
                final info = _infoOf(data);
                final dateText =
                info.date != null ? ' (${info.date})' : '';
                final isReady =
                    drafts[_idOf(data)]?.status == _DraftStatus.ready;

                final (statusIcon, statusColor, statusLabel) =
                switch (info.status) {
                  ContactStatus.none => (
                  Icons.circle_outlined,
                  Colors.grey,
                  'Not contacted'
                  ),
                  ContactStatus.emailed => (
                  Icons.mark_email_read_outlined,
                  Colors.blueAccent,
                  'Emailed$dateText'
                  ),
                  ContactStatus.replied => (
                  Icons.check_circle,
                  Colors.green,
                  'Replied$dateText'
                  ),
                  ContactStatus.noEmail => (
                  Icons.do_not_disturb_alt_outlined,
                  Colors.orange,
                  'Email nahi mili$dateText'
                  ),
                };

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  elevation: 2,
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.school),
                    ),
                    title: Text(
                      cleanName(data['name'] ?? 'Unknown Name'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${data['affiliation'] ?? 'No University'}'
                          '${country.isEmpty ? '' : ' • $country'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: info.favorite
                              ? 'Favorite se hatayein'
                              : 'Favorite karein',
                          icon: Icon(
                            info.favorite
                                ? Icons.star
                                : Icons.star_border,
                            color: info.favorite
                                ? Colors.amber
                                : Colors.grey,
                          ),
                          onPressed: () => _toggleFavorite(data),
                        ),
                        IconButton(
                          tooltip: '$statusLabel (tap to change)',
                          icon: Icon(statusIcon, color: statusColor),
                          onPressed: () => _cycleStatus(data),
                        ),
                        if (isReady)
                          IconButton(
                            tooltip: 'Email dobara banayein',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.refresh, size: 20),
                            onPressed: () => _regenerate(data),
                          ),
                        _emailButton(data),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}