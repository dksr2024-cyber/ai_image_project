import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:typed_data';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Image Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ImageProcessorScreen(),
    );
  }
}

class ImageProcessorScreen extends StatefulWidget {
  const ImageProcessorScreen({super.key});

  @override
  State<ImageProcessorScreen> createState() => _ImageProcessorScreenState();
}

class _ImageProcessorScreenState extends State<ImageProcessorScreen> {
  File? _originalImage;
  Uint8List? _processedImageBytes; // សម្រាប់ផ្ទុករូបភាពដែល AI ធ្វើរួច
  bool _isLoading = false;
  String _statusMessage = 'សូមជ្រើសរើសរូបភាពដើម្បីចាប់ផ្តើម';

  // មុខងារជ្រើសរើសរូបភាពពីទូរស័ព្ទ
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _originalImage = File(pickedFile.path);
        _processedImageBytes = null; // លុបរូបចាស់ចេញពេលរើសរូបថ្មី
        _statusMessage = 'បានជ្រើសរើសរូបភាពរួចរាល់';
      });
    }
  }

  // មុខងារបញ្ជូនរូបភាពទៅកាន់ Render Backend
  Future<void> _processImage(String action) async {
    if (_originalImage == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'កំពុងបញ្ជូនទៅកាន់ AI... សូមរង់ចាំបន្តិច!';
    });

    try {
      // ទីនេះគឺជា Link API របស់អ្នកនៅលើ Render
      var uri = Uri.parse('https://ai-image-project-86xd.onrender.com/process/');
      var request = http.MultipartRequest('POST', uri);

      // កំណត់ Token សម្ងាត់ (ជាបណ្តោះអាសន្នសិន មុននឹងយើងភ្ជាប់ Firebase ពិតប្រាកដ)
      // កំណត់សម្គាល់៖ អ្នកត្រូវតែមាន Token នេះទើប Backend ឲ្យឆ្លងកាត់
      String mockFirebaseToken = "YOUR_FIREBASE_ID_TOKEN_HERE"; 
      request.headers['Authorization'] = 'Bearer $mockFirebaseToken';

      // បញ្ចូលទិន្នន័យ
      request.fields['action'] = action; 
      request.files.add(await http.MultipartFile.fromPath('file', _originalImage!.path));

      // ផ្ញើសំណើទៅកាន់ Server
      var response = await request.send();

      if (response.statusCode == 200) {
        // ប្រសិនបើជោគជ័យ ទាញយករូបភាពដែលកែរួចមកបង្ហាញ
        var bytes = await response.stream.toBytes();
        setState(() {
          _processedImageBytes = bytes;
          _statusMessage = 'ជោគជ័យ! នេះជាលទ្ធផលរបស់អ្នក។';
        });
      } else if (response.statusCode == 401) {
        setState(() => _statusMessage = 'បរាជ័យ៖ គ្មានសិទ្ធិអនុញ្ញាត (Token ខុស ឬផុតកំណត់)');
      } else if (response.statusCode == 402) {
        setState(() => _statusMessage = 'បរាជ័យ៖ អ្នកមិនមាន Credit គ្រប់គ្រាន់ទេ!');
      } else {
        setState(() => _statusMessage = 'មានបញ្ហាពី Server: លេខកូដ ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _statusMessage = 'មានកំហុសបណ្តាញតភ្ជាប់: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Image Enhancer 4K', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // កន្លែងបង្ហាញរូបភាព
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]
              ),
              child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : _processedImageBytes != null
                      ? Image.memory(_processedImageBytes!, fit: BoxFit.contain)
                      : _originalImage != null
                          ? Image.file(_originalImage!, fit: BoxFit.contain)
                          : const Icon(Icons.add_photo_alternate, size: 80, color: Colors.grey),
            ),
            
            const SizedBox(height: 20),
            
            // សារបញ្ជាក់ស្ថានភាព
            Text(
              _statusMessage, 
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold, 
                color: _statusMessage.contains('ជោគជ័យ') ? Colors.green : Colors.blueGrey
              )
            ),
            
            const SizedBox(height: 30),

            // ប៊ូតុងបញ្ជា
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickImage,
              icon: const Icon(Icons.image_search),
              label: const Text('ជ្រើសរើសរូបភាពពីទូរស័ព្ទ'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _processImage('bg_remove'),
                    icon: const Icon(Icons.layers_clear, color: Colors.white),
                    label: const Text('កាត់ Background', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15), 
                      backgroundColor: Colors.blueAccent
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _processImage('upscale_4k'),
                    icon: const Icon(Icons.high_quality, color: Colors.white),
                    label: const Text('បម្លែងច្បាស់ 4K', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15), 
                      backgroundColor: Colors.orangeAccent
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}