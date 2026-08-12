import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/bonus_inventory_model.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/api_url.dart';

class ShopController extends GetxController {
  final _api = ApiClient();

  final tokenBalance = 0.obs;
  final isLoadingBalance = false.obs;

  final inventory = BonusInventory.empty.obs;
  final isLoadingInventory = false.obs;

  final isPurchasing = false.obs;
  final isEarningVideo = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAll();
  }

  Future<void> fetchAll() async {
    await Future.wait([fetchTokenBalance(), fetchInventory()]);
  }

  Future<void> fetchTokenBalance() async {
    isLoadingBalance.value = true;
    try {
      final response = await _api.get(url: ApiUrl.baseUrl + ApiUrl.tokenWallet);
      if (response.statusCode == 200 && response.body != null) {
        tokenBalance.value = (response.body['balance'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {
    } finally {
      isLoadingBalance.value = false;
    }
  }

  Future<void> fetchInventory() async {
    isLoadingInventory.value = true;
    try {
      final response =
          await _api.get(url: ApiUrl.baseUrl + ApiUrl.bonusInventory);
      if (response.statusCode == 200 && response.body != null) {
        inventory.value =
            BonusInventory.fromJson(response.body as Map<String, dynamic>);
      }
    } catch (_) {
    } finally {
      isLoadingInventory.value = false;
    }
  }

  /// Purchase a bonus from the shop. Returns true on success.
  Future<bool> purchaseBonus(String slug) async {
    if (isPurchasing.value) return false;
    isPurchasing.value = true;
    try {
      final response = await _api.post(
        url: ApiUrl.baseUrl + ApiUrl.bonusPurchase,
        body: {'bonus': slug},
      );
      if (response.statusCode == 200 && response.body != null) {
        tokenBalance.value =
            (response.body['token_balance'] as num?)?.toInt() ??
                tokenBalance.value;
        final invJson = response.body['inventory'] as Map<String, dynamic>?;
        if (invJson != null) {
          inventory.value = BonusInventory.fromJson(invJson);
        }
        return true;
      }
      final detail =
          (response.body?['detail'] as String?) ?? 'Purchase failed';
      Get.snackbar('Error', detail,
          backgroundColor: const Color(0xFF3a0000),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } catch (_) {
      Get.snackbar('Error', 'Network error. Please try again.',
          backgroundColor: const Color(0xFF3a0000),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isPurchasing.value = false;
    }
  }

  /// TEMPORARY: instantly grants a token pack, no real payment taken —
  /// replace with real IAP once App Store/Play Console products exist
  /// (see ApiUrl.mockTokenPurchase / tokens/router.py). Returns true on
  /// success.
  final isPurchasingTokens = false.obs;

  Future<bool> purchaseTokenPack(String pack) async {
    if (isPurchasingTokens.value) return false;
    isPurchasingTokens.value = true;
    try {
      final response = await _api.post(
        url: ApiUrl.baseUrl + ApiUrl.mockTokenPurchase,
        body: {'pack': pack},
      );
      if (response.statusCode == 200 && response.body != null) {
        tokenBalance.value =
            (response.body['balance'] as num?)?.toInt() ?? tokenBalance.value;
        return true;
      }
      final detail = (response.body?['detail'] as String?) ?? 'Purchase failed';
      Get.snackbar('Error', detail,
          backgroundColor: const Color(0xFF3a0000),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } catch (_) {
      Get.snackbar('Error', 'Network error. Please try again.',
          backgroundColor: const Color(0xFF3a0000),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isPurchasingTokens.value = false;
    }
  }

  /// Watch a rewarded ad → earn 6 tokens (backend enforces 24h limit).
  Future<void> earnDailyVideoTokens() async {
    if (isEarningVideo.value) return;
    isEarningVideo.value = true;
    try {
      final response =
          await _api.post(url: ApiUrl.baseUrl + ApiUrl.earnDailyVideo);
      if (response.statusCode == 200 && response.body != null) {
        tokenBalance.value =
            (response.body['balance'] as num?)?.toInt() ?? tokenBalance.value;
        Get.snackbar('Tokens earned!', '+6 tokens added to your wallet',
            backgroundColor: const Color(0xFF1a3d1a),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      } else {
        final detail =
            (response.body?['detail'] as String?) ?? 'Could not earn tokens';
        Get.snackbar('Not available', detail,
            backgroundColor: const Color(0xFF2a2a2a),
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (_) {
      Get.snackbar('Error', 'Network error.',
          backgroundColor: const Color(0xFF3a0000),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isEarningVideo.value = false;
    }
  }
}
