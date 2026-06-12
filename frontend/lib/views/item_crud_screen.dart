import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../controllers/item_controller.dart';
import '../models/item.dart';
import '../models/user.dart';
import 'widgets/export_buttons.dart';
import 'widgets/breadcrumbs.dart';

class ItemCrudScreen extends StatefulWidget {
  final ItemController itemController;
  final User user;

  const ItemCrudScreen({
    super.key,
    required this.itemController,
    required this.user,
  });

  @override
  State<ItemCrudScreen> createState() => _ItemCrudScreenState();
}

class _ItemCrudScreenState extends State<ItemCrudScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  String _selectedTypeFilter = 'Todos';
  String _selectedStockFilter = 'Todos';
  String _selectedSizeFilter = 'Todos';
  String _selectedGenderFilter = 'Todos';
  bool _showFilters = false;
  final ScrollController _desktopScrollController = ScrollController();
  final ScrollController _mobileScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Guard against non-admin accessing this screen directly
    if (!widget.user.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acceso Denegado. Solo administradores.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      });
    } else {
      // Load items with pagination after build completes to avoid notifying listeners during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.itemController.fetchItems(isRefresh: true, paginate: true);
        }
      });
      _desktopScrollController.addListener(_onScroll);
      _mobileScrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _desktopScrollController.dispose();
    _mobileScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_desktopScrollController.hasClients &&
        _desktopScrollController.position.pixels >= _desktopScrollController.position.maxScrollExtent - 200) {
      widget.itemController.fetchItems(isRefresh: false);
    }
    if (_mobileScrollController.hasClients &&
        _mobileScrollController.position.pixels >= _mobileScrollController.position.maxScrollExtent - 200) {
      widget.itemController.fetchItems(isRefresh: false);
    }
  }

  void _showItemForm({Item? item}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _ItemFormDialog(
          itemController: widget.itemController,
          imagePicker: _imagePicker,
          item: item,
        );
      },
    );
  }

  void _confirmDelete(Item item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text('¿Está seguro de que desea eliminar "${item.name}"? Esta acción no se puede deshacer.'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                final success = await widget.itemController.deleteItem(item.id);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Artículo eliminado con éxito.' : 'Error al eliminar artículo.'),
                    backgroundColor: success ? Colors.green : Colors.redAccent,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 700;

    return Scaffold(
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
            const BreadcrumbItem(label: 'Inventario'),
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
            icon: Icon(_showFilters ? Icons.filter_alt_rounded : Icons.filter_alt_outlined),
            tooltip: 'Filtros y Exportación',
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: () => widget.itemController.fetchItems(isRefresh: true, paginate: true),
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showItemForm(),
        backgroundColor: const Color(0xFF1E3C72),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: AnimatedBuilder(
        animation: widget.itemController,
        builder: (context, child) {
          if (widget.itemController.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final originalItems = widget.itemController.items;

          if (originalItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No hay artículos de ropa registrados.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _showItemForm(),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3C72), foregroundColor: Colors.white),
                    child: const Text('Agregar Artículo'),
                  ),
                ],
              ),
            );
          }

          // Apply filters
          var filteredItems = originalItems;
          if (_selectedTypeFilter != 'Todos') {
            filteredItems = filteredItems.where((item) => item.type == _selectedTypeFilter).toList();
          }
          if (_selectedStockFilter != 'Todos') {
            if (_selectedStockFilter == 'Disponible') {
              filteredItems = filteredItems.where((item) => item.quantity > 0).toList();
            } else if (_selectedStockFilter == 'Sin stock') {
              filteredItems = filteredItems.where((item) => item.quantity == 0).toList();
            } else if (_selectedStockFilter == 'Bajo stock (< 5)') {
              filteredItems = filteredItems.where((item) => item.quantity < 5).toList();
            }
          }
          if (_selectedSizeFilter != 'Todos') {
            filteredItems = filteredItems.where((item) => item.variants.any((v) => v.size == _selectedSizeFilter)).toList();
          }
          if (_selectedGenderFilter != 'Todos') {
            filteredItems = filteredItems.where((item) => item.gender == _selectedGenderFilter).toList();
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.itemController.errorMessage != null)
                  Container(
                    constraints: const BoxConstraints(minHeight: 50),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.shade100),
                    ),
                    child: Text(
                      widget.itemController.errorMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Prendas Registradas (${filteredItems.length})',
                      style: TextStyle(
                        fontSize: isDesktop ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E3C72),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                isDesktop
                                    ? Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: DropdownButtonFormField<String>(
                                                  value: _selectedTypeFilter,
                                                  decoration: InputDecoration(
                                                    labelText: 'Tipo de Prenda',
                                                    prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF1E3C72)),
                                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                                  decoration: InputDecoration(
                                                    labelText: 'Nivel de Stock',
                                                    prefixIcon: const Icon(Icons.inventory_outlined, color: Color(0xFF1E3C72)),
                                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: DropdownButtonFormField<String>(
                                                  value: _selectedSizeFilter,
                                                  decoration: InputDecoration(
                                                    labelText: 'Talla',
                                                    prefixIcon: const Icon(Icons.straighten_rounded, color: Color(0xFF1E3C72)),
                                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  ),
                                                  items: ['Todos', 'Única', 'XS', 'S', 'M', 'L', 'XL', 'XXL', '36', '38', '40', '42', '44'].map((sz) {
                                                    return DropdownMenuItem(value: sz, child: Text(sz));
                                                  }).toList(),
                                                  onChanged: (val) {
                                                    if (val != null) {
                                                      setState(() {
                                                        _selectedSizeFilter = val;
                                                      });
                                                    }
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: DropdownButtonFormField<String>(
                                                  value: _selectedGenderFilter,
                                                  decoration: InputDecoration(
                                                    labelText: 'Género',
                                                    prefixIcon: const Icon(Icons.wc_rounded, color: Color(0xFF1E3C72)),
                                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  ),
                                                  items: ['Todos', 'Unisex', 'Hombre', 'Mujer', 'Niño', 'Niña'].map((gen) {
                                                    return DropdownMenuItem(value: gen, child: Text(gen));
                                                  }).toList(),
                                                  onChanged: (val) {
                                                    if (val != null) {
                                                      setState(() {
                                                        _selectedGenderFilter = val;
                                                      });
                                                    }
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      )
                                    : Column(
                                        children: [
                                          DropdownButtonFormField<String>(
                                            value: _selectedTypeFilter,
                                            decoration: InputDecoration(
                                              labelText: 'Tipo de Prenda',
                                              prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF1E3C72)),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                          const SizedBox(height: 12),
                                          DropdownButtonFormField<String>(
                                            value: _selectedStockFilter,
                                            decoration: InputDecoration(
                                              labelText: 'Nivel de Stock',
                                              prefixIcon: const Icon(Icons.inventory_outlined, color: Color(0xFF1E3C72)),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                          const SizedBox(height: 12),
                                          DropdownButtonFormField<String>(
                                            value: _selectedSizeFilter,
                                            decoration: InputDecoration(
                                              labelText: 'Talla',
                                              prefixIcon: const Icon(Icons.straighten_rounded, color: Color(0xFF1E3C72)),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            ),
                                            items: ['Todos', 'Única', 'XS', 'S', 'M', 'L', 'XL', 'XXL', '36', '38', '40', '42', '44'].map((sz) {
                                              return DropdownMenuItem(value: sz, child: Text(sz));
                                            }).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  _selectedSizeFilter = val;
                                                });
                                              }
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          DropdownButtonFormField<String>(
                                            value: _selectedGenderFilter,
                                            decoration: InputDecoration(
                                              labelText: 'Género',
                                              prefixIcon: const Icon(Icons.wc_rounded, color: Color(0xFF1E3C72)),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            ),
                                            items: ['Todos', 'Unisex', 'Hombre', 'Mujer', 'Niño', 'Niña'].map((gen) {
                                              return DropdownMenuItem(value: gen, child: Text(gen));
                                            }).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  _selectedGenderFilter = val;
                                                });
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                const SizedBox(height: 16),
                                const Divider(height: 1),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: isDesktop ? Alignment.centerRight : Alignment.center,
                                  child: ExportButtons(
                                    title: 'Reporte de Inventario de Ropa',
                                    defaultFileName: 'reporte_inventario_${DateTime.now().toString().substring(0, 10)}',
                                    headers: const ['ID', 'Nombre', 'Tipo', 'Talla (Stock)', 'Género', 'Precio', 'Stock Total'],
                                    onFetchData: () {
                                      return filteredItems.map((item) {
                                        return [
                                          item.id.toString(),
                                          item.name,
                                          item.type,
                                          item.variants.map((v) => '${v.size} (${v.quantity})').join(', '),
                                          item.gender,
                                          item.formattedPriceRange,
                                          item.quantity.toString(),
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
                  child: filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.filter_list_off_rounded, size: 48, color: Colors.grey),
                              const SizedBox(height: 8),
                              const Text(
                                'Ningún artículo coincide con los filtros.',
                                style: TextStyle(color: Colors.grey, fontSize: 15),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedTypeFilter = 'Todos';
                                    _selectedStockFilter = 'Todos';
                                    _selectedSizeFilter = 'Todos';
                                    _selectedGenderFilter = 'Todos';
                                  });
                                },
                                child: const Text('Limpiar Filtros', style: TextStyle(color: Color(0xFF1E3C72))),
                              ),
                            ],
                          ),
                        )
                      : isDesktop
                          ? Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: SingleChildScrollView(
                                controller: _desktopScrollController,
                                scrollDirection: Axis.vertical,
                                child: Column(
                                  children: [
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        columns: const [
                                          DataColumn(label: Text('Foto')),
                                          DataColumn(label: Text('Nombre')),
                                          DataColumn(label: Text('Tipo')),
                                          DataColumn(label: Text('Talla')),
                                          DataColumn(label: Text('Género')),
                                          DataColumn(label: Text('Precio')),
                                          DataColumn(label: Text('Cantidad')),
                                          DataColumn(label: Text('Código de Barras')),
                                          DataColumn(label: Text('Acciones')),
                                        ],
                                        rows: filteredItems.map((item) {
                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                Container(
                                                  width: 40,
                                                  height: 40,
                                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade200,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  clipBehavior: Clip.antiAlias,
                                                  child: item.fullPhotoUrl != null
                                                      ? Image.network(
                                                          item.fullPhotoUrl!,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context, err, stack) => const Icon(Icons.broken_image_rounded, size: 20, color: Colors.grey),
                                                        )
                                                      : const Icon(Icons.image_rounded, size: 20, color: Colors.grey),
                                                ),
                                              ),
                                              DataCell(
                                                Container(
                                                  constraints: const BoxConstraints(maxWidth: 150),
                                                  child: Text(
                                                    item.name,
                                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ),
                                              DataCell(Text(item.type)),
                                              DataCell(
                                                Container(
                                                  constraints: const BoxConstraints(maxWidth: 120),
                                                  child: Text(
                                                    item.variants.map((v) => '${v.size} (${v.quantity})').join(', '),
                                                    style: const TextStyle(fontSize: 12),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ),
                                              DataCell(Text(item.gender)),
                                              DataCell(Text(item.formattedPriceRange)),
                                              DataCell(Text('${item.quantity}')),
                                              DataCell(
                                                Container(
                                                  constraints: const BoxConstraints(maxWidth: 150),
                                                  child: Tooltip(
                                                    message: item.variants.map((v) => '${v.size}: ${v.barcode ?? "-"}').join('\n'),
                                                    child: Text(
                                                      item.variants.map((v) => v.barcode ?? '-').join(' / '),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                      style: const TextStyle(fontSize: 12),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                                      onPressed: () => _showItemForm(item: item),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                                      onPressed: () => _confirmDelete(item),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    if (widget.itemController.isLoadingMore)
                                      const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Center(
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _mobileScrollController,
                              itemCount: filteredItems.length + (widget.itemController.isLoadingMore ? 1 : 0),
                              itemBuilder: (context, idx) {
                                if (idx == filteredItems.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  );
                                }
                                final item = filteredItems[idx];
                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    leading: Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: item.fullPhotoUrl != null
                                          ? Image.network(
                                              item.fullPhotoUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, err, stack) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
                                            )
                                          : const Icon(Icons.image_rounded, color: Colors.grey),
                                    ),
                                    title: Text('${item.name} (${item.gender})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                      'Tipo: ${item.type} | Precio: ${item.formattedPriceRange} | Stock: ${item.quantity}\n'
                                      'Tallas: ${item.variants.map((v) => '${v.size} (${v.quantity})').join(', ')}'
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                          onPressed: () => _showItemForm(item: item),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                          onPressed: () => _confirmDelete(item),
                                        ),
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
        },
      ),
    );
  }
}

class _ItemFormDialog extends StatefulWidget {
  final ItemController itemController;
  final ImagePicker imagePicker;
  final Item? item; // Null for add, non-null for edit

  const _ItemFormDialog({
    required this.itemController,
    required this.imagePicker,
    this.item,
  });

  @override
  State<_ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends State<_ItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  final List<XFile> _selectedImages = [];
  List<String> _existingPhotos = [];
  bool _isLoadingPhotos = false;
  bool _isSaving = false;

  static const List<String> _categories = [
    'Camisa',
    'Pantalón',
    'Vestido',
    'Abrigo',
    'Calzado',
    'Accesorios',
    'Otros',
  ];
  static const List<String> _sizes = [
    'Única', 'XS', 'S', 'M', 'L', 'XL', 'XXL', '36', '38', '40', '42', '44'
  ];
  static const List<String> _genders = [
    'Unisex', 'Hombre', 'Mujer', 'Niño', 'Niña'
  ];
  late String _selectedType;
  late String _selectedGender;
  final List<Map<String, dynamic>> _variants = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _priceController = TextEditingController(text: widget.item?.price.toString() ?? '');
    _selectedType = widget.item?.type ?? 'Otros';
    if (!_categories.contains(_selectedType)) {
      _selectedType = 'Otros';
    }
    _selectedGender = widget.item?.gender ?? 'Unisex';
    if (!_genders.contains(_selectedGender)) {
      _selectedGender = 'Unisex';
    }

    if (widget.item != null && widget.item!.variants.isNotEmpty) {
      for (final v in widget.item!.variants) {
        _variants.add({
          'id': v.id,
          'size': v.size,
          'quantity': v.quantity,
          'barcode': v.barcode ?? '',
          'price': v.price,
          'qtyController': TextEditingController(text: v.quantity.toString()),
          'barcodeController': TextEditingController(text: v.barcode ?? ''),
          'priceController': TextEditingController(text: v.price.toString()),
        });
      }
    } else {
      _variants.add({
        'id': null,
        'size': 'Única',
        'quantity': 1,
        'barcode': '',
        'price': 0.0,
        'qtyController': TextEditingController(text: '1'),
        'barcodeController': TextEditingController(text: ''),
        'priceController': TextEditingController(text: widget.item?.price.toString() ?? ''),
      });
    }

    if (widget.item != null) {
      _isLoadingPhotos = true;
      widget.itemController.fetchItemPhotos(widget.item!.id).then((photos) {
        if (mounted) {
          setState(() {
            _existingPhotos = [
              if (widget.item!.fullPhotoUrl != null) widget.item!.fullPhotoUrl!,
              ...photos,
            ];
            _isLoadingPhotos = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    for (final v in _variants) {
      (v['qtyController'] as TextEditingController).dispose();
      (v['barcodeController'] as TextEditingController).dispose();
      (v['priceController'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    final currentTotal = _selectedImages.length + _existingPhotos.length;
    if (currentTotal >= 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se permite un máximo de 5 fotos en total.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      List<XFile> picked = await widget.imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked.isNotEmpty) {
        final remainingSlots = 5 - currentTotal;
        if (picked.length > remainingSlots) {
          picked = picked.sublist(0, remainingSlots);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Se redujo la selección al límite máximo de 5 fotos.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
        setState(() {
          _selectedImages.addAll(picked);
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  String _toRelativePath(String fullUrl) {
    const prefix = '/uploads/';
    final idx = fullUrl.indexOf(prefix);
    if (idx != -1) {
      return fullUrl.substring(idx);
    }
    return fullUrl;
  }

  Widget _buildImageSection() {
    if (_isLoadingPhotos) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final hasImages = _selectedImages.isNotEmpty || _existingPhotos.isNotEmpty;

    if (!hasImages) {
      return GestureDetector(
        onTap: _pickImages,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.add_a_photo_rounded, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Seleccionar Fotos (Máx 5)',
                style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...List.generate(
                _existingPhotos.length,
                (index) {
                  final photoUrl = _existingPhotos[index];
                  return Container(
                    width: 90,
                    height: 100,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, err, stack) => const Icon(Icons.broken_image_rounded),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _existingPhotos.removeAt(index);
                              });
                            },
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ...List.generate(
                _selectedImages.length,
                (index) {
                  final localPhoto = _selectedImages[index];
                  return Container(
                    width: 90,
                    height: 100,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.file(
                            File(localPhoto.path),
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImages.removeAt(index);
                              });
                            },
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_existingPhotos.length + _selectedImages.length} de 5 fotos seleccionadas',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (_existingPhotos.length + _selectedImages.length < 5)
              TextButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_a_photo_rounded, size: 16),
                label: const Text('Agregar fotos', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1E3C72),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0.0;

    final List<Map<String, dynamic>> variantsToSend = [];
    for (final v in _variants) {
      final sizeVal = v['size'] as String;
      final qtyText = (v['qtyController'] as TextEditingController).text.trim();
      final qtyVal = int.tryParse(qtyText) ?? 0;
      final barcodeVal = (v['barcodeController'] as TextEditingController).text.trim();
      final priceText = (v['priceController'] as TextEditingController).text.trim();
      final priceVal = double.tryParse(priceText) ?? price;

      variantsToSend.add({
        if (v['id'] != null) 'id': v['id'],
        'size': sizeVal,
        'quantity': qtyVal,
        'barcode': barcodeVal.isEmpty ? null : barcodeVal,
        'price': priceVal,
      });
    }

    final totalQty = variantsToSend.fold<int>(0, (sum, v) => sum + (v['quantity'] as int));

    final List<String> photoPathsToSend = _selectedImages.map((e) => e.path).toList();
    final List<String> relativeExistingPhotos = _existingPhotos.map((url) => _toRelativePath(url)).toList();

    bool success;
    if (widget.item == null) {
      success = await widget.itemController.addItem(
        name: name,
        price: price,
        quantity: totalQty,
        type: _selectedType,
        variants: variantsToSend,
        photoPaths: photoPathsToSend,
        barcode: variantsToSend.isNotEmpty ? variantsToSend.first['barcode'] as String? : null,
        size: variantsToSend.isNotEmpty ? variantsToSend.first['size'] as String : 'Única',
        gender: _selectedGender,
      );
    } else {
      success = await widget.itemController.editItem(
        id: widget.item!.id,
        name: name,
        price: price,
        quantity: totalQty,
        type: _selectedType,
        variants: variantsToSend,
        photoPaths: photoPathsToSend,
        existingPhotos: relativeExistingPhotos,
        barcode: variantsToSend.isNotEmpty ? variantsToSend.first['barcode'] as String? : null,
        size: variantsToSend.isNotEmpty ? variantsToSend.first['size'] as String : 'Única',
        gender: _selectedGender,
      );
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.item == null ? 'Artículo agregado.' : 'Artículo actualizado.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.itemController.errorMessage ?? 'Error al guardar artículo.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;

    return AlertDialog(
      title: Text(isEdit ? 'Editar Artículo de Ropa' : 'Agregar Artículo de Ropa'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Picker Area
              _buildImageSection(),
              const SizedBox(height: 20),
              // Name textfield
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre de Prenda',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Ingrese el nombre' : null,
              ),
              const SizedBox(height: 16),
              // Price textfield
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Precio (\$)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Ingrese el precio';
                  final num = double.tryParse(val);
                  if (num == null || num < 0) return 'Precio inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              // Type dropdown
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Tipo de Prenda',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedType = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              // Gender dropdown
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: InputDecoration(
                  labelText: 'Género de Prenda',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _genders.map((gen) {
                  return DropdownMenuItem(
                    value: gen,
                    child: Text(gen),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedGender = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Variantes de Talla y Stock',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3C72)),
              ),
              const SizedBox(height: 10),
              Column(
                children: List.generate(_variants.length, (idx) {
                  final v = _variants[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            // Size dropdown
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: v['size'],
                                decoration: const InputDecoration(
                                  labelText: 'Talla',
                                  border: UnderlineInputBorder(),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                items: _sizes.map((sz) {
                                  return DropdownMenuItem(value: sz, child: Text(sz));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      v['size'] = val;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Quantity text field
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: v['qtyController'],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Stock',
                                  border: UnderlineInputBorder(),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'Stock';
                                  final num = int.tryParse(val);
                                  if (num == null || num < 0) return 'Err';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Price text field
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: v['priceController'],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Precio',
                                  border: UnderlineInputBorder(),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'Precio';
                                  final num = double.tryParse(val);
                                  if (num == null || num < 0) return 'Err';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_variants.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                onPressed: () {
                                  setState(() {
                                    _variants.removeAt(idx);
                                  });
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Barcode row
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: v['barcodeController'],
                                decoration: const InputDecoration(
                                  labelText: 'Código de Barras',
                                  border: UnderlineInputBorder(),
                                  prefixIcon: Icon(Icons.qr_code_scanner_rounded, size: 18),
                                  hintText: 'Autogenerado si vacío',
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                final rand = math.Random();
                                final num = 100000000 + rand.nextInt(900000000);
                                setState(() {
                                  (v['barcodeController'] as TextEditingController).text = '779$num';
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade50,
                                foregroundColor: const Color(0xFF1E3C72),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: const Text('Generar', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _variants.add({
                      'id': null,
                      'size': 'Única',
                      'quantity': 1,
                      'barcode': '',
                      'price': 0.0,
                      'qtyController': TextEditingController(text: '1'),
                      'barcodeController': TextEditingController(text: ''),
                      'priceController': TextEditingController(text: _priceController.text.isNotEmpty ? _priceController.text : '0.0'),
                    });
                  });
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Agregar Variante/Talla', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E3C72),
                  side: const BorderSide(color: Color(0xFF1E3C72)),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              (() {
                final firstBarcode = _variants.isNotEmpty
                    ? (_variants.first['barcodeController'] as TextEditingController).text.trim()
                    : '';
                if (firstBarcode.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: BarcodeWidget(
                          barcode: Barcode.code128(),
                          data: firstBarcode,
                          width: 200,
                          height: 80,
                          drawText: true,
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              })(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3C72),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
