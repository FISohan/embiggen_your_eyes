import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:stellar_zoom/dataset_metadata.dart';
import 'package:stellar_zoom/viewer.dart';
import 'package:url_launcher/url_launcher.dart';

class ImageCard extends StatefulWidget {
  final Map<String, dynamic> image;

  const ImageCard({super.key, required this.image});

  @override
  State<ImageCard> createState() => _ImageCardState();
}

class _ImageCardState extends State<ImageCard> {
  bool _isHovered = false;

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0), // rounded-lg
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Viewer(
                  resolutionTable: widget.image['resTable'],
                  id: widget.image['id'],
                  creditLink: widget.image['creditLink'],
                  creditTitle: widget.image['creditTitle'],
                ),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: widget.image['imageUrl']!,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
              // Hover overlay with description
              AnimatedOpacity(
                opacity: _isHovered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.image['title']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          widget.image['description']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14.0,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Always visible bottom section with title and credit
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedOpacity(
                        opacity: _isHovered ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          widget.image['title']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      InkWell(
                        onTap: () => _launchUrl(widget.image['creditLink']!),
                        child: Text(
                          'Credit: ${widget.image['creditTitle']}',
                          style: TextStyle(
                            fontSize: 12.0,
                            color: Colors.blue[300],
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1A23), // background-dark
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                _buildHeroSection(context),
                _buildImageGallery(context),
              ],
            ),
          ),
          _buildHeader(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      // sticky top-0 z-50 flex items-center justify-between whitespace-nowrap border-b border-white/10 bg-background-dark/50 px-6 py-4 backdrop-blur-md md:px-10
      color: const Color(0xFF0F1A23).withOpacity(0.5), // bg-background-dark/50
      padding: const EdgeInsets.symmetric(
        horizontal: 24.0,
        vertical: 16.0,
      ), // px-6 py-4
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // SVG logo is omitted as per user's request
              Text(
                "Stellar Zoom", // Changed from Embiggen Your Eyes
                style: TextStyle(
                  fontSize: 20.0, // text-xl
                  fontWeight: FontWeight.bold, // font-bold
                  color: Colors.white,
                  shadows: [
                    // text-glow
                    Shadow(
                      color: const Color(0xFF0090FF).withOpacity(0.5),
                      blurRadius: 8.0,
                    ),
                    Shadow(
                      color: const Color(0xFF0090FF).withOpacity(0.3),
                      blurRadius: 20.0,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Navigation links (User Manual)
          TextButton(
            onPressed: () {
              // Handle navigation
            },
            child: const Text(
              "User Manual",
              style: TextStyle(
                fontSize: 14.0, // text-sm
                fontWeight: FontWeight.w500, // font-medium
                color: Colors.white70, // text-white/80
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      // relative flex h-[80vh] min-h-[480px] w-full flex-col items-center justify-center bg-cover bg-fixed bg-center bg-no-repeat px-4 text-center
      height: 300, // Approximate h-[80vh] and min-h-[480px]
      width: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: CachedNetworkImageProvider(
            "https://lh3.googleusercontent.com/aida-public/AB6AXuAiyZCOn2JumdigW-Rg0DUpLSEVtzKJlzdpKA0uVgEv30kZVD8r_PuRmVMuxgkdkc8ehSK-FM_0LqL0V12ROELQDL4JPXhrghQ7NPesv0z6fW1-Ke5XEDQes2MSd_iBvuzuihSrtpSe60DotIvmKmXzgUKKf7wfpEPh-13Vb2hXIW6ifx2W9o9HJE2JQ50XBXeE-uE7r2I4RgoKnHmYOi5qFbdm7Nmkk6LBaMZrNTjWdunNXL5s3XSHztrGFtFSvqW_3RVPWQk40G6H",
          ),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          colorFilter: ColorFilter.mode(
            const Color(0xFF0F1A23).withOpacity(
              0.6,
            ), // linear-gradient(rgba(15, 26, 35, 0.6) 0%, rgba(15, 26, 35, 1) 100%)
            BlendMode.darken,
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Explore the Cosmos in Unprecedented Detail.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32.0, // text-4xl md:text-6xl
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                // text-glow
                Shadow(
                  color: const Color(0xFF0090FF).withOpacity(0.5),
                  blurRadius: 8.0,
                ),
                Shadow(
                  color: const Color(0xFF0090FF).withOpacity(0.3),
                  blurRadius: 20.0,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8.0), // gap-6
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0), // px-4
            child: Text(
              "Your personal observatory for the universe's most breathtaking wonders.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18.0, // text-lg md:text-xl
                color: Colors.white70, // text-white/70
              ),
            ),
          ),
          const SizedBox(height: 16.0), // mt-4 (from button)
        ],
      ),
    );
  }

  Widget _buildImageGallery(BuildContext context) {
    final List<Map<String, dynamic>> images = [
      {
        "title": "Andromeda Galaxy",
        "id": messiar13,
        "resTable": resolutionTableMessiar13,
        "description":
            "A breathtaking view of the Carina Nebula's cliffs, sculpted by stellar winds.",
        "imageUrl":
            "https://cdn.esahubble.org/archives/images/screen/heic2501a.jpg",
        "creditTitle": "NASA, ESA, B. Williams (University of Washington)",
        "creditLink": "https://esahubble.org/images/heic0506a/",
      },
      {
        "title": "The Whirlpool Galaxy",
        "id": messiar51,
        "resTable": resolutionTableM51,
        "description":
            "A breathtaking view of the Carina Nebula's cliffs, sculpted by stellar winds.",
        "imageUrl":
            "https://cdn.esahubble.org/archives/images/screen/heic0506a.jpg",
        "creditLink": "https://esahubble.org/images/heic0506a/",
        "creditTitle": "ESA/Hubble",
      },
      {
        "title": "Sombrero Galaxy",
        "id": sombreroGalaxy,
        "resTable": resolutionTableSombreroGalaxy,
        "description":
            "A breathtaking view of the Carina Nebula's cliffs, sculpted by stellar winds.",
        "imageUrl":
            "https://cdn.esahubble.org/archives/images/wallpaper1/opo0328a.jpg",
        "creditLink": "https://esahubble.org/images/opo0328a/",
        "creditTitle": "ESA/Hubble",
      },
      {
        "title": "Sun",
        "id": sun,
        "resTable": resolutionTableSun,
        "description":
            "A breathtaking view of the Carina Nebula's cliffs, sculpted by stellar winds.",
        "imageUrl":
            "http://sohan.sgp1.cdn.digitaloceanspaces.com/PIA26681_modest.jpg",
        "creditLink": "https://photojournal.jpl.nasa.gov/catalog/PIA26681",
        "creditTitle": "NASA/JPL-Caltech",
      },
      {
        "title": "The Central Parts of the Milky Way",
        "id": milkWay,
        "resTable": resolutionTableMilkWay,
        "description":
            "A breathtaking view of the Carina Nebula's cliffs, sculpted by stellar winds.",
        "imageUrl": "https://cdn.eso.org/images/wallpaper1/eso1242a.jpg",
        "creditLink": "https://www.eso.org/public/images/eso1242a/",
        "creditTitle": "ESO",
      },
      {
        "title": "Carina Nebula Jets",
        "id": carina,
        "resTable": resolutionTableCarina,
        "description":
            "A breathtaking view of the Carina Nebula's cliffs, sculpted by stellar winds.",
        "imageUrl":
            "https://cdn.esawebb.org/archives/images/screen/carinanebula3.jpg",
        "creditLink": "https://esawebb.org/images/carinanebula3/",
        "creditTitle": "ESA/Webb",
      },
      {
        "title": "Tapestry of Blazing Starbirth",
        "id": tapestryOfBlazingStarbirth,
        "resTable": resolutionTableTapestryOfBlazingStarbirth,
        "description":
            "A breathtaking view of the Carina Nebula's cliffs, sculpted by stellar winds.",
        "imageUrl":
            "https://cdn.esahubble.org/archives/images/screen/heic2007a.jpg",
        "creditLink": "https://esawebb.org/images/carinanebula3/",
        "creditTitle": "ESA/Webb",
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 64.0,
      ), // px-4 py-16
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Image Gallery",
            style: TextStyle(
              fontSize: 28.0, // text-3xl
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                // text-glow
                Shadow(
                  color: const Color(0xFF0090FF).withOpacity(0.5),
                  blurRadius: 8.0,
                ),
                Shadow(
                  color: const Color(0xFF0090FF).withOpacity(0.3),
                  blurRadius: 20.0,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32.0), // mb-8
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:
                  3, // md:grid-cols-3, lg:grid-cols-3, xl:grid-cols-3
              crossAxisSpacing: 24.0, // gap-6
              mainAxisSpacing: 24.0, // gap-6
              childAspectRatio: 1.0, // Adjust as needed
            ),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final image = images[index];
              return ImageCard(image: image);
            },
          ),
        ],
      ),
    );
  }
}
