// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:application.lib.app.dart/app.dart';
import 'package:application.services/application_controller.fidl.dart';
import 'package:application.services/application_environment.fidl.dart';
import 'package:application.services/application_environment_host.fidl.dart';
import 'package:application.services/application_launcher.fidl.dart';
import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.modular.services.module/module.fidl.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.module/module_controller.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:apps.mozart.services.views/view_token.fidl.dart';
import 'package:apps.web_view.services/web_view.fidl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.fidl.dart/core.dart';

final ApplicationContext _context = new ApplicationContext.fromStartupInfo();
final ApplicationEnvironmentProxy _childEnvironment = _initChildEnvironment();
final ApplicationLauncherProxy _childLauncher = _initLauncher();

final String _kEmailServiceUrl = 'file:///system/apps/email_service';
final String _kEmailSessionUrl = 'file:///system/apps/email_session';
final String _kEmailNavUrl = 'file:///system/apps/email_nav';
final String _kEmailListUrl = 'file:///system/apps/email_list';
final String _kEmailListGridUrl = 'file:///system/apps/email_list_grid';
final String _kEmailThreadUrl = 'file:///system/apps/email_thread';

final String _kWebViewUrl = 'file:///system/apps/web_view';
final String _kClientId = 'ENTER_CLIENT_ID_HERE';
final String _kCallbackUrl = 'com.fuchsia.googleauth:/oauth2redirect';

final List<String> _kScopes = <String>[
  'https://www.googleapis.com/auth/gmail.modify',
  'https://www.googleapis.com/auth/userinfo.email',
  'https://www.googleapis.com/auth/userinfo.profile',
  'https://www.googleapis.com/auth/contacts',
  'https://www.googleapis.com/auth/plus.login',
];

final GlobalKey<HomeScreenState> _kHomeKey = new GlobalKey<HomeScreenState>();

ModuleImpl _module;

ChildViewConnection _connNav;
ChildViewConnection _connList;
ChildViewConnection _connListGrid;
ChildViewConnection _connThread;
ChildViewConnection _connWebView;

bool _authCompleted = false;

void _log(String msg) {
  print('[email_story] $msg');
}

class ApplicationEnvironmentHostImpl extends ApplicationEnvironmentHost {
  final ApplicationEnvironmentHostBinding _binding =
      new ApplicationEnvironmentHostBinding();

  void bind(InterfaceRequest<ApplicationEnvironmentHost> request) {
    _binding.bind(this, request);
  }

  InterfaceHandle<ApplicationEnvironmentHost> getInterfaceHandle() {
    return _binding.wrap(this);
  }

  @override
  void getApplicationEnvironmentServices(
      InterfaceRequest<ServiceProvider> services) {
    ServiceProviderImpl impl = new ServiceProviderImpl()
      ..bind(services)
      // ..addServiceForName((request) {
      //   new PresenterImpl().bind(request);
      // }, Presenter.serviceName)
      ..defaultConnector = (String serviceName, InterfaceRequest request) {
        _context.environmentServices
            .connectToService(serviceName, request.passChannel());
      };
    // TODO(abarth): Add a proper BindingSet to the FIDL Dart bindings so we
    // accumulate all these service provider impls.
    _serviceProviders.add(impl);
  }

  List<ServiceProviderImpl> _serviceProviders = <ServiceProviderImpl>[];
}

final ApplicationEnvironmentHostImpl _environmentHost =
    new ApplicationEnvironmentHostImpl();

ApplicationEnvironmentProxy _initChildEnvironment() {
  final ApplicationEnvironmentProxy proxy = new ApplicationEnvironmentProxy();
  _context.environment.createNestedEnvironment(
    _environmentHost.getInterfaceHandle(),
    proxy.ctrl.request(),
    null,
    'email',
  );
  return proxy;
}

ApplicationLauncherProxy _initLauncher() {
  final ApplicationLauncherProxy proxy = new ApplicationLauncherProxy();
  _childEnvironment.getApplicationLauncher(proxy.ctrl.request());
  return proxy;
}

class ChildApplication {
  ChildApplication(
      {this.controller, this.connection, this.title, this.services});

  factory ChildApplication.create(String url, {String title}) {
    final ApplicationControllerProxy controller =
        new ApplicationControllerProxy();

    final ServiceProviderProxy services = new ServiceProviderProxy();

    ChildViewConnection connection = new ChildViewConnection.launch(
        url, _childLauncher,
        controller: controller.ctrl.request(),
        childServices: services.ctrl.request());

    return new ChildApplication(
      controller: controller,
      connection: connection,
      title: title,
      services: services,
    );
  }

  factory ChildApplication.view(InterfaceHandle<ViewOwner> viewOwner) {
    return new ChildApplication(
      connection: new ChildViewConnection(viewOwner),
    );
  }

  void close() {
    if (controller != null) {
      controller.kill();
      controller.ctrl.close();
    }
  }

