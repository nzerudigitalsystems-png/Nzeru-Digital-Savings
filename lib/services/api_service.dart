import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Central API service handling all HTTP calls to the Django backend.
/// Tokens are persisted to SharedPreferences so sessions survive app restarts.
class ApiService {
  static const String _defaultBaseUrl =
      'https://nzeru-digital-savings-production-27a02bec.up.railway.app/api';
  static const String _envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static String get baseUrl {
    final configuredUrl = _envBaseUrl.trim();
    return configuredUrl.endsWith('/')
        ? configuredUrl.substring(0, configuredUrl.length - 1)
        : configuredUrl;
  }

  String? _accessToken;
  String? _refreshToken;

  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  bool get isAuthenticated => _accessToken?.trim().isNotEmpty == true;
  bool get canRefresh => _refreshToken?.trim().isNotEmpty == true;

  // ─── Token Persistence ──────────────────────────────

  /// Call once at startup (in main.dart) to restore any saved session.
  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString('access_token')?.trim();
    final refresh = prefs.getString('refresh_token')?.trim();
    _accessToken = access?.isNotEmpty == true ? access : null;
    _refreshToken = refresh?.isNotEmpty == true ? refresh : null;
  }

  Future<void> _saveTokens() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken?.trim().isNotEmpty == true) {
      await prefs.setString('access_token', _accessToken!.trim());
    } else {
      await prefs.remove('access_token');
    }
    if (_refreshToken?.trim().isNotEmpty == true) {
      await prefs.setString('refresh_token', _refreshToken!.trim());
    } else {
      await prefs.remove('refresh_token');
    }
  }

  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  // ─── Headers ────────────────────────────────────────

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_accessToken?.trim().isNotEmpty == true) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  // ─── Core HTTP helpers with auto-refresh ────────────

  /// GET with automatic token refresh on 401.
  Future<http.Response> _get(String path) async {
    var response = await http
        .get(Uri.parse('$baseUrl$path'), headers: _headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      final refreshed = await refreshToken();
      if (refreshed) {
        response = await http
            .get(Uri.parse('$baseUrl$path'), headers: _headers)
            .timeout(const Duration(seconds: 30));
      }
    }
    return response;
  }

  /// POST with automatic token refresh on 401.
  Future<http.Response> _post(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    final headers = requiresAuth
        ? _headers
        : {'Content-Type': 'application/json', 'Accept': 'application/json'};

    var response = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401 && requiresAuth) {
      final refreshed = await refreshToken();
      if (refreshed) {
        response = await http
            .post(
              Uri.parse('$baseUrl$path'),
              headers: _headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(const Duration(seconds: 30));
      }
    }
    return response;
  }

  Future<http.Response> _patch(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    final headers = requiresAuth
        ? _headers
        : {'Content-Type': 'application/json', 'Accept': 'application/json'};

    var response = await http
        .patch(
          Uri.parse('$baseUrl$path'),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401 && requiresAuth) {
      final refreshed = await refreshToken();
      if (refreshed) {
        response = await http
            .patch(
              Uri.parse('$baseUrl$path'),
              headers: _headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(const Duration(seconds: 30));
      }
    }
    return response;
  }

  // ─── Auth ────────────────────────────────────────────

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String password2,
    String firstName = '',
    String lastName = '',
    String phone = '',
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedUsername = username.trim().isEmpty
        ? normalizedEmail
        : username.trim();
    try {
      final response = await _post(
        '/auth/register/',
        body: {
          'username': normalizedUsername,
          'email': normalizedEmail,
          'password': password,
          'password2': password2,
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'phone': phone.trim(),
        },
        requiresAuth: false,
      );
      return _handleResponse(response);
    } on SocketException catch (e) {
      throw Exception(
        'Network error: ${e.message}. Check your internet connection.',
      );
    } on http.ClientException {
      throw Exception(
        'Unable to reach the API. Check API_BASE_URL and confirm the backend URL is live.',
      );
    } on TimeoutException {
      throw Exception('Request timeout. Server took too long to respond.');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final identifier = username.trim();
    try {
      final response = await _post(
        '/auth/login/',
        body: {'username': identifier, 'password': password},
        requiresAuth: false,
      );
      final data = _handleResponse(response);
      _accessToken = (data['access'] as String?)?.trim();
      _refreshToken = (data['refresh'] as String?)?.trim();
      if (_accessToken == null || _accessToken!.isEmpty || _refreshToken == null || _refreshToken!.isEmpty) {
        await logout();
        throw Exception('Authentication response missing access or refresh token.');
      }
      await _saveTokens();
      return data;
    } on SocketException catch (e) {
      throw Exception(
        'Network error: ${e.message}. Check your internet connection.',
      );
    } on http.ClientException {
      throw Exception(
        'Unable to reach the API. Check API_BASE_URL and confirm the backend URL is live.',
      );
    } on TimeoutException {
      throw Exception('Login timeout. Server took too long to respond.');
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> refreshToken() async {
    if (_refreshToken == null) return false;
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/refresh/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh': _refreshToken}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final access = (data['access'] as String?)?.trim();
        final refresh = (data['refresh'] as String?)?.trim();
        if (access == null || access.isEmpty) {
          await logout();
          return false;
        }
        _accessToken = access;
        if (refresh?.isNotEmpty == true) {
          _refreshToken = refresh;
        }
        await _saveTokens();
        return true;
      }
      // Refresh token expired or invalid — clear everything
      await logout();
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    await _clearTokens();
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await _get('/auth/me/');
    return _handleResponse(response);
  }

  // ─── Dashboard (single-call) ─────────────────────────

  Future<Map<String, dynamic>> getDashboard() async {
    final response = await _get('/dashboard/');
    return _handleResponse(response);
  }

  // ─── Profile ─────────────────────────────────────────

  Future<Map<String, dynamic>> recalculateProfile() async {
    final response = await _post('/profile/recalculate/');
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> data) async {
    final response = await _patch('/profile/settings/', body: data);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _post(
      '/profile/change_password/',
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
    return _handleResponse(response);
  }

  // ─── Savings Plans ────────────────────────────────────

  Future<List<dynamic>> getSavingsPlans({bool? secretOnly}) async {
    final path = secretOnly == null
        ? '/savings/'
        : '/savings/?secret=$secretOnly';
    final response = await _get(path);
    return _handleListResponse(response);
  }

  Future<Map<String, dynamic>> createSavingsPlan(
    Map<String, dynamic> data,
  ) async {
    final response = await _post('/savings/', body: data);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> simulatePenalty({
    required String planId,
    double amount = 250,
    String reason = 'Simulated penalty for testing.',
  }) async {
    final response = await _post(
      '/savings/$planId/simulate_penalty/',
      body: {'amount': amount, 'reason': reason},
    );
    return _handleResponse(response);
  }

  // ─── Transactions ──────────────────────────────────────

  Future<List<dynamic>> getTransactions() async {
    final response = await _get('/transactions/');
    return _handleListResponse(response);
  }

  Future<Map<String, dynamic>> createTransaction(
    Map<String, dynamic> data,
  ) async {
    final response = await _post('/transactions/', body: data);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> createDeposit(Map<String, dynamic> data) async {
    return createTransaction(data);
  }

  // ─── Penalties ─────────────────────────────────────────

  Future<List<dynamic>> getPenalties() async {
    final response = await _get('/penalties/');
    return _handleListResponse(response);
  }

  // ─── Loans ─────────────────────────────────────────────

  Future<List<dynamic>> getLoans() async {
    final response = await _get('/loans/');
    return _handleListResponse(response);
  }

  Future<List<dynamic>> getCredits() async {
    final response = await _get('/credits/');
    return _handleListResponse(response);
  }

  Future<Map<String, dynamic>> requestLoan(Map<String, dynamic> data) async {
    final response = await _post('/loans/', body: data);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> requestCredit(Map<String, dynamic> data) async {
    final response = await _post('/credits/', body: data);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getLoanEligibility() async {
    final response = await _get('/loans/eligibility/');
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getCreditEligibility({String? planId}) async {
    final path = planId == null
        ? '/credits/eligibility/'
        : '/credits/eligibility/?plan=$planId';
    final response = await _get(path);
    return _handleResponse(response);
  }

  // ─── Loan Payments ─────────────────────────────────────

  Future<List<dynamic>> getLoanPayments() async {
    final response = await _get('/payments/');
    return _handleListResponse(response);
  }

  Future<List<dynamic>> getCreditPayments() async {
    final response = await _get('/credit-payments/');
    return _handleListResponse(response);
  }

  Future<Map<String, dynamic>> makeLoanPayment(
    Map<String, dynamic> data,
  ) async {
    final response = await _post('/payments/', body: data);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> makeCreditPayment(
    Map<String, dynamic> data,
  ) async {
    final response = await _post('/credit-payments/', body: data);
    return _handleResponse(response);
  }

  // ─── Interest Distributions ────────────────────────────

  Future<List<dynamic>> getInterestDistributions() async {
    final response = await _get('/interest/');
    return _handleListResponse(response);
  }

  // ─── Notifications ─────────────────────────────────────

  Future<List<dynamic>> getNotifications() async {
    final response = await _get('/notifications/');
    return _handleListResponse(response);
  }

  Future<void> markNotificationRead(int id) async {
    await _post('/notifications/$id/mark_read/');
  }

  Future<void> markAllNotificationsRead() async {
    await _post('/notifications/mark_all_read/');
  }

  Future<List<dynamic>> getIjcGroups() async {
    final response = await _get('/ijc-groups/');
    return _handleListResponse(response);
  }

  Future<Map<String, dynamic>> createIjcGroup(
    Map<String, dynamic> data,
  ) async {
    final response = await _post('/ijc-groups/', body: data);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> pauseIjcGroup(int groupId) async {
    final response = await _post('/ijc-groups/$groupId/pause/');
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> resumeIjcGroup(int groupId) async {
    final response = await _post('/ijc-groups/$groupId/resume/');
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> joinIjcGroup(
    Map<String, dynamic> data,
  ) async {
    final response = await _post('/ijc-groups/join/', body: data);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> approveIjcMember({
    required int groupId,
    required int memberId,
  }) async {
    final response = await _post(
      '/ijc-groups/$groupId/approve_member/',
      body: {'member_id': memberId},
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> depositIjc({
    required int groupId,
    required double amount,
    String description = '',
    double? totalAmount,
    double? releaseAmount,
    String? cashOutPolicy,
  }) async {
    final body = {
      'amount': amount.toStringAsFixed(2),
      'description': description,
    };
    if (totalAmount != null) {
      body['total_amount'] = totalAmount.toStringAsFixed(2);
    }
    if (releaseAmount != null) {
      body['release_amount'] = releaseAmount.toStringAsFixed(2);
    }
    if (cashOutPolicy != null) {
      body['cash_out_policy'] = cashOutPolicy;
    }
    final response = await _post(
      '/ijc-groups/$groupId/deposit/',
      body: body,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> withdrawIjc({
    required int groupId,
    required double amount,
    String description = '',
  }) async {
    final response = await _post(
      '/ijc-groups/$groupId/withdraw/',
      body: {
        'amount': amount.toStringAsFixed(2),
        'description': description,
      },
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> updateIjcGroup(int groupId, Map<String, dynamic> fields) async {
    final response = await http
        .patch(
          Uri.parse('$baseUrl/ijc-groups/$groupId/'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode(fields),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 401) {
      final refreshed = await refreshToken();
      if (refreshed) {
        final retried = await http
            .patch(
              Uri.parse('$baseUrl/ijc-groups/$groupId/'),
              headers: {..._headers, 'Content-Type': 'application/json'},
              body: jsonEncode(fields),
            )
            .timeout(const Duration(seconds: 30));
        return _handleResponse(retried);
      }
    }
    return _handleResponse(response);
  }

  Future<void> deleteIjcGroup(int groupId) async {
    var response = await http
        .delete(Uri.parse('$baseUrl/ijc-groups/$groupId/'), headers: _headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 401) {
      final refreshed = await refreshToken();
      if (refreshed) {
        response = await http
            .delete(Uri.parse('$baseUrl/ijc-groups/$groupId/'), headers: _headers)
            .timeout(const Duration(seconds: 30));
      }
    }
    if (response.statusCode != 204) {
      throw ApiException(response.statusCode, response.body);
    }
  }

  // ─── Reports ───────────────────────────────────────────

  Future<Map<String, dynamic>> getFinancialReport() async {
    final response = await _get('/reports/');
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> askAssistant({
    required String message,
    required List<Map<String, String>> history,
  }) async {
    final response = await _post(
      '/assistant/chat/',
      body: {'message': message, 'history': history},
    );
    return _handleResponse(response);
  }

  // ─── Response Helpers ──────────────────────────────────

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    }
    throw ApiException(response.statusCode, response.body);
  }

  List<dynamic> _handleListResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) return decoded;
      if (decoded is Map && decoded.containsKey('results')) {
        return decoded['results'] as List;
      }
      return [];
    }
    throw ApiException(response.statusCode, response.body);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;

  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}

class ApiConfigurationException implements Exception {
  final String message;

  const ApiConfigurationException(this.message);

  @override
  String toString() => message;
}
