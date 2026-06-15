import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../controllers/my_leagues_controller.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../../../data/models/private_league_model.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';

final logger = Logger();

class CreateLeagueController extends GetxController {
  final bool isPublic;

  CreateLeagueController({this.isPublic = false});

  // Observable variables
  var isLoading = false.obs;
  var isCreatingLeague = false.obs;
  var isUpdatingLeague = false.obs;
  var isDeletingLeague = false.obs;
  var isLoadingActiveLeagues = false.obs;

  // League data
  Rx<PrivateLeagueModel?> currentLeague = Rx<PrivateLeagueModel?>(null);
  var leagueTeams = <TeamInfo>[].obs;
  var activePublicLeagues = <PrivateLeagueModel>[].obs;

  // Form controllers
  final leagueNameController = TextEditingController();
  final leagueDescriptionController = TextEditingController();

  // Form data
  var selectedLogo = ''.obs;
  var selectedBudget = '100M'.obs;
  var selectedMaxTeams = '6'.obs;
  var isFormValid = false.obs;

  // WebSocket
  WebSocketChannel? _webSocketChannel;
  StreamSubscription? _webSocketSubscription;

  // Form key
  final formKey = GlobalKey<FormState>();

  // Dynamic API endpoints based on league type
  String get _leagueEndpoint =>
      isPublic ? ApiUrl.publicLeagues : ApiUrl.privateLeagues;

  String get _kickEndpoint =>
      isPublic ? ApiUrl.kickPublicTeam : ApiUrl.kickTeam;

  String get _startEndpoint =>
      isPublic ? ApiUrl.startPublicLeague : ApiUrl.startLeague;

  String get _joinEndpoint =>
      isPublic ? ApiUrl.joinPublicLeague : ApiUrl.joinLeague;

  String get _wsPath => isPublic ? 'ws/public-leagues' : 'ws/private-leagues';

  String get _leagueTypeLabel => isPublic ? 'Public' : 'Private';

  @override
  void onClose() {
    leagueNameController.dispose();
    leagueDescriptionController.dispose();
    _webSocketChannel?.sink.close();
    _webSocketSubscription?.cancel();
    super.onClose();
  }

  @override
  void onInit() {
    super.onInit();
    leagueNameController.addListener(_updateFormValidity);
    selectedLogo.listen((_) => _updateFormValidity());
  }

