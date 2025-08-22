import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart'
    show
        doWhenWindowReady,
        appWindow,
        MoveWindow,
        WindowButtonColors,
        MinimizeWindowButton,
        MaximizeWindowButton,
        CloseWindowButton;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hear_me/app/windows/screen/transcription_page_windows.dart';
import 'package:hear_me/constant.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hear_me/feature/gemini_test.dart';
import 'package:hear_me/app/windows/screen/homepage_windows.dart';
import 'package:hear_me/app/mobile/screen/login.dart';
import 'package:hear_me/app/windows/screen/onboarding_page_windows.dart';
import 'package:hear_me/app/mobile/screen/onboarding_page.dart';
import 'package:hear_me/app/mobile/provider/onboarding_provider.dart';
import 'package:hear_me/feature/realtime_bisindo.dart';
import 'package:hear_me/app/mobile/screen/transcription_page.dart';
import 'package:hear_me/services/azure_stt_bridge.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:camera/camera.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeGoogleSignIn(); 
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => OnboardingProvider()),
        Provider<AzureSttBridgeService>(
          create: (_) => AzureSttBridgeService(),
          dispose: (_, service) => service.stopBridgeExe(),
        ),
      ],
      child: const MyApp(),
    ),
  );
  if (Platform.isWindows) {
    doWhenWindowReady(() {
      const initialSize = Size(1280, 720);
      appWindow.minSize = initialSize;
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      appWindow.title = "HearMe";
      appWindow.show();
    });
  }
}

Future<void> initializeGoogleSignIn() async {
  try {
    await GoogleSignIn.instance.initialize(
      serverClientId: "591091586203-km1a7uulr152q2aic5n8vdhlg6hnm88m.apps.googleusercontent.com",
    );
  } catch (e) {
    print("Error initializing Google Sign In: $e");
  }
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hear Me',
      initialRoute: '/',
      onGenerateRoute: (settings) {
        Widget pageContent;

        switch (settings.name) {
          case '/':
            pageContent = Platform.isWindows
                ? const OnboardingPageWindows()
                : OnboardingScreen();
            break;
          case '/home-mahasiswa':
            pageContent = const HomepagaWindows();
            break;
          case '/get-started':
            pageContent = const GetStarted();
            break;
          case '/gemini':
            pageContent = GeminiClientScreen();
            break;
          case '/home':
            pageContent = HomePage();
            break;
          case '/stt':
            pageContent = const TranscriptionPage();
            break;
          case '/stt-windows':
            pageContent = TranscriptionPageWindows();
            break;
          default:
            pageContent = const GetStarted();
        }

     
          return MaterialPageRoute(builder: (_) => pageContent);
      },
    );
  }
}

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const CustomTitleBar(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

final buttonColors = WindowButtonColors(
    iconNormal: Colors.black,
    mouseOver: Colors.black.withOpacity(0.1),
    mouseDown: Colors.black.withOpacity(0.2),
    iconMouseOver: Colors.black,
    iconMouseDown: Colors.black);

final closeButtonColors = WindowButtonColors(
    mouseOver: const Color(0xFFD32F2F),
    mouseDown: const Color(0xFFB71C1C),
    iconNormal: Colors.black,
    iconMouseOver: Colors.black);

class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      color: const Color(0xFFCBE4FF),
      child: Row(
        children: [
          Expanded(child: MoveWindow()),
          MinimizeWindowButton(colors: buttonColors),
          MaximizeWindowButton(colors: buttonColors),
          CloseWindowButton(colors: closeButtonColors),
        ],
      ),
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
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
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
                      text:
                          '${_user?.displayName?.split(' ').first ?? 'Pengguna'}!',
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 25),
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
                      bottom: 0,
                      child: Image.asset(
                        'assets/current_session.png',
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ))
                ],
              ),
              const SizedBox(height: 20),
              Text('Kelas yang akan datang',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  )),
              const SizedBox(height: 20),
              UpcomingClassesCarousel(
                key: UniqueKey(),
              ),
              SizedBox(
                height: 20,
              ),
              Text('Statistik Pembelajaran',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  )),
              SizedBox(
                height: 20,
              ),
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
                  child: Text(
                    'Sign Out',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
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
                padding: EdgeInsets.only(
                    right: index == upcomingClasses.length - 1 ? 0 : 16),
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