  final ApplicationControllerProxy controller;
  final ChildViewConnection connection;
  final String title;
  final ServiceProviderProxy services;
}

/// A wrapper class for duplicating ServiceProvider
class ServiceProviderWrapper extends ServiceProvider {
  final ServiceProviderBinding _binding = new ServiceProviderBinding();

  /// The original [ServiceProvider] instance that this class wraps.
  final ServiceProvider serviceProvider;

  /// Creates a new [ServiceProviderWrapper] with the given [ServiceProvider].
  ServiceProviderWrapper(this.serviceProvider);

  /// Gets the [InterfaceHandle] for this [ServiceProvider] wrapper.
  ///
  /// The returned handle should only be used once.
  InterfaceHandle<ServiceProvider> getHandle() => _binding.wrap(this);

  /// Closes the binding.
  void close() => _binding.close();

  @override
  void connectToService(String serviceName, Channel channel) {
    serviceProvider.connectToService(serviceName, channel);
  }
}

/// An implementation of the [Module] interface.
class ModuleImpl extends Module {
  final ModuleBinding _binding = new ModuleBinding();

  /// [ModuleContext] service provided by the framework.
  final ModuleContextProxy moduleContext = new ModuleContextProxy();

  /// [Link] service provided by the framework.
  final LinkProxy link = new LinkProxy();

  /// [ServiceProviderProxy] between email session and UI modules.
  final ServiceProviderProxy emailSessionProvider = new ServiceProviderProxy();

  /// A list used for holding references to the [ServiceProviderWrapper]
  /// objects for the lifetime of this module.
  final List<ServiceProviderWrapper> serviceProviders =
      <ServiceProviderWrapper>[];

  ChildApplication _childApp;
  WebViewProxy _webView;
  WebRequestDelegateImpl _webRequestDelegate;

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
    InterfaceRequest<ServiceProvider> outgoingServices,
  ) {
    _log('ModuleImpl::initialize call');

    moduleContext.ctrl.bind(moduleContextHandle);
    link.ctrl.bind(linkHandle);

    // Launch the web view for authentication.
    _childApp = new ChildApplication.create(_kWebViewUrl);
    _webView = new WebViewProxy();
    connectToService(_childApp.services, _webView.ctrl);

    final String url = 'https://accounts.google.com/o/oauth2/v2/auth?'
        'scope=${_kScopes.join('%20')}'
        '&response_type=code'
        '&redirect_uri=$_kCallbackUrl' +
        '&client_id=${_kClientId}';

    print('URL is ' + url);

    _webView.setUrl(url);

    _webRequestDelegate = new WebRequestDelegateImpl(link: link);
    _webView.setWebRequestDelegate(_webRequestDelegate.getInterfaceHandle());
    _connWebView = _childApp.connection;

    // Binding between email service and email session.
    InterfacePair<ServiceProvider> emailServiceBinding =
        new InterfacePair<ServiceProvider>();

    // Obtain the email service provider from the email_service module.
    startModule(
      url: _kEmailServiceUrl,
      incomingServices: emailServiceBinding.passRequest(),
    );
    startModule(
      url: _kEmailSessionUrl,
      outgoingServices: emailServiceBinding.passHandle(),
      incomingServices: emailSessionProvider.ctrl.request(),
    );

    InterfaceHandle<ViewOwner> navViewOwner = startModule(
      url: _kEmailNavUrl,
      outgoingServices: duplicateServiceProvider(emailSessionProvider),
    );
    _connNav = new ChildViewConnection(navViewOwner);
    updateUI();

    InterfaceHandle<ViewOwner> listViewOwner = startModule(
      url: _kEmailListUrl,
      outgoingServices: duplicateServiceProvider(emailSessionProvider),
    );
    _connList = new ChildViewConnection(listViewOwner);
    updateUI();

    InterfaceHandle<ViewOwner> threadViewOwner = startModule(
      url: _kEmailThreadUrl,
      outgoingServices: duplicateServiceProvider(emailSessionProvider),
    );
    _connThread = new ChildViewConnection(threadViewOwner);
    updateUI();

    // NOTE(youngseokyoon): Start this module ahead of time, even though it's
    // not used right away. This should be better for performance.
    // TODO(youngseokyoon): Make grid module scrollable
    // https://fuchsia.atlassian.net/browse/SO-141
    InterfaceHandle<ViewOwner> listGridViewOwner = startModule(
      url: _kEmailListGridUrl,
      outgoingServices: duplicateServiceProvider(emailSessionProvider),
    );
    _connListGrid = new ChildViewConnection(listGridViewOwner);
  }

  @override
  void stop(void callback()) {
    _log('ModuleImpl::stop call');
    moduleContext.ctrl.close();
    link.ctrl.close();
    emailSessionProvider.ctrl.close();
    serviceProviders.forEach((ServiceProviderWrapper s) => s.close());
    callback();
  }

  /// Updates the UI by calling setState on the [HomeScreenState] object.
  void updateUI() {
    _kHomeKey.currentState?.updateUI();
  }

  /// Start a module and return its [ViewOwner] handle.
  InterfaceHandle<ViewOwner> startModule({
    String url,
    InterfaceHandle<ServiceProvider> outgoingServices,
    InterfaceRequest<ServiceProvider> incomingServices,
  }) {
    InterfacePair<ViewOwner> viewOwnerPair = new InterfacePair<ViewOwner>();
    InterfacePair<ModuleController> moduleControllerPair =
        new InterfacePair<ModuleController>();

    _log('Starting sub-module: $url');
    moduleContext.startModule(
      url,
      duplicateLink(),
      outgoingServices,
      incomingServices,
      moduleControllerPair.passRequest(),
      viewOwnerPair.passRequest(),
    );
    _log('Started sub-module: $url');

    return viewOwnerPair.passHandle();
  }

  /// Obtains a duplicated [InterfaceHandle] for the given [Link] object.
  InterfaceHandle<Link> duplicateLink() {
    InterfacePair<Link> linkPair = new InterfacePair<Link>();
    link.dup(linkPair.passRequest());
    return linkPair.passHandle();
  }

  /// Duplicates a [ServiceProvider] and returns its handle.
  InterfaceHandle<ServiceProvider> duplicateServiceProvider(ServiceProvider s) {
    ServiceProviderWrapper dup = new ServiceProviderWrapper(s);
    serviceProviders.add(dup);
    return dup.getHandle();
  }
}

