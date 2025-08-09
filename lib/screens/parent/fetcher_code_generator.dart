import 'package:flutter/material.dart';
import 'dart:math';

class FetcherCodeGeneratorScreen extends StatefulWidget {
  const FetcherCodeGeneratorScreen({Key? key}) : super(key: key);

  @override
  State<FetcherCodeGeneratorScreen> createState() =>
      _FetcherCodeGeneratorScreenState();
}

class _FetcherCodeGeneratorScreenState extends State<FetcherCodeGeneratorScreen>
    with TickerProviderStateMixin {
  String _generatedCode = '';
  bool _isGenerating = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _generateCode() {
    setState(() {
      _isGenerating = true;
    });

    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    // Simulate code generation
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _generatedCode = _generateRandomCode();
          _isGenerating = false;
        });
      }
    });
  }

  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(
      6,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF19AE61);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);
    const Color white = Color(0xFFFFFFFF);

    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      appBar: AppBar(
        title: const Text(
          'Fetcher Code Generator',
          style: TextStyle(color: white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryGreen,
        elevation: 0,
        shadowColor: const Color(0xFF000000).withOpacity(0.1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: const Color(0xFF000000).withOpacity(0.1),
                child: Container(
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF000000).withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: greenWithOpacity,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            Icons.security,
                            color: primaryGreen,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Generate Fetcher Code',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create a unique code for authorized fetchers to access your child',
                          style: TextStyle(
                            fontSize: 14,
                            color: black.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Code Display Card
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: const Color(0xFF000000).withOpacity(0.1),
                child: Container(
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF000000).withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: greenWithOpacity,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.code,
                                color: primaryGreen,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Generated Code',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AnimatedBuilder(
                          animation: _scaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _generatedCode.isNotEmpty
                                          ? greenWithOpacity
                                          : const Color(0xFFF0F0F0),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        _generatedCode.isNotEmpty
                                            ? primaryGreen
                                            : const Color(0xFFE0E0E0),
                                    width: 2,
                                  ),
                                ),
                                child:
                                    _isGenerating
                                        ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(primaryGreen),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Generating...',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: black,
                                              ),
                                            ),
                                          ],
                                        )
                                        : Text(
                                          _generatedCode.isNotEmpty
                                              ? _generatedCode
                                              : 'No code generated yet',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                _generatedCode.isNotEmpty
                                                    ? primaryGreen
                                                    : black.withOpacity(0.5),
                                            letterSpacing: 2,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generateCode,
                    icon: Icon(
                      _isGenerating ? Icons.hourglass_empty : Icons.security,
                    ),
                    label: Text(
                      _isGenerating ? 'Generating...' : 'Generate New Code',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: white,
                      elevation: 2,
                      shadowColor: const Color(0xFF000000).withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_generatedCode.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Implement copy to clipboard
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: primaryGreen,
                                    size: 24,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Success',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: black,
                                    ),
                                  ),
                                ],
                              ),
                              content: Text(
                                'Code copied to clipboard successfully.',
                                style: TextStyle(color: black.withOpacity(0.7)),
                              ),
                              actions: [
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryGreen,
                                    foregroundColor: white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text('OK'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.content_copy),
                      label: const Text('Copy Code'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryGreen,
                        side: BorderSide(color: primaryGreen),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Instructions Card
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                shadowColor: const Color(0xFF000000).withOpacity(0.05),
                child: Container(
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF000000).withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: greenWithOpacity,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.help_outline,
                                color: primaryGreen,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'How to use:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInstructionStep(
                          '1',
                          'Generate a unique code',
                          Icons.qr_code,
                          primaryGreen,
                          black,
                        ),
                        const SizedBox(height: 8),
                        _buildInstructionStep(
                          '2',
                          'Share the code with authorized fetchers',
                          Icons.share,
                          primaryGreen,
                          black,
                        ),
                        const SizedBox(height: 8),
                        _buildInstructionStep(
                          '3',
                          'Fetchers can use this code to access your child',
                          Icons.security,
                          primaryGreen,
                          black,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(
    String number,
    String instruction,
    IconData icon,
    Color primaryGreen,
    Color black,
  ) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(25, 174, 97, 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            instruction,
            style: TextStyle(fontSize: 14, color: black.withOpacity(0.8)),
          ),
        ),
        Icon(icon, color: primaryGreen, size: 16),
      ],
    );
  }
}
