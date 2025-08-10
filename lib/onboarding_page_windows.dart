import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hear_me/login.dart';

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
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 65),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/hearme_white.png',
                height: 20,
              ),
              const Spacer(),
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
      ),
    );
  }
}

// --- PERUBAHAN UTAMA DI SINI ---
// Mengubah _RightPanel menjadi StatefulWidget
class _RightPanel extends StatefulWidget {
  const _RightPanel();

  @override
  State<_RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<_RightPanel> {
  // State untuk mengontrol tampilan mana yang aktif
  bool _showLoginView = false;
  String _selectedRole = '';

  // Fungsi untuk beralih ke tampilan login
  void _selectRole(String role) {
    setState(() {
      _selectedRole = role;
      _showLoginView = true;
    });
  }

  // Fungsi untuk kembali ke pemilihan peran
  void _goBack() {
    setState(() {
      _showLoginView = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 2,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 100),
        // AnimatedSwitcher untuk memberikan transisi fade antar tampilan
        child: // Di dalam method build() di _RightPanelState
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300), 
                transitionBuilder: (Widget child, Animation<double> animation) {
                  // Tween untuk animasi masuk (dari kanan ke tengah)
                  final inAnimation = Tween<Offset>(
                    begin: const Offset(0.5, 0.0),
                    end: Offset.zero,
                  ).animate(animation);

                  // Tween untuk animasi keluar (dari tengah ke kiri)
                  final outAnimation = Tween<Offset>(
                    begin: const Offset(-0.5, 0.0),
                    end: Offset.zero,
                  ).animate(animation);

                  // Tentukan animasi mana yang digunakan berdasarkan key dari child
                  if (child.key == const ValueKey('LoginView')) {
                    // Widget baru masuk, gunakan kombinasi Slide dan Fade
                    return ClipRect(
                      child: SlideTransition(
                        position: inAnimation,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      ),
                    );
                  } else {
                    // Widget lama keluar, gunakan kombinasi Slide dan Fade
                    return ClipRect(
                      child: SlideTransition(
                        position: outAnimation,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      ),
                    );
                  }
                },
                // Switcher akan memilih widget mana yang ditampilkan berdasarkan state
                child: _showLoginView
                    ? _buildLoginView() // Tampilan Login
                    : _buildRoleSelectionView(), // Tampilan Awal
              )
      ),
    );
  }

  // Widget untuk membangun tampilan pemilihan peran
  Widget _buildRoleSelectionView() {
    return Column(
      key: const ValueKey('RoleSelectionView'), // Key untuk AnimatedSwitcher
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
        const SizedBox(height: 16),
        Text(
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore aliqua.',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 40),
        _RoleButton(
          text: 'Dosen',
          onTap: () => _selectRole('Dosen'),
        ),
        const SizedBox(height: 20),
        _RoleButton(
          text: 'Mahasiswa',
          onTap: () => _selectRole('Mahasiswa'),
        ),
      ],
    );
  }

  // Widget untuk membangun tampilan login setelah peran dipilih
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
        const SizedBox(height: 40),
        LoginButton(),
        const SizedBox(height: 30),
        GestureDetector(
          onTap: _goBack, // Fungsi untuk kembali
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Text(
              '<< Kembali pilih peran',
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

// Widget tombol yang sudah memiliki efek hover
class _RoleButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _RoleButton({
    required this.text,
    required this.onTap,
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
    final Border? currentBorder = _isHovered
        ? null
        : Border.all(color: Colors.black, width: 1.5);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
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
            child: Text(
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
