import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Untuk mendeteksi platform web
import 'dart:io' show Platform; // Untuk mendeteksi platform desktop
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hear_me/constant.dart';

class GetStarted extends StatelessWidget {
  const GetStarted({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mulai Gunakan Aplikasi Ini!',
                style: headerStyle,
              ),
              const SizedBox(height: 40),
              const LoginButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginButton extends StatefulWidget {
  const LoginButton({super.key});

  @override
  State<LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<LoginButton> {
  bool _isSigningIn = false;

  // Fungsi untuk menangani proses login Google
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
    });

    UserCredential? userCredential;

    try {
      // 1. Buat instance GoogleAuthProvider
      GoogleAuthProvider googleProvider = GoogleAuthProvider();

      // 2. Panggil signInWithPopup. Ini akan membuka browser untuk login.
      // Ini adalah metode yang direkomendasikan untuk Web dan Desktop.
      userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
    } on FirebaseAuthException catch (e) {
      // Menangani error spesifik dari Firebase Auth
      // Contoh: pengguna menutup jendela popup browser
      if (e.code == 'auth/popup-closed-by-user') {
        print('Jendela login ditutup oleh pengguna.');
      } else {
        print('Login gagal: ${e.message}');
      }
    } catch (e) {
      // Menangani error lainnya
      print('Terjadi error tak terduga: $e');
    } finally {
      // 3. Pastikan indikator loading berhenti setelah proses selesai
      setState(() {
        _isSigningIn = false;
      });
    }

    // 4. Jika login berhasil, navigasi ke halaman home
    if (userCredential != null) {
      // Gunakan 'mounted' untuk memastikan widget masih ada di tree
      if (!mounted) return;
      Navigator.pushNamed(context, '/home', arguments: userCredential.user);
    } else {
      // Menampilkan pesan error jika login gagal atau dibatalkan
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login dengan Google gagal atau dibatalkan.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cek apakah platform saat ini adalah desktop atau web
    // `signInWithPopup` hanya didukung di platform ini.
    bool isDesktopOrWeb = !Platform.isIOS && !Platform.isAndroid;
    if (kIsWeb) {
      isDesktopOrWeb = true;
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, '/tes');
          },
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: 73,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0XFFCBE4FF),
              border: Border.all(color: Colors.black, width: 1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Login dengan Akun UM',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Image.asset('assets/Lambang-UM.png',
                    width: 30, height: 30, fit: BoxFit.cover),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Hanya tampilkan tombol Google Login jika platformnya didukung
        if (isDesktopOrWeb)
          GestureDetector(
            onTap: _isSigningIn ? null : _signInWithGoogle, // Panggil fungsi login
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: 73,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0XFFCBE4FF),
                border: Border.all(color: Colors.black, width: 1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: _isSigningIn
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Login dengan Google',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          Image.asset(
                            'assets/google_new.png',
                            width: 30,
                            height: 30,
                            fit: BoxFit.cover,
                          ),
                        ],
                      ),
              ),
            ),
          ),
      ],
    );
  }
}
