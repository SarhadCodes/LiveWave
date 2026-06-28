import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/app_theme.dart';
import '../widgets/status_card.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key});

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _version = '${packageInfo.version}+${packageInfo.buildNumber}';
      });
    } catch (e) {
      setState(() {
        _version = '2.4.0-build.82';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingXXL),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title
                    Text(
                      'Live Wave',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Technical details and system status of Live Wave.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.spacingXXL * 1.5),
                    
                    // Status Cards Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount;
                        if (constraints.maxWidth < 600) {
                          crossAxisCount = 2; // Mobile
                        } else if (constraints.maxWidth < 900) {
                          crossAxisCount = 4; // Tablet
                        } else {
                          crossAxisCount = 6; // Desktop/TV
                        }

                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: AppTheme.spacingL,
                          mainAxisSpacing: AppTheme.spacingL,
                          childAspectRatio: 1.0,
                          children: [
                            StatusCard(
                              icon: Icons.tv_rounded,
                              label: 'Application Name',
                              value: 'Live Wave',
                              iconColor: AppTheme.primaryColor,
                            ),
                            // Version and Theme removed as requested
                            StatusCard(
                              icon: Icons.check_circle_outline_rounded,
                              label: 'Performance',
                              value: 'System Optimal',
                              iconColor: AppTheme.accentGreen,
                            ),
                            StatusCard(
                              icon: Icons.cloud_outlined,
                              label: 'Environment',
                              value: 'Production',
                              iconColor: Colors.blue,
                            ),
                            StatusCard(
                              icon: Icons.settings_outlined,
                              label: 'Android TV Optimized',
                              value: 'TV Experience', // Shortened for smaller card
                              iconColor: AppTheme.accentGold,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Footer
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingXL),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'created with ',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '❤️',
                  style: TextStyle(fontSize: 12),
                ),
                Text(
                  ' by Sarhad',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'LIVE WAVE ENTERTAINMENT © 2025',
            style: TextStyle(
              color: AppTheme.textTertiary.withOpacity(0.5),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
        ],
      ),
    );
  }
}
