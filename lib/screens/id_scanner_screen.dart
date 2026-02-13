import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Scanner status stages
enum ScannerStatus {
  searching,
  objectDetected,
  cnicAligned,
  stabilizing,
  capturing,
}

extension ScannerStatusExtension on ScannerStatus {
  String get statusText {
    switch (this) {
      case ScannerStatus.searching:
        return 'Searching...';
      case ScannerStatus.objectDetected:
        return 'Object Detected';
      case ScannerStatus.cnicAligned:
        return 'CNIC Detected';
      case ScannerStatus.stabilizing:
        return 'Verifying...';
      case ScannerStatus.capturing:
        return 'Capturing...';
    }
  }

  String get instruction {
    switch (this) {
      case ScannerStatus.searching:
        return 'Position CNIC inside the frame';
      case ScannerStatus.objectDetected:
        return 'Align card edges with frame';
      case ScannerStatus.cnicAligned:
        return 'Hold steady...';
      case ScannerStatus.stabilizing:
        return 'Keep still';
      case ScannerStatus.capturing:
        return "Don't move";
    }
  }

  Color get color {
    switch (this) {
      case ScannerStatus.searching:
        return Colors.white70;
      case ScannerStatus.objectDetected:
        return Colors.amber;
      case ScannerStatus.cnicAligned:
        return Colors.lightGreen;
      case ScannerStatus.stabilizing:
        return Colors.green;
      case ScannerStatus.capturing:
        return Colors.greenAccent;
    }
  }

  IconData get icon {
    switch (this) {
      case ScannerStatus.searching:
        return Icons.search;
      case ScannerStatus.objectDetected:
        return Icons.crop_free;
      case ScannerStatus.cnicAligned:
        return Icons.credit_card;
      case ScannerStatus.stabilizing:
        return Icons.hourglass_top;
      case ScannerStatus.capturing:
        return Icons.camera;
    }
  }
}

/// High-performance ID card scanner with edge-based contour detection.
/// Uses fast luminance analysis for sub-30ms rectangle detection.
class IDScannerScreen extends StatefulWidget {
  const IDScannerScreen({super.key});

  @override
  State<IDScannerScreen> createState() => _IDScannerScreenState();
}

