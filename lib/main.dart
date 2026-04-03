// ============================================================
//  CINESCOPE v2 — Movie & TV Trailer App
//  Powered by TMDB API
//
//  pubspec.yaml dependencies:
//    provider: ^6.1.2
//    http: ^1.2.1
//    cached_network_image: ^3.3.1
//    shimmer: ^3.0.0
//    shared_preferences: ^2.2.3
//    webview_flutter: ^4.7.0
//    flutter_launcher_icons: ^0.14.1  (dev_dependency)
//
//  AndroidManifest.xml — add inside <manifest>:
//    <uses-permission android:name="android.permission.INTERNET"/>
//
//  See SETUP.md for icon & pubspec instructions.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ═══════════════════════════════════════════════════════
//  ENTRY POINT
// ═══════════════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const CineScopeApp());
}

// ═══════════════════════════════════════════════════════
//  DESIGN SYSTEM
// ═══════════════════════════════════════════════════════

class C {
  static const bg        = Color(0xFF0A0A0F);
  static const surface   = Color(0xFF12121A);
  static const card      = Color(0xFF1A1A26);
  static const red       = Color(0xFFE50914);
  static const gold      = Color(0xFFFFBF00);
  static const text      = Color(0xFFF5F5F5);
  static const textDim   = Color(0xFF9E9E9E);
  static const divider   = Color(0xFF2A2A3A);
  static const sBase     = Color(0xFF1E1E2E);
  static const sHigh     = Color(0xFF2E2E3E);
}

class T {
  static const d1 = TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
      color: C.text, letterSpacing: -0.5);
  static const h1 = TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
      color: C.text, letterSpacing: -0.3);
  static const h2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: C.text);
  static const h3 = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: C.text);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.w400,
      color: C.text, height: 1.55);
  static const small = TextStyle(fontSize: 12, color: C.textDim);
  static const label = TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
      color: C.textDim, letterSpacing: 1.2);
}

ThemeData appTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: C.bg,
  colorScheme: const ColorScheme.dark(primary: C.red, surface: C.surface, background: C.bg),
  appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0,
      titleTextStyle: T.h1, iconTheme: IconThemeData(color: C.text)),
  inputDecorationTheme: InputDecorationTheme(
    filled: true, fillColor: C.card,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    hintStyle: T.body.copyWith(color: C.textDim),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: C.red, foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0, textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: C.card, selectedColor: C.red.withOpacity(0.2),
    labelStyle: T.small, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: C.divider)),
  ),
);

// ═══════════════════════════════════════════════════════
//  TMDB SERVICE
// ═══════════════════════════════════════════════════════

class TmdbService {
  static const _key  = '765624a778d3a369c049d69c8bad2f9a';
  static const _base = 'https://api.themoviedb.org/3';
  static const _img  = 'https://image.tmdb.org/t/p';

  static String poster(String? path, {String size = 'w500'}) =>
      path != null && path.isNotEmpty ? '$_img/$size$path' : '';
  static String backdrop(String? path, {String size = 'w1280'}) =>
      path != null && path.isNotEmpty ? '$_img/$size$path' : '';

  final Map<String, dynamic> _cache = {};

  Future<Map<String, dynamic>?> _get(String endpoint,
      {Map<String, String> params = const {}}) async {
    final key = '$endpoint?${params.toString()}';
    if (_cache.containsKey(key)) return _cache[key];
    try {
      final uri = Uri.parse('$_base$endpoint').replace(queryParameters: {
        'api_key': _key, 'language': 'en-US', ...params,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        _cache[key] = data;
        return data;
      }
    } catch (e) { debugPrint('TMDB error: $e'); }
    return null;
  }

  // ── Movies ──────────────────────────────────────────
  Future<List<TmdbItem>> trendingMovies({int page = 1}) async {
    final d = await _get('/trending/movie/week', params: {'page': '$page'});
    return _parseItems(d, 'movie');
  }

  Future<List<TmdbItem>> popularMovies({int page = 1}) async {
    final d = await _get('/movie/popular', params: {'page': '$page'});
    return _parseItems(d, 'movie');
  }

  Future<List<TmdbItem>> topRatedMovies({int page = 1}) async {
    final d = await _get('/movie/top_rated', params: {'page': '$page'});
    return _parseItems(d, 'movie');
  }

  Future<List<TmdbItem>> upcomingMovies({int page = 1}) async {
    final d = await _get('/movie/upcoming', params: {'page': '$page'});
    return _parseItems(d, 'movie');
  }

  Future<List<TmdbItem>> moviesByGenre(int genreId, {int page = 1}) async {
    final d = await _get('/discover/movie',
        params: {'with_genres': '$genreId', 'page': '$page', 'sort_by': 'popularity.desc'});
    return _parseItems(d, 'movie');
  }

  Future<List<TmdbItem>> discoverMovies({
    int page = 1, int? genreId, String? country, String? sortBy, int? year,
  }) async {
    final p = <String, String>{'page': '$page', 'sort_by': sortBy ?? 'popularity.desc'};
    if (genreId != null) p['with_genres'] = '$genreId';
    if (country != null && country.isNotEmpty) p['with_origin_country'] = country;
    if (year != null) p['primary_release_year'] = '$year';
    final d = await _get('/discover/movie', params: p);
    return _parseItems(d, 'movie');
  }

  Future<List<TmdbItem>> searchMovies(String query, {int page = 1}) async {
    final d = await _get('/search/movie',
        params: {'query': query, 'page': '$page'});
    return _parseItems(d, 'movie');
  }

  Future<List<TmdbItem>> movieRecommendations(int id) async {
    final d = await _get('/movie/$id/recommendations');
    return _parseItems(d, 'movie');
  }

  Future<TmdbItem?> movieDetail(int id) async {
    final d = await _get('/movie/$id',
        params: {'append_to_response': 'credits,videos'});
    if (d == null) return null;
    return TmdbItem.fromDetailJson(d, 'movie');
  }

  // ── TV ───────────────────────────────────────────────
  Future<List<TmdbItem>> trendingTv({int page = 1}) async {
    final d = await _get('/trending/tv/week', params: {'page': '$page'});
    return _parseItems(d, 'tv');
  }

  Future<List<TmdbItem>> popularTv({int page = 1}) async {
    final d = await _get('/tv/popular', params: {'page': '$page'});
    return _parseItems(d, 'tv');
  }

  Future<List<TmdbItem>> topRatedTv({int page = 1}) async {
    final d = await _get('/tv/top_rated', params: {'page': '$page'});
    return _parseItems(d, 'tv');
  }

  Future<List<TmdbItem>> discoverTv({
    int page = 1, int? genreId, String? country, String? sortBy,
  }) async {
    final p = <String, String>{'page': '$page', 'sort_by': sortBy ?? 'popularity.desc'};
    if (genreId != null) p['with_genres'] = '$genreId';
    if (country != null && country.isNotEmpty) p['with_origin_country'] = country;
    final d = await _get('/discover/tv', params: p);
    return _parseItems(d, 'tv');
  }

  Future<List<TmdbItem>> searchTv(String query, {int page = 1}) async {
    final d = await _get('/search/tv', params: {'query': query, 'page': '$page'});
    return _parseItems(d, 'tv');
  }

  Future<TmdbItem?> tvDetail(int id) async {
    final d = await _get('/tv/$id',
        params: {'append_to_response': 'credits,videos'});
    if (d == null) return null;
    return TmdbItem.fromDetailJson(d, 'tv');
  }

  // ── Multi search ─────────────────────────────────────
  Future<List<TmdbItem>> searchMulti(String query, {int page = 1}) async {
    final d = await _get('/search/multi',
        params: {'query': query, 'page': '$page'});
    if (d == null) return [];
    final results = (d['results'] as List? ?? [])
        .where((r) => r['media_type'] == 'movie' || r['media_type'] == 'tv')
        .map((r) => TmdbItem.fromJson(r, r['media_type'] ?? 'movie'))
        .toList();
    return results;
  }

  // ── Videos / Trailers ────────────────────────────────
  Future<String?> getTrailerKey(int id, String type) async {
    final endpoint = type == 'tv' ? '/tv/$id/videos' : '/movie/$id/videos';
    final d = await _get(endpoint);
    if (d == null) return null;
    final videos = (d['results'] as List? ?? []);
    // Prefer official trailers
    for (final v in videos) {
      if (v['site'] == 'YouTube' &&
          (v['type'] == 'Trailer' || v['type'] == 'Teaser') &&
          v['official'] == true) {
        return v['key'];
      }
    }
    for (final v in videos) {
      if (v['site'] == 'YouTube') return v['key'];
    }
    return null;
  }

  // ── Genres ───────────────────────────────────────────
  Future<List<Genre>> movieGenres() async {
    final d = await _get('/genre/movie/list');
    return (d?['genres'] as List? ?? []).map((g) => Genre.fromJson(g)).toList();
  }

  Future<List<Genre>> tvGenres() async {
    final d = await _get('/genre/tv/list');
    return (d?['genres'] as List? ?? []).map((g) => Genre.fromJson(g)).toList();
  }

  // ── Helpers ──────────────────────────────────────────
  List<TmdbItem> _parseItems(Map<String, dynamic>? d, String type) {
    if (d == null) return [];
    return (d['results'] as List? ?? [])
        .map((r) => TmdbItem.fromJson(r, type))
        .where((i) => i.posterPath.isNotEmpty)
        .toList();
  }
}

// ═══════════════════════════════════════════════════════
//  MODELS
// ═══════════════════════════════════════════════════════

class Genre {
  final int id;
  final String name;
  Genre({required this.id, required this.name});
  factory Genre.fromJson(Map<String, dynamic> j) =>
      Genre(id: j['id'], name: j['name'] ?? '');
}

class TmdbItem {
  final int id;
  final String type; // 'movie' | 'tv'
  final String title;
  final String posterPath;
  final String backdropPath;
  final String overview;
  final String releaseDate;
  final double voteAverage;
  final List<int> genreIds;
  // Detail fields (loaded separately)
  final String? tagline;
  final int? runtime;
  final String? status;
  final List<String> genres;
  final List<String> cast;
  final String? director;
  final String? trailerKey;
  final String? originCountry;
  bool isWatchlisted;

