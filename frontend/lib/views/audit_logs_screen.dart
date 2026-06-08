import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/audit_log_controller.dart';
import 'widgets/export_buttons.dart';
import 'widgets/breadcrumbs.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final AuditLogController _controller = AuditLogController();
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String _selectedUserFilter = 'Todos';
  String _selectedActionFilter = 'Todos';
  DateTimeRange? _selectedDateRange;
  late ScrollController _scrollController;
  Timer? _searchDebounce;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(hours: 24)),
      end: DateTime.now(),
    );
    _scrollController = ScrollController()..addListener(_onScroll);
    _controller.fetchUsers();
    _fetchLogs(isRefresh: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _fetchLogs(isRefresh: false);
    }
  }

  void _fetchLogs({bool isRefresh = false}) {
    _controller.fetchLogs(
      isRefresh: isRefresh,
      dateRange: _selectedDateRange,
      userFilter: _selectedUserFilter,
      actionFilter: _selectedActionFilter,
      searchQuery: _searchQuery,
    );
  }

  Color _getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'LOGIN':
        return Colors.blue.shade700;
      case 'CREATE_ITEM':
        return Colors.green.shade700;
      case 'UPDATE_ITEM':
        return Colors.orange.shade700;
      case 'DELETE_ITEM':
        return Colors.red.shade700;
      case 'CHECKOUT':
        return Colors.purple.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  String _formatDateTime(DateTime dt) {
    final year = dt.year.toString();
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  Widget _buildDesktopTable(List<dynamic> logs, bool isLoadingMore) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: const [
                Expanded(flex: 2, child: Text('Fecha y Hora', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                Expanded(flex: 2, child: Text('Usuario', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                Expanded(flex: 2, child: Text('Acción', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                Expanded(flex: 5, child: Text('Detalles', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              itemCount: logs.length + (isLoadingMore ? 1 : 0),
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == logs.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final log = logs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(_formatDateTime(log.createdAt), style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
                      Expanded(flex: 2, child: Text(log.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: Chip(label: Text(log.action, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)), backgroundColor: _getActionColor(log.action), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap))),
                      Expanded(flex: 5, child: Text(log.details, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 2)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(List<dynamic> logs, bool isLoadingMore) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: logs.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == logs.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final log = logs[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(label: Text(log.action, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)), backgroundColor: _getActionColor(log.action), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    Text(_formatDateTime(log.createdAt), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                RichText(text: TextSpan(text: 'Usuario: ', style: const TextStyle(color: Colors.grey, fontSize: 13), children: [TextSpan(text: log.username, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))])),
                const SizedBox(height: 4),
                Text(log.details, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                const Divider(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 750;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3C72),
        foregroundColor: Colors.white,
        title: Breadcrumbs(
          items: [
            BreadcrumbItem(
              label: 'Ventas',
              onTap: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
            BreadcrumbItem(
              label: 'Administración',
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const BreadcrumbItem(label: 'Bitácora'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.storefront_rounded),
            tooltip: 'Volver a Ventas',
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading && _controller.logs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_controller.errorMessage != null && _controller.logs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(_controller.errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        _controller.fetchUsers();
                        _fetchLogs(isRefresh: true);
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3C72), foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
            );
          }

          final filteredLogs = _controller.logs;
          final users = _controller.users;
          if (!users.contains(_selectedUserFilter)) {
            _selectedUserFilter = 'Todos';
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Filtrar por acción, usuario o detalle...',
                            prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                            suffixIcon: (_searchQuery.isNotEmpty || _selectedUserFilter != 'Todos' || _selectedActionFilter != 'Todos' || _selectedDateRange != null)
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                        _selectedUserFilter = 'Todos';
                                        _selectedActionFilter = 'Todos';
                                        _selectedDateRange = null;
                                      });
                                      _fetchLogs(isRefresh: true);
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                            _searchDebounce?.cancel();
                            _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                              _fetchLogs(isRefresh: true);
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(_showFilters ? Icons.filter_alt_rounded : Icons.filter_alt_outlined, color: const Color(0xFF1E3C72)),
                      style: IconButton.styleFrom(backgroundColor: Colors.white, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      tooltip: 'Filtros y Exportación',
                      onPressed: () {
                        setState(() {
                          _showFilters = !_showFilters;
                        });
                      },
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E3C72)),
                      style: IconButton.styleFrom(backgroundColor: Colors.white, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () {
                        _controller.fetchUsers();
                        _fetchLogs(isRefresh: true);
                      },
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Registros Encontrados: ${filteredLogs.length}',
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E3C72),
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _showFilters
                      ? Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                isDesktop
                                    ? Row(
                                        children: [
                                          Expanded(child: DropdownButtonFormField<String>(value: _selectedUserFilter, decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.person_outline_rounded, color: Color(0xFF1E3C72), size: 20), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4)), items: users.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: (val) { if (val != null) { setState(() { _selectedUserFilter = val; }); _fetchLogs(isRefresh: true); } })),
                                          const SizedBox(width: 16),
                                          Expanded(child: DropdownButtonFormField<String>(value: _selectedActionFilter, decoration: const InputDecoration(labelText: 'Acción', prefixIcon: Icon(Icons.info_outline, color: Color(0xFF1E3C72), size: 20), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4)), items: ['Todos', 'LOGIN', 'CREATE_ITEM', 'UPDATE_ITEM', 'DELETE_ITEM', 'CHECKOUT'].map((act) => DropdownMenuItem(value: act, child: Text(act))).toList(), onChanged: (val) { if (val != null) { setState(() { _selectedActionFilter = val; }); _fetchLogs(isRefresh: true); } })),
                                          const SizedBox(width: 16),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.date_range_rounded, size: 16),
                                                label: Text(_selectedDateRange == null ? 'Rango de Fechas' : '${_selectedDateRange!.start.toString().substring(0, 10)} - ${_selectedDateRange!.end.toString().substring(0, 10)}', style: const TextStyle(fontSize: 12)),
                                                onPressed: () async {
                                                  final picked = await showDateRangePicker(context: context, initialDateRange: _selectedDateRange, firstDate: DateTime(2025), lastDate: DateTime.now().add(const Duration(days: 365)), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF1E3C72), onPrimary: Colors.white, onSurface: Colors.black87)), child: child!));
                                                  if (picked != null) { setState(() { _selectedDateRange = picked; }); _fetchLogs(isRefresh: true); }
                                                },
                                                style: ElevatedButton.styleFrom(backgroundColor: _selectedDateRange == null ? Colors.white : const Color(0xFF1E3C72), foregroundColor: _selectedDateRange == null ? Colors.black87 : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 1),
                                              ),
                                              if (_selectedDateRange != null) ...[const SizedBox(width: 4), IconButton(icon: const Icon(Icons.cancel_rounded, color: Colors.grey, size: 20), onPressed: () { setState(() { _selectedDateRange = null; }); _fetchLogs(isRefresh: true); }, tooltip: 'Limpiar Fechas')]
                                            ],
                                          )
                                        ],
                                      )
                                    : Column(
                                        children: [
                                          DropdownButtonFormField<String>(value: _selectedUserFilter, decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.person_outline_rounded, color: Color(0xFF1E3C72), size: 20), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4)), items: users.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: (val) { if (val != null) { setState(() { _selectedUserFilter = val; }); _fetchLogs(isRefresh: true); } }),
                                          const Divider(),
                                          DropdownButtonFormField<String>(value: _selectedActionFilter, decoration: const InputDecoration(labelText: 'Acción', prefixIcon: Icon(Icons.info_outline, color: Color(0xFF1E3C72), size: 20), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4)), items: ['Todos', 'LOGIN', 'CREATE_ITEM', 'UPDATE_ITEM', 'DELETE_ITEM', 'CHECKOUT'].map((act) => DropdownMenuItem(value: act, child: Text(act))).toList(), onChanged: (val) { if (val != null) { setState(() { _selectedActionFilter = val; }); _fetchLogs(isRefresh: true); } }),
                                          const Divider(),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.date_range_rounded, size: 16),
                                                label: Text(_selectedDateRange == null ? 'Rango de Fechas' : '${_selectedDateRange!.start.toString().substring(0, 10)} - ${_selectedDateRange!.end.toString().substring(0, 10)}', style: const TextStyle(fontSize: 12)),
                                                onPressed: () async {
                                                  final picked = await showDateRangePicker(context: context, initialDateRange: _selectedDateRange, firstDate: DateTime(2025), lastDate: DateTime.now().add(const Duration(days: 365)), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF1E3C72), onPrimary: Colors.white, onSurface: Colors.black87)), child: child!));
                                                  if (picked != null) { setState(() { _selectedDateRange = picked; }); _fetchLogs(isRefresh: true); }
                                                },
                                                style: ElevatedButton.styleFrom(backgroundColor: _selectedDateRange == null ? Colors.white : const Color(0xFF1E3C72), foregroundColor: _selectedDateRange == null ? Colors.black87 : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 1),
                                              ),
                                              if (_selectedDateRange != null) IconButton(icon: const Icon(Icons.cancel_rounded, color: Colors.grey, size: 20), onPressed: () { setState(() { _selectedDateRange = null; }); _fetchLogs(isRefresh: true); }, tooltip: 'Limpiar Fechas')
                                            ],
                                          )
                                        ],
                                      ),
                                const SizedBox(height: 16),
                                const Divider(height: 1),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: isDesktop ? Alignment.centerRight : Alignment.center,
                                  child: ExportButtons(
                                    title: 'Bitácora de Auditoría - MarySold POS',
                                    defaultFileName: 'bitacora_auditoria_${DateTime.now().toString().substring(0, 10)}',
                                    headers: const ['Fecha', 'Usuario', 'Acción', 'Detalles'],
                                    onFetchData: () {
                                      return filteredLogs.map((log) {
                                        return [
                                          _formatDateTime(log.createdAt),
                                          log.username,
                                          log.action,
                                          log.details,
                                        ];
                                      }).toList();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: filteredLogs.isEmpty && !_controller.isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.filter_list_off_rounded, size: 48, color: Colors.grey),
                              const SizedBox(height: 8),
                              const Text('No se encontraron registros en la bitácora.', style: TextStyle(fontSize: 15, color: Colors.grey)),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                    _selectedUserFilter = 'Todos';
                                    _selectedActionFilter = 'Todos';
                                    _selectedDateRange = null;
                                  });
                                  _fetchLogs(isRefresh: true);
                                },
                                child: const Text('Limpiar Filtros', style: TextStyle(color: Color(0xFF1E3C72))),
                              ),
                            ],
                          ),
                        )
                      : isDesktop
                          ? _buildDesktopTable(filteredLogs, _controller.isLoadingMore)
                          : _buildMobileList(filteredLogs, _controller.isLoadingMore),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
