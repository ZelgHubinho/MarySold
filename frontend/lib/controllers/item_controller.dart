import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/item.dart';

class ItemController extends ChangeNotifier {
  List<Item> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final int _limit = 12;
  bool _isPaginatedMode = true;

  List<Item> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  bool get isPaginatedMode => _isPaginatedMode;

  final ApiClient _apiClient = ApiClient.instance;

  Future<void> fetchItems({bool isRefresh = true, bool? paginate}) async {
    if (paginate != null) {
      _isPaginatedMode = paginate;
    }

    if (isRefresh) {
      _currentPage = 1;
      _hasMore = true;
      _isLoading = true;
      _errorMessage = null;
      if (_isPaginatedMode) notifyListeners();
    } else {
      if (!_isPaginatedMode || !_hasMore || _isLoading || _isLoadingMore) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      final String url = _isPaginatedMode
          ? '/items?page=$_currentPage&limit=$_limit'
          : '/items';
      final response = await _apiClient.get(url);
      final decoded = jsonDecode(response.body);

      List<dynamic> itemsList;
      int total = 0;

      if (decoded is Map<String, dynamic>) {
        itemsList = decoded['items'] as List<dynamic>;
        total = decoded['totalItems'] as int;
      } else {
        itemsList = decoded as List<dynamic>;
        total = itemsList.length;
      }

      final List<Item> newItems = itemsList.map((json) => Item.fromJson(json)).toList();

      if (isRefresh) {
        _items = newItems;
      } else {
        _items.addAll(newItems);
      }

      _hasMore = _isPaginatedMode && _items.length < total;
      if (_hasMore) {
        _currentPage++;
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to load items. Check server connection.';
      debugPrint('Error fetching items: $e');
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<bool> addItem({
    required String name,
    required double price,
    required int quantity,
    required String type,
    required List<Map<String, dynamic>> variants,
    List<String>? photoPaths,
    String? barcode,
    String? size,
    String? gender,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fields = {
        'name': name,
        'price': price.toString(),
        'quantity': quantity.toString(),
        'type': type,
        'variants': jsonEncode(variants),
      };
      if (barcode != null) {
        fields['barcode'] = barcode;
      }
      if (size != null) {
        fields['size'] = size;
      }
      if (gender != null) {
        fields['gender'] = gender;
      }

      if (photoPaths != null && photoPaths.isNotEmpty) {
        await _apiClient.multipartList(
          'POST',
          '/items',
          fields,
          'photos',
          photoPaths,
        );
      } else {
        await _apiClient.multipart(
          'POST',
          '/items',
          fields,
        );
      }

      // Refresh item list
      await fetchItems();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to add item. Check server connection.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> editItem({
    required int id,
    required String name,
    required double price,
    required int quantity,
    required String type,
    required List<Map<String, dynamic>> variants,
    List<String>? photoPaths,
    List<String>? existingPhotos,
    String? barcode,
    String? size,
    String? gender,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fields = {
        'name': name,
        'price': price.toString(),
        'quantity': quantity.toString(),
        'type': type,
        'variants': jsonEncode(variants),
      };
      if (barcode != null) {
        fields['barcode'] = barcode;
      }
      if (existingPhotos != null) {
        fields['existingPhotos'] = jsonEncode(existingPhotos);
      }
      if (size != null) {
        fields['size'] = size;
      }
      if (gender != null) {
        fields['gender'] = gender;
      }

      if (photoPaths != null && photoPaths.isNotEmpty) {
        await _apiClient.multipartList(
          'PUT',
          '/items/$id',
          fields,
          'photos',
          photoPaths,
        );
      } else {
        await _apiClient.multipart(
          'PUT',
          '/items/$id',
          fields,
        );
      }

      // Refresh item list
      await fetchItems();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to update item. Check server connection.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<List<String>> fetchItemPhotos(int itemId) async {
    try {
      final response = await _apiClient.get('/items/$itemId/photos');
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.map((photo) {
          final relativeUrl = photo['photo_url'] as String;
          if (relativeUrl.startsWith('http')) return relativeUrl;
          return '${ApiConstants.mediaUrl}$relativeUrl';
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching secondary photos: $e');
      return [];
    }
  }

  Future<Item?> fetchItemByBarcode(String barcode) async {
    _errorMessage = null;
    try {
      final response = await _apiClient.get('/items/barcode/$barcode');
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('error')) {
          _errorMessage = decoded['error'];
          return null;
        }
        return Item.fromJson(decoded);
      }
      return null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (e) {
      _errorMessage = 'Error al buscar el código de barras.';
      debugPrint('Error fetching item by barcode: $e');
      return null;
    }
  }

  Future<bool> deleteItem(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiClient.delete('/items/$id');
      
      // Remove local copy directly to make it faster
      _items.removeWhere((item) => item.id == id);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to delete item.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> checkout(Map<CartItem, int> cart) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Map cart to backend format: { "items": [ { "id": X, "variantId": Z, "quantity": Y }, ... ] }
      final cartData = cart.entries.map((entry) {
        return {
          'id': entry.key.item.id,
          'variantId': entry.key.variant.id,
          'quantity': entry.value,
        };
      }).toList();

      await _apiClient.post('/items/checkout', {
        'items': cartData,
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error al procesar el cobro. Verifique su conexión.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
