// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:application.lib.app.dart/app.dart';
import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.modular.services.module/module.fidl.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.modules.email.services/email_service.fidl.dart' as es;
import 'package:flutter/material.dart';
import 'package:lib.fidl.dart/bindings.dart';

import 'src/email_impl.dart';

final ApplicationContext _context = new ApplicationContext.fromStartupInfo();

ModuleImpl _module;

void _log(String msg) {
  print('[email_service] $msg');
}

/// An implementation of the [Module] interface.
class ModuleImpl extends Module {
  final ModuleBinding _binding = new ModuleBinding();

  /// A [ServiceProvider] implementation to be used as the outgoing services.
  final ServiceProviderImpl outgoingServices = new ServiceProviderImpl();

  final EmailServiceImpl _emailServiceImpl = new EmailServiceImpl();

  final LinkProxy _link = new LinkProxy();
  LinkWatcherImpl _linkWatcher;

  /// Bind an [InterfaceRequest] for a [Module] interface to this object.
  void bind(InterfaceRequest<Module> request) {
    _binding.bind(this, request);
  }

  /// Implementation of the Initialize(Story story, Link link) method.
  @override
  void initialize(
    InterfaceHandle<ModuleContext> moduleContextHandle,
    InterfaceHandle<Link> linkHandle,
    InterfaceHandle<ServiceProvider> incomingServices,
    InterfaceRequest<ServiceProvider> outgoingServicesRequest,
  ) {
    _log('ModuleImpl::initialize call');

    // TODO: register link watcher and receive all the necessary data.
    _link.ctrl.bind(linkHandle);
    _linkWatcher = new LinkWatcherImpl(_emailServiceImpl);
    _link.watch(_linkWatcher.getInterfaceHandle());

    // Register the service provider which can serve the `Threads` service.
    outgoingServices
      ..addServiceForName(
        (InterfaceRequest<es.EmailService> request) {
          _log('Received binding request for Threads');
          _emailServiceImpl.bind(request);
        },
        es.EmailService.serviceName,
      )
      ..bind(outgoingServicesRequest);
  }

  @override
  void stop(void callback()) {
    _log('ModuleImpl::stop call');
    _emailServiceImpl.close();
    _linkWatcher.close();
    _link.ctrl.close();
    callback();
  }
}

class LinkWatcherImpl extends LinkWatcher {
  final LinkWatcherBinding _binding = new LinkWatcherBinding();
  final EmailServiceImpl _emailServiceImpl;

  LinkWatcherImpl(this._emailServiceImpl);

  InterfaceHandle<LinkWatcher> getInterfaceHandle() => _binding.wrap(this);

  void close() {
    _binding.close();
  }

  @override
  void notify(String json) {
    _log('JSON Link Notify');
    _log(json);

    if (json == null || json == 'null') {
      return;
    }

    dynamic root = JSON.decode(json);
    dynamic auth = root['auth'];

    if (auth != null) {
      _emailServiceImpl.initialize(
        id: auth['client_id'],
        secret: auth['client_secret'],
        token: auth['access_token'],
        expiry: new DateTime.now().toUtc()
          ..add(new Duration(seconds: auth['expires_in'])),
        refreshToken:
            null, // NOTE: refresh token doesn't work as expected for some unknown reason.
        scopes: auth['scopes'],
      );
    }
  }
}

/// Main entry point.
Future<Null> main() async {
  _log('main started with context: $_context');

  /// Add [ModuleImpl] to this application's outgoing ServiceProvider.
  _context.outgoingServices.addServiceForName(
    (InterfaceRequest<Module> request) {
      _log('Received binding request for Module');
      if (_module != null) {
        _log('Module interface can only be provided once. Rejecting request.');
        request.channel.close();
        return;
      }
      _module = new ModuleImpl()..bind(request);
    },
    Module.serviceName,
  );

  runApp(new MaterialApp(
    title: 'Email Service',
    home: new Text('This should never be seen.'),
  ));
}
