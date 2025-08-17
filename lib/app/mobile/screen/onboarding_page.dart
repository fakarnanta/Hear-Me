import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hear_me/constant.dart';
import 'package:hear_me/app/mobile/screen/login.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../provider/onboarding_provider.dart';

class OnboardingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final onboardingProvider = Provider.of<OnboardingProvider>(context);

    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: PageView(
              controller: onboardingProvider.pageController,
              onPageChanged: onboardingProvider.updatePage,
              children: [
                buildPage(
                  title: "Pendidikan \nInklusif Untuk \nSemua Orang",
                  subtitle:
                      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore aliqua.",
                  image: "assets/onboarding1.png",
                ),
                buildPage(
                  title: "Pembelajaran \nKaku yang Membosankan?",
                  subtitle:
                      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore aliqua.",
                  image: "assets/onboarding2.png",
                ),
                buildPage(
                  title: "Pembelajaran Inklusif dengan AI",
                  subtitle:
                      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore aliqua.",
                  image: "assets/onboarding3.png",
                ),
                SemuaSetara(),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.only(right: 40, left: 40, bottom: 40, top: 20),
            child: Stack(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SmoothPageIndicator(
                      controller: onboardingProvider.pageController,
                      count: 4,
                      effect: WormEffect(
                        dotHeight: 8,
                        dotWidth: 8,
                        activeDotColor: primaryColor,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (onboardingProvider.currentPage == 3) {
                          Navigator.pushReplacementNamed(context, '/get-started');
                        } else {
                          onboardingProvider.nextPage(); // ➡️ Move to next page
                        }
                      },
                      child: Row(
                        children: [
                          Text(
                            "Next",
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14, color: primaryColor),
                          ),
                          SizedBox(width: 5),
                          Image.asset("assets/next.png", height: 20),
                        ],
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPage(
      {required String title,
      required String subtitle,
      required String image}) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Image.asset(image, height: 250),
          ),
          SizedBox(height: 10),
          Text(
            title,
            style: headerStyle,
          ),
          SizedBox(height: 10),
          Text(subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Color(0XFF3D3C3C),
              )),
        ],
      ),
    );
  }
}

class SemuaSetara extends StatelessWidget {
  const SemuaSetara({super.key});

  @override
  Widget build(BuildContext context) {
    final onboardingProvider = Provider.of<OnboardingProvider>(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 70),
        Text(
          '#SemuaSetara',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            color: primaryColor,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
