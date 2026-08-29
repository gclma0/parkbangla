import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'i18n.dart';
import 'session.dart';
import 'theme.dart';
import 'widgets.dart';

class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.home});
  final Widget home;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    session.boot();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (_, __) {
        if (!session.ready) {
          return const Scaffold(
            backgroundColor: Pb.yellow,
            body: Center(
              child: Text('ParkBangla', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
            ),
          );
        }
        if (session.user == null) return const Onboarding();
        return widget.home;
      },
    );
  }
}

class Onboarding extends StatelessWidget {
  const Onboarding({super.key});

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    return Scaffold(
      backgroundColor: Pb.yellow,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => session.setBn(!session.bn),
                  child: Text(session.bn ? 'EN' : 'বাংলা', style: const TextStyle(color: Pb.ink, fontWeight: FontWeight.w800)),
                ),
              ),
              const Spacer(),
              Text(i.app, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))
                  .animate()
                  .fadeIn()
                  .slideY(begin: 0.2, curve: Curves.easeOutBack),
              const SizedBox(height: 12),
              Text(
                i.tagline,
                style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, height: 1.05),
              ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.15),
              const SizedBox(height: 16),
              Text(
                i.t('Hosts share unused driveways. You lock a weekday pass near work.',
                    'হোস্টরা খালি ড্রাইভওয়ে ভাড়া দেন। আপনি অফিসের কাছে সাপ্তাহিক পাস নেন।'),
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
              const Spacer(),
              YellowCta(
                label: i.continuePhone,
                onPressed: () => Navigator.push(context, _fade(const PhoneScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});
  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final c = TextEditingController(text: '01710000001');
  bool loading = false;
  String? err;

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(i.phone, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(i.demoHint, style: const TextStyle(color: Pb.muted)),
            const SizedBox(height: 24),
            TextField(
              controller: c,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                hintText: '01XXXXXXXXX',
              ),
            ),
            if (err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(err!, style: const TextStyle(color: Colors.red))),
            const Spacer(),
            YellowCta(
              label: loading ? '…' : i.t('Send OTP', 'ওটিপি পাঠান'),
              onPressed: loading
                  ? null
                  : () async {
                      setState(() {
                        loading = true;
                        err = null;
                      });
                      try {
                        await session.requestOtp(c.text.trim());
                        if (!context.mounted) return;
                        Navigator.push(context, _fade(OtpScreen(phone: c.text.trim())));
                      } catch (e) {
                        setState(() => err = e.toString());
                      } finally {
                        if (mounted) setState(() => loading = false);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phone});
  final String phone;
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final c = TextEditingController(text: '123456');
  bool loading = false;
  String? err;

  @override
  Widget build(BuildContext context) {
    final i = I18n(session.bn);
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(i.otp, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900))
                .animate()
                .fadeIn()
                .scale(begin: const Offset(0.96, 0.96)),
            const SizedBox(height: 8),
            Text(widget.phone, style: const TextStyle(color: Pb.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            TextField(
              controller: c,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            if (err != null) Text(err!, style: const TextStyle(color: Colors.red)),
            const Spacer(),
            YellowCta(
              label: loading ? '…' : i.t('Verify', 'যাচাই'),
              onPressed: loading
                  ? null
                  : () async {
                      setState(() {
                        loading = true;
                        err = null;
                      });
                      try {
                        await session.verifyOtp(widget.phone, c.text.trim());
                        if (!context.mounted) return;
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      } catch (e) {
                        setState(() => err = e.toString());
                      } finally {
                        if (mounted) setState(() => loading = false);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

Route _fade(Widget page) => PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 320),
    );
