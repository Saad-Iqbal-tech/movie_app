Movie Explorer - Flutter App

A modern, production-ready movie discovery mobile application built with Flutter.
This app integrates with the TMDB API to fetch real-time movie data, trailers, genres, and personalized recommendations. It features a sleek UI with smooth animations and an intuitive browsing experience for movie lovers.

✨ Features
🎥 Movie Discovery System
Browse trending, popular, and top-rated movies
View detailed movie information (overview, ratings, release date)
Watch official trailers directly inside the app (YouTube integration)
🔎 Smart Filtering
Filter movies by genres (Action, Comedy, Drama, Horror, etc.)
Sort by popularity, rating, and release date
Search movies instantly with live results
🤖 Recommendation Engine (UI-based)
“Recommended for You” section
Similar movies based on selected title
Genre-based suggestions
🎞 Trailer Experience
Embedded trailer player
Smooth transitions to trailer screen
Full-screen playback support
🎨 Modern UI/UX
Smooth page transitions and hero animations
Netflix-inspired card layout design
Responsive and adaptive UI for all screen sizes
Clean dark-themed interface optimized for movies
⚡ Performance & UX Enhancements
Lazy loading with pagination
Cached images for faster performance
Skeleton loaders while fetching data
Optimized API calls with minimal rebuilds


Prerequisites
Flutter 3.0.0 or higher
Dart 3.0.0 or higher
TMDB API Key (free from https://www.themoviedb.org/
)
Installation
# Extract the project folder
cd movie_explorer

# Install dependencies
flutter pub get

# Run the app
flutter run
🔑 TMDB API Setup
Create an account on TMDB
Go to API section and generate your API key
Open tmdb_service.dart
Replace:
const String apiKey = "YOUR_API_KEY_HERE";
📱 Running on Devices
Android
flutter run -d android
iOS
flutter run -d ios
🔨 Build for Release
Android APK
flutter build apk --release
Android App Bundle
flutter build appbundle --release
iOS
flutter build ios --release
📦 Dependencies
http – API requests to TMDB
provider – State management
cached_network_image – Image optimization
youtube_player_flutter – Trailer playback
carousel_slider – Movie sliders
shimmer – Loading effects
intl – Date formatting
🎨 UI/UX Design
Design Highlights
Netflix-style movie browsing experience
Smooth hero animations between screens
Animated genre chips
Card-based movie grid layout
Dark cinematic theme
Animations Used
Fade transitions
Slide-up movie details animation
Hero image transitions
Loading shimmer effects
🔐 Security Notes
TMDB API key is exposed only for demo purposes
In production:
Store API keys securely (env variables / backend proxy)
Implement rate limiting
Add caching layer for API optimization
📝 API Integration Guide
Fetch Movies

Handled inside tmdb_service.dart:

Trending movies
Popular movies
Top-rated movies
Movie Details
Full metadata from TMDB
Genre mapping
Rating + votes
Trailer Fetching
YouTube video key extraction
Embedded player integration
🐛 Troubleshooting
Issue: API not working
flutter clean
flutter pub get
Issue: Images not loading
Check TMDB image base URL
Verify internet permissions
Issue: Build errors
cd android
./gradlew clean
cd ..
flutter run
🎯 Project Screens
Splash Screen – Animated app intro
Home Screen – Trending & recommended movies
Search Screen – Instant movie search
Movie Detail Screen – Full movie info + trailer
Trailer Screen – YouTube playback UI
📊 State Management
MovieProvider → Handles movie fetching & caching
GenreProvider → Manages filtering system
RecommendationProvider → Handles suggested movies logic
🚀 Performance Tips
Use CachedNetworkImage for posters
Implement pagination for movie lists
Avoid unnecessary rebuilds in provider
Preload trailers for smoother UX
📄 License

MIT License — Free to use for learning and commercial projects.
