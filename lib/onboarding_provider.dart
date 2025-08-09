import 'package:flutter/material.dart';

class OnboardingProvider extends ChangeNotifier {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  PageController get pageController => _pageController;
  int get currentPage => _currentPage;

  void nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void skipToLastPage() {
    _pageController.jumpToPage(2);
  }

  void updatePage(int index) {
    _currentPage = index;
    notifyListeners();
  }
}
