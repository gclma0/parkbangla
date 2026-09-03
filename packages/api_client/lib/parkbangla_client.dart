library parkbangla_client;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PbApi {
  PbApi({this.baseUrl = 'http://localhost:3001', this.token, this.activeRole});

  String baseUrl;
  String? token;
  String? activeRole;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Bypass-Tunnel-Reminder': 'true',
        if (token != null) 'Authorization': 'Bearer $token',
        if (activeRole != null) 'x-active-role': activeRole!,
      };

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: q);

  Future<dynamic> _exec(Future<http.Response> Function() req) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final r = await req().timeout(const Duration(seconds: 35));
        return _decode(r);
      } on TimeoutException catch (e) {
        lastError = e;
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
      } catch (e) {
        if (e is PbException) rethrow;
        lastError = e;
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
      }
    }
    if (lastError is TimeoutException) {
      throw PbException(408, 'Connection timeout. The server may still be waking up. Please try again in a minute.');
    }
    throw PbException(500, 'Network error: Unable to connect to server at $baseUrl');
  }

  Future<dynamic> get(String path, [Map<String, String>? q]) async {
    return _exec(() => http.get(_u(path, q), headers: _headers));
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    return _exec(() => http.post(_u(path), headers: _headers, body: jsonEncode(body ?? {})));
  }

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    return _exec(() => http.patch(_u(path), headers: _headers, body: jsonEncode(body ?? {})));
  }

  Future<dynamic> delete(String path) async {
    return _exec(() => http.delete(_u(path), headers: _headers));
  }

  dynamic _decode(http.Response r) {
    if (r.body.isEmpty) return <String, dynamic>{};
    try {
      final data = jsonDecode(r.body);
      if (r.statusCode >= 400) {
        final msg = data is Map ? (data['message'] ?? data['error'] ?? r.body) : r.body;
        throw PbException(r.statusCode, msg.toString());
      }
      return data;
    } catch (e) {
      if (e is PbException) rethrow;
      if (r.statusCode >= 400) {
        throw PbException(r.statusCode, 'Server error (${r.statusCode})');
      }
      if (r.body.contains('localtunnel') || r.body.contains('<!DOCTYPE html>')) {
        throw PbException(502, 'Tunnel verification required. Please retry.');
      }
      throw PbException(r.statusCode, 'Invalid server response');
    }
  }
}

class PbException implements Exception {
  PbException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}
