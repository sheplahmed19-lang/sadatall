import 'package:flutter/material.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';

class UpdateLocationWidget extends StatefulWidget {
  final Function(double latitude, double longitude) onLocationUpdated;
  final bool isLoading;
  final String buttonText;
  final IconData icon;
  final Color? backgroundColor;
  final Color? textColor;
  final EdgeInsetsGeometry? padding;
  final bool showCurrentLocation;
  final double? currentLatitude;
  final double? currentLongitude;

  const UpdateLocationWidget({
    super.key,
    required this.onLocationUpdated,
    this.isLoading = false,
    this.buttonText = 'تحديث الموقع الحالي',
    this.icon = Icons.my_location,
    this.backgroundColor,
    this.textColor,
    this.padding,
    this.showCurrentLocation = true,
    this.currentLatitude,
    this.currentLongitude,
  });

  @override
  State<UpdateLocationWidget> createState() => _UpdateLocationWidgetState();
}

class _UpdateLocationWidgetState extends State<UpdateLocationWidget> {
  final LocationService _locationService = LocationService();
  bool _isUpdatingLocation = false;

  Future<void> _updateCurrentLocation() async {
    setState(() {
      _isUpdatingLocation = true;
    });

    try {
      final locationResult = await _locationService.getCurrentLocation();
      
      if (locationResult.success && locationResult.latitude != null && locationResult.longitude != null) {
        // Call the callback with the new location
        widget.onLocationUpdated(locationResult.latitude!, locationResult.longitude!);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تحديث الموقع: ${locationResult.latitude!.toStringAsFixed(4)}, ${locationResult.longitude!.toStringAsFixed(4)}'),
              backgroundColor: AppTheme.primaryColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Fallback to 0,0 coordinates
        widget.onLocationUpdated(0.0, 0.0);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل في الحصول على الموقع، تم استخدام الموقع الافتراضي\nالخطأ: ${locationResult.error ?? 'غير معروف'}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تحديث الموقع: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: widget.padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'الموقع الجغرافي',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          if (widget.showCurrentLocation && widget.currentLatitude != null && widget.currentLongitude != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.place,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الموقع الحالي:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'خط العرض: ${widget.currentLatitude!.toStringAsFixed(6)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'خط الطول: ${widget.currentLongitude!.toStringAsFixed(6)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (widget.isLoading || _isUpdatingLocation) ? null : _updateCurrentLocation,
              icon: _isUpdatingLocation 
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.textColor ?? Colors.white,
                        ),
                      ),
                    )
                  : Icon(widget.icon),
              label: Text(
                _isUpdatingLocation ? 'جاري تحديث الموقع...' : widget.buttonText,
                style: TextStyle(
                  color: widget.textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.backgroundColor ?? AppTheme.primaryColor,
                foregroundColor: widget.textColor ?? Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 1,
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'اضغط للحصول على موقعك الحالي وتحديث الإحداثيات تلقائياً',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}