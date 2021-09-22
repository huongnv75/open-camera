import 'colors.dart';
import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';
import 'languages/en_CA.dart';
import 'languages/fa.dart';
Map availableLanguages = {
    "en_CA": language_en_CA,
    "fa": language_fa,
setLanguageParameters(languageMap){
    Map newMap = new Map.from(languageMap);
    newMap.forEach((key,value){
        newMap[key] = value.replaceAll(new RegExp(r'__appTitle__'),languageMap['appTitle']);
    });
    return newMap;
Map lang = setLanguageParameters(language_en_CA['text']);
class languageSettings extends StatefulWidget {
    @override
    _languageSettings createState() => _languageSettings();
class _languageSettings extends State<languageSettings> {
    LocalStorage storageSettings;
  @override
  void initState() {
      storageSettings = new LocalStorage('Settings.json');
      super.initState();
  @override
  Widget build(BuildContext context) {
      print(availableLanguages);
      List<Widget> languageSelectors = [];
      availableLanguages.forEach((languageCode,data){
          languageSelectors.add(ListTile(
            // leading: Icon(Icons.bug_report, color: colorWhite),
            title: Text(
                data['name'],
                style: TextStyle(color: colorWhite),
            ),
            onTap: () {
                // print('failed');
                lang = setLanguageParameters(data['text']);
                setState((){});
            },
        ));
      });
    return Scaffold(
        appBar: new AppBar(
            title: new Text(lang['languageSettings']),
            backgroundColor: primaryHeaderColor,
        ),
        body: Container(
          decoration: BoxDecoration(
              color: primaryBackgroundColor,
        ),
        child: Center(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.only(left: 15, right: 15, top:15),
            children: languageSelectors
          )
        )
      ),
    );
  @override
  void dispose() {
    super.dispose();
  }