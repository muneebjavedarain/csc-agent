import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/professor_utils.dart';

class SearchOutcome {
  final List<Map<String, dynamic>> results;
  final bool hitLimit;
  const SearchOutcome(this.results, this.hitLimit);
}

class IndexReport {
  final int updated;
  final int skipped;
  final String? error;
  const IndexReport(this.updated, this.skipped, this.error);
}

class SearchService {
  static const int limit = 300;

  /// Sab se lamba word server par (searchTokens se), baqi words app mein filter.
  static Future<SearchOutcome> search(String raw) async {
    final q = raw.toLowerCase().trim();
    final col = FirebaseFirestore.instance.collection('professors');
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    List<QueryDocumentSnapshot> docs;
    if (words.isEmpty) {
      docs = (await col.limit(100).get()).docs;
    } else {
      final sorted = [...words]..sort((a, b) => b.length.compareTo(a.length));
      var token = sorted.first;
      if (token.length > 15) token = token.substring(0, 15);
      docs = (await col
          .where('searchTokens', arrayContains: token)
          .limit(limit)
          .get())
          .docs;
    }

    final list = <Map<String, dynamic>>[];
    for (final d in docs) {
      final data = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
      data['id'] = d.id; // tracking ke liye stable ID
      final hay = [data['name'], data['affiliation'], data['country']]
          .map((e) => (e ?? '').toString())
          .join(' ')
          .toLowerCase();
      final ok = words.every(
              (w) => hay.contains(w) || (w == 'china' && isMainlandChina(data)));
      if (ok) list.add(data);
    }
    return SearchOutcome(list, words.isNotEmpty && docs.length >= limit);
  }

  /// Ek dafa chalane wala kaam: har professor mein searchTokens likhta hai.
  /// Jin docs mein pehle se hai unhein skip karta hai (resume ho sakta hai).
  static Future<IndexReport> buildIndex(void Function(String) onProgress) async {
    final db = FirebaseFirestore.instance;
    var updated = 0, skipped = 0;
    DocumentSnapshot? last;

    try {
      while (true) {
        Query q = db
            .collection('professors')
            .orderBy(FieldPath.documentId)
            .limit(500);
        if (last != null) q = q.startAfterDocument(last);
        final snap = await q.get();
        if (snap.docs.isEmpty) break;

        final batch = db.batch();
        var n = 0;
        for (final d in snap.docs) {
          final data = d.data() as Map<String, dynamic>;
          if (data['searchTokens'] is List) {
            skipped++;
            continue;
          }
          batch.update(d.reference, {'searchTokens': buildSearchTokens(data)});
          n++;
        }
        if (n > 0) await batch.commit();
        updated += n;
        last = snap.docs.last;
        onProgress('Update hue: $updated   |   Pehle se theek: $skipped');
      }
    } catch (e) {
      return IndexReport(updated, skipped, '$e');
    }
    return IndexReport(updated, skipped, null);
  }
}