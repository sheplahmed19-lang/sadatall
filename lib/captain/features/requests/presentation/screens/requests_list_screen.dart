import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../data/models/captain_request_model.dart';
import '../providers/requests_provider.dart';

class RequestsListScreen extends ConsumerStatefulWidget {
  const RequestsListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RequestsListScreen> createState() => _RequestsListScreenState();
}

class _RequestsListScreenState extends ConsumerState<RequestsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);

    // Load requests when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentState = ref.read(requestsListProvider);
      if (currentState.requests.isEmpty && !currentState.isLoading) {
        ref.read(requestsListProvider.notifier).loadRequests();
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      final state = ref.read(requestsListProvider);
      if (!state.isLoading && state.hasMore) {
        ref.read(requestsListProvider.notifier).loadRequests();
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلباتي السابقة'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          tabs: const [
            Tab(text: 'في الانتظار'),
            Tab(text: 'مقبولة'),
            Tab(text: 'مرفوضة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestsList('PENDING'),
          _buildRequestsList('APPROVED'),
          _buildRequestsList('REJECTED'),
        ],
      ),
    );
  }

  Widget _buildRequestsList(String status) {
    return Consumer(
      builder: (context, ref, child) {
        final requestsState = ref.watch(requestsListProvider);

        // Filter requests by status
        final filteredRequests = requestsState.requests
            .where((request) => request.status.value == status)
            .toList();

        if (requestsState.error != null && requestsState.requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'حدث خطأ',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    requestsState.error!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: 'إعادة المحاولة',
                    onPressed: () {
                      ref
                          .read(requestsListProvider.notifier)
                          .loadRequests(refresh: true);
                    },
                    type: ButtonType.outlined,
                  ),
                ],
              ),
            ),
          );
        }

        if (filteredRequests.isEmpty && !requestsState.isLoading) {
          return _buildEmptyState(context, status);
        }

        return RefreshIndicator(
          onRefresh: () async {
            await ref
                .read(requestsListProvider.notifier)
                .loadRequests(refresh: true);
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            itemCount:
                filteredRequests.length + (requestsState.isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == filteredRequests.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              return _buildRequestCard(context, filteredRequests[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String status) {
    String message;
    IconData icon;

    switch (status) {
      case 'PENDING':
        message = 'لا توجد طلبات في الانتظار';
        icon = Icons.hourglass_empty;
        break;
      case 'APPROVED':
        message = 'لا توجد طلبات مقبولة';
        icon = Icons.check_circle_outline;
        break;
      case 'REJECTED':
        message = 'لا توجد طلبات مرفوضة';
        icon = Icons.cancel_outlined;
        break;
      default:
        message = 'لا توجد طلبات';
        icon = Icons.inbox;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: AppColors.onSurfaceVariant),
            const SizedBox(height: 24),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: AppColors.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'ستظهر طلباتك هنا عند توفرها',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, CaptainRequestModel request) {
    Color statusColor;
    IconData statusIcon;
    String statusText = _getRequestStatusText(request.status);

    switch (request.status) {
      case RequestStatus.pending:
        statusColor = AppColors.pending;
        statusIcon = Icons.hourglass_empty;
        break;
      case RequestStatus.approved:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
      case RequestStatus.rejected:
        statusColor = AppColors.error;
        statusIcon = Icons.cancel;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'طلب رقم: #${request.id}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              request.description,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'تم الإرسال: ${AppUtils.formatDateTime(request.submittedAt.toLocal())}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (request.reply != null && request.reply!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.admin_panel_settings,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'رد الإدارة:',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      request.reply!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (request.repliedAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'تاريخ الرد: ${AppUtils.formatDateTime(request.repliedAt!.toLocal())}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getRequestStatusText(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return 'في الانتظار';
      case RequestStatus.approved:
        return 'مقبول';
      case RequestStatus.rejected:
        return 'مرفوض';
    }
  }
}
