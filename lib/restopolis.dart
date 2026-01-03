import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

import 'device.dart';

final FlutterSecureStorage _storage = const FlutterSecureStorage();

class RestopolisApi {
  static const String baseUrl = 'https://ssl.education.lu/eRestauration/API/WebApp';
  static const String apiUser = 'restopolis-api';
  static const String apiPassword = "{qYVWE'fL/hA}!jY*~zEf*BG59:9&}^z";

  final Dio _dio;
  String? _machineId;

  RestopolisApi() : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 10),
    validateStatus: (status) => status! < 500, // Don't throw on 4xx
  )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add Basic Auth
        final credentials = base64Encode(
            utf8.encode('$apiUser:$apiPassword')
        );
        options.headers['Authorization'] = 'Basic $credentials';

        // Add MachineId
        _machineId ??= await DeviceIdService.getHardwareId();
        options.headers['MachineId'] = _machineId;

        options.headers['Content-Type'] = 'application/json';
        options.headers['Accept'] = 'application/json';

        print('Request: ${options.method} ${options.uri}');
        print('Headers: ${options.headers}');

        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('Response: ${response.statusCode}');
        print('Data: ${response.data}');
        return handler.next(response);
      },
      onError: (error, handler) {
        print('Error: ${error.message}');
        print('Response: ${error.response?.data}');
        return handler.next(error);
      },
    ));
  }

  // Get all sites and restaurants
  Future<String> getSitesAndRestaurants() async {
    final response = await _dio.get('/v1/sites-restaurants');
    return response.toString();
  }

  // Get daily menu
  Future<Map<String, dynamic>> getMenu({
    required int restaurantId,
    required int serviceId,
    required DateTime date,
  }) async {
    final response = await _dio.get(
      '/v1/GetOrderedFormulaProducts/$restaurantId/$serviceId/${date.toIso8601String()}',
    );
    return response.data;
  }

  // Pair account with code
  Future<Map<String, dynamic>> pairAccount({
    required String username,
    required String key,
  }) async {
    final response = await _dio.post('/v1/account', data: {
      'customerLogin': username,
      'key': key,
      'deviceName': "phone",
      'hardwareId': await DeviceIdService.getHardwareId(),
    });
    return response.data;
  }

  // Get user's reservations
  Future<List<dynamic>> getReservations(int customerId) async {
    final response = await _dio.get('/v1/GetReservations/$customerId');
    return response.data['reservations'] ?? [];
  }

  // Make a reservation
  Future<Map<String, dynamic>> makeReservation({
    required int customerId,
    required int restaurantId,
    required int serviceId,
    required DateTime date,
    required List<Map<String, dynamic>> products,
  }) async {
    final response = await _dio.post('/v1/MakeReservation', data: {
      'customerId': customerId,
      'restaurantId': restaurantId,
      'serviceId': serviceId,
      'date': date.toIso8601String(),
      'products': products,
    });
    return response.data;
  }

  // Cancel reservation
  Future<bool> cancelReservation(int reservationId) async {
    final response = await _dio.delete('/v1/CancelReservation/$reservationId');
    return response.data['success'] ?? false;
  }

  // Get account balance/history
  Future<Map<String, dynamic>> getHistory(int customerId) async {
    final response = await _dio.get('/v1/GetHistory/$customerId');
    return response.data;
  }

  // Get news
  Future<List<dynamic>> getNews() async {
    final response = await _dio.get('/v1/news');
    return response.data['news'] ?? [];
  }

  // Get payment link (SaferPay - credit card)
  Future<String> getSaferPayLink({
    required int accountId,
    required double value,
    required String language,
  }) async {
    final response = await _dio.get(
      '/v1/saferpay/$accountId/$value/$language',
    );
    return response.data['url'];
  }

  // Get Payconiq link (mobile payment)
  Future<Map<String, dynamic>> getPayconiqLink({
    required String accountId,
    required int value,
    String? returnUrl
  }) async {
    final response = await _dio.get(
      '/v1/GetPayconiqLink/$accountId/$value',
      queryParameters: returnUrl != null ? {'returnUrl': returnUrl} : null,
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getRestaurant(int restaurantId) async {
    final response = await _dio.get('/v1/restaurant/$restaurantId');
    return response.data;
  }

  Future<Map<String, dynamic>> getAccounts() async {
    final response = await _dio.get('/v1/account/${await DeviceIdService.getHardwareId()}');
    return response.data;
  }

  Future<bool> removeAccount(String customerId) async {
    final response = await _dio.delete('/v1/account/$customerId/${await DeviceIdService.getHardwareId()}');
    return response.data["code"] == 0;
  }
}

RestopolisApi _api = RestopolisApi();

class UserManager {
  
  static bool? _loggedIn;
  
  static Future<bool> isLoggedIn() async {
    if(_loggedIn != null) {
      return _loggedIn!;
    }
    _loggedIn = (await _storage.read(key: "loggedIn") ?? "false") == "true";
    return _loggedIn!;
  }
  
  
  
  static Future<bool> _confirmLogout(BuildContext context) async {
    var confirmed = await showDialog<bool>(context: context, builder: (context) {
      return AlertDialog(
        title: Text("Do you really want to sign out?"),
        actions: [
          TextButton(
            child: Text("Yes"),
            onPressed: () {
              Navigator.pop(context, true);
            },
          ),
          FilledButton(
            child: Text("No"),
            onPressed: () {
              Navigator.pop(context, false);
            },
          )
        ],
      );
    });
    return confirmed ?? false;
  }

  static Future<String> _getCustomerId() async {
    return await _storage.read(key: "customerId") ?? "";
  }

  static void logout(BuildContext context) async {
    var confirmed = await _confirmLogout(context);
    if(!confirmed) return;
    var result = await _api.removeAccount(await _getCustomerId());
    if(!result) {
      if(context.mounted) {
        showError(context, "Error occured while logging out, please try again later");
      }
      return;
    }
    _storage.delete(key: "loggedIn");
    _loggedIn = false;
    if(context.mounted) {
      Navigator.pop(context);
    }
  }

}

class RestaurantManager {
  static List<Restaurant>? _selectedRestaurants;
  static List<Restaurant>? _allRestaurants;
  static final Map<int, int> _serviceIds = {};
  static Future<String> _getRestaurantData() async {
    if(await _storage.containsKey(key: "restaurantData")) {
      return await _storage.read(key: "restaurantData") ?? "";
    }
    var result = await _api.getSitesAndRestaurants();
    await _storage.write(key: "restaurantData", value: result);
    return result;
  }
  static Future<List<Restaurant>> getSelectedRestaurants() async {
    if(_selectedRestaurants != null) {
      return _selectedRestaurants!;
    }
    final rawSelectedRestaurants = await _storage.read(key: "restaurantIds") ?? "[]";
    List<Restaurant> result = List.empty(growable: true);
    var restaurants = jsonDecode(rawSelectedRestaurants);
    for(var restaurant in restaurants) {
      result.add(
        Restaurant(
          restaurant["id"],
          restaurant["name"],
          restaurant["siteName"]
        )
      );
    }
    return result;
  }
  static Future<void> selectRestaurant(Restaurant restaurant) async {
    var selectedRestaurants = await getSelectedRestaurants();
    selectedRestaurants.add(restaurant);
    _saveRestaurants(selectedRestaurants);
  }
  static Future<void> removeRestaurant(int index) async {
    var selectedRestaurants = await getSelectedRestaurants();
    selectedRestaurants.removeAt(index);
    _saveRestaurants(selectedRestaurants);
  }
  static void _saveRestaurants(List<Restaurant> selectedRestaurants) {
    String jsonString = jsonEncode(
        selectedRestaurants.map((r) => r.toJson()).toList()
    );
    _storage.write(key: "restaurantIds", value: jsonString);
  }
  static Future<int> getServiceId(Restaurant restaurant) async {
    if(_serviceIds.containsKey(restaurant.id)) {
      return _serviceIds[restaurant.id]!;
    }
    var result = await _api.getRestaurant(restaurant.id);
    if(result["code"] != 0) return 0;
    _serviceIds[restaurant.id] = result["objects"][0]["services"][0]["id"];
    return result["objects"][0]["services"][0]["id"];
  }
  static Future<List<Restaurant>> getAllRestaurants() async {
    if(_allRestaurants != null) {
      return _allRestaurants!;
    }
    String data = await _getRestaurantData();
    Map<String, dynamic> json = jsonDecode(data);
    List<Restaurant> result = List.empty(growable: true);
    for(var site in json["objects"]) {
      for(var restaurant in site["restaurants"]) {
        result.add(
          Restaurant(
            restaurant["id"],
            restaurant["name"],
            site["name"]
          )
        );
      }
    }
    _allRestaurants = result;
    return result;
  }
}

class Restaurant {
  int id;
  String name;
  String siteName;
  Restaurant(this.id, this.name, this.siteName);
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'siteName': siteName,
    };
  }
}

