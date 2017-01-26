// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// THIS IS A GENERATED FILE. DO NOT MODIFY MANUALLY.

import 'package:flutter/material.dart';
import 'package:gallery/src/common/typedefs.dart';
import 'package:widget_specs/widget_specs.dart';
import 'package:mock_package/exported.dart';

/// Name of the widget.
const String kName = 'Widget01';

/// [WidgetSpecs] of this widget.
final WidgetSpecs kSpecs = new WidgetSpecs(
  packageName: 'mock_package',
  name: 'Widget01',
  path: 'exported.dart',
  doc: '''
This is a public [StatefulWidget].''',
);

/// Helper widget.
class _HelperWidget extends StatefulWidget {
  final double width;
  final double height;

  _HelperWidget(this.width, this.height);

  @override
  _HelperWidgetState createState() => new _HelperWidgetState();
}

/// Helper widget state.
class _HelperWidgetState extends State<_HelperWidget> {
  int intParam;
  bool boolParam;
  String stringParam;
  dynamic noExampleValueParam;

  Key uniqueKey = new UniqueKey();

  @override
  void initState() {
    super.initState();

    intParam = 42;
    boolParam = true;
    stringParam = '''example string value!''';
    noExampleValueParam = null;
  }

  @override
  Widget build(BuildContext context) {
    Widget widget;
    try {
      widget = new Widget01(
        key: uniqueKey,
        intParam: intParam,
        boolParam: boolParam,
        stringParam: stringParam,
        noExampleValueParam: noExampleValueParam,
      );
    } catch (e) {
      widget = new Text('Failed to build the widget.\n'
          'See the error message below:\n\n'
          '$e');
    }

    return new Block(children: <Widget>[
      new Container(
        decoration: new BoxDecoration(
          border: new Border.all(color: Colors.grey[500]),
          borderRadius: new BorderRadius.all(new Radius.circular(4.0)),
        ),
        margin: const EdgeInsets.all(16.0),
        child: new Container(
          child: new Container(
            margin: const EdgeInsets.all(16.0),
            child: new Block(
              children: <Widget>[
                new Text(
                  'Parameters',
                  style: new TextStyle(fontWeight: FontWeight.bold),
                ),
                new Table(
                  children: <TableRow>[
                    new TableRow(
                      children: <Widget>[
                        new Text('int'),
                        new Container(),
                        new Text('intParam'),
                        new Container(),
                        new TextField(
                          initialValue:
                              new InputValue(text: (intParam ?? 0).toString()),
                          isDense: true,
                          onChanged: (InputValue value) {
                            try {
                              int intValue = int.parse(value.text);
                              setState(() {
                                intParam = intValue;
                                updateKey();
                              });
                            } catch (e) {
                              // Do nothing.
                            }
                          },
                        ),
                      ],
                    ),
                    new TableRow(
                      children: <Widget>[
                        new Text('bool'),
                        new Container(),
                        new Text('boolParam'),
                        new Container(),
                        new Row(
                          children: <Widget>[
                            new Switch(
                              value: boolParam ?? false,
                              onChanged: (bool value) {
                                setState(() {
                                  boolParam = value;
                                  updateKey();
                                });
                              },
                            ),
                            new Expanded(child: new Container()),
                          ],
                        ),
                      ],
                    ),
                    new TableRow(
                      children: <Widget>[
                        new Text('String'),
                        new Container(),
                        new Text('stringParam'),
                        new Container(),
                        new TextField(
                          initialValue: new InputValue(text: stringParam ?? ''),
                          isDense: true,
                          onChanged: (InputValue value) {
                            setState(() {
                              stringParam = value.text;
                              updateKey();
                            });
                          },
                        ),
                      ],
                    ),
                    new TableRow(
                      children: <Widget>[
                        new Text('dynamic'),
                        new Container(),
                        new Text('noExampleValueParam'),
                        new Container(),
                        new Text(
                            'null (this type of parameter is not supported yet)'),
                      ],
                    ),
                  ],
                  columnWidths: <int, TableColumnWidth>{
                    0: const IntrinsicColumnWidth(),
                    1: const FixedColumnWidth(16.0),
                    2: const IntrinsicColumnWidth(),
                    3: const FixedColumnWidth(16.0),
                    4: const FlexColumnWidth(1.0),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                ),
              ],
            ),
          ),
        ),
      ),
      new Container(
        decoration: new BoxDecoration(
          border: new Border.all(color: Colors.grey[500]),
          borderRadius: new BorderRadius.all(new Radius.circular(4.0)),
        ),
        margin: const EdgeInsets.all(16.0),
        child: new Container(
          margin: const EdgeInsets.all(16.0),
          child: new Row(
            children: <Widget>[
              new Container(
                width: config.width,
                height: config.height,
                child: widget,
              ),
              new Expanded(child: new Container()),
            ],
          ),
        ),
      ),
    ]);
  }

  void updateKey() {
    uniqueKey = new UniqueKey();
  }
}

/// Builder for this widget.
final GalleryWidgetBuilder kBuilder =
    (BuildContext context, double width, double height) =>
        new _HelperWidget(width, height);
