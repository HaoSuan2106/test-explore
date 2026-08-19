import 'package:flutter/material.dart';

class PostUI extends StatelessWidget {
  const PostUI({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Create Post'),
      ),
    );
  }
}

typedef PostUi = PostUI;