  TmdbItem({
    required this.id, required this.type, required this.title,
    required this.posterPath, required this.backdropPath,
    required this.overview, required this.releaseDate,
    required this.voteAverage, required this.genreIds,
    this.tagline, this.runtime, this.status, this.genres = const [],
    this.cast = const [], this.director, this.trailerKey,
    this.originCountry, this.isWatchlisted = false,
  });

  factory TmdbItem.fromJson(Map<String, dynamic> j, String type) {
    final isMovie = type == 'movie';
    return TmdbItem(
      id: j['id'] ?? 0,
      type: type,
      title: (isMovie ? j['title'] : j['name']) ?? 'Unknown',
      posterPath: j['poster_path'] ?? '',
      backdropPath: j['backdrop_path'] ?? '',
      overview: j['overview'] ?? '',
      releaseDate: (isMovie ? j['release_date'] : j['first_air_date']) ?? '',
      voteAverage: ((j['vote_average'] ?? 0) as num).toDouble(),
      genreIds: List<int>.from(j['genre_ids'] ?? []),
      originCountry: (j['origin_country'] as List?)?.isNotEmpty == true
          ? j['origin_country'][0] : null,
    );
  }

  factory TmdbItem.fromDetailJson(Map<String, dynamic> j, String type) {
    final isMovie = type == 'movie';
    final genres = (j['genres'] as List? ?? []).map((g) => g['name'] as String).toList();
    final cast = ((j['credits']?['cast'] as List?) ?? [])
        .take(6).map((c) => c['name'] as String).toList();
    String? director;
    if (isMovie) {
      final crew = (j['credits']?['crew'] as List? ?? []);
      director = crew.firstWhere((c) => c['job'] == 'Director',
          orElse: () => {})['name'];
    }
    // Find best trailer
    String? trailerKey;
    final videos = (j['videos']?['results'] as List? ?? []);
    for (final v in videos) {
      if (v['site'] == 'YouTube' && v['type'] == 'Trailer' && v['official'] == true) {
        trailerKey = v['key']; break;
      }
    }
    trailerKey ??= videos.firstWhere(
            (v) => v['site'] == 'YouTube', orElse: () => {})['key'];

    final countries = (j['origin_country'] as List?)?.cast<String>() ??
        (j['production_countries'] as List? ?? []).map((c) => c['iso_3166_1'] as String).toList();

    return TmdbItem(
      id: j['id'] ?? 0, type: type,
      title: (isMovie ? j['title'] : j['name']) ?? 'Unknown',
      posterPath: j['poster_path'] ?? '',
      backdropPath: j['backdrop_path'] ?? '',
      overview: j['overview'] ?? '',
      releaseDate: (isMovie ? j['release_date'] : j['first_air_date']) ?? '',
      voteAverage: ((j['vote_average'] ?? 0) as num).toDouble(),
      genreIds: [],
      tagline: j['tagline'],
      runtime: isMovie ? j['runtime'] : (j['episode_run_time'] as List?)?.firstOrNull,
      status: j['status'],
      genres: genres, cast: cast, director: director, trailerKey: trailerKey,
      originCountry: countries.isNotEmpty ? countries.first : null,
    );
  }

  String get year => releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';
  String get ratingStr => voteAverage > 0 ? voteAverage.toStringAsFixed(1) : 'N/A';
  bool get hasPoster => posterPath.isNotEmpty;
  bool get hasBackdrop => backdropPath.isNotEmpty;
  String get posterUrl => TmdbService.poster(posterPath);
  String get backdropUrl => TmdbService.backdrop(backdropPath);

  // For watchlist persistence
  String toJson() => jsonEncode({
    'id': id, 'type': type, 'title': title,
    'poster_path': posterPath, 'backdrop_path': backdropPath,
    'overview': overview, 'release_date': releaseDate,
    'vote_average': voteAverage, 'genre_ids': genreIds,
  });

  factory TmdbItem.fromJsonStr(String s) {
    final j = jsonDecode(s);
    return TmdbItem.fromJson(j, j['type'] ?? 'movie');
  }
}

// ═══════════════════════════════════════════════════════
//  USER PREFERENCES & STATE
// ═══════════════════════════════════════════════════════

class UserPrefs {
  final List<String> watchlist; // serialised TmdbItem JSON strings
  final bool onboardingDone;
  final bool isGuest;
  final String userName;
  final List<int> likedGenreIds;

  UserPrefs({
    this.watchlist = const [], this.onboardingDone = false,
    this.isGuest = false, this.userName = 'Guest', this.likedGenreIds = const [],
  });

  UserPrefs copyWith({List<String>? watchlist, bool? onboardingDone,
    bool? isGuest, String? userName, List<int>? likedGenreIds}) => UserPrefs(
    watchlist: watchlist ?? this.watchlist,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    isGuest: isGuest ?? this.isGuest,
    userName: userName ?? this.userName,
    likedGenreIds: likedGenreIds ?? this.likedGenreIds,
  );

  List<TmdbItem> get watchlistItems =>
      watchlist.map((s) { try { return TmdbItem.fromJsonStr(s); } catch (_) { return null; } })
          .whereType<TmdbItem>().toList();
}

class AppState extends ChangeNotifier {
  UserPrefs _prefs = UserPrefs();
  UserPrefs get prefs => _prefs;

  Future<void> init() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _prefs = UserPrefs(
        watchlist: sp.getStringList('watchlist') ?? [],
        onboardingDone: sp.getBool('onboarding_done') ?? false,
        isGuest: sp.getBool('is_guest') ?? false,
        userName: sp.getString('user_name') ?? 'Guest',
        likedGenreIds: (sp.getStringList('liked_genres') ?? []).map(int.parse).toList(),
      );
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList('watchlist', _prefs.watchlist);
      await sp.setBool('onboarding_done', _prefs.onboardingDone);
      await sp.setBool('is_guest', _prefs.isGuest);
      await sp.setString('user_name', _prefs.userName);
      await sp.setStringList('liked_genres',
          _prefs.likedGenreIds.map((i) => i.toString()).toList());
    } catch (_) {}
  }

  Future<void> loginAsGuest() async {
    _prefs = _prefs.copyWith(isGuest: true, userName: 'Guest');
    await _save(); notifyListeners();
  }

  Future<void> completeOnboarding(List<int> genreIds) async {
    _prefs = _prefs.copyWith(onboardingDone: true, likedGenreIds: genreIds);
    await _save(); notifyListeners();
  }

  Future<void> logout() async {
    _prefs = UserPrefs();
    await _save(); notifyListeners();
  }

  bool isWatchlisted(int id) =>
      _prefs.watchlist.any((s) => s.contains('"id":$id'));

  Future<void> toggleWatchlist(TmdbItem item) async {
    final list = List<String>.from(_prefs.watchlist);
    final idx = list.indexWhere((s) => s.contains('"id":${item.id}'));
    if (idx >= 0) {
      list.removeAt(idx);
    } else {
      list.add(item.toJson());
    }
    _prefs = _prefs.copyWith(watchlist: list);
    await _save(); notifyListeners();
  }
}

