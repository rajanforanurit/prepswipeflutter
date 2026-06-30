import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:prepswipe/models/currentaffair.dart';
import 'package:prepswipe/utils/app_theme.dart';
import '../services/api_service.dart';

class CurrentNewsScreen extends StatefulWidget {
  const CurrentNewsScreen({super.key});

  @override
  State<CurrentNewsScreen> createState() => _CurrentNewsScreenState();
}

class _CurrentNewsScreenState extends State<CurrentNewsScreen> {
  final ApiService _api = ApiService();

  List<CurrentAffairModel> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCurrentAffairs();
  }

  Future<void> _loadCurrentAffairs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.getCurrentAffairs(limit: 50);
      final list = List<Map<String, dynamic>>.from(res['data'] ?? []);
      final items = list.map((e) => CurrentAffairModel.fromJson(e)).toList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadCurrentAffairs();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null && _items.isEmpty) {
      return _buildErrorState();
    }

    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _items.length,
        itemBuilder: (context, index) => _buildCard(_items[index]),
      ),
    );
  }

  Widget _buildErrorState() {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.22),
          const Icon(Icons.wifi_off_rounded,
              size: 56, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Could not load current affairs',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Pull down to retry',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          const Icon(Icons.article_outlined,
              size: 56, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'No current affairs available yet',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Pull down to refresh',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(CurrentAffairModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: InkWell(
        onTap: () => _showDetail(item),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.imgUrl != null && item.imgUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    item.imgUrl!,
                    width: 92,
                    height: 92,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 92,
                      height: 92,
                      color: AppColors.surfaceSecondary,
                      child: const Icon(Icons.image_not_supported,
                          size: 32, color: AppColors.textTertiary),
                    ),
                  ),
                )
              else
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.newspaper,
                      size: 32, color: AppColors.textTertiary),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (item.subject.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.subject,
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (item.date.isNotEmpty)
                          Text(
                            item.date,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(CurrentAffairModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: controller,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (item.imgUrl != null && item.imgUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        item.imgUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 180,
                          width: double.infinity,
                          color: AppColors.surfaceSecondary,
                          child: const Icon(Icons.image_not_supported,
                              size: 60, color: AppColors.textTertiary),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (item.subject.isNotEmpty) ...[
                            const Icon(Icons.source,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              item.subject,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          if (item.date.isNotEmpty) ...[
                            const Icon(Icons.access_time,
                                size: 16, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Text(
                              item.date,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Divider(height: 28, color: AppColors.cardBorder),
                      Text(
                        item.overview,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          height: 1.6,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (item.highlights.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Highlights',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...item.highlights.map((h) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      h,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        height: 1.55,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
