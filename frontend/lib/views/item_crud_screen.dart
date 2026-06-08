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
                                    ? Row(
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
                                    headers: const ['ID', 'Nombre', 'Tipo', 'Precio', 'Stock'],
                                    onFetchData: () {
                                      return filteredItems.map((item) {
                                        return [
                                          item.id.toString(),
                                          item.name,
                                          item.type,
                                          '\$${item.price.toStringAsFixed(2)}',
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
                                              DataCell(Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                              DataCell(Text(item.type)),
                                              DataCell(Text('\$${item.price.toStringAsFixed(2)}')),
                                              DataCell(Text('${item.quantity}')),
                                              DataCell(Text(item.barcode ?? '-')),
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
                                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('Tipo: ${item.type} | Precio: \$${item.price.toStringAsFixed(2)} | Stock: ${item.quantity}\nCódigo: ${item.barcode ?? "-"}'),
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
  late TextEditingController _quantityController;
  late TextEditingController _barcodeController;
  XFile? _selectedImage;
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
  late String _selectedType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _priceController = TextEditingController(text: widget.item?.price.toString() ?? '');
    _quantityController = TextEditingController(text: widget.item?.quantity.toString() ?? '');
    _barcodeController = TextEditingController(text: widget.item?.barcode ?? '');
    _selectedType = widget.item?.type ?? 'Otros';
    if (!_categories.contains(_selectedType)) {
      _selectedType = 'Otros';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  void _generateBarcode() {
    final rand = math.Random();
    // Generate 9 digit random number
    final num = 100000000 + rand.nextInt(900000000);
    setState(() {
      _barcodeController.text = '779$num';
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await widget.imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    final price = double.parse(_priceController.text);
    final quantity = int.parse(_quantityController.text);
    final barcode = _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim();

    bool success;
    if (widget.item == null) {
      // Add new item
      success = await widget.itemController.addItem(
        name: name,
        price: price,
        quantity: quantity,
        type: _selectedType,
        photoPath: _selectedImage?.path,
        barcode: barcode,
      );
    } else {
      // Edit existing item
      success = await widget.itemController.editItem(
        id: widget.item!.id,
        name: name,
        price: price,
        quantity: quantity,
        type: _selectedType,
        photoPath: _selectedImage?.path,
        barcode: barcode,
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
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _selectedImage != null
                      ? Image.file(File(_selectedImage!.path), fit: BoxFit.cover)
                          : isEdit && widget.item!.fullPhotoUrl != null
                              ? Image.network(
                                  widget.item!.fullPhotoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, err, stack) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40)),
                                )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.add_a_photo_rounded, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Seleccionar Foto', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                ),
              ),
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
              // Quantity textfield
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Cantidad en Stock',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Ingrese la cantidad';
                  final num = int.tryParse(val);
                  if (num == null || num < 0) return 'Cantidad inválida';
                  return null;
                },
              ),
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
              // Barcode field
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeController,
                      decoration: InputDecoration(
                        labelText: 'Código de Barras',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                        hintText: 'Autogenerado si se deja vacío',
                      ),
                      onChanged: (val) {
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _generateBarcode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: const Color(0xFF1E3C72),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Generar'),
                  ),
                ],
              ),
              if (_barcodeController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: _barcodeController.text.trim(),
                      width: 200,
                      height: 80,
                      drawText: true,
                    ),
                  ),
                ),
              ],
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