// ═══════════════════════════════════════════════════════
//  ROOT APP
// ═══════════════════════════════════════════════════════

class CineScopeApp extends StatelessWidget {
  const CineScopeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tmdb = TmdbService();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..init()),
        Provider.value(value: tmdb),
      ],
      child: MaterialApp(
        title: 'CineScope',
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  SPLASH
// ═══════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _fade, _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _fade  = CurvedAnimation(parent: _c, curve: Curves.easeIn);
    _scale = Tween(begin: 0.78, end: 1.0).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
    _c.forward();
    Future.delayed(const Duration(milliseconds: 2600), _nav);
  }

  void _nav() {
    if (!mounted) return;
    final p = context.read<AppState>().prefs;
    Widget dest = p.isGuest
        ? (p.onboardingDone ? const MainShell() : const OnboardingScreen())
        : const LoginScreen();
    Navigator.of(context).pushReplacement(_fade_(dest));
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    body: Center(child: FadeTransition(opacity: _fade,
        child: ScaleTransition(scale: _scale, child: const _Logo(size: 100)))),
  );
}

// ═══════════════════════════════════════════════════════
//  LOGIN  (guest-only for now)
// ═══════════════════════════════════════════════════════

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF1C0000), C.bg],
      )),
      child: SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(children: [
          const SizedBox(height: 60),
          const _Logo(size: 80),
          const SizedBox(height: 20),
          const Text('CINESCOPE', style: TextStyle(fontSize: 26,
              fontWeight: FontWeight.w800, color: C.text, letterSpacing: 5)),
          const SizedBox(height: 6),
          const Text('Your cinematic universe', style: T.small),
          const Spacer(),
          // Disabled fields — auth in Phase 2
          _disabledField('EMAIL', 'you@example.com', Icons.email_outlined),
          const SizedBox(height: 14),
          _disabledField('PASSWORD', '••••••••', Icons.lock_outline, obscure: true),
          const SizedBox(height: 20),
          Opacity(opacity: 0.35,
            child: ElevatedButton(
              onPressed: () => _snack(context, '🔧 Auth coming in Phase 2'),
              child: const Text('Sign In'),
            ),
          ),
          const SizedBox(height: 12),
          _badge(),
          const SizedBox(height: 28),
          _divider(),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => _guest(context),
            icon: const Icon(Icons.person_outline_rounded),
            label: const Text('Continue as Guest'),
            style: ElevatedButton.styleFrom(backgroundColor: C.surface,
                side: const BorderSide(color: C.divider)),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _snack(context, '🔧 Sign Up coming in Phase 2'),
            child: const Text.rich(TextSpan(children: [
              TextSpan(text: "Don't have an account? ", style: T.small),
              TextSpan(text: 'Sign Up', style: TextStyle(color: C.textDim,
                  fontSize: 12, decoration: TextDecoration.lineThrough)),
            ])),
          ),
          const SizedBox(height: 32),
        ]),
      )),
    ),
  );

  Widget _disabledField(String lbl, String hint, IconData icon, {bool obscure = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(lbl, style: T.label),
        const SizedBox(height: 6),
        TextField(enabled: false, obscureText: obscure,
            style: const TextStyle(color: C.textDim),
            decoration: InputDecoration(hintText: hint,
                prefixIcon: Icon(icon, color: C.textDim))),
      ]);

  Widget _badge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.divider)),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.construction_rounded, size: 13, color: C.gold),
      SizedBox(width: 6),
      Text('Auth available in Phase 2',
          style: TextStyle(color: C.gold, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _divider() => Row(children: [
    const Expanded(child: Divider(color: C.divider)),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text('or', style: T.small.copyWith(color: C.textDim.withOpacity(0.6)))),
    const Expanded(child: Divider(color: C.divider)),
  ]);

  void _guest(BuildContext context) async {
    await context.read<AppState>().loginAsGuest();
    if (!context.mounted) return;
    final p = context.read<AppState>().prefs;
    Navigator.of(context).pushReplacement(_fade_(
        p.onboardingDone ? const MainShell() : const OnboardingScreen()));
  }

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: C.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
}

// ═══════════════════════════════════════════════════════
//  ONBOARDING  (pick genres, not movies)
// ═══════════════════════════════════════════════════════

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override State<OnboardingScreen> createState() => _OnboardState();
}

class _OnboardState extends State<OnboardingScreen> {
  final Set<int> _sel = {};
  bool _loading = true;
  List<Genre> _genres = [];

  @override
  void initState() {
    super.initState();
    context.read<TmdbService>().movieGenres().then((g) {
      if (!mounted) return;
      setState(() { _genres = g; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(24, 28, 24, 0), child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Logo(size: 44, showText: true),
        const SizedBox(height: 32),
        const Text('What do you love?', style: T.d1),
        const SizedBox(height: 8),
        const Text('Pick genres you enjoy. We\'ll build your feed around them.',
            style: T.small),
        const SizedBox(height: 20),
        AnimatedContainer(duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _sel.isNotEmpty ? C.red.withOpacity(0.12) : C.card,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _sel.isNotEmpty ? C.red : C.divider),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_outline, size: 15,
                color: _sel.isNotEmpty ? C.red : C.textDim),
            const SizedBox(width: 8),
            Text('${_sel.length} selected',
                style: TextStyle(color: _sel.isNotEmpty ? C.red : C.textDim,
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
      ]),
      ),
      const SizedBox(height: 20),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: C.red))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Wrap(spacing: 10, runSpacing: 10, children: _genres.map((g) {
          final on = _sel.contains(g.id);
          return GestureDetector(
            onTap: () => setState(() => on ? _sel.remove(g.id) : _sel.add(g.id)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: on ? C.red : C.card,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: on ? C.red : C.divider),
                boxShadow: on ? [BoxShadow(color: C.red.withOpacity(0.35),
                    blurRadius: 10)] : [],
              ),
              child: Text(g.name, style: TextStyle(
                  color: on ? Colors.white : C.textDim,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 14)),
            ),
          );
        }).toList()),
      ),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: ElevatedButton(
          onPressed: () async {
            await context.read<AppState>().completeOnboarding(_sel.toList());
            if (!mounted) return;
            Navigator.of(context).pushReplacement(_fade_(const MainShell()));
          },
          child: Text(_sel.isEmpty ? 'Skip for Now' : 'Start Watching →'),
        ),
      ),
    ])),
  );
}

// ═══════════════════════════════════════════════════════
//  MAIN SHELL
// ═══════════════════════════════════════════════════════

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _ShellState();
}

