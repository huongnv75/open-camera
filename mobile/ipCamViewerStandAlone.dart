import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:badges/badges.dart';
import 'language.dart';
import 'colors.dart';
import 'basic.dart';
// localStorage >
import 'package:localstorage/localstorage.dart';
LocalStorage storageSettings;
// localStorage END />
_createHeaderText(textChoice,iconChoice,orientationIsLandscape){
    return Container(
              decoration: BoxDecoration(
                color: primaryHeaderColor,
              ),
              margin: EdgeInsets.only(bottom: 10.0),
              child:Column(
                  children: <Widget>[
                      Padding(
                          padding: EdgeInsets.only(top:25.0,left:0,bottom:25),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                flex: 1,
                                child: Padding(
                                           padding: EdgeInsets.only(left:orientationIsLandscape ? 40 : 15, right:15),
                                           child: Icon(iconChoice, color: colorWhite)
                                       ),
                              ),
                              Expanded(
                                flex: 6,
                                child: Padding(
                                   padding: EdgeInsets.only(left: orientationIsLandscape ? 40 : 15),
                                   child: Text(
                                      textChoice,
                                      style: new TextStyle(
                                        fontSize: 30.0,
                                        color: colorWhite,
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),
                                ),
                              ),
                            ],
                          ),
                      ),
                  ]
              ),
          );