class _IDScannerScreenState extends State<IDScannerScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  bool _isBusy = false;
  bool _captured = false;
  bool _isInitialized = false;
  String? _errorMessage;
  String? _capturedImagePath;
  
  // Status tracking
  ScannerStatus _status = ScannerStatus.searching;
  
  // Stability tracking for auto-capture
  int _stableFrameCount = 0;
  static const int _requiredStableFrames = 3;
  
  // Detection states
  bool _objectInFrame = false;
  bool _cardAligned = false;
  int _frameSkipCounter = 0;
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _cornerController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _cornerAnimation;
  
  // Overlay dimensions (ID card aspect ratio ~1.586)
  static const double _overlayWidthRatio = 0.85;
  static const double _overlayAspectRatio = 1.586;
  
  // Detection thresholds
  static const double _minCoverageRatio = 0.55;
  static const double _highCoverageRatio = 0.70;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Pulse animation for capturing state
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Corner bracket animation
    _cornerController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _cornerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cornerController, curve: Curves.easeOut),
    );
    
    _initializeScanner();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _cornerController.dispose();
    _disposeResources();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _disposeResources();
    } else if (state == AppLifecycleState.resumed) {
      _initializeScanner();
    }
  }

  Future<void> _disposeResources() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }

  Future<void> _initializeScanner() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No camera available');
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();

      if (!mounted) return;

      await _controller!.startImageStream(_processFrame);

      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _errorMessage = 'Camera error: $e');
    }
  }

  void _updateStatus(ScannerStatus newStatus) {
    if (_status != newStatus) {
      setState(() => _status = newStatus);
      
      // Handle animations based on status
      if (newStatus == ScannerStatus.capturing) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
      
      if (newStatus.index >= ScannerStatus.objectDetected.index) {
        _cornerController.forward();
      } else {
        _cornerController.reverse();
      }
    }
  }

  /// Fast edge-based rectangle detection
  void _processFrame(CameraImage image) async {
    if (_isBusy || _captured) return;
    
    _frameSkipCounter++;
    if (_frameSkipCounter % 2 != 0) return;
    
    _isBusy = true;

    try {
      final result = _detectRectangle(image);
      
      if (!mounted || _captured) {
        _isBusy = false;
        return;
      }

      _objectInFrame = result.objectDetected;
      _cardAligned = result.cardAligned;

      if (_cardAligned) {
        _stableFrameCount++;
        
        if (_stableFrameCount >= _requiredStableFrames) {
          _updateStatus(ScannerStatus.capturing);
          await _captureImage();
        } else if (_stableFrameCount >= 2) {
          _updateStatus(ScannerStatus.stabilizing);
        } else {
          _updateStatus(ScannerStatus.cnicAligned);
        }
      } else if (_objectInFrame) {
        _stableFrameCount = 0;
        _updateStatus(ScannerStatus.objectDetected);
      } else {
        _stableFrameCount = 0;
        _updateStatus(ScannerStatus.searching);
      }
    } catch (e) {
      debugPrint('Detection error: $e');
    } finally {
      _isBusy = false;
    }
  }

  /// Detection result with multiple states
  ({bool objectDetected, bool cardAligned}) _detectRectangle(CameraImage image) {
    if (image.planes.isEmpty) {
      return (objectDetected: false, cardAligned: false);
    }
    
    final int width = image.width;
    final int height = image.height;
    final plane = image.planes[0];
    final bytes = plane.bytes;
    
    final overlayWidth = (width * _overlayWidthRatio).toInt();
    final overlayHeight = (overlayWidth / _overlayAspectRatio).toInt();
    final overlayLeft = ((width - overlayWidth) / 2).toInt();
    final overlayTop = ((height - overlayHeight) / 2).toInt();
    
    int edgeCount = 0;
    const int samplePoints = 12;
    const int edgeThreshold = 25;
    const int borderOffset = 10;
    
    // Sample top edge
    for (int i = 0; i < samplePoints; i++) {
      final x = overlayLeft + (overlayWidth * i ~/ samplePoints);
      final yOuter = math.max(0, overlayTop - borderOffset);
      final yInner = math.min(height - 1, overlayTop + borderOffset);
      
      final outerIdx = yOuter * plane.bytesPerRow + x;
      final innerIdx = yInner * plane.bytesPerRow + x;
      
      if (outerIdx < bytes.length && innerIdx < bytes.length) {
        final diff = (bytes[outerIdx] - bytes[innerIdx]).abs();
        if (diff > edgeThreshold) edgeCount++;
      }
    }
    
    // Sample bottom edge
    final bottomY = overlayTop + overlayHeight;
    for (int i = 0; i < samplePoints; i++) {
      final x = overlayLeft + (overlayWidth * i ~/ samplePoints);
      final yInner = math.max(0, bottomY - borderOffset);
      final yOuter = math.min(height - 1, bottomY + borderOffset);
      
      final innerIdx = yInner * plane.bytesPerRow + x;
      final outerIdx = yOuter * plane.bytesPerRow + x;
      
      if (innerIdx < bytes.length && outerIdx < bytes.length) {
        final diff = (bytes[innerIdx] - bytes[outerIdx]).abs();
        if (diff > edgeThreshold) edgeCount++;
      }
    }
    
    // Sample left edge
    for (int i = 0; i < samplePoints; i++) {
      final y = overlayTop + (overlayHeight * i ~/ samplePoints);
      final xOuter = math.max(0, overlayLeft - borderOffset);
      final xInner = math.min(width - 1, overlayLeft + borderOffset);
      
      final outerIdx = y * plane.bytesPerRow + xOuter;
      final innerIdx = y * plane.bytesPerRow + xInner;
      
      if (outerIdx < bytes.length && innerIdx < bytes.length) {
        final diff = (bytes[outerIdx] - bytes[innerIdx]).abs();
        if (diff > edgeThreshold) edgeCount++;
      }
    }
    
    // Sample right edge
    final rightX = overlayLeft + overlayWidth;
    for (int i = 0; i < samplePoints; i++) {
      final y = overlayTop + (overlayHeight * i ~/ samplePoints);
      final xInner = math.max(0, rightX - borderOffset);
      final xOuter = math.min(width - 1, rightX + borderOffset);
      
      final innerIdx = y * plane.bytesPerRow + xInner;
      final outerIdx = y * plane.bytesPerRow + xOuter;
      
      if (innerIdx < bytes.length && outerIdx < bytes.length) {
        final diff = (bytes[innerIdx] - bytes[outerIdx]).abs();
        if (diff > edgeThreshold) edgeCount++;
      }
    }
    
    // Check center brightness
    final centerX = width ~/ 2;
    final centerY = height ~/ 2;
    final centerIdx = centerY * plane.bytesPerRow + centerX;
    final cornerIdx = (overlayTop - 20).clamp(0, height - 1) * plane.bytesPerRow + 
                      (overlayLeft - 20).clamp(0, width - 1);
    
    bool hasBrightnessContrast = false;
    if (centerIdx < bytes.length && cornerIdx < bytes.length) {
      final centerBrightness = bytes[centerIdx];
      final cornerBrightness = bytes[cornerIdx];
      hasBrightnessContrast = centerBrightness > cornerBrightness + 15;
    }
    
    final totalSamples = samplePoints * 4;
    final edgeRatio = edgeCount / totalSamples;
    
    final objectDetected = edgeRatio > _minCoverageRatio;
    final cardAligned = edgeRatio > _highCoverageRatio && hasBrightnessContrast;
    
    return (objectDetected: objectDetected, cardAligned: cardAligned);
  }

  Future<void> _captureImage() async {
    if (_captured || _controller == null) return;

    _captured = true;
    
    // Haptic feedback
    HapticFeedback.mediumImpact();

    try {
      await _controller!.stopImageStream();
      final file = await _controller!.takePicture();

      if (!mounted) return;

      setState(() {
        _capturedImagePath = file.path;
      });
    } catch (e) {
      debugPrint('Capture error: $e');
      _captured = false;
      _stableFrameCount = 0;
      _updateStatus(ScannerStatus.searching);
      await _controller!.startImageStream(_processFrame);
    }
  }

  void _retake() {
    setState(() {
      _capturedImagePath = null;
      _captured = false;
      _stableFrameCount = 0;
      _objectInFrame = false;
      _cardAligned = false;
      _status = ScannerStatus.searching;
    });
    _pulseController.stop();
    _pulseController.reset();
    _cornerController.reset();
    _controller!.startImageStream(_processFrame);
  }

  void _confirmCapture() {
    Navigator.of(context).pop(_capturedImagePath);
  }

  @override
  Widget build(BuildContext context) {
    if (_capturedImagePath != null) {
      return _buildPreviewScreen();
    }
    return _buildScannerScreen();
  }

  Widget _buildPreviewScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(_capturedImagePath!), fit: BoxFit.contain),
          
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: const Text(
                'Preview',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 32,
                right: 32,
                top: 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: _retake,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text('Retake', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  FilledButton.icon(
                    onPressed: _confirmCapture,
                    icon: const Icon(Icons.check),
                    label: const Text('Use Photo'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerScreen() {
    final screenSize = MediaQuery.of(context).size;
    final overlayWidth = screenSize.width * _overlayWidthRatio;
    final overlayHeight = overlayWidth / _overlayAspectRatio;
    final centerY = screenSize.height / 2;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          if (_isInitialized && _controller != null)
            Center(child: CameraPreview(_controller!))
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Overlay with cutout
          if (_isInitialized)
            CustomPaint(
              size: screenSize,
              painter: _OverlayPainter(overlayWidth: overlayWidth, overlayHeight: overlayHeight),
            ),

          // Animated corner brackets
          if (_isInitialized)
            Center(
              child: AnimatedBuilder(
                animation: _cornerAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(overlayWidth + 20, overlayHeight + 20),
                    painter: _CornerBracketPainter(
                      color: _status.color,
                      progress: _cornerAnimation.value,
                      width: overlayWidth,
                      height: overlayHeight,
                    ),
                  );
                },
              ),
            ),

          // Overlay border with pulse animation
          if (_isInitialized)
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _status == ScannerStatus.capturing ? _pulseAnimation.value : 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: overlayWidth,
                      height: overlayHeight,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _status.color,
                          width: _status.index >= ScannerStatus.cnicAligned.index ? 4 : 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Status indicator with icon
          if (_isInitialized)
            Positioned(
              top: centerY - overlayHeight / 2 - 60,
              left: 0,
              right: 0,
              child: _StatusIndicator(status: _status, stableCount: _stableFrameCount),
            ),

          // Progress dots (stability indicator)
          if (_isInitialized && _status.index >= ScannerStatus.cnicAligned.index)
            Positioned(
              top: centerY + overlayHeight / 2 + 20,
              left: 0,
              right: 0,
              child: _ProgressDots(
                current: _stableFrameCount,
                total: _requiredStableFrames,
              ),
            ),

          // Instructions
          if (_isInitialized)
            Positioned(
              bottom: 130,
              left: 24,
              right: 24,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _status.instruction,
                  key: ValueKey(_status.instruction),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
              tooltip: 'Close ID scanner',
            ),
          ),

          // Manual capture button
          if (_isInitialized)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Semantics(
                  button: true,
                  label: 'Capture ID card photo',
                  child: GestureDetector(
                    onTap: _captureImage,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _status.color, width: 4),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _status.index >= ScannerStatus.cnicAligned.index
                              ? _status.color
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Status indicator widget with icon and text
class _StatusIndicator extends StatelessWidget {
  final ScannerStatus status;
  final int stableCount;

  const _StatusIndicator({required this.status, required this.stableCount});

  @override
  Widget build(BuildContext context) {
    String displayText = status.statusText;
    if (status == ScannerStatus.stabilizing) {
      displayText = 'Verifying... ($stableCount/3)';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.2),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey(displayText),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: status.color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: status.color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(status.icon, color: status.color, size: 20),
            const SizedBox(width: 8),
            Text(
              displayText,
              style: TextStyle(
                color: status.color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress dots showing stability count
class _ProgressDots extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final isActive = index < current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: isActive ? Colors.green : Colors.white30,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}

/// Corner bracket painter for visual feedback
class _CornerBracketPainter extends CustomPainter {
  final Color color;
  final double progress;
  final double width;
  final double height;

  _CornerBracketPainter({
    required this.color,
    required this.progress,
    required this.width,
    required this.height,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final bracketLength = 30.0 * progress;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final left = centerX - width / 2;
    final top = centerY - height / 2;
    final right = centerX + width / 2;
    final bottom = centerY + height / 2;

    // Top-left corner
    canvas.drawLine(Offset(left, top + bracketLength), Offset(left, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left + bracketLength, top), paint);

    // Top-right corner
    canvas.drawLine(Offset(right - bracketLength, top), Offset(right, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + bracketLength), paint);

    // Bottom-left corner
    canvas.drawLine(Offset(left, bottom - bracketLength), Offset(left, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left + bracketLength, bottom), paint);

    // Bottom-right corner
    canvas.drawLine(Offset(right - bracketLength, bottom), Offset(right, bottom), paint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - bracketLength), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) {
    return color != oldDelegate.color || progress != oldDelegate.progress;
  }
}

/// Overlay painter with cutout
class _OverlayPainter extends CustomPainter {
  final double overlayWidth;
  final double overlayHeight;

  _OverlayPainter({required this.overlayWidth, required this.overlayHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.6);

    final cutoutRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: overlayWidth,
        height: overlayHeight,
      ),
      const Radius.circular(12),
    );

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(cutoutRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) {
    return overlayWidth != oldDelegate.overlayWidth || overlayHeight != oldDelegate.overlayHeight;
  }
}