class _ShellState extends State<MainShell> {
  int _i = 0;
  final _pages = const [HomeScreen(), MoviesScreen(), TvScreen(), SearchScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _i, children: _pages),
    bottomNavigationBar: _nav(),
  );

  Widget _nav() => Container(
    decoration: const BoxDecoration(color: C.surface,
        border: Border(top: BorderSide(color: C.divider, width: 0.5))),
    child: SafeArea(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _item(Icons.home_rounded, 'Home', 0),
        _item(Icons.movie_outlined, 'Movies', 1),
        _item(Icons.tv_outlined, 'TV', 2),
        _item(Icons.search_rounded, 'Search', 3),
        _item(Icons.person_outline_rounded, 'Profile', 4),
      ]),
    )),
  );

  Widget _item(IconData icon, String lbl, int idx) {
    final on = _i == idx;
    return GestureDetector(
      onTap: () => setState(() => _i = idx),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: on ? C.red.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: on ? C.red : C.textDim, size: 22),
          const SizedBox(height: 3),
          Text(lbl, style: TextStyle(fontSize: 10,
              color: on ? C.red : C.textDim,
              fontWeight: on ? FontWeight.w700 : FontWeight.normal)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  HOME SCREEN
// ═══════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  TmdbItem? _hero;
  List<TmdbItem> _trending = [], _topRated = [], _popular = [], _tvTrending = [];
  bool _loading = true;
  String? _err;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _err = null; });
    try {
      final tmdb = context.read<TmdbService>();
      final results = await Future.wait([
        tmdb.trendingMovies(),
        tmdb.topRatedMovies(),
        tmdb.popularMovies(),
        tmdb.trendingTv(),
      ]);
      _trending   = results[0];
      _topRated   = results[1];
      _popular    = results[2];
      _tvTrending = results[3];
      // Pick hero: random from trending that has backdrop
      final heroes = _trending.where((m) => m.hasBackdrop).toList();
      if (heroes.isNotEmpty) {
        _hero = heroes[Random().nextInt(heroes.length.clamp(1, 5))];
      }
    } catch (_) { _err = 'Failed to load. Pull to refresh.'; }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    body: RefreshIndicator(onRefresh: _load, color: C.red, backgroundColor: C.surface,
      child: CustomScrollView(slivers: [
        // Transparent AppBar over hero
        SliverAppBar(pinned: false, floating: true, backgroundColor: Colors.transparent,
          title: const _Logo(size: 32, showText: true, compact: true),
          actions: [IconButton(icon: const Icon(Icons.notifications_outlined, color: C.text),
              onPressed: () {})],
        ),
        if (_loading) ...[
          SliverToBoxAdapter(child: _heroShimmer()),
          SliverToBoxAdapter(child: _rowShimmer()),
          SliverToBoxAdapter(child: _rowShimmer()),
        ] else if (_err != null)
          SliverFillRemaining(child: _errWidget())
        else ...[
            if (_hero != null)
              SliverToBoxAdapter(child: HeroBanner(item: _hero!, onRefreshHero: () {
                final heroes = _trending.where((m) => m.hasBackdrop).toList();
                if (heroes.isNotEmpty) setState(() =>
                _hero = heroes[Random().nextInt(heroes.length.clamp(1, 5))]);
              })),
            SliverToBoxAdapter(child: _Section('🔥 Trending Movies', _trending, 'movie')),
            SliverToBoxAdapter(child: _Section('📺 Trending TV', _tvTrending, 'tv')),
            SliverToBoxAdapter(child: _Section('⭐ Top Rated', _topRated, 'movie')),
            SliverToBoxAdapter(child: _Section('🎬 Popular Now', _popular, 'movie')),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
      ]),
    ),
  );

  Widget _errWidget() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.wifi_off_rounded, size: 64, color: C.textDim),
    const SizedBox(height: 14),
    Text(_err!, style: T.small),
    const SizedBox(height: 20),
    TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(color: C.red))),
  ]));

  Widget _heroShimmer() => Shimmer.fromColors(baseColor: C.sBase, highlightColor: C.sHigh,
      child: Container(height: 520, color: C.sBase));

  Widget _rowShimmer() => Padding(padding: const EdgeInsets.only(top: 28),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Shimmer.fromColors(baseColor: C.sBase, highlightColor: C.sHigh,
          child: Container(height: 18, width: 160, margin: const EdgeInsets.only(left: 20, bottom: 14),
              color: C.sBase)),
      SizedBox(height: 200, child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 5, separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Shimmer.fromColors(baseColor: C.sBase, highlightColor: C.sHigh,
            child: Container(width: 130, decoration: BoxDecoration(color: C.sBase,
                borderRadius: BorderRadius.circular(12)))),
      )),
    ]),
  );
}

// ═══════════════════════════════════════════════════════
//  HERO BANNER
// ═══════════════════════════════════════════════════════

class HeroBanner extends StatelessWidget {
  final TmdbItem item;
  final VoidCallback? onRefreshHero;
  const HeroBanner({super.key, required this.item, this.onRefreshHero});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return GestureDetector(
      onTap: () => _pushDetail(context, item),
      child: SizedBox(height: 520, child: Stack(fit: StackFit.expand, children: [
        // Backdrop
        item.hasBackdrop
            ? CachedNetworkImage(imageUrl: item.backdropUrl, fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: C.card),
            errorWidget: (_, __, ___) => Container(color: C.card))
            : Container(color: C.card),
        // Gradient
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black26, Colors.transparent, Colors.black87, C.bg],
          stops: [0, 0.3, 0.7, 1],
        ))),
        // Content
        Positioned(left: 20, right: 20, bottom: 24, child:
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          // Badge
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(6)),
            child: Text(item.type == 'tv' ? '📺 TRENDING TV' : '🎬 TRENDING',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 1.5)),
          ),
          const SizedBox(height: 10),
          Text(item.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
              color: Colors.white, shadows: [Shadow(blurRadius: 8, color: Colors.black54)]),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          if (item.voteAverage > 0) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.star_rounded, size: 14, color: C.gold),
              const SizedBox(width: 4),
              Text(item.ratingStr, style: const TextStyle(color: C.gold,
                  fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(width: 10),
              Text(item.year, style: T.small),
            ]),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: () => _pushDetail(context, item),
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: const Text('More Info'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
            )),
            const SizedBox(width: 10),
            // Watchlist
            _circleBtn(
              icon: appState.isWatchlisted(item.id)
                  ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              color: appState.isWatchlisted(item.id) ? C.red : Colors.white,
              onTap: () => context.read<AppState>().toggleWatchlist(item),
            ),
            const SizedBox(width: 8),
            // Refresh hero
            if (onRefreshHero != null)
              _circleBtn(icon: Icons.shuffle_rounded, color: Colors.white,
                  onTap: onRefreshHero!),
          ]),
        ]),
        ),
      ])),
    );
  }

  Widget _circleBtn({required IconData icon, required Color color, required VoidCallback onTap}) =>
      GestureDetector(onTap: onTap, child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: Colors.white12, shape: BoxShape.circle,
            border: Border.all(color: Colors.white24)),
        child: Icon(icon, color: color, size: 20),
      ));
}

// ═══════════════════════════════════════════════════════
//  SECTION WIDGET (horizontal scroll row)
// ═══════════════════════════════════════════════════════

class _Section extends StatelessWidget {
  final String title;
  final List<TmdbItem> items;
  final String type;
  const _Section(this.title, this.items, this.type);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 28), child:
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child:
      Row(children: [
        Expanded(child: Text(title, style: T.h2)),
        TextButton(
          onPressed: () => Navigator.push(context, _slide(
              SeeAllScreen(title: title, items: items, type: type))),
          child: const Text('See All', style: TextStyle(color: C.red, fontSize: 13)),
        ),
      ]),
      ),
      const SizedBox(height: 12),
      SizedBox(height: 210, child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) => GestureDetector(
          onTap: () => _pushDetail(ctx, items[i]),
          child: PosterCard(item: items[i]),
        ),
      )),
    ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  MOVIES SCREEN  (infinite scroll + filters)
// ═══════════════════════════════════════════════════════

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});
  @override State<MoviesScreen> createState() => _MoviesState();
}

class _MoviesState extends State<MoviesScreen> {
  final _scroll = ScrollController();
  List<TmdbItem> _items = [];
  List<Genre> _genres = [];
  bool _loading = false, _loadingMore = false, _init = false;
  int _page = 1;
  int? _selGenre;
  String _selCountry = '';
  String _selSort = 'popularity.desc';
  int? _selYear;
  String? _err;

