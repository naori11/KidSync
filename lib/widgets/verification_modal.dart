import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/verification_service.dart';

class VerificationModal extends StatefulWidget {
  final List<Map<String, dynamic>> pendingVerifications;
  final VoidCallback onVerificationUpdated;

  const VerificationModal({
    Key? key,
    required this.pendingVerifications,
    required this.onVerificationUpdated,
  }) : super(key: key);

  @override
  State<VerificationModal> createState() => _VerificationModalState();
}

class _VerificationModalState extends State<VerificationModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  final VerificationService _verificationService = VerificationService();
  final TextEditingController _notesController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleVerification(int verificationId, bool isConfirmed) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      bool success;
      if (isConfirmed) {
        success = await _verificationService.confirmVerification(
          verificationId,
          parentNotes:
              _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
        );
      } else {
        success = await _verificationService.denyVerification(
          verificationId,
          parentNotes:
              _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
        );
      }

      if (success) {
        widget.onVerificationUpdated();
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isConfirmed
                  ? 'Pickup/Dropoff verified successfully'
                  : 'Pickup/Dropoff dispute reported',
            ),
            backgroundColor: isConfirmed ? Colors.green : Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error processing verification'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
    final isLandscape = screenWidth > screenHeight;

    // Get text scale factor for accessibility
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    final isLargeText = textScaleFactor > 1.2;

    // Responsive sizing
    final modalWidth =
        isMobile
            ? screenWidth - 32
            : isTablet
            ? screenWidth * 0.8
            : screenWidth * 0.6;
    final modalHeight =
        isMobile
            ? (isLandscape ? screenHeight * 0.95 : screenHeight * 0.9)
            : isTablet
            ? (isLandscape ? screenHeight * 0.9 : screenHeight * 0.85)
            : (isLandscape ? screenHeight * 0.85 : screenHeight * 0.8);
    final maxHeight = modalHeight;

    // Ensure minimum and maximum sizes
    final minWidth = isMobile ? 280.0 : 400.0;
    final maxWidth = isDesktop ? 800.0 : double.infinity;
    final minHeight = isMobile ? 400.0 : 500.0;

    const Color primaryGreen = Color(0xFF19AE61);
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(
        isMobile
            ? 16
            : isTablet
            ? 24
            : 40,
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: modalWidth.clamp(minWidth, maxWidth),
            height: maxHeight.clamp(minHeight, screenHeight * 0.95),
            constraints: BoxConstraints(
              minWidth: minWidth,
              maxWidth: maxWidth,
              minHeight: minHeight,
              maxHeight: screenHeight * 0.95,
            ),
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: isMobile ? 16 : 20,
                  offset: const Offset(0, 8),
                  spreadRadius: isMobile ? 2 : 5,
                ),
              ],
            ),
            child: Column(
              children: [
                // Modal Header
                Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 20),
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isMobile ? 16 : 20),
                      topRight: Radius.circular(isMobile ? 16 : 20),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color: primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            isMobile ? 8 : 10,
                          ),
                        ),
                        child: Icon(
                          Icons.verified_user,
                          color: primaryGreen,
                          size: isMobile ? 20 : 24,
                        ),
                      ),
                      SizedBox(width: isMobile ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verify Pickup/Dropoff',
                              style: TextStyle(
                                color: black,
                                fontWeight: FontWeight.bold,
                                fontSize:
                                    isMobile
                                        ? 18
                                        : isTablet
                                        ? 20
                                        : 22,
                              ),
                            ),
                            Text(
                              'Please verify the following events',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: isMobile ? 12 : 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: black.withOpacity(0.6),
                          size: isMobile ? 20 : 24,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.withOpacity(0.1),
                          shape: const CircleBorder(),
                          padding: EdgeInsets.all(isMobile ? 8 : 12),
                        ),
                      ),
                    ],
                  ),
                ),
                // Modal Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.pendingVerifications.isEmpty)
                          Container(
                            padding: EdgeInsets.all(isMobile ? 30 : 40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: isMobile ? 48 : 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: isMobile ? 12 : 16),
                                Text(
                                  'No pending verifications',
                                  style: TextStyle(
                                    fontSize: isMobile ? 16 : 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...widget.pendingVerifications.map(
                            (verification) => _buildVerificationCard(
                              verification,
                              isMobile,
                              isTablet,
                              isDesktop,
                              isLandscape,
                              isLargeText,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationCard(
    Map<String, dynamic> verification,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
    bool isLandscape,
    bool isLargeText,
  ) {
    const Color primaryGreen = Color(0xFF19AE61);
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);

    final student = verification['students'];
    final driver = verification['drivers'];
    final eventType = verification['event_type'];
    final eventTime = DateTime.parse(verification['event_time']);
    final studentName = '${student['fname']} ${student['lname']}';
    final driverName = '${driver['fname']} ${driver['lname']}';
    final plateNumber = driver['plate_number'];
    final profileImageUrl = student['profile_image_url'];
    final driverImageUrl = driver['profile_image_url'];

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 16 : 20),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        border: Border.all(color: primaryGreen.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.1),
            blurRadius: isMobile ? 8 : 10,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Header
          Row(
            children: [
              Icon(
                eventType == 'pickup' ? Icons.directions_car : Icons.home,
                color: eventType == 'pickup' ? primaryGreen : Colors.orange,
                size: isMobile ? 20 : 24,
              ),
              SizedBox(width: isMobile ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${eventType == 'pickup' ? 'Pickup' : 'Dropoff'} Verification',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize:
                            (isMobile
                                ? 16
                                : isTablet
                                ? 18
                                : 20) *
                            (isLargeText ? 1.1 : 1.0),
                        color: black,
                      ),
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy at h:mm a').format(eventTime),
                      style: TextStyle(
                        color: black.withOpacity(0.6),
                        fontSize:
                            (isMobile ? 12 : 14) * (isLargeText ? 1.1 : 1.0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: (isMobile ? 16 : 20) * (isLargeText ? 1.2 : 1.0)),

          // Student and Driver Info
          (isMobile || (isTablet && isLandscape))
              ? Column(
                children: [
                  // Student Info
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: primaryGreen.withOpacity(0.1),
                          radius: isMobile ? 20 : 24,
                          backgroundImage:
                              profileImageUrl != null &&
                                      profileImageUrl.isNotEmpty
                                  ? NetworkImage(profileImageUrl)
                                  : null,
                          child:
                              profileImageUrl == null || profileImageUrl.isEmpty
                                  ? Icon(
                                    Icons.person,
                                    color: primaryGreen,
                                    size: isMobile ? 20 : 24,
                                  )
                                  : null,
                        ),
                        SizedBox(width: isMobile ? 10 : 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Student',
                                style: TextStyle(
                                  fontSize: isMobile ? 10 : 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                studentName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isMobile ? 14 : 16,
                                  color: black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                  // Driver Info
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: primaryGreen.withOpacity(0.1),
                          radius: isMobile ? 20 : 24,
                          backgroundImage:
                              driverImageUrl != null &&
                                      driverImageUrl.isNotEmpty
                                  ? NetworkImage(driverImageUrl)
                                  : null,
                          child:
                              driverImageUrl == null || driverImageUrl.isEmpty
                                  ? Icon(
                                    Icons.local_shipping,
                                    color: primaryGreen,
                                    size: isMobile ? 20 : 24,
                                  )
                                  : null,
                        ),
                        SizedBox(width: isMobile ? 10 : 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Driver',
                                style: TextStyle(
                                  fontSize: isMobile ? 10 : 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                driverName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isMobile ? 14 : 16,
                                  color: black,
                                ),
                              ),
                              if (plateNumber != null &&
                                  plateNumber.toString().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.directions_car,
                                      size: isMobile ? 12 : 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Plate: $plateNumber',
                                      style: TextStyle(
                                        fontSize: isMobile ? 11 : 13,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
              : Row(
                children: [
                  // Student Info
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: primaryGreen.withOpacity(0.1),
                            radius: isMobile ? 20 : 24,
                            backgroundImage:
                                profileImageUrl != null &&
                                        profileImageUrl.isNotEmpty
                                    ? NetworkImage(profileImageUrl)
                                    : null,
                            child:
                                profileImageUrl == null ||
                                        profileImageUrl.isEmpty
                                    ? Icon(
                                      Icons.person,
                                      color: primaryGreen,
                                      size: isMobile ? 20 : 24,
                                    )
                                    : null,
                          ),
                          SizedBox(width: isMobile ? 10 : 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Student',
                                  style: TextStyle(
                                    fontSize: isMobile ? 10 : 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  studentName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: isMobile ? 14 : 16,
                                    color: black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: isMobile ? 12 : 16),
                  // Driver Info
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: primaryGreen.withOpacity(0.1),
                            radius: isMobile ? 20 : 24,
                            backgroundImage:
                                driverImageUrl != null &&
                                        driverImageUrl.isNotEmpty
                                    ? NetworkImage(driverImageUrl)
                                    : null,
                            child:
                                driverImageUrl == null || driverImageUrl.isEmpty
                                    ? Icon(
                                      Icons.local_shipping,
                                      color: primaryGreen,
                                      size: isMobile ? 20 : 24,
                                    )
                                    : null,
                          ),
                          SizedBox(width: isMobile ? 10 : 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Driver',
                                  style: TextStyle(
                                    fontSize: isMobile ? 10 : 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  driverName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: isMobile ? 14 : 16,
                                    color: black,
                                  ),
                                ),
                                if (plateNumber != null &&
                                    plateNumber.toString().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.directions_car,
                                        size: isMobile ? 12 : 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Plate: $plateNumber',
                                        style: TextStyle(
                                          fontSize: isMobile ? 11 : 13,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          SizedBox(height: isMobile ? 16 : 20),

          // Notes Field
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Add any comments about this ${eventType}...',
              labelStyle: TextStyle(fontSize: isMobile ? 12 : 14),
              hintStyle: TextStyle(fontSize: isMobile ? 12 : 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                borderSide: const BorderSide(color: primaryGreen, width: 2),
              ),
              contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
            ),
            maxLines: isMobile ? 2 : 3,
            style: TextStyle(fontSize: isMobile ? 14 : 16),
          ),
          SizedBox(height: isMobile ? 20 : 24),

          // Action Buttons
          (isMobile || (isTablet && isLandscape))
              ? Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _isProcessing
                              ? null
                              : () =>
                                  _handleVerification(verification['id'], true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: white,
                        padding: EdgeInsets.symmetric(
                          vertical: isMobile ? 14 : 16,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            isMobile ? 10 : 12,
                          ),
                        ),
                        elevation: 4,
                        shadowColor: primaryGreen.withOpacity(0.3),
                      ),
                      icon:
                          _isProcessing
                              ? SizedBox(
                                width: isMobile ? 14 : 16,
                                height: isMobile ? 14 : 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    white,
                                  ),
                                ),
                              )
                              : Icon(
                                Icons.check,
                                color: white,
                                size: isMobile ? 18 : 20,
                              ),
                      label: Text(
                        _isProcessing ? 'Processing...' : 'Confirm',
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          _isProcessing
                              ? null
                              : () => _handleVerification(
                                verification['id'],
                                false,
                              ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 2),
                        padding: EdgeInsets.symmetric(
                          vertical: isMobile ? 14 : 16,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            isMobile ? 10 : 12,
                          ),
                        ),
                      ),
                      icon: Icon(
                        Icons.close,
                        color: Colors.red,
                        size: isMobile ? 18 : 20,
                      ),
                      label: Text(
                        'Dispute',
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ],
              )
              : Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _isProcessing
                              ? null
                              : () =>
                                  _handleVerification(verification['id'], true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: white,
                        padding: EdgeInsets.symmetric(
                          vertical: isMobile ? 14 : 16,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            isMobile ? 10 : 12,
                          ),
                        ),
                        elevation: 4,
                        shadowColor: primaryGreen.withOpacity(0.3),
                      ),
                      icon:
                          _isProcessing
                              ? SizedBox(
                                width: isMobile ? 14 : 16,
                                height: isMobile ? 14 : 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    white,
                                  ),
                                ),
                              )
                              : Icon(
                                Icons.check,
                                color: white,
                                size: isMobile ? 18 : 20,
                              ),
                      label: Text(
                        _isProcessing ? 'Processing...' : 'Confirm',
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isMobile ? 12 : 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _isProcessing
                              ? null
                              : () => _handleVerification(
                                verification['id'],
                                false,
                              ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 2),
                        padding: EdgeInsets.symmetric(
                          vertical: isMobile ? 14 : 16,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            isMobile ? 10 : 12,
                          ),
                        ),
                      ),
                      icon: Icon(
                        Icons.close,
                        color: Colors.red,
                        size: isMobile ? 18 : 20,
                      ),
                      label: Text(
                        'Dispute',
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}
