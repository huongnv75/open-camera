import 'language.dart';
import 'colors.dart';
import 'package:flutter/material.dart';
class aboutPage extends StatefulWidget {
    @override
    _aboutPage createState() => _aboutPage();
class _aboutPage extends State<aboutPage> {
  // VideoPlayerController _controller;
  // ChewieController chewieController;
  @override
  void initState() {
      super.initState();
  @override
  Widget build(BuildContext context) {
      var dateNow = new DateTime.now();
      String currentYear = '${dateNow.year}';
    return Scaffold(
        appBar: new AppBar(
            title: new Text(lang['aboutPage']),
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
            children: [
                Card(
                  color: primaryCardBackgroundColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                        Padding(
                           padding: EdgeInsets.only(bottom: 10, top: 20, left: 20),
                           child: Column(
                               children: [
                                   Text(
                                      lang['aboutThisApp'],
                                      textAlign: TextAlign.left,
                                      style: new TextStyle(
                                        fontSize: 30.0,
                                        color: colorWhite,
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),
                                    Text(
                                       '${lang["Mobile Client"]} (Alpha Demo)',
                                       textAlign: TextAlign.left,
                                       style: new TextStyle(
                                         fontSize: 10.0,
                                         color: colorWhite,
                                         fontWeight: FontWeight.bold
                                       ),
                                     ),
                               ]
                           )
                        ),
                        ListTile(
                          title: Text("Created by : Shinobi Systems",style: TextStyle(color: blipTextColor)),
                          subtitle: Text('Copyright ${currentYear}, All Rights Reserved',style: TextStyle(color: blipTextColor)),
                        ),
                        ListTile(
                          title: Text("This application is a public demonstration.",style: TextStyle(color: blipTextColor)),
                        ),
                        ListTile(
                            leading: Icon(Icons.laptop,color: blipTextColor),
                            title: Text('https://www.shinobi.video',style: TextStyle(color: blipTextColor)),
                        ),
                    ]
                  )
                ),
            ]
          )
        )
      ),
    );
  @override
  void dispose() {
    // setOrientationPortrait();
    super.dispose();
    // chewieController.dispose();
    // _controller.dispose();
  }
  }
  }
}