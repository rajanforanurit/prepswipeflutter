// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepswipe/models/room_model.dart';
import 'package:prepswipe/services/api_service.dart';
import 'package:prepswipe/utils/app_theme.dart';
import 'package:prepswipe/widgets/ps_card.dart';
import 'create_room_screen.dart';
import 'quiz_room_screen.dart';
import 'leaderboard_screen.dart';

class CommunityLobbyScreen extends StatefulWidget {
  const CommunityLobbyScreen({
    super.key,
  });

  @override
  State<CommunityLobbyScreen> createState() => _CommunityLobbyScreenState();
}

class _CommunityLobbyScreenState extends State<CommunityLobbyScreen>
    with SingleTickerProviderStateMixin {
  final ApiService apiService = ApiService();
  late Future<List<Room>> _publicRoomsFuture;
  late Future<List<Room>> _myRoomsFuture;
  late Future<List<Room>> _historyRoomsFuture;
  late TabController _tabController;
  Timer? _refreshTimer;

  final _roomIdController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshAllLobbies();

    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_tabController.index == 0) {
        _refreshAllLobbies();
        ();
      }
    });
  }

  Future<void> _refreshAll() async {
    await Future.wait([_refreshAllLobbies()]);
  }

  Future<void> _refreshAllLobbies() async {
    setState(() {
      _publicRoomsFuture = apiService.getActiveRooms();
      _myRoomsFuture = apiService.getCreatedRooms();
      _historyRoomsFuture = apiService.getRoomHistory();
    });
  }

  // Handle routing logic based on user completion status
  void _onRoomSelected(Room room) {
    // Check if current user has already completed this room quiz
    final selfParticipant = room.participants.firstWhere(
      (p) => p.userId == FirebaseAuth.instance.currentUser!.uid,
      orElse: () => RoomParticipant(
        userId: '',
        userID: '',
        name: '',
        score: 0,
        timeTakenSeconds: 0,
        status: 'joined',
      ),
    );

    if (selfParticipant.status == 'completed' || room.status != 'active') {
      // Directly navigate to leaderboard screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LeaderboardScreen(
            roomId: room.roomId,
            initialLeaderboard: room.participants,
          ),
        ),
      ).then((_) => _refreshAllLobbies());
    } else {
      // Prompt join/start quiz room sequence
      _joinRoomAction(room.roomId);
    }
  }

  void _joinRoomAction(String roomId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final result = await apiService.joinRoom(
        roomId: roomId,
        password: _passwordController.text.isNotEmpty
            ? _passwordController.text
            : null,
      );

      Navigator.pop(context); // Dismiss progress loader
      _roomIdController.clear();
      _passwordController.clear();

      final room = result['room'] as Room;
      final questions = result['questions'] as List<RoomQuestion>;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizRoomScreen(
            room: room,
            questions: questions,
          ),
        ),
      ).then((_) => _refreshAllLobbies());
    } catch (e) {
      Navigator.pop(context); // Dismiss progress loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining: ${e.toString()}')),
      );
    }
  }

  void _showJoinDialog() {
    showDialog(
      context: context,
      builder: (context) {
        bool isPrivate = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'Join Custom Room',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _roomIdController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Room Code (e.g., AB3D9F)',
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
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        activeColor: AppColors.primary,
                        value: isPrivate,
                        onChanged: (val) {
                          setDialogState(() {
                            isPrivate = val ?? false;
                          });
                        },
                      ),
                      const Text(
                        'Is Private Room?',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  if (isPrivate) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Passcode',
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
                      ),
                      obscureText: true,
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _joinRoomAction(_roomIdController.text.trim());
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Join', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _copyRoomId(String roomId) {
    Clipboard.setData(ClipboardData(text: roomId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Room Code $roomId copied to clipboard!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _confirmDeleteRoom(String roomId) async {
    bool confirmdismiss = false;

    showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "Dismiss",
        barrierColor: Colors.black.withOpacity(0.5), // Smoothly dims background
        transitionDuration: const Duration(milliseconds: 200), // Pop speed
        pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
        transitionBuilder: (context, anim1, anim2, child) {
          // 1. Apply a smooth curve to the animation value
          final curve = Curves.bounceInOut.transform(anim1.value);
          return Transform.scale(
            scale: curve,
            child: Opacity(
              opacity: anim1.value,
              child: AlertDialog(
                title: const Text('Delete Room'),
                content: const Text(
                    'Are you sure you want to delete this room? This action cannot be undone.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      confirmdismiss = false;
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      confirmdismiss = true;
                      Navigator.pop(context);
                      _deleteRoomAction(roomId);
                    },
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          );
        });
    return confirmdismiss;
  }

  void _deleteRoomAction(String roomId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await apiService.deleteRoom(roomId);

      Navigator.pop(context); // Dismiss progress loader
      _refreshAllLobbies();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room deleted successfully')),
      );
    } catch (e) {
      Navigator.pop(context); // Dismiss progress loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete room: ${e.toString()}')),
      );
    }
  }

  Widget _buildRoomList(
      Future<List<Room>> futureLoader, String emptyMessage, String type) {
    return FutureBuilder<List<Room>>(
      future: futureLoader,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
              child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(emptyMessage, textAlign: TextAlign.center),
          ));
        }

        final rooms = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView.builder(
            itemCount: rooms.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final r = rooms[index];

              return _buildRoomCard(r, type);
              // Card(
              //   child: ListTile(
              //     title: Text(r.title,
              //         style: const TextStyle(fontWeight: FontWeight.bold)),
              //     subtitle: Text(
              //         '${r.subject ?? "General"} • ${r.questions.length} Qs • ${r.participants.length} Players'),
              //     trailing: Row(
              //       mainAxisSize: MainAxisSize.min,
              //       children: [
              //         if (hasCompleted)
              //           const Chip(
              //             label: Text('Completed',
              //                 style:
              //                     TextStyle(fontSize: 10, color: Colors.green)),
              //             backgroundColor: Colors.transparent,
              //             side: BorderSide(color: Colors.green),
              //           ),
              //         if (isHost)
              //           IconButton(
              //             icon:
              //                 const Icon(Icons.delete_outline, color: Colors.red),
              //             tooltip: 'Delete Room',
              //             onPressed: () => _confirmDeleteRoom(r.roomId),
              //           ),
              //         const SizedBox(width: 4),
              //         const Icon(Icons.arrow_forward_ios, size: 16),
              //       ],
              //     ),
              //     onTap: () => _onRoomSelected(r),
              //   ),
              // );
            },
          ),
        );
      },
    );
  }

  Future<bool> _showEditRoomDialog(Room room) async {
    final titleController = TextEditingController(text: room.title);
    final marksController = TextEditingController(text: room.marks.toString());
    final negativeMarksController =
        TextEditingController(text: room.negativeMarks.toString());
    final List<int> playerOptions = [2, 4, 8, 10, 15, 20, 25, 30];
    int selectedMaxParticipants =
        playerOptions.contains(room.maxParticipants) ? room.maxParticipants : 4;
    String selectedStatus = room.status;

    showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "Dismiss",
        barrierColor: Colors.black.withOpacity(0.5), // Smoothly dims background
        transitionDuration: const Duration(milliseconds: 200), // Pop speed
        pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
        transitionBuilder: (context, anim1, anim2, child) {
          // 1. Apply a smooth curve to the animation value
          final curve = Curves.bounceInOut.transform(anim1.value);
          return Transform.scale(
            scale: curve,
            child: Opacity(
                opacity: anim1.value,
                child: AlertDialog(
                  title: const Text('Edit Room Details'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            labelText: 'Contest Title',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: selectedStatus,
                          decoration: InputDecoration(
                            labelText: 'Room Status',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15)),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'active', child: Text('Active')),
                            DropdownMenuItem(
                                value: 'completed', child: Text('Completed')),
                            DropdownMenuItem(
                                value: 'cancelled', child: Text('Cancelled')),
                          ],
                          onChanged: (val) {
                            if (val != null) selectedStatus = val;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: selectedMaxParticipants,
                          decoration: InputDecoration(
                            labelText: 'Maximum Players',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15)),
                          ),
                          items: playerOptions
                              .map((num) => DropdownMenuItem(
                                  value: num, child: Text('$num Players')))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) selectedMaxParticipants = val;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: marksController,
                                decoration: InputDecoration(
                                    labelText: 'Marks/Q',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(15))),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: negativeMarksController,
                                decoration: InputDecoration(
                                    labelText: 'Negative/Q',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(15))),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    SizedBox(
                      width: 120,
                      child: PSButton(
                        onTap: () {
                          Navigator.pop(context);
                          _editRoomAction(
                            roomId: room.roomId,
                            title: titleController.text.trim(),
                            status: selectedStatus,
                            maxParticipants: selectedMaxParticipants,
                            marks: double.tryParse(marksController.text),
                            negativeMarks:
                                double.tryParse(negativeMarksController.text),
                          );
                        },
                        label: 'Save Changes',
                      ),
                    ),
                  ],
                )),
          );
        });

    return false;
  }

  void _editRoomAction({
    required String roomId,
    required String title,
    required String status,
    int? maxParticipants,
    double? marks,
    double? negativeMarks,
  }) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await apiService.editRoom(
        roomId: roomId,
        title: title,
        status: status,
        maxParticipants: maxParticipants,
        marks: marks,
        negativeMarks: negativeMarks,
      );

      Navigator.pop(context); // Dismiss progress indicator
      _refreshAllLobbies();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room updated successfully')),
      );
    } catch (e) {
      Navigator.pop(context); // Dismiss progress indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update room: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRoomList(_publicRoomsFuture,
                    'No active public rooms available.', 'public'),
                _buildRoomList(_myRoomsFuture,
                    'You have not created any rooms yet.', 'myroom'),
                _buildRoomList(_historyRoomsFuture,
                    'No room participation history found.', 'history'),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              _LobbyActionButton(
                label: 'Join Room Code',
                icon: Icons.group_add_rounded,
                onTap: _showJoinDialog,
              ),
              const SizedBox(width: 12),
              _LobbyActionButton(
                label: 'Create Room',
                icon: Icons.add_rounded,
                isPrimary: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateRoomScreen(),
                    ),
                  ).then((_) => _refreshAllLobbies());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      //padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      constraints: const BoxConstraints.expand(height: 35.0),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        indicator: BoxDecoration(
          //color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
          border: BoxBorder.all(color: const Color.fromRGBO(124, 77, 255, 1)),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textTertiary,
        labelStyle: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Public'),
          Tab(text: 'My Rooms'),
          Tab(
            text: 'History',
          )
        ],
      ),
    );
  }

  Widget _buildRoomCard(Room room, String type) {
    final hasCompleted = room.participants.any(
      (p) =>
          p.userId == FirebaseAuth.instance.currentUser!.uid &&
          p.status == 'completed',
    );
    final isHost = room.hostId == FirebaseAuth.instance.currentUser!.uid;

    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _onRoomSelected(room),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Room ID & Copy & Status & Host Badge
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _copyRoomId(room.roomId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            room.roomId,
                            style: const TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF38BDF8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: Color(0xFF38BDF8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isHost)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'Host',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB388FF),
                        ),
                      ),
                    ),
                  const Spacer(),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: room.status == 'cancelled'
                          ? Colors.red.withValues(alpha: 0.1)
                          : room.status == 'completed'
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      room.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: room.status == 'cancelled'
                            ? Colors.redAccent
                            : room.status == 'completed'
                                ? Colors.greenAccent
                                : Colors.blueAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                room.title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // Middle Badges Row: Exam & Subject
              Row(
                children: [
                  if (room.examType != null && room.examType!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        room.examType!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF7DD3FC),
                        ),
                      ),
                    ),
                  if (room.subject != null && room.subject!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        room.subject!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFFDA4AF),
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (hasCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 12, color: Colors.greenAccent),
                          SizedBox(width: 4),
                          Text(
                            'Completed',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 12),

              // Bottom Stats Info Row: Qs, Players, Marks, Private
              Row(
                children: [
                  // Questions Count
                  _buildStatIcon(Icons.quiz_outlined, '${room.questions.length} Qs'),
                  const SizedBox(width: 14),

                  // Participants Count
                  _buildStatIcon(Icons.people_outline_rounded, '${room.participants.length}/${room.maxParticipants} Players'),
                  const SizedBox(width: 14),

                  // Marks per question
                  _buildStatIcon(
                    Icons.add_circle_outline_rounded,
                    '+${room.marks.toStringAsFixed(room.marks % 1 == 0 ? 0 : 1)}',
                    color: Colors.greenAccent,
                  ),
                  const SizedBox(width: 8),

                  // Negative marks
                  _buildStatIcon(
                    Icons.remove_circle_outline_rounded,
                    '-${room.negativeMarks.toStringAsFixed(room.negativeMarks % 1 == 0 ? 0 : 2)}',
                    color: Colors.redAccent,
                  ),
                  const Spacer(),

                  // Lock indicator for private rooms
                  Icon(
                    room.isPrivate ? Icons.lock_outline_rounded : Icons.public_rounded,
                    size: 15,
                    color: room.isPrivate ? Colors.amber : Colors.white24,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    room.isPrivate ? 'Private' : 'Public',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: room.isPrivate ? Colors.amber : Colors.white30,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return isHost && type == 'myroom'
        ? Dismissible(
            key: UniqueKey(),
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.cyan,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.edit, color: Colors.white),
            ),
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) {
              if (direction == DismissDirection.startToEnd) {
                return _showEditRoomDialog(room);
              } else {
                return _confirmDeleteRoom(room.roomId);
              }
            },
            child: cardContent,
          )
        : cardContent;
  }

  Widget _buildStatIcon(IconData icon, String label, {Color color = Colors.white54}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _LobbyActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _LobbyActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isPrimary
        ? const Color(0xFF7C4DFF).withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.03);
    final borderColor = isPrimary
        ? const Color(0xFF7C4DFF).withValues(alpha: 0.3)
        : Colors.white.withValues(alpha: 0.08);
    final textColor = isPrimary
        ? const Color(0xFFB388FF)
        : Colors.white70;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
