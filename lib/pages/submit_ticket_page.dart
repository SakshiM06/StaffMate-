import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AppColors {
  static const Color primaryDarkBlue = Color(0xFF1A2C42);
  static const Color midDarkBlue = Color(0xFF273F5A);
  static const Color accentTeal = Color(0xFF00C897);
  static const Color darkerAccentTeal = Color(0xFF00A37D);
  static const Color lightBlue = Color(0xFF66D7EE);
  static const Color whiteColor = Colors.white;
  static const Color textDark = primaryDarkBlue;
  static const Color textBodyColor = Color(0xFF90A4AE);
  static const Color lightGreyColor = Color(0xFFF0F4F8);
  static const Color fieldFillColor = Color(0xFFE3E8ED);
  static const Color errorRed = Color(0xFFE53935);
  static const Color warningOrange = Color(0xFFFFA726);
}

class SubmitTicketPage extends StatefulWidget {
  const SubmitTicketPage({super.key});

  @override
  State<SubmitTicketPage> createState() => _SubmitTicketPageState();
}

class _SubmitTicketPageState extends State<SubmitTicketPage> {
  // --- STATE MANAGEMENT ---
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String _selectedCategory = 'IT Issue';
  String _selectedPriority = 'Medium';
  String _selectedLanguage = 'English';
  File? _selectedImage;

  final List<String> _categories = ['IT Issue', 'System Issue', 'Billing Error', 'Other'];
  final List<String> _priorities = ['Low', 'Medium', 'High'];
  final List<String> _languages = ['English', 'Hindi', 'Marathi'];

  late stt.SpeechToText _speech;
  bool _isListening = false;

  // --- LIFECYCLE & CORE METHODS ---
  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.photos.request();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() => _descController.text = val.recognizedWords),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _submitTicket() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ticket submitted successfully!"),
          backgroundColor: AppColors.accentTeal,
        ),
      );
      _titleController.clear();
      _descController.clear();
      setState(() {
        _selectedCategory = 'IT Issue';
        _selectedPriority = 'Medium';
        _selectedLanguage = 'English';
        _selectedImage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGreyColor,
      appBar: AppBar(
        title: Text(
          "Submit a Ticket",
          style: GoogleFonts.poppins(
            color: AppColors.primaryDarkBlue,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              _buildTextField(
                controller: _titleController,
                label: 'Ticket Title',
                icon: Icons.title_rounded,
              ),
              const SizedBox(height: 20),
              _buildDropdown(
                value: _selectedCategory,
                items: _categories,
                onChanged: (val) => setState(() => _selectedCategory = val!),
                icon: Icons.category_rounded,
              ),
              const SizedBox(height: 20),
              _buildDropdown(
                value: _selectedPriority,
                items: _priorities,
                onChanged: (val) => setState(() => _selectedPriority = val!),
                icon: Icons.priority_high_rounded,
              ),
              const SizedBox(height: 20),
              _buildDropdown(
                value: _selectedLanguage,
                items: _languages,
                onChanged: (val) => setState(() => _selectedLanguage = val!),
                icon: Icons.language_rounded,
              ),
              const SizedBox(height: 20),
              _buildDescriptionField(),
              const SizedBox(height: 20),
              _buildAttachmentSection(),
              const SizedBox(height: 30),
              _buildSubmitButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: GoogleFonts.poppins(color: AppColors.textBodyColor),
          prefixIcon: Icon(icon, color: AppColors.accentTeal),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
        validator: (value) => value!.isEmpty ? 'Please enter a $label' : null,
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.accentTeal, size: 30),
          dropdownColor: AppColors.whiteColor,
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.w500),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextFormField(
        controller: _descController,
        maxLines: 5,
        style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Description',
          hintStyle: GoogleFonts.poppins(color: AppColors.textBodyColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          suffixIcon: IconButton(
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? AppColors.errorRed : AppColors.accentTeal,
            ),
            onPressed: _listen,
          ),
        ),
        validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
      ),
    );
  }

  Widget _buildAttachmentSection() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.fieldFillColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _selectedImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(_selectedImage!, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_outlined, color: AppColors.accentTeal, size: 50),
                  const SizedBox(height: 12),
                  Text(
                    "Add Screenshot",
                    style: GoogleFonts.poppins(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accentTeal, AppColors.darkerAccentTeal],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentTeal.withValues(alpha: .4),
            offset: const Offset(0, 10),
            blurRadius: 20,
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _submitTicket,
        icon: const Icon(Icons.send_rounded, color: AppColors.whiteColor),
        label: Text(
          "Submit Ticket",
          style: GoogleFonts.poppins(color: AppColors.whiteColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, // Make button transparent to show gradient
          shadowColor: Colors.transparent, // No shadow from the button itself
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}