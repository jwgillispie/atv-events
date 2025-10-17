import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

class CallFounderButton extends StatelessWidget {
  static const String founderPhoneNumber = '+13523271969';
  static const String founderName = 'Jozo';

  final bool isCompact;

  const CallFounderButton({super.key, this.isCompact = false});

  Future<void> _callFounder(BuildContext context) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: founderPhoneNumber);

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Unable to make phone call. Phone: $founderPhoneNumber',
              ),
              backgroundColor: HiPopColors.errorPlum,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return IconButton(
        icon: const Icon(Icons.phone),
        color: HiPopColors.primaryDeepSage,
        tooltip: 'Phone the Founder',
        onPressed: () => _callFounder(context),
      );
    }

    return Card(
      color: HiPopColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: HiPopColors.primaryDeepSage.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _callFounder(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: HiPopColors.primaryDeepSage.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.phone,
                  color: HiPopColors.primaryDeepSage,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Need Help? Phone the Founder',
                      style: TextStyle(
                        color: HiPopColors.darkTextPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Direct line to $founderName',
                      style: TextStyle(
                        color: HiPopColors.darkTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: HiPopColors.darkTextTertiary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget listTile({required BuildContext context, bool dense = false}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: HiPopColors.primaryDeepSage.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.phone,
          color: HiPopColors.primaryDeepSage,
          size: dense ? 20 : 24,
        ),
      ),
      title: Text(
        'Phone the Founder',
        style: TextStyle(
          color: HiPopColors.darkTextPrimary,
          fontWeight: FontWeight.w500,
          fontSize: dense ? 14 : 16,
        ),
      ),
      subtitle:
          dense
              ? null
              : Text(
                'Get help from $founderName',
                style: TextStyle(
                  color: HiPopColors.darkTextSecondary,
                  fontSize: 13,
                ),
              ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: HiPopColors.darkTextTertiary,
      ),
      onTap: () async {
        final CallFounderButton button = const CallFounderButton();
        await button._callFounder(context);
      },
    );
  }
}
