import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class DocumentUploadingScreen extends StatefulWidget {
  final List<String> documents;

  const DocumentUploadingScreen({
    super.key,
    required this.documents,
  });

  @override
  State<DocumentUploadingScreen> createState() =>
      _DocumentUploadingScreenState();
}

class _DocumentUploadingScreenState extends State<DocumentUploadingScreen> {
  late List<String> _uploadStatus;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _uploadStatus = List.filled(widget.documents.length, 'pending');
  }

  void updateProgress(int index, String status) {
    if (mounted) {
      setState(() {
        if (index < _uploadStatus.length) {
          _uploadStatus[index] = status;
          if (status == 'completed') {
            _currentIndex = index + 1;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: AppColors.appGradientEnd,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: AppColors.greenLight,
                strokeWidth: 3,
              ),
              const SizedBox(height: 30),
              const Text(
                'Uploading Documents',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Please wait while your documents are being uploaded',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: List.generate(
                    widget.documents.length,
                    (index) => Padding(
                      padding: EdgeInsets.only(
                        bottom: index < widget.documents.length - 1 ? 12 : 0,
                      ),
                      child: Row(
                        children: [
                          if (_uploadStatus[index] == 'completed')
                            const Icon(Icons.check_circle,
                                color: AppColors.greenLight, size: 24)
                          else if (_uploadStatus[index] == 'uploading')
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.greenLight),
                              ),
                            )
                          else
                            const Icon(Icons.schedule,
                                color: Colors.grey, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.documents[index],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _uploadStatus[index] == 'completed'
                                    ? AppColors.greenLight
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            _uploadStatus[index] == 'completed'
                                ? 'Done'
                                : (_uploadStatus[index] == 'uploading'
                                    ? 'Uploading...'
                                    : 'Pending'),
                            style: TextStyle(
                              fontSize: 12,
                              color: _uploadStatus[index] == 'completed'
                                  ? AppColors.greenLight
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                '${_currentIndex}/${widget.documents.length} documents uploaded',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
