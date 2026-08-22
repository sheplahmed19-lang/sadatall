import 'package:flutter/material.dart';
import '../dashboard/main_dashboard_screen.dart';
import '../orders/orders_management_screen.dart';
import '../items/items_management_screen.dart';
import '../menu/menu_management_screen.dart';
import '../settings/settings_screen.dart';
import '../announcements/vendor_offers_screen.dart';
import '../../services/notification_service.dart';
import '../chat/vendor_support_chat_tab.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  final NotificationService _notificationService = NotificationService();

  late List<Widget> _screens;
  late List<BottomNavigationBarItem> _navItems;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    
    _screens = [
      const MainDashboardScreen(),
      const OrdersManagementScreen(),
      const ItemsManagementScreen(),
      const MenuManagementScreen(),
      const VendorOffersScreen(),
      const SettingsScreen(),
      const VendorSupportChatTab(),
    ];

    _navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard),
        activeIcon: Icon(Icons.dashboard),
        label: 'الرئيسية',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.shopping_cart_outlined),
        activeIcon: Icon(Icons.shopping_cart),
        label: 'الطلبات',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.shopping_bag_outlined),
        activeIcon: Icon(Icons.shopping_bag),
        label: 'المنتجات',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.restaurant_menu_outlined),
        activeIcon: Icon(Icons.restaurant_menu),
        label: 'القوائم',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.campaign_outlined),
        activeIcon: Icon(Icons.campaign),
        label: 'الأخبار',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.settings_outlined),
        activeIcon: Icon(Icons.settings),
        label: 'الإعدادات',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.support_agent_outlined),
        activeIcon: Icon(Icons.support_agent),
        label: 'الدعم',
      ),
    ];
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize();
      
      // Subscribe to vendor-specific topics
      await _notificationService.subscribeToTopic('vendor_notifications');
      await _notificationService.subscribeToTopic('order_updates');
      
      // Show welcome notification if FCM is working
      if (_notificationService.isInitialized) {
        await Future.delayed(const Duration(seconds: 2));
        await _notificationService.showGeneralNotification(
          title: 'مرحبًا بك في تطبيق تعالالي للبائعين!',
          body: 'سيتم إشعارك بجميع الطلبات والتحديثات الجديدة',
        );
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFFFFC107),
            unselectedItemColor: Colors.grey[600],
            selectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12,
            ),
            elevation: 0,
            items: _navItems,
          ),
        ),
      ),
      // The orders tab now offers both order types as cards above the list
      // (CreateOrderActions), so a generic "+" here would be a third, more
      // ambiguous route to the same place.
      floatingActionButton: null,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