  static const _sorts = {
    'popularity.desc': 'Most Popular',
    'vote_average.desc': 'Highest Rated',
    'primary_release_date.desc': 'Newest',
    'revenue.desc': 'Box Office',
  };
  static const _countries = {
    '': 'All Countries', 'US': '🇺🇸 USA', 'GB': '🇬🇧 UK',
    'FR': '🇫🇷 France', 'DE': '🇩🇪 Germany', 'JP': '🇯🇵 Japan',
    'KR': '🇰🇷 Korea', 'IN': '🇮🇳 India', 'IT': '🇮🇹 Italy',
  };

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadGenres();
    _fetch(reset: true);
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  Future<void> _loadGenres() async {
    final g = await context.read<TmdbService>().movieGenres();
    if (mounted) setState(() => _genres = g);
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300 && !_loadingMore) {
      _fetch();
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loading || _loadingMore) return;
    if (reset) { setState(() { _loading = true; _page = 1; _err = null; }); }
    else setState(() => _loadingMore = true);
    try {
      final items = await context.read<TmdbService>().discoverMovies(
        page: _page, genreId: _selGenre,
        country: _selCountry.isEmpty ? null : _selCountry,
        sortBy: _selSort, year: _selYear,
      );
      if (mounted) setState(() {
        if (reset) _items = items; else _items.addAll(items);
        _page++; _init = true;
      });
    } catch (_) { if (mounted) setState(() => _err = 'Failed to load.'); }
    if (mounted) setState(() { _loading = false; _loadingMore = false; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    body: SafeArea(child: Column(children: [
      _header(),
      _filterBar(),
      Expanded(child: _loading
          ? _gridShimmer()
          : _err != null
          ? _errWidget()
          : _grid()),
    ])),
  );

  Widget _header() => Padding(padding: const EdgeInsets.fromLTRB(20, 16, 16, 8), child:
  Row(children: [
    const Text('Movies', style: T.h1),
    const Spacer(),
    IconButton(icon: const Icon(Icons.tune_rounded, color: C.textDim),
        onPressed: _showFilters),
  ]),
  );

  Widget _filterBar() => SizedBox(height: 44, child: ListView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    children: [
      // Sort
      _fChip(_sorts[_selSort] ?? 'Sort', Icons.sort_rounded, () => _showSortPicker()),
      const SizedBox(width: 8),
      // Genres
      ..._genres.take(8).map((g) => Padding(padding: const EdgeInsets.only(right: 8),
          child: _toggleChip(g.name, _selGenre == g.id, () {
            setState(() => _selGenre = _selGenre == g.id ? null : g.id);
            _fetch(reset: true);
          }))),
    ],
  ));

  Widget _fChip(String label, IconData icon, VoidCallback onTap) =>
      GestureDetector(onTap: onTap, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: C.divider)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: C.textDim),
          const SizedBox(width: 6),
          Text(label, style: T.small),
        ]),
      ));

  Widget _toggleChip(String label, bool on, VoidCallback onTap) =>
      GestureDetector(onTap: onTap, child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? C.red : C.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? C.red : C.divider),
        ),
        child: Text(label, style: TextStyle(fontSize: 12,
            color: on ? Colors.white : C.textDim,
            fontWeight: on ? FontWeight.w700 : FontWeight.normal)),
      ));

  Widget _grid() => GridView.builder(
    controller: _scroll,
    padding: const EdgeInsets.all(16),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, childAspectRatio: 0.62,
        crossAxisSpacing: 10, mainAxisSpacing: 10),
    itemCount: _items.length + (_loadingMore ? 3 : 0),
    itemBuilder: (ctx, i) {
      if (i >= _items.length) return Shimmer.fromColors(baseColor: C.sBase,
          highlightColor: C.sHigh, child: Container(decoration: BoxDecoration(
              color: C.sBase, borderRadius: BorderRadius.circular(10))));
      return GestureDetector(
        onTap: () => _pushDetail(ctx, _items[i]),
        child: SmallCard(item: _items[i]),
      );
    },
  );

  Widget _gridShimmer() => GridView.builder(
    padding: const EdgeInsets.all(16),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, childAspectRatio: 0.62,
        crossAxisSpacing: 10, mainAxisSpacing: 10),
    itemCount: 9,
    itemBuilder: (_, __) => Shimmer.fromColors(baseColor: C.sBase, highlightColor: C.sHigh,
        child: Container(decoration: BoxDecoration(color: C.sBase,
            borderRadius: BorderRadius.circular(10)))),
  );

  Widget _errWidget() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline_rounded, size: 56, color: C.textDim),
    const SizedBox(height: 12),
    Text(_err!, style: T.small),
    const SizedBox(height: 16),
    TextButton(onPressed: () => _fetch(reset: true),
        child: const Text('Retry', style: TextStyle(color: C.red))),
  ]));

  void _showFilters() => showModalBottomSheet(
    context: context, backgroundColor: C.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _FilterSheet(
      genres: _genres, selGenre: _selGenre, selCountry: _selCountry,
      selSort: _selSort, countries: _countries, sorts: _sorts,
      onApply: (g, c, s) {
        setState(() { _selGenre = g; _selCountry = c; _selSort = s; });
        _fetch(reset: true);
      },
    ),
  );

  void _showSortPicker() => showModalBottomSheet(
    context: context, backgroundColor: C.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => Padding(padding: const EdgeInsets.all(20), child:
    Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sort By', style: T.h2),
          const SizedBox(height: 16),
          ..._sorts.entries.map((e) => ListTile(
            title: Text(e.value, style: const TextStyle(color: C.text)),
            trailing: _selSort == e.key
                ? const Icon(Icons.check_rounded, color: C.red) : null,
            onTap: () {
              setState(() => _selSort = e.key);
              Navigator.pop(context);
              _fetch(reset: true);
            },
          )),
        ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════
//  TV SCREEN  (infinite scroll + filters)
// ═══════════════════════════════════════════════════════

class TvScreen extends StatefulWidget {
  const TvScreen({super.key});
  @override State<TvScreen> createState() => _TvState();
}

class _TvState extends State<TvScreen> {
  final _scroll = ScrollController();
  List<TmdbItem> _items = [];
  List<Genre> _genres = [];
  bool _loading = false, _loadingMore = false;
  int _page = 1;
  int? _selGenre;
  String _selCountry = '';
  String _selSort = 'popularity.desc';
  String? _err;

  static const _sorts = {
    'popularity.desc': 'Most Popular',
    'vote_average.desc': 'Highest Rated',
    'first_air_date.desc': 'Newest',
  };
  static const _countries = {
    '': 'All Countries', 'US': '🇺🇸 USA', 'GB': '🇬🇧 UK',
    'FR': '🇫🇷 France', 'JP': '🇯🇵 Japan', 'KR': '🇰🇷 Korea',
    'IN': '🇮🇳 India', 'TR': '🇹🇷 Turkey',
  };

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadGenres();
    _fetch(reset: true);
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  Future<void> _loadGenres() async {
    final g = await context.read<TmdbService>().tvGenres();
    if (mounted) setState(() => _genres = g);
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300 && !_loadingMore) {
      _fetch();
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loading || _loadingMore) return;
    if (reset) setState(() { _loading = true; _page = 1; _err = null; });
    else setState(() => _loadingMore = true);
    try {
      final items = await context.read<TmdbService>().discoverTv(
        page: _page, genreId: _selGenre,
        country: _selCountry.isEmpty ? null : _selCountry,
        sortBy: _selSort,
      );
      if (mounted) setState(() {
        if (reset) _items = items; else _items.addAll(items);
        _page++;
      });
    } catch (_) { if (mounted) setState(() => _err = 'Failed to load.'); }
    if (mounted) setState(() { _loading = false; _loadingMore = false; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 16, 8), child:
      Row(children: [
        const Text('TV Shows', style: T.h1),
        const Spacer(),
        IconButton(icon: const Icon(Icons.tune_rounded, color: C.textDim),
            onPressed: _showFilters),
      ]),
      ),
      SizedBox(height: 44, child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _fChip(_sorts[_selSort] ?? 'Sort', () => _showSortPicker()),
          const SizedBox(width: 8),
          ..._genres.take(8).map((g) => Padding(padding: const EdgeInsets.only(right: 8),
              child: _toggleChip(g.name, _selGenre == g.id, () {
                setState(() => _selGenre = _selGenre == g.id ? null : g.id);
                _fetch(reset: true);
              }))),
        ],
      )),
      Expanded(child: _loading
          ? _shimmer()
          : _err != null
          ? Center(child: Text(_err!, style: T.small))
          : _grid()),
    ])),
  );

  Widget _fChip(String label, VoidCallback onTap) => GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.divider)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.sort_rounded, size: 14, color: C.textDim),
        const SizedBox(width: 6),
        Text(label, style: T.small),
      ]),
    ),
  );

  Widget _toggleChip(String label, bool on, VoidCallback onTap) => GestureDetector(
    onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 180),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: on ? C.red : C.card, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: on ? C.red : C.divider),
    ),
    child: Text(label, style: TextStyle(fontSize: 12,
        color: on ? Colors.white : C.textDim,
        fontWeight: on ? FontWeight.w700 : FontWeight.normal)),
  ),
  );

  Widget _grid() => GridView.builder(
    controller: _scroll, padding: const EdgeInsets.all(16),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, childAspectRatio: 0.62,
        crossAxisSpacing: 10, mainAxisSpacing: 10),
    itemCount: _items.length + (_loadingMore ? 3 : 0),
    itemBuilder: (ctx, i) {
      if (i >= _items.length) return Shimmer.fromColors(baseColor: C.sBase,
          highlightColor: C.sHigh, child: Container(decoration: BoxDecoration(
              color: C.sBase, borderRadius: BorderRadius.circular(10))));
      return GestureDetector(
        onTap: () => _pushDetail(ctx, _items[i]),
        child: SmallCard(item: _items[i]),
      );
    },
  );

  Widget _shimmer() => GridView.builder(
    padding: const EdgeInsets.all(16),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, childAspectRatio: 0.62,
        crossAxisSpacing: 10, mainAxisSpacing: 10),
    itemCount: 9,
    itemBuilder: (_, __) => Shimmer.fromColors(baseColor: C.sBase, highlightColor: C.sHigh,
        child: Container(decoration: BoxDecoration(color: C.sBase,
            borderRadius: BorderRadius.circular(10)))),
  );

  void _showFilters() => showModalBottomSheet(
    context: context, backgroundColor: C.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _FilterSheet(
      genres: _genres, selGenre: _selGenre, selCountry: _selCountry,
      selSort: _selSort, countries: _countries, sorts: _sorts,
      onApply: (g, c, s) {
        setState(() { _selGenre = g; _selCountry = c; _selSort = s; });
        _fetch(reset: true);
      },
    ),
  );

  void _showSortPicker() => showModalBottomSheet(
    context: context, backgroundColor: C.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => Padding(padding: const EdgeInsets.all(20), child:
    Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sort By', style: T.h2),
          const SizedBox(height: 16),
          ..._sorts.entries.map((e) => ListTile(
            title: Text(e.value, style: const TextStyle(color: C.text)),
            trailing: _selSort == e.key
                ? const Icon(Icons.check_rounded, color: C.red) : null,
            onTap: () {
              setState(() => _selSort = e.key);
              Navigator.pop(context);
              _fetch(reset: true);
            },
          )),
        ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════
//  FILTER BOTTOM SHEET
// ═══════════════════════════════════════════════════════

class _FilterSheet extends StatefulWidget {
  final List<Genre> genres;
  final int? selGenre;
  final String selCountry, selSort;
  final Map<String, String> countries, sorts;
  final void Function(int?, String, String) onApply;

  const _FilterSheet({required this.genres, required this.selGenre,
    required this.selCountry, required this.selSort,
    required this.countries, required this.sorts, required this.onApply});

  @override State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late int? _genre;
  late String _country, _sort;

  @override
  void initState() {
    super.initState();
    _genre = widget.selGenre; _country = widget.selCountry; _sort = widget.selSort;
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false, initialChildSize: 0.75, maxChildSize: 0.9,
    builder: (_, ctrl) => Container(
      decoration: const BoxDecoration(color: C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(color: C.divider, borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child:
        Row(children: [
          const Text('Filters', style: T.h2),
          const Spacer(),
          TextButton(onPressed: () => setState(() {
            _genre = null; _country = ''; _sort = 'popularity.desc';
          }), child: const Text('Reset', style: TextStyle(color: C.red))),
        ]),
        ),
        Expanded(child: ListView(controller: ctrl, padding: const EdgeInsets.all(20),
          children: [
            _label('SORT BY'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: widget.sorts.entries.map((e) =>
                _chip(e.value, _sort == e.key, () => setState(() => _sort = e.key))
            ).toList()),
            const SizedBox(height: 24),
            _label('GENRE'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: widget.genres.map((g) =>
                _chip(g.name, _genre == g.id, () => setState(() =>
                _genre = _genre == g.id ? null : g.id))
            ).toList()),
            const SizedBox(height: 24),
            _label('COUNTRY'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: widget.countries.entries.map((e) =>
                _chip(e.value, _country == e.key, () => setState(() => _country = e.key))
            ).toList()),
          ],
        )),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), child:
        ElevatedButton(
          onPressed: () { Navigator.pop(context); widget.onApply(_genre, _country, _sort); },
          child: const Text('Apply Filters'),
        ),
        ),
      ]),
    ),
  );

  Widget _label(String t) => Text(t, style: T.label);

  Widget _chip(String label, bool on, VoidCallback onTap) => GestureDetector(
    onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 150),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: on ? C.red : C.card, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: on ? C.red : C.divider),
    ),
    child: Text(label, style: TextStyle(fontSize: 12,
        color: on ? Colors.white : C.textDim,
        fontWeight: on ? FontWeight.w700 : FontWeight.normal)),
  ),
  );
}

