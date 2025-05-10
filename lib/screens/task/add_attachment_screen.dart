import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:zediatask/providers/providers.dart';
import 'package:zediatask/utils/app_theme.dart';

class AddAttachmentScreen extends ConsumerStatefulWidget {
  final String taskId;

  const AddAttachmentScreen({
    super.key,
    required this.taskId,
  });

  @override
  ConsumerState<AddAttachmentScreen> createState() => _AddAttachmentScreenState();
}

class _AddAttachmentScreenState extends ConsumerState<AddAttachmentScreen> {
  final TextEditingController _fileNameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedFile;
  bool _isLoading = false;
  String? _errorMessage;
  String? _fileExtension;

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  void _showPhotoOptions() {
    print("Opening photo options sheet");
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Add Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.camera_alt, color: Colors.white),
              ),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.photo_library, color: Colors.white),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      print('Opening image picker with source: ${source.name}');
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedImage != null) {
        final File imageFile = File(pickedImage.path);
        final String originalFileName = path.basename(pickedImage.path);

        setState(() {
          _selectedFile = imageFile;
          _fileNameController.text = _getFileNameWithoutExtension(originalFileName);
          _fileExtension = path.extension(originalFileName).toLowerCase();
        });

        print('Image selected: ${pickedImage.path}');
        print('File name: ${_fileNameController.text}');
        print('File extension: $_fileExtension');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking image: $e';
      });
      print('Error picking image: $e');
    }
  }

  String _getFileNameWithoutExtension(String fileName) {
    final extension = path.extension(fileName);
    return fileName.replaceAll(extension, '');
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) {
      setState(() {
        _errorMessage = 'Please select a photo first';
      });
      return;
    }

    if (_fileNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a name for this photo';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      final String fileName = '${_fileNameController.text}${_fileExtension ?? '.jpg'}';
      
      // Upload the actual file to storage
      print('Starting upload: file=${_selectedFile!.path}, fileName=$fileName');
      print('File exists: ${await _selectedFile!.exists()}, file size: ${await _selectedFile!.length()} bytes');
      
      final fileUrl = await supabaseService.uploadFile(
        filePath: _selectedFile!.path,
        fileName: fileName,
      );
      
      print('File uploaded successfully to: $fileUrl');
      
      // Create attachment record with file URL
      await supabaseService.addAttachment(
        taskId: widget.taskId,
        fileUrl: fileUrl,
        fileName: fileName,
      );
      
      print('Attachment record created for task: ${widget.taskId}');
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo uploaded successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        
        // Refresh attachments list
        ref.refresh(taskAttachmentsProvider(widget.taskId));
        
        // Close screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error uploading photo: $e';
      });
      print('Error in upload process: $e');
      
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if we have a file to display
    final bool hasFile = _selectedFile != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(hasFile ? 'Edit Photo' : 'Add Photo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.errorColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: AppTheme.errorColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Image preview
            if (hasFile) ...[
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    _selectedFile!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // File name input
              TextField(
                controller: _fileNameController,
                decoration: InputDecoration(
                  labelText: 'Photo name',
                  hintText: 'Enter a name for this photo',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixText: _fileExtension ?? '.jpg',
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // File picker button
            if (!hasFile)
              Column(
                children: [
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    child: InkWell(
                      onTap: _showPhotoOptions,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 64,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Select a photo to upload',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to browse',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            
            const Spacer(),
            
            // Upload button
            if (hasFile)
              ElevatedButton(
                onPressed: _isLoading ? null : _uploadFile,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Upload Photo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
} 