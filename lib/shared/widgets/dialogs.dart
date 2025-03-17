import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';

void showAddIssueWarningDialog(context) {
  AwesomeDialog(
    width: 750,
    context: context,
    dialogType: DialogType.noHeader,
    animType: AnimType.bottomSlide,
    title: 'Attenzione!',
    desc: 'Devi aggiungere almeno un difetto prima di poter andare avanti.',
    btnOkOnPress: () {},
    btnOkColor: Colors.orange,
  ).show();
}

void showConfirmSendDialog(context) {
  AwesomeDialog(
    width: 750,
    context: context,
    dialogType: DialogType.noHeader,
    animType: AnimType.bottomSlide,
    title: 'Avanti',
    desc: 'Il pezzo verrà inviato e non si potrà tornare indietro.',
    btnOkOnPress: () {},
    btnOkColor: Colors.green,
  ).show();
}

void showConfirmDeleteDialog(context) {
  AwesomeDialog(
    width: 750,
    context: context,
    dialogType: DialogType.noHeader,
    animType: AnimType.bottomSlide,
    title: 'Eliminare?',
    desc: 'Sei sicuro di voler eliminare questo oggetto?',
    btnOkOnPress: () {},
    btnOkColor: Colors.red,
  ).show();
}