  // Validation
  String? validateLeagueName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "League name is required";
    }
    if (value.trim().length < 3) {
      return "League name must be at least 3 characters";
    }
    return null;
  }

  String? validateLogo(String? value) {
    if (value == null || value.isEmpty) {
      return "Please select a league logo";
    }
    return null;
  }

  void _updateFormValidity() {
    isFormValid.value =
        selectedLogo.value.isNotEmpty &&
        leagueNameController.text.trim().isNotEmpty;
  }

  // Show snackbar
  void showSnackbar(
    BuildContext context,
    String title,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(message),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Create League
  Future<void> createLeague(BuildContext context) async {
    if (isCreatingLeague.value) return;

    if (selectedLogo.value.isEmpty ||
        leagueNameController.text.trim().isEmpty) {
      showSnackbar(
        context,
        "Validation Error",
        "Please fill in all required fields",
        isError: true,
      );
      return;
    }

    if (selectedLogo.value.isEmpty) {
      showSnackbar(
        context,
        "Validation Error",
        "Please select a league logo",
        isError: true,
      );
      return;
    }

    isCreatingLeague.value = true;

    try {
      final apiClient = ApiClient();

      final body = {
        'leauge_name': leagueNameController.text.trim(),
        'leauge_logo': selectedLogo.value,
        'leauge_description': leagueDescriptionController.text.trim(),
        'team_budget': selectedBudget.value,
        'max_team_number': selectedMaxTeams.value,
      };

      logger.i("Create $_leagueTypeLabel League Request: $body");

      final response = await apiClient.post(
        url: "${ApiUrl.baseUrl}$_leagueEndpoint",
        body: body,
        showResult: true,
      );

      logger.i("Create League Response: ${response.statusCode}");
      logger.i("Create League Body: ${response.body}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        final leagueData = PrivateLeagueModel.fromJson(response.body);
        currentLeague.value = leagueData;
        leagueTeams.value = leagueData.teams;

        logger.i(
          "$_leagueTypeLabel League Created Successfully: ${leagueData.toString()}",
        );

        if (isPublic) {
          showSnackbar(
            context,
            "Success",
            "Public league created successfully!",
          );
        } else {
          showSnackbar(
            context,
            "Success",
            "Private league created successfully! Code: ${leagueData.joinCode}",
          );
        }

        try {
          final myLeaguesController = Get.find<MyLeaguesController>();
          await myLeaguesController.refreshLeagues();
        } catch (e) {
          logger.w("MyLeaguesController not found: $e");
        }

        if (leagueData.id != null) {
          connectToWebSocket(leagueData.id!);
        }

        // For public leagues, navigate directly to waiting room
        if (isPublic && context.mounted && leagueData.id != null) {
          context.go(
            '${RoutePath.createPrivateLeagueWaitingRoomScreen.addBasePath}?leagueId=${leagueData.id}&isPublic=true',
          );
        }

        return;
      } else {
        final errorMessage =
            response.body['detail'] ??
            response.body['message'] ??
            "Failed to create $_leagueTypeLabel league";

        showSnackbar(context, "Error", errorMessage, isError: true);
      }
    } catch (e) {
      logger.e("Create League Error: $e");
      showSnackbar(
        context,
        "Error",
        "An error occurred while creating the league",
        isError: true,
      );
    } finally {
      isCreatingLeague.value = false;
    }
  }

  // Get League Details
  Future<void> getLeagueDetails(
    BuildContext context,
    int leagueId,
  ) async {
    if (isLoading.value) return;

    isLoading.value = true;

    try {
      final apiClient = ApiClient();

      logger.i(
        "Get $_leagueTypeLabel League Details Request: League ID = $leagueId",
      );

      final response = await apiClient.get(
        url: "${ApiUrl.baseUrl}$_leagueEndpoint$leagueId/",
        showResult: true,
      );

      logger.i("Get League Response: ${response.statusCode}");
      logger.i("Get League Body: ${response.body}");

      if (response.statusCode == 200) {
        final leagueData = PrivateLeagueModel.fromJson(response.body);
        currentLeague.value = leagueData;
        leagueTeams.value = leagueData.teams;

        // Pre-fill form controllers if editing
        leagueNameController.text = leagueData.leagueName;
        leagueDescriptionController.text = leagueData.leagueDescription;
        selectedLogo.value = leagueData.leagueLogo;
        selectedBudget.value = leagueData.teamBudget;
        selectedMaxTeams.value = leagueData.maxTeamNumber;

        logger.i(
          "$_leagueTypeLabel League Details Fetched: ${leagueData.toString()}",
        );

        connectToWebSocket(leagueId);

        return;
      } else {
        final errorMessage =
            response.body['detail'] ??
            response.body['message'] ??
            "Failed to fetch league details";

        showSnackbar(context, "Error", errorMessage, isError: true);
      }
    } catch (e) {
      logger.e("Get League Details Error: $e");
      showSnackbar(
        context,
        "Error",
        "An error occurred while fetching league details",
        isError: true,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Update League
  Future<void> updateLeague(BuildContext context, int leagueId) async {
    if (isUpdatingLeague.value) return;

    if (selectedLogo.value.isEmpty ||
        leagueNameController.text.trim().isEmpty) {
      showSnackbar(
        context,
        "Validation Error",
        "Please fill in all required fields",
        isError: true,
      );
      return;
    }

    isUpdatingLeague.value = true;

    try {
      final apiClient = ApiClient();

      final body = {
        'leauge_name': leagueNameController.text.trim(),
        'leauge_logo': selectedLogo.value,
        'leauge_description': leagueDescriptionController.text.trim(),
        'team_budget': selectedBudget.value,
        'max_team_number': selectedMaxTeams.value,
      };

      logger.i("Update $_leagueTypeLabel League Request: $body");

      if (isPublic) {
        // Public uses PUT
        final response = await apiClient.put(
          url: "${ApiUrl.baseUrl}$_leagueEndpoint$leagueId/",
          body: body,
          isBasic: false,
        );

        logger.i("Update League Response: $response");

        if (response != null) {
          final leagueData = PrivateLeagueModel.fromJson(response);
          currentLeague.value = leagueData;

          showSnackbar(
            context,
            "Success",
            "$_leagueTypeLabel league updated successfully!",
          );

          try {
            final myLeaguesController = Get.find<MyLeaguesController>();
            await myLeaguesController.refreshLeagues();
          } catch (e) {
            logger.w("MyLeaguesController not found: $e");
          }

          if (context.mounted) {
            context.pop();
          }
          return;
        } else {
          showSnackbar(
            context,
            "Error",
            "Failed to update $_leagueTypeLabel league",
            isError: true,
          );
        }
      } else {
        // Private uses PATCH
        final response = await apiClient.patch(
          url: "${ApiUrl.baseUrl}$_leagueEndpoint$leagueId/",
          body: body,
          showResult: true,
        );

        logger.i("Update League Response: ${response.statusCode}");
        logger.i("Update League Body: ${response.body}");

        if (response.statusCode == 200) {
          final leagueData = PrivateLeagueModel.fromJson(response.body);
          currentLeague.value = leagueData;
          leagueTeams.value = leagueData.teams;

          logger.i(
            "League Updated Successfully: ${leagueData.toString()}",
          );

          showSnackbar(
            context,
            "Success",
            "$_leagueTypeLabel league updated successfully!",
          );

          try {
            final myLeaguesController = Get.find<MyLeaguesController>();
            await myLeaguesController.refreshLeagues();
          } catch (e) {
            logger.w("MyLeaguesController not found: $e");
          }
          return;
        } else {
          final errorMessage =
              response.body['detail'] ??
              response.body['message'] ??
              "Failed to update league";

          showSnackbar(context, "Error", errorMessage, isError: true);
        }
      }
    } catch (e) {
      logger.e("Update League Error: $e");
      showSnackbar(
        context,
        "Error",
        "An error occurred while updating the league",
        isError: true,
      );
    } finally {
      isUpdatingLeague.value = false;
    }
  }

  // Delete League
  Future<void> deleteLeague(BuildContext context, int leagueId) async {
    if (isDeletingLeague.value) return;

    isDeletingLeague.value = true;

    try {
      final apiClient = ApiClient();

      logger.i(
        "Delete $_leagueTypeLabel League Request: League ID = $leagueId",
      );

      final success = await apiClient.delete(
        url: "${ApiUrl.baseUrl}$_leagueEndpoint$leagueId/",
        code: 204,
        showResult: true,
        isBasic: false,
      );

      logger.i("Delete League Success: $success");

      if (success) {
        logger.i("$_leagueTypeLabel League Deleted Successfully");
        try {
          final myLeaguesController = Get.find<MyLeaguesController>();
          await myLeaguesController.refreshLeagues();
        } catch (e) {
          logger.w("MyLeaguesController not found: $e");
        }

        _webSocketChannel?.sink.close();
        _webSocketSubscription?.cancel();

        currentLeague.value = null;
        leagueTeams.clear();

        if (!context.mounted) {
          isDeletingLeague.value = false;
          return;
        }

        context.go(RoutePath.myLeague.addBasePath);

        await Future.delayed(const Duration(milliseconds: 200));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "$_leagueTypeLabel league deleted successfully!",
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (context.mounted) {
          showSnackbar(
            context,
            "Error",
            "Failed to delete league",
            isError: true,
          );
        }
      }
    } catch (e) {
      logger.e("Delete League Error: $e");
      if (context.mounted) {
        showSnackbar(
          context,
          "Error",
          "An error occurred while deleting the league",
          isError: true,
        );
      }
    } finally {
      isDeletingLeague.value = false;
    }
  }

  // Join League (private uses join code, public uses league ID)
  Future<void> joinLeague(
    BuildContext context, {
    String? joinCode,
    int? leagueId,
  }) async {
    if (isLoading.value) return;

    if (!isPublic && (joinCode == null || joinCode.trim().isEmpty)) {
      showSnackbar(
        context,
        "Validation Error",
        "Please enter a valid join code",
        isError: true,
      );
      return;
    }

    isLoading.value = true;

    try {
      final apiClient = ApiClient();

      final body = isPublic
          ? {'league_id': leagueId}
          : {'join_code': joinCode!.trim()};

      logger.i("Join $_leagueTypeLabel League Request: $body");

      final response = await apiClient.post(
        url: "${ApiUrl.baseUrl}$_joinEndpoint",
        body: body,
        showResult: true,
      );

      logger.i("Join League Response: ${response.statusCode}");
      logger.i("Join League Body: ${response.body}");

      if (response.statusCode == 200) {
        final detail =
            response.body['detail'] ?? 'Successfully joined the league.';

        showSnackbar(context, "Success", detail);

        try {
          final myLeaguesController = Get.find<MyLeaguesController>();
          await myLeaguesController.refreshLeagues();
        } catch (e) {
          logger.w("MyLeaguesController not found: $e");
        }

        if (isPublic) {
          if (context.mounted && leagueId != null) {
            context.go(
              '${RoutePath.privateLeagueWaitingRoomScreen.addBasePath}?leagueId=$leagueId',
            );
          }
        } else {
          if (response.body['league_id'] != null) {
            final responseLeagueId = response.body['league_id'];
            if (context.mounted) {
              context.go(
                '${RoutePath.privateLeagueWaitingRoomScreen.addBasePath}?leagueId=$responseLeagueId',
              );
            }
          } else {
            if (context.mounted) {
              context.go(RoutePath.myLeague.addBasePath);
            }
          }
        }

        return;
      } else {
        final errorMessage =
            response.body['detail'] ??
            response.body['message'] ??
            "Failed to join league";

        showSnackbar(context, "Error", errorMessage, isError: true);
      }
    } catch (e) {
      logger.e("Join League Error: $e");
      showSnackbar(
        context,
        "Error",
        "An error occurred while joining the league",
        isError: true,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Kick Team from League
  Future<void> kickTeamFromLeague(
    BuildContext context,
    int teamId,
    int leagueId,
  ) async {
    if (isLoading.value) return;

    isLoading.value = true;

    try {
      final apiClient = ApiClient();

      final body = {'team_id': teamId, 'league_id': leagueId};

      logger.i("Kick Team from $_leagueTypeLabel League Request: $body");

      final response = await apiClient.post(
        url: "${ApiUrl.baseUrl}$_kickEndpoint",
        body: body,
        showResult: true,
      );

      logger.i("Kick Team Response: ${response.statusCode}");
      logger.i("Kick Team Body: ${response.body}");

      if (response.statusCode == 200) {
        final message = response.body['detail'] ?? "Team kicked successfully";

        leagueTeams.removeWhere((team) => team.teamId == teamId);

        logger.i("Team Kicked from $_leagueTypeLabel League Successfully");

        showSnackbar(context, "Success", message);

        return;
      } else {
        final errorMessage =
            response.body['detail'] ??
            response.body['message'] ??
            "Failed to kick team";

        showSnackbar(context, "Error", errorMessage, isError: true);
      }
    } catch (e) {
      logger.e("Kick Team Error: $e");
      showSnackbar(
        context,
        "Error",
        "An error occurred while kicking the team",
        isError: true,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Start League
  Future<void> startLeague(BuildContext context, int leagueId) async {
    if (isLoading.value) return;

    isLoading.value = true;

    try {
      final apiClient = ApiClient();

      final body = {'league_id': leagueId};

      logger.i("Start $_leagueTypeLabel League Request: $body");

      final response = await apiClient.post(
        url: "${ApiUrl.baseUrl}$_startEndpoint",
        body: body,
        showResult: true,
        isBasic: false,
      );

      logger.i("Start League Response: ${response.statusCode}");
      logger.i("Start League Body: ${response.body}");

      if (response.statusCode == 200) {
        final message =
            response.body['detail'] ?? "League started successfully";

        logger.i("$_leagueTypeLabel League Started Successfully");

        showSnackbar(context, "Success", message);
        try {
          final myLeaguesController = Get.find<MyLeaguesController>();
          await myLeaguesController.refreshLeagues();
        } catch (e) {
          logger.w("MyLeaguesController not found: $e");
        }

        if (context.mounted) {
          // Use current_match_day from the start_league response (backend sets it to 1).
          // Do NOT use currentLeague.value?.currentMatchDay — it is 0 before the
          // league starts and `0 ?? 1` stays 0, causing "League has not started" errors.
          final matchDay =
              (response.body['current_match_day'] as num?)?.toInt() ?? 1;

          context.go(
            '${RoutePath.fantasyLeagueScreenForJoin.addBasePath}/$leagueId?matchDay=$matchDay',
          );
        }

        return;
      } else {
        final errorMessage =
            response.body['detail'] ??
            response.body['message'] ??
            "Failed to start league";

        showSnackbar(context, "Error", errorMessage, isError: true);
      }
    } catch (e) {
      logger.e("Start League Error: $e");
      showSnackbar(
        context,
        "Error",
        "An error occurred while starting the league",
        isError: true,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // Get All Active Public Leagues (public only)
  Future<void> getActivePublicLeagues(BuildContext context) async {
    if (isLoadingActiveLeagues.value) return;

    isLoadingActiveLeagues.value = true;

    try {
      final apiClient = ApiClient();

      logger.i("Get Active Public Leagues Request");

      final response = await apiClient.get(
        url: "${ApiUrl.baseUrl}${ApiUrl.activePublicLeagues}",
        showResult: true,
      );

      logger.i("Get Active Leagues Response: ${response.statusCode}");
      logger.i("Get Active Leagues Body: ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> leaguesJson = response.body;
        activePublicLeagues.value = leaguesJson
            .map((json) => PrivateLeagueModel.fromJson(json))
            .toList();

        logger.i("Active Public Leagues Count: ${activePublicLeagues.length}");
        return;
      } else {
        final errorMessage =
            response.body['detail'] ??
            response.body['message'] ??
            "Failed to get active leagues";

        showSnackbar(context, "Error", errorMessage, isError: true);
      }
    } catch (e) {
      logger.e("Get Active Leagues Error: $e");
      showSnackbar(
        context,
        "Error",
        "An error occurred while fetching active leagues",
        isError: true,
      );
    } finally {
      isLoadingActiveLeagues.value = false;
    }
  }

  // Connect to WebSocket for real-time updates
  void connectToWebSocket(int leagueId) {
    try {
      _webSocketChannel?.sink.close();
      _webSocketSubscription?.cancel();

      final wsBase = ApiUrl.baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final wsUrl = Uri.parse("$wsBase/$_wsPath/$leagueId/");
      _webSocketChannel = WebSocketChannel.connect(wsUrl);

      logger.i("WebSocket connected: $wsUrl");

      _webSocketSubscription = _webSocketChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            final event = WebSocketLeagueEvent.fromJson(data);

            switch (event.event) {
              case 'team_joined':
                _handleTeamJoined(event.payload);
                break;
              case 'team_left':
                _handleTeamLeft(event.payload);
                break;
              case 'team_kicked':
                _handleTeamKicked(event.payload);
                break;
              case 'league_started':
                _handleLeagueStarted(event.payload);
                break;
              default:
                logger.w("Unknown WebSocket event: ${event.event}");
            }
          } catch (e) {
            logger.e("WebSocket message parse error: $e");
          }
        },
        onError: (error) {
          logger.e("WebSocket error: $error");
        },
        onDone: () {
          logger.i("WebSocket connection closed");
        },
      );
    } catch (e) {
      logger.e("WebSocket connection error: $e");
    }
  }

  void _handleLeagueStarted(WebSocketPayload payload) {
    logger.i("$_leagueTypeLabel League Started: ${payload.message}");
  }

  void _handleTeamJoined(WebSocketPayload payload) {
    logger.i("Team Joined $_leagueTypeLabel League: ${payload.teamName}");

    final existingTeam = leagueTeams.firstWhereOrNull(
      (team) => team.teamId == payload.teamId,
    );

    if (existingTeam == null) {
      leagueTeams.add(
        TeamInfo(
          teamId: payload.teamId!,
          teamName: payload.teamName ?? '',
          teamLogo: payload.teamLogo ?? '',
        ),
      );
    }
  }

  void _handleTeamLeft(WebSocketPayload payload) {
    logger.i("Team Left $_leagueTypeLabel League: ${payload.teamName}");

    if (payload.teamId != null) {
      leagueTeams.removeWhere((team) => team.teamId == payload.teamId);
    }
  }

  void _handleTeamKicked(WebSocketPayload payload) {
    logger.i("Team Kicked from $_leagueTypeLabel League: ${payload.teamName}");

    if (payload.teamId != null) {
      leagueTeams.removeWhere((team) => team.teamId == payload.teamId);
    }
  }

  void disconnectWebSocket() {
    _webSocketChannel?.sink.close();
    _webSocketSubscription?.cancel();
    logger.i("WebSocket disconnected");
  }

  void setFormData({
    String? leagueName,
    String? leagueDescription,
    String? logo,
    String? budget,
    String? maxTeams,
  }) {
    if (leagueName != null) leagueNameController.text = leagueName;
    if (leagueDescription != null) {
      leagueDescriptionController.text = leagueDescription;
    }
    if (logo != null) selectedLogo.value = logo;
    if (budget != null) selectedBudget.value = budget;
    if (maxTeams != null) selectedMaxTeams.value = maxTeams;
  }

  void clearForm() {
    leagueNameController.clear();
    leagueDescriptionController.clear();
    selectedLogo.value = '';
    selectedBudget.value = '100M';
    selectedMaxTeams.value = '6';
    currentLeague.value = null;
    leagueTeams.clear();
    activePublicLeagues.clear();
  }
}