class WebRequestDelegateImpl extends WebRequestDelegate {
  final WebRequestDelegateBinding _binding = new WebRequestDelegateBinding();
  final Link link;

  WebRequestDelegateImpl({this.link});

  void bind(InterfaceRequest<WebRequestDelegate> request) {
    _binding.bind(this, request);
  }

  InterfaceHandle<WebRequestDelegate> getInterfaceHandle() {
    return _binding.wrap(this);
  }

  @override
  void willSendRequest(String url) {
    String code;
    if (url.startsWith(_kCallbackUrl)) {
      print(Uri.splitQueryString(url));
      code = Uri.splitQueryString(url)[_kCallbackUrl + '?code'];
    } else {
      return;
    }

    final kAccessTokenURL = 'https://www.googleapis.com/oauth2/v4/token';

    // TODO(mikejurka): verify that 'code' is correct format
    var data = {
      'code': code,
      'client_id': _kClientId,
      'grant_type': 'authorization_code',
      'redirect_uri': _kCallbackUrl
    };

    createHttpClient().post(kAccessTokenURL, body: data).then((response) {
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      var tokenMap = JSON.decode(response.body);
      print('Access token:');
      print(tokenMap['access_token']);

      // Put the response body as a JSON value in the root link.
      tokenMap['scopes'] = _kScopes;
      tokenMap['client_id'] = _kClientId;
      link.set(<String>['auth'], JSON.encode(tokenMap));
      _authCompleted = true;
      updateUI();
    });
  }

  /// Updates the UI by calling setState on the [HomeScreenState] object.
  void updateUI() {
    _kHomeKey.currentState?.updateUI();
  }
}

/// The top level [StatefulWidget].
class HomeScreen extends StatefulWidget {
  /// Creates a new [HomeScreen].
  HomeScreen({Key key}) : super(key: key);

  @override
  HomeScreenState createState() => new HomeScreenState();
}

/// The [State] class for the [HomeScreen].
class HomeScreenState extends State<HomeScreen> {
  bool _grid = false;

  @override
  Widget build(BuildContext context) {
    if (!_authCompleted) {
      return new Container(
        child: new ChildView(connection: _connWebView),
        constraints: const BoxConstraints.expand(),
      );
    }

    Widget nav = new Expanded(
      flex: 2,
      child: new Column(
        children: <Widget>[
          new Expanded(
            flex: 1,
            child: _connNav != null
                ? new ChildView(connection: _connNav)
                : new Container(),
          ),
        ],
      ),
    );

    ChildViewConnection connList = _grid ? _connListGrid : _connList;
    Widget list = new Expanded(
      flex: 3,
      child: new Container(
        padding: new EdgeInsets.symmetric(horizontal: 4.0),
        child: new Material(
          elevation: 2,
          child: _connList != null
              ? new ChildView(connection: connList)
              : new Container(),
        ),
      ),
    );

    Widget thread = new Expanded(
      flex: 4,
      child: _connThread != null
          ? new ChildView(connection: _connThread)
          : new Container(),
    );

    List<Widget> columns = <Widget>[nav, list, thread];
    return new Material(
      color: Colors.white,
      child: new Row(children: columns),
    );
  }

  /// Convenient method for other entities to call setState to cause UI updates.
  void updateUI() {
    setState(() {});
  }
}

/// Main entry point to the quarterback module.
void main() {
  _log('Email quarterback module started with context: $_context');

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

  runApp(new HomeScreen(key: _kHomeKey));
}
