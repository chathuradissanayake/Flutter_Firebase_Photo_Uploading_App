import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

import 'details_page.dart'; // Import the details page

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  final FirebaseStorage storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> images = [];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    FirebaseFirestore.instance
        .collection('images')
        .snapshots()
        .listen((snapshot) {
      List<Map<String, dynamic>> imageList = [];
      for (var doc in snapshot.docs) {
        imageList.add({
          'id': doc.id,
          'url': doc['url'],
          'title': doc['title'],
          'description': doc['description'],
        });
      }
      setState(() {
        images = imageList;
      });
    });
  }

  Future<void> _uploadImage() async {
    final title = _titleController.text;
    final description = _descriptionController.text;

    if (title.isEmpty || description.isEmpty) {
      print('Title or description cannot be empty');
      return;
    }

    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        File file = File(pickedFile.path);
        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        Reference ref = storage.ref().child('images').child(fileName);
        UploadTask uploadTask = ref.putFile(file);

        print('Uploading image to Firebase Storage...');
        TaskSnapshot taskSnapshot = await uploadTask;

        if (taskSnapshot.state == TaskState.success) {
          print('Upload completed successfully.');
          String url = await taskSnapshot.ref.getDownloadURL();
          print('Download URL retrieved: $url');

          await FirebaseFirestore.instance.collection('images').add({
            'url': url,
            'title': title,
            'description': description,
          });

          setState(() {
            images.add({
              'url': url,
              'title': title,
              'description': description,
            });
          });

          // Clear the text fields after uploading
          _titleController.clear();
          _descriptionController.clear();
        } else {
          print('Upload failed with state: ${taskSnapshot.state}');
        }
      } else {
        print('No image selected');
      }
    } catch (e) {
      print('Error uploading image: $e');
    }
  }

  Future<void> logout() async {
    await googleSignIn.signOut();
  }

  void _navigateToDetailsPage(Map<String, dynamic> image) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailsPage(
          imageUrl: image['url'],
          title: image['title'],
          description: image['description'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Page'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await logout();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Profile Page'),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            ElevatedButton(
              onPressed: _uploadImage,
              child: const Text('Upload Photo'),
            ),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                ),
                itemCount: images.length,
                itemBuilder: (context, index) {
                  final image = images[index];
                  return GestureDetector(
                    onTap: () => _navigateToDetailsPage(image),
                    child: Card(
                      child: Column(
                        children: [
                          Expanded(
                            child:
                                Image.network(image['url'], fit: BoxFit.cover),
                          ),
                          Text(image['title'],
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
