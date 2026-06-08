import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/item.dart';

class ItemController extends ChangeNotifier {
  List<Item> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Item> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  final ApiClient _apiClient = ApiClient.instance;

  Future<void> fetchItems() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('/items');
      final List<dynamic> data = jsonDecode(response.body);
      _items = data.map((json) => Item.fromJson(json)).toList();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to load items. Check server connection.';
      debugPrint('Error fetching items: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addItem({
    required String name,
    required double price,
    required int quantity,
    required String type,
    String? photoPath,
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
      };

      await _apiClient.multipart(
        'POST',
        '/items',
        fields,
        fileKey: photoPath != null ? 'photo' : null,
        filePath: photoPath,
      );

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
    String? photoPath,
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
      };

      await _apiClient.multipart(
        'PUT',
        '/items/$id',
        fields,
        fileKey: photoPath != null ? 'photo' : null,
        filePath: photoPath,
      );

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

  Future<bool> checkout(Map<Item, int> cart) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Map cart to backend format: { "items": [ { "id": X, "quantity": Y }, ... ] }
      final cartData = cart.entries.map((entry) {
        return {
          'id': entry.key.id,
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
