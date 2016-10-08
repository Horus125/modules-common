// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:models/user/user.dart';
import 'package:models/contact/contact.dart';
import 'package:widgets/contact/contact_details_full.dart';

/// Full contact details page
class ContactDetailsFullScreen extends StatefulWidget {
  /// Creates a [ContactDetailsFullScreen] instance.
  ContactDetailsFullScreen({Key key}) : super(key: key);

  @override
  _ContactDetailsFullScreenState createState() => new _ContactDetailsFullScreenState();
}

class _ContactDetailsFullScreenState extends State<ContactDetailsFullScreen> {
  final GlobalKey<ScaffoldState> _key = new GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      key: _key,
      appBar: new AppBar(
        title: new Text('Contact - Full Detail'),
      ),
      body: new ContactDetailsFull(
        contact: new Contact(
          user: new User(
            name: 'Coco Yang',
            familyName: 'Yang',
            givenName: 'Coco',
            picture: 'https://raw.githubusercontent.com/dvdwasibi/DogsOfFuchsia/master/coco.jpg',
          ),
        ),
      ),
    );
  }
}
