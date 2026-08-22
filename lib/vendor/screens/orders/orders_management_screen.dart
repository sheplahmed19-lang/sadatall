import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/orders/order_card.dart';
import '../../widgets/orders/create_order_actions.dart';
import 'order_details_screen.dart';
import 'counter_offer_screen.dart';
import 'create_order_screen.dart';

class OrdersManagementScreen extends StatefulWidget {
  const OrdersManagementScreen({super.key});

  @override
  State<OrdersManagementScreen> createState() => _OrdersManagementScreenState();
}

class _OrdersManagementScreenState extends State<OrdersManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final OrderService _orderService = OrderService();

  // Tab statuses
  final List<String> _tabStatuses = [
    '', // All orders
    OrderStatus.pending,
    OrderStatus.counterOfferAccepted,
    OrderStatus.acceptedByCaptain,
    OrderStatus.delivered,
    OrderStatus.cancelled,
  ];

  final List<String> _tabLabels = [
    'الكل',
    'في الانتظار',
    'عرض مقبول',
    'مقبول من الكابتن',
    'تم التوصيل',
    'ملغي',
  ];

  // Orders data for each tab
  Map<String, List<Order>> _ordersData = {};
  Map<String, bool> _isLoading = {};
  Map<String, String?> _errors = {};
  Map<String, int> _currentPages = {};
  Map<String, bool> _hasMoreData = {};

  // Search and filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _initializeTabData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (!authProvider.isVendorLocked) {
        _loadOrders(''); // Load all orders first
      }
    });

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final status = _tabStatuses[_tabController.index];
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (!authProvider.isVendorLocked) {
          _loadOrders(status);
        }
      }
    });
  }

  void _initializeTabData() {
    for (String status in _tabStatuses) {
      _ordersData[status] = [];
      _isLoading[status] = false;
      _errors[status] = null;
      _currentPages[status] = 1;
      _hasMoreData[status] = true;
    }
  }

  Future<void> _loadOrders(String status, {bool refresh = false}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Check if vendor is locked before making API call
    if (authProvider.isVendorLocked) {
      if (mounted && _errors[status] != 'يرجى الانتظار حتى يتم فتح الحساب') {
        _showVendorLockedDialog();
      }
      return;
    }

    if (_isLoading[status] == true) return;

    if (!mounted) return;
    setState(() {
      _isLoading[status] = true;
      if (refresh) {
        _ordersData[status] = [];
        _currentPages[status] = 1;
        _hasMoreData[status] = true;
      }
    });

    try {
      final response = await _orderService.getVendorOrders(
        page: _currentPages[status]!,
        limit: 10,
        status: status.isEmpty ? null : status,
      );

      if (!mounted) return;
      if (response.success && response.data != null) {
        setState(() {
          if (refresh) {
            _ordersData[status] = response.data!;
          } else {
            _ordersData[status]!.addAll(response.data!);
          }
          _currentPages[status] = _currentPages[status]! + 1;
          _hasMoreData[status] = response.data!.length >= 10;
          _errors[status] = null;
        });
      } else if (response.error != null &&
          response.error!.contains('يرجى الانتظار حتى يتم فتح الحساب')) {
        // Update auth provider to indicate vendor is locked
        authProvider.setVendorLockStatus(true);
        if (mounted) {
          _showVendorLockedDialog();
        }
      } else {
        setState(() {
          _errors[status] = response.error ?? 'فشل في تحميل الطلبات';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errors[status] = 'حدث خطأ: ${e.toString()}';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading[status] = false;
      });
    }
  }

  void _showVendorLockedDialog() {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('الحساب مغلق'),
            content: const Text(
              'حسابك مغلق مؤقتًا، يرجى إغلاق التطبيق وإعادة فتحه بعد فتح الحساب من قبل الإدارة',
            ),
          );
        },
      );
    }
  }

  Future<void> _refreshOrders() async {
    final status = _tabStatuses[_tabController.index];
    await _loadOrders(status, refresh: true);
  }

  Future<void> _refreshAllTabs() async {
    for (String status in _tabStatuses) {
      await _loadOrders(status, refresh: true);
    }
  }

  void _navigateToOrderDetails(Order order) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Check if vendor is locked before navigating
    if (authProvider.isVendorLocked) {
      _showVendorLockedDialog();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OrderDetailsScreen(order: order)),
    ).then((_) => _refreshAllTabs());
  }

  void _navigateToCounterOffer(Order order) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Check if vendor is locked before navigating
    if (authProvider.isVendorLocked) {
      _showVendorLockedDialog();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CounterOfferScreen(order: order)),
    ).then((_) => _refreshAllTabs());
  }

  void _navigateToCreateOrder({bool isShopOrder = false}) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Check if vendor is locked before navigating
    if (authProvider.isVendorLocked) {
      _showVendorLockedDialog();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateOrderScreen(isShopOrder: isShopOrder),
      ),
    ).then((_) => _refreshAllTabs());
  }

  Future<void> _handleOrderAction(Order order, String action) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Check if vendor is locked before handling action
    if (authProvider.isVendorLocked) {
      _showVendorLockedDialog();
      return;
    }

    switch (action) {
      case 'counter_offer':
        _navigateToCounterOffer(order);
        break;
      case 'reject':
        await _rejectOrder(order);
        break;
    }
  }

  Future<void> _rejectOrder(Order order) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Check if vendor is locked before rejecting order
    if (authProvider.isVendorLocked) {
      _showVendorLockedDialog();
      return;
    }

    final confirmed = await _showConfirmDialog(
      'رفض الطلب',
      'هل أنت متأكد من رفض هذا الطلب؟',
    );

    if (confirmed) {
      final response = await _orderService.rejectOrder(order.id);
      if (response.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفض الطلب بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _refreshAllTabs();
      } else if (response.error != null &&
          response.error!.contains('يرجى الانتظار حتى يتم فتح الحساب')) {
        // Update auth provider to indicate vendor is locked
        authProvider.setVendorLockStatus(true);
        if (mounted) {
          _showVendorLockedDialog();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'فشل في رفض الطلب'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تأكيد'),
              ),
            ],
          ),
        ) ??
        false;
  }

  List<Order> _getFilteredOrders(String status) {
    final orders = _ordersData[status] ?? [];
    if (_searchQuery.isEmpty) {
      return orders;
    }

    return orders.where((order) {
      return order.description.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          order.userAddress.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          order.phoneNumber.contains(_searchQuery) ||
          (order.user?.name.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ??
              false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'إدارة الطلبات',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshOrders,
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _navigateToCreateOrder,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search bar
              Container(
                margin: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'البحث في الطلبات...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onChanged: (value) {
                    if (mounted) {
                      setState(() {
                        _searchQuery = value;
                      });
                    }
                  },
                ),
              ),
              // Tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          CreateOrderActions(onCreate: _navigateToCreateOrder),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabStatuses
                  .map((status) => _buildOrdersList(status))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(String status) {
    final isLoading = _isLoading[status] ?? false;
    final error = _errors[status];
    final filteredOrders = _getFilteredOrders(status);

    if (isLoading && filteredOrders.isEmpty) {
      return const LoadingSkeleton();
    }

    if (error != null && filteredOrders.isEmpty) {
      return _buildErrorWidget(error, () => _loadOrders(status, refresh: true));
    }

    if (filteredOrders.isEmpty) {
      return _buildEmptyWidget();
    }

    return RefreshIndicator(
      onRefresh: _refreshOrders,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (!isLoading &&
              _hasMoreData[status] == true &&
              scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            _loadOrders(status);
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredOrders.length + (isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= filteredOrders.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final order = filteredOrders[index];
            return OrderCard(
              order: order,
              onTap: () => _navigateToOrderDetails(order),
              onAction: (action) => _handleOrderAction(order, action),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لا توجد طلبات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر الطلبات هنا عند توفرها',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
