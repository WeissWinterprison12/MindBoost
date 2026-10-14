import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import 'level_select_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegistering = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _googleReady = false;

  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();
  }
  
  void _playAsGuest() {
    if (_isLoading) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LevelSelectScreen(),
      ),
    );
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      await GoogleSignIn.instance.initialize();

      if (mounted) {
        setState(() => _googleReady = true);
      }
    } catch (e) {
      debugPrint('Google Sign-In initialization failed: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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

  Future<void> _saveUserProfile(
    User user, {
    String? name,
    String? provider,
  }) async {
    final doc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    final existing = await doc.get();

    final enteredName = name?.trim();
    final profileName = enteredName != null && enteredName.isNotEmpty
        ? enteredName
        : user.displayName;

    final data = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName': profileName,
      'photoUrl': user.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (provider != null) {
      data['provider'] = provider;
    }

    // Preserve the original account creation timestamp.
    if (!existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await doc.set(data, SetOptions(merge: true));
  }

  Future<void> _finishSignIn(
    UserCredential credential, {
    String? name,
    String? provider,
  }) async {
    final user = credential.user;

    if (user == null) {
      throw Exception('Authentication returned no user.');
    }

    await _saveUserProfile(
      user,
      name: name,
      provider: provider,
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LevelSelectScreen(),
      ),
    );
  }

  Future<void> _emailAuthentication() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isRegistering) {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final name = _nameController.text.trim();

        if (name.isNotEmpty) {
          await credential.user?.updateDisplayName(name);
          await credential.user?.reload();
        }

        await _finishSignIn(
          credential,
          name: name,
          provider: 'password',
        );
      } else {
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        await _finishSignIn(
          credential,
          provider: 'password',
        );
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(_authErrorMessage(e.code));
    } catch (e) {
      _showMessage('Unable to sign in. Please try again.');
      debugPrint('Email authentication error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email already has an account. Try logging in.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase.';
      default:
        return 'Authentication failed: $code';
    }
  }

  Future<void> _googleSignIn() async {
    if (!_googleReady || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final googleUser =
          await GoogleSignIn.instance.authenticate();

      final googleAuth = googleUser.authentication;

      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception(
          'Google did not return an ID token. Check your Firebase configuration.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      await _finishSignIn(
        userCredential,
        provider: 'google',
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(_authErrorMessage(e.code));
    } catch (e) {
      _showMessage(
        'Google Sign-In failed. Check your configuration and try again.',
      );
      debugPrint('Google Sign-In error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _facebookSignIn() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final result = await FacebookAuth.instance.login();

      if (result.status == LoginStatus.cancelled) {
        return;
      }

      if (result.status != LoginStatus.success ||
          result.accessToken == null) {
        _showMessage(
          result.message ?? 'Facebook Sign-In was unsuccessful.',
        );
        return;
      }

      final credential = FacebookAuthProvider.credential(
        result.accessToken!.tokenString,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      await _finishSignIn(
        userCredential,
        provider: 'facebook',
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(_authErrorMessage(e.code));
    } catch (e) {
      _showMessage(
        'Facebook Sign-In failed. Check your Facebook configuration.',
      );
      debugPrint('Facebook Sign-In error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
            .hasMatch(email)) {
      _showMessage('Enter your email address first.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      _showMessage(
        'If an account exists for that email, a reset link will be sent.',
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(_authErrorMessage(e.code));
    } catch (e) {
      _showMessage('Could not send the reset email.');
      debugPrint('Password reset error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF811252)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.purple.shade100,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF811252),
          width: 2,
        ),
      ),
    );
  }

  Widget _socialButton({
    required String text,
    required Widget leading,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: _isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF351039),
          side: BorderSide(color: Colors.purple.shade100),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F1FA),
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
                child: Container(
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: Text(
                            '🧠',
                            style: TextStyle(fontSize: 58),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Welcome to MindBoost!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF4A0E4E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isRegistering
                              ? 'Create your player account'
                              : 'Sign in to continue your adventure',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.purple.shade700,
                          ),
                        ),
                        const SizedBox(height: 28),

                        if (_isRegistering) ...[
                          TextFormField(
                            controller: _nameController,
                            textCapitalization:
                                TextCapitalization.words,
                            decoration: _inputDecoration(
                              label: 'Player name',
                              icon: Icons.person_outline,
                            ),
                            validator: (value) {
                              if (_isRegistering &&
                                  (value == null ||
                                      value.trim().isEmpty)) {
                                return 'Enter your player name.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [
                            AutofillHints.email,
                          ],
                          decoration: _inputDecoration(
                            label: 'Email address',
                            icon: Icons.email_outlined,
                          ),
                          validator: (value) {
                            if (value == null ||
                                !RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                ).hasMatch(value.trim())) {
                              return 'Enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: _isRegistering
                              ? const [AutofillHints.newPassword]
                              : const [AutofillHints.password],
                          decoration: _inputDecoration(
                            label: 'Password',
                            icon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword =
                                      !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter your password.';
                            }

                            if (_isRegistering &&
                                value.length < 6) {
                              return 'Use at least 6 characters.';
                            }

                            return null;
                          },
                        ),

                        if (!_isRegistering)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed:
                                  _isLoading ? null : _resetPassword,
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                  color: Color(0xFF811252),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 8),

                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : _emailAuthentication,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF811252),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child:
                                        CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isRegistering
                                        ? 'CREATE ACCOUNT'
                                        : 'LOG IN',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _isRegistering =
                                        !_isRegistering;
                                  });
                                },
                          child: Text(
                            _isRegistering
                                ? 'Already have an account? Log in'
                                : 'New player? Create an account',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF811252),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.purple.shade100,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'OR CONTINUE WITH',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.purple.shade100,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        _socialButton(
                          text: 'Continue with Google',
                          leading: const Text(
                            'G',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF4285F4),
                            ),
                          ),
                          onPressed:
                              _googleReady ? _googleSignIn : null,
                        ),

                        const SizedBox(height: 12),

                        _socialButton(
                          text: 'Continue with Facebook',
                          leading: const Icon(
                            Icons.facebook,
                            color: Color(0xFF1877F2),
                            size: 28,
                          ),
                          onPressed: _facebookSignIn,
                        ),

                        const SizedBox(height: 20),

                        TextButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back to welcome screen'),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                const Color(0xFF811252),
                          ),
                        ),

                        if (_isLoading) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Connecting to MindBoost...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}