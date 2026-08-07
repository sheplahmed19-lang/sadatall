import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/complaint.dart';
import '../../providers/auth_provider.dart';
import '../../services/complaint_service.dart';
import '../../utils/time_utils.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  final ComplaintService _complaintService = ComplaintService();
  final TextEditingController _complaintController = TextEditingController();
  List<Complaint> _complaints = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  int _currentPage = 1;
  int _totalPages = 1;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  Future<void> _loadComplaints() async {
    setState(() {
      _isLoading = true;
    });

    final response = await _complaintService.getUserComplaints(
      page: _currentPage,
      limit: _limit,
    );

    if (response.success && response.data != null) {
      setState(() {
        _complaints = response.data!['complaints'] as List<Complaint>;
        final pagination = response.data!['pagination'] as Map<String, dynamic>;
        _totalPages = pagination['pages'] as int;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.error ?? 'حدث خطأ أثناء جلب الشكاوى'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _submitComplaint() async {
    final description = _complaintController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة وصف الشكوى'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final response = await _complaintService.submitComplaint(description);

    if (response.success && response.data != null) {
      _complaintController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'تم إرسال الشكوى بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
      // Reload complaints to show the new one
      _currentPage = 1;
      _loadComplaints();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.error ?? 'حدث خطأ أثناء إرسال الشكوى'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isSubmitting = false;
    });
  }

  Future<void> _deleteComplaint(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الشكوى'),
        content: const Text('هل أنت متأكد من حذف هذه الشكوى؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _complaintService.deleteComplaint(id);

      if (response.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'تم حذف الشكوى بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // Reload complaints after deletion
        _loadComplaints();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'حدث خطأ أثناء حذف الشكوى'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _refreshComplaints() async {
    _currentPage = 1;
    await _loadComplaints();
  }

  void _nextPage() {
    if (_currentPage < _totalPages) {
      setState(() {
        _currentPage++;
      });
      _loadComplaints();
    }
  }

  void _previousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
      _loadComplaints();
    }
  }

  @override
  void dispose() {
    _complaintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الشكاوى',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshComplaints,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSubmitComplaintSection(),
              const SizedBox(height: 24),
              _buildComplaintsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitComplaintSection() {
    final authProvider = Provider.of<AuthProvider>(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إرسال شكوى جديدة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'المستخدم: ${authProvider.user?.userName ?? ''}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _complaintController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'وصف الشكوى...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitComplaint,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'إرسال الشكوى',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplaintsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'شكاواك السابقة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
              const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (_complaints.isEmpty)
          const Center(
            child: Text(
              'لا توجد شكاوى سابقة',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          )
        else
          Column(
            children: [
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _complaints.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final complaint = _complaints[index];
                  return _buildComplaintCard(complaint);
                },
              ),
              const SizedBox(height: 16),
              _buildPaginationControls(),
            ],
          ),
      ],
    );
  }

  Widget _buildComplaintCard(Complaint complaint) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'رقم الشكوى: ${complaint.id}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteComplaint(complaint.id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              complaint.description,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'تاريخ الإرسال: ${_formatDate(complaint.submittedAt)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            if (complaint.reply != null) ...[
              const Divider(height: 24),
              const Text(
                'الرد من الإدارة:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                complaint.reply!,
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
              if (complaint.repliedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'تاريخ الرد: ${_formatDate(complaint.repliedAt!)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton(
          onPressed: _currentPage <= 1 ? null : _previousPage,
          child: const Text('السابق'),
        ),
        Text('الصفحة $_currentPage من $_totalPages'),
        ElevatedButton(
          onPressed: _currentPage >= _totalPages ? null : _nextPage,
          child: const Text('التالي'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return TimeUtils.formatCairoDateTimeArabic(date, pattern: 'yyyy/MM/dd hh:mm a');
  }
}