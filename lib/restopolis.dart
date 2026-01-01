import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

import 'device.dart';

class RestopolisService {
  static const String baseUrl = 'https://ssl.education.lu/eRestauration/API/WebApp';
  static const String apiUser = 'restopolis-api';
  static const String apiPassword = "{qYVWE'fL/hA}!jY*~zEf*BG59:9&}^z";

  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _machineId;

  RestopolisService() : _dio = Dio(BaseOptions(
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

  Future<String> _getMachineId() async {
    String? machineId = await _storage.read(key: 'machineId');
    if (machineId == null) {
      machineId = _generateMachineId();
      await _storage.write(key: 'machineId', value: machineId);
    }
    return machineId;
  }

  String _generateMachineId() {
    // Generate unique device ID (similar to their mS() function)
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (DateTime.now().microsecond % 10000).toString();
  }

  // Get all sites and restaurants
  Future<Map<String, dynamic>> getSitesAndRestaurants() async {
    final response = await _dio.get('/v1/sites-restaurants');
    return response.data;
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
    required String hardwareId,
  }) async {
    final response = await _dio.post('/v1/account', data: {
      'customerLogin': username,
      'key': key,
      'deviceName': "phone",
      'hardwareId': hardwareId,
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

  Future<Map<String, dynamic>> getAccounts(String hardwareId) async {
    final response = await _dio.get('/v1/account/$hardwareId');
    return response.data;
  }

  Future<Map<String, dynamic>> removeAccount(String customerId, String hardwareId) async {
    final response = await _dio.delete('/v1/account/$customerId/$hardwareId');
    return response.data;
  }
}