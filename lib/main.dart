import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AllInOneOtpScreen(),
  ));
}

class SmsAccount {
  final String accountSid;
  final String authToken;
  final String fromNumber;

  SmsAccount({
    required this.accountSid,
    required this.authToken,
    required this.fromNumber,
  });
}

class AllInOneOtpScreen extends StatefulWidget {
  const AllInOneOtpScreen({super.key});

  @override
  State<AllInOneOtpScreen> createState() => _AllInOneOtpScreenState();
}

class _AllInOneOtpScreenState extends State<AllInOneOtpScreen> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  // ==========================================
  // 1. Enter EmailJS Credentials Here
  // ==========================================
  final String _emailServiceId = "YOUR_SERVICE_ID";
  final String _emailTemplateId = "YOUR_TEMPLATE_ID";
  final String _emailPublicKey = "YOUR_PUBLIC_KEY";

  // ==========================================
  // 2. Enter Twilio SMS Accounts Here
  // ==========================================
  final List<SmsAccount> _smsAccounts = [
    SmsAccount(
      accountSid: "ACCOUNT_SID_1",
      authToken: "AUTH_TOKEN_1",
      fromNumber: "+12345678901",
    ),
    SmsAccount(
      accountSid: "ACCOUNT_SID_2",
      authToken: "AUTH_TOKEN_2",
      fromNumber: "+12345678902",
    ),
  ];

  bool _isEmailMode = true; // true = Email Mode, false = SMS Mode
  int _currentSmsAccountIndex = 0;
  String _generatedOtp = "";
  String _statusMessage = "Select a method and enter details to receive OTP";
  bool _isLoading = false;
  bool _otpSent = false;

  void _switchMode(bool emailMode) {
    setState(() {
      _isEmailMode = emailMode;
      _inputController.clear();
      _otpController.clear();
      _otpSent = false;
      _statusMessage = emailMode
          ? "Enter your email address"
          : "Enter mobile number with country code (e.g. +92...)";
    });
  }

  Future<void> _sendOtp() async {
    String target = _inputController.text.trim();

    if (_isEmailMode) {
      if (target.isEmpty || !target.contains('@')) {
        setState(() => _statusMessage = "Please enter a valid email address.");
        return;
      }
    } else {
      if (target.isEmpty || !target.startsWith('+')) {
        setState(() => _statusMessage = "Please include country code (e.g. +923001234567)");
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _statusMessage = _isEmailMode
          ? "Sending OTP to email..."
          : "Sending SMS via Account #${_currentSmsAccountIndex + 1}...";
    });

    // Generate 6-digit random OTP
    _generatedOtp = (100000 + Random().nextInt(900000)).toString();

    if (_isEmailMode) {
      await _sendViaEmail(target);
    } else {
      await _sendViaSms(target);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _sendViaEmail(String email) async {
    try {
      final url = Uri.parse('https://emailjs.com');
      final response = await http.post(
        url,
        headers: {
          'origin': 'http://localhost',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'service_id': _emailServiceId,
          'template_id': _emailTemplateId,
          'user_id': _emailPublicKey,
          'template_params': {
            'to_email': email,
            'user_email': email,
            'otp_code': _generatedOtp,
          }
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _otpSent = true;
          _statusMessage = "Success! A 6-digit OTP has been sent to $email.";
        });
      } else {
        setState(() => _statusMessage = "Email Error: ${response.body}");
      }
    } catch (e) {
      setState(() => _statusMessage = "Network Error: $e");
    }
  }

  Future<void> _sendViaSms(String phone) async {
    SmsAccount activeAccount = _smsAccounts[_currentSmsAccountIndex];
    try {
      final url = Uri.parse(
        'https://twilio.com{activeAccount.accountSid}/Messages.json',
      );
      String basicAuth = 'Basic ' +
          base64Encode(utf8.encode('${activeAccount.accountSid}:${activeAccount.authToken}'));

      final response = await http.post(
        url,
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'From': activeAccount.fromNumber,
          'To': phone,
          'Body': 'Your verification OTP code is: $_generatedOtp',
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        setState(() {
          _otpSent = true;
          _statusMessage =
              "Success! SMS sent to $phone using Account #${_currentSmsAccountIndex + 1}.";
        });
      } else {
        final errorData = json.decode(response.body);
        setState(() {
          _statusMessage =
              "SMS Error (Account #${_currentSmsAccountIndex + 1}): ${errorData['message']}";
        });
      }
    } catch (e) {
      setState(() => _statusMessage = "Network Error: $e");
    } finally {
      setState(() {
        _currentSmsAccountIndex = (_currentSmsAccountIndex + 1) % _smsAccounts.length;
      });
    }
  }

  void _verifyOtp() {
    if (_otpController.text.trim() == _generatedOtp) {
      setState(() {
        _statusMessage = "Congratulations! Your OTP has been verified successfully.";
      });
    } else {
      setState(() {
        _statusMessage = "Invalid OTP! Please check the code and try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Color primaryColor = _isEmailMode ? Colors.teal : Colors.indigo;

    return Scaffold(
      appBar: AppBar(
        title: const Text("All-in-One OTP Service"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 15),
            // Mode Switcher Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _switchMode(true),
                    icon: const Icon(Icons.email),
                    label: const Text("Email OTP"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isEmailMode ? Colors.teal : Colors.grey.shade300,
                      foregroundColor: _isEmailMode ? Colors.white : Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _switchMode(false),
                    icon: const Icon(Icons.sms),
                    label: const Text("SMS OTP"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_isEmailMode ? Colors.indigo : Colors.grey.shade300,
                      foregroundColor: !_isEmailMode ? Colors.white : Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (!_isEmailMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  "Next Active SMS Account: ${_currentSmsAccountIndex + 1} / ${_smsAccounts.length}",
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: Colors.indigo),
                ),
              ),
            TextField(
              controller: _inputController,
              keyboardType:
                  _isEmailMode ? TextInputType.emailAddress : TextInputType.phone,
              decoration: InputDecoration(
                labelText: _isEmailMode
                    ? "Email Address (e.g. name@gmail.com)"
                    : "Phone Number (e.g. +923001234567)",
                border: const OutlineInputBorder(),
                prefixIcon: Icon(_isEmailMode ? Icons.email_outlined : Icons.phone_android),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isEmailMode ? "Send Email OTP" : "Send SMS OTP",
                        style: const TextStyle(fontSize: 17),
                      ),
              ),
            ),
            if (_otpSent) ...[
              const SizedBox(height: 25),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: "Enter 6-Digit OTP",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
