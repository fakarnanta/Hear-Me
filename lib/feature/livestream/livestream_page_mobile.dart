import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hear_me/app/windows/screen/summary_page.dart';
import 'package:hear_me/services/livestream_service.dart';
import 'package:hear_me/services/whiteboard_stream_service.dart';
import 'package:line_icons/line_icon.dart';
import 'package:hear_me/constant.dart';

class LiveStreamPage extends StatefulWidget {
  const LiveStreamPage({super.key});

  @override
  State<LiveStreamPage> createState() => _LiveStreamPageState();
}

class _LiveStreamPageState extends State<LiveStreamPage> {
  // Service tetap sama
  final _livestreamService = LivestreamService();
  final GlobalKey _interactiveViewerKey = GlobalKey();
  bool _hasPerformedInitialFit = false;
  final TransformationController _transformationController = TransformationController();

  @override
  // Di dalam file LiveStreamPage.dart -> _LiveStreamPageState

@override
void initState() {
  super.initState();

      _livestreamService.summaryStream.listen((summary) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SummaryPage(summaryText: summary),
          ),
        );
      }
    });
  
  // --- GANTI LOGIKA LAMA DENGAN INI ---
  // Dengarkan perubahan pada data goresan (paths)
  _livestreamService.pathsStream.listen((paths) {
    // Jika ada data goresan DAN penyesuaian awal belum dilakukan
    if (paths.isNotEmpty && !_hasPerformedInitialFit) {
      // Tunggu sesaat agar UI selesai membangun, lalu panggil fitContent
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitContentToScreen();
        // Set flag agar tidak dijalankan lagi secara otomatis
        setState(() {
          _hasPerformedInitialFit = true;
        });
      });
    }
  });

  // Reset flag jika sesi terputus
  _livestreamService.isSessionActiveStream.listen((isActive) {
    if (!isActive) {
      setState(() {
        _hasPerformedInitialFit = false;
      });
    }
  });

  
}

  @override
  void dispose() {
    _livestreamService.dispose();
    _transformationController.dispose(); 
    super.dispose();
  }

  void _fitContentToScreen() {
  // 1. Dapatkan ukuran viewport (layar mobile)
  final renderBox = _interactiveViewerKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || !_livestreamService.pathsController.hasValue) return;
    final viewportSize = renderBox.size;

  // Gunakan .pathsController.value untuk mendapatkan data terakhir
  final paths = _livestreamService.pathsController.value;
  if (paths.isEmpty) {
    // Jika tidak ada goresan, cukup reset view
    _transformationController.value = Matrix4.identity();
    return;
  }

  // 3. Hitung total bounding box (kotak batas) dari semua goresan
  Rect contentBounds = paths.first.path.getBounds();
  for (var drawingPath in paths) {
    contentBounds = contentBounds.expandToInclude(drawingPath.path.getBounds());
  }
  
  // Tambahkan sedikit padding agar tidak terlalu mepet ke tepi
  contentBounds = contentBounds.inflate(50.0);

  if (contentBounds.width == 0 || contentBounds.height == 0) return;

  // 4. Hitung skala yang dibutuhkan
  final scaleX = viewportSize.width / contentBounds.width;
  final scaleY = viewportSize.height / contentBounds.height;
  final scale = scaleX < scaleY ? scaleX : scaleY; // Ambil skala terkecil

  // 5. Hitung posisi tengah (translate)
  final scaledContentWidth = contentBounds.width * scale;
  final scaledContentHeight = contentBounds.height * scale;
  final translateX = (viewportSize.width - scaledContentWidth) / 2 - (contentBounds.left * scale);
  final translateY = (viewportSize.height - scaledContentHeight) / 2 - (contentBounds.top * scale);

  // 6. Terapkan transformasi ke controller
  _transformationController.value = Matrix4.identity()
    ..translate(translateX, translateY)
    ..scale(scale);
}

  @override
  Widget build(BuildContext context) {
    // Mengganti widget utama menjadi Stack
    return Scaffold(
      body: Stack(
        children: <Widget>[
          _buildFullscreenWhiteboard(),

          Positioned(
            top: 47, 
            left: 24,
            right: 24,
            child: _buildTopBar(),
          ),
          Positioned(
            top: 120, 
            left: 24,
            child: _buildFloatingTranscriptPanel(),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

Widget _buildFullscreenWhiteboard() {
  return InteractiveViewer(
    key: _interactiveViewerKey,
    transformationController: _transformationController,
    minScale: 0.1,
    maxScale: 4.0,
    clipBehavior: Clip.none,
    
    child: StreamBuilder<List<DrawingPath>>(
      stream: _livestreamService.pathsStream,
      initialData: const [],
      builder: (context, snapshot) {
        final paths = snapshot.data ?? [];
        if (paths.isEmpty) {
          // Jika tidak ada gambar, kembalikan container kosong
          return Container();
        }

        // --- INI ADALAH BAGIAN PENTING YANG MEMPERBAIKI MASALAH ---
        // 1. Hitung batas total dari semua goresan yang diterima
        Rect contentBounds = paths.first.path.getBounds();
        for (var p in paths) {
          contentBounds = contentBounds.expandToInclude(p.path.getBounds());
        }

        // 2. Beri ukuran yang jelas pada child InteractiveViewer menggunakan SizedBox
        return SizedBox(
          width: contentBounds.width,
          height: contentBounds.height,
          child: CustomPaint(
            painter: DrawingPainter(
              paths: paths,// Berikan info batas ke painter
            ),
          ),
        );
        // -----------------------------------------------------------
      },
    ),
  );
}

  Widget _buildFloatingTranscriptPanel() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.87,
      height: 300, 
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.9), // Beri sedikit transparansi
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: StreamBuilder<bool>(
        stream: _livestreamService.isDiscoveringStream,
        initialData: false,
        builder: (context, snapshot) {
          final isDiscovering = snapshot.data ?? false;
          // Tampilkan view discovery atau view transkrip
          return isDiscovering ? _buildDiscoveryView() : _buildTranscriptionView();
        },
      ),
    );
  }

  /// WIDGET LAMA (tidak berubah, hanya dipanggil di tempat berbeda)
  // Di dalam file LiveStreamPage.dart

Widget _buildTopBar() {
  return StreamBuilder<String>(
    stream: _livestreamService.statusStream,
    initialData: "Terputus",
    builder: (context, statusSnapshot) {
      final statusText = statusSnapshot.data ?? "Terputus";
      final isActive = statusText.contains("Terhubung");
      
      return Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
              )
            ]),
        child: Row(children: [
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: LineIcon.arrowLeft(),
              color: Colors.white),
          const SizedBox(width: 5),
          Text("Judul Sesi",
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const Spacer(),

       
          IconButton(
            icon: const Icon(Icons.zoom_out_map, color: Colors.white70),
            onPressed: _fitContentToScreen, // Memanggil fungsi yang sudah ada
            tooltip: 'Sesuaikan Tampilan ke Layar',
          ),
          
          // --- 2. INDIKATOR STATUS DIUBAH MENJADI LINGKARAN ---
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 8.0),
            child: Tooltip( // Dibungkus Tooltip agar status teks tetap bisa dilihat
              message: statusText,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isActive ? Colors.greenAccent : Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5)
                ),
              ),
            ),
          ),
        ]),
      );
    },
  );
}
  Widget _buildTranscriptionView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 42,
          width: 110,
          decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9),
              borderRadius: BorderRadius.circular(25)),
          child: Center(
              child: Text('Transkrip',
                  style: GoogleFonts.plusJakartaSans(
                      color: primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600))),
        ),
        const SizedBox(height: 15),
        Expanded(
          child: SingleChildScrollView(
            reverse: true,
            child: StreamBuilder<List<String>>(
              stream: _livestreamService.transcriptsStream,
              initialData: ["Menunggu transkripsi..."],
              builder: (context, snapshot) {
                final transcripts = snapshot.data ?? [];
                return Text(
                  transcripts.join('\n\n'),
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// WIDGET LAMA (tidak berubah)
  Widget _buildDiscoveryView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 20),
          StreamBuilder<String>(
            stream: _livestreamService.statusStream,
            initialData: "Mencari server...",
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? '',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              );
            },
          ),
        ],
      ),
    );
  }

  /// WIDGET LAMA (tidak berubah)
  Widget _buildFloatingActionButton() {
    return StreamBuilder<bool>(
      stream: _livestreamService.isSessionActiveStream,
      initialData: false,
      builder: (context, sessionSnapshot) {
        final isSessionActive = sessionSnapshot.data ?? false;
        return StreamBuilder<bool>(
          stream: _livestreamService.isDiscoveringStream,
          initialData: false,
          builder: (context, discoveringSnapshot) {
            final isDiscovering = discoveringSnapshot.data ?? false;
            return FloatingActionButton.extended(
              onPressed: _livestreamService.toggleSession,
              backgroundColor: isSessionActive ? Colors.red : Colors.blue,
              icon: isDiscovering
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Icon(isSessionActive ? Icons.stop : Icons.play_arrow),
              label: Text(isSessionActive ? 'Keluar Sesi' : 'Gabung Sesi'),
            );
          },
        );
      },
    );
  }
}