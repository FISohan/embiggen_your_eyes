# stellar_zoom

A deep zoom image viewer for space images, built with Flutter.
[Demo](https://embiggen-your-eyes.pages.dev/)

## About The Project

This application allows users to explore high-resolution space imagery with deep zoom capabilities. It's designed to provide an immersive experience for viewing large astronomical images. The project uses Flutter for the cross-platform user interface and integrates with Firebase for backend services.

### Features

*   **Deep Zoom:** Seamlessly zoom into high-resolution images.
*   **Network Image Caching:** Efficiently loads and caches images from the web.
*   **Local Storage:** Uses Hive for local data persistence.
*   **Text-to-Speech:** Provides accessibility and interactive features.
*   **Firebase Integration:** Utilizes Firebase services, including Firebase AI.
*   **Markdown Support:** Renders markdown content within the app.

## How to Use the App

*   **Explore the Cosmos**: From the home page, you can browse a gallery of stunning astronomical images. Click on any image to start your deep-space exploration.

*   **Deep Zoom & Panning**: In the viewer, use your mouse wheel or the on-screen controls to zoom in and out. Click and drag to pan across the vast expanse of the image.

*   **Add Custom Labels**: Enable 'Add Label' mode to place your own annotations on the image. Long-press on any point of interest to create a new label. You can add a title, description, and even categorize your findings.

*   **AI-Powered Analysis**: Activate 'AI Search' mode and draw a box around any region of the image. The AI assistant will provide a detailed scientific analysis of the selected area, which you can then save as a label.

*   **View and Manage Labels**: Click on a label's icon to view its details. You can edit or delete your custom labels.

*   **Offline Storage**: All the labels you create are saved locally on your device, so you can revisit your discoveries at any time.

## Potential Impact

*   **Educational Tool**: Stellar Zoom serves as an engaging educational resource for students, educators, and astronomy enthusiasts. It transforms the passive viewing of space images into an interactive exploration, making complex astronomical data more accessible and understandable.

*   **Democratizing Science**: By providing easy access to high-resolution imagery from telescopes like Hubble and Webb, the app democratizes the exploration of our universe. Users don't need specialized scientific software to get a detailed look at galaxies, nebulae, and other celestial objects.

*   **Fostering Curiosity**: The ability to freely explore, label, and even ask an AI about any part of an image can spark curiosity and inspire a deeper interest in science and space exploration among users of all ages.

*   **Foundation for Citizen Science**: The architecture of this app lays the groundwork for potential citizen science projects. Future versions could allow users to collaboratively identify and classify celestial objects, contributing to real scientific research.

## How It Works

The application is designed to handle massive images efficiently by breaking them down into smaller, manageable tiles. This allows for a smooth deep zoom experience without requiring prohibitive amounts of memory.

1.  **Homepage Gallery (`home_page.dart`)**:
    *   The app opens to a gallery of astronomical images, which are currently defined in a hardcoded list.
    *   Each image is presented as an `ImageCard`. Clicking on a card navigates the user to the main `Viewer`.

2.  **Tiled Image Viewer (`viewer.dart`)**:
    *   The core of the application is the deep zoom viewer. Instead of loading a single, massive image file, the viewer loads smaller image "tiles" that make up the full picture.
    *   These tiles are organized into multiple zoom levels, each with a different resolution, defined in a `resolutionTable`.

3.  **Dynamic Loading & Rendering (`painter.dart`)**:
    *   As the user pans and zooms, the application calculates which tiles are currently visible in the viewport.
    *   Only the visible tiles for the current zoom level are loaded from the network. This "lazy loading" approach conserves bandwidth and memory.
    *   A `CustomPaint` widget is used to draw the loaded tiles onto the canvas. If a tile hasn't been loaded yet, a "Loading..." placeholder is displayed in its place.

4.  **Caching Strategy**:
    *   Loaded image tiles are kept in an in-memory cache.
    *   To prevent excessive memory consumption, a cache management system automatically removes less relevant tiles (e.g., tiles from distant zoom levels or those outside the current view) when the cache size exceeds a predefined limit (256 MB).

5.  **User-Created Labels**:
    *   Users can enable "Add Label" mode to place custom annotations on the image by long-pressing.
    *   Each label's position is saved as a normalized coordinate, ensuring it stays correctly anchored to its point of interest regardless of the zoom level.
    *   Labels, including titles and descriptions, are saved locally on the user's device using the **Hive** database. Each image has its own dedicated storage "box" for its labels.

6.  **AI-Powered Analysis (`ai.dart`)**:
    *   In "AI Search" mode, a user can draw a box around any region of the image.
    *   The application captures this selected region as a PNG image.
    *   This captured image is sent to the **Gemini 2.5 Pro** model via the `firebase_ai` package.
    *   The AI's analysis of the region is streamed back and displayed in a search panel. The user can then save this analysis as a new label.

## Tech Stack

*   **Framework:** [Flutter](https://flutter.dev/)
*   **Language:** [Dart](https://dart.dev/)
*   **Backend & AI:** [Firebase](https://firebase.google.com/) (Firebase Core, Firebase AI)
*   **Local Storage:** [Hive](https://pub.dev/packages/hive)
*   **HTTP:** [http](https://pub.dev/packages/http)
*   **Image Caching:** [cached_network_image](https://pub.dev/packages/cached_network_image)

## Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites

*   Flutter SDK: [Installation Guide](https://flutter.dev/docs/get-started/install)
*   A configured Firebase project.

### Installation

1.  Clone the repo
    ```sh
    git clone https://github.com/your_username/stellar_zoom.git
    ```
2.  Navigate to the project directory
    ```sh
    cd stellar_zoom
    ```
3.  Install Dart packages
    ```sh
    flutter pub get
    ```
4.  Run the app
    ```sh
    flutter run
    ```

## Project Structure

```
.
├── lib/                # Main application source code
├── assets/             # Images, fonts, and other assets
├── android/            # Android specific files
├── ios/                # iOS specific files
├── web/                # Web specific files
├── pubspec.yaml        # Project dependencies and metadata
└── README.md           # This file
```

## Configuration

This project requires Firebase to be configured for full functionality. Make sure to add your own `google-services.json` (for Android) and configure the iOS and web projects accordingly.