// ═══════════════════════════════════════════════════════
//  SEE ALL SCREEN
// ═══════════════════════════════════════════════════════

class SeeAllScreen extends StatefulWidget {
  final String title;
  final List<TmdbItem> items;
  final String type;
  const SeeAllScreen({super.key, required this.title, required this.items, required this.type});
  @override State<SeeAllScreen> createState() => _SeeAllState();
}

class _SeeAllState extends State<SeeAllScreen> {
  final _scroll = ScrollController();
  late List<TmdbItem> _items;
  bool _loadingMore = false;
  int _page = 2;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300 && !_loadingMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final tmdb = context.read<TmdbService>();
      List<TmdbItem> more = [];
      if (widget.title.contains('Trending') && widget.type == 'movie') {
        more = await tmdb.trendingMovies(page: _page);
      } else if (widget.title.contains('Trending') && widget.type == 'tv') {
        more = await tmdb.trendingTv(page: _page);
      } else if (widget.title.contains('Top Rated')) {
        more = await tmdb.topRatedMovies(page: _page);
      } else if (widget.title.contains('Popular')) {
        more = await tmdb.popularMovies(page: _page);
      } else if (widget.title.contains('TV')) {
        more = await tmdb.popularTv(page: _page);
      }
      setState(() { _items.addAll(more); _page++; });
    } catch (_) {}
    if (mounted) setState(() => _loadingMore = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(title: Text(widget.title)),
    body: GridView.builder(
      controller: _scroll, padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 0.62,
          crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemCount: _items.length + (_loadingMore ? 3 : 0),
      itemBuilder: (ctx, i) {
        if (i >= _items.length) return Shimmer.fromColors(baseColor: C.sBase,
            highlightColor: C.sHigh, child: Container(decoration: BoxDecoration(
                color: C.sBase, borderRadius: BorderRadius.circular(10))));
        return GestureDetector(
          onTap: () => _pushDetail(ctx, _items[i]),
          child: SmallCard(item: _items[i]),
        );
      },
    ),
  );
}

// ═══════════════════════════════════════════════════════
//  SEARCH SCREEN
// ═══════════════════════════════════════════════════════

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override State<SearchScreen> createState() => _SearchState();
}

class _SearchState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<TmdbItem> _results = [];
  bool _loading = false, _searched = false;
  String _tab = 'all'; // 'all' | 'movie' | 'tv'

  @override
  void dispose() { _ctrl.dispose(); _debounce?.cancel(); super.dispose(); }

  void _search(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _results = []; _searched = false; }); return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() { _loading = true; _searched = true; });
      try {
        final tmdb = context.read<TmdbService>();
        List<TmdbItem> res;
        if (_tab == 'movie') res = await tmdb.searchMovies(q.trim());
        else if (_tab == 'tv') res = await tmdb.searchTv(q.trim());
        else res = await tmdb.searchMulti(q.trim());
        setState(() => _results = res);
      } catch (_) {}
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 10), child:
      TextField(
        controller: _ctrl, onChanged: _search,
        style: const TextStyle(color: C.text),
        decoration: InputDecoration(
          hintText: 'Search movies & TV shows...',
          prefixIcon: const Icon(Icons.search, color: C.textDim),
          suffixIcon: _ctrl.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear, color: C.textDim),
              onPressed: () { _ctrl.clear(); _search(''); })
              : null,
        ),
      ),
      ),
      // Tabs
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child:
      Row(children: [
        _tabBtn('All', 'all'), const SizedBox(width: 8),
        _tabBtn('Movies', 'movie'), const SizedBox(width: 8),
        _tabBtn('TV Shows', 'tv'),
      ]),
      ),
      const SizedBox(height: 10),
      Expanded(child: _loading
          ? _shimmer()
          : !_searched ? _emptyState()
          : _results.isEmpty ? _noResults()
          : _grid()),
    ])),
  );

  Widget _tabBtn(String label, String val) => GestureDetector(
    onTap: () { setState(() => _tab = val); if (_ctrl.text.isNotEmpty) _search(_ctrl.text); },
    child: AnimatedContainer(duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: _tab == val ? C.red : C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _tab == val ? C.red : C.divider),
      ),
      child: Text(label, style: TextStyle(fontSize: 13,
          color: _tab == val ? Colors.white : C.textDim,
          fontWeight: _tab == val ? FontWeight.w700 : FontWeight.normal)),
    ),
  );

  Widget _emptyState() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.search_rounded, size: 80, color: C.textDim.withOpacity(0.3)),
    const SizedBox(height: 16),
    const Text('Search for movies & TV shows', style: T.small, textAlign: TextAlign.center),
  ]));

  Widget _noResults() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.search_off_rounded, size: 64, color: C.textDim),
    const SizedBox(height: 12),
    Text('No results for "${_ctrl.text}"', style: T.small),
  ]));

  Widget _grid() => GridView.builder(
    padding: const EdgeInsets.all(16),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, childAspectRatio: 0.62,
        crossAxisSpacing: 10, mainAxisSpacing: 10),
    itemCount: _results.length,
    itemBuilder: (ctx, i) => GestureDetector(
      onTap: () => _pushDetail(ctx, _results[i]),
      child: SmallCard(item: _results[i]),
    ),
  );

  Widget _shimmer() => GridView.builder(
    padding: const EdgeInsets.all(16),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, childAspectRatio: 0.62,
        crossAxisSpacing: 10, mainAxisSpacing: 10),
    itemCount: 9,
    itemBuilder: (_, __) => Shimmer.fromColors(baseColor: C.sBase, highlightColor: C.sHigh,
        child: Container(decoration: BoxDecoration(color: C.sBase,
            borderRadius: BorderRadius.circular(10)))),
  );
}

