import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/offline_prayer.dart';
import '../../core/theme.dart';
import '../../l10n/prayer_labels.dart';
import '../../widgets/common.dart';
import '../../widgets/location_picker.dart';

/// Within this many degrees the user is considered facing the qibla.
const _facingTolerance = 5.0;

class QiblaScreen extends StatelessWidget {
  const QiblaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lat = state.settings['latitude'];
    final lng = state.settings['longitude'];
    return Scaffold(
      appBar: AppBar(title: Text(prayerL(context).qiblaDirection)),
      body: !state.hasLocation
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.explore_outlined,
                      size: 56,
                      color: FadlColors.sage,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      prayerL(context).qiblaLocationPrompt,
                      style: FadlFonts.heading(size: 18),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => showLocationPicker(context),
                      icon: const Icon(Icons.my_location_rounded),
                      label: Text(prayerL(context).setLocation),
                    ),
                  ],
                ),
              ),
            )
          : AsyncView<Map<String, dynamic>>(
              reloadToken: '$lat|$lng',
              load: () async => Api.hasBackend
                  ? await Api.instance.get('/qibla', {'lat': lat, 'lng': lng})
                        as Map<String, dynamic>
                  : OfflinePrayer.qibla(
                      (lat as num).toDouble(),
                      (lng as num).toDouble(),
                    ),
              builder: (context, qibla, _) => _QiblaBody(
                qibla: qibla,
                locationName: locationLabel(
                  prayerL(context),
                  state.settings['locationName'] as String?,
                ),
              ),
            ),
    );
  }
}

class _QiblaBody extends StatelessWidget {
  const _QiblaBody({required this.qibla, required this.locationName});
  final Map<String, dynamic> qibla;
  final String locationName;

  @override
  Widget build(BuildContext context) {
    final bearing = (qibla['bearing'] as num).toDouble();
    final stream = FlutterCompass.events;
    return StreamBuilder<CompassEvent>(
      stream: stream,
      builder: (context, snap) {
        final heading = snap.data?.heading;
        final accuracy = snap.data?.accuracy;
        final hasSensor =
            stream != null &&
            !(snap.hasData && heading == null) &&
            !snap.hasError;
        final waiting = hasSensor && heading == null;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            FadlCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: FadlColors.sage,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      locationName,
                      style: FadlFonts.ui(size: 15, weight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => showLocationPicker(context),
                    child: Text(prayerL(context).change),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: _CompassDial(
                heading: heading ?? 0,
                bearing: bearing,
                live: heading != null,
              ),
            ),
            const SizedBox(height: 20),
            _StatusCard(
              heading: heading,
              bearing: bearing,
              hasSensor: hasSensor,
              waiting: waiting,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    icon: Icons.navigation_outlined,
                    label: prayerL(context).qiblaAngle,
                    value: '${prayerNumber(context, bearing.round())}°',
                    caption:
                        '${compassLabel(prayerL(context), qibla['direction'] as String?)} ${prayerL(context).fromTrueNorth}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.mosque_outlined,
                    label: prayerL(context).distanceToMakkah,
                    value: prayerL(
                      context,
                    ).distanceKm(prayerNumber(context, qibla['distanceKm'])),
                    caption: prayerL(context).straightToKaaba,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _AccuracyNote(hasSensor: hasSensor, accuracy: accuracy),
          ],
        );
      },
    );
  }
}

/// Dial rotated so north follows the device heading; the Kaaba marker sits at
/// the qibla bearing on the dial, and the fixed top pointer is "where you face".
class _CompassDial extends StatelessWidget {
  const _CompassDial({
    required this.heading,
    required this.bearing,
    required this.live,
  });
  final double heading;
  final double bearing;
  final bool live;

