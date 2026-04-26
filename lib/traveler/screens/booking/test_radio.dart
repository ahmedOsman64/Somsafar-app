import 'package:flutter/material.dart';
Widget testRadio(int val) { return RadioGroup<int>(groupValue: val, onChanged: (v) {}, child: Column(children: [RadioListTile<int>(value: 1, title: Text('1'))])); }
