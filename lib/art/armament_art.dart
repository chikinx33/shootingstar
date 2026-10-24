import 'package:flutter/material.dart';

import '../data/aircraft_assembly.dart';
import 'aircraft_assembly_art.dart';

/// All primary firing modes share the physical forward-mounted cannon.
class ArmamentArt extends StatelessWidget {
  const ArmamentArt(this.id, {super.key, this.size = 56});
  final String id;
  final double size;
  @override
  Widget build(BuildContext context) =>
      AssemblyPartIcon(aircraftPart('cannon'), size: size);
}