// ═══════════════════════════════════════════════════════
//  DETAIL SCREEN
// ═══════════════════════════════════════════════════════

class DetailScreen extends StatefulWidget {
  final TmdbItem item;
  const DetailScreen({super.key, required this.item});
  @override State<DetailScreen> createState() => _DetailState();
}

class _DetailState extends State<DetailScreen> {
  TmdbItem? _detail;
  bool _loading = true;
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tmdb = context.read<TmdbService>();
      final d = widget.item.type == 'tv'
          ? await tmdb.tvDetail(widget.item.id)
          : await tmdb.movieDetail(widget.item.id);
      if (mounted) setState(() { _detail = d; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openTrailer() {
    final item = _detail ?? widget.item;
    final key = item.trailerKey;
    if (key == null || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No trailer available for this title'),
        backgroundColor: C.card,
      ));
      return;
    }
    Navigator.push(context, _slide(TrailerScreen(
      title: item.title,
      youtubeKey: key,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final item = _detail ?? widget.item;
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: C.bg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 440,
          pinned: true,
          backgroundColor: C.bg,
          leading: IconButton(
            icon: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black54,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20)),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              (item.hasBackdrop || item.hasPoster)
                  ? CachedNetworkImage(
                  imageUrl: item.hasBackdrop ? item.backdropUrl : item.posterUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: C.card),
                  errorWidget: (_, __, ___) => Container(color: C.card))
                  : Container(color: C.card),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.transparent, Colors.black54, C.bg],
                stops: [0, 0.4, 0.75, 1],
              ))),
              // Play button overlay
              Center(child: GestureDetector(
                onTap: _openTrailer,
                child: Container(width: 72, height: 72,
                    decoration: BoxDecoration(color: C.red, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: C.red.withOpacity(0.4),
                            blurRadius: 24, spreadRadius: 4)]),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 42)),
              )),
              // Type badge
              Positioned(top: 16, right: 16,
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black54,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(item.type == 'tv' ? '📺 TV' : '🎬 MOVIE',
                          style: const TextStyle(color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.w700)))),
            ]),
          ),
        ),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _loading ? _detailShimmer() : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(item.title, style: T.h1),
              if (item.tagline != null && item.tagline!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(item.tagline!, style: T.small.copyWith(
                    fontStyle: FontStyle.italic, color: C.textDim)),
              ],
              const SizedBox(height: 12),
              // Meta chips
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (item.year.isNotEmpty) _chip(item.year),
                if (item.voteAverage > 0)
                  _chip('⭐ ${item.ratingStr}', color: C.gold),
                if (item.runtime != null && item.runtime! > 0)
                  _chip('${item.runtime}m'),
                if (item.status != null) _chip(item.status!),
                if (item.originCountry != null) _chip(item.originCountry!),
              ]),
              if (item.genres.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: item.genres
                    .map((g) => _genreChip(g)).toList()),
              ],
              const SizedBox(height: 20),
              // Action buttons
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                  onPressed: _openTrailer,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Watch Trailer'),
                )),
                const SizedBox(width: 12),
                _iconBtn(
                  icon: appState.isWatchlisted(item.id)
                      ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                  color: appState.isWatchlisted(item.id) ? C.red : null,
                  onTap: () => context.read<AppState>().toggleWatchlist(item),
                ),
                const SizedBox(width: 8),
                _iconBtn(
                  icon: _liked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                  color: _liked ? Colors.pinkAccent : null,
                  onTap: () => setState(() => _liked = !_liked),
                ),
              ]),
              const SizedBox(height: 28),
              if (item.overview.isNotEmpty) ...[
                const Text('Overview', style: T.h3),
                const SizedBox(height: 10),
                Text(item.overview, style: T.body),
                const SizedBox(height: 24),
              ],
              if (item.director != null) ...[
                _creditRow('Director', item.director!), const SizedBox(height: 12),
              ],
              if (item.cast.isNotEmpty)
                _creditRow('Cast', item.cast.join(', ')),
              const SizedBox(height: 40),
            ],
          ),
        )),
      ]),
    );
  }

  Widget _detailShimmer() => Shimmer.fromColors(baseColor: C.sBase, highlightColor: C.sHigh,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Container(height: 26, width: 220, color: C.sBase),
      const SizedBox(height: 12),
      Container(height: 14, width: 160, color: C.sBase),
      const SizedBox(height: 20),
      Container(height: 52, decoration: BoxDecoration(color: C.sBase,
          borderRadius: BorderRadius.circular(12))),
      const SizedBox(height: 20),
      Container(height: 14, color: C.sBase),
      const SizedBox(height: 8),
      Container(height: 14, color: C.sBase),
      const SizedBox(height: 8),
      Container(height: 14, width: 200, color: C.sBase),
    ]),
  );

  Widget _chip(String t, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(6),
        border: Border.all(color: C.divider)),
    child: Text(t, style: TextStyle(fontSize: 12,
        color: color ?? C.textDim, fontWeight: FontWeight.w500)),
  );

  Widget _genreChip(String g) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: C.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.red.withOpacity(0.3))),
    child: Text(g, style: const TextStyle(fontSize: 11, color: C.red, fontWeight: FontWeight.w600)),
  );

  Widget _creditRow(String label, String val) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 70, child: Text(label, style: T.small.copyWith(fontWeight: FontWeight.w600))),
      Expanded(child: Text(val, style: T.body.copyWith(fontSize: 13))),
    ],
  );

  Widget _iconBtn({required IconData icon, Color? color, required VoidCallback onTap}) =>
      GestureDetector(onTap: onTap, child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.divider)),
        child: Icon(icon, color: color ?? C.text, size: 22),
      ));
}

// ═══════════════════════════════════════════════════════
//  TRAILER SCREEN  (in-app WebView)
// ═══════════════════════════════════════════════════════

class TrailerScreen extends StatefulWidget {
  final String title, youtubeKey;
  const TrailerScreen({super.key, required this.title, required this.youtubeKey});
  @override State<TrailerScreen> createState() => _TrailerState();
}

class _TrailerState extends State<TrailerScreen> {
  late final WebViewController _wv;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final url = 'https://www.youtube.com/watch?v=${widget.youtubeKey}';
    _wv = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) { if (mounted) setState(() => _loading = false); }))
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(backgroundColor: Colors.black,
      leading: IconButton(icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      title: Text(widget.title, style: const TextStyle(color: Colors.white,
          fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
    ),
    body: Stack(children: [
      WebViewWidget(controller: _wv),
      if (_loading) Container(color: Colors.black,
          child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: C.red),
            SizedBox(height: 16),
            Text('Loading trailer...', style: T.small),
          ]))),
    ]),
  );
}

