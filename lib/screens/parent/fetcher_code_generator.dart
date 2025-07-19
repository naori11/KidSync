import 'package:flutter/material.dart';

class FetcherCodeGeneratorScreen extends StatelessWidget {
  const FetcherCodeGeneratorScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fetcher Code Generator')),
      body: const Center(
        child: Text('Fetcher code (QR/PIN) will be generated here.'),
      ),
    );
  }
}
