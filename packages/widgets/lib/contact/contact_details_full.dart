// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:models/contact/contact.dart';

import '../user/alphatar.dart';

/// Full Contact Details designed to take up much of the screen.
class ContactDetailsFull extends StatelessWidget {

  /// User [Contact] that is being rendered
  Contact contact;

  /// Constructor
  ContactDetailsFull({
    Key key,
    @required this.contact
  }) : super(key: key) {
    assert(contact != null);
  }

  @override
  Widget build(BuildContext context) {
    return new Container(
      child: new CustomMultiChildLayout(
        delegate: new _ContactLayoutDelegate(),
        children: <Widget>[
          new LayoutId(
            id: 'headerBackground',
            child: new Container(
              height: 300.0,
              decoration: new BoxDecoration(
                backgroundColor: Colors.grey[400],
              ),
            ),
          ),
          new LayoutId(
            id: 'content',
            child: new Container(
              padding: const EdgeInsets.only(top: 100.0),
              child: new Text('Content'),
              decoration: new BoxDecoration(
                backgroundColor: Colors.grey[200],
              ),
            ),
          ),
          new LayoutId(
            id: 'alphatar',
            child: new Alphatar.withUrl(
              avatarUrl: contact.user.picture,
              size: 160.0,
              letter: contact.user.name[0],
            ),
          ),
        ],
      ),
    );
  }
}


/// Layout Delegate that allows the participant text list to grow up to the
/// width of the parent while still accounting for the width of the message
/// count widget that follows.
class _ContactLayoutDelegate extends MultiChildLayoutDelegate {
  _ContactLayoutDelegate();

  static final String headerBackground = 'headerBackground';
  static final String alphatar = 'alphatar';
  static final String content = 'content';

  @override
  void performLayout(Size size) {

    print('SIZE: ${size}');
    // Height is fixed for background.
    // Width should stretch out to the parent
    Size headerBackgroundSize = layoutChild(
      headerBackground,
      new BoxConstraints.tightForFinite(
        height: 200.0,
        width: size.width,
      ),
    );

    // Fixed size for Alphatar
    Size alphatarSize = layoutChild(
      alphatar,
      new BoxConstraints.tightFor(
        width: 160.0,
        height: 160.0,
      )
    );

    // Content should stretch out to the rest of the parent
    layoutChild(
      content,
      new BoxConstraints.tightFor(
        height: size.height-200.0,
        width: size.width,
      ),
    );

    positionChild(headerBackground, Offset.zero);
    positionChild(content, new Offset(0.0, headerBackgroundSize.height));
    positionChild(alphatar, new Offset(
      headerBackgroundSize.width/2.0 - alphatarSize.width/2.0,
      headerBackgroundSize.height - alphatarSize.width/2.0,
    ));
  }

  @override
  bool shouldRelayout(MultiChildLayoutDelegate oldDelegate) => false;
}
