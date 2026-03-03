import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/user_service.dart';

class ProfileSetupBottomSheet extends StatefulWidget {
  final String uid;
  final String email;

  const ProfileSetupBottomSheet({
    super.key,
    required this.uid,
    required this.email,
  });

  @override
  State<ProfileSetupBottomSheet> createState() => _ProfileSetupBottomSheetState();
}

class _ProfileSetupBottomSheetState extends State<ProfileSetupBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _userService = UserService();
  
  bool _isLoading = false;
  bool _isCheckingUsername = false;
  bool _isUsernameAvailable = false;
  String? _usernameError;
  Timer? _usernameCheckTimer;

  @override
  void initState() {
    super.initState();
    // Initialize username controller with @
    _usernameController.text = '@';
    _usernameController.selection = TextSelection.fromPosition(
      TextPosition(offset: _usernameController.text.length),
    );
    
    // Listen to username changes for availability checking
    _usernameController.addListener(_onUsernameChanged);
    
    // Try to load existing user data to pre-fill name
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await _userService.getUserDocument(widget.uid);
      final userData = userDoc.data() as Map<String, dynamic>?;
      final name = userData?['name'] as String? ?? '';
      
      if (name.isNotEmpty && mounted) {
        _nameController.text = name;
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _usernameCheckTimer?.cancel();
    super.dispose();
  }

  void _onUsernameChanged() {
    final text = _usernameController.text;
    
    // Ensure @ is always at the start
    if (!text.startsWith('@')) {
      _usernameController.value = TextEditingValue(
        text: '@${text.replaceAll('@', '')}',
        selection: TextSelection.collapsed(
          offset: _usernameController.text.length,
        ),
      );
      return;
    }

    // Cancel previous timer
    _usernameCheckTimer?.cancel();

    // Get username without @
    final usernameWithoutAt = text.substring(1);

    if (usernameWithoutAt.isEmpty) {
      setState(() {
        _isUsernameAvailable = false;
        _usernameError = null;
      });
      return;
    }

    // Validate username format (alphanumeric and underscore only)
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(usernameWithoutAt)) {
      setState(() {
        _isUsernameAvailable = false;
        _usernameError = 'Username can only contain letters, numbers, and underscores';
      });
      return;
    }

    // Debounce username checking (wait 500ms after user stops typing)
    _usernameCheckTimer = Timer(const Duration(milliseconds: 500), () {
      _checkUsernameAvailability(usernameWithoutAt);
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (username.isEmpty) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameError = null;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });

    try {
      final isAvailable = await _userService.isUsernameAvailable('@$username');
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = isAvailable;
          _usernameError = isAvailable 
              ? null 
              : 'This username is already taken';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = false;
          _usernameError = 'Unable to check username availability';
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isUsernameAvailable) {
      setState(() {
        _usernameError = 'Please choose an available username';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _userService.updateUserProfile(
        uid: widget.uid,
        name: _nameController.text.trim(),
        username: _usernameController.text,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final topPadding = mediaQuery.padding.top; // Includes dynamic island area
    
    // When keyboard is closed, use 48% of screen height
    // When keyboard is open, reduce height to fit content better
    final baseHeight = screenHeight * 0.48;
    final bottomSheetHeight = keyboardHeight > 0
        ? screenHeight - keyboardHeight - topPadding - 100 // Reduced space for more compact height
        : baseHeight;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      height: bottomSheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Let us get to know you',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  color: Colors.black,
                ),
              ],
            ),
          ),
          // Form content
          Expanded(
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              behavior: HitTestBehavior.opaque,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: 8, // Minimal padding when keyboard is open
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name field
                      const Text(
                        'Name',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Enter your name',
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        style: const TextStyle(fontSize: 16),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Username field
                      const Text(
                        'Username',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          hintText: '@username',
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          suffixIcon: _isCheckingUsername
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : _isUsernameAvailable && 
                                  _usernameController.text.length > 1
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      ),
                                    )
                                  : null,
                        ),
                        style: const TextStyle(fontSize: 16),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleSubmit(),
                        validator: (value) {
                          if (value == null || value.length <= 1) {
                            return 'Please enter a username';
                          }
                          final usernameWithoutAt = value.substring(1);
                          if (usernameWithoutAt.isEmpty) {
                            return 'Username cannot be empty';
                          }
                          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(usernameWithoutAt)) {
                            return 'Username can only contain letters, numbers, and underscores';
                          }
                          if (_usernameError != null) {
                            return _usernameError;
                          }
                          return null;
                        },
                      ),
                      if (_usernameError != null && !_isCheckingUsername)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _usernameError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (_isUsernameAvailable && 
                          _usernameController.text.length > 1 &&
                          !_isCheckingUsername)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Username is available',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 32),
                      
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
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
