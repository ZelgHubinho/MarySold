import 'package:flutter/material.dart';
import '../controllers/item_controller.dart';
import '../models/user.dart';
import 'item_crud_screen.dart';
import 'audit_logs_screen.dart';
import 'sales_stats_screen.dart';
import 'widgets/breadcrumbs.dart';

class AdminPanelScreen extends StatelessWidget {
  final ItemController itemController;
  final User user;

  const AdminPanelScreen({
    super.key,
    required this.itemController,
    required this.user,
  });

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
            const BreadcrumbItem(label: 'Administración'),
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 950),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Gestión Administrativa',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3C72),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Seleccione la sección que desea administrar, auditar o analizar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),
                isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildMenuCard(context, 0)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildMenuCard(context, 1)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildMenuCard(context, 2)),
                        ],
                      )
                    : Column(
                        children: [
                          _buildMenuCard(context, 0),
                          const SizedBox(height: 16),
                          _buildMenuCard(context, 1),
                          const SizedBox(height: 16),
                          _buildMenuCard(context, 2),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, int type) {
    late final String title;
    late final String subtitle;
    late final IconData icon;
    late final Color color;
    late final Widget targetScreen;

    switch (type) {
      case 0:
        title = 'Inventario de Ropa';
        subtitle = 'Gestionar stock, registrar nuevas prendas, modificar precios y fotos.';
        icon = Icons.checkroom_rounded;
        color = const Color(0xFF1E3C72);
        targetScreen = ItemCrudScreen(itemController: itemController, user: user);
        break;
      case 1:
        title = 'Bitácora de Auditoría';
        subtitle = 'Ver registro de acciones, inicios de sesión y ventas por usuario.';
        icon = Icons.history_toggle_off_rounded;
        color = const Color(0xFF2A5298);
        targetScreen = const AuditLogsScreen();
        break;
      case 2:
      default:
        title = 'Estadísticas';
        subtitle = 'Ver volumen de ventas, productos populares e históricos en gráficos.';
        icon = Icons.bar_chart_rounded;
        color = const Color(0xFF0F2027);
        targetScreen = const SalesStatsScreen();
        break;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => targetScreen,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 48,
                  color: color,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
