import 'package:flutter/material.dart';
import 'route_navigation_dialogs.dart';


/// UC201 - Navigate to Hidden Place
/// Active navigation / route guidance screen (BF-9 to BF-13).
/// Map + distance/ETA/address are placeholder data until GPS polling and
/// the Google Routes API are wired in later.

const _accentColor = Color(0xFFF15A29);
const _dangerColor = Color(0xFFB03A2E);

class RouteNavigationActiveScreen extends StatelessWidget {
  const RouteNavigationActiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _MapPlaceholder()),
          Align(
            alignment: Alignment.bottomCenter,
            child: _NavigationInfoCard(
              onCancelNavigate: () async {
                final confirmed = await showCancelNavigationDialog(context);
                if (confirmed == true && context.mounted) {
                  // TODO: stop GPS/route guidance, end navigation session (A1)
                  Navigator.of(context).maybePop();
                }
              },
            ),
          ),
          // TEMP: lets you preview every alt-flow dialog without live
          // GPS/API logic. Remove once real triggers call these directly.
          const Positioned(top: 40, right: 16, child: _DebugDialogMenu()),
        ],
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFE9E1),
      alignment: Alignment.center,
      child: const Text(
        'Map view\n(Google Maps integration goes here)',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black38),
      ),
    );
  }
}

class _NavigationInfoCard extends StatelessWidget {
  final VoidCallback onCancelNavigate;

  const _NavigationInfoCard({required this.onCancelNavigate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route progress indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: const LinearProgressIndicator(
              value: 0.35, // placeholder until GPS tracking is live
              minHeight: 3,
              backgroundColor: Color(0xFFEFEFEF),
              valueColor: AlwaysStoppedAnimation(_accentColor),
            ),
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              text: '13 minit',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
              children: [
                TextSpan(
                  text: '  500 m',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '28-G, Jalan Puteri 1/4, Bandar Puteri,\n47100 Puchong, Selangor',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onCancelNavigate,
              style: ElevatedButton.styleFrom(
                backgroundColor: _dangerColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              label: const Text(
                'Cancel Navigate',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugDialogMenu extends StatelessWidget {
  const _DebugDialogMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.bug_report, color: Colors.black45),
      onSelected: (value) {
        switch (value) {
          case 'deviation':
            showRouteDeviationDialog(context);
            break;
          case 'gps':
            showGpsUnavailableDialog(context);
            break;
          case 'already':
            showAlreadyAtDestinationDialog(context);
            break;
          case 'arrived':
            showArrivalSuccessDialog(context);
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'deviation', child: Text('Preview: Route deviation')),
        PopupMenuItem(value: 'gps', child: Text('Preview: GPS unavailable')),
        PopupMenuItem(value: 'already', child: Text('Preview: Already at destination')),
        PopupMenuItem(value: 'arrived', child: Text('Preview: Arrival success')),
      ],
    );
  }
}