import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(ImageGalleryApp());

class ImageGalleryApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Image Gallery App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: PersonGalleryScreen(),
    );
  }
}

class PersonGalleryScreen extends StatefulWidget {
  @override
  _PersonGalleryScreenState createState() => _PersonGalleryScreenState();
}

class _PersonGalleryScreenState extends State<PersonGalleryScreen> {
  final Map<String, List<File>> _personImages = {};
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    _prefs = await SharedPreferences.getInstance();
    final savedData = _prefs.getString('personImages');
    if (savedData != null) {
      final decodedData = json.decode(savedData) as Map<String, dynamic>;
      decodedData.forEach((person, imagePaths) {
        _personImages[person] = (imagePaths as List<dynamic>)
            .map((path) => File(path))
            .toList();
      });
      setState(() {});
    }
  }

  Future<void> _saveData() async {
    final encodedData = _personImages.map((person, images) {
      return MapEntry(person, images.map((image) => image.path).toList());
    });
    await _prefs.setString('personImages', json.encode(encodedData));
  }

  Future<void> _addImages(String personName) async {
    final pickedImages = await ImagePicker().pickMultiImage();
    if (pickedImages != null) {
      final images = await Future.wait(pickedImages.map((e) async {
        final appDir = await getApplicationDocumentsDirectory();
        final newImagePath = '${appDir.path}/${e.name}';
        return File(e.path).copy(newImagePath);
      }));

      setState(() {
        if (_personImages.containsKey(personName)) {
          _personImages[personName]!.addAll(images);
        } else {
          _personImages[personName] = images;
        }
      });

      await _saveData();
    }
  }

  void _openPersonGallery(String personName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IndividualPersonGallery(
          personName: personName,
          images: _personImages[personName]!,
          onDeleteImage: (image) => _deleteImage(personName, image),
        ),
      ),
    );
  }

  Future<void> _deletePerson(String personName) async {
    // Delete all images for this person from device storage
    for (var image in _personImages[personName]!) {
      await image.delete();
    }

    // Remove the person from the map
    setState(() {
      _personImages.remove(personName);
    });

    // Save updated data
    await _saveData();
  }

  Future<void> _deleteImage(String personName, File image) async {
    // Remove from gallery
    setState(() {
      _personImages[personName]!.remove(image);
    });

    // Delete the file from device storage
    await image.delete();

    // Save updated data
    await _saveData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image Gallery'),
      ),
      body: _personImages.isEmpty
          ? Center(child: Text('No images added.'))
          : ListView.builder(
              itemCount: _personImages.keys.length,
              itemBuilder: (context, index) {
                final personName = _personImages.keys.elementAt(index);
                final thumbnail = _personImages[personName]!.first;
                return ListTile(
                  leading: Image.file(thumbnail, width: 50, height: 50, fit: BoxFit.cover),
                  title: Text(personName),
                  onTap: () => _openPersonGallery(personName),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.add, color: Colors.green),
                        onPressed: () => _addImages(personName),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deletePerson(personName),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {
          _showAddPersonDialog();
        },
      ),
    );
  }

  void _showAddPersonDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Person'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: 'Person Name'),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: Text('Add Images'),
            onPressed: () async {
              final personName = nameController.text.trim();
              if (personName.isNotEmpty) {
                Navigator.of(ctx).pop();
                await _addImages(personName);
              }
            },
          ),
        ],
      ),
    );
  }
}

class IndividualPersonGallery extends StatefulWidget {
  final String personName;
  final List<File> images;
  final Function(File) onDeleteImage;

  IndividualPersonGallery({required this.personName, required this.images, required this.onDeleteImage});

  @override
  _IndividualPersonGalleryState createState() => _IndividualPersonGalleryState();
}

class _IndividualPersonGalleryState extends State<IndividualPersonGallery> {
  bool _isGridView = true;

  void _viewImage(BuildContext context, File image) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(image: image),
      ),
    );
  }

  Future<void> _downloadImage(BuildContext context, File image) async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        final newImagePath = '${downloadsDir.path}/${image.uri.pathSegments.last}';
        await image.copy(newImagePath);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image downloaded to Downloads folder')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloads directory not found')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Storage permission denied')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.personName)),
      body: Column(
        children: [
          // Toggle between GridView and PageView
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Grid View"),
              Switch(
                value: _isGridView,
                onChanged: (value) {
                  setState(() {
                    _isGridView = value;
                  });
                },
              ),
              Text("Swipe View"),
            ],
          ),
          Expanded(
            child: _isGridView
                ? GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                    ),
                    itemCount: widget.images.length,
                    itemBuilder: (ctx, index) {
                      return GestureDetector(
                        onTap: () => _viewImage(context, widget.images[index]),
                        child: Stack(
                          children: [
                            Image.file(widget.images[index], fit: BoxFit.cover),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => widget.onDeleteImage(widget.images[index]),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : PageView.builder(
                    itemCount: widget.images.length,
                    itemBuilder: (ctx, index) {
                      return Stack(
                        children: [
                          GestureDetector(
                            onTap: () => _viewImage(context, widget.images[index]),
                            child: Image.file(widget.images[index], fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => widget.onDeleteImage(widget.images[index]),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ImageViewerScreen extends StatelessWidget {
  final File image;

  ImageViewerScreen({required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('View Image'),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            onPressed: () async {
              final downloadsDir = Directory('/storage/emulated/0/Download');
              if (await downloadsDir.exists()) {
                final newImagePath = '${downloadsDir.path}/${image.uri.pathSegments.last}';
                await image.copy(newImagePath);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Image downloaded to Downloads folder')),
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Image.file(image),
      ),
    );
  }
}
