import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_gate.dart';
import 'services/network_utils.dart';
import 'widgets/app_backdrop.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int codeLength = 6;

  final List<TextEditingController> _controllers = List.generate(
    codeLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    codeLength,
    (_) => FocusNode(),
  );

  bool _isLoading = false;
  int _resendSeconds = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    for (int i = 0; i < codeLength; i++) {
      _controllers[i].addListener(() => _onControllerChange(i));
    }
  }

  void _startResendTimer() {
    _canResend = false;
    _resendSeconds = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
        } else {
          _canResend = true;
        }
      });
      return _resendSeconds > 0 && mounted;
    });
  }

  void _onControllerChange(int index) {
    final text = _controllers[index].text;
    if (text.length == 1 && index < codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (text.length == 1 && index == codeLength - 1) {
      _focusNodes[index].unfocus();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _enteredCode => _controllers.map((c) => c.text).join();
  bool get _isCodeComplete => _enteredCode.length == codeLength;

  Future<void> _verifyOtp() async {
    if (!_isCodeComplete) return;

    final canReachBackend = await NetworkUtils.canResolveSupabase();
    if (!canReachBackend) {
      _showSnackBar(
        'Нет подключения к интернету или недоступен сервер. Проверьте сеть и попробуйте снова.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: _enteredCode,
        type: OtpType.email,
      );

      if (response.session == null || !mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthGate()),
        (route) => false,
      );
    } on AuthException catch (error) {
      _showSnackBar('Неверный код: ${error.message}', isError: true);
    } catch (error) {
      if (NetworkUtils.isNetworkError(error)) {
        _showSnackBar(
          'Не удалось подключиться к серверу. Проверьте интернет и повторите попытку.',
          isError: true,
        );
      } else {
        _showSnackBar('Произошла ошибка', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;

    final canReachBackend = await NetworkUtils.canResolveSupabase();
    if (!canReachBackend) {
      _showSnackBar(
        'Нет подключения к интернету или недоступен сервер. Проверьте сеть и попробуйте снова.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signInWithOtp(email: widget.email);
      _startResendTimer();
      _showSnackBar('Новый код отправлен');
      for (final controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    } on AuthException catch (error) {
      _showSnackBar(error.message, isError: true);
    } catch (error) {
      if (NetworkUtils.isNetworkError(error)) {
        _showSnackBar(
          'Не удалось подключиться к серверу. Проверьте интернет и повторите попытку.',
          isError: true,
        );
      } else {
        _showSnackBar('Произошла ошибка', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text == null) return;
    final pastedText = clipboardData!.text!.trim();
    if (pastedText.length != codeLength ||
        !RegExp(r'^\d+$').hasMatch(pastedText)) {
      _showSnackBar('Вставьте 6 цифр', isError: true);
      return;
    }
    for (int i = 0; i < codeLength; i++) {
      _controllers[i].text = pastedText[i];
    }
    _focusNodes[codeLength - 1].unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Подтверждение входа')),
      body: AppBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.mark_email_unread_rounded,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Код отправлен',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              widget.email,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(codeLength, (index) {
                      return SizedBox(
                        width: 46,
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontSize: 22),
                          decoration: const InputDecoration(counterText: ''),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _pasteFromClipboard,
                      icon: const Icon(
                        Icons.content_paste_go_rounded,
                        size: 18,
                      ),
                      label: const Text('Вставить код'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: (_isLoading || !_isCodeComplete)
                        ? null
                        : _verifyOtp,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.verified_rounded),
                    label: Text(_isLoading ? 'Проверяем...' : 'Подтвердить'),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _canResend
                        ? 'Код не пришёл? Отправьте повторно.'
                        : 'Повторная отправка через $_resendSeconds сек',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (_canResend)
                    Center(
                      child: TextButton(
                        onPressed: _isLoading ? null : _resendOtp,
                        child: const Text('Отправить код снова'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
