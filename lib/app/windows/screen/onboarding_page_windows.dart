import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart' as shelf;
import 'package:toastification/toastification.dart' show toastification, ToastificationType, ToastificationStyle;

import 'package:url_launcher/url_launcher.dart';

class OnboardingPageWindows extends StatelessWidget {
  const OnboardingPageWindows({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      // Menggunakan Row untuk membagi layar menjadi dua kolom
      body: Row(
        children: [
          // Panel Kiri (Biru Tua)
          _LeftPanel(),
          // Panel Kanan (Putih)
          _RightPanel(),
        ],
      ),
    );
  }
}

class _LeftPanel extends StatelessWidget {
  const _LeftPanel();

  @override
  Widget build(BuildContext context) {
    // Expanded dengan flex: 1 mengambil 1/3 dari lebar layar
    return Expanded(
      flex: 1,
      child: Container(
        color: const Color(0xFF1A3D63), // Warna biru tua
        child: Padding(
          padding: const EdgeInsets.only(top: 60, left: 65, right: 65),
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/hearme_white.png',
                      height: 20,
                    ),
                    const SizedBox(height: 140,),
                    Text(
                      'Pendidikan Inklusif untuk Semua Orang',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const Spacer(), // Mendorong konten ke tengah
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Image.asset('assets/orang_atas.png',
                    height: 250, 
                    fit: BoxFit.cover), // 
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RightPanel extends StatefulWidget {
  const _RightPanel();

  @override
  State<_RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<_RightPanel> {
  bool _showRoleSelectionView = false;
  bool _isSigningIn = false; // State untuk loading

  // --- FUNGSI AUTENTIKASI GOOGLE UNTUK DESKTOP ---
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
    });

    HttpServer? server;
    try {
      // 1. Dapatkan Client ID dan Secret dari Google Cloud Console Anda
      //    (dari kredensial OAuth 2.0 tipe "Web application")
      const String clientId =
          "591091586203-ms37g52nl2rcr9eqd9m20qo4e23jre38.apps.googleusercontent.com"; // Ganti dengan Web Client ID Anda
      const String clientSecret =
          "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"; // <-- PENTING: Ganti dengan Client Secret Anda

      // 2. Mulai server lokal untuk mendengarkan redirect dari Google
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final String redirectUrl = 'http://localhost:${server.port}';

      // 3. Buat URL otentikasi dan buka di browser
      final Uri authUrl =
          Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirectUrl,
        'response_type': 'code',
        'scope': 'email profile openid',
      });

      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, webOnlyWindowName: '_blank');
      } else {
        throw 'Tidak dapat membuka browser.';
      }

      // 4. Tunggu browser memanggil kembali server lokal kita
      final request = await server.first;
      final code = request.uri.queryParameters['code'];

      // Kirim respons ke browser agar tab bisa ditutup
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(
            '<html><body>Anda bisa menutup jendela ini sekarang.</body></html>')
        ..close();

      if (code == null) {
        throw 'Proses login dibatalkan atau gagal.';
      }

      final tokenResponse = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': code,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUrl,
        },
      );

      if (tokenResponse.statusCode != 200) {
        throw 'Gagal mendapatkan token dari Google: ${tokenResponse.body}';
      }

      final tokens = jsonDecode(tokenResponse.body);
      final String idToken = tokens['id_token'];
      final String accessToken = tokens['access_token'];

      // 6. Gunakan token untuk sign in ke Firebase
      final authCredential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(authCredential);

      if (userCredential.user != null) {
        print(
            "Login Google berhasil untuk ${userCredential.user!.displayName}");
        _proceedToRoleSelection();
        toastification.show(
        context: context, 
        type: ToastificationType.success,
        style: ToastificationStyle.fillColored,
        title: Text('Login berhasil!'),
        autoCloseDuration: const Duration(seconds: 5),
      );
        
      }
    } catch (e) {
      print('Error saat login: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login gagal: $e')),
        );
      }
    } finally {
      await server?.close(); // Pastikan server selalu ditutup
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  void _proceedToRoleSelection() {
    setState(() {
      _showRoleSelectionView = true;
    });
  }

  void _goBackToLogin() {
    setState(() {
      _showRoleSelectionView = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 2,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 100),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (Widget child, Animation<double> animation) {
            final inAnimation = Tween<Offset>(
              begin: const Offset(0.5, 0.0),
              end: Offset.zero,
            ).animate(animation);
            final outAnimation = Tween<Offset>(
              begin: const Offset(-0.5, 0.0),
              end: Offset.zero,
            ).animate(animation);

            if (child.key == const ValueKey('RoleSelectionView')) {
              return ClipRect(
                  child: SlideTransition(
                      position: inAnimation,
                      child: FadeTransition(opacity: animation, child: child)));
            } else {
              return ClipRect(
                  child: SlideTransition(
                      position: outAnimation,
                      child: FadeTransition(opacity: animation, child: child)));
            }
          },
          child: _showRoleSelectionView
              ? _buildRoleSelectionView()
              : _buildLoginView(),
        ),
      ),
    );
  }

  Widget _buildLoginView() {
    return Column(
      key: const ValueKey('LoginView'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mulai Gunakan Aplikasi Ini!',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.black,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore aliqua.',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 40),
        _LoginHoverButton(
          text: 'Login dengan Akun UM',
          onTap: _isSigningIn ? () {} : _proceedToRoleSelection,
          imageAsset: 'assets/Lambang-UM.png',
        ),
        const SizedBox(height: 20),
        _LoginHoverButton(
          text: 'Login dengan Google',
          isLoading: _isSigningIn,
          onTap: _signInWithGoogle,
          imageAsset: 'assets/google_new.png',
        ),
      ],
    );
  }

  Widget _buildRoleSelectionView() {
    return Column(
      key: const ValueKey('RoleSelectionView'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilih peran anda !',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.black,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 40),
        _RoleButton(
          text: 'Dosen',
          onTap: () {
            print('Peran Dosen dipilih. Navigasi ke halaman utama...');
          },
        ),
        const SizedBox(height: 20),
        _RoleButton(
          text: 'Mahasiswa',
          onTap: () {
            print('Peran Mahasiswa dipilih. Navigasi ke halaman utama...');
            Navigator.pushNamed(context, '/home-mahasiswa');
          },
        ),
        const SizedBox(height: 30),
        GestureDetector(
          onTap: _goBackToLogin,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Text(
              '<< Kembali ke Login',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.grey[700],
                fontSize: 14,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginHoverButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final bool isLoading;
  final String? imageAsset; // Optional image asset for the button

  const _LoginHoverButton({
    required this.text,
    required this.onTap,
    this.isLoading = false,
    this.imageAsset,
  });

  @override
  State<_LoginHoverButton> createState() => _LoginHoverButtonState();
}

class _LoginHoverButtonState extends State<_LoginHoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color currentBackgroundColor =
        _isHovered ? const Color(0xFF1A3D63) : const Color(0XFFCBE4FF);
    final Color currentTextColor = _isHovered ? Colors.white : Colors.black;
    final Border? currentBorder =
        _isHovered ? null : Border.all(color: Colors.black, width: 1);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: MediaQuery.of(context).size.width * 0.35, // Match login.dart width
          height: 73, // Match login.dart height
          padding: const EdgeInsets.symmetric(horizontal: 20), // Match login.dart padding
          transform: _isHovered
              ? (Matrix4.identity()..scale(1.03))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: currentBackgroundColor,
            borderRadius: BorderRadius.circular(15), // Match login.dart border radius
            border: currentBorder,
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: widget.isLoading
                ? CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isHovered ? Colors.white : Colors.black,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        widget.text,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, // Match login.dart font size
                          fontWeight: FontWeight.w600, // Match login.dart font weight
                          color: currentTextColor,
                        ),
                      ),
                      if (widget.imageAsset != null)
                        Image.asset(
                          widget.imageAsset!,
                          width: 30,
                          height: 30,
                          fit: BoxFit.cover,
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final bool isLoading;

  const _RoleButton({
    required this.text,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  State<_RoleButton> createState() => _RoleButtonState();
}

class _RoleButtonState extends State<_RoleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color currentBackgroundColor =
        _isHovered ? const Color(0xFF1A3D63) : const Color(0xFFF0F0F0);
    final Color currentTextColor = _isHovered ? Colors.white : Colors.black;
    final Border? currentBorder =
        _isHovered ? null : Border.all(color: Colors.black, width: 1.5);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: 400,
          height: 60,
          transform: _isHovered
              ? (Matrix4.identity()..scale(1.03))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: currentBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: currentBorder,
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: widget.isLoading
                ? CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isHovered ? Colors.white : Colors.black,
                    ),
                  )
                : Text(
                    widget.text,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: currentTextColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
