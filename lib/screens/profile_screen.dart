import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/auth_service.dart';
import '../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _userService = UserService();
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();

  String? _uid;
  String? _username;
  String? _email;
  String? _profileImageUrl;
  bool _loading = true;
  bool _uploadingImage = false;
  bool _saving = false;
  bool _isCheckingUsername = false;
  bool _isUsernameAvailable = false;
  String? _usernameError;
  String? _error;
  Timer? _usernameCheckTimer;

  @override
  void initState() {
    super.initState();
    _usernameController.text = '@';
    _usernameController.selection = TextSelection.fromPosition(
      TextPosition(offset: _usernameController.text.length),
    );
    _usernameController.addListener(_onUsernameChanged);
    _loadProfile();
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
    if (!text.startsWith('@')) {
      _usernameController.value = TextEditingValue(
        text: '@${text.replaceAll('@', '')}',
        selection: TextSelection.collapsed(offset: _usernameController.text.length),
      );
      return;
    }
    _usernameCheckTimer?.cancel();
    final usernameWithoutAt = text.substring(1);
    if (usernameWithoutAt.isEmpty) {
      setState(() {
        _isUsernameAvailable = false;
        _usernameError = null;
      });
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(usernameWithoutAt)) {
      setState(() {
        _isUsernameAvailable = false;
        _usernameError = 'Username can only contain letters, numbers, and underscores';
      });
      return;
    }
    _usernameCheckTimer = Timer(const Duration(milliseconds: 500), () {
      _checkUsernameAvailability(usernameWithoutAt);
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (_uid == null || username.isEmpty) {
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
      final available = await _userService.isUsernameAvailable(
        '@$username',
        excludeUid: _uid,
      );
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = available;
          _usernameError = available ? null : 'This username is already taken';
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

  Future<void> _loadProfile() async {
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Not signed in';
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _uid = user.uid;
      _email = user.email;
    });

    try {
      final doc = await _userService.getUserDocument(user.uid);
      final data = doc.data() as Map<String, dynamic>?;
      if (mounted) {
        final name = data?['name'] as String? ?? '';
        final username = data?['username'] as String? ?? '';
        _nameController.text = name;
        _usernameController.text = username.isNotEmpty ? '@$username' : '@';
        _usernameController.selection = TextSelection.fromPosition(
          TextPosition(offset: _usernameController.text.length),
        );
        setState(() {
          _username = username;
          _profileImageUrl = data?['profileImageUrl'] as String?;
          _loading = false;
        });
        if (username.isNotEmpty) _checkUsernameAvailability(username);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null || !mounted) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop profile photo',
            toolbarColor: const Color(0xFF2196F3),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: 'Crop profile photo',
            aspectRatioLockEnabled: true,
            cropStyle: CropStyle.circle,
          ),
          WebUiSettings(context: context),
        ],
        compressQuality: 85,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (croppedFile == null || !mounted) return;

      final file = File(croppedFile.path);
      setState(() => _uploadingImage = true);

      final downloadUrl = await _userService.uploadProfileImage(
        uid: user.uid,
        imageFile: file,
      );
      await _userService.updateProfileImageUrl(
        uid: user.uid,
        imageUrl: downloadUrl,
      );

      if (mounted) {
        setState(() {
          _profileImageUrl = downloadUrl;
          _uploadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_uid == null) return;
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final usernameText = _usernameController.text;
    final usernameWithoutAt = usernameText.startsWith('@')
        ? usernameText.substring(1)
        : usernameText;

    if (usernameWithoutAt.isEmpty) {
      setState(() => _usernameError = 'Please enter a username');
      return;
    }
    if (!_isUsernameAvailable && usernameWithoutAt != _username) {
      setState(() => _usernameError = 'Please choose an available username');
      return;
    }

    setState(() => _saving = true);
    try {
      await _userService.updateUserProfile(
        uid: _uid!,
        name: name,
        username: _usernameController.text,
      );
      if (mounted) {
        setState(() {
          _username = usernameWithoutAt;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildProfileImage(),
                      const SizedBox(height: 32),
                      _buildProfileForm(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: _uploadingImage ? null : _pickAndUploadImage,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                ? NetworkImage(_profileImageUrl!)
                : null,
            child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                ? Icon(
                    Icons.person,
                    size: 56,
                    color: Colors.grey.shade600,
                  )
                : null,
          ),
          if (_uploadingImage)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 4),
                ),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                      ? Icons.camera_alt
                      : Icons.add_a_photo,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel('Name'),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    border: UnderlineInputBorder(),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
                    ),
                    errorBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                    ),
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter your name';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildFieldLabel('Username'),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    border: const UnderlineInputBorder(),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
                    ),
                    errorBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                    ),
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    suffixIcon: _isCheckingUsername
                        ? const Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _usernameError == null && _usernameController.text.length > 1
                            ? Icon(Icons.check_circle, color: _isUsernameAvailable ? Colors.green : Colors.red, size: 22)
                            : null,
                    errorText: _usernameError,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                  autocorrect: false,
                  validator: (v) {
                    final text = v ?? '';
                    final withoutAt = text.startsWith('@') ? text.substring(1) : text;
                    if (withoutAt.isEmpty) return 'Enter a username';
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(withoutAt)) {
                      return 'Letters, numbers, and underscores only';
                    }
                    if (!_isUsernameAvailable && withoutAt != (_username ?? '')) {
                      return 'Choose an available username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildInfoRow('Email', _email ?? '—'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _saveProfile,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF757575),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
