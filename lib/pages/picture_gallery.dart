import 'package:flutter/material.dart';
import '../shared/utils/helpers.dart';
import 'big_picture_page.dart';

class PictureGalleryPage extends StatefulWidget {
  final List<Map<String, String>> images;
  final void Function(int index)? onDelete;
  // we should add a bool to know that the images are preloaded :
  final bool isPreloaded;

  const PictureGalleryPage({
    super.key,
    required this.images,
    this.onDelete,
    required this.isPreloaded,
  });

  @override
  State<PictureGalleryPage> createState() => _PictureGalleryPageState();
}

class _PictureGalleryPageState extends State<PictureGalleryPage> {
  late List<Map<String, String>> galleryImages;

  @override
  void initState() {
    super.initState();
    galleryImages = List.from(widget.images); // Make a copy
  }

  void _deleteImage(int index) {
    setState(() {
      galleryImages.removeAt(index);
    });

    // Optional: call parent to update its copy
    if (widget.onDelete != null) {
      widget.onDelete!(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Foto")),
      body: galleryImages.isEmpty
          ? const Center(child: Text("Nessuna immagine"))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: galleryImages.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final image = galleryImages[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FullImagePage(
                          image: image['image']!,
                          defect: image['defect'] ?? '',
                        ),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.memory(
                            decodeImage(image['image']!),
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            color: Colors.black.withOpacity(0.6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: Text(
                              image['defect'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        if (!widget.isPreloaded)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => _deleteImage(index),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(Icons.close,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
    );
  }
}