  @override
  Widget build(BuildContext context) {
    const size = 280.0;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final facing = live && _deviation(heading, bearing) <= _facingTolerance;
    return SizedBox(
      width: size,
      height: size + 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: Icon(
              Icons.arrow_drop_down_rounded,
              size: 40,
              color: facing ? FadlColors.gold : FadlColors.sage,
            ),
          ),
          Positioned(
            top: 24,
            child: AnimatedRotation(
              turns: -heading / 360,
              duration: const Duration(milliseconds: 250),
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dark ? FadlColors.darkSurface : Colors.white,
                        border: Border.all(
                          color: facing ? FadlColors.gold : FadlColors.emerald,
                          width: 6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: FadlColors.emerald.withValues(alpha: 0.12),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                    ),
                    CustomPaint(
                      size: const Size(size, size),
                      painter: _TicksPainter(dark: dark),
                    ),
                    for (final (label, deg) in [
                      (prayerL(context).north, 0.0),
                      (prayerL(context).east, 90.0),
                      (prayerL(context).south, 180.0),
                      (prayerL(context).west, 270.0),
                    ])
                      _onRing(
                        deg,
                        size / 2 - 34,
                        Text(
                          label,
                          style: FadlFonts.ui(
                            size: 12,
                            weight: FontWeight.w800,
                            color: deg == 0
                                ? FadlColors.error
                                : FadlColors.sage,
                          ),
                        ),
                      ),
                    // Qibla line + Kaaba marker.
                    Transform.rotate(
                      angle: bearing * math.pi / 180,
                      child: Container(
                        width: 3,
                        height: size / 2 - 40,
                        margin: EdgeInsets.only(bottom: size / 2 - 40),
                        decoration: BoxDecoration(
                          color: FadlColors.gold,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    _onRing(
                      bearing,
                      size / 2 - 34,
                      Transform.rotate(
                        // Keep the marker upright relative to the screen.
                        angle: heading * math.pi / 180,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: FadlColors.primary,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: FadlColors.gold,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.mosque_rounded,
                            color: FadlColors.goldLight,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: FadlColors.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _onRing(double degrees, double radius, Widget child) {
    final rad = degrees * math.pi / 180;
    return Transform.translate(
      offset: Offset(radius * math.sin(rad), -radius * math.cos(rad)),
      child: child,
    );
  }
}

class _TicksPainter extends CustomPainter {
  _TicksPainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 10;
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var d = 0; d < 360; d += 5) {
      final major = d % 30 == 0;
      paint
        ..color = (dark ? FadlColors.onEmerald : FadlColors.outline).withValues(
          alpha: major ? 0.9 : 0.4,
        )
        ..strokeWidth = major ? 2.2 : 1;
      final a = d * math.pi / 180;
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(c + dir * r, c + dir * (r - (major ? 12 : 6)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TicksPainter old) => old.dark != dark;
}

double _deviation(double heading, double bearing) {
  final d = ((heading - bearing) % 360 + 360) % 360;
  return d > 180 ? 360 - d : d;
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.heading,
    required this.bearing,
    required this.hasSensor,
    required this.waiting,
  });
  final double? heading;
  final double bearing;
  final bool hasSensor;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String subtitle;
    var facing = false;
    if (!hasSensor) {
      title = prayerL(context).noCompassSensor;
      subtitle = prayerL(
        context,
      ).bearingFromNorth(prayerNumber(context, bearing.round()));
    } else if (waiting || heading == null) {
      title = prayerL(context).readingCompass;
      subtitle = prayerL(context).holdPhoneLevel;
    } else {
      final dev = _deviation(heading!, bearing);
      facing = dev <= _facingTolerance;
      // Signed turn: positive = turn clockwise (right).
      final signed = ((bearing - heading!) % 360 + 540) % 360 - 180;
      title = facing
          ? prayerL(context).facingQibla
          : signed > 0
          ? prayerL(context).turnRight
          : prayerL(context).turnLeft;
      subtitle = prayerL(context).headingDeviation(
        prayerNumber(context, heading!.round()),
        prayerNumber(context, dev.toStringAsFixed(1)),
      );
    }
    return FadlCard(
      color: facing ? FadlColors.goldSoft : null,
      child: Row(
        children: [
          Icon(
            facing
                ? Icons.check_circle_rounded
                : (hasSensor
                      ? Icons.screen_rotation_alt_rounded
                      : Icons.sensors_off_rounded),
            color: facing ? FadlColors.gold : FadlColors.sage,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FadlFonts.heading(
                    size: 17,
                    color: facing ? FadlColors.primary : null,
                  ),
                ),
                Text(
                  subtitle,
                  style: FadlFonts.ui(
                    size: 12.5,
                    color: facing
                        ? FadlColors.textMuted
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
  });
  final IconData icon;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) => FadlCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: FadlColors.sage),
            const SizedBox(width: 6),
            Text(
              label,
              style: FadlFonts.ui(
                size: 12.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(value, style: FadlFonts.heading(size: 22)),
        Text(
          caption,
          style: FadlFonts.ui(
            size: 11.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _AccuracyNote extends StatelessWidget {
  const _AccuracyNote({required this.hasSensor, required this.accuracy});
  final bool hasSensor;
  final double? accuracy;

  @override
  Widget build(BuildContext context) {
    final String text;
    if (!hasSensor) {
      text = prayerL(context).noSensorAdvice;
    } else if (accuracy == null) {
      text = prayerL(context).calibrateCompass;
    } else {
      final level = accuracy! <= 5
          ? prayerL(context).accuracyHigh
          : (accuracy! <= 15
                ? prayerL(context).accuracyMedium
                : prayerL(context).accuracyLow);
      text = prayerL(
        context,
      ).sensorAccuracy(level, prayerNumber(context, accuracy!.round()));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: FadlColors.outline,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: FadlFonts.ui(
              size: 12.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
