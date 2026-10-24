import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/player_avatar.dart';
import 'level_select_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _adjectives = [
    'Brainy',
    'Clever',
    'Swift',
    'Cosmic',
    'Mighty',
    'Sneaky',
    'Lucky',
    'Sharp',
    'Bright',
    'Wild',
    'Turbo',
    'Magic',
  ];

  static const _nouns = [
    'Fox',
    'Owl',
    'Panda',
    'Wizard',
    'Ninja',
    'Tiger',
    'Falcon',
    'Robot',
    'Dragon',
    'Genius',
    'Comet',
    'Otter',
  ];

  final _nameController = TextEditingController();
  final _random = Random();

  int _avatarIndex = 0;
  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController.text = _randomName();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Load the local profile first so the screen works without internet.
  // If Firebase is available, refresh the local copy from the cloud.
  Future<void> _loadExistingProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localUsername = prefs.getString('player_username');
      final localAvatar = prefs.getInt('player_avatar');

      if (mounted) {
        setState(() {
          if (localUsername != null &&
              localUsername.trim().isNotEmpty) {
            _nameController.text = localUsername.trim();
          }

          if (localAvatar != null) {
            _avatarIndex =
                localAvatar.clamp(0, kAvatarCount - 1);
          }
        });
      }
    } catch (e) {
      debugPrint('Could not load local profile: $e');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 4));

      final data = doc.data();
      if (data == null || !mounted) return;

      final username = data['username'];
      final avatar = data['avatar'];

      final prefs = await SharedPreferences.getInstance();

      if (username is String && username.trim().isNotEmpty) {
        await prefs.setString(
          'player_username',
          username.trim(),
        );
      }

      if (avatar is int) {
        await prefs.setInt(
          'player_avatar',
          avatar.clamp(0, kAvatarCount - 1),
        );
      }

      if (!mounted) return;

      setState(() {
        if (username is String && username.trim().isNotEmpty) {
          _nameController.text = username.trim();
        }

        if (avatar is int) {
          _avatarIndex =
              avatar.clamp(0, kAvatarCount - 1);
        }
      });
    } catch (e) {
      debugPrint('Could not refresh profile from Firebase: $e');
    }
  }

  String _randomName() {
    final adjective =
        _adjectives[_random.nextInt(_adjectives.length)];
    final noun = _nouns[_random.nextInt(_nouns.length)];

    return '$adjective$noun${_random.nextInt(100)}';
  }

  void _generateRandomName() {
    setState(() {
      _nameController.text = _randomName();
      _errorText = null;
    });
  }

  bool get _isNameValid => RegExp(
        r'^[a-zA-Z0-9_]{3,20}$',
      ).hasMatch(_nameController.text.trim());

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF4A0E4E),
      ),
    );
  }

  // AVATAR PICKER
  Future<void> _pickAvatar() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBFF),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'CHOOSE YOUR AVATAR',
                  style: TextStyle(
                    color: Color(0xFF4A0E4E),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 18),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: kAvatarCount,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                  ),
                  itemBuilder: (context, index) {
                    final selected = index == _avatarIndex;

                    return GestureDetector(
                      onTap: () =>
                          Navigator.pop(sheetContext, index),
                      child: AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? const Color(0xFFFFD700)
                                : Colors.purple.shade100,
                            width: selected ? 3.5 : 2,
                          ),
                          boxShadow: selected
                              ? const [
                                  BoxShadow(
                                    color: Color(0x66FF8008),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: LayoutBuilder(
                          builder: (context, c) => PlayerAvatar(
                            index: index,
                            size: c.maxWidth,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _avatarIndex = picked);
    }
  }

  // SAVE PROFILE AND CONTINUE
  // Save locally first, then sync to Firebase when possible.
  // A Firebase/network failure must not block offline gameplay.
  Future<void> _createPlayer() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    final username = _nameController.text.trim();

    if (!_isNameValid) {
      setState(() {
        _errorText =
            'Use 3–20 letters, numbers, or underscores.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    var savedToCloud = false;

    try {
      // Save locally first. This works without internet.
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('player_username', username);
      await prefs.setInt('player_avatar', _avatarIndex);

      // Best-effort cloud save.
      // First-time anonymous sign-in requires internet.
      try {
        var user = FirebaseAuth.instance.currentUser;

        if (user == null) {
          final credential = await FirebaseAuth.instance
              .signInAnonymously()
              .timeout(const Duration(seconds: 5));

          user = credential.user;
        }

        if (user != null) {
          try {
            await user
                .updateDisplayName(username)
                .timeout(const Duration(seconds: 4));
          } catch (e) {
            debugPrint(
              'Could not update Firebase display name: $e',
            );
          }

          final doc = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid);

          await doc.set({
            'uid': user.uid,
            'username': username,
            'displayName': username,
            'avatar': _avatarIndex,
            'provider': 'anonymous',
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).timeout(
            const Duration(seconds: 5),
          );

          savedToCloud = true;
        }
      } catch (e) {
        // Keep going: the local profile has already been saved.
        debugPrint('Firebase sync deferred until online: $e');
      }

      if (!mounted) return;

      _showMessage(
        savedToCloud
            ? 'Profile saved to Firebase!'
            : 'Profile saved on this device. Cloud sync needs internet.',
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LevelSelectScreen(),
        ),
      );
    } catch (e) {
      debugPrint('Could not save local player profile: $e');

      _showMessage(
        'Could not save your profile on this device. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF4A0E4E),
              Color(0xFF811252),
              Color(0xFF2E0854),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // TITLE BADGE
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFFFFD700),
                          width: 2,
                        ),
                      ),
                      child: const Text(
                        'NEW PLAYER',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // CARD
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBFF),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 25,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Create your profile',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF4A0E4E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const SizedBox(height: 24),

                          // AVATAR WITH EDIT BADGE
                          Center(
                            child: GestureDetector(
                              onTap: _isLoading ? null : _pickAvatar,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      border: Border.all(
                                        color: const Color(0xFFFFD700),
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF8008)
                                              .withOpacity(0.5),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                        const BoxShadow(
                                          color: Colors.black26,
                                          offset: Offset(0, 6),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: PlayerAvatar(
                                      index: _avatarIndex,
                                      size: 110,
                                    ),
                                  ),
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF4081),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0xFF990033),
                                            offset: Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.edit_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),
                          Text(
                            'Tap to change avatar',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),

                          const SizedBox(height: 22),

                          // USERNAME FIELD
                          TextField(
                            controller: _nameController,
                            maxLength: 20,
                            enabled: !_isLoading,
                            textCapitalization:
                                TextCapitalization.none,
                            onChanged: (_) {
                              setState(() => _errorText = null);
                            },
                            onSubmitted: (_) => _createPlayer(),
                            decoration: InputDecoration(
                              labelText: 'Player name',
                              hintText: 'e.g. BrainMaster',
                              errorText: _errorText,
                              counterText: '',
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: Color(0xFF811252),
                              ),
                              suffixIcon: _isNameValid
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF2E9E5B),
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white,
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.purple.shade100,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF811252),
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Colors.redAccent,
                                  width: 1.5,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Colors.redAccent,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 4),

                          // RANDOM BUTTON
                          _GameButton(
                            text: 'RANDOM NAME',
                            icon: Icons.casino_rounded,
                            buttonColor: const Color(0xFF00A6FF),
                            shadowColor: const Color(0xFF0052B4),
                            textColor: Colors.white,
                            height: 50,
                            fontSize: 15,
                            onPressed: _isLoading
                                ? null
                                : _generateRandomName,
                          ),

                          const SizedBox(height: 22),

                          // CREATE BUTTON
                          _GameButton(
                            text: _isLoading
                                ? 'SAVING...'
                                : 'LET\'S PLAY!',
                            icon: Icons.play_arrow_rounded,
                            buttonColor: const Color(0xFF38EF7D),
                            shadowColor: const Color(0xFF0C6B63),
                            textColor: const Color(0xFF003816),
                            height: 58,
                            fontSize: 19,
                            loading: _isLoading,
                            onPressed:
                                _isLoading ? null : _createPlayer,
                          ),

                          const SizedBox(height: 10),

                          TextButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back'),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  const Color(0xFF811252),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Same 3D press-down button style used on your home screen.
class _GameButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final Color buttonColor;
  final Color shadowColor;
  final Color textColor;
  final double height;
  final double fontSize;
  final bool loading;
  final VoidCallback? onPressed;

  const _GameButton({
    required this.text,
    required this.icon,
    required this.buttonColor,
    required this.shadowColor,
    required this.textColor,
    required this.height,
    required this.fontSize,
    required this.onPressed,
    this.loading = false,
  });

  @override
  State<_GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<_GameButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return Opacity(
      opacity: enabled || widget.loading ? 1 : 0.6,
      child: GestureDetector(
        onTapDown: enabled
            ? (_) => setState(() => _isPressed = true)
            : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _isPressed = false);
                widget.onPressed!();
              }
            : null,
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: widget.height,
          margin: const EdgeInsets.only(top: 6, bottom: 8),
          transform: Matrix4.translationValues(
            0,
            _isPressed ? 5 : 0,
            0,
          ),
          decoration: BoxDecoration(
            color: widget.buttonColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.8),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.shadowColor,
                offset: Offset(0, _isPressed ? 1 : 6),
                blurRadius: 0,
              ),
              const BoxShadow(
                color: Colors.black26,
                offset: Offset(0, 8),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.loading)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: widget.textColor,
                  ),
                )
              else
                Icon(
                  widget.icon,
                  color: widget.textColor,
                  size: 26,
                ),
              const SizedBox(width: 8),
              Text(
                widget.text,
                style: TextStyle(
                  color: widget.textColor,
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}