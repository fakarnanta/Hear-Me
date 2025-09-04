import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hear_me/app/windows/screen/summary_page.dart';
import 'package:hear_me/services/livestream_service.dart';
import 'package:hear_me/services/whiteboard_stream_service.dart';
import 'package:line_icons/line_icon.dart';
import 'package:hear_me/constant.dart';
import 'package:rxdart/rxdart.dart';

class LiveStreamPage extends StatefulWidget {
  const LiveStreamPage({super.key});

  @override
  State<LiveStreamPage> createState() => _LiveStreamPageState();
}

class _LiveStreamPageState extends State<LiveStreamPage> {
  final _livestreamService = LivestreamService();
  final GlobalKey _interactiveViewerKey = GlobalKey();
  bool _hasPerformedInitialFit = false;
  final TransformationController _transformationController = TransformationController();
  StreamSubscription? _summarySubscription;
  StreamSubscription? _pathsSubscription;
  StreamSubscription? _sessionSubscription;

  @override
  void initState() {
    super.initState();

     _summarySubscription = _livestreamService.summaryStream.listen((summary) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SummaryPage(summaryText: summary),
          ),
        );
      }
    });

     _pathsSubscription = _livestreamService.pathsStream.listen((paths) {
      if (paths.isNotEmpty && !_hasPerformedInitialFit) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _fitContentToScreen();
            setState(() {
              _hasPerformedInitialFit = true;
            });
          }
        });
      }
    });

     _sessionSubscription = _livestreamService.isSessionActiveStream.listen((isActive) {
      if (!isActive) {
        setState(() {
          _hasPerformedInitialFit = false;
        });
      }
    });
  }

  @override
  void dispose() {
  _summarySubscription?.cancel();
  _pathsSubscription?.cancel();
  _sessionSubscription?.cancel();
    _livestreamService.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _fitContentToScreen() {
    final renderBox = _interactiveViewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !_livestreamService.pathsStream.hasValue) return;
    final viewportSize = renderBox.size;

    final paths = _livestreamService.pathsStream.value;
    if (paths.isEmpty) {
      _transformationController.value = Matrix4.identity();
      return;
    }

    Rect contentBounds = paths.first.path.getBounds();
    for (var drawingPath in paths) {
      contentBounds = contentBounds.expandToInclude(drawingPath.path.getBounds());
    }

    contentBounds = contentBounds.inflate(50.0);

    if (contentBounds.width <= 0 || contentBounds.height <= 0) return;

    final scaleX = viewportSize.width / contentBounds.width;
    final scaleY = viewportSize.height / contentBounds.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final scaledContentWidth = contentBounds.width * scale;
    final scaledContentHeight = contentBounds.height * scale;
    final translateX = (viewportSize.width - scaledContentWidth) / 2 - (contentBounds.left * scale);
    final translateY = (viewportSize.height - scaledContentHeight) / 2 - (contentBounds.top * scale);

    _transformationController.value = Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
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
      // Set a large boundary for the drawing area, allowing panning freely
      boundaryMargin: const EdgeInsets.all(double.infinity),
      child: StreamBuilder<List<DrawingPath>>(
        stream: _livestreamService.pathsStream,
        initialData: const [],
        builder: (context, snapshot) {
          // The CustomPaint should be allowed to draw anywhere
          return SizedBox(
            width: 2000,
            height: 2000,
            child: CustomPaint(
              painter: DrawingPainter(paths: snapshot.data ?? []),
            ),
          );
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
        color: primaryColor.withOpacity(0.9),
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
          return isDiscovering ? _buildDiscoveryView() : _buildTranscriptionView();
        },
      ),
    );
  }

  Widget _buildTopBar() {
    return StreamBuilder<String>(
      stream: _livestreamService.statusStream,
      initialData: "Terputus",
      builder: (context, statusSnapshot) {
        final statusText = statusSnapshot.data ?? "Terputus";
        final isActive = statusText.contains("Terhubung");
        final User? user = FirebaseAuth.instance.currentUser;

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
              icon: const Icon(Icons.pan_tool, color: Colors.white70),
              onPressed: () {
                if (user != null && user.displayName != null) {
                  _livestreamService.raiseHand(user.displayName!.split(' ').first);
                } else if (user != null) {
                  _livestreamService.raiseHand(user.uid); // Fallback to UID if displayName is null
                }
              },
              tooltip: 'Angkat Tangan',
            ),
            IconButton(
              icon: const Icon(Icons.zoom_out_map, color: Colors.white70),
              onPressed: _fitContentToScreen,
              tooltip: 'Sesuaikan Tampilan ke Layar',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 8.0),
              child: Tooltip(
                message: statusText,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: isActive ? Colors.greenAccent : Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5)),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildTranscriptionView() {
    final scrollController = ScrollController();
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
          child: StreamBuilder<({List<TranscriptEntry> transcripts, TranscriptEntry? partial})>(
            stream: CombineLatestStream.combine2(
                _livestreamService.transcriptsStream,
                _livestreamService.partialTranscriptStream,
                (transcripts, partial) => (transcripts: transcripts, partial: partial)),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }
              final finalTranscripts = snapshot.data!.transcripts;
              final partialEntry = snapshot.data!.partial;

              final allItems = [...finalTranscripts];
              if (partialEntry != null && partialEntry.text.isNotEmpty) {
                allItems.add(partialEntry);
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (scrollController.hasClients && scrollController.position.maxScrollExtent > 0) {
                  scrollController.animateTo(
                    scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                }
              });

              return ListView.builder(
                controller: scrollController,
                itemCount: allItems.length,
                itemBuilder: (context, index) {
                  final entry = allItems[index];
                  final isPartial = (partialEntry != null && partialEntry.text.isNotEmpty) && (index == allItems.length - 1);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text.rich(
                      TextSpan(
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          TextSpan(
                            text: "${entry.speakerId}: ",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPartial ? entry.color.withOpacity(0.7) : entry.color,
                              backgroundColor: isPartial ? Colors.white.withOpacity(0.1) : Colors.transparent,
                            ),
                          ),
                          TextSpan(
                            text: entry.text,
                            style: TextStyle(
                              color: isPartial ? Colors.white.withOpacity(0.7) : Colors.white,
                              backgroundColor: isPartial ? Colors.white.withOpacity(0.1) : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

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