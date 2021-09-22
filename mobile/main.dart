import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:localstorage/localstorage.dart';
import 'package:random_string/random_string.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'about.dart';
import 'basic.dart';
import 'colors.dart';
import 'ipCamViewerStandAlone.dart';
import 'language.dart';
import 'logViewer.dart';
import 'login.dart';
import 'recordingFileViewer.dart';
import 'websocket.dart';
// Stream Handlers >
import 'dart:typed_data';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
// import 'package:flutter_vlc_player/vlc_player_controller.dart';
import 'package:flutter/services.dart';
// Stream Handlers END />
// Stream WebView plugin >
import 'package:webview_flutter/webview_flutter.dart';
// Stream WebView plugin END />
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:badges/badges.dart';
// notification >
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/subjects.dart';
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
// Streams are created so that app can respond to notification-related events since the plugin is initialised in the `main` function
final BehaviorSubject<ReceivedNotification> didReceiveLocalNotificationSubject =
    BehaviorSubject<ReceivedNotification>();
final BehaviorSubject<String> selectNotificationSubject =
    BehaviorSubject<String>();
class ReceivedNotification {
  final int id;
  final String title;
  final String body;
  final String payload;
  ReceivedNotification(
      {@required this.id,
      @required this.title,
      @required this.body,
      @required this.payload});
Future createNotification(title, text, channel, payload) async {
  try {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'shinobi_mobile_${channel}',
        'Shinobi Mobile',
        'Shinobi Event Notifications',
        playSound: false,
        styleInformation: DefaultStyleInformation(true, true));
    var iOSPlatformChannelSpecifics =
        IOSNotificationDetails(presentSound: false);
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin
        .show(0, title, text, platformChannelSpecifics, payload: payload);
  } catch (err, stacktrace) {
    debugLog('${err} \n ${stacktrace}');
initializeNotifications() {
  WidgetsFlutterBinding.ensureInitialized();
  var initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  var initializationSettingsIOS = IOSInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification:
          (int id, String title, String body, String payload) async {
        didReceiveLocalNotificationSubject.add(ReceivedNotification(
            id: id, title: title, body: body, payload: payload));
      });
  var initializationSettings = InitializationSettings(
      initializationSettingsAndroid, initializationSettingsIOS);
  flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onSelectNotification: (String payload) async {
    if (payload != null) {
      debugLog('notification request : ' + payload);
      var payloadPieces = payload.split(',');
      String typeOfRequest = payloadPieces[0];
      String value = payloadPieces[1];
      switch (typeOfRequest) {
        case 'live':
          debugLog(value);
          clearSelectedLiveStreamMonitors();
          liveStreamMonitors[value] = true;
          globallyOpenPage('liveStreamScreen');
          break;
        case 'video':
          storageSettings.setItem('activeVideoUrl', value);
          globallyOpenPage('recordingPlayVideo');
          break;
      }
    }
  });
// notification END />
Map<String, Map> monitors = {};
var monitorsTasks = {};
var user;
var sessionKey;
var groupKey;
var isP2P;
var loginEndpoint;
var selectedMonitorId;
var selectedMonitorName;
Map<dynamic, dynamic> liveStreamMonitors = {};
Map<dynamic, dynamic> liveStreamMonitorControllers = {};
var licenseCheckEndpoint = 'https://licenses.shinobi.video/subscribe/check';
var licenseCheckResult = false;
var loginData;
var usernameValue;
var passwordValue;
var loginEndpointValue;
var licenseKeyValue;
var $user;
var recordedVideos = [];
LocalStorage storageLogin;
LocalStorage storageSettings;
LocalStorage storageLogs;
List logsInMemory = [];
List filteredMonitorData = [];
List loadedMonitorData = [];
getApiPrefix(){
    return loginEndpoint + '/' + sessionKey;
    return isP2P == true ? loginEndpoint : loginEndpoint + '/' + sessionKey;
debugLog(theVar) {
  logsInMemory.add({
    "log": theVar.toString(),
    "time": DateTime.now().toString(),
  });
  if (logsInMemory.length > 100) logsInMemory = logsInMemory.sublist(1);
  print(theVar);
cantViewMultipleLiveStreams() {
  return false;
  // return Platform.isIOS;
createLiveStreamControllers(setStateCallback) {
  disposeLiveStreamControllers();
  Map ipCamViewerSavedStreamsSelected =
      storageSettings.getItem('ipCamViewerSavedStreamsSelected');
  if (ipCamViewerSavedStreamsSelected == null)
    ipCamViewerSavedStreamsSelected = {};
  ipCamViewerSavedStreamsSelected.forEach((streamName, savedStream) {
    liveStreamMonitorControllers[streamName] =
        new VlcPlayerController(onInit: () {
      liveStreamMonitorControllers[streamName].play();
    });
    liveStreamMonitorControllers[streamName].addListener(() {
      setStateCallback();
    });
  });
  liveStreamMonitors.forEach((monitorId, monitor) {
    switch (jsonDecode(monitors[monitorId]["details"])["stream_type"]) {
      case 'b64':
        liveStreamMonitorControllers[monitorId] =
            Completer<WebViewController>();
        break;
      default:
        liveStreamMonitorControllers[monitorId] =
            new VlcPlayerController(onInit: () {
          liveStreamMonitorControllers[monitorId].play();
        });
        liveStreamMonitorControllers[monitorId].addListener(() {
          setStateCallback();
        });
        break;
    }
  });
disposeLiveStreamControllers() {
  liveStreamMonitorControllers.forEach((monitorId, controller) {
    try {
      if (liveStreamMonitorControllers[monitorId] != null)
        liveStreamMonitorControllers[monitorId].dispose();
    } catch (err, stacktrace) {
      // debugLog('${err} \n ${stacktrace}');
    }
  });
  liveStreamMonitorControllers.clear();
bool isLoadingMonitors = false;
Future<String> getMonitorsFromServer() async {
  debugLog('getMonitorsFromServer');
  isLoadingMonitors = true;
  final url = getApiPrefix() + '/monitor/' + groupKey;
  try {
    var response = await http.get(Uri.encodeFull(url), headers: {
      "Accept": "application/json"
    }).timeout(const Duration(seconds: 15));
    if (legacyLoadingToggleValue == true) {
      debugLog('using legacy parsing');
      loadedMonitorData = jsonDecode(response.body);
      loadedMonitorData = loadedMonitorData.toList();
      setMonitorData(monitor) {
        monitors[monitor["mid"]] = monitor;
      }
      loadedMonitorData.forEach((monitor) => setMonitorData(monitor));
    } else {
      var responseBody = jsonDecode(response.body);
      debugLog('loadedMonitorDataRuntimeType');
      debugLog(loadedMonitorData.runtimeType.toString());
      if (responseBody.runtimeType.toString() != 'List<dynamic>' &&
          responseBody['mid'] != null) {
        loadedMonitorData = [];
        loadedMonitorData.add(Map.from(responseBody));
      } else {
        loadedMonitorData = responseBody;
      }
      loadedMonitorData = loadedMonitorData.toList();
      loadedMonitorData.forEach((monitor) {
        try {
          monitors['${monitor["mid"]}'] = Map.from(monitor);
        } catch (err, stacktrace) {
          debugLog('${err} \n ${stacktrace}');
        }
      });
    }
    filteredMonitorData.clear();
    filteredMonitorData.addAll(loadedMonitorData);
  } catch (err, stacktrace) {
    debugLog('${err} \n ${stacktrace}');
    debugLog('loadedMonitorDataRuntimeType');
    debugLog(loadedMonitorData.runtimeType.toString());
    debugLog('loadedMonitorDataLength');
    debugLog(loadedMonitorData.length);
    debugLog('loadedMonitorData');
    debugLog(loadedMonitorData);
  isLoadingMonitors = false;
  return "Success";
Future<String> getVideosFromServer(monitorId, callback) async {
  debugLog('getVideosFromServer');
  String videoUrl = getApiPrefix() +
      '/videos/' +
      groupKey +
      '/' +
      monitorId +
      '?limit=' +
      searchLimit;
  try {
    var startDatePieces =
        convertListStringsToInts(videoListScreenStartDateSelected.split('-'));
    var startHourPieces =
        convertListStringsToInts(videoListScreenStartTimeSelected.split(':'));
    var endDatePieces =
        convertListStringsToInts(videoListScreenEndDateSelected.split('-'));
    var endHourPieces =
        convertListStringsToInts(videoListScreenEndTimeSelected.split(':'));
    var utcTime = DateTime(
            startDatePieces[0],
            startDatePieces[1],
            startDatePieces[2],
            startHourPieces[0],
            startHourPieces[1],
            startHourPieces[2])
        .toUtc();
    var utcStartString = getHumanDate(utcTime) + 'T' + getHumanTimeRaw(utcTime);
    var utcTimeEnd = DateTime(
            endDatePieces[0],
            endDatePieces[1],
            endDatePieces[2],
            endHourPieces[0],
            endHourPieces[1],
            endHourPieces[2])
        .toUtc();
    var utcEndString =
        getHumanDate(utcTimeEnd) + 'T' + getHumanTimeRaw(utcTimeEnd);
    videoUrl = videoUrl + '&start=' + utcStartString + '&end=' + utcEndString;
    print(videoUrl);
    var response = await http.get(Uri.encodeFull(videoUrl), headers: {
      "Accept": "application/json"
    }).timeout(const Duration(seconds: 15));
    print(response.body);
    var data = jsonDecode(response.body);
    loadedVideos[monitorId] = [];
    if (data.length > 0) loadedVideos[monitorId] = data["videos"];
  } catch (err, stacktrace) {
    debugLog('${err} \n ${stacktrace}');
  callback();
  return "Success";
Future<String> getEventsFromServer(monitorId, callback) async {
  debugLog('getEventsFromServer');
  String apiUrl = getApiPrefix() +
      '/events/' +
      groupKey +
      '/' +
      monitorId +
      '?limit=200'; // + searchLimit;
  loadedEvents[monitorId] = [];
  try {
    var startDatePieces =
        convertListStringsToInts(videoListScreenStartDateSelected.split('-'));
    var startHourPieces =
        convertListStringsToInts(videoListScreenStartTimeSelected.split(':'));
    var endDatePieces =
        convertListStringsToInts(videoListScreenEndDateSelected.split('-'));
    var endHourPieces =
        convertListStringsToInts(videoListScreenEndTimeSelected.split(':'));
    var utcTime = DateTime(
            startDatePieces[0],
            startDatePieces[1],
            startDatePieces[2],
            startHourPieces[0],
            startHourPieces[1],
            startHourPieces[2])
        .toUtc();
    var utcStartString = getHumanDate(utcTime) + 'T' + getHumanTimeRaw(utcTime);
    var utcTimeEnd = DateTime(
            endDatePieces[0],
            endDatePieces[1],
            endDatePieces[2],
            endHourPieces[0],
            endHourPieces[1],
            endHourPieces[2])
        .toUtc();
    var utcEndString =
        getHumanDate(utcTimeEnd) + 'T' + getHumanTimeRaw(utcTimeEnd);
    apiUrl = apiUrl + '&start=' + utcStartString + '&end=' + utcEndString;
    var response = await http.get(Uri.encodeFull(apiUrl), headers: {
      "Accept": "application/json"
    }).timeout(const Duration(seconds: 15));
    var data = jsonDecode(response.body);
    loadedEvents[monitorId].addAll(data);
  } catch (err, stacktrace) {
    debugLog('${err} \n ${stacktrace}');
  debugLog(apiUrl);
  callback();
  return "Success";
Future<String> setVideoStatus(video, status, callback) async {
    try{
        String filename = video["filename"];
        String monitorId = video["mid"];
        String statusValue = status.toString();
        video["status"] = status;
        debugLog('setVideoStatus');
        String videoUrl = getApiPrefix() +
            '/videos/' +
            groupKey +
            '/' +
            monitorId;
        ;
        videoUrl = videoUrl + '/' + filename + '/status/' + statusValue;
        debugLog(videoUrl);
        var response = await http
            .get(Uri.encodeFull(videoUrl), headers: {"Accept": "application/json"});
    }catch(err,stacktrace){
        debugLog(err);
        debugLog(stacktrace);
    }
  callback();
  return "Success";
Future<String> deleteVideo(video, callback) async {
  String filename = video["filename"];
  String monitorId = video["mid"];
  debugLog('deleteVideo');
  String videoUrl = getApiPrefix() +
      '/videos/' +
      groupKey +
      '/' +
      monitorId;
  videoUrl = videoUrl + '/' + filename + '/delete';
  debugLog(videoUrl);
  var response = await http
      .get(Uri.encodeFull(videoUrl), headers: {"Accept": "application/json"});
  var data = jsonDecode(response.body);
  deleteVideoFromLoadedVideos(video);
  callback();
  return "Success";
deleteVideoFromLoadedVideos(video) {
  String monitorId = video["mid"];
  int index = loadedVideos[monitorId].indexOf(video);
  loadedVideos[monitorId].removeAt(index);
sanitizeHostname() {
    print('sanitizeHostname');
    print(loginEndpointValue);
    loginEndpoint = '${loginEndpointValue}';
    if (loginEndpoint.contains('?p2p=1') == true || loginEndpoint.contains('&p2p=1') == true) {
        isP2P = true;
        loginEndpoint = '${loginEndpoint}'.replaceAll('?p2p=1', '').replaceAll('&p2p=1', '');
    }
    if (loginEndpoint.endsWith('/') == true) {
        loginEndpoint = loginEndpoint.substring(0, loginEndpoint.length() - 1);
    }
    if (loginEndpointValue.contains('://') == false) {
        loginEndpoint = 'http://' + loginEndpoint;
    }
    print(loginEndpoint);
setSession(loginEndpointValue, userData, callback) {
  user = userData;
  sessionKey = user["auth_token"];
  groupKey = user["ke"];
  _disconnectWebsocket();
  _connectWebSocket(callback);
destroySession(callback) {
  user = null;
  sessionKey = null;
  groupKey = null;
  loginEndpoint = null;
  isP2P = false;
  loginData = {};
  monitors.clear();
  loadedVideos.clear();
  loadedEvents.clear();
  clearSelectedLiveStreamMonitors();
  videoListMonitorsSelected.clear();
  storageSettings.setItem(
      'videoListMonitorsSelected', videoListMonitorsSelected);
  storageSettings.setItem('liveStreamMonitors', liveStreamMonitors);
  _disconnectWebsocket();
clearSelectedLiveStreamMonitors() {
  liveStreamMonitors.forEach((monitorId, monitor) {
    websocketClient
        .emit('f', {"f": 'monitor', "ff": 'watch_off', "id": monitorId});
  });
  liveStreamMonitors.clear();
enableWatchingForLiveStreamMonitors() {
  liveStreamMonitors.forEach((monitorId, monitor) {
    websocketClient
        .emit('f', {"f": 'monitor', "ff": 'watch_on', "id": monitorId});
  });
loadDataAfterLogin(setStateCallback) async {
  await getMonitorsFromServer();
  videoListMonitorsSelected =
      storageSettings.getItem('videoListMonitorsSelected');
  if (videoListMonitorsSelected == null) videoListMonitorsSelected = {};
  videoListMonitorsSelected.forEach((monitorId, monitor) async {
    if (videoListMonitorsSelected[monitorId] != null &&
        loadedVideos[monitorId] == null) {
      videoListMonitorsSelected[monitorId] = true;
      await getVideosFromServer(monitorId, () {
        setStateCallback();
      });
    }
  });
getSessionError(error, callback) {
  if (error != null) {
    debugLog('loginPostError');
    var errorString = error.toString().toLowerCase();
    debugLog(errorString);
    errorContains(text) {
      return errorString.contains(text);
    }
    String msg = '';
    if (errorContains('connection refused')) {
      msg = 'REFUSED';
    } else if (errorContains('timeout')) {
      msg = 'TIMEOUT';
    } else {
      msg = errorString;
    }
    callback(msg);
bool attemptingLogin = false;
bool isConnectingToShinobi = false;
grazeResponse(loginData) {
  if (loginData["ok"] == true &&
      loginData["\$user"] != null &&
      loginData["\$user"]['details'] != null) {
    $user = loginData["\$user"];
  } else if (loginData["ok"] == true && loginData["\$user"] != null) {
    factorAuthResponse = loginData["\$user"];
Future<String> twoFactorPost(callback) async {
  isConnectingToShinobi = true;
  try {
    attemptingLogin = true;
    String machineID = storageSettings.getItem('machineID');
    if (machineID == null) {
      machineID = randomAlphaNumeric(10);
      storageSettings.setItem('machineID', machineID);
    }
    debugLog('factorAuthKeyText');
    debugLog(factorAuthKeyText);
    var response = await http.post(loginEndpoint + '?json=true', body: {
      'machineID': machineID,
      'ke': factorAuthResponse['ke'],
      'id': factorAuthResponse['uid'],
      'factorAuthKey': factorAuthKeyText,
      "remember": "1"
    }).timeout(new Duration(seconds: 10));
    loginData = jsonDecode(response.body);
    grazeResponse(loginData);
    attemptingLogin = false;
    callback(null);
  } catch (e) {
    attemptingLogin = false;
    callback(e);
  isConnectingToShinobi = false;
  return "Success!";
Future<String> loginPost(callback) async {
  isConnectingToShinobi = true;
  try {
    // if(attemptingLogin == false){
    debugLog('loginPost');
    debugLog(usernameValue);
    String machineID = storageSettings.getItem('machineID');
    if (machineID == null) {
      machineID = randomAlphaNumeric(10);
      storageSettings.setItem('machineID', machineID);
    }
    attemptingLogin = true;
    print(loginEndpoint + '?json=true');
    var response = await http.post(loginEndpoint + '?json=true', body: {
      'machineID': machineID,
      'mail': usernameValue,
      'pass': passwordValue,
      'function': "dash"
    }).timeout(new Duration(seconds: 10));
    loginData = jsonDecode(response.body);
    grazeResponse(loginData);
    attemptingLogin = false;
    callback(null);
    // }
  } catch (e) {
    attemptingLogin = false;
    callback(e);
  isConnectingToShinobi = false;
  return "Success!";
autoLogin(setStateCallback) async {
  if (storageSettings != null) {
    licenseCheckResult = storageSettings.getItem('licenseCheckResult');
    licenseCheckResult =
        (licenseCheckResult != null ? licenseCheckResult : false);
  // AUTO LOGIN >>
  if (licenseCheckResult == false) {
    String initialValueLicenseKey;
    initialValueLicenseKey = storageLogin.getItem('licenseKey');
    if (initialValueLicenseKey == null) initialValueLicenseKey = '';
    licenseKeyValue = initialValueLicenseKey;
    if (licenseKeyValue != '') {
      await licenseCheck(licenseKeyValue);
    }
  if (storageLogin != null) {
    String initialValueLoginEndpoint = storageLogin.getItem('loginEndpoint');
    if (initialValueLoginEndpoint == null) initialValueLoginEndpoint = '';
    loginEndpointValue = initialValueLoginEndpoint;
    String initialValueEmail = storageLogin.getItem('email');
    if (initialValueEmail == null) initialValueEmail = '';
    usernameValue = initialValueEmail;
    String initialValuePassword = storageLogin.getItem('password');
    if (initialValuePassword == null) initialValuePassword = '';
    passwordValue = initialValuePassword;
    if (initialValueLoginEndpoint != '' &&
        initialValueEmail != '' &&
        initialValuePassword != '') {
            sanitizeHostname();
      await loginPost((error) => getSessionError(error, (errorMsg) {
            debugLog(errorMsg);
          }));
      if (loginData["ok"] == true) {
        setSession(loginEndpointValue, $user, () {
          enableWatchingForLiveStreamMonitors();
          setStateCallback();
        });
        loadDataAfterLogin(() {
          setStateCallback();
        });
        debugLog('Auto Login Succeded');
      } else {
        debugLog('Auto Login Failed');
      }
    }
Future<String> licenseCheck(subscriptionId) async {
  var dateNow = new DateTime.now();
  var lastDateLogged = storageSettings.getItem('licenseCheckResultDate');
  var lastSubscriptionId = storageSettings.getItem('lastSubscriptionId');
  lastDateLogged =
      lastDateLogged != null ? DateTime.parse(lastDateLogged) : dateNow;
  if (licenseCheckResult == false ||
      dateNow.difference(lastDateLogged).inDays > 7 ||
      lastSubscriptionId != subscriptionId) {
    storageSettings.setItem('lastSubscriptionId', subscriptionId);
    try {
      var response = await http.post(licenseCheckEndpoint, body: {
        'subscriptionId': subscriptionId
      }).timeout(const Duration(seconds: 10));
      debugLog(response.body);
      try {
        licenseCheckResult = jsonDecode(response.body)["ok"];
      } catch (err, stacktrace) {
        debugLog('${err} \n ${stacktrace}');
      }
      return licenseCheckResult != false ? "Success" : "Failure";
    } on TimeoutException catch (e) {
      licenseCheckResult = false;
      return "Failure";
    } on Error catch (e) {
      licenseCheckResult = false;
      return "Failure";
    }
    storageSettings.setItem('licenseCheckResultDate', dateNow.toString());
  storageSettings.setItem('licenseCheckResult', licenseCheckResult);
_createHeaderText(textChoice, iconChoice, orientationIsLandscape) {
  return Container(
    decoration: BoxDecoration(
      color: primaryHeaderColor,
    ),
    margin: EdgeInsets.only(bottom: 10.0),
    child: Column(children: <Widget>[
      Padding(
        padding: EdgeInsets.only(top: 25.0, left: 0, bottom: 25),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 1,
              child: Padding(
                  padding: EdgeInsets.only(
                      left: orientationIsLandscape ? 40 : 15, right: 15),
                  child: Icon(iconChoice, color: colorWhite)),
            ),
            Expanded(
              flex: 6,
              child: Padding(
                padding:
                    EdgeInsets.only(left: orientationIsLandscape ? 40 : 15),
                child: Text(
                  textChoice,
                  style: new TextStyle(
                      fontSize: 30.0,
                      color: colorWhite,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    ]),
  );
_createHeaderBlockRow(list) {
  return Container(
    decoration: BoxDecoration(
      color: primaryHeaderColor,
    ),
    margin: EdgeInsets.only(bottom: 10.0),
    child: Column(children: <Widget>[
      Padding(
        padding: EdgeInsets.only(top: 25.0, left: 0, bottom: 25),
        child: Row(
          children: list,
        ),
      ),
    ]),
  );
createIcon(iconSelection, iconColor, double iconSize) {
  return new Icon(
    iconSelection,
    color: iconColor,
    size: iconSize,
  );
createFittedBox(child, double size) {
  return Container(
      width: size,
      height: size,
      child:
          FittedBox(child: Padding(padding: EdgeInsets.all(4), child: child)));
setOrientationPortrait() {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);
setOrientationLandscape(callback) {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);
  callback();
// MAIN PAGE >
final GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();
var forceMonitorListRefresh = false;
double liveStreamGridRowCount = 2;
bool eventNotificationsToggleValue = true;
bool legacyLoadingToggleValue = false;
globallyOpenPage(String page) {
  navigatorKey.currentState.pushNamed('/' + page);
void main() {
  initializeNotifications();
  runApp(MyApp());
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shinobi Mobile Client',
      navigatorKey: navigatorKey,
      routes: {
        '/loginScreen': (context) => loginScreen(),
        '/licenseScreen': (context) => licenseScreen(),
        '/recordingPlayVideo': (context) => recordingPlayVideo(),
        '/videoListScreen': (context) => videoListScreen(),
        '/liveStreamScreen': (context) => liveStreamScreen(),
        '/ipCamViewer': (context) => ipCamViewer(),
        '/languageSettings': (context) => languageSettings(),
        '/aboutPage': (context) => aboutPage(),
        '/logViewerScreen': (context) {
          if (storageLogs == null) storageLogs = LocalStorage('Logs.json');
          storageLogs.setItem('logsInMemory', logsInMemory);
          return logViewerScreen();
        },
        // '/settingsScreen': (context) => settingsScreen(),
      },
      theme: ThemeData(
        primarySwatch: primarySwatch,
      ),
      home: MyHomePage(title: lang['appTitle']),
    );
//Main Page (Home Screen)
class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
class _MyHomePageState extends State<MyHomePage> {
  Widget toggleNotificationsWidget() {
    bool eventNotificationsToggleInitialValue;
    eventNotificationsToggleInitialValue =
        storageSettings.getItem('eventNotificationsToggle');
    if (eventNotificationsToggleInitialValue == null)
      eventNotificationsToggleInitialValue = true;
    eventNotificationsToggleValue = eventNotificationsToggleInitialValue;
    return SwitchListTile(
        title: Text(lang['Event Notifications'],
            style: TextStyle(color: colorWhite)),
        value: eventNotificationsToggleValue,
        secondary: Icon(
            eventNotificationsToggleValue
                ? Icons.notifications
                : Icons.notifications_off,
            color: colorWhite),
        activeColor: colorWhite,
        onChanged: (bool value) async {
          eventNotificationsToggleValue = !eventNotificationsToggleValue;
          storageSettings.setItem(
              'eventNotificationsToggle', eventNotificationsToggleValue);
          setState(() {});
        });
  Widget toggleLegacyLoadingWidget() {
    bool legacyLoadingToggleValueInitialValue;
    legacyLoadingToggleValueInitialValue =
        storageSettings.getItem('legacyLoadingToggleValue');
    if (legacyLoadingToggleValueInitialValue == null)
      legacyLoadingToggleValueInitialValue = false;
    legacyLoadingToggleValue = legacyLoadingToggleValueInitialValue;
    return SwitchListTile(
        title:
            Text(lang['Legacy Loading'], style: TextStyle(color: colorWhite)),
        value: legacyLoadingToggleValue,
        secondary: Icon(Icons.device_hub, color: colorWhite),
        activeColor: colorWhite,
        onChanged: (bool value) async {
          legacyLoadingToggleValue = !legacyLoadingToggleValue;
          storageSettings.setItem(
              'legacyLoadingToggleValue', legacyLoadingToggleValue);
          setState(() {});
        });
  createLiveStreamGridRowCountMenuItem(orientationIsLandscape) {
    double liveStreamGridRowCountInitialValue;
    liveStreamGridRowCountInitialValue =
        storageSettings.getItem('liveStreamGridRowCount');
    if (liveStreamGridRowCountInitialValue == null)
      liveStreamGridRowCountInitialValue = 2;
    liveStreamGridRowCount = liveStreamGridRowCountInitialValue;
    return Padding(
        padding: EdgeInsets.only(left: orientationIsLandscape ? 30 : 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: EdgeInsets.only(left: 0, bottom: 5, top: 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(Icons.live_tv, color: colorWhite)),
                ),
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: EdgeInsets.only(left: 0),
                    child: Text(lang['Live Streams'],
                        style: TextStyle(color: colorWhite)),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Text(
                        '${liveStreamGridRowCount.toStringAsFixed(0)} ${lang["per row"]}',
                        style: TextStyle(fontSize: 11.5, color: colorWhite),
                        textAlign: TextAlign.right),
                  ),
                )
              ],
            ),
          ),
          Slider(
            activeColor: colorWhite,
            min: 1,
            max: 5,
            onChanged: (newRating) {
              final value = double.parse(newRating.toStringAsFixed(0));
              storageSettings.setItem('liveStreamGridRowCount', value);
              liveStreamGridRowCount = double.parse(value.toString());
              setState(() {});
            },
            value: liveStreamGridRowCount,
          ),
        ]));
// Monitor List >
  TextEditingController editingController = TextEditingController();
  drawList() {
    return sessionKey == null ||
            isLoadingMonitors == true ||
            isConnectingToShinobi == true ||
            monitors.length == 0
        ? Padding(
            padding: EdgeInsets.all(15),
            child: Column(
              children: <Widget>[
                Card(
                  color: primaryCardBackgroundColor,
                  child: Padding(
                    padding: EdgeInsets.only(top: 15, bottom: 15),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        sessionKey == null
                            ? ListTile(
                                leading:
                                    Icon(Icons.router, color: blipTextColor),
                                title: Text(lang['connectToAShinobiInstance'],
                                    style: TextStyle(color: blipTextColor)),
                                subtitle: Text(
                                    lang['connectToAShinobiInstanceText'],
                                    style: TextStyle(color: blipTextColor)),
                                onTap: () {
                                  openPage(context, 'loginScreen');
                                },
                              )
                            : monitors.length == 0
                                ? ListTile(
                                    leading: Icon(Icons.router,
                                        color: blipTextColor),
                                    title: Text(lang['noMonitorsLoaded'],
                                        style: TextStyle(color: blipTextColor)),
                                    subtitle: Text(lang['noMonitorsLoadedText'],
                                        style: TextStyle(color: blipTextColor)),
                                    onTap: () {
                                      setState(() {});
                                    },
                                  )
                                : isLoadingMonitors == true ||
                                        isConnectingToShinobi == true
                                    ? ListTile(
                                        leading: Icon(Icons.router,
                                            color: blipTextColor),
                                        title: Text(
                                            isLoadingMonitors == true
                                                ? '${lang["monitorsLoading"]}...'
                                                : isConnectingToShinobi == true
                                                    ? '${lang["connectingToYourShinobi"]}...'
                                                    : lang['howDidThisHappen'],
                                            style: TextStyle(
                                                color: blipTextColor)),
                                        subtitle: Text(
                                            '${lang["Please Wait"]}...',
                                            style: TextStyle(
                                                color: blipTextColor)),
                                        onTap: () {
                                          setState(() {});
                                        },
                                      )
                                    : Container()
                      ],
                    ),
                  ),
                ),
              ],
            ))
        : new Container(
            padding: EdgeInsets.only(bottom: 25),
            color: primaryBackgroundColor,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: TextField(
                    style: TextStyle(color: colorWhite),
                    onChanged: (value) {
                      filterSearchResults(value);
                    },
                    controller: editingController,
                    decoration: InputDecoration(
                        filled: true,
                        fillColor: primaryInputFillColor,
                        labelText: lang["Monitors"],
                        labelStyle: TextStyle(color: colorWhite),
                        hintText: lang["Search"],
                        hintStyle: TextStyle(color: secondaryTextColor),
                        prefixIcon:
                            Icon(Icons.search, color: secondaryTextColor),
                        border: OutlineInputBorder(
                            borderSide:
                                new BorderSide(color: secondaryTextColor),
                            borderRadius:
                                BorderRadius.all(Radius.circular(25.0)))),
                  ),
                ),
                Expanded(
                  child: new Padding(
                    padding: new EdgeInsets.all(2.0),
                    child: new ListView.builder(
                        itemCount: filteredMonitorData == null
                            ? 0
                            : filteredMonitorData.length,
                        itemBuilder: (BuildContext context, int index) {
                          String monitorId = filteredMonitorData[index]["mid"];
                          String streamType =
                              jsonDecode(filteredMonitorData[index]["details"])[
                                  'stream_type'];
                          String hostTag =
                              '${filteredMonitorData[index]["protocol"]}://${filteredMonitorData[index]["host"]}';
                          if (hostTag.length > 22)
                            hostTag = hostTag.substring(0, 22) + '...';
                          return new Card(
                            color: primaryCardBackgroundColor,
                            margin: EdgeInsets.all(8.0),
                            child: new InkWell(
                              child: new Column(
                                children: <Widget>[
                                  new Padding(
                                      padding: new EdgeInsets.all(3.0),
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            new ListTile(
                                                title: Container(
                                                    child: new Row(children: <
                                                        Widget>[
                                                  Container(
                                                      padding: EdgeInsets.only(
                                                          bottom: 10, top: 10),
                                                      child: Row(children: [
                                                        Text(
                                                            filteredMonitorData[
                                                                index]["name"],
                                                            style: TextStyle(
                                                              color: colorWhite,
                                                              fontSize: 22.0,
                                                            ))
                                                      ])),
                                                  Expanded(child: Container()),
                                                  monitorsTasks[monitorId] !=
                                                              null &&
                                                          monitorsTasks[
                                                                      monitorId]
                                                                  ["icon"] !=
                                                              null
                                                      ? Container(
                                                          padding:
                                                              EdgeInsets.only(
                                                                  top: 15),
                                                          child: SizedBox(
                                                              width: 30,
                                                              height: 30,
                                                              child: ClipRRect(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8.0),
                                                                child: monitorsTasks[
                                                                        monitorId]
                                                                    ["icon"],
                                                              )))
                                                      : Container()
                                                ])),
                                                subtitle:
                                                    Row(children: <Widget>[
                                                  Badge(
                                                      badgeColor: filteredMonitorData[index]
                                                                  ["status"] ==
                                                              'Watching'
                                                          ? watchingColor
                                                          : filteredMonitorData[index]
                                                                      [
                                                                      "status"] ==
                                                                  'Recording'
                                                              ? recordingColor
                                                              : filteredMonitorData[index]["status"] ==
                                                                      'Stopped'
                                                                  ? disabledColor
                                                                  : colorYellow,
                                                      shape: BadgeShape.square,
                                                      borderRadius: 10,
                                                      toAnimate: false,
                                                      badgeContent: Text(
                                                          filteredMonitorData[index]
                                                                  ["status"]
                                                              .toUpperCase(),
                                                          style: TextStyle(
                                                              color: colorWhite))),
                                                  Container(
                                                      padding: EdgeInsets.only(
                                                          right: 10)),
                                                  Badge(
                                                    badgeColor: streamType !=
                                                                'hls' &&
                                                            streamType !=
                                                                'mp4' &&
                                                            streamType !=
                                                                'mjpeg' &&
                                                            streamType != 'flv'
                                                        ? dangerColor
                                                        : primaryBadgeColor,
                                                    shape: BadgeShape.square,
                                                    borderRadius: 10,
                                                    toAnimate: false,
                                                    badgeContent: Text(
                                                        streamType
                                                            .toUpperCase(),
                                                        style: TextStyle(
                                                            color: colorWhite)),
                                                  ),
                                                ])),
                                            new Padding(
                                              padding: new EdgeInsets.only(
                                                  left: 15, top: 5),
                                              child: Row(children: <Widget>[
                                                Badge(
                                                    badgeColor:
                                                        primaryBadgeColor,
                                                    shape: BadgeShape.square,
                                                    borderRadius: 10,
                                                    toAnimate: false,
                                                    badgeContent: Text(hostTag,
                                                        style: TextStyle(
                                                            color:
                                                                colorWhite))),
                                                new Expanded(
                                                    child: Container()),
                                                IconButton(
                                                  icon: Icon(
                                                      Icons.personal_video,
                                                      color: colorWhite),
                                                  onPressed: () {
                                                    clearSelectedLiveStreamMonitors();
                                                    if (liveStreamMonitors[
                                                            monitorId] ==
                                                        null) {
                                                      liveStreamMonitors[
                                                          monitorId] = true;
                                                      websocketClient.emit(
                                                          'f', {
                                                        "f": 'monitor',
                                                        "ff": 'watch_on',
                                                        "id": monitorId
                                                      });
                                                    }
                                                    openPage(context,
                                                        'liveStreamScreen');
                                                    storageSettings.setItem(
                                                        'liveStreamMonitors',
                                                        liveStreamMonitors);
                                                    setState(() {});
                                                  },
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                      Icons.video_library,
                                                      color: colorWhite),
                                                  onPressed: () {
                                                    videoListMonitorsSelected
                                                        .clear();
                                                    loadedVideos.clear();
                                                    videoListMonitorsSelected[
                                                        monitorId] = true;
                                                    getVideosFromServer(
                                                        monitorId, () {
                                                      openPage(context,
                                                          'videoListScreen');
                                                    });
                                                    storageSettings.setItem(
                                                        'videoListMonitorsSelected',
                                                        videoListMonitorsSelected);
                                                  },
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                      cantViewMultipleLiveStreams()
                                                          ? Icons.live_tv
                                                          : liveStreamMonitors[
                                                                      monitorId] ==
                                                                  null
                                                              ? Icons
                                                                  .check_box_outline_blank
                                                              : Icons.check_box,
                                                      color: liveStreamMonitors[
                                                                  monitorId] ==
                                                              null
                                                          ? primaryTextColor
                                                          : primarySelectedTextColor),
                                                  onPressed: () {
                                                    if (liveStreamMonitors[
                                                            monitorId] ==
                                                        null) {
                                                      liveStreamMonitors[
                                                          monitorId] = true;
                                                      websocketClient.emit(
                                                          'f', {
                                                        "f": 'monitor',
                                                        "ff": 'watch_on',
                                                        "id": monitorId
                                                      });
                                                    } else {
                                                      liveStreamMonitors
                                                          .remove(monitorId);
                                                      websocketClient.emit(
                                                          'f', {
                                                        "f": 'monitor',
                                                        "ff": 'watch_off',
                                                        "id": monitorId
                                                      });
                                                    }
                                                    storageSettings.setItem(
                                                        'liveStreamMonitors',
                                                        liveStreamMonitors);
                                                    setState(() {});
                                                  },
                                                ),
                                              ]),
                                            ),
                                          ])),
                                ],
                              ),
                            ),
                          );
                        }),
                  ),
                ),
              ],
            ),
          );
  void filterSearchResults(String query) {
    List dummySearchList = [];
    dummySearchList.addAll(loadedMonitorData);
    if (query.isNotEmpty) {
      List dummyListData = [];
      dummySearchList.forEach((monitor) {
        if (jsonEncode(monitor).contains(query)) {
          dummyListData.add(monitor);
        }
      });
      setState(() {
        filteredMonitorData.clear();
        filteredMonitorData.addAll(dummyListData);
      });
      return;
    } else {
      setState(() {
        filteredMonitorData.clear();
        filteredMonitorData.addAll(loadedMonitorData);
      });
    }
  Widget monitorListPage() {
    doFutureBuild() {
      return FutureBuilder(
        builder: (context, projectSnap) {
          return drawList();
        },
        future: getMonitorsFromServer(),
      );
    }
    if (forceMonitorListRefresh == true) {
      forceMonitorListRefresh = false;
      return doFutureBuild();
    } else if (loadedMonitorData == null) {
      forceMonitorListRefresh = false;
      return doFutureBuild();
    } else {
      return drawList();
    }
// Monitor List END />
  @override
  void initState() {
    debugLog('initStateForMain');
    storageLogin = new LocalStorage('Login.json');
    storageSettings = new LocalStorage('Settings.json');
    storageLogs = new LocalStorage('Logs.json');
    super.initState();
    _requestIOSPermissions();
    _configureDidReceiveLocalNotificationSubject();
    _configureSelectNotificationSubject();
    new Timer(new Duration(seconds: 2), () async {
      await autoLogin(() {
        setState(() {});
      });
      // AUTO LOGIN />>
      liveStreamMonitors = storageSettings.getItem('liveStreamMonitors');
      if (liveStreamMonitors == null) liveStreamMonitors = {};
      setState(() {});
    });
  void persist(bool value) {
    setState(() {});
  @override
  void dispose() {
    _disconnectWebsocket();
    didReceiveLocalNotificationSubject.close();
    selectNotificationSubject.close();
    super.dispose();
  void _requestIOSPermissions() {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  void _configureDidReceiveLocalNotificationSubject() {
    didReceiveLocalNotificationSubject.stream
        .listen((ReceivedNotification receivedNotification) async {
      await showDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: receivedNotification.title != null
              ? Text(receivedNotification.title)
              : null,
          content: receivedNotification.body != null
              ? Text(receivedNotification.body)
              : null,
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: Text('Ok'),
              onPressed: () async {
                Navigator.of(context, rootNavigator: true).pop();
                // openPage(context,'recordingPlayVideo');
              },
            )
          ],
        ),
      );
    });
  void _configureSelectNotificationSubject() {
    selectNotificationSubject.stream.listen((String payload) async {
      print(payload);
      // await Navigator.push(
      //   context,
      //   MaterialPageRoute(builder: (context) => SecondScreen(payload)),
      // );
    });
  @override
  Widget build(BuildContext context) {
    var orientationIsLandscape =
        (MediaQuery.of(context).orientation == Orientation.landscape);
    List menuSettingsWidgets = <Widget>[
      createLiveStreamGridRowCountMenuItem(orientationIsLandscape),
      Divider(
        color: primaryFadedBackgroundColor,
      ),
      toggleNotificationsWidget(),
      Divider(
        color: primaryFadedBackgroundColor,
      ),
      toggleLegacyLoadingWidget(),
    ];
    return Scaffold(
      backgroundColor: primaryBackgroundColor,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: primaryHeaderColor,
        actions: <Widget>[
          IconButton(
            icon: Icon(liveStreamMonitors.length > 0
                ? Icons.check_box
                : Icons.check_box_outline_blank),
            onPressed: () {
              if (liveStreamMonitors.length > 0) {
                clearSelectedLiveStreamMonitors();
              } else {
                monitors.forEach((monitorId, monitor) {
                  websocketClient.emit(
                      'f', {"f": 'monitor', "ff": 'watch_on', "id": monitorId});
                  liveStreamMonitors[monitorId] = true;
                });
              }
              storageSettings.setItem('liveStreamMonitors', liveStreamMonitors);
              setState(() {});
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              forceMonitorListRefresh = true;
              setState(() {});
            },
          ),
          IconButton(
            icon: Icon(Icons.live_tv),
            onPressed: () {
              openPage(context, 'liveStreamScreen');
            },
          ),
        ].reversed.toList(),
      ),
      body: monitorListPage(),
      floatingActionButton: sessionKey == null
          ? FloatingActionButton(
              backgroundColor: floatingButtonDefaultColor,
              onPressed: () {
                openPage(context, 'loginScreen');
              },
              child: Icon(Icons.router),
            )
          : FloatingActionButton(
              onPressed: () {
                openPage(context, 'liveStreamScreen');
              },
              child: Icon(Icons.live_tv, color: colorWhite),
              backgroundColor: primaryBadgeColor,
            ),
      // main menu >
      drawer: Theme(
        data: Theme.of(context).copyWith(
          canvasColor:
              primaryBackgroundColor, //This will change the drawer background to blue.
          //other styles
        ),
        child: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              Container(
                padding: EdgeInsets.only(bottom: 25),
                decoration: BoxDecoration(
                  color: primaryHeaderColor,
                ),
              ),
              _createHeaderBlockRow(<Widget>[
                Expanded(
                  flex: 7,
                  child: Padding(
                    padding: EdgeInsets.only(left: 15),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${lang["appTitle"]} : ${(websocketClient != null && websocketClient.connected ? lang['Connected'] : lang['Disconnected'])}',
                            style: new TextStyle(
                              fontSize: 12.0,
                              color: colorWhite,
                            ),
                          ),
                          Text(
                            '${lang["activatedClient"]} : ${(licenseCheckResult ? lang['Yes'] : lang['No'])}',
                            style: new TextStyle(
                              fontSize: 12.0,
                              color: colorWhite,
                            ),
                          )
                        ]),
                  ),
                ),
              ]),
              Divider(
                color: primaryFadedBackgroundColor,
              ),
              sessionKey != null && !cantViewMultipleLiveStreams()
                  ? Column(children: [
                      ListTile(
                        leading: Icon(Icons.live_tv, color: colorWhite),
                        title: Text(
                          lang['Live Streams'],
                          style: TextStyle(color: colorWhite),
                        ),
                        onTap: () {
                          openPage(context, 'liveStreamScreen');
                        },
                      ),
                      Divider(
                        color: primaryFadedBackgroundColor,
                      ),
                    ])
                  : Container(),
              sessionKey != null
                  ? Column(children: [
                      ListTile(
                        leading: Icon(Icons.video_library, color: colorWhite),
                        title: Text(
                          lang['Recordings'],
                          style: TextStyle(color: colorWhite),
                        ),
                        onTap: () {
                          openPage(context, 'videoListScreen');
                        },
                      ),
                      Divider(
                        color: primaryFadedBackgroundColor,
                      ),
                    ])
                  : Container(),
              ListTile(
                leading: Icon(Icons.router, color: colorWhite),
                title: Text(
                  lang['connectYourShinobi'],
                  style: TextStyle(color: colorWhite),
                ),
                onTap: () {
                  openPage(context, 'loginScreen');
                },
              ),
              Divider(
                color: primaryFadedBackgroundColor,
              ),
              ListTile(
                leading: Icon(Icons.lock_open, color: colorWhite),
                title: Text(
                  '${(licenseCheckResult ? lang['activatedClient'] : lang['Activate License'])}',
                  style: TextStyle(color: colorWhite),
                ),
                onTap: () {
                  openPage(context, 'licenseScreen');
                },
              ),
              Divider(
                color: primaryFadedBackgroundColor,
              ),
              ListTile(
                leading: Icon(Icons.tap_and_play, color: colorWhite),
                title: Text(
                  lang['Direct Streams'],
                  style: TextStyle(color: colorWhite),
                ),
                onTap: () {
                  openPage(context, 'ipCamViewer');
                },
              ),
              Divider(
                color: primaryFadedBackgroundColor,
              ),
              ListTile(
                leading: Icon(Icons.bug_report, color: colorWhite),
                title: Text(
                  lang['Logs'],
                  style: TextStyle(color: colorWhite),
                ),
                onTap: () {
                  openPage(context, 'logViewerScreen');
                },
              ),
              Divider(
                color: primaryFadedBackgroundColor,
              ),
              ListTile(
                leading: Icon(Icons.language, color: colorWhite),
                title: Text(
                  lang['languageSettings'],
                  style: TextStyle(color: colorWhite),
                ),
                onTap: () {
                  openPage(context, 'languageSettings');
                },
              ),
              Divider(
                color: primaryFadedBackgroundColor,
              ),
              ListTile(
                leading: Icon(Icons.person_pin, color: colorWhite),
                title: Text(
                  lang['aboutPage'],
                  style: TextStyle(color: colorWhite),
                ),
                onTap: () {
                  openPage(context, 'aboutPage');
                },
              ),
              menuSettingsWidgets.length > 0
                  ? Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: _createHeaderText(lang['Settings'],
                          Icons.settings_applications, orientationIsLandscape))
                  : Container(),
              Column(children: menuSettingsWidgets),
            ],
          ),
        ),
      ),
      // main menu />
    );
// MAIN PAGE END />
// websocket >
IO.Socket websocketClient;
var connectionsSinceStart = 1;
var allowConnect = true;
_connectWebSocket(callbackOnConnect) {
  if (loginEndpoint != null &&
      groupKey != null &&
      sessionKey != null &&
      allowConnect) {
          var queryString = '';
          var parsedEndpoint = loginEndpoint
              .replaceAll('http://', 'ws://')
              .replaceAll('https://', 'wss://');
          if(parsedEndpoint.contains('shinobi.cloud') == true){
              parsedEndpoint = 'shinobi.cloud:8000';
          }
          if(isP2P){
              var splitEndpoint = parsedEndpoint.split('/').toList();
              var machineId = '${splitEndpoint[splitEndpoint.length - 1]}';
              print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!11111111111');
              print(machineId);
              queryString = 'machineId=${machineId}';
          }
    allowConnect = false;
    debugLog('websocketClient CONNECT ATTEMPT # ${connectionsSinceStart}');
    ++connectionsSinceStart;
    websocketClient = IO.io(parsedEndpoint, <String, dynamic>{
      'transports': ['websocket'],
      'query': queryString != '' ? queryString : null
    });
    websocketClient.on('connect', (_) {
      debugLog('websocketClient CONNECTED');
      websocketClient.emit('f', {
        'f': 'init',
        'ke': groupKey,
        'auth': sessionKey,
        'uid': user["uid"],
      });
    });
    websocketClient.on('ping', (data) {
      websocketClient.emit('pong', {"beat": 1});
    });
    websocketClient.on('f', (data) {
      try {
        // debugLog(data);
        // if(data['f'] == 'init_success'){
        //     debugLog('init_success');
        // }
        switch (data['f']) {
          case 'init_success':
            debugLog('init_success');
            callbackOnConnect();
            break;
          case 'detector_trigger':
            createNotification('Detector Trigger', 'Open live stream',
                data['mid'], 'live,${data['id']}');
            break;
          case 'video_build_success':
            if (data['events'] != null) {
              createNotification(
                  'Video with Events Created',
                  'Play video',
                  data['mid'],
                  'video,' +
                      getApiPrefix() +
                      data['hrefNoAuth']);
            }
            break;
          case 'monitor_snapshot':
            debugLog('monitor_snapshot');
            if (monitorsTasks[data["mid"]] == null)
              monitorsTasks[data["mid"]] = {};
            switch (data["snapshot_format"]) {
              case 'plc':
                String text = data["snapshot"];
                break;
              case 'b64':
                String base64Image = data["snapshot"];
                Uint8List bytes = base64Decode(base64Image);
                monitorsTasks[data["mid"]]["icon"] = new Image.memory(bytes);
                break;
            }
            callbackOnConnect();
            break;
          case 'monitor_edit':
            monitors[data["mid"]] = data["mon"];
            if (monitorsTasks[data["mid"]] == null)
              monitorsTasks[data["mid"]] = {};
            break;
          case 'disable_stream':
            if (monitorsTasks[data["mid"]] == null)
              monitorsTasks[data["mid"]] = {};
            monitorsTasks[data["mid"]]["allowStream"] = false;
            break;
          case 'enable_stream':
            if (monitorsTasks[data["mid"]] == null)
              monitorsTasks[data["mid"]] = {};
            monitorsTasks[data["mid"]]["allowStream"] = true;
            break;
        }
      } catch (err, stacktrace) {
        debugLog('${err} \n ${stacktrace}');
      }
    });
    websocketClient.on('disconnect', (_) {
      debugLog('websocketClient.disconnected');
      checkWebsocket(true);
    });
    checkWebsocket(false);
checkWebsocket(loop) {
  debugLog('Checking websocketClient.connected status...');
  new Timer(new Duration(seconds: 5), () {
    if (websocketClient != null || websocketClient.connected != true) {
      websocketClient.connect();
      new Timer(new Duration(seconds: 30), () {
        debugLog('websocketClient.connected : ${websocketClient.connected}');
        if (loop == true && websocketClient.connected != true) {
          checkWebsocket(true);
        }
      });
    } else {
      debugLog('websocketClient.connected : ${websocketClient.connected}');
    }
  });
_disconnectWebsocket() {
  try {
    if (websocketClient.connected) {
      websocketClient.disconnect();
    }
    websocketClient.destroy();
    websocketClient = null;
    allowConnect = true;
  } catch (e) {
    debugLog('WEBSOCKET DISCONNECT ERROR');
    debugLog(e);
//websocket END />
// Login Screen
String loginMsgTitle;
String loginMsgText;
Map factorAuthResponse;
String factorAuthKeyText = '';
class loginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
class _LoginScreenState extends State<loginScreen> {
  @override
  Widget build(BuildContext context) {
    // Login WINDOW >
    String initialValueLoginEndpoint;
    String initialValueEmail;
    String initialValuePassword;
    if (storageLogin != null) {
      initialValueLoginEndpoint = storageLogin.getItem('loginEndpoint');
      if (initialValueLoginEndpoint == null) initialValueLoginEndpoint = '';
      loginEndpointValue = initialValueLoginEndpoint;
      initialValueEmail = storageLogin.getItem('email');
      if (initialValueEmail == null) initialValueEmail = '';
      usernameValue = initialValueEmail;
      initialValuePassword = storageLogin.getItem('password');
      if (initialValuePassword == null) initialValuePassword = '';
      passwordValue = initialValuePassword;
    }
    final email = TextFormField(
      keyboardType: TextInputType.emailAddress,
      autofocus: false,
      initialValue: initialValueEmail,
      onChanged: (text) async {
        storageLogin.setItem('email', text);
        usernameValue = text;
      },
      style: TextStyle(
        color: colorWhite,
      ),
      decoration: InputDecoration(
        hintText: 'Email / Username',
        contentPadding: EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(32.0)),
        fillColor: primaryInputFillColor,
        filled: true,
      ),
    );
    final password = TextFormField(
      autofocus: false,
      initialValue: initialValuePassword,
      obscureText: true,
      onChanged: (text) {
        storageLogin.setItem('password', text);
        passwordValue = text;
      },
      style: TextStyle(
        color: colorWhite,
      ),
      decoration: InputDecoration(
        hintText: 'Password',
        contentPadding: EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(32.0)),
        fillColor: primaryInputFillColor,
        filled: true,
      ),
    );
    final loginEndpointField = TextFormField(
      autofocus: false,
      initialValue: initialValueLoginEndpoint,
      onChanged: (text) {
        storageLogin.setItem('loginEndpoint', text);
        loginEndpointValue = text;
      },
      style: TextStyle(
        color: colorWhite,
      ),
      decoration: InputDecoration(
        hintText: 'http://xxx.xxx.xxx.xxx:8080',
        contentPadding: EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(32.0)),
        fillColor: primaryInputFillColor,
        filled: true,
      ),
    );
    final factorAuthKey = TextFormField(
      autofocus: false,
      initialValue: factorAuthKeyText,
      onChanged: (text) {
        factorAuthKeyText = text;
      },
      style: TextStyle(
        color: colorWhite,
      ),
      decoration: InputDecoration(
        hintText: '420420',
        contentPadding: EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(32.0)),
        fillColor: primaryInputFillColor,
        filled: true,
      ),
    );
    final loginButton = Expanded(
        child: Padding(
            padding: EdgeInsets.only(left: 10),
            child: RaisedButton(
              padding: EdgeInsets.all(12),
              color: primaryBackgroundColor,
              child: Text(lang['Login'],
                  style: TextStyle(color: primaryBadgeColor)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: primaryBadgeColor)),
              onPressed: () async {
                destroySession(() {});
                sanitizeHostname();
                loginMsgTitle = 'Attempting Connection...';
                loginMsgText = 'Please Wait...';
                setState(() {});
                if (factorAuthResponse != null) {
                  await twoFactorPost(
                      (error) => getSessionError(error, (errorMsg) {
                            debugLog(errorMsg);
                            switch (errorMsg) {
                              case 'TIMEOUT':
                                loginMsgTitle = lang["connectionTimeout"];
                                loginMsgText = lang["connectionTimeoutText"];
                                break;
                              case 'REFUSED':
                                loginMsgTitle = lang["connectionRefused"];
                                loginMsgText = lang["connectionTimeoutText"];
                                break;
                            }
                            setState(() {});
                          }));
                } else {
                  await loginPost((error) => getSessionError(error, (errorMsg) {
                        debugLog(errorMsg);
                        switch (errorMsg) {
                          case 'TIMEOUT':
                            loginMsgTitle = lang["connectionTimeout"];
                            loginMsgText = lang["connectionTimeoutText"];
                            break;
                          case 'REFUSED':
                            loginMsgTitle = lang["connectionRefused"];
                            loginMsgText = lang["connectionTimeoutText"];
                            break;
                        }
                        setState(() {});
                      }));
                }
                // await licenseCheck(licenseKeyValue);
                // if(licenseCheckResult == true){
                if (loginData["ok"] == true &&
                    loginData["\$user"] != null &&
                    loginData["\$user"]['details'] != null) {
                  debugLog('You In');
                  factorAuthResponse = null;
                  loginMsgTitle = lang['successfullyAuthenticated'];
                  loginMsgText = lang['successfullyAuthenticatedText'];
                  setSession(loginEndpointValue, $user, () {
                    enableWatchingForLiveStreamMonitors();
                    setState(() {});
                  });
                  loadDataAfterLogin(() {
                    setState(() {});
                  });
                  closePage(context);
                } else if (loginData["ok"] == true &&
                    loginData["\$user"] != null) {
                  loginMsgTitle = lang['twoFactorAuthentication'];
                  loginMsgText = lang['twoFactorAuthenticationText'];
                  setState(() {});
                } else {
                  loginMsgTitle = lang['loginFailed'];
                  loginMsgText = lang['loginFailedText'];
                  debugLog('Login Failed');
                }
                setState(() {});
                // }else{
                //     debugLog('licenseCheckResult ' + licenseKeyValue);
                //     debugLog(licenseCheckResult);
                // }
              },
            )));
    final backButton = Expanded(
        child: Padding(
            padding: EdgeInsets.only(right: 10),
            child: RaisedButton(
              padding: EdgeInsets.all(12),
              color: primaryInputFillColor,
              child: Text(lang['Back'], style: TextStyle(color: colorWhite)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              onPressed: () async {
                factorAuthResponse = null;
                closePage(context);
              },
            )));
    // Login WINDOW END />
    Color loginTextColor = loginMsgTitle == lang['successfullyAuthenticated']
        ? colorGreen
        : colorYellow;
    return Scaffold(
      backgroundColor: primaryBackgroundColor,
      appBar: new AppBar(
        title: new Text(lang['connectYourShinobi']),
        backgroundColor: primaryHeaderColor,
      ),
      body: Center(
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.only(left: 24.0, right: 24.0),
          children: <Widget>[
            Card(
              color: primaryCardBackgroundColor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    leading: Icon(Icons.lock, color: blipTextColor),
                    title: Text(
                        '${lang['loginStatus']} : ${(sessionKey != null ? lang['Success'] : lang['Not Logged In'])}',
                        style: TextStyle(color: blipTextColor)),
                    subtitle: Text(
                        '${lang['websocketStatus']} : ${(websocketClient != null && websocketClient.connected ? lang['Connected'] : lang['Disconnected'])}',
                        style: TextStyle(color: blipTextColor)),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(),
            ),
            loginMsgText != null
                ? new Card(
                    color: primaryCardBackgroundColor,
                    child: Padding(
                      padding: EdgeInsets.only(top: 16.0, bottom: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ListTile(
                            leading: Icon(
                                loginMsgTitle ==
                                        lang['successfullyAuthenticated']
                                    ? Icons.check
                                    : loginMsgTitle ==
                                            '${lang['attemptingConnection']}...'
                                        ? Icons.info
                                        : Icons.priority_high,
                                color: loginTextColor),
                            title: Text(
                              loginMsgTitle,
                              style: TextStyle(color: primaryTextColor),
                            ),
                            subtitle: Text(
                              loginMsgText,
                              style: TextStyle(color: primaryTextColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(),
            SizedBox(height: 15.0),
            factorAuthResponse == null
                ? Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    loginEndpointField,
                    SizedBox(height: 8.0),
                    email,
                    SizedBox(height: 8.0),
                    password,
                  ])
                : factorAuthKey,
            SizedBox(height: 25.0),
            Padding(
              padding: EdgeInsets.only(right: 5, left: 5),
              child: Row(children: [
                backButton,
                loginButton,
              ]),
            ),
            SizedBox(height: 25.0),
            new Padding(
              padding: new EdgeInsets.only(left: 45, right: 45),
              child: Text(lang['loginToViewStreamsAndRecords'],
                  style: TextStyle(color: Color(4294967295)),
                  textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
// login screen END />
// license Screen >
class licenseScreen extends StatefulWidget {
  @override
  _LicenseScreenState createState() => _LicenseScreenState();
class _LicenseScreenState extends State<licenseScreen> {
  @override
  Widget build(BuildContext context) {
    // Login WINDOW >
    String initialValueLicenseKey;
    // initialValueLicenseKey = storageLogin.getItem('licenseKey');
    if (initialValueLicenseKey == null) initialValueLicenseKey = '';
    licenseKeyValue = initialValueLicenseKey;
    final licenseKey = TextFormField(
      autofocus: false,
      initialValue: initialValueLicenseKey,
      obscureText: true,
      onChanged: (text) {
        storageLogin.setItem('licenseKey', text);
        licenseKeyValue = text;
      },
      style: TextStyle(
        color: colorWhite,
      ),
      decoration: InputDecoration(
          hintText: lang['mobileAppLicenseKey'],
          contentPadding: EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
          fillColor: primaryInputFillColor,
          filled: true,
          hintStyle: TextStyle(color: secondaryTextColor),
          prefixIcon: Icon(Icons.search, color: secondaryTextColor),
          border: OutlineInputBorder(
              borderSide: new BorderSide(color: secondaryTextColor),
              borderRadius: BorderRadius.all(Radius.circular(25.0)))),
    );
    final loginButton = Expanded(
        child: Padding(
            padding: EdgeInsets.only(left: 10),
            child: RaisedButton(
                color: primaryBackgroundColor,
                child: Text(lang['Activate'],
                    style: TextStyle(color: primaryBadgeColor)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: primaryBadgeColor)),
                onPressed: () async {
                  await licenseCheck(licenseKeyValue);
                  setState(() {
                    if (licenseCheckResult == true) {
                      closePage(context);
                    } else {
                      debugLog('licenseCheckResult ' + licenseKeyValue);
                      debugLog(licenseCheckResult);
                    }
                  });
                },
                padding: EdgeInsets.all(12))));
    final backButton = Expanded(
        child: Padding(
            padding: EdgeInsets.only(right: 10),
            child: RaisedButton(
              onPressed: () async {
                closePage(context);
              },
              padding: EdgeInsets.all(12),
              color: primaryInputFillColor,
              child: Text(lang['Back'], style: TextStyle(color: colorWhite)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            )));
    // Login WINDOW END />
    return Scaffold(
      backgroundColor: primaryBackgroundColor,
      appBar: new AppBar(
        title: new Text(lang['licenseActivation']),
        backgroundColor: primaryHeaderColor,
      ),
      body: Center(
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.only(left: 24.0, right: 24.0),
          children: <Widget>[
            new Padding(
              padding: new EdgeInsets.all(15.0),
              child: Text(
                  '${lang['activationStatus']} : ${(licenseCheckResult ? lang['Success'] : lang['Failed'])}',
                  style: TextStyle(color: Color(4294967295)),
                  textAlign: TextAlign.center),
            ),
            SizedBox(height: 15.0),
            licenseKey,
            SizedBox(height: 25.0),
            Row(children: [
              backButton,
              loginButton,
            ]),
            SizedBox(height: 25.0),
            new Padding(
              padding: new EdgeInsets.all(15.0),
              child: Text(lang['reasonToActivate'],
                  style: TextStyle(color: Color(4294967295)),
                  textAlign: TextAlign.center),
            )
          ],
        ),
      ),
    );
// license screen END />
// video list basic >
Map filteredRecordingListMonitors = {};
var videoListMonitorsSelected = {};
Map loadedVideos = {};
Map loadedEvents = {};
String searchLimit = '10';
var dateNowStart = DateTime.now().subtract(new Duration(days: 2));
var dateNowEnd = DateTime.now();
String videoListScreenStartDateSelected =
    '${dateNowStart.year}-${dateNowStart.month}-${dateNowStart.day}';
String videoListScreenStartTimeSelected =
    '${dateNowStart.hour}:${dateNowStart.minute}:${dateNowStart.second}';
String videoListScreenEndDateSelected =
    '${dateNowEnd.year}-${dateNowEnd.month}-${dateNowEnd.day}';
String videoListScreenEndTimeSelected =
    '${dateNowEnd.hour}:${dateNowEnd.minute}:${dateNowEnd.second}';
class videoListScreen extends StatefulWidget {
  @override
  _VideoListScreenState createState() => _VideoListScreenState();
class _VideoListScreenState extends State<videoListScreen> {
  TextEditingController searchController = TextEditingController();
  TextEditingController searchLimitController = TextEditingController();
  // void filterSearchResults(String query) {
  //   if(query.isNotEmpty) {
  //     monitors.entries.toList().forEach((monitor) {
  //       print(jsonDecode(monitor.toString()));
  //         // if(jsonEncode(monitor).contains(query)) {
  //         //     filteredRecordingListMonitors[monitor["mid"]] = true;
  //         // }else{
  //         //     filteredRecordingListMonitors.remove(monitor["mid"]);
  //         // }
  //     });
  //     setState((){});
  //     return;
  //   }
  // }
  createVideoListFromLoadedVideos() {
    List newVideosList = [];
    loadedVideos.forEach((monitorId, videos) {
      if (videos != null) newVideosList.addAll(videos);
    });
    newVideosList.sort((a, b) {
      return a["time"].compareTo(b["time"]);
    });
    return newVideosList;
  createListTilesForMonitorSelection() {
    List<Widget> generated = [];
    addMonitorToList(monitorId, monitor) {
      // if(filteredRecordingListMonitors.length > 0 && filteredRecordingListMonitors[monitorId] != true)return;
      generated.add(ListTile(
        leading: Icon(Icons.videocam,
            color: videoListMonitorsSelected[monitorId] == null
                ? primaryTextColor
                : primarySelectedTextColor),
        title: Text(monitor['name'], style: TextStyle(color: colorWhite)),
        onTap: () async {
          if (videoListMonitorsSelected[monitorId] == null) {
            videoListMonitorsSelected[monitorId] = true;
            getVideosFromServer(monitorId, () {
              setState(() {});
            });
          } else {
            loadedVideos.remove(monitorId);
            videoListMonitorsSelected.remove(monitorId);
          }
          storageSettings.setItem(
              'videoListMonitorsSelected', videoListMonitorsSelected);
          setState(() {});
        },
      ));
    }
    monitors
        .forEach((monitorId, monitor) => addMonitorToList(monitorId, monitor));
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: generated);
  createVideosRowForTable() {
    List videoWidgets = <DataRow>[];
    List filteredEventsList = [];
    DateTime dateNow = DateTime.now();
    createVideoListFromLoadedVideos().reversed.toList().forEach((video) {
      video['eventsDetected'] = [];
      String monitorId = video["mid"];
      var filename = video["filename"];
      var startTime = DateTime.parse(video["time"]).toLocal();
      var endTime = DateTime.parse(video["end"]).toLocal();
      var difference = endTime.difference(startTime).inMinutes;
      var inSeconds = difference == 0;
      difference = inSeconds == true ? endTime.difference(startTime).inSeconds : difference;
      double differenceFromNow =
          double.parse(dateNow.difference(endTime).inMinutes.toString());
      var differenceFromNowTag = 'minutes';
      if (differenceFromNow > 60) {
        differenceFromNow =
            double.parse((differenceFromNow / 60).toStringAsFixed(2));
        differenceFromNowTag = 'hours';
      }
      int averageConfidence = 0;
      int numberOfDetectedObjects = 0;
      int numberOfDetectedPeople = 0;
      int numberOfEventsForThisVideo = 0;
      if (loadedEvents[monitorId] != null)
        filteredEventsList.addAll(loadedEvents[monitorId]);
      int eventIndex = 0;
      // List indexesToRemove = [];
      filteredEventsList.forEach((event) {
        if (event == null) return;
        final eventTime = DateTime.parse(event["time"]);
        if (eventTime.isAfter(startTime) && eventTime.isBefore(endTime)) {
          video['eventsDetected'].add(event);
          ++numberOfEventsForThisVideo;
          averageConfidence += event['details']['confidence'];
          if (event['details']['matrices'] != null) {
            numberOfDetectedObjects += event['details']['matrices'].length;
            event['details']['matrices'].forEach((matrix) {
              if (matrix['tag'] == 'person') numberOfDetectedPeople += 1;
            });
          }
          // indexesToRemove.add(eventIndex);
        }
        ++eventIndex;
      });
      // indexesToRemove.forEach((index){
      //     if(filteredEventsList[index] != null)filteredEventsList.removeAt(index);
      // });
      // print(filteredEventsList.length);
      videoWidgets.add(DataRow(
        selected: false,
        onSelectChanged: (value) {
          // recordingList.setRecordingRowSelection(filename,!selectedRecordingRows[filename]);
          // debugLog(selectedRecordingRows[filename]);
          setState(() {});
        },
        cells: [
          DataCell(Padding(
              padding: EdgeInsets.only(top: 10, bottom: 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${monitors[video["mid"]]["name"]}',
                      style: TextStyle(color: colorWhite),
                    ),
                    Text(
                      '${getHumanTime(startTime)} to ${getHumanTime(endTime)}',
                      style: TextStyle(color: colorWhite),
                    ),
                    Text(
                      '${getHumanDate(startTime)}, ${differenceFromNow} ${differenceFromNowTag} ago',
                      textAlign: TextAlign.left,
                      style: new TextStyle(
                          color: colorWhite, fontWeight: FontWeight.bold),
                    )
                  ]))),
          DataCell(
            Row(children: [
              // Play Button >
              FlatButton(
                child: Icon(
                  video["status"] == 2 ? Icons.play_arrow : Icons.fiber_new,
                  // Icons.play_arrow,
                  color: video["status"] == 2
                      ? primaryTextColor
                      : colorGreenAccentLight,
                ),
                onPressed: () async {
                  if (video["status"] != 2) {
                    setVideoStatus(video, 2, () {
                      setState(() {});
                    });
                  }
                  storageSettings.setItem(
                      'activeVideoUrl', loginEndpoint + video['href']);
                  openPage(context, 'recordingPlayVideo');
                },
              ),
              // Play Button />
              // // Archive Button >
              // FlatButton(
              //     child: Icon(
              //               itemRow["archive"] ? Icons.unarchive : Icons.archive,
              //               color: itemRow["archive"] ? Colors.orange : secondaryTextColor,
              //           ),
              //     onPressed: () {
              //         recordingList.archiveRecordedVideosInList([filename],!itemRow["archive"],(){
              //             setState((){});
              //         });
              //     },
              // ),
              // // Archive Button />
              // // Share Button >
              // FlatButton(
              //     child: Icon(
              //               Icons.call_made,
              //               color: secondaryTextColor,
              //           ),
              //     onPressed: () {
              //         ShareExtend.share('$recordingPath${filename}', "video");
              //     },
              // ),
              // // Share Button />
              // // Upload Button >
              // FlatButton(
              //     child: Icon(
              //         itemRow["uploadedShinobi"] ? Icons.cloud_done : Icons.cloud_upload,
              //         color: itemRow["uploadedShinobi"] ? colorGreenAccent : secondaryTextColor,
              //     ),
              //     onPressed: () {
              //         if(!itemRow["uploadedShinobi"]){
              //             if(selectedMonitorId != null){
              //                 uploadVideoToShinobiEngine('$recordingPath${filename}',(){
              //                     setState((){});
              //                 });
              //             }else{
              //                 showInRecordingPageSnackBar(_scaffoldRecordingKey,'Please select a Monitor first.');
              //             }
              //         }else{
              //
              //         }
              //     },
              // ),
              // // Upload Button />
              // // Delete Button >
              FlatButton(
                child: Icon(
                  Icons.delete,
                  color: primaryTextColor,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      // return object of type Dialog
                      return AlertDialog(
                        title: Text('${lang['deleteVideo']}?'),
                        content: Text('This video will not be recoverable.'),
                        actions: <Widget>[
                          // usually buttons at the bottom of the dialog
                          new FlatButton(
                            child: new Text(lang["Close"]),
                            onPressed: () {
                              closeDialog(context);
                            },
                          ),
                          new FlatButton(
                            child: new Text(lang["Delete"]),
                            onPressed: () {
                              closeDialog(context);
                              deleteVideo(video, () {
                                setState(() {});
                              });
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              // // Delete Button />
            ]),
          ),
          DataCell(Padding(
              padding: EdgeInsets.only(top: 10, bottom: 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    numberOfEventsForThisVideo > 0
                        ? Text(
                            '${numberOfEventsForThisVideo} ${lang['Events']}',
                            textAlign: TextAlign.left,
                            style: new TextStyle(
                                color: numberOfEventsForThisVideo > 0
                                    ? colorYellow
                                    : colorWhite,
                                fontWeight: FontWeight.bold),
                          )
                        : Container(),
                    averageConfidence > 0
                        ? Text(
                            '${(averageConfidence / numberOfEventsForThisVideo).toStringAsFixed(2)} ${lang['averageConfidence']}',
                            textAlign: TextAlign.left,
                            style: new TextStyle(
                                color: numberOfEventsForThisVideo > 0
                                    ? colorYellow
                                    : colorWhite,
                                fontWeight: FontWeight.bold),
                          )
                        : Container(),
                    numberOfDetectedObjects > 0
                        ? Text(
                            '${numberOfDetectedObjects} ${lang['detectedObjects']}',
                            textAlign: TextAlign.left,
                            style: new TextStyle(
                                color: numberOfEventsForThisVideo > 0
                                    ? colorYellow
                                    : colorWhite,
                                fontWeight: FontWeight.bold),
                          )
                        : Container(),
                    numberOfDetectedPeople > 0
                        ? Text(
                            '${numberOfDetectedPeople} ${lang['peopleFound']}',
                            textAlign: TextAlign.left,
                            style: new TextStyle(
                                color: numberOfEventsForThisVideo > 0
                                    ? colorYellow
                                    : colorWhite,
                                fontWeight: FontWeight.bold),
                          )
                        : Container()
                  ]))),
              DataCell(Padding(
                  padding: EdgeInsets.only(top: 10, bottom: 10),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text(
                        '${numberOfEventsForThisVideo > 0 ? numberOfEventsForThisVideo.toString() + ' Events, ' : ''}${difference} ${inSeconds == true ? 'second' : 'minute'}${difference > 1 ? 's' : ''}, ${(video["size"] / 1000000).toStringAsFixed(2)} MB',
                        textAlign: TextAlign.left,
                        style: new TextStyle(
                            color: numberOfEventsForThisVideo > 0
                                ? colorRedAccentLight
                                : colorWhite,
                            fontWeight: FontWeight.bold),
                      )
                      ])))
        ],
      ));
    });
    return videoWidgets;
  @override
  void initState() {
    super.initState();
  @override
  Widget build(BuildContext context) {
    List videoRows = createVideosRowForTable();
    return Scaffold(
      backgroundColor: primaryBackgroundColor,
      appBar: new AppBar(
        title: new Text(lang['Recordings']),
        backgroundColor: primaryHeaderColor,
      ),
      body: loadedVideos.length == 0
          ? Padding(
              padding: EdgeInsets.all(15),
              child: Column(
                children: <Widget>[
                  Card(
                    color: primaryCardBackgroundColor,
                    child: Padding(
                      padding: EdgeInsets.only(top: 15, bottom: 15),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ListTile(
                            leading:
                                Icon(Icons.skip_previous, color: blipTextColor),
                            title: Text(lang['noMonitorsSelected'],
                                style: TextStyle(color: blipTextColor)),
                            subtitle: Text(lang['noMonitorsSelectedText'],
                                style: TextStyle(color: blipTextColor)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ))
          : videoRows.length == 0
              ? Padding(
                  padding: EdgeInsets.all(15),
                  child: Column(
                    children: <Widget>[
                      Card(
                        color: primaryCardBackgroundColor,
                        child: Padding(
                          padding: EdgeInsets.only(top: 15, bottom: 15),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              ListTile(
                                leading:
                                    Icon(Icons.history, color: blipTextColor),
                                title: Text(lang['noVideosFound'],
                                    style: TextStyle(color: blipTextColor)),
                                subtitle: Text(lang['noVideosFoundText'],
                                    style: TextStyle(color: blipTextColor)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ))
              : Container(
                  child: new Stack(children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      color: primaryHeaderColor,
                    ),
                  ),
                  SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Container(
                              child: Padding(
                            padding: EdgeInsets.only(left: 0),
                            child: DataTable(
                              onSelectAll: (value) {
                                // List recordedVideos = recordingList.getRecordedVideosList();
                                // recordedVideos.forEach((video){
                                //     final String filename = video['filename'];
                                //     selectedRecordingRows[filename] = value;
                                // });
                                // recordingList.generateSelectedFilenamesList();
                                // setState((){});
                              },
                              dataRowHeight: 85.0,
                              sortAscending: true,
                              columns: <DataColumn>[
                                DataColumn(
                                  label: Text(
                                    lang['swipeLeft'],
                                    style: TextStyle(color: colorWhite),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    '',
                                    style: TextStyle(color: colorWhite),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    '',
                                    style: TextStyle(color: colorWhite),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    '',
                                    style: TextStyle(color: colorWhite),
                                  ),
                                ),
                              ],
                              rows: videoRows,
                            ),
                          ))))
                ])),
      endDrawer: Theme(
        data: Theme.of(context).copyWith(
          canvasColor:
              primaryBackgroundColor, //This will change the drawer background to blue.
          //other styles
        ),
        child: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              Container(
                padding: EdgeInsets.only(bottom: 25),
                decoration: BoxDecoration(
                  color: primaryHeaderColor,
                ),
              ),
              _createHeaderBlockRow(<Widget>[
                Expanded(
                  flex: 7,
                  child: Padding(
                    padding: EdgeInsets.only(left: 15),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${lang['appTitle']} : ${(websocketClient != null && websocketClient.connected ? 'Connected' : 'Disconnected')}',
                            style: new TextStyle(
                              fontSize: 12.0,
                              color: colorWhite,
                            ),
                          ),
                          Text(
                            '${lang['activatedClient']} : ${(licenseCheckResult ? 'Yes' : 'No')}',
                            style: new TextStyle(
                              fontSize: 12.0,
                              color: colorWhite,
                            ),
                          )
                        ]),
                  ),
                ),
              ]),
              ListTile(
                leading: Icon(Icons.refresh, color: colorWhite),
                title:
                    Text(lang['Refresh'], style: TextStyle(color: colorWhite)),
                onTap: () {
                  loadedVideos.forEach((monitorId, videos) {
                    getVideosFromServer(monitorId, () {
                      setState(() {});
                    });
                  });
                },
              ),
              Padding(
                padding: EdgeInsets.only(top: 10, left: 15),
                child: Text(lang['Start Date'],
                    style: TextStyle(
                        color: colorWhite, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: Icon(Icons.date_range, color: colorWhite),
                title: Text(videoListScreenStartDateSelected,
                    style: TextStyle(color: colorWhite)),
                onTap: () {
                  DatePicker.showDatePicker(context,
                      theme: DatePickerTheme(
                        containerHeight: 210.0,
                      ),
                      showTitleActions: true,
                      minTime: DateTime(2000, 1, 1),
                      maxTime: DateTime(2022, 12, 31), onConfirm: (date) {
                    videoListScreenStartDateSelected =
                        '${date.year}-${date.month}-${date.day}';
                    setState(() {});
                  }, currentTime: DateTime.now());
                },
              ),
              ListTile(
                leading: Icon(Icons.access_time, color: colorWhite),
                title: Text(videoListScreenStartTimeSelected,
                    style: TextStyle(color: colorWhite)),
                onTap: () {
                  DatePicker.showTimePicker(context,
                      theme: DatePickerTheme(
                        containerHeight: 210.0,
                      ),
                      showTitleActions: true, onConfirm: (time) {
                    debugLog('confirm $time');
                    videoListScreenStartTimeSelected =
                        '${time.hour}:${time.minute}:${time.second}';
                    setState(() {});
                  }, currentTime: DateTime.now());
                  setState(() {});
                },
              ),
              Divider(
                color: primaryFadedBackgroundColor,
              ),
              Padding(
                padding: EdgeInsets.only(top: 10, left: 15),
                child: Text(lang["End Date"],
                    style: TextStyle(
                        color: colorWhite, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: Icon(Icons.date_range, color: colorWhite),
                title: Text(videoListScreenEndDateSelected,
                    style: TextStyle(color: colorWhite)),
                onTap: () {
                  DatePicker.showDatePicker(context,
                      theme: DatePickerTheme(
                        containerHeight: 210.0,
                      ),
                      showTitleActions: true,
                      minTime: DateTime(2000, 1, 1),
                      maxTime: DateTime(2022, 12, 31), onConfirm: (date) {
                    videoListScreenEndDateSelected =
                        '${date.year}-${date.month}-${date.day}';
                    setState(() {});
                  }, currentTime: DateTime.now());
                },
              ),
              ListTile(
                leading: Icon(Icons.access_time, color: colorWhite),
                title: Text(videoListScreenEndTimeSelected,
                    style: TextStyle(color: colorWhite)),
                onTap: () {
                  DatePicker.showTimePicker(context,
                      theme: DatePickerTheme(
                        containerHeight: 210.0,
                      ),
                      showTitleActions: true, onConfirm: (time) {
                    debugLog('confirm $time');
                    videoListScreenEndTimeSelected =
                        '${time.hour}:${time.minute}:${time.second}';
                    setState(() {});
                  }, currentTime: DateTime.now());
                  setState(() {});
                },
              ),
              Divider(
                color: primaryFadedBackgroundColor,
              ),
              Padding(
                padding: EdgeInsets.only(top: 10, left: 15),
                child: Text(lang["Video Limit"],
                    style: TextStyle(
                        color: colorWhite, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: EdgeInsets.only(top: 15.0, left: 15.0, right: 15.0),
                child: TextField(
                  onChanged: (value) {
                    if (value == '') {
                      searchLimit = '10';
                      return;
                    }
                    searchLimit = value;
                  },
                  controller: searchLimitController,
                  decoration: InputDecoration(
                      filled: true,
                      fillColor: primaryInputFillColor,
                      labelText: lang["Default is 10"],
                      labelStyle: TextStyle(color: secondaryTextColor),
                      hintText: lang["Video Limit"],
                      hintStyle: TextStyle(color: secondaryTextColor),
                      prefixIcon:
                          Icon(Icons.video_library, color: secondaryTextColor),
                      border: OutlineInputBorder(
                          borderSide: new BorderSide(color: secondaryTextColor),
                          borderRadius:
                              BorderRadius.all(Radius.circular(25.0)))),
                ),
              ),
              Divider(
                color: primaryFadedBackgroundColor,
              ),
              Padding(
                padding: EdgeInsets.only(top: 10, left: 15),
                child: Text(lang["Monitors"],
                    style: TextStyle(
                        color: colorWhite, fontWeight: FontWeight.bold)),
              ),
              // Padding(
              //   padding: EdgeInsets.only(top:15.0,left:15.0,right:15.0),
              //   child: TextField(
              //     onChanged: (value) {
              //         filterSearchResults(value);
              //     },
              //     controller: searchController,
              //     decoration: InputDecoration(
              //         filled: true,
              //         fillColor: primaryInputFillColor,
              //         labelText: "Search",
              //         labelStyle: TextStyle(color: secondaryTextColor),
              //         hintText: "Search",
              //         hintStyle: TextStyle(color: secondaryTextColor),
              //         prefixIcon: Icon(Icons.search,color: secondaryTextColor),
              //         border: OutlineInputBorder(
              //             borderSide: new BorderSide(color: secondaryTextColor),
              //             borderRadius: BorderRadius.all(Radius.circular(25.0)))),
              //   ),
              // ),
              createListTilesForMonitorSelection()
            ],
          ),
        ),
      ),
    );
// video list basic END />
// live streams window >
class liveStreamScreen extends StatefulWidget {
  @override
  _LiveStreamScreenState createState() => _LiveStreamScreenState();
class _LiveStreamScreenState extends State<liveStreamScreen> {
  List<Widget> vlcWidgetList = [];
  double screenWidth;
  createWidgets() {
    // liveStreamMonitors.forEach((key,value){
    //   // value.forEach((key,value){
    //   //     if(key == 'streams')print(value);
    //   // });
    // });
    monitorVlcWidget(monitorId) {
      String streamType =
          jsonDecode(monitors[monitorId]["details"])["stream_type"];
      Map ipCamViewerSavedStreamsSelected =
          storageSettings.getItem('ipCamViewerSavedStreamsSelected');
      if (ipCamViewerSavedStreamsSelected == null)
        ipCamViewerSavedStreamsSelected = {};
      int staticWidth = 500;
      int staticHeight = 360;
      if (monitors[monitorId] == null ||
          monitors[monitorId]["streams"] == null ||
          (monitors[monitorId]["streams"].length == 0 && streamType != 'b64') ||
          (monitors[monitorId]["status"] != 'Watching' &&
              monitors[monitorId]["status"] != 'Recording')) {
        return new GridTile(
            child: new InkResponse(
          enableFeedback: true,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    '${monitors[monitorId]["name"]} ${lang['cannotBeViewedAtThisTime']}',
                    textAlign: TextAlign.center,
                    style: new TextStyle(
                      color: colorWhite,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${lang['Status']} : ${monitors[monitorId]["status"]}',
                    textAlign: TextAlign.center,
                    style: new TextStyle(
                      color: primaryTextColor,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${monitorId}',
                    textAlign: TextAlign.center,
                    style: new TextStyle(
                      color: primaryTextColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          onTap: () {
            debugLog(monitorId);
          },
        ));
      }
      switch (streamType) {
        case 'b64':
        case 'jpeg':
          String streamUrl = getApiPrefix() +
              '/embed/' +
              groupKey +
              '/' +
              monitorId +
              '/jquery%7Cfullscreen';
          debugLog(streamUrl);
          return new GridTile(
              child: new InkResponse(
            enableFeedback: true,
            child: WebView(
              initialUrl: streamUrl,
              javascriptMode: JavascriptMode.unrestricted,
              onWebViewCreated: (WebViewController webViewController) {
                try {
                  liveStreamMonitorControllers[monitorId]
                      .complete(webViewController);
                } catch (err, stacktrace) {
                  debugLog('${err} \n ${stacktrace}');
                }
              },
              javascriptChannels: <JavascriptChannel>[
                _toasterJavascriptChannel(context),
              ].toSet(),
              onPageStarted: (String url) {
                debugLog('Page started loading: $url');
              },
              onPageFinished: (String url) {
                debugLog('Page finished loading: $url');
              },
            ),
            onTap: () {
              debugLog(monitorId);
            },
          ));
          break;
        default:
          String streamUrl = loginEndpoint + monitors[monitorId]["streams"][0];
          return new GridTile(
              child: new InkResponse(
            enableFeedback: true,
            child: new VlcPlayer(
              aspectRatio: 16 / 9,
              url: streamUrl,
              controller: liveStreamMonitorControllers[monitorId],
              placeholder: Container(
                height: 250.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[CircularProgressIndicator()],
                ),
              ),
            ),
            onTap: () {
              debugLog(monitorId);
            },
          ));
          break;
      }
    }
    ipCamViewerSavedStreamsSelected.forEach((streamName, savedStream) {
      if (liveStreamMonitorControllers[streamName] == null) {
        liveStreamMonitorControllers[streamName] =
            new VlcPlayerController(onInit: () {
          liveStreamMonitorControllers[streamName].play();
        });
      }
      String streamUrl = savedStream["url"];
      print(streamUrl);
      int staticWidth = 500;
      int staticHeight = 360;
      vlcWidgetList.add(new GridTile(
          child: new InkResponse(
              enableFeedback: true,
              child: SizedBox(
                height: 360,
                width: 500,
                child: new VlcPlayer(
                  aspectRatio: 16 / 9,
                  url: streamUrl,
                  controller: liveStreamMonitorControllers[streamName],
                  placeholder: Container(
                    height: 250.0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[CircularProgressIndicator()],
                    ),
                  ),
                ),
              ))));
    });
    liveStreamMonitors.forEach((key, value) {
      var newWidget = monitorVlcWidget(key);
      if (value != null && newWidget != null) vlcWidgetList.add(newWidget);
    });
  JavascriptChannel _toasterJavascriptChannel(BuildContext context) {
    return JavascriptChannel(
        name: 'Toaster',
        onMessageReceived: (JavascriptMessage message) {
          debugLog('JavascriptMessage');
          debugLog(message.message);
        });
  @override
  void initState() {
    createLiveStreamControllers(() {
      setState(() {});
    });
    createWidgets();
    super.initState();
  @override
  dispose() {
    // setOrientationPortrait();
    disposeLiveStreamControllers();
    super.dispose();
  @override
  Widget build(BuildContext context) {
    var orientationIsLandscape =
        (MediaQuery.of(context).orientation == Orientation.landscape);
    List appBarActions = <Widget>[];
    appBarActions.add(IconButton(
      icon: Icon(Icons.keyboard_arrow_left, color: colorWhite),
      onPressed: () {
        closePage(context);
      },
    ));
    List appBarBottomActions = <Widget>[];
    // appBarBottomActions.add(RawMaterialButton(
    //   onPressed: (){
    //     if(orientationIsLandscape){
    //         setOrientationPortrait();
    //     }else{
    //         setOrientationLandscape((){
    //             setState((){});
    //             disposeLiveStreamControllers();
    //             vlcWidgetList.clear();
    //             createWidgets();
    //         });
    //     }
    //   },
    //   child: new Icon(
    //      orientationIsLandscape ? Icons.stay_current_portrait : Icons.stay_current_landscape,
    //      color: colorWhite,
    //      size: 25.0,
    //   ),
    //   shape: new CircleBorder(),
    //   elevation: 2.0,
    //   fillColor: secondaryColor,
    //   padding: EdgeInsets.all(10.0),
    // ));
    appBarBottomActions.add(RawMaterialButton(
      onPressed: () {
        closePage(context);
      },
      child: new Icon(
        Icons.clear,
        color: colorWhite,
        size: 25.0,
      ),
      shape: new CircleBorder(),
      elevation: 2.0,
      fillColor: dangerColor,
      padding: EdgeInsets.all(10.0),
    ));
    var grideRowCount = storageSettings.getItem('liveStreamGridRowCount');
    grideRowCount = grideRowCount != null ? grideRowCount : 2;
    int gridCrossAxisCount = int.parse(grideRowCount.toStringAsFixed(0));
    if (vlcWidgetList.length < gridCrossAxisCount)
      gridCrossAxisCount = vlcWidgetList.length;
    return Scaffold(
      appBar: vlcWidgetList.length == 0
          ? AppBar(
              title: Text(''),
              backgroundColor: primaryHeaderColor,
            )
          : null,
      backgroundColor: primaryBackgroundColor,
      body: vlcWidgetList.length == 0
          ? Padding(
              padding: EdgeInsets.all(15),
              child: Column(
                children: <Widget>[
                  Card(
                    color: primaryCardBackgroundColor,
                    child: Padding(
                      padding: EdgeInsets.only(top: 15, bottom: 15),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ListTile(
                            leading: Icon(Icons.videocam, color: blipTextColor),
                            title: Text(lang['selectAMonitor'],
                                style: TextStyle(color: blipTextColor)),
                            subtitle: Text(lang['selectAMonitorText'],
                                style: TextStyle(color: blipTextColor)),
                            onTap: () {
                              closePage(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ))
          : Container(
              child: Center(
                child: new Stack(
                  children: <Widget>[
                    vlcWidgetList.length == 1
                        ? Column(children: [
                            Expanded(
                                child: Center(
                              child: vlcWidgetList[0],
                            ))
                          ])
                        : GridView.count(
                            crossAxisCount: gridCrossAxisCount,
                            children: vlcWidgetList,
                          ),
                    new Positioned(
                        left: orientationIsLandscape ? 30 : 0,
                        top: orientationIsLandscape ? 10 : 30.0,
                        child: Column(children: [
                          orientationIsLandscape
                              ? Column(
                                  children: appBarActions.reversed.toList())
                              : Row(children: appBarActions)
                        ])),
                    new Positioned(
                        right: orientationIsLandscape ? 10 : 0,
                        bottom: orientationIsLandscape ? 0 : 15,
                        top: orientationIsLandscape ? 10 : null,
                        // width: orientationIsLandscape ? 100 : null,
                        // height: orientationIsLandscape ? null : 80,
                        child: Column(children: [
                          orientationIsLandscape
                              ? Row(children: appBarBottomActions)
                              : Row(children: appBarBottomActions)
                        ])),
                  ],
                ),
              ),
              decoration: BoxDecoration(
                color: colorBlack,
              ),
            ),
      //   body: Center(
      //     child: ListView(
      //       shrinkWrap: true,
      //       padding: EdgeInsets.only(left: 24.0, right: 24.0),
      //       children: vlcWidgetList
      //     ),
      // ),
    );
// live streams window END />