import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/requests_provider.dart';

class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Reset submit state when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(submitRequestProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(submitRequestProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء طلب جديد'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'معلومات الطلب',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'يمكنك إنشاء طلب للإدارة لأي استفسار أو مشكلة تواجهك. '
                        'سيتم مراجعة طلبك والرد عليك في أقرب وقت ممكن.',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: CustomTextField(
                  label: 'وصف الطلب',
                  hint: 'اكتب تفاصيل طلبك أو استفسارك هنا...',
                  controller: _descriptionController,
                  maxLines: 8,
                  maxLength: 500,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'وصف الطلب مطلوب';
                    }
                    if (value.trim().length < 10) {
                      return 'وصف الطلب يجب أن يكون 10 أحرف على الأقل';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 24),
              if (submitState.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Text(
                    submitState.error!,
                    style: const TextStyle(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              CustomButton(
                text: 'إرسال الطلب',
                onPressed: _submitRequest,
                isLoading: submitState.isLoading,
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 200 : 50),
            ],
          ),
        ),
      ),
    );
  }

  void _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await ref.read(submitRequestProvider.notifier).submitRequest(
      _descriptionController.text.trim(),
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الطلب بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true); // Return true to indicate success
    }
  }
}