// lib/presentation/screens/profile/support_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
import '../../../core/routes/route_path.dart';
import '../../../core/routes/routes.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/api_url.dart';

const _orange = Color(0xFFFF6B35);
const _card = Color(0xFF1A1A1A);

/// Player-facing support tickets: the list of the player's own requests,
/// and the conversation inside one. An admin answers from the dashboard.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _Ticket {
  final String id;
  final String subject;
  final String status;
  final int messageCount;
  final String lastActivity;

  _Ticket({
    required this.id,
    required this.subject,
    required this.status,
    required this.messageCount,
    required this.lastActivity,
  });

  factory _Ticket.fromJson(Map<String, dynamic> json) => _Ticket(
        id: '${json['id'] ?? ''}',
        subject: json['subject'] as String? ?? '',
        status: json['status'] as String? ?? 'open',
        messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
        lastActivity: json['last_activity_at'] as String? ?? '',
      );
}

String _statusLabel(String status) {
  switch (status) {
    case 'pending':
      return AppString.supportStatusPending.tr;
    case 'resolved':
      return AppString.supportStatusResolved.tr;
    case 'closed':
      return AppString.supportStatusClosed.tr;
    default:
      return AppString.supportStatusOpen.tr;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'pending':
      return const Color(0xFF2196F3);
    case 'resolved':
      return const Color(0xFF4CAF50);
    case 'closed':
      return Colors.grey;
    default:
      return _orange;
  }
}

String _formatWhen(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '';
  final d = parsed.toLocal();
  final two = (int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}

class _SupportScreenState extends State<SupportScreen> {
  bool _isLoading = true;
  String? _error;
  List<_Ticket> _tickets = [];

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    try {
      final response = await ApiClient().get(
        url: '${ApiUrl.baseUrl}${ApiUrl.supportTickets}',
      );

      if (response.statusCode == 200 && response.body is List) {
        setState(() {
          _tickets = (response.body as List)
              .map((e) => _Ticket.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _error = null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load (${response.statusCode}).';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openNewTicketSheet() async {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    bool sending = false;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 20.h,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppString.newSupportTicket.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16.h),
              _field(subjectCtrl, AppString.supportSubject.tr),
              SizedBox(height: 12.h),
              _field(messageCtrl, AppString.supportMessage.tr, maxLines: 4),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: sending
                      ? null
                      : () async {
                          final subject = subjectCtrl.text.trim();
                          final message = messageCtrl.text.trim();
                          if (subject.length < 3 || message.isEmpty) return;

                          setSheetState(() => sending = true);
                          final response = await ApiClient().post(
                            url: '${ApiUrl.baseUrl}${ApiUrl.supportTickets}',
                            body: {'subject': subject, 'message': message},
                          );
                          if (!sheetContext.mounted) return;
                          if (response.statusCode == 201 ||
                              response.statusCode == 200) {
                            Navigator.pop(sheetContext, true);
                          } else {
                            setSheetState(() => sending = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    disabledBackgroundColor: const Color(0xFF333333),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: Text(
                    AppString.supportSend.tr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (created == true && mounted) {
      Get.snackbar('', AppString.supportCreated.tr,
          titleText: const SizedBox.shrink(), colorText: Colors.white);
      _fetchTickets();
    }
  }

  Widget _field(TextEditingController controller, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: Colors.white, fontSize: 14.sp),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey, fontSize: 14.sp),
        filled: true,
        fillColor: Colors.black,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: Color(0x7FB0B0B0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: Color(0x7FB0B0B0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: _orange),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Assets.icons.backButton.image(fit: BoxFit.contain),
          onPressed: () =>
              context.go(RoutePath.profileSettingsScreen.addBasePath),
        ),
        title: Text(
          AppString.support.tr,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _orange,
        onPressed: _openNewTicketSheet,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          AppString.newSupportTicket.tr,
          style: TextStyle(color: Colors.white, fontSize: 13.sp),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _orange));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14.sp),
          ),
        ),
      );
    }

    if (_tickets.isEmpty) {
      return Center(
        child: Text(
          AppString.supportNoTickets.tr,
          style: TextStyle(color: Colors.grey, fontSize: 14.sp),
        ),
      );
    }

    return RefreshIndicator(
      color: _orange,
      onRefresh: _fetchTickets,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 100.h),
        itemCount: _tickets.length,
        itemBuilder: (context, i) {
          final t = _tickets[i];
          return GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TicketThreadScreen(ticketId: t.id),
                ),
              );
              if (mounted) _fetchTickets();
            },
            child: Container(
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0x7FB0B0B0), width: 1.w),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: _statusColor(t.status).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          _statusLabel(t.status),
                          style: TextStyle(
                            color: _statusColor(t.status),
                            fontSize: 11.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '${t.messageCount} · ${_formatWhen(t.lastActivity)}',
                    style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One ticket's conversation, with a reply box unless it is closed.
class TicketThreadScreen extends StatefulWidget {
  final String ticketId;

  const TicketThreadScreen({super.key, required this.ticketId});

  @override
  State<TicketThreadScreen> createState() => _TicketThreadScreenState();
}

class _TicketThreadScreenState extends State<TicketThreadScreen> {
  final TextEditingController _replyCtrl = TextEditingController();
  bool _isLoading = true;
  bool _sending = false;
  String _subject = '';
  String _status = 'open';
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  void _apply(dynamic body) {
    final map = Map<String, dynamic>.from(body as Map);
    setState(() {
      _subject = map['subject'] as String? ?? '';
      _status = map['status'] as String? ?? 'open';
      _messages = ((map['messages'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _fetch() async {
    try {
      final response = await ApiClient().get(
        url: '${ApiUrl.baseUrl}${ApiUrl.supportTicket(widget.ticketId)}',
      );
      if (response.statusCode == 200 && response.body != null) {
        _apply(response.body);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final response = await ApiClient().post(
        url: '${ApiUrl.baseUrl}${ApiUrl.supportTicketReply(widget.ticketId)}',
        body: {'message': text},
      );
      if (response.statusCode == 200 && response.body != null) {
        _replyCtrl.clear();
        _apply(response.body);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _subject.isEmpty ? AppString.support.tr : _subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _orange))
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.all(20.w),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        final fromAdmin = m['author_is_admin'] == true;
                        return Align(
                          alignment: fromAdmin
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Container(
                            margin: EdgeInsets.only(bottom: 12.h),
                            padding: EdgeInsets.all(12.w),
                            constraints: BoxConstraints(maxWidth: 260.w),
                            decoration: BoxDecoration(
                              color: fromAdmin ? _card : _orange,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['body'] as String? ?? '',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.sp,
                                    height: 1.4,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  _formatWhen(m['sent_at'] as String? ?? ''),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                    child: _status == 'closed'
                        ? Text(
                            AppString.supportClosed.tr,
                            style:
                                TextStyle(color: Colors.grey, fontSize: 13.sp),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _replyCtrl,
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14.sp),
                                  decoration: InputDecoration(
                                    hintText: AppString.supportReply.tr,
                                    hintStyle: TextStyle(
                                        color: Colors.grey, fontSize: 13.sp),
                                    filled: true,
                                    fillColor: _card,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 10.w),
                              GestureDetector(
                                onTap: _sendReply,
                                child: Container(
                                  padding: EdgeInsets.all(12.r),
                                  decoration: const BoxDecoration(
                                    color: _orange,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _sending ? Icons.hourglass_top : Icons.send,
                                    color: Colors.white,
                                    size: 20.r,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
