import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../../providers/providers.dart';
import '../../models/post_model.dart';
import '../../services/google_places_service.dart';
import '../../widgets/gym_location_selector.dart';
import '../../services/deezer_service.dart';
import '../../widgets/music_selector.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  File? _selectedMedia;
  final _captionController = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _hasTriggeredCamera = false;

  // Tagged users and location
  List<String> _taggedUserIds = [];
  Map<String, String> _taggedUserNames = {}; // userId -> username
  Map<String, double>? _selectedLocation;
  String? _selectedLocationName;
  PlaceResult? _selectedGym;

  // Music
  DeezerTrack? _selectedMusic;

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isInitializingCamera = false;

  // Camera controls
  int _currentCameraIndex = 1; // Prioritize back camera (usually 1)
  FlashMode _currentFlashMode = FlashMode.off;
  bool _isFlashSupported = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_isInitializingCamera) return;

    _isInitializingCamera = true;
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        // Find back camera
        int backCameraIndex = _cameras!.indexWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back);

        if (backCameraIndex != -1) {
          _currentCameraIndex = backCameraIndex;
          print('DEBUG: Found back camera at index: $backCameraIndex');
        } else {
          _currentCameraIndex = 0; // Fallback to first camera
          print('DEBUG: No back camera found, using index 0');
        }

        await _setupCamera(_currentCameraIndex);
      }
    } catch (e) {
      print('Error of starting camera: $e');
      // Use image_picker as fallback in case of error
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    } finally {
      _isInitializingCamera = false;
    }
  }

  Future<void> _setupCamera(int cameraIndex) async {
    if (_cameras == null || _cameras!.isEmpty) return;

    try {
      // Dispose previous controller
      await _cameraController?.dispose();
      _cameraController = null;

      // Create new controller
      _cameraController = CameraController(
        _cameras![cameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );

      // Initialize and wait
      await _cameraController!.initialize();

      // Check if initialization was successful
      if (!_cameraController!.value.isInitialized) {
        print('DEBUG: Camera initialization failed!');
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
          });
        }
        return;
      }

      // Check flash support
      _isFlashSupported = _cameraController!.description.lensDirection ==
          CameraLensDirection.back;

      print(
          'DEBUG: Camera ${cameraIndex} - Lens direction: ${_cameraController!.description.lensDirection}');
      print('DEBUG: Flash supported: $_isFlashSupported');
      print('DEBUG: Current camera index: $cameraIndex');
      print('DEBUG: ✅ Camera initialized successfully');

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _currentCameraIndex = cameraIndex;
        });
      }
    } catch (e) {
      print('DEBUG: ❌ Camera setup error: $e');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  Future<void> _openCameraDirectly() async {
    // Camera already integrated, this method is no longer used
    print('DEBUG: _openCameraDirectly called - camera already integrated');
  }

  Future<void> _takePicture() async {
    print('DEBUG: _takePicture called');
    print('DEBUG: Camera controller null: ${_cameraController == null}');
    print('DEBUG: Camera initialized: $_isCameraInitialized');
    print(
        'DEBUG: Controller value initialized: ${_cameraController?.value.isInitialized}');

    if (_cameraController == null || !_isCameraInitialized) {
      print('DEBUG: Camera not ready, ignoring tap');
      return;
    }

    // Double check controller is ready
    if (!_cameraController!.value.isInitialized) {
      print('DEBUG: Controller not initialized yet, waiting...');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera is still initializing, please wait...'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      print('DEBUG: Taking picture...');
      final XFile image = await _cameraController!.takePicture();
      print('DEBUG: Picture taken successfully: ${image.path}');

      if (!mounted) return;

      setState(() {
        _selectedMedia = File(image.path);
      });

      print('DEBUG: State updated with selected media');
    } catch (e) {
      print('DEBUG: Error of taking picture: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error. Please try again or use gallery.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Gallery',
              textColor: Colors.white,
              onPressed: _pickFromGallery,
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    setState(() {
      _isCameraInitialized = false;
    });

    final newCameraIndex = _currentCameraIndex == 0 ? 1 : 0;
    await _setupCamera(newCameraIndex);
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_isFlashSupported) return;

    FlashMode newFlashMode;
    switch (_currentFlashMode) {
      case FlashMode.off:
        newFlashMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        newFlashMode = FlashMode.always;
        break;
      case FlashMode.always:
        newFlashMode = FlashMode.off;
        break;
      default:
        newFlashMode = FlashMode.off;
    }

    await _cameraController!.setFlashMode(newFlashMode);
    setState(() {
      _currentFlashMode = newFlashMode;
    });
  }

  IconData _getFlashIcon() {
    switch (_currentFlashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      default:
        return Icons.flash_off;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(createPostProvider);
    final navigationState = ref.watch(navigationProvider);

    // Only open camera when user navigates to Create Post tab
    if (navigationState == NavigationState.createPost &&
        !_hasTriggeredCamera &&
        _selectedMedia == null) {
      _hasTriggeredCamera = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openCameraDirectly();
      });
    }

    // If returning from another tab, reset state
    if (navigationState != NavigationState.createPost) {
      _hasTriggeredCamera = false;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: _selectedMedia == null
          ? _buildCameraScreen()
          : _buildPostCreationScreen(isLoading),
    );
  }

  Widget _buildCameraScreen() {
    return SafeArea(
      child: Stack(
        children: [
          // Main camera area - real camera preview
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: _isCameraInitialized && _cameraController != null
                ? CameraPreview(_cameraController!)
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.orange,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Initializing camera...',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // Top transparent gradient overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.6)
                  ],
                ),
              ),
            ),
          ),

          // Bottom transparent gradient overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.6)
                  ],
                ),
              ),
            ),
          ),

          // Top section - Back button and title
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () {
                      ref.read(navigationProvider.notifier).goToHome();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),

                  // Title
                  const Text(
                    'Create Post',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // Camera controls
                  Row(
                    children: [
                      // Camera switch button
                      if (_cameras != null && _cameras!.length > 1)
                        GestureDetector(
                          onTap: _toggleCamera,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.flip_camera_ios,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom section - Gallery and Camera buttons
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Gallery button
                  GestureDetector(
                    onTap: _pickFromGallery,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.photo_library,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),

                  // Camera button (main)
                  GestureDetector(
                    onTap: _isCameraInitialized ? _takePicture : null,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color:
                            _isCameraInitialized ? Colors.orange : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                      ),
                      child: Icon(
                        Icons.camera,
                        color: Colors.white,
                        size: 35,
                      ),
                    ),
                  ),

                  // Flash button
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _isFlashSupported ? _toggleFlash : null,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (_isFlashSupported &&
                                      _currentFlashMode != FlashMode.off)
                                  ? Colors.yellow
                                  : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _getFlashIcon(),
                            color: (_isFlashSupported &&
                                    _currentFlashMode != FlashMode.off)
                                ? Colors.yellow
                                : (_isFlashSupported
                                    ? Colors.white
                                    : Colors.grey),
                            size: 24,
                          ),
                        ),
                      ),
                      // Debug info
                      Text(
                        'F:${_isFlashSupported ? 'Y' : 'N'} C:$_currentCameraIndex',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCreationScreen(bool isLoading) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          onPressed: () {
            setState(() {
              _selectedMedia = null;
            });
          },
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: const Text(
          'New Post',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: ElevatedButton(
              onPressed: isLoading ? null : _sharePost,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isLoading ? Colors.grey.shade300 : Colors.orange,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Share',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media Preview Area
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _selectedMedia != null
                    ? AspectRatio(
                        aspectRatio: 0.7,
                        child: Stack(
                          children: [
                            Image.file(
                              _selectedMedia!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                            // Retake button
                            Positioned(
                              top: 12,
                              right: 12,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedMedia = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_outlined,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No image selected',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),

            // Caption Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Caption',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _captionController,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: 'Write something about your workout...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                        counterStyle: TextStyle(color: Colors.grey),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tagged Users ve Location Preview
            if (_taggedUserIds.isNotEmpty || _selectedLocation != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_taggedUserIds.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.people,
                                size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tagged: ${_taggedUserNames.values.join(', ')}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_selectedLocation != null)
                          const SizedBox(height: 8),
                      ],
                      if (_selectedLocation != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedLocationName ?? 'Location added',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Options Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add to your post',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Options List
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        // Add Music
                        _buildOptionTile(
                          icon: Icons.music_note,
                          title: 'Add Music',
                          subtitle: _selectedMusic != null
                              ? '${_selectedMusic!.name} - ${_selectedMusic!.artist}'
                              : 'Add a song to your post',
                          onTap: _showMusicSelector,
                          trailing: _selectedMusic != null
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _selectedMusic = null;
                                    });
                                  },
                                )
                              : null,
                        ),
                        const Divider(height: 1),
                        _buildOptionTile(
                          icon: Icons.person_add_alt_1,
                          title: 'Tag People',
                          subtitle: _taggedUserIds.isEmpty
                              ? 'Let others know who\'s with you'
                              : '${_taggedUserIds.length} people tagged',
                          onTap: _showTagPeopleDialog,
                          trailing: _taggedUserIds.isNotEmpty
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_taggedUserIds.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        Divider(height: 1, color: Colors.grey.shade200),
                        _buildOptionTile(
                          icon: Icons.location_on,
                          title: 'Add Gym Location',
                          subtitle: _selectedLocationName ??
                              'Find and select your gym',
                          onTap: _handleLocationTap,
                          trailing: _selectedLocation != null
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _removeLocation,
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.grey[600],
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom spacing
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.orange,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 14,
        ),
      ),
      trailing: trailing ??
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey.shade400,
          ),
      onTap: onTap,
    );
  }

  Future<void> _pickFromGallery() async {
    final XFile? media = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (media != null) {
      setState(() {
        _selectedMedia = File(media.path);
      });
    }
  }

  // Music Selector Dialog
  void _showMusicSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MusicSelector(
        onTrackSelected: (track) {
          setState(() {
            _selectedMusic = track;
          });
          Navigator.pop(context);
        },
        onCancel: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  // Tag People Dialog
  void _showTagPeopleDialog() async {
    try {
      final currentUser = ref.read(firebaseAuthServiceProvider).currentUser;
      if (currentUser == null) return;

      final userService = ref.read(firebaseUserServiceProvider);
      final friends = await userService.getUserFriends(currentUser.uid);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Tag People'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: friends.isEmpty
                  ? const Center(
                      child: Text(
                        'You have no friends to tag.\nAdd friends first!',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        final isTagged = _taggedUserIds.contains(friend.id);

                        return CheckboxListTile(
                          value: isTagged,
                          onChanged: (value) {
                            // Update both dialog state and main widget state
                            setDialogState(() {
                              if (value == true) {
                                _taggedUserIds.add(friend.id);
                                _taggedUserNames[friend.id] = friend.username;
                              } else {
                                _taggedUserIds.remove(friend.id);
                                _taggedUserNames.remove(friend.id);
                              }
                            });

                            // Also update the main widget state for UI refresh
                            setState(() {});
                          },
                          title: Text(friend.username),
                          subtitle: friend.bio?.isNotEmpty == true
                              ? Text(friend.bio!)
                              : null,
                          secondary: CircleAvatar(
                            backgroundImage: friend.profilePhoto != null
                                ? NetworkImage(friend.profilePhoto!)
                                : null,
                            child: friend.profilePhoto == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          activeColor: Colors.orange,
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {}); // Refresh main UI
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading friends: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Location handling
  void _handleLocationTap() async {
    try {
      // Get current location
      final locationNotifier = ref.read(locationProvider.notifier);
      await locationNotifier.getCurrentLocation();

      final locationState = ref.read(locationProvider);

      if (locationState.currentPosition != null) {
        final position = locationState.currentPosition!;

        // Show gym location selector
        _showGymLocationSelector(position.latitude, position.longitude);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(locationState.errorMessage ?? 'Could not get location'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showGymLocationSelector(double lat, double lng) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GymLocationSelector(
        latitude: lat,
        longitude: lng,
        onLocationSelected: (gym) {
          setState(() {
            _selectedGym = gym;
            _selectedLocation = {'lat': gym.lat, 'lng': gym.lng};
            _selectedLocationName = gym.name;
          });
          Navigator.pop(context);
        },
        onCancel: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  void _removeLocation() {
    setState(() {
      _selectedGym = null;
      _selectedLocation = null;
      _selectedLocationName = null;
    });
  }

  Future<void> _sharePost() async {
    if (_selectedMedia == null) return;

    // Set loading state
    ref.read(createPostProvider.notifier).state = true;

    try {
      final currentUser = ref.read(firebaseAuthServiceProvider).currentUser;
      print('DEBUG: Current user: ${currentUser?.uid}');
      print('DEBUG: Current user email: ${currentUser?.email}');

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get services
      final storageService = ref.read(firebaseStorageServiceProvider);
      final postService = ref.read(firestorePostServiceProvider);
      final userService = ref.read(firebaseUserServiceProvider);

      print('DEBUG: Services initialized');

      // Get current user data
      final userModel = await userService.getUserProfile(currentUser.uid);
      if (userModel == null) {
        throw Exception('User profile not found');
      }

      print('DEBUG: User profile found: ${userModel.username}');

      // Create post ID
      final postId = DateTime.now().millisecondsSinceEpoch.toString();
      print('DEBUG: Generated post ID: $postId');

      // Check file exists and readable
      if (!await _selectedMedia!.exists()) {
        throw Exception('Selected media file does not exist');
      }

      final fileSize = await _selectedMedia!.length();
      print('DEBUG: Media file size: $fileSize bytes');

      // Upload image to Firebase Storage
      print('DEBUG: Starting Firebase Storage upload...');
      final mediaUrl =
          await storageService.uploadPostImage(postId, _selectedMedia!);
      print('DEBUG: Upload successful, URL: $mediaUrl');

      // Save post to Firestore
      print('DEBUG: Creating Firestore post...');
      print('DEBUG: Selected Music Data:');
      print('  - ID: ${_selectedMusic?.id}');
      print('  - Name: ${_selectedMusic?.name}');
      print('  - Artist: ${_selectedMusic?.artist}');
      print('  - Album Art: ${_selectedMusic?.albumArt}');
      print('  - Preview URL: ${_selectedMusic?.previewUrl}');

      final firestorePost = PostModel(
        id: postId,
        userId: currentUser.uid,
        caption: _captionController.text.trim().isEmpty
            ? null
            : _captionController.text.trim(),
        mediaUrl: mediaUrl,
        type: 'photo',
        taggedUsers: _taggedUserIds,
        musicTrackId: _selectedMusic?.id,
        musicTrackName: _selectedMusic?.name,
        musicArtist: _selectedMusic?.artist,
        musicAlbumArt: _selectedMusic?.albumArt,
        musicPreviewUrl: _selectedMusic?.previewUrl,
        createdAt: DateTime.now(),
        location: _selectedLocation,
        locationName: _selectedLocationName,
      );

      print('DEBUG: PostModel toJson output:');
      print(firestorePost.toJson());

      await postService.createPost(firestorePost);
      print('DEBUG: Post created successfully in Firestore');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear state and go back
        setState(() {
          _selectedMedia = null;
          _captionController.clear();
          _taggedUserIds.clear();
          _taggedUserNames.clear();
          _selectedLocation = null;
          _selectedLocationName = null;
          _selectedGym = null;
        });

        // Reset loading state
        ref.read(createPostProvider.notifier).state = false;

        // Invalidate all post-related providers to refresh data
        ref.invalidate(postsProvider);
        ref.invalidate(friendsPostsProvider);
        ref.invalidate(userPostsProvider(currentUser.uid));
        ref.invalidate(currentUserPostsCountProvider);

        // Refresh gym-specific providers if location was tagged
        if (_selectedLocationName != null) {
          final refreshNotifier = ref.read(gymDataRefreshProvider.notifier);
          refreshNotifier.state = refreshNotifier.state + 1;
        }

        // Wait a moment for data refresh
        await Future.delayed(const Duration(milliseconds: 300));

        // Go to Home screen
        ref.read(navigationProvider.notifier).goToHome();
      }
    } catch (error) {
      print('DEBUG: Error in _sharePost: $error');
      print('DEBUG: Error type: ${error.runtimeType}');

      // Reset loading state
      ref.read(createPostProvider.notifier).state = false;

      if (mounted) {
        String errorMessage = 'Error sharing post: $error';

        // Provide more specific error messages
        if (error.toString().contains('firebase_storage/unauthorized')) {
          errorMessage =
              'Storage access denied. Please check Firebase Storage rules.';
        } else if (error
            .toString()
            .contains('firebase_storage/unauthenticated')) {
          errorMessage = 'User not authenticated for storage access.';
        } else if (error
            .toString()
            .contains('firebase_storage/retry-limit-exceeded')) {
          errorMessage =
              'Upload failed. Please check your internet connection.';
        } else if (error
            .toString()
            .contains('firebase_storage/invalid-format')) {
          errorMessage = 'Invalid file format. Please use JPG, PNG, or WEBP.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _captionController.dispose();
    super.dispose();
  }
}