class ipCamViewer extends StatefulWidget {
    @override
    IpCamViewerState createState() => IpCamViewerState();
String ipCamViewerStreamUrlFieldValue = '';
String ipCamViewerStreamNameFieldValue = '';
List ipCamViewerSavedStreams = [];
Map ipCamViewerSavedStreamsSelected = {};
double liveStreamGridRowCount = 2;
class IpCamViewerState extends State<ipCamViewer> {
  TextEditingController ipCamViewerStreamUrlFieldController = TextEditingController();
  TextEditingController ipCamViewerStreamNameFieldController = TextEditingController();
  createLiveStreamGridRowCountMenuItem(orientationIsLandscape){
      double liveStreamGridRowCountInitialValue;
      liveStreamGridRowCountInitialValue = storageSettings.getItem('liveStreamGridRowCount');
      if(liveStreamGridRowCountInitialValue == null)liveStreamGridRowCountInitialValue = 2;
      liveStreamGridRowCount = liveStreamGridRowCountInitialValue;
      return Padding(
        padding: EdgeInsets.only(left: orientationIsLandscape ? 30 : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:[
              Padding(
                padding: EdgeInsets.only(left: 0,bottom: 5, top: 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: 2,
                      child: Padding(
                          padding: EdgeInsets.only(right:10),
                          child: Icon(Icons.live_tv, color: colorWhite)
                        ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Padding(
                          padding: EdgeInsets.only(left: 0),
                          child: Text(
                              lang['Live Streams'],
                              style: TextStyle(color: colorWhite)
                          ),
                        ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Text(
                              '${liveStreamGridRowCount.toStringAsFixed(0)} per row',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: colorWhite
                              ),
                              textAlign: TextAlign.right
                          ),
                        ),
                    )
                  ],
                ),
            ),
              Slider(
                 activeColor: trinaryColor,
                 min: 1,
                 max: 5,
                 onChanged: (newRating) {
                     final value = double.parse(newRating.toStringAsFixed(0));
                     storageSettings.setItem('liveStreamGridRowCount', value);
                     liveStreamGridRowCount = double.parse(value.toString());
                     setState((){});
                 },
                 value: liveStreamGridRowCount,
             ),
          ]
      )
      );
  createListTilesForStreamSelection(){
      List<Widget> generated = [];
      int index = 0;
      ipCamViewerSavedStreams.forEach((stream){
          String streamName = stream['name'];
          int theIndex = int.parse('${index}');
          DateTime theTime = DateTime.parse(stream['timeCreated']);
          String timeCreated = '${getHumanDateReversed(theTime)} ${getHumanTime(theTime)}';
          generated.add(Card(
            color: primaryCardBackgroundColor,
            child: Padding(
               padding: EdgeInsets.all(15),
               child:Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                       ListTile(
                         leading: Icon(Icons.live_tv, color: primaryTextColor),
                         title: Text(
                            streamName,
                            style: TextStyle(color: primaryTextColor)
                         ),
                         subtitle: Text(
                            stream['url'],
                            style: TextStyle(color: secondaryTextColor)
                         ),
                         onTap:(){
                           ipCamViewerStreamNameFieldController.text = streamName;
                           ipCamViewerStreamUrlFieldController.text = stream['url'];
                           ipCamViewerStreamUrlFieldValue = stream['url'];
                           ipCamViewerStreamNameFieldValue = streamName;
                         }
                       ),
                        Container(
                          child: Row(
                            children: <Widget>[
                              Badge(
                                badgeColor: primaryBadgeColor,
                                shape: BadgeShape.square,
                                borderRadius: 10,
                                toAnimate: false,
                                badgeContent:
                                Text(
                                    timeCreated,
                                    style: TextStyle(color: colorWhite)
                                )
                              ),
                              new Expanded(
                                child: Container()
                              ),
                              IconButton(
                                icon: Icon(Icons.delete,color: colorWhite),
                                onPressed: () {
                                  showDialog<void>(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                      title: new Text("Delete Stream"),
                                      content: new Text("This record is stored on your mobile device. It cannot be recovered once deleted."),
                                      actions: <Widget>[
                                        new FlatButton(
                                          child: new Text("Close"),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        new FlatButton(
                                          child: new Text("Delete"),
                                          onPressed: () {
                                            ipCamViewerSavedStreamsSelected.remove(ipCamViewerSavedStreams[theIndex]["name"]);
                                            ipCamViewerSavedStreams.removeAt(theIndex);
                                            storageSettings.setItem('ipCamViewerSavedStreams',ipCamViewerSavedStreams);
                                            Navigator.of(context).pop();
                                            setState((){});
                                          },
                                        ),
                                      ],
                                    );
                                  }
                                );
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.personal_video,color: colorWhite),
                                onPressed: () {
                                    ipCamViewerSavedStreamsSelected.clear();
                                    if(ipCamViewerSavedStreamsSelected[streamName] == null){
                                        ipCamViewerSavedStreamsSelected[streamName] = new Map.from(stream);
                                    }
                                    storageSettings.setItem('ipCamViewerSavedStreamsSelected',ipCamViewerSavedStreamsSelected);
                                    openPage(context,'liveStreamScreen');
                                    setState((){});
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  ipCamViewerSavedStreamsSelected[streamName] == null ? Icons.check_box_outline_blank : Icons.check_box,
                                  color: ipCamViewerSavedStreamsSelected[streamName] == null ? primaryTextColor : primarySelectedTextColor),
                                  onPressed: () {
                                    if(ipCamViewerSavedStreamsSelected[streamName] == null){
                                        ipCamViewerSavedStreamsSelected[streamName] = new Map.from(stream);
                                    }else{
                                        ipCamViewerSavedStreamsSelected.remove(streamName);
                                    }
                                    storageSettings.setItem('ipCamViewerSavedStreamsSelected',ipCamViewerSavedStreamsSelected);
                                    setState((){});
                                },
                              ),
                          ]
                        ),
                        )
                     ]
                   )
                 )
               )
             );
             ++index;
      });
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: generated
      );
  @override
  void initState() {
    storageSettings = new LocalStorage('Settings.json');
    ipCamViewerSavedStreams = storageSettings.getItem('ipCamViewerSavedStreams');
    if(ipCamViewerSavedStreams == null)ipCamViewerSavedStreams = [];
    ipCamViewerSavedStreamsSelected = storageSettings.getItem('ipCamViewerSavedStreamsSelected');
    if(ipCamViewerSavedStreamsSelected == null)ipCamViewerSavedStreamsSelected = {};
    ipCamViewerStreamNameFieldController.text = ipCamViewerStreamNameFieldValue;
    ipCamViewerStreamUrlFieldController.text = ipCamViewerStreamUrlFieldValue;
    super.initState();
  @override
  Widget build(BuildContext context) {
    var orientationIsLandscape = (MediaQuery.of(context).orientation == Orientation.landscape);
    return Scaffold(
        appBar: AppBar(
          title: Text('Direct Streams'),
          backgroundColor: primaryHeaderColor,
          actions: <Widget>[
              IconButton(
                icon: Icon(ipCamViewerSavedStreamsSelected.length > 0 ? Icons.check_box : Icons.check_box_outline_blank),
                onPressed: () {
                    if(ipCamViewerSavedStreamsSelected.length > 0){
                        ipCamViewerSavedStreamsSelected.clear();
                    }else{
                        ipCamViewerSavedStreams.forEach((stream){
                            ipCamViewerSavedStreamsSelected[stream['name']] = new Map.from(stream);
                        });
                    }
                    storageSettings.setItem('ipCamViewerSavedStreamsSelected',ipCamViewerSavedStreamsSelected);
                    setState((){});
                },
              ),
              IconButton(
                icon: Icon(Icons.live_tv),
                onPressed: () {
                    openPage(context,'liveStreamScreen');
                },
              ),
          ].reversed.toList(),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: (){
              openPage(context,'liveStreamScreen');
          },
          child: Icon(Icons.live_tv, color: colorWhite),
          backgroundColor: primaryColor,
        ),
        body: Container(
          decoration: BoxDecoration(
              color: primaryBackgroundColor,
          ),
        child:Container(
          child: ListView(
            padding: EdgeInsets.only(left: 15.0, right: 15.0, top: 15,bottom: 35),
            children: <Widget>[
              Card(
                color: primaryCardBackgroundColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                      Padding(
                         padding: EdgeInsets.only(bottom: 10, top: 20, left: 20),
                         child: Text(
                            'Add a Stream',
                            textAlign: TextAlign.left,
                            style: new TextStyle(
                              fontSize: 30.0,
                              color: colorWhite,
                              fontWeight: FontWeight.bold
                            ),
                          ),
                      ),
                      ListTile(
                        title: Text("Please provide the connection address",style: TextStyle(color: blipTextColor)),
                        subtitle: Text('Example : rtsp://user:pass@camera_ip:port/',style: TextStyle(color: blipTextColor)),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top:15.0,left:15.0,right:15.0),
                        child: TextField(
                          style: TextStyle(color: colorWhite),
                          onChanged: (value) {
                              ipCamViewerStreamNameFieldValue = value;
                          },
                          controller: ipCamViewerStreamNameFieldController,
                          decoration: InputDecoration(
                              filled: true,
                              fillColor: primaryInputFillColor,
                              labelText: "Name",
                              labelStyle: TextStyle(color: secondaryTextColor),
                              hintText: "Stream Name",
                              hintStyle: TextStyle(color: secondaryTextColor),
                              prefixIcon: Icon(Icons.edit,color: secondaryTextColor),
                              border: OutlineInputBorder(
                                  borderSide: new BorderSide(color: primaryInputBorderColor),
                                  borderRadius: BorderRadius.all(Radius.circular(25.0)))),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top:15.0,left:15.0,right:15.0),
                        child: TextField(
                          style: TextStyle(color: colorWhite),
                          onChanged: (value) {
                              ipCamViewerStreamUrlFieldValue = value;
                          },
                          controller: ipCamViewerStreamUrlFieldController,
                          decoration: InputDecoration(
                              filled: true,
                              fillColor: primaryInputFillColor,
                              labelText: "Connection Address",
                              labelStyle: TextStyle(color: secondaryTextColor),
                              hintText: "Link Here",
                              hintStyle: TextStyle(color: secondaryTextColor),
                              prefixIcon: Icon(Icons.link,color: secondaryTextColor),
                              border: OutlineInputBorder(
                                  borderSide: new BorderSide(color: primaryInputBorderColor),
                                  borderRadius: BorderRadius.all(Radius.circular(25.0)))),
                        ),
                      ),
                      Divider(
                          color: fadedColor,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(left: 15,right:15, bottom: 15),
                                child: RaisedButton(
                                    padding: EdgeInsets.all(12),
                                    color: secondaryTextColor,
                                    child: Text('Save', style: TextStyle(color: colorBlack)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      side: BorderSide(color: primaryBackgroundColor)
                                    ),
                                    onPressed: () async {
                                       FocusScope.of(context).unfocus();
                                       List checkList = ipCamViewerSavedStreams.where((stream) => stream["name"] == ipCamViewerStreamNameFieldValue).toList();
                                       String timeNow = DateTime.now().toString();
                                       if(checkList.length == 0 && ipCamViewerStreamUrlFieldValue != ''){
                                           ipCamViewerSavedStreams.add({
                                               "name": ipCamViewerStreamNameFieldValue != '' ? ipCamViewerStreamNameFieldValue : 'DirectStream',
                                               "url": ipCamViewerStreamUrlFieldValue,
                                               "timeCreated": timeNow,
                                           });
                                           storageSettings.setItem('ipCamViewerSavedStreams',ipCamViewerSavedStreams);
                                           setState((){});
                                       }else{
                                          int indexToUpdate = ipCamViewerSavedStreams.indexWhere((stream) => stream["name"] == ipCamViewerStreamNameFieldValue);
                                          ipCamViewerSavedStreams[indexToUpdate] = {
                                            "name": ipCamViewerStreamNameFieldValue,
                                            "url": ipCamViewerStreamUrlFieldValue,
                                            "timeCreated": timeNow,
                                          };
                                          if(ipCamViewerSavedStreamsSelected[ipCamViewerStreamNameFieldValue] != null)ipCamViewerSavedStreamsSelected[ipCamViewerStreamNameFieldValue] = {
                                            "name": ipCamViewerStreamNameFieldValue,
                                            "url": ipCamViewerStreamUrlFieldValue,
                                            "timeCreated": timeNow,
                                          };
                                          storageSettings.setItem('ipCamViewerSavedStreams',ipCamViewerSavedStreams);
                                          setState((){});
                                       }
                                    }
                                  )
                                ),
                            )
                          ]
                        )
                      ]
                    )
                  ),
                Padding(
                    padding: EdgeInsets.only(top: 15),
                    child: Container()
                ),
                ipCamViewerSavedStreams.length > 0 ? createListTilesForStreamSelection() : Card(
                  color: primaryCardBackgroundColor,
                  child: Padding(
                     padding: EdgeInsets.only(top:15,bottom:15),
                     child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ListTile(
                          leading: Icon(Icons.tap_and_play,color: blipTextColor),
                          title: Text('You have no saved streams',style: TextStyle(color: blipTextColor)),
                          subtitle: Text('Direct streams are video stream links saved on your mobile device and accessed directly by your mobile device. A Shinobi server is not required to view a direct stream.',style: TextStyle(color: primaryTextColor)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      )
    );
  @override
  void dispose() {
    super.dispose();
  }