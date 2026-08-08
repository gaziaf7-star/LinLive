import 'package:flutter/material.dart';

class FacebookImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FacebookImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  _FacebookImageViewerState createState() => _FacebookImageViewerState();
}

class _FacebookImageViewerState extends State<FacebookImageViewer> {
  late PageController pageController;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          /// FULL SCREEN PHOTO VIEW
          // PhotoViewGallery.builder(
          //   itemCount: widget.images.length,
          //   pageController: pageController,
          //   scrollPhysics: BouncingScrollPhysics(),
          //   onPageChanged: (index) {
          //     setState(() {
          //       currentIndex = index;
          //     });
          //   },
          //   builder: (context, index) {
          //     return PhotoViewGalleryPageOptions(
          //       imageProvider: NetworkImage(widget.images[index]),
          //       minScale: PhotoViewComputedScale.contained,
          //       maxScale: PhotoViewComputedScale.covered * 2,
          //     );
          //   },
          // ),

          /// CLOSE BUTTON
          Positioned(
            top: 40,
            left: 15,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          /// INDEX INDICATOR (1/5)
          Positioned(
            top: 45,
            right: 20,
            child: Text(
              "${currentIndex + 1}/${widget.images.length}",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),

          /// LIKE COMMENT SHARE BAR (BOTTOM)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  buildAction(
                    Icons.thumb_up_alt_outlined,
                    "Like",
                  ),
                  buildAction(Icons.mode_comment_outlined, "Comment"),
                  buildAction(Icons.share_outlined, "Share"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAction(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        SizedBox(width: 6),
        Text(text, style: TextStyle(color: Colors.white, fontSize: 16)),
      ],
    );
  }
}
