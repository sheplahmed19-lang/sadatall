import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../screens/vendors/vendor_details_screen.dart';
import '../../services/api_service.dart';
import '../../services/user_vendor_service.dart';

/// Home-screen promo carousel — short marketing cards (title + description
/// + a CTA button) admin-managed via the "البطاقات الترويجية" screen in the
/// admin app, e.g. a Vodafone-style "Free Gigabytes!" banner. Deliberately
/// separate from the Announcements/عروض system (plain image+text list) —
/// this is styled, colored, tappable cards, not a news feed.
class PromoAdCarousel extends StatefulWidget {
  const PromoAdCarousel({super.key});

  @override
  State<PromoAdCarousel> createState() => _PromoAdCarouselState();
}

class _PromoAdCarouselState extends State<PromoAdCarousel> {
  final ApiService _apiService = ApiService();
  final UserVendorService _vendorService = UserVendorService();
  final PageController _pageController = PageController(viewportFraction: 0.9);
  Timer? _autoScrollTimer;

  List<Map<String, dynamic>> _ads = [];
  int _currentPage = 0;
  bool _loading = true;
  bool _openingVendor = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await _apiService.getPromoAds();
    if (!mounted) return;
    if (result.success && result.data != null) {
      final data = result.data['data'] ?? result.data;
      final list = (data['promoAds'] as List? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      setState(() {
        _ads = list;
        _loading = false;
      });
      if (_ads.length > 1) _startAutoScroll();
    } else {
      setState(() => _loading = false);
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % _ads.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  Color _parseHex(String? hex) {
    try {
      return Color(
        int.parse('FF${(hex ?? 'E4001B').replaceFirst('#', '')}', radix: 16),
      );
    } catch (_) {
      return const Color(0xFFE4001B);
    }
  }

  Future<void> _handleTap(Map<String, dynamic> data) async {
    final linkType = data['link_type'] as String? ?? 'none';
    if (linkType == 'vendor') {
      final vendorId = data['vendor_id'] as String?;
      if (vendorId != null && vendorId.isNotEmpty) await _openVendor(vendorId);
      return;
    }
    if (linkType == 'external') {
      final link = data['cta_link'] as String?;
      if (link == null || link.isEmpty) return;
      final uri = Uri.tryParse(link);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _openVendor(String vendorId) async {
    if (_openingVendor) return;
    setState(() => _openingVendor = true);
    final result = await _vendorService.getVendorById(vendorId);
    if (!mounted) return;
    setState(() => _openingVendor = false);
    if (result.success && result.data != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VendorDetailsScreen(vendor: result.data!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Decorative content — stay silent on loading/empty/error.
    if (_loading || _ads.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: _ads.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (context, index) {
                    final data = _ads[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: GestureDetector(
                        onTap: _openingVendor ? null : () => _handleTap(data),
                        child: _PromoAdCard(
                          data: data,
                          color: _parseHex(
                            data['background_color_hex'] as String?,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (_openingVendor)
                  const Positioned.fill(
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_ads.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _ads.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _currentPage ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _currentPage
                        ? _parseHex(
                            _ads[_currentPage]['background_color_hex']
                                as String?,
                          )
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PromoAdCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color color;
  const _PromoAdCard({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final ctaText = data['cta_text'] as String? ?? 'اعرف أكثر';
    final imageUrl = data['image_url'] as String?;
    final linkType = data['link_type'] as String? ?? 'none';
    final hasLink = linkType == 'vendor'
        ? (data['vendor_id'] as String?)?.isNotEmpty == true
        : linkType == 'external'
        ? (data['cta_link'] as String?)?.isNotEmpty == true
        : false;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: color,
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
        child: Stack(
          children: [
            // Decorative faint circles, echoing the reference design's
            // background texture, without needing per-card artwork.
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                      if (hasLink) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            ctaText,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      imageUrl,
                      width: 90,
                      height: 90,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
