import 'package:flutter/material.dart';

import '../logic/scheme_repository.dart';
import 'scheme_screen.dart';
import 'scheme_register.dart';

class SchemeRecordsScreen extends StatefulWidget {
  const SchemeRecordsScreen({super.key});
  @override
  State<SchemeRecordsScreen> createState() => _SchemeRecordsScreenState();
}

class _SchemeRecordsScreenState extends State<SchemeRecordsScreen> {
  final _repository = SchemeRepository();
  late Future<List<SchemeListItem>> _records = _repository.list();
  String _query = '';
  bool _opening = false;

  void _refresh() => setState(() => _records = _repository.list(_query));

  Future<void> _open(int? id) async {
    if (_opening) return;
    _opening = true;
    try {
      final scheme = id == null ? null : await _repository.load(id);
      if (mounted) await SchemeScreen.open(context, existing: scheme);
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this scheme.')),
        );
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Housing Schemes'),
      actions: [
        IconButton(tooltip: 'Office scheme register', icon: const Icon(Icons.list_alt_outlined),
          onPressed: () => SchemeRegister.open(context)),
        IconButton(
          tooltip: 'New scheme',
          icon: const Icon(Icons.add),
          onPressed: () => _open(null),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search scheme, owner, or approval reference',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                _query = value;
                _refresh();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<SchemeListItem>>(
              future: _records,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load Housing Schemes.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data!;
                if (rows.isEmpty) {
                  return const Center(
                    child: Text('No matching housing schemes.'),
                  );
                }
                return ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return ListTile(
                      title: Text(row.name),
                      subtitle: Text(
                        [
                          row.owner,
                          row.approval,
                        ].where((value) => value.isNotEmpty).join(' • '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(row.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
