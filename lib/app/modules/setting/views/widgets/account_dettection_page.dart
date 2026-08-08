import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';

import '../../../../../apis/api_endpoints.dart';

import '../../../../../constants/constants.dart';
import '../../../auth/controllers/auth_controller.dart';


class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key});

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  static const String _publicDeletionUrl =
      'https://linlive.fr/delete-account';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 25),
      headers: const <String, dynamic>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _confirmationController =
  TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  bool _accepted = false;
  bool _pending = false;
  String _statusMessage = '';
  String _scheduledFor = '';
  String _reference = '';

  String get _statusUrl => '$kMainUrl/account-deletion/status';
  String get _requestUrl => '$kMainUrl/account-deletion/request';
  String get _cancelUrl => '$kMainUrl/account-deletion/cancel';

  @override
  void initState() {
    super.initState();

    if (Get.isRegistered<AuthController>()) {
      Get.find<AuthController>().configureProtectedDio(_dio);
    }

    _loadStatus();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Options _authOptions() {
    final String token = _token;

    return Options(
      headers: <String, dynamic>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }

  String get _token =>
      authController.userProfile.value.token?.toString().trim() ?? '';

  bool get _hasAuthenticatedSession => _token.isNotEmpty;

  Future<void> _copyPublicDeletionUrl() async {
    await Clipboard.setData(
      const ClipboardData(text: _publicDeletionUrl),
    );
    if (!mounted) return;
    _showMessage(('Account deletion link copied.').appTr);
  }

  Future<void> _loadStatus() async {
    if (!_hasAuthenticatedSession) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _pending = false;
        _statusMessage =
            ('Please sign in to request account deletion inside the app. You can also use the public deletion page below.').appTr;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final Response<dynamic> response = await _dio.get(
        _statusUrl,
        options: _authOptions(),
      );

      final Map<String, dynamic> data = _map(response.data);
      final Map<String, dynamic> request = _map(data['request']);

      if (!mounted) return;

      setState(() {
        _pending = data['pending'] == true;
        _scheduledFor = request['scheduled_for']?.toString() ?? '';
        _reference = request['reference']?.toString() ?? '';
        _statusMessage = data['message']?.toString() ?? '';
      });
    } on DioException catch (error) {
      if (!mounted) return;
      if (error.response?.statusCode == 404) {
        setState(() {
          _pending = false;
          _scheduledFor = '';
          _reference = '';
          _statusMessage = '';
        });
      } else {
        _showMessage(_dioMessage(error), error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _submitRequest() async {
    FocusScope.of(context).unfocus();

    if (!_hasAuthenticatedSession) {
      _showMessage(
        ('Please sign in before submitting an in-app deletion request.').appTr,
        error: true,
      );
      return;
    }

    if (!_accepted) {
      _showMessage(
        ('Please confirm that you understand the deletion consequences.').appTr,
        error: true,
      );
      return;
    }

    if (_confirmationController.text.trim().toUpperCase() != 'DELETE') {
      _showMessage(
        ('Type DELETE exactly to confirm.').appTr,
        error: true,
      );
      return;
    }

    final bool confirmed = await _showFinalConfirmation();
    if (!confirmed || !mounted) return;

    setState(() {
      _submitting = true;
    });

    try {
      final Response<dynamic> response = await _dio.post(
        _requestUrl,
        data: <String, dynamic>{
          'reason': _reasonController.text.trim(),
          'confirmation': 'DELETE',
        },
        options: _authOptions(),
      );

      final Map<String, dynamic> data = _map(response.data);
      final Map<String, dynamic> request = _map(data['request']);

      if (!mounted) return;

      setState(() {
        _pending = true;
        _scheduledFor = request['scheduled_for']?.toString() ?? '';
        _reference = request['reference']?.toString() ?? '';
        _statusMessage = data['message']?.toString() ??
            ('Your deletion request has been submitted.').appTr;
        _reasonController.clear();
        _confirmationController.clear();
        _accepted = false;
      });

      _showMessage(_statusMessage);
    } on DioException catch (error) {
      if (!mounted) return;
      _showMessage(_dioMessage(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _cancelRequest() async {
    if (!_hasAuthenticatedSession) {
      _showMessage(
        ('Please sign in before changing an account deletion request.').appTr,
        error: true,
      );
      return;
    }

    final bool confirmed = await _showCancelConfirmation();
    if (!confirmed || !mounted) return;

    setState(() {
      _submitting = true;
    });

    try {
      final Response<dynamic> response = await _dio.post(
        _cancelUrl,
        options: _authOptions(),
      );

      final Map<String, dynamic> data = _map(response.data);

      if (!mounted) return;

      setState(() {
        _pending = false;
        _scheduledFor = '';
        _reference = '';
        _statusMessage = data['message']?.toString() ??
            ('Account deletion request canceled.').appTr;
      });

      _showMessage(_statusMessage);
    } on DioException catch (error) {
      if (!mounted) return;
      _showMessage(_dioMessage(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<bool> _showFinalConfirmation() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xffd9365c),
            size: 42,
          ),
          title: Text(
            ('Submit deletion request?').appTr,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
          ),
          content: Text(
            ('Your account will enter a deletion-pending state. You can cancel before the scheduled deletion date shown after submission.')
                .appTr,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12.5, height: 1.5),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(('Not now').appTr),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffd9365c),
                foregroundColor: Colors.white,
              ),
              child: Text(('Submit request').appTr),
            ),
          ],
        );
      },
    ) ??
        false;
  }

  Future<bool> _showCancelConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            ('Cancel account deletion?').appTr,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
          ),
          content: Text(
            ('Your account will remain active.').appTr,
            style: GoogleFonts.poppins(fontSize: 12.5),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(('Keep request').appTr),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(('Cancel deletion').appTr),
            ),
          ],
        );
      },
    ) ??
        false;
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
          error ? const Color(0xffb42318) : const Color(0xff137a4d),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _dioMessage(DioException error) {
    final dynamic responseData = error.response?.data;

    if (responseData is Map) {
      final String message = responseData['message']?.toString().trim() ?? '';
      if (message.isNotEmpty) return message;

      final dynamic errors = responseData['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final dynamic first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        return first.toString();
      }
    }

    if (error.response?.statusCode == 401 ||
        error.response?.statusCode == 403) {
      return ('Your session has expired. Please sign in again.').appTr;
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return ('The request timed out. Please try again.').appTr;
    }

    if (error.type == DioExceptionType.connectionError) {
      return ('No internet connection. Please try again.').appTr;
    }

    return ('Could not complete the request. Please try again.').appTr;
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffff8fa),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff2d2340),
        elevation: 0.5,
        centerTitle: true,
        title: Text(
          ('Account Deletion').appTr,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _loadStatus,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            children: <Widget>[
              _warningHeader(),
              const SizedBox(height: 16),
              if (_pending) _pendingCard() else _requestForm(),
              const SizedBox(height: 16),
              _deletionDetailsCard(),
              const SizedBox(height: 16),
              _publicRequestCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _warningHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xffffedf2), Color(0xfffff8fa)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffffc7d4)),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.person_remove_alt_1_rounded,
            size: 46,
            color: Color(0xffd9365c),
          ),
          const SizedBox(height: 10),
          Text(
            ('Delete your LinLive account').appTr,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xff3b2029),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ('Deletion may permanently remove your profile access, social connections, and virtual items. Limited records may be retained for legal, safety, fraud-prevention, accounting, chargeback, or dispute purposes.')
                .appTr,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              height: 1.55,
              color: const Color(0xff735d65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffffc14d)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.schedule_rounded,
                color: Color(0xffb25d00),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ('Deletion request pending').appTr,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xff4a3422),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_statusMessage.isNotEmpty)
            Text(
              _statusMessage,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                height: 1.5,
                color: const Color(0xff68564a),
              ),
            ),
          if (_scheduledFor.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _infoRow(('Scheduled deletion:').appTr, _scheduledFor),
          ],
          if (_reference.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _infoRow(('Request reference:').appTr, _reference),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _submitting ? null : _cancelRequest,
              icon: _submitting
                  ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.undo_rounded),
              label: Text(('Cancel account deletion').appTr),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xff137a4d),
                side: const BorderSide(color: Color(0xff137a4d)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffffd7e0)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            ('Request details').appTr,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xff2d2340),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reasonController,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: ('Reason (optional)').appTr,
              hintText: ('Tell us why you are leaving').appTr,
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _confirmationController,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: ('Type DELETE to confirm').appTr,
              prefixIcon: const Icon(Icons.keyboard_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            value: _accepted,
            contentPadding: EdgeInsets.zero,
            activeColor: const Color(0xffd9365c),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              ('I understand that completed account deletion is generally permanent.')
                  .appTr,
              style: GoogleFonts.poppins(fontSize: 12, height: 1.4),
            ),
            onChanged: (bool? value) {
              setState(() {
                _accepted = value ?? false;
              });
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submitRequest,
              icon: _submitting
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.delete_forever_rounded),
              label: Text(('Submit deletion request').appTr),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffd9365c),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deletionDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffeadff3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            ('What deletion means').appTr,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xff2d2340),
            ),
          ),
          const SizedBox(height: 10),
          _detailBullet(
            ('Normally deleted or anonymized: account access, profile identifiers, social connections, eligible user content, preferences, and account-specific virtual items.').appTr,
          ),
          _detailBullet(
            ('May be retained where permitted or required: limited transaction, refund, chargeback, accounting, fraud-prevention, moderation, safety, legal, dispute, and security records.').appTr,
          ),
          _detailBullet(
            ('Completed deletion is generally permanent. A pending request can be canceled only before the scheduled deletion time shown by the service.').appTr,
          ),
        ],
      ),
    );
  }

  Widget _detailBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Icon(
              Icons.circle,
              size: 6,
              color: Color(0xff8A4CF7),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                height: 1.5,
                color: const Color(0xff665b72),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _publicRequestCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfff4f7ff),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffd6e1ff)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            ('Cannot access the app?').appTr,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xff263968),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ('Use the public account deletion page. Identity verification may be required before a web request is processed.')
                .appTr,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              height: 1.5,
              color: const Color(0xff59688c),
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            _publicDeletionUrl,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xff3658b5),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _copyPublicDeletionUrl,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(('Copy deletion link').appTr),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xff3658b5),
                side: const BorderSide(color: Color(0xff8fa8e8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xff68564a),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: const Color(0xff68564a),
            ),
          ),
        ),
      ],
    );
  }
}
