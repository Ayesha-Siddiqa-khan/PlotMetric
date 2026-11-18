import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_formatters.dart';
import '../../../data/models/calculation.dart';
import '../../land/state/land_controller.dart';

class RecordsScreen extends ConsumerStatefulWidget {
  final void Function(Calculation calc) onOpenCalculation;

  const RecordsScreen({super.key, required this.onOpenCalculation});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Calculation> _calculations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCalculations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCalculations([String? query]) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(calculationRepositoryProvider);
      final list = await repo.getAllCalculations(query: query);
      if (mounted) {
        setState(() {
          _calculations = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load records: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _loadCalculations(query.trim());
  }

  void _clearSearch() {
    _searchController.clear();
    _loadCalculations();
  }

  Future<void> _confirmDelete(Calculation calc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Calculation?'),
        content: Text(
          'Are you sure you want to delete "${calc.title}" and all its measurements? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && calc.id != null) {
      try {
        final repo = ref.read(calculationRepositoryProvider);
        await repo.deleteCalculation(calc.id!);
        _loadCalculations(_searchController.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${calc.title}"'),
              backgroundColor: AppTheme.primaryNavy,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: AppTheme.dangerRed,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final isDesktop = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Records'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _loadCalculations(_searchController.text),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                // Search Bar
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search records by title...',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.accentTeal),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: _clearSearch,
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.paleBackground,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.dividerColor),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppTheme.dividerColor),
                // Content Area
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: AppTheme.accentTeal),
                        )
                      : _error != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline, size: 48, color: AppTheme.dangerRed),
                                    const SizedBox(height: 12),
                                    Text(_error!, textAlign: TextAlign.center),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () => _loadCalculations(),
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _calculations.isEmpty
                              ? _buildEmptyState(query)
                              : isDesktop
                                  ? _buildDesktopGrid()
                                  : _buildMobileList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String query) {
    final isSearching = query.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.folder_open,
              size: 64,
              color: AppTheme.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isSearching
                  ? 'No matching calculations found'
                  : 'No saved calculations yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Try searching with a different calculation title or clear the search.'
                  : 'Create a measurement sheet in the Land tab and tap "Save" to keep records here.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
            ),
            if (isSearching) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _clearSearch,
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear Search'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _calculations.length,
      itemBuilder: (context, index) {
        final calc = _calculations[index];
        return _buildRecordCard(calc);
      },
    );
  }

  Widget _buildDesktopGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _calculations.length,
      itemBuilder: (context, index) {
        final calc = _calculations[index];
        return _buildRecordCard(calc);
      },
    );
  }

  Widget _buildRecordCard(Calculation calc) {
    final summary = calc.summary;
    final displayDate = DateTimeFormatters.storageToDisplayDate(calc.calculationDate);
    final displayTime = DateTimeFormatters.storageToDisplayTime(calc.calculationTime);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.dividerColor),
      ),
      child: InkWell(
        onTap: () => widget.onOpenCalculation(calc),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header: Title & Delete button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      calc.title.isEmpty ? '(Untitled)' : calc.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNavy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.dangerRed),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Delete record',
                    onPressed: () => _confirmDelete(calc),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Date & Time line
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    displayDate,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.access_time, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    displayTime,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const Spacer(),
                  Text(
                    '${calc.entries.length} ${calc.entries.length == 1 ? "entry" : "entries"}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
              const Divider(height: 12, color: AppTheme.dividerColor),
              // Net summary line
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      summary.netCompositeArea.toDisplayString(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: summary.isNegative ? AppTheme.dangerRed : AppTheme.primaryNavy,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${summary.netSqFtFormatted} sq ft',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: summary.isNegative ? AppTheme.dangerRed : AppTheme.accentTeal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
