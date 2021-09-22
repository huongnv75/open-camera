import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'colors.dart';
import 'language.dart';
import 'basic.dart';
// localStorage >
import 'package:localstorage/localstorage.dart';
LocalStorage storageLogs;
List logsInMemory = [];
// localStorage END />
// Recordings Play Video Screen, video player >
class logViewerScreen extends StatefulWidget {
    @override
    logViewerState createState() => logViewerState();
class logViewerState extends State<logViewerScreen> {
  List<Widget> mainWidgets;
  @override
  void initState() {
    mainWidgets = [];
    storageLogs = new LocalStorage('Logs.json');
    logsInMemory = storageLogs.getItem('logsInMemory');
    logsInMemory.reversed.toList().forEach((row){
        mainWidgets.add(Padding(
           padding: EdgeInsets.only(bottom: 15),
           child: Column(
              children: <Widget>[
                Card(
                  color: primaryCardBackgroundColor,
                  child: Padding(
                     padding: EdgeInsets.only(top:15,bottom:15),
                     child: ListTile(
                       title: Text(row["time"],style: TextStyle(color: colorWhite)),
                       subtitle: Text(row["log"],style: TextStyle(color: primaryTextColor)),
                       onTap: () {
                          setState((){});
                       },
                     ),
                  ),
                ),
              ],
            )
          ));
    });
    super.initState();
  @override
  void dispose() {
    // setOrientationPortrait();
    super.dispose();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: new AppBar(
            title: new Text(lang['Logs']),
            backgroundColor: primaryHeaderColor,
        ),
        body: Container(
          decoration: BoxDecoration(
              // Box decoration takes a gradient
              color: primaryBackgroundColor,
        ),
        child: Center(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.only(left: 15, right: 15, top:15),
            children: mainWidgets
          )
        )
      ),
    );
  }
  }
  }
};
// Recordings Play Video Screen END />