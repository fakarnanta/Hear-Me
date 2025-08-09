import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hear_me/constant.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hear_me/gemini_test.dart';
import 'package:hear_me/login.dart';
import 'package:hear_me/new_onboarding_page.dart';
import 'package:hear_me/onboarding_page.dart';
import 'package:hear_me/onboarding_provider.dart';
import 'package:hear_me/realtime_bisindo.dart';
import 'package:hear_me/transcription_page.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:camera/camera.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GoogleSignIn.instance.initialize(
    serverClientId: '591091586203-km1a7uulr152q2aic5n8vdhlg6hnm88m.apps.googleusercontent.com',
  );
  cameras = await availableCameras();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(  MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (context) => OnboardingProvider()),
    ],
    child: const MyApp(),
  ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: Platform.isWindows ? '/new-onboarding' : '/get-started',
      routes: {
        '/': (context) => OnboardingScreen(),
        '/new-onboarding': (context) => const NewOnboardingPage(),
        '/get-started': (context) => const GetStarted(),
        '/gemini': (context) => GeminiClientScreen(),
        '/home': (context) => const HomePage(),
        '/stt' : (context) => const TranscriptionPage(),
      },
      title: 'Hear Me',
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  User? _user;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = ModalRoute.of(context)?.settings.arguments as User?;
    if (user != null) {
      setState(() {
        _user = user;
      });
    }

    
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 37),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
                children: [
                  TextSpan(text: 'Selamat\n', style: headerStyle),
                  TextSpan(text: 'Pagi, ', style: headerStyle),
                  TextSpan(
                    text: '${_user?.displayName?.split(' ').first ?? 'Pengguna'}!',
                    style: headerStyle.copyWith(color: primaryColor),
                  ),
                ],
                ),
              ),
              const SizedBox(height: 35),
              Stack(
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width,
                    height: 180,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                    decoration: BoxDecoration(
                      color: const Color(0XFF1C1C1C),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 15,
                              height: 15,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF5AF571),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text('Sesi Saat Ini',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                )),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Text(
                          'Binary Search',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Struktur Data - NMAT230111',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '35 students',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 5,
                    bottom : 0,
                    child: Image.asset(
                      'assets/current_session.png',
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    )
                  )
                ],
              ),
              const SizedBox(height: 20),
              Text('Kelas yang akan datang', style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              )),
              const SizedBox(height: 20),
              UpcomingClassesCarousel(
                key: UniqueKey(), // Gunakan UniqueKey untuk memaksa rebuild
              ),
              SizedBox(height: 20,),
              Text('Statistik Pembelajaran',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  
                  color: Colors.black,
                )),
                SizedBox(height: 20,),
                StatistikPembelajaran(),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/stt');
                  },
                 child: Container(
                    width: MediaQuery.sizeOf(context).width,
                    height: 73,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0XFFCBE4FF),
                      border: Border.all(color: Colors.black, width: 1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text('bisindo test', style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),),
                  ),
                 ),
            ],
          ),
        ),
      ),
    ));
  }
}

class UpcomingClass {
  final String course;
  final String topic;
  final String date;
  final String time;

  UpcomingClass({
    required this.course,
    required this.topic,
    required this.date,
    required this.time,
  });
}


class UpcomingClassesCarousel extends StatelessWidget {
  UpcomingClassesCarousel({super.key});

  final List<UpcomingClass> upcomingClasses = [
    UpcomingClass(
      course: 'Kalkulus - NMAT230318',
      topic: 'Pengali Lagrange',
      date: '27 Februari 2025',
      time: '14:00 - 15:35 WIB',
    ),
    UpcomingClass(
      course: 'Teori Grup - NMAT230412',
      topic: 'Isomorfisma',
      date: '28 Februari 2025',
      time: '07:00 - 09:35 WIB',
    ),
    UpcomingClass(
      course: 'Aljabar Linear - NMAT230111',
      topic: 'Transformasi Linear',
      date: '1 Maret 2025',
      time: '10:00 - 11:35 WIB',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 133, 
          child: ListView.builder(
            scrollDirection: Axis.horizontal, 
            itemCount: upcomingClasses.length,
            itemBuilder: (context, index) {
              final aClass = upcomingClasses[index];
              return Padding(
                padding: EdgeInsets.only(right: index == upcomingClasses.length - 1 ? 0 : 16),
                child: ClassCard(aClass: aClass),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
    required this.aClass,
  });

  final UpcomingClass aClass;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280, // Lebar setiap kartu
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFCBE4FF), 
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: Colors.black, 
          width: 1.0, 
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            aClass.course,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.grey[700],
              fontSize: 12,
            ),
          ),
          SizedBox(height: 15),
          Text(
            aClass.topic,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 3),
          Text(
            aClass.date,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.grey[800],
              fontSize: 11,
            ),
          ),
          SizedBox(height: 3),
           Text(
            aClass.time,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.grey[800],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class StatistikPembelajaran extends StatefulWidget {
  const StatistikPembelajaran({super.key});

  @override
  State<StatistikPembelajaran> createState() => _StatistikPembelajaranState();
}

class _StatistikPembelajaranState extends State<StatistikPembelajaran> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: MediaQuery.sizeOf(context).width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFCBE4FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total waktu belajar',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                )),
                Container(
                  width: 99,
                  height: 34,
                  margin: const EdgeInsets.only(left: 10, right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                )
            ],
          )
        ],
      ),
    );
  }
}