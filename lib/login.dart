
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hear_me/constant.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<UserCredential?> signInWithGoogle() async {
    try {


      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();

      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: null, 
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print("Error saat login dengan Google: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
class GetStarted extends StatelessWidget {
  const GetStarted({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mulai Gunakan Aplikasi Ini!', style: headerStyle,),
              SizedBox(height: 40),
              LoginButton(),
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

  @override
  Widget build(BuildContext context) {
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
                Text('Login dengan Akun UM', style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),),
                 Image.asset('assets/Lambang-UM.png', width: 30, height: 30, fit: BoxFit.cover),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () async {
            setState(() {
              _isSigningIn = true;
            });

            AuthService authService = AuthService();
            UserCredential? userCredential = await authService.signInWithGoogle();

            setState(() {
              _isSigningIn = false;
            });

            if (userCredential != null) {
              Navigator.pushNamed(context, '/home', arguments: userCredential.user);
            } else {
              // Menampilkan pesan error atau notifikasi jika login gagal
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Login dengan Google gagal atau dibatalkan.'),
                ),
              );
            }
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
            child: Center(
              child: _isSigningIn
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Login dengan Google', style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),),
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

