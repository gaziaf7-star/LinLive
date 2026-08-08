import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class MediaLinksDocsView extends StatelessWidget {
  const MediaLinksDocsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Color(0xFF4B0082), // App purple
        elevation: 0,
        title: Text(
          ("Media, Links & Docs").appTr,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600,color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            // Tabs
            Container(
              color: Color(0xFF4B0082),
              child: TabBar(
                indicatorColor: Colors.amber,
                labelColor: Colors.amber,
                unselectedLabelColor: Colors.white70,
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                tabs:  [
                  Tab(text: ("Media").appTr),
                  Tab(text: ("Links").appTr),
                  Tab(text: ("Docs").appTr),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                children: [
                  // Media Grid
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GridView.builder(
                      gridDelegate:
                       SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                        childAspectRatio: 0.6,
                      ),
                      itemCount: 20, // Replace with media list length
                      itemBuilder: (context, index) {
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: AssetImage(
                                  'assets/images/girlprofile.webp'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Links List
                  ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: 10, // Replace with link list length
                    itemBuilder: (context, index) {
                      return Card(
                        color: Colors.deepPurple.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Icon(Icons.link, color: Colors.white),
                          title: Text(
                            "https://example.com/link$index",
                            style: GoogleFonts.poppins(
                                color: Colors.white, fontSize: 14),
                          ),
                          onTap: () {
                            // Open link logic
                          },
                        ),
                      );
                    },
                  ),

                  // Docs List
                  ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: 10, // Replace with docs list length
                    itemBuilder: (context, index) {
                      return Card(
                        color: Colors.deepPurple.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Icon(Icons.insert_drive_file,
                              color: Colors.white),
                          title: Text(
                            ("Document$index.pdf").appTr,
                            style: GoogleFonts.poppins(
                                color: Colors.white, fontSize: 14),
                          ),
                          onTap: () {
                            // Open document logic
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
