import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mon5majeur_app/core/constants/api_constants.dart';
import 'package:mon5majeur_app/core/local_db/local_db.dart';
import 'package:mon5majeur_app/utils/logger/logger.dart';

final log = logger(ApiClient);

Map<String, String> basicHeaderInfo() {
  return {
    HttpHeaders.contentTypeHeader: 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };
}

Future<Map<String, String>> bearerHeaderInfo() async {
  final token = await SharedPrefsHelper.getString(AppConstants.token);
  return {
    HttpHeaders.contentTypeHeader: 'application/json',
    HttpHeaders.authorizationHeader: 'Bearer $token',
    'ngrok-skip-browser-warning': 'true',
  };
}

String noInternetConnection = "No internet connection.!";

class ApiClient {
  final GetConnect _connect = GetConnect(timeout: const Duration(seconds: 30));

  //=========================== Get method ======================
  Future<Response> get({
    required String url,
    bool isBasic = false,
    int duration = 30,
    bool showResult = false,
    BuildContext? context,
  }) async {
    final headers = isBasic ? basicHeaderInfo() : await bearerHeaderInfo();
    final response = await _connect.get(url, headers: headers);
    if (showResult) log.i('GET $url → ${response.statusCode}');
    return response;
  }

  //========================== Post Method =======================
  Future<Response> post({
    required String url,
    bool isBasic = false,
    Map<String, dynamic>? body,
    int duration = 30,
    bool showResult = true,
  }) async {
    final headers = isBasic ? basicHeaderInfo() : await bearerHeaderInfo();
    final response = await _connect.post(url, body, headers: headers);
    if (showResult) log.i('POST $url → ${response.statusCode}');
    return response;
  }

  //========================== Patch Method ======================
  Future<Response> patch({
    required String url,
    bool isBasic = false,
    Map<String, dynamic>? body,
    int duration = 30,
    bool showResult = false,
  }) async {
    final headers = isBasic ? basicHeaderInfo() : await bearerHeaderInfo();
    final response = await _connect.patch(url, body, headers: headers);
    if (showResult) log.i('PATCH $url → ${response.statusCode}');
    return response;
  }

  //========================== Param Get Method ==================
  Future<Map<String, dynamic>?> paramGet({
    String? url,
    bool? isBasic,
    Map<String, String>? body,
    int code = 200,
    int duration = 15,
    bool showResult = false,
  }) async {
    final headers = (isBasic ?? false) ? basicHeaderInfo() : await bearerHeaderInfo();
    final response = await _connect.get(url ?? '', headers: headers);
    return response.statusCode == code ? response.body as Map<String, dynamic>? : null;
  }

  //========================== Multipart Request =================
  Future<Response> multipartRequest({
    required String url,
    required String reqType,
    bool isBasic = false,
    Map<String, String>? body,
    required List<MultipartBody> multipartBody,
    bool showResult = true,
  }) async {
    final token = await SharedPrefsHelper.getString(AppConstants.token);
    final formData = FormData({
      if (body != null) ...body,
      for (final mp in multipartBody)
        mp.key: MultipartFile(mp.file, filename: mp.file.path.split('/').last),

    });
    final headers = {
      HttpHeaders.authorizationHeader: 'Bearer $token',
      'ngrok-skip-browser-warning': 'true',
    };
    if (reqType == 'POST') {
      return await _connect.post(url, formData, headers: headers);
    } else {
      return await _connect.patch(url, formData, headers: headers);
    }
  }

  //========================== Delete Method =====================
  Future<bool> delete({
    String? url,
    bool? isBasic,
    int code = 204,
    bool isLogout = false,
    int duration = 15,
    bool showResult = false,
  }) async {
    final headers = (isBasic ?? false) ? basicHeaderInfo() : await bearerHeaderInfo();
    final response = await _connect.delete(url ?? '', headers: headers);
    return response.statusCode == code;
  }

  //========================== Put Method ========================
  Future<Map<String, dynamic>?> put({
    String? url,
    bool? isBasic,
    Map<String, dynamic>? body,
    int code = 202,
    int duration = 15,
    bool showResult = false,
  }) async {
    final headers = (isBasic ?? false) ? basicHeaderInfo() : await bearerHeaderInfo();
    final response = await _connect.put(url ?? '', body, headers: headers);
    if (response.statusCode == code) {
      return response.body as Map<String, dynamic>?;
    }
    return null;
  }
}

class MultipartBody {
  String key;
  File file;
  MultipartBody(this.key, this.file);
}
