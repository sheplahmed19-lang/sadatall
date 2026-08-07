import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../services/order_service.dart';
import '../orders/order_details_screen.dart';
import '../../../shared/chat/models/chat_message.dart';
import '../../../shared/chat/models/chat_participant.dart';
import '../../../shared/chat/presentation/chat_screen.dart';
import 'vendor_chat_attachment_uploader.dart';
import 'vendor_chat_client.dart';

const Color _vendorAccent = Color(0xFFFFC107);

/// vendor<->admin support chat — one persistent thread, always open.
class VendorSupportChatTab extends StatefulWidget {
  const VendorSupportChatTab({super.key});

  @override
  State<VendorSupportChatTab> createState() => _VendorSupportChatTabState();
}

class _VendorSupportChatTabState extends State<VendorSupportChatTab> {
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    // currentVendor can be null while still logged in when the launch-time
    // profile fetch failed (e.g. no connectivity on the splash screen), so
    // try once more on open rather than dead-ending on "please log in".
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryLoadVendor());
  }

  Future<void> _tryLoadVendor() async {
    final auth = context.read<AuthProvider>();
    if (auth.currentVendor != null || _retrying) return;

    setState(() => _retrying = true);
    await auth.ensureVendorLoaded();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final vendor = context.watch<AuthProvider>().currentVendor;
    if (vendor == null) {
      return Scaffold(
        body: Center(
          child: _retrying
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'تعذر تحميل بيانات المتجر، تحقق من الاتصال بالإنترنت',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _tryLoadVendor,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
        ),
      );
    }

    final self = ChatParticipant(role: ChatRole.vendor, id: vendor.id, displayName: vendor.vendorName);
    final repo = buildVendorChatRepository();

    return ChatScreen(
      repository: repo,
      openThread: () => repo.getOrCreateSupportChat(self),
      self: self,
      otherParticipantId: ChatParticipant.admin().participantId,
      title: 'الدعم',
      accentColor: _vendorAccent,
      attachmentService: buildVendorChatAttachmentService(),
      getCurrentLocation: () async {
        final result = await LocationService().getCurrentLocation();
        if (!result.success || result.latitude == null || result.longitude == null) return null;
        return (lat: result.latitude!, lng: result.longitude!);
      },
      onOrderRefTap: (OrderRef ref) => _openOrder(context, ref.orderId),
    );
  }

  Future<void> _openOrder(BuildContext context, String orderId) async {
    final response = await OrderService().getOrderById(orderId);
    if (response.success && response.data != null && context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(order: response.data!),
      ));
    }
  }
}
