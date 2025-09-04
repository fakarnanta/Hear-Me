import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hear_me/app/mobile/screen/transcription_page.dart';
import 'package:hear_me/app/windows/screen/transcription_page_windows.dart';
import 'package:hear_me/constant.dart';
import 'package:hear_me/main.dart';
import 'package:line_icons/line_icon.dart';
import 'package:line_icons/line_icons.dart';

class HomepagaWindows extends StatefulWidget {
  const HomepagaWindows({super.key});

  @override
  State<HomepagaWindows> createState() => _HomepagaWindowsState();
}

class _HomepagaWindowsState extends State<HomepagaWindows> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 35),
        child: Row(
          children: [
            LeftNavigationRail(),
            SizedBox(width: 50,),
            MiddleHomepage(),
            SizedBox(width: 70,),
            RightHomepage(),
          ],
        ),
      ),
    );
  }
}

class LeftNavigationRail extends StatelessWidget {
  // To make selection work, you would make this a StatefulWidget
  // and manage the selectedIndex. For now, we'll hardcode it for demo.
  final int selectedIndex = 0;

  const LeftNavigationRail({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 85,
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20)
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Image.asset('assets/hearme_white.png', width: 45, height: 45),
              const SizedBox(height: 40),
              // Use the new NavIcon widget
              NavIcon(icon: LineIcons.home, isSelected: selectedIndex == 0),
              const SizedBox(height: 16),
              NavIcon(icon: LineIcons.calendar, isSelected: selectedIndex == 1),
              const SizedBox(height: 16),
              NavIcon(icon: LineIcons.tasks, isSelected: selectedIndex == 2),
            ],
          ),
          Column(
            children: [
              NavIcon(icon: LineIcons.cog, isSelected: selectedIndex == 3),
              const SizedBox(height: 20),
              const CircleAvatar(backgroundColor: Colors.white,),
            ],
          ),
        ],
      ),
    );
  }
}

class NavIcon extends StatefulWidget {
  final IconData icon;
  final bool isSelected;

  const NavIcon({
    super.key,
    required this.icon,
    this.isSelected = false,
  });

  @override
  State<NavIcon> createState() => _NavIconState();
}

class _NavIconState extends State<NavIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // 2. Use MouseRegion to detect hover events
    return MouseRegion(
      onEnter: (event) => setState(() => _isHovered = true),
      onExit: (event) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Container(
        width: 47,
        height: 47,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isHovered
              ? primaryColor// Hover color
              : Colors.white,// Default color
          borderRadius: BorderRadius.circular(10),
          border: _isHovered
              ? Border.all(color: Colors.white, width: 1) // Border on hover
              : null,
        ),
        child: Icon(
          widget.icon,
          color: _isHovered ? Colors.white : Colors.black,
          size: 25,
        ),
      ),
    );
  }
}

class MiddleHomepage extends StatefulWidget {
  const MiddleHomepage({super.key});

  @override
  State<MiddleHomepage> createState() => _MiddleHomepageState();
}

class _MiddleHomepageState extends State<MiddleHomepage> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 30,),
        Text(
          'Jadikan Setiap Pembelajaran\nLebih Inklusif',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
          ),
           Text(
          '#SemuaSetara',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
          ),
          SizedBox(height: 40,),
            GestureDetector(
              onTap: () {
              Navigator.pushNamed(context, '/kosakata', arguments: 'Binary Search');
              },
              child: Stack(
              children: [
                Container(
                width: 400,
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

      ],
    );
  }
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
          width: 400,
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

class RightHomepage extends StatefulWidget {
  const RightHomepage({super.key});

  @override
  State<RightHomepage> createState() => _RightHomepageState();
}

class _RightHomepageState extends State<RightHomepage> {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFCBE4FF),
          borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: Colors.black,
          width: 1.0,
        ),
        ),
      ),
    );
  }
}
