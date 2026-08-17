import 'package:flutter/material.dart';
import 'package:prepswipe/models/room_model.dart';
import 'package:prepswipe/screens/community/quiz_room_screen.dart';
import 'package:prepswipe/services/api_service.dart';
import 'package:prepswipe/utils/app_theme.dart';
import 'package:prepswipe/widgets/ps_card.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final ApiService apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String? _selectedExam;
  String? _selectedSubject;
  int _questionCount = 10;
  bool _isPrivate = false;
  String _password = '';

  // Set requested defaults
  int _maxParticipants = 4;
  double _marks = 1.0;
  double _negativeMarks = 0.0;

  // Placeholder subjects/exams matching app structure
  final List<String> _exams = ['UPSC', 'UPPCS', 'BPSC', 'SSC CGL', 'RRB NTPC'];
  final List<String> _subjects = [
    'History',
    'Geography',
    'Polity',
    'Current Affairs',
    'General Science'
  ];
  final List<int> _playerOptions = [2, 4, 8, 10, 15, 20, 25, 30];

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final result = await apiService.createRoom(
        title: _title,
        examType: _selectedExam,
        subject: _selectedSubject,
        questionCount: _questionCount,
        isPrivate: _isPrivate,
        password: _isPrivate ? _password : null,
        maxParticipants: _maxParticipants,
        marks: _marks,
        negativeMarks: _negativeMarks,
      );

      Navigator.pop(context); // Dismiss loader

      final createdRoom = result['room'] as Room;

      // Auto join room
      final joinResult = await apiService.joinRoom(
        roomId: createdRoom.roomId,
        password: _isPrivate ? _password : null,
      );

      final room = joinResult['room'] as Room;
      final questions = joinResult['questions'] as List<RoomQuestion>;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizRoomScreen(
            room: room,
            questions: questions,
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Dismiss loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create: ${e.toString()}')),
      );
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text(
          'Create Custom Room',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Heading
                    const Text(
                      'CONTEST DETAILS',
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white38,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    TextFormField(
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _inputDecoration('Contest Title'),
                      validator: (val) => val == null || val.isEmpty ? 'Please enter a title' : null,
                      onSaved: (val) => _title = val ?? '',
                    ),
                    const SizedBox(height: 16),

                    // Exam Target
                    DropdownButtonFormField<String>(
                      dropdownColor: AppColors.card,
                      value: _selectedExam,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _inputDecoration('Exam Target'),
                      items: _exams
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedExam = val),
                    ),
                    const SizedBox(height: 16),

                    // Quiz Subject
                    DropdownButtonFormField<String>(
                      dropdownColor: AppColors.card,
                      value: _selectedSubject,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _inputDecoration('Quiz Subject'),
                      items: _subjects
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedSubject = val),
                    ),
                    const SizedBox(height: 16),

                    // Question Count & Max Players Row
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            dropdownColor: AppColors.card,
                            value: _questionCount,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: _inputDecoration('Question Count'),
                            items: [5, 10, 15, 20, 30]
                                .map((c) => DropdownMenuItem(value: c, child: Text('$c Qs')))
                                .toList(),
                            onChanged: (val) => setState(() => _questionCount = val ?? 10),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            dropdownColor: AppColors.card,
                            value: _maxParticipants,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: _inputDecoration('Max Players'),
                            items: _playerOptions
                                .map((num) => DropdownMenuItem(value: num, child: Text('$num Players')))
                                .toList(),
                            onChanged: (val) => setState(() => _maxParticipants = val ?? 4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Marks & Negative Marks Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: '1.0',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: _inputDecoration('Marks per Question'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid' : null,
                            onSaved: (val) => _marks = double.parse(val!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: '0.0',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: _inputDecoration('Negative Marks'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid' : null,
                            onSaved: (val) => _negativeMarks = double.parse(val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Private room switch
                    SwitchListTile(
                      activeColor: AppColors.primary,
                      title: const Text(
                        'Private Room',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Require a passkey to enter',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      value: _isPrivate,
                      onChanged: (val) => setState(() => _isPrivate = val),
                    ),
                    if (_isPrivate) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDecoration('Enter Room Passkey'),
                        obscureText: true,
                        validator: (val) => _isPrivate && (val == null || val.isEmpty)
                            ? 'Passkey is required'
                            : null,
                        onSaved: (val) => _password = val ?? '',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Submit button
              PSButton(
                label: 'Create and Start',
                icon: Icons.play_arrow_rounded,
                onTap: _submitForm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
