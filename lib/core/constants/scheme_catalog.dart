class SchemeCatalog {
  const SchemeCatalog._();

  // Ittefaq and Al-Khair were supplied separately from the visible register page.
  static const colonies = [
    'Ittefaq City',
    'Al-Khair Block',
    'Ahmad City',
    'Muhammad Iqbal City',
    'Dubai Villas',
    'Yasir Villas',
    'Azmat City',
    'Yousaf Colony',
    'Royal City',
    'Gulshan-e-Hajra',
    'Nawab City',
    'Rehan Avenue',
    'Al-Haram City',
    'Rehan Garden',
    'Defence Block',
    'Fazal Villas Phase-II',
    'Fazal Villas Phase-III',
    'Anmol City',
    'Rehan Garden Phase-II',
    'New Johar Town',
    'Rehan Villas',
  ];

  static const areaTitles = [
    'Total Area',
    'Total Area of Scheme',
    'Residential Area',
    'Total Road Area',
    'Commercial Area',
    'Park & Green Belt',
    'Public Building Mosque',
    'Public Building Mosque (17M-8S) Dispensary (3M)',
    'Solid Waste Management & Disposal',
  ];

  static Iterable<String> suggest(Iterable<String> options, String input) {
    final query = _searchText(input);
    if (query.isEmpty) return const [];
    final matches = options.toSet().where((name) {
      final normalized = _searchText(name);
      return normalized.startsWith(query) ||
          normalized.replaceAll(' ', '').startsWith(query.replaceAll(' ', '')) ||
          normalized.split(' ').any((part) => part.startsWith(query));
    }).toList();
    matches.sort((left, right) {
      final leftPrefix = _searchText(left).startsWith(query);
      final rightPrefix = _searchText(right).startsWith(query);
      if (leftPrefix != rightPrefix) return leftPrefix ? -1 : 1;
      return left.toLowerCase().compareTo(right.toLowerCase());
    });
    return matches.take(12);
  }

  static String _searchText(String text) => text
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^(?:اتفاق|इत्तेफाक)(?:\s+سٹی)?$'), 'ittefaq')
      .replaceFirst(RegExp(r'^(?:الخیر|الخير|अलखैर)$'), 'al khair')
      .replaceFirst(RegExp(r'^(?:ال|अल)$'), 'al')
      .replaceAll(RegExp(r'[-‐‑–]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}