// ═══════════════════════════════════════════════════════
//  PROFILE SCREEN
// ═══════════════════════════════════════════════════════

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppState>().prefs;
    return Scaffold(
      backgroundColor: C.bg,
      body: CustomScrollView(slivers: [
        const SliverAppBar(floating: true, backgroundColor: C.bg,
            title: Text('Profile', style: T.h1)),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Avatar
            Center(child: Column(children: [
              Container(width: 90, height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [C.red, Color(0xFF6B0000)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: C.red.withOpacity(0.3), blurRadius: 24, spreadRadius: 4)],
                ),
                child: Center(child: Text(
                  prefs.userName.isNotEmpty ? prefs.userName[0].toUpperCase() : 'G',
                  style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white),
                )),
              ),
              const SizedBox(height: 14),
              Text(prefs.userName, style: T.h2),
              const SizedBox(height: 4),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Guest Mode', style: TextStyle(color: C.textDim, fontSize: 12))),
            ])),
            const SizedBox(height: 32),

            // Watchlist card — clickable → opens list
            _sLabel('WATCHLIST'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.push(context, _slide(const WatchlistScreen())),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: C.divider)),
                child: Row(children: [
                  Container(width: 44, height: 44,
                    decoration: BoxDecoration(color: C.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.bookmark_rounded, color: C.red, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${prefs.watchlist.length} Saved',
                        style: const TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 15)),
                    const Text('Tap to view your list', style: T.small),
                  ]),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: C.textDim),
                ]),
              ),
            ),

            if (prefs.likedGenreIds.isNotEmpty) ...[
              const SizedBox(height: 28),
              _sLabel('MY GENRES'),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: prefs.likedGenreIds
                  .map((id) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: C.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: C.red.withOpacity(0.3))),
                child: Text('Genre $id', style: const TextStyle(color: C.red,
                    fontWeight: FontWeight.w600, fontSize: 13)),
              )).toList()),
            ],

            const SizedBox(height: 28),
            _sLabel('SETTINGS'),
            const SizedBox(height: 10),
            _tile(context, Icons.tune_rounded, 'Update Preferences',
                onTap: () => Navigator.push(context,
                    _slide(const OnboardingScreen()))),
            _tile(context, Icons.help_outline_rounded, 'Help & Support'),
            _tile(context, Icons.privacy_tip_outlined, 'Privacy Policy'),
            const SizedBox(height: 28),

            OutlinedButton(
              onPressed: () async {
                await context.read<AppState>().logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                    _fade_(const LoginScreen()), (_) => false);
              },
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: C.red), foregroundColor: C.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Sign Out', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
            const Center(child: Text('CineScope v2.0 — Powered by TMDB',
                style: T.small)),
            const SizedBox(height: 24),
          ]),
        )),
      ]),
    );
  }

  Widget _sLabel(String t) => Text(t, style: T.label);

  Widget _tile(BuildContext ctx, IconData icon, String title, {VoidCallback? onTap}) =>
      ListTile(contentPadding: EdgeInsets.zero,
        leading: Container(width: 38, height: 38,
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: C.textDim, size: 20)),
        title: Text(title, style: const TextStyle(color: C.text, fontSize: 14)),
        trailing: const Icon(Icons.chevron_right, color: C.textDim, size: 20),
        onTap: onTap ?? () {},
      );
}

// ═══════════════════════════════════════════════════════
//  WATCHLIST SCREEN
// ═══════════════════════════════════════════════════════

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<AppState>().prefs.watchlistItems;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: Text('Watchlist (${items.length})', style: T.h1)),
      body: items.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bookmark_outline_rounded, size: 80,
            color: C.textDim.withOpacity(0.4)),
        const SizedBox(height: 16),
        const Text('Your watchlist is empty', style: T.small),
        const SizedBox(height: 8),
        const Text('Tap the bookmark icon on any title to save it.',
            style: T.small, textAlign: TextAlign.center),
      ]))
          : GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, childAspectRatio: 0.62,
            crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemCount: items.length,
        itemBuilder: (ctx, i) => GestureDetector(
          onTap: () => _pushDetail(ctx, items[i]),
          child: SmallCard(item: items[i]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════════════════

/// App logo widget — consistent everywhere
class _Logo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool compact;
  const _Logo({this.size = 48, this.showText = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: C.red,
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [BoxShadow(color: C.red.withOpacity(0.45),
            blurRadius: size * 0.5, spreadRadius: size * 0.03)],
      ),
      child: Stack(alignment: Alignment.center, children: [
        // Film strip dots — top
        Positioned(top: size * 0.09, child: Row(children: List.generate(3, (i) =>
            Container(width: size*0.08, height: size*0.07, margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2)))))),
        // Play arrow
        Icon(Icons.play_arrow_rounded, color: Colors.white, size: size * 0.55),
        // Film strip dots — bottom
        Positioned(bottom: size * 0.09, child: Row(children: List.generate(3, (i) =>
            Container(width: size*0.08, height: size*0.07, margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2)))))),
      ]),
    );

    if (!showText) return icon;

    return Row(mainAxisSize: MainAxisSize.min, children: [
      icon,
      const SizedBox(width: 10),
      if (!compact)
        const Text('CINESCOPE', style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.w800, color: C.text, letterSpacing: 3))
      else
        const Text('CINESCOPE', style: TextStyle(fontSize: 15,
            fontWeight: FontWeight.w800, color: C.text, letterSpacing: 2.5)),
    ]);
  }
}

/// Standard poster card (horizontal lists)
class PosterCard extends StatelessWidget {
  final TmdbItem item;
  const PosterCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) => SizedBox(width: 130,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(12),
        child: Stack(fit: StackFit.expand, children: [
          item.hasPoster
              ? CachedNetworkImage(imageUrl: item.posterUrl, fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: C.card),
              errorWidget: (_, __, ___) => _ph())
              : _ph(),
          // Rating badge
          Positioned(top: 6, right: 6, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star_rounded, size: 10, color: C.gold),
              const SizedBox(width: 3),
              Text(item.ratingStr, style: const TextStyle(fontSize: 10,
                  color: Colors.white, fontWeight: FontWeight.w600)),
            ]),
          )),
          // Type badge
          Positioned(bottom: 6, left: 6, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: item.type == 'tv'
                ? Colors.blue.withOpacity(0.85) : C.red.withOpacity(0.85),
                borderRadius: BorderRadius.circular(4)),
            child: Text(item.type == 'tv' ? 'TV' : 'Film',
                style: const TextStyle(color: Colors.white, fontSize: 9,
                    fontWeight: FontWeight.w700)),
          )),
        ]),
      )),
      const SizedBox(height: 7),
      Text(item.title, style: T.h3.copyWith(fontSize: 12),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      Text(item.year, style: T.small),
    ]),
  );

  Widget _ph() => Container(color: C.card,
      child: const Center(child: Icon(Icons.movie_outlined, color: C.textDim, size: 30)));
}

/// Small card for grids
class SmallCard extends StatelessWidget {
  final TmdbItem item;
  const SmallCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Stack(fit: StackFit.expand, children: [
      item.hasPoster
          ? CachedNetworkImage(imageUrl: item.posterUrl, fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: C.card),
          errorWidget: (_, __, ___) => Container(color: C.card,
              child: const Icon(Icons.movie_outlined, color: C.textDim)))
          : Container(color: C.card,
          child: const Icon(Icons.movie_outlined, color: C.textDim)),
      // Gradient + title
      Positioned(left: 0, right: 0, bottom: 0,
        child: Container(padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black87])),
          child: Text(item.title, style: const TextStyle(color: Colors.white,
              fontSize: 10, fontWeight: FontWeight.w600),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
      // Type tag
      Positioned(top: 5, right: 5, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: item.type == 'tv'
              ? Colors.blue.withOpacity(0.85) : Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(item.type == 'tv' ? 'TV' : '🎬',
            style: const TextStyle(fontSize: 9, color: Colors.white)),
      )),
    ]),
  );
}

// ═══════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════

void _pushDetail(BuildContext context, TmdbItem item) =>
    Navigator.push(context, _slide(DetailScreen(item: item)));

PageRouteBuilder _fade_(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
  transitionDuration: const Duration(milliseconds: 500),
);

PageRouteBuilder _slide(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, a, __, c) {
    final tween = Tween(begin: const Offset(1, 0), end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeOutCubic));
    return SlideTransition(position: a.drive(tween), child: c);
  },
  transitionDuration: const Duration(milliseconds: 350),
);