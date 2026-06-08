import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../controllers/auth_controller.dart';
import '../controllers/item_controller.dart';
import '../models/item.dart';
import 'admin_panel_screen.dart';
import 'login_screen.dart';

class PosDashboard extends StatefulWidget {
  final AuthController authController;

  const PosDashboard({super.key, required this.authController});

  @override
  State<PosDashboard> createState() => _PosDashboardState();
}

class _PosDashboardState extends State<PosDashboard> {
  final ItemController _itemController = ItemController();
  final Map<Item, int> _cart = {};
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _selectedTypeFilter = 'Todos';
  String _selectedStockFilter = 'Todos';
  bool _isGridCompact = true;
  bool _showFilters = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _itemController.fetchItems(isRefresh: true, paginate: true);
    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _itemController.fetchItems(isRefresh: false);
    }
  }

  double get _totalPrice {
    double total = 0.0;
    _cart.forEach((item, qty) {
      total += item.price * qty;
    });
    return total;
  }

  void _addToCart(Item item) {
    final latestItem = _itemController.items.firstWhere(
      (i) => i.id == item.id,
      orElse: () => item,
    );
    final cartQty = _cart[latestItem] ?? 0;
    if (latestItem.quantity - cartQty <= 0) return;
    setState(() {
      if (cartQty < latestItem.quantity) {
        _cart[latestItem] = cartQty + 1;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Límite de stock alcanzado para este artículo.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 1),
          ),
        );
      }
    });
  }

  void _removeFromCart(Item item) {
    final latestItem = _itemController.items.firstWhere(
      (i) => i.id == item.id,
      orElse: () => item,
    );
    setState(() {
      final currentQty = _cart[latestItem] ?? 0;
      if (currentQty <= 1) {
        _cart.remove(latestItem);
      } else {
        _cart[latestItem] = currentQty - 1;
      }
    });
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
    });
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;

    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    final receiptItems = _cart.entries.toList();
    final double total = _totalPrice;

    final success = await _itemController.checkout(_cart);

    if (mounted) {
      Navigator.of(context).pop(); // Dismiss loading indicator
    }

    if (success) {
      _itemController.fetchItems(paginate: true);
      _clearCart();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                padding: const EdgeInsets.all(24),
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
                        SizedBox(width: 12),
                        Text(
                          '¡Venta Exitosa!',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Comprobante de Pago',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const Divider(height: 24, thickness: 1),
                    const Text(
                      'MarySold Ropa POS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text('Fecha: ${DateTime.now().toString().substring(0, 19)}'),
                    Text('Atendido por: ${widget.authController.currentUser?.username}'),
                    const Divider(height: 24, thickness: 1),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: receiptItems.length,
                        itemBuilder: (context, idx) {
                          final entry = receiptItems[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${entry.key.name} x${entry.value}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text('\$${(entry.key.price * entry.value).toStringAsFixed(2)}'),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 24, thickness: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E3C72)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Refetch items to update display stock
                        _itemController.fetchItems(paginate: true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3C72),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Error en la Venta'),
              content: Text(_itemController.errorMessage ?? 'No se pudo procesar el cobro. Verifique su conexión y stock.'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _itemController.fetchItems(paginate: true); // Sync items in case stock changed
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3C72),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Aceptar'),
                )
              ],
            );
          },
        );
      }
    }
  }

  void _handleLogout() {
    widget.authController.logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => LoginScreen(authController: widget.authController),
      ),
    );
  }

  Future<void> _scanBarcode({VoidCallback? onScanSuccess}) async {
    showDialog(
      context: context,
      builder: (context) => BarcodeScannerDialog(
        onScan: (barcode) async {
          final messenger = ScaffoldMessenger.of(context);
          final item = await _itemController.fetchItemByBarcode(barcode);
          if (item == null) {
            final err = _itemController.errorMessage ?? 'Artículo no registrado.';
            messenger.showSnackBar(
              SnackBar(
                content: Text('Error: $err'),
                backgroundColor: Colors.redAccent,
              ),
            );
            return;
          }

          final latestItem = _itemController.items.firstWhere(
            (i) => i.id == item.id,
            orElse: () => item,
          );
          final cartQty = _cart[latestItem] ?? 0;
          if (latestItem.quantity <= 0) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('"${item.name}" no tiene stock disponible.'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          if (cartQty >= latestItem.quantity) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Límite de stock alcanzado para "${item.name}".'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          _addToCart(item);
          if (onScanSuccess != null) {
            onScanSuccess();
          }

          messenger.showSnackBar(
            SnackBar(
              content: Text('"${item.name}" agregado al carrito.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }

  void _showItemImageDetail(Item item) {
    showDialog(
      context: context,
      builder: (context) {
        // Calculate remaining stock in real time
        final cartQty = _cart[item] ?? 0;
        final remainingStock = item.quantity - cartQty;
        final isOutOfStock = remainingStock <= 0;
        final photoUrl = item.fullPhotoUrl;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 8,
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Image area
                Stack(
                  children: [
                    Container(
                      height: 300,
                      width: double.infinity,
                      color: Colors.grey.shade100,
                      child: photoUrl != null
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, err, stack) => const Center(
                                child: Icon(Icons.broken_image_rounded, size: 80, color: Colors.grey),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.image_not_supported_rounded, size: 80, color: Colors.grey),
                            ),
                    ),
                    // Close button
                    Positioned(
                      top: 12,
                      right: 12,
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.4),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                    // Category/Type Pill
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3C72).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item.type.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
                // Item details
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${item.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3C72),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isOutOfStock ? Colors.red.shade50 : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isOutOfStock ? Colors.red.shade100 : Colors.green.shade100,
                              ),
                            ),
                            child: Text(
                              isOutOfStock ? 'Sin stock' : 'Stock: $remainingStock unidades',
                              style: TextStyle(
                                color: isOutOfStock ? Colors.red : Colors.green.shade800,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.barcode != null && item.barcode!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.qr_code_rounded, size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              'Código: ${item.barcode}',
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      // Add to cart action button
                      ElevatedButton.icon(
                        onPressed: isOutOfStock
                            ? null
                            : () {
                                _addToCart(item);
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('"${item.name}" agregado al carrito.'),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        label: const Text('Agregar al Carrito', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3C72),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authController.currentUser;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3C72),
        elevation: 4,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_rounded, color: Colors.white),
            const SizedBox(width: 8),
            const Text(
              'MarySold POS',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0, fontSize: 18),
            ),
            if (size.width > 650) ...[
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  user?.role.toUpperCase() ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (size.width > 650) ...[
            Text(
              'Hola, ${user?.username}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(width: 8),
          ],
          if (user?.isAdmin == true)
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              tooltip: 'Administración',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AdminPanelScreen(
                      itemController: _itemController,
                      user: user!,
                    ),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Cerrar Sesión',
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: AnimatedBuilder(
        animation: _itemController,
        builder: (context, child) {
          final filteredItems = _itemController.items.where((item) {
            final matchesQuery = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesType = _selectedTypeFilter == 'Todos' || item.type == _selectedTypeFilter;
            
            bool matchesStock = true;
            if (_selectedStockFilter == 'Disponible') {
              matchesStock = item.quantity > 0;
            } else if (_selectedStockFilter == 'Sin stock') {
              matchesStock = item.quantity == 0;
            } else if (_selectedStockFilter == 'Bajo stock (< 5)') {
              matchesStock = item.quantity < 5;
            }
            return matchesQuery && matchesType && matchesStock;
          }).toList();

          return Row(
            children: [
              // Catalog Pane (Left / Main)
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Search and Filter Bar
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: TextField(
                                focusNode: _searchFocusNode,
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Buscar ropa por nombre...',
                                  prefixIcon: _searchFocusNode.hasFocus
                                      ? IconButton(
                                          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E3C72)),
                                          onPressed: () {
                                            _searchFocusNode.unfocus();
                                          },
                                        )
                                      : const Icon(Icons.search_rounded, color: Colors.grey),
                                  suffixIcon: (_searchQuery.isNotEmpty || _selectedTypeFilter != 'Todos' || _selectedStockFilter != 'Todos')
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded),
                                          onPressed: () {
                                            setState(() {
                                              _searchController.clear();
                                              _searchQuery = '';
                                              _selectedTypeFilter = 'Todos';
                                              _selectedStockFilter = 'Todos';
                                            });
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
                                },
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            width: _searchFocusNode.hasFocus ? 0 : 232,
                            decoration: const BoxDecoration(),
                            clipBehavior: Clip.antiAlias,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const NeverScrollableScrollPhysics(),
                              child: Row(
                                children: [
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E3C72)),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      elevation: 2,
                                      fixedSize: const Size(46, 46),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    tooltip: 'Actualizar Catálogo',
                                    onPressed: () => _itemController.fetchItems(paginate: true),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF1E3C72)),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      elevation: 2,
                                      fixedSize: const Size(46, 46),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    tooltip: 'Escanear Código de Barras',
                                    onPressed: () => _scanBarcode(),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: Icon(
                                      _isGridCompact ? Icons.grid_view_rounded : Icons.view_comfy_rounded,
                                      color: const Color(0xFF1E3C72),
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      elevation: 2,
                                      fixedSize: const Size(46, 46),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    tooltip: _isGridCompact ? 'Ver cuadrícula normal' : 'Ver cuadrícula pequeña',
                                    onPressed: () {
                                      setState(() {
                                        _isGridCompact = !_isGridCompact;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: Icon(
                                      _showFilters ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
                                      color: const Color(0xFF1E3C72),
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      elevation: 2,
                                      fixedSize: const Size(46, 46),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    tooltip: 'Filtros de Búsqueda',
                                    onPressed: () {
                                      setState(() {
                                        _showFilters = !_showFilters;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                                  child: isDesktop
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: DropdownButtonFormField<String>(
                                                value: _selectedTypeFilter,
                                                decoration: const InputDecoration(
                                                  labelText: 'Tipo de Prenda',
                                                  prefixIcon: Icon(Icons.category_outlined, color: Color(0xFF1E3C72), size: 20),
                                                  border: InputBorder.none,
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                ),
                                                items: ['Todos', 'Camisa', 'Pantalón', 'Vestido', 'Abrigo', 'Calzado', 'Accesorios', 'Otros'].map((cat) {
                                                  return DropdownMenuItem(value: cat, child: Text(cat));
                                                }).toList(),
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setState(() {
                                                      _selectedTypeFilter = val;
                                                    });
                                                  }
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: DropdownButtonFormField<String>(
                                                value: _selectedStockFilter,
                                                decoration: const InputDecoration(
                                                  labelText: 'Disponibilidad / Stock',
                                                  prefixIcon: Icon(Icons.inventory_outlined, color: Color(0xFF1E3C72), size: 20),
                                                  border: InputBorder.none,
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                ),
                                                items: ['Todos', 'Disponible', 'Sin stock', 'Bajo stock (< 5)'].map((stk) {
                                                  return DropdownMenuItem(value: stk, child: Text(stk));
                                                }).toList(),
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setState(() {
                                                      _selectedStockFilter = val;
                                                    });
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          children: [
                                            DropdownButtonFormField<String>(
                                              value: _selectedTypeFilter,
                                              decoration: const InputDecoration(
                                                labelText: 'Tipo de Prenda',
                                                prefixIcon: Icon(Icons.category_outlined, color: Color(0xFF1E3C72), size: 20),
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                              ),
                                              items: ['Todos', 'Camisa', 'Pantalón', 'Vestido', 'Abrigo', 'Calzado', 'Accesorios', 'Otros'].map((cat) {
                                                return DropdownMenuItem(value: cat, child: Text(cat));
                                              }).toList(),
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setState(() {
                                                    _selectedTypeFilter = val;
                                                  });
                                                }
                                              },
                                            ),
                                            const Divider(),
                                            DropdownButtonFormField<String>(
                                              value: _selectedStockFilter,
                                              decoration: const InputDecoration(
                                                labelText: 'Disponibilidad / Stock',
                                                prefixIcon: Icon(Icons.inventory_outlined, color: Color(0xFF1E3C72), size: 20),
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                              ),
                                              items: ['Todos', 'Disponible', 'Sin stock', 'Bajo stock (< 5)'].map((stk) {
                                                return DropdownMenuItem(value: stk, child: Text(stk));
                                              }).toList(),
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setState(() {
                                                    _selectedStockFilter = val;
                                                  });
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      const SizedBox(height: 16),
                      // Grid of Clothes Items
                      Expanded(
                        child: _itemController.isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _itemController.errorMessage != null
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                                        const SizedBox(height: 12),
                                        Text(
                                          _itemController.errorMessage!,
                                          style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                                        ),
                                        const SizedBox(height: 12),
                                        ElevatedButton(
                                          onPressed: () => _itemController.fetchItems(),
                                          child: const Text('Reintentar'),
                                        )
                                      ],
                                    ),
                                  )
                                : filteredItems.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.filter_list_off_rounded, size: 48, color: Colors.grey),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'No se encontraron artículos.',
                                              style: TextStyle(fontSize: 16, color: Colors.grey),
                                            ),
                                            const SizedBox(height: 8),
                                            TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  _searchController.clear();
                                                  _searchQuery = '';
                                                  _selectedTypeFilter = 'Todos';
                                                  _selectedStockFilter = 'Todos';
                                                });
                                              },
                                              child: const Text('Limpiar Filtros', style: TextStyle(color: Color(0xFF1E3C72))),
                                            ),
                                          ],
                                        ),
                                      )
                                    : GridView.builder(
                                        controller: _scrollController,
                                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: isDesktop 
                                              ? (_isGridCompact ? 5 : 3) 
                                              : (_isGridCompact ? 3 : 2),
                                          crossAxisSpacing: _isGridCompact ? 10 : 16,
                                          mainAxisSpacing: _isGridCompact ? 10 : 16,
                                          childAspectRatio: _isGridCompact ? 0.70 : 0.78,
                                        ),
                                        itemCount: filteredItems.length + (_itemController.isLoadingMore ? 1 : 0),
                                        itemBuilder: (context, idx) {
                                          if (idx == filteredItems.length) {
                                            return const Card(
                                              elevation: 1,
                                              child: Center(
                                                child: Padding(
                                                  padding: EdgeInsets.all(16.0),
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                ),
                                              ),
                                            );
                                          }
                                          final item = filteredItems[idx];
                                          final cartQty = _cart[item] ?? 0;
                                          final remainingStock = item.quantity - cartQty;
                                          final isOutOfStock = remainingStock <= 0;
                                          final photoUrl = item.fullPhotoUrl;

                                          return Card(
                                            elevation: 3,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(_isGridCompact ? 10 : 16),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                // Image / Image placeholder
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: () => _showItemImageDetail(item),
                                                    child: Container(
                                                      color: Colors.grey.shade100,
                                                      child: photoUrl != null
                                                          ? Image.network(
                                                              photoUrl,
                                                              fit: BoxFit.cover,
                                                              errorBuilder: (context, err, stack) {
                                                                return const Center(
                                                                  child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40),
                                                                );
                                                              },
                                                            )
                                                          : const Center(
                                                              child: Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 40),
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: EdgeInsets.all(_isGridCompact ? 8.0 : 12.0),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        item.name,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold, 
                                                          fontSize: _isGridCompact ? 12 : 15,
                                                        ),
                                                      ),
                                                      SizedBox(height: _isGridCompact ? 2 : 4),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            '\$${item.price.toStringAsFixed(2)}',
                                                            style: TextStyle(
                                                              color: const Color(0xFF1E3C72),
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: _isGridCompact ? 13 : 16,
                                                            ),
                                                          ),
                                                          Text(
                                                            isOutOfStock ? 'Sin stock' : 'Stock: $remainingStock',
                                                            style: TextStyle(
                                                              color: isOutOfStock ? Colors.red : Colors.grey,
                                                              fontSize: _isGridCompact ? 10 : 12,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      SizedBox(height: _isGridCompact ? 6 : 10),
                                                      // Add to cart button
                                                      ElevatedButton.icon(
                                                        onPressed: isOutOfStock ? null : () => _addToCart(item),
                                                        icon: Icon(Icons.add_shopping_cart_rounded, size: _isGridCompact ? 12 : 16),
                                                        label: Text(
                                                          'Agregar',
                                                          style: TextStyle(fontSize: _isGridCompact ? 11 : 14),
                                                        ),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFF1E3C72),
                                                          foregroundColor: Colors.white,
                                                          elevation: 0,
                                                          minimumSize: Size(double.infinity, _isGridCompact ? 28 : 36),
                                                          padding: _isGridCompact ? const EdgeInsets.symmetric(vertical: 4) : null,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(_isGridCompact ? 6 : 8),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                      ),
                    ],
                  ),
                ),
              ),

              // Cart Pane (Right Panel, Desktop Only)
              if (isDesktop)
                Container(
                  width: 380,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(-2, 0),
                      ),
                    ],
                  ),
                  child: _buildCartPanel(),
                ),
            ],
          );
        },
      ),
      // Floating Cart button for Mobile layout
      floatingActionButton: !isDesktop
          ? FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) => DraggableScrollableSheet(
                    initialChildSize: 0.75,
                    maxChildSize: 0.9,
                    expand: false,
                    builder: (context, scrollController) {
                      return StatefulBuilder(
                        builder: (context, setModalState) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            child: _buildCartPanel(
                              isMobileModal: true,
                              onCartChanged: () {
                                setModalState(() {});
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
              backgroundColor: const Color(0xFF1E3C72),
              icon: const Icon(Icons.shopping_cart_rounded, color: Colors.white),
              label: Text(
                'Carrito (${_cart.values.fold(0, (sum, val) => sum + val)})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildCartPanel({bool isMobileModal = false, VoidCallback? onCartChanged}) {
    final cartList = _cart.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_basket_rounded, color: Color(0xFF1E3C72)),
                  const SizedBox(width: 8),
                  const Text(
                    'Carrito de Compra',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_cart.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        _clearCart();
                        if (isMobileModal) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                      label: const Text('Limpiar', style: TextStyle(color: Colors.redAccent)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF1E3C72)),
                    tooltip: 'Escanear Código de Barras',
                    onPressed: () => _scanBarcode(onScanSuccess: onCartChanged),
                  ),
                ],
              )
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'El carrito está vacío.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cartList.length,
                  separatorBuilder: (context, idx) => const Divider(),
                  itemBuilder: (context, idx) {
                    final entry = cartList[idx];
                    final item = entry.key;
                    final qty = entry.value;

                    return Row(
                      children: [
                        // Small image preview
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: item.fullPhotoUrl != null
                              ? Image.network(
                                  item.fullPhotoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, err, stack) => const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 24),
                                )
                              : const Icon(Icons.image_rounded, color: Colors.grey, size: 24),
                        ),
                        const SizedBox(width: 12),
                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '\$${item.price.toStringAsFixed(2)} x unidad',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        // Qty Buttons
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.grey),
                              onPressed: () {
                                _removeFromCart(item);
                                if (onCartChanged != null) {
                                  onCartChanged();
                                }
                              },
                            ),
                            Text(
                              '$qty',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            (() {
                              final latestItem = _itemController.items.firstWhere(
                                (i) => i.id == item.id,
                                orElse: () => item,
                              );
                              final canAdd = qty < latestItem.quantity;
                              return IconButton(
                                icon: Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: canAdd ? const Color(0xFF1E3C72) : Colors.grey.shade400,
                                ),
                                onPressed: canAdd
                                    ? () {
                                        _addToCart(item);
                                        if (onCartChanged != null) {
                                          onCartChanged();
                                        }
                                      }
                                    : null,
                              );
                            })(),
                          ],
                        ),
                      ],
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        // Total price and Checkout
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  Text(
                    '\$${_totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E3C72)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _cart.isEmpty
                    ? null
                    : () {
                        if (isMobileModal) Navigator.pop(context);
                        _checkout();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3C72),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: const Text(
                  'Cobrar y Finalizar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}

class BarcodeScannerDialog extends StatefulWidget {
  final Function(String) onScan;
  const BarcodeScannerDialog({required this.onScan, super.key});

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool get _useCamera => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitCode() {
    final code = _inputController.text.trim();
    if (code.isNotEmpty) {
      widget.onScan(code);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF1E3C72), size: 28),
                      SizedBox(width: 8),
                      Text(
                        'Escanear Código',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3C72)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
              const SizedBox(height: 16),
              if (_useCamera)
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: MobileScanner(
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        final String? code = barcode.rawValue;
                        if (code != null && code.isNotEmpty) {
                          widget.onScan(code);
                          Navigator.of(context).pop();
                          break;
                        }
                      }
                    },
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.desktop_windows_rounded, size: 40, color: Color(0xFF1E3C72)),
                      SizedBox(height: 8),
                      Text(
                        'Modo Simulación de Escritorio',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3C72)),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'El lector de cámara física está optimizado para dispositivos móviles. En Windows, puedes ingresar el código manualmente o usar una lectora física USB.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              TextField(
                controller: _inputController,
                focusNode: _focusNode,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Ingresar código de barras',
                  hintText: 'Ej: 779123456789',
                  prefixIcon: const Icon(Icons.keyboard_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF1E3C72)),
                    onPressed: _submitCode,
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onSubmitted: (_) => _submitCode(),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _submitCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3C72),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