class MenuManager {
  static Map<int, Map<DateTime, Map<String, dynamic>>> cache = {};
  static Future<Map<String, dynamic>> getCachedMenu(Restaurant restaurant, DateTime date) async {
    if(cache.containsKey(restaurant.id)) {
      if(cache[restaurant.id]!.containsKey(DateTime(date.year, date.month, date.day))) {
        return cache[restaurant.id]![DateTime(date.year, date.month, date.day)]!;
      }
    }
    var data = await _api.getMenu(restaurantId: restaurant.id, serviceId: await RestaurantManager.getServiceId(restaurant), date: date);
    if(cache[restaurant.id] == null) {
      cache[restaurant.id] = {};
    }
    cache[restaurant.id]![DateTime(date.year, date.month, date.day)] = data;
    return data;
  }
  static Future<Map<Restaurant, Menu>> getMenuForDate(DateTime date) async {
    Map<Restaurant, Map<String, dynamic>> menus = {};
    Map<Restaurant, Menu> result = {};
    for(var restaurant in await RestaurantManager.getSelectedRestaurants()) {
      menus[restaurant] = await getCachedMenu(restaurant, date);
    }
    for(var menu in menus.entries) {
      List<Gang> gangs = List.empty(growable: true);
      for(var gang in menu.value["objects"]) {
        List<Product> products = List.empty(growable: true);
        for(var product in gang["products"]) {
          List<int> allergens = List.empty(growable: true);
          for(var allergen in product["allergens"]) {
            allergens.add(allergen);
          }
          products.add(
            Product(
              product["names"]["fr"] ?? "",
              allergens
            )
          );
        }
        gangs.add(
          Gang(
            gang["names"]["fr"] ?? "",
            products
          )
        );
      }
      result[menu.key] = Menu(gangs, menu.key);
    }
    return result;
  }
}

class Menu {
  Restaurant restaurant;
  List<Gang> gangs;
  Menu(this.gangs, this.restaurant);
}

class Gang {
  String name;
  List<Product> products;
  Gang(this.name, this.products);
}

class Product {
  String name;
  List<int> allergens;
  Product(this.name, this.allergens);
}

void showError(BuildContext context, String message) {
  showDialog(context: context, builder: (context) {
    return AlertDialog(
      title: Text(message),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text("Ok"),
        )
      ],
    );
  });
}