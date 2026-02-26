import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:gal/gal.dart'; // New Package
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  bool _isDownloading = false;

  Future<void> _downloadImage(BuildContext context) async {
    // 1. Web par Download allowed nahi
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Download is only available on Mobile App"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isDownloading = true);

    try {
      // 2. Permission Check
      // Android 10+ par permission ki zaroorat nahi hoti Gal package ke sath,
      // lekin purane phones ke liye safe side check kar lete hain.
      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }

      // 3. Get Temporary Directory
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/evidence_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 4. Download File
      await Dio().download(widget.imageUrl, path);

      // 5. Save to Gallery using Gal (Modern Way)
      await Gal.putImage(path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Saved to Gallery!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _isDownloading
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: "Save to Gallery",
                  onPressed: () => _downloadImage(context),
                ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (context, error, stackTrace) => const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.white70, size: 50),
                SizedBox(height: 10),
                Text(
                  "Image not available",
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
