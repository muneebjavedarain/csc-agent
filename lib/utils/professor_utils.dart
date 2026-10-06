// Professor ke data se related helper functions.

/// CSC sirf mainland China ki universities ke liye hai
/// (Hong Kong / Macau / Taiwan alag hain).
bool isMainlandChina(Map<String, dynamic> data) {
  final country = (data['country'] ?? '').toString().toLowerCase().trim();
  final affiliation = (data['affiliation'] ?? '').toString().toLowerCase();
  const excluded = ['hong kong', 'macau', 'macao', 'taiwan'];
  if (excluded.any((x) => country.contains(x) || affiliation.contains(x))) {
    return false;
  }
  if (country == 'cn' || country.contains('china')) return true;
  // country missing ho to university ke naam se andaza
  const cnHints = [
    'china', 'chinese', 'beijing', 'shanghai', 'tsinghua', 'peking',
    'zhejiang', 'fudan', 'nanjing', 'wuhan', 'harbin', 'xi\'an', 'xidian',
    'tianjin', 'shenzhen', 'guangzhou', 'sun yat-sen', 'huazhong',
    'sichuan', 'chongqing', 'hunan', 'jilin', 'shandong', 'xinjiang',
    'uestc', 'ustc', 'nankai', 'tongji', 'southeast university',
    'dalian', 'northeastern university (china)',
  ];
  if (country.isEmpty || country.contains('unknown')) {
    return cnHints.any((h) => affiliation.contains(h));
  }
  return false;
}

/// Har doc ke liye search tokens: naam/university/country ke words aur
/// unke prefixes (3+ letters), taake "syd" likhne par "sydney" mile.
List<String> buildSearchTokens(Map<String, dynamic> data) {
  final text = [data['name'], data['affiliation'], data['country']]
      .map((e) => (e ?? '').toString())
      .join(' ')
      .toLowerCase();
  final words = text
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((w) => w.length >= 2);
  final tokens = <String>{};
  for (final w in words) {
    if (w.length == 2) {
      tokens.add(w); // Li, Wu, Xu jaise surnames
      continue;
    }
    final max = w.length < 15 ? w.length : 15;
    for (var i = 3; i <= max; i++) {
      tokens.add(w.substring(0, i));
    }
  }
  if (isMainlandChina(data)) tokens.add('china');
  return tokens.take(200).toList();
}
String cleanName(dynamic raw) =>
    raw.toString().replaceAll(RegExp(r'\s+\d{4}$'), '').trim();