@import 'package:flutter/material.dart';
String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();
getHumanTime(time) {
  var isAbove12 = (time.hour > 12);
  return '${isAbove12 ? time.hour - 12 : time.hour}:${time.minute <= 9 ? '0${time.minute}' : time.minute}:${time.second <= 9 ? '0${time.second}' : time.second} ${isAbove12 ? 'PM' : 'AM'}';
getHumanTimeNoExt(time) {
  var isAbove12 = (time.hour > 12);
  return '${isAbove12 ? time.hour - 12 : time.hour}:${time.minute <= 9 ? '0${time.minute}' : time.minute}:${time.second <= 9 ? '0${time.second}' : time.second}';
getHumanTimeRaw(time) {
  return '${time.hour}:${time.minute <= 9 ? '0${time.minute}' : time.minute}:${time.second <= 9 ? '0${time.second}' : time.second}';
getHumanDate(time) {
  return '${time.year}-${time.month}-${time.day}';
getHumanDateReversed(time) {
  return '${time.day}-${time.month}-${time.year}';
getUtcDateTime(dateString) {
  return DateTime.parse(dateString).toUtc();
convertUtcStringToLocalDateTime(dateString) {
  print(dateString);
  var dateStringPieces = dateString.split(' ');
  var datePieces = convertListStringsToInts(dateStringPieces[0].split('-'));
  var timePieces = convertListStringsToInts(dateStringPieces[1].split(':'));
  return DateTime.utc(datePieces[0], datePieces[1], datePieces[2],
          timePieces[0], timePieces[1], timePieces[2].split('-')[0])
      .toLocal();
convertListStringsToInts(theList) {
  List newArray = [];
  theList.forEach((item) {
    if(item != '' && item != null)newArray.add(int.parse('${item}'));
  });
  return newArray;
openPage(context, pageName) async {
  Navigator.of(context).pushNamed('/${pageName}');
closePage(context) {
  Navigator.of(context, rootNavigator: true).pop();
closeDialog(context) {
  Navigator.of(context).pop();
// Globals
String _activeVideoUrl = '';