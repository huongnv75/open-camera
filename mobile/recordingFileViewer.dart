import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'language.dart';
import 'colors.dart';
import 'basic.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:matrix_gesture_detector/matrix_gesture_detector.dart';
// localStorage >
import 'package:localstorage/localstorage.dart';
LocalStorage storageSettings;
// localStorage END />
// Recordings Play Video Screen, video player >
var _videoPlayerWidget;
var videoPlayerController;
double currentPlayerTime = 0;
class recordingPlayVideo extends StatefulWidget {
    @override
    _MainVideoState createState() => _MainVideoState();
class _MainVideoState extends State<recordingPlayVideo> {
  bool videoControlsShowing = true;
  Matrix4 videoZoomPosition = Matrix4.identity();
  // VideoPlayerController _controller;
  // ChewieController chewieController;
  @override
  void initState() {
    currentPlayerTime = 0;
    videoPlayerController = new VlcPlayerController(
        // Start playing as soon as the video is loaded.
        onInit: (){
            videoPlayerController.play();
        }
    );
    videoPlayerController.addListener((){
        double newTime = double.parse(videoPlayerController.position.inSeconds.toString());
        if(newTime != currentPlayerTime)currentPlayerTime = newTime;
        setState((){});
    });
    storageSettings = new LocalStorage('Settings.json');
    final activeVideoUrl = storageSettings.getItem('activeVideoUrl');
    super.initState();
    // setOrientationLandscape();
    // debugLog(activeVideoUrl);
    // _controller = VideoPlayerController.network(activeVideoUrl)
    //   ..initialize().then((_) {
    //     // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
    //     setState(() {
    //         _controller.play();
    //     });
    //   });
    //
    //
    //   chewieController = ChewieController(
    //     videoPlayerController: _controller,
    //     aspectRatio: 3 / 2,
    //     looping: false,
    //   );
    //
    //   _videoPlayerWidget =  Chewie(
    //     controller: chewieController,
    //   );
      _videoPlayerWidget =  new VlcPlayer(
          aspectRatio: 16 / 9,
          url: activeVideoUrl,
          controller: videoPlayerController,
          placeholder: Center(child: CircularProgressIndicator()),
      );
  @override
  Widget build(BuildContext context) {
    Matrix4 originalDimensions = Matrix4.identity();
    var orientationIsLandscape = (MediaQuery.of(context).orientation == Orientation.landscape);
    List appBarActions = <Widget>[];
    appBarActions.add(RawMaterialButton(
        child: new Icon(
           Icons.keyboard_arrow_left,
           color: colorWhite,
           size: 40.0,
        ),
        shape: new CircleBorder(),
        elevation: 2.0,
        padding: const EdgeInsets.all(10.0),
        onPressed: (){
            closePage(context);
        },
    ));
    List appBarBottomActions = <Widget>[];
    appBarBottomActions.add(RawMaterialButton(
      onPressed: (){
        if(videoPlayerController.duration.inSeconds == videoPlayerController.position.inSeconds){
            videoPlayerController.stop();
            videoPlayerController.setStreamUrl(storageSettings.getItem('activeVideoUrl'));
            videoPlayerController.setTime(0);
        }
        print(videoPlayerController.playingState.toString());
        videoPlayerController.playingState.toString() == 'PlayingState.PLAYING'
            ? videoPlayerController.pause()
            : videoPlayerController.play();
        // _controller.value.isPlaying
        //     ? _controller.pause()
        //     : _controller.play();
        setState((){});
      },
      child: new Icon(
          // _controller.value.isPlaying
          videoPlayerController.playingState.toString() == 'PlayingState.PLAYING'
          ? Icons.pause
          : Icons.play_arrow,
         color: colorWhite,
         size: 25.0,
      ),
      shape: new CircleBorder(),
      elevation: 2.0,
      padding: const EdgeInsets.all(15),
    ));
    appBarBottomActions.add(RawMaterialButton(
      onPressed: (){
        videoPlayerController.stop();
        // videoPlayerController.setStreamUrl(storageSettings.getItem('activeVideoUrl'));
        setState((){
            videoPlayerController.play();
        });
      },
      child: new Icon(
          Icons.refresh,
         color: colorWhite,
         size: 25.0,
      ),
      shape: new CircleBorder(),
      elevation: 2.0,
      padding: const EdgeInsets.all(7.5),
    ));
    appBarBottomActions.add(RawMaterialButton(
        child: new Icon(
           Icons.tonality,
           color: colorWhite,
           size: 25.0,
        ),
        shape: new CircleBorder(),
        elevation: 2.0,
        padding: const EdgeInsets.all(7.5),
        onPressed: (){
            videoControlsShowing = !videoControlsShowing;
            setState((){});
        },
    ));
    if(originalDimensions != videoZoomPosition)appBarBottomActions.add(RawMaterialButton(
      onPressed: (){
        videoZoomPosition = originalDimensions;
        setState((){});
      },
      child: new Icon(
          Icons.center_focus_strong,
         color: colorWhite,
         size: 25.0,
      ),
      shape: new CircleBorder(),
      elevation: 2.0,
      fillColor: quinciaryColor,
      padding: const EdgeInsets.all(7.5),
    ));
    Widget sliderElement = Container();
    try{
        sliderElement = Slider(
           activeColor: colorYellow,
           min: 0,
           max: double.parse(videoPlayerController.duration.inSeconds.toString()),
           onChanged: (newRating) {
               var time = int.parse(newRating.toStringAsFixed(0));
               currentPlayerTime = double.parse(newRating.toStringAsFixed(0));
               print(currentPlayerTime);
               videoPlayerController.setTime(time * 1000);
               setState((){});
           },
           value: currentPlayerTime,
       );
    }catch(err, stacktrace){
    }
    return Scaffold(
        body: Container(
          decoration: BoxDecoration(
              // Box decoration takes a gradient
              color: primaryHeaderColor,
          ),
        child:Container(
          child: Center(
            child: new Stack(
                children: <Widget>[
                  Column(
                      children:[
                          Expanded(
                              child:  Center(
                                  child: MatrixGestureDetector(
                                    shouldRotate: false,
                                    onMatrixUpdate: (Matrix4 m, Matrix4 tm, Matrix4 sm, Matrix4 rm) {
                                      setState(() {
                                        videoZoomPosition = m;
                                      });
                                    },
                                    child: Transform(
                                      transform: videoZoomPosition,
                                      child: _videoPlayerWidget,
                                    ),
                                  )
                              )
                          )
                      ]
                  ),
                   videoControlsShowing ? new Positioned(
                     left: 30,
                     right: 30,
                     bottom: orientationIsLandscape ? 65 : 65,
                     child: Column(
                         children:[
                            sliderElement,
                        ]
                     )
                   ) : Container(),
                   new Positioned(
                     left: orientationIsLandscape ? 0 : 0,
                     top: orientationIsLandscape ? 15 : 30.0,
                     child: Opacity(
                       opacity: videoControlsShowing ? 1.0 : 0.3,
                       child: Column(
                           children:[
                               orientationIsLandscape ? Column(
                                     children: appBarActions.reversed.toList()
                                 ) : Row(
                                     children: appBarActions
                                 )
                           ]
                       )
                     )
                   ),
                   new Positioned(
                     right: 0,
                     bottom: orientationIsLandscape ? 15 : 15,
                     // width: orientationIsLandscape ? 100 : null,
                     // height: orientationIsLandscape ? null : 80,
                     child: Opacity(
                       opacity: videoControlsShowing ? 1.0 : 0.25,
                       child: Column(
                         children:[
                             orientationIsLandscape ? Row(
                                   children: appBarBottomActions.reversed.toList()
                               ) : Row(
                                   crossAxisAlignment: CrossAxisAlignment.center,
                                   children: appBarBottomActions.reversed.toList()
                               )
                         ]
                     )
                     )
                   ),
                 ],
             ),
          ),
          decoration: BoxDecoration(
            color: colorBlack,
          ),
        ),
      ),
    );
  @override
  void dispose() {
    // setOrientationPortrait();
    super.dispose();
    // chewieController.dispose();
    // _controller.dispose();
// Recordings Play Video Screen END />
  }
  