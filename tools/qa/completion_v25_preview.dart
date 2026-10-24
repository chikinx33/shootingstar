// Isolated browser origin and UI fixture; production reads no QA parameters.
import 'package:flutter/material.dart';
import 'package:shootingstar/art/raster_assets.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/flight_history_screen.dart';
import 'package:shootingstar/ui/campaign_selector.dart';

Future<void> main() async {
 WidgetsFlutterBinding.ensureInitialized();await RasterAssets.load();
 final p=await Profile.load();p.soundEnabled=false;p.onboarded=true;
 p.clearedStages.addAll(List.generate(100,(i)=>i));
 final world=(int.tryParse(Uri.base.queryParameters['world']??'0')??0).clamp(0,9);
 p.selectedStage=world*10;
 for(var i=0;i<8;i++){
  final g=GameEngine(stageIndex:i*10,shipIndex:0,attackLevel:0,hullLevel:0,magnetLevel:0,equipmentIndex:0,seed:25)
   ..elapsed=45+i.toDouble()..level=3+i..kills=30+i*10..hp=0..lastDamageSource='환경 위험'..damageByWeapon['gun']=1000+i*50..abandon();
  p.recordFlight('qa-$i',g); // In-memory report, no reward or save call.
 }
 runApp(_Preview(p));
}
class _Preview extends StatelessWidget{
 const _Preview(this.p);final Profile p;
 @override Widget build(BuildContext context){
  final app=ShootingstarApp(profile:p).build(context) as MaterialApp;
  return MaterialApp(theme:app.theme,debugShowCheckedModeBanner:false,builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(double.tryParse(Uri.base.queryParameters['textScale']??'1')??1)),child:Builder(builder:(context)=>app.builder!(context,child))),home:Uri.base.queryParameters['mode']=='world'?Scaffold(body:CampaignSelector(profile:p)):FlightHistoryScreen(profile:p));
 }
}
