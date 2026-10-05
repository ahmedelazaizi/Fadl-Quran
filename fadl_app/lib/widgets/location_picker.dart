import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/local_notifications.dart';
import '../core/theme.dart';
import '../l10n/prayer_labels.dart';
import 'common.dart';

/// Bottom sheet to choose the location: GPS or a preset city.
Future<void> showLocationPicker(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final state = sheetContext.read<AppState>();
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shrinkWrap: true,
            children: [
              Text(
                prayerL(sheetContext).setLocation,
                style: FadlFonts.heading(size: 20),
              ),
              const SizedBox(height: 4),
              Text(
                prayerL(sheetContext).locationPurpose,
                style: FadlFonts.ui(size: 13),
              ),
              const SizedBox(height: 12),
              FadlCard(
                onTap: () async {
                  final ok = await state.useDeviceLocation();
                  if (!sheetContext.mounted) return;
                  if (!ok) {
                    showToast(
                      sheetContext,
                      prayerL(sheetContext).locationFailed,
                    );
                  } else {
                    Navigator.pop(sheetContext);
                    LocalNotifications.instance.reschedule(state);
                  }
                },
                child: Row(
                  children: [
                    const Icon(
                      Icons.my_location_rounded,
                      color: FadlColors.sage,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      prayerL(sheetContext).locationUseGps,
                      style: FadlFonts.ui(size: 15, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final city in presetCities)
                ListTile(
                  leading: const Icon(Icons.location_city_rounded),
                  title: Text(
                    cityLabel(prayerL(sheetContext), city),
                    style: FadlFonts.ui(size: 15),
                  ),
                  selected: state.settings['locationName'] == city.nameAr,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await state.setCity(city);
                    LocalNotifications.instance.reschedule(state);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}
