import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'widgets/breadcrumbs.dart';
import 'widgets/collapsible_panel.dart';

class SalesStatsScreen extends StatefulWidget {
  const SalesStatsScreen({super.key});

  @override
  State<SalesStatsScreen> createState() => _SalesStatsScreenState();
}

class _SalesStatsScreenState extends State<SalesStatsScreen> {
  final ApiClient _apiClient = ApiClient.instance;
  bool _isLoading = true;
  String? _errorMessage;

  // Stats Data
  double _totalRevenue = 0.0;
  int _totalSales = 0;
  double _avgSaleValue = 0.0;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _hourly = [];
  List<Map<String, dynamic>> _daily = [];

  // Filter state
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  String _activePreset = '30d'; // 'hoy', '7d', '30d', 'custom'
  String _productMetric = 'quantity'; // 'quantity' or 'revenue'
  String _activeChartTab = 'products'; // 'products', 'hourly', 'daily'

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final startStr = _selectedDateRange.start.toIso8601String().split('T')[0];
      final endStr = _selectedDateRange.end.toIso8601String().split('T')[0];

      final response = await _apiClient.get('/sales/stats?startDate=$startStr&endDate=$endStr');
      final data = jsonDecode(response.body);

      setState(() {
        _totalRevenue = (data['summary']['totalRevenue'] as num).toDouble();
        _totalSales = (data['summary']['totalSales'] as num).toInt();
        _avgSaleValue = (data['summary']['avgSaleValue'] as num).toDouble();

        _products = List<Map<String, dynamic>>.from(data['products']);
        _hourly = List<Map<String, dynamic>>.from(data['hourly']);
        _daily = List<Map<String, dynamic>>.from(data['daily']);
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión. Intente nuevamente.';
        _isLoading = false;
      });
    }
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    if (preset == 'hoy') {
      start = DateTime(now.year, now.month, now.day);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    } else if (preset == '7d') {
      start = now.subtract(const Duration(days: 7));
    } else if (preset == '30d') {
      start = now.subtract(const Duration(days: 30));
    } else {
      return;
    }

    setState(() {
      _activePreset = preset;
      _selectedDateRange = DateTimeRange(start: start, end: end);
    });
    _fetchStats();
  }

  Future<void> _selectCustomDateRange() async {
    final pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3C72),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _activePreset = 'custom';
        _selectedDateRange = pickedRange;
      });
      _fetchStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

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
            const BreadcrumbItem(label: 'Estadísticas'),
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
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: _fetchStats,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3C72)))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 54, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 16, color: Colors.redAccent, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _fetchStats,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3C72),
                          foregroundColor: Colors.white,
                        ),
                      )
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildFilterSection(isDesktop),
                          const SizedBox(height: 24),
                          _buildSummaryRow(isDesktop),
                          const SizedBox(height: 24),
                          _buildChartsSection(),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildFilterSection(bool isDesktop) {
    return CollapsiblePanel(
      title: 'Filtros de Fecha',
      icon: Icons.date_range_rounded,
      initialExpanded: false,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          // Preset Segmented Buttons
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildPresetButton('hoy', 'Hoy'),
              _buildPresetButton('7d', '7 Días'),
              _buildPresetButton('30d', '30 Días'),
              _buildPresetButton('custom', 'Personalizado', isCustom: true),
            ],
          ),
          // Date string display
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_rounded, color: Color(0xFF1E3C72), size: 20),
              const SizedBox(width: 8),
              Text(
                'Rango: ${_formatDate(_selectedDateRange.start)} - ${_formatDate(_selectedDateRange.end)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(String preset, String label, {bool isCustom = false}) {
    final isActive = _activePreset == preset;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        selected: isActive,
        selectedColor: const Color(0xFF1E3C72),
        backgroundColor: Colors.grey.shade200,
        elevation: isActive ? 2 : 0,
        pressElevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onSelected: (selected) {
          if (selected) {
            if (isCustom) {
              _selectCustomDateRange();
            } else {
              _applyPreset(preset);
            }
          }
        },
      ),
    );
  }

  Widget _buildSummaryRow(bool isDesktop) {
    final cards = [
      _buildSummaryCard(
        'Ingresos Totales',
        '\$${_totalRevenue.toStringAsFixed(2)}',
        Icons.attach_money_rounded,
        Colors.green.shade600,
      ),
      _buildSummaryCard(
        'Transacciones',
        '$_totalSales ventas',
        Icons.shopping_bag_rounded,
        const Color(0xFF1E3C72),
      ),
      _buildSummaryCard(
        'Ticket Promedio',
        '\$${_avgSaleValue.toStringAsFixed(2)}',
        Icons.analytics_rounded,
        Colors.orange.shade700,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: c,
        ))).toList(),
      );
    } else {
      return Column(
        children: cards.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: c,
        )).toList(),
      );
    }
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tabs Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabButton('products', 'Tipos de Prenda'),
                  _buildTabButton('hourly', 'Horarios Pico'),
                  _buildTabButton('daily', 'Tendencia Diaria'),
                ],
              ),
            ),
            const Divider(height: 32),
            if (_activeChartTab == 'products') _buildProductsChartSection(),
            if (_activeChartTab == 'hourly') _buildHourlyChartSection(),
            if (_activeChartTab == 'daily') _buildDailyChartSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String tab, String label) {
    final isActive = _activeChartTab == tab;
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: TextButton(
        onPressed: () {
          setState(() {
            _activeChartTab = tab;
          });
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          backgroundColor: isActive ? const Color(0xFF1E3C72).withOpacity(0.08) : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isActive ? const Color(0xFF1E3C72) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildProductsChartSection() {
    if (_products.isEmpty) {
      return _buildNoDataMessage('No hay datos de productos en este rango.');
    }

    // Metric selector (volume vs revenue)
    final isQty = _productMetric == 'quantity';
    
    // Convert products array to chart data
    final chartData = _products.map((item) {
      return {
        'label': item['name'] as String,
        'value': isQty ? (item['quantity'] as num).toDouble() : (item['revenue'] as num).toDouble(),
        'display': isQty ? '${item['quantity']} uds' : '\$${(item['revenue'] as num).toStringAsFixed(0)}',
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            const Text(
              'Rendimiento por Tipo de Prenda',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            // Segmented Metric Toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMetricToggle('quantity', 'Cantidad', isQty),
                  _buildMetricToggle('revenue', 'Ingresos', !isQty),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        _buildNativeBarChart(chartData, gradientColors: [const Color(0xFF1E3C72), const Color(0xFF00C9FF)]),
      ],
    );
  }

  Widget _buildMetricToggle(String value, String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _productMetric = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isActive ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isActive ? const Color(0xFF1E3C72) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildHourlyChartSection() {
    if (_hourly.isEmpty) {
      return _buildNoDataMessage('No hay datos de horarios en este rango.');
    }

    // Chart representation: map hours (0 to 23)
    final chartData = _hourly.map((h) {
      final hourStr = '${h['hour']}:00';
      return {
        'label': hourStr,
        'value': (h['revenue'] as num).toDouble(),
        'display': '\$${(h['revenue'] as num).toStringAsFixed(0)}',
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Distribución de Ventas por Hora',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 30),
        _buildNativeBarChart(chartData, gradientColors: [const Color(0xFF2A5298), const Color(0xFFF39C12)]),
      ],
    );
  }

  Widget _buildDailyChartSection() {
    if (_daily.isEmpty) {
      return _buildNoDataMessage('No hay ventas registradas en este rango.');
    }

    final chartData = _daily.map((d) {
      // Show short date e.g. "Jun 05"
      final parts = d['date'].split('-');
      final monthMap = {'01':'Ene','02':'Feb','03':'Mar','04':'Abr','05':'May','06':'Jun','07':'Jul','08':'Ago','09':'Sep','10':'Oct','11':'Nov','12':'Dic'};
      final shortDate = parts.length >= 3 ? '${parts[2]} ${monthMap[parts[1]] ?? parts[1]}' : d['date'];

      return {
        'label': shortDate,
        'value': (d['revenue'] as num).toDouble(),
        'display': '\$${(d['revenue'] as num).toStringAsFixed(0)}',
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Histórico de Ventas Diarias',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 30),
        _buildNativeBarChart(chartData, gradientColors: [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)]),
      ],
    );
  }

  Widget _buildNativeBarChart(List<Map<String, dynamic>> data, {required List<Color> gradientColors}) {
    // Find the maximum value to scale heights
    double maxValue = 0.01;
    for (var d in data) {
      if (d['value'] > maxValue) {
        maxValue = d['value'];
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // We set a fixed height for the bar chart
        const chartHeight = 250.0;
        final barWidth = data.length > 15 ? 40.0 : 60.0;

        return SizedBox(
          height: chartHeight + 85, // extra height for labels and displays (increased to prevent RenderFlex overflow)
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((d) {
                final double value = d['value'];
                final String label = d['label'];
                final String display = d['display'];
                
                // Calculate proportional height
                final double barHeight = (value / maxValue) * chartHeight;

                return Container(
                  width: barWidth + 16,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Display value at the top of the bar
                      Text(
                        display,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                      const SizedBox(height: 6),
                      // Bar itself
                      Container(
                        height: barHeight.clamp(4.0, chartHeight), // clamp to make sure tiny heights are still visible
                        width: barWidth,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Label under the bar
                      SizedBox(
                        height: 32,
                        child: Text(
                          label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoDataMessage(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(Icons.query_stats_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              msg,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
