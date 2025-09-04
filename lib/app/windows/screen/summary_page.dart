import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hear_me/constant.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

class SummaryPage extends StatelessWidget {
  final String summaryText;
  final GlobalKey _markdownKey = GlobalKey();

  SummaryPage({super.key, required this.summaryText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12.0, left: 8.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Container(
                    width: 650,
                    margin: const EdgeInsets.symmetric(vertical: 20.0),
                    padding: const EdgeInsets.all(30.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Text(
                            'Ringkasan Sesi',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Column(
                            children: [
                              Expanded(
                                child: RepaintBoundary(
                                  key: _markdownKey,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: SingleChildScrollView(
                                      child: MarkdownBody(
                                        data: summaryText,
                                        styleSheet: _getMarkdownStyleSheet(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildExportButton(context, summaryText),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton(BuildContext context, String summary) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _exportSummaryToPdf(context, summary),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Ekspor ke PDF',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  MarkdownStyleSheet _getMarkdownStyleSheet() {
    return MarkdownStyleSheet(
      p: GoogleFonts.plusJakartaSans(
        color: Colors.black87,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      strong: GoogleFonts.plusJakartaSans(
        color: Colors.black,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
      listBullet: GoogleFonts.plusJakartaSans(
        color: Colors.black87,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      h1: GoogleFonts.plusJakartaSans(
        color: Colors.black,
        fontSize: 26,
        fontWeight: FontWeight.w800,
      ),
      h2: GoogleFonts.plusJakartaSans(
        color: Colors.black,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
      h3: GoogleFonts.plusJakartaSans(
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Future<void> _exportSummaryToPdf(BuildContext context, String summary) async {
    try {
      RenderRepaintBoundary? boundary = _markdownKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception("Could not find MarkdownBody render object.");
      }
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception("Failed to convert image to byte data.");
      }
      Uint8List imageBytes = byteData.buffer.asUint8List();

      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();

      final PdfBitmap bitmap = PdfBitmap(imageBytes);

      double pageHeight = page.getClientSize().height;
      double pageWidth = page.getClientSize().width;
      double aspectRatio = bitmap.width / bitmap.height;

      double imageWidth = pageWidth;
      double imageHeight = imageWidth / aspectRatio;

      if (imageHeight > pageHeight) {
        imageHeight = pageHeight;
        imageWidth = imageHeight * aspectRatio;
      }

      page.graphics.drawImage(
        bitmap,
        Rect.fromLTWH(0, 0, imageWidth, imageHeight),
      );

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/ringkasan.pdf');
      await file.writeAsBytes(await document.save());

      document.dispose();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF berhasil disimpan di: ${file.path}')),
      );
      
      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Tidak dapat membuka file PDF.';
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor PDF: $e')),
      );
    }
  }
}
