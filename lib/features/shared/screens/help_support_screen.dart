import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import '../widgets/call_founder_button.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@hipopmarkets.com', // TODO: Update with real support email
      query: 'subject=HiPop Markets Support Request',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: HiPopColors.darkSurface,
        foregroundColor: HiPopColors.darkTextPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    HiPopColors.primaryDeepSage.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HiPopColors.primaryDeepSage.withOpacity(0.1),
                    ),
                    child: Icon(
                      Icons.support_agent,
                      size: 48,
                      color: HiPopColors.primaryDeepSage,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'How can we help you?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Get support, view policies, or contact us directly',
                    style: TextStyle(
                      fontSize: 14,
                      color: HiPopColors.darkTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Support Section
                  _buildSectionTitle('Quick Support'),
                  const SizedBox(height: 12),

                  // Phone the Founder
                  const CallFounderButton(),
                  const SizedBox(height: 12),

                  // Email Support
                  Card(
                    color: HiPopColors.darkSurface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: HiPopColors.darkBorder.withOpacity(0.5),
                      ),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: HiPopColors.primaryDeepSage.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.email,
                          color: HiPopColors.primaryDeepSage,
                          size: 24,
                        ),
                      ),
                      title: const Text(
                        'Email Support',
                        style: TextStyle(
                          color: HiPopColors.darkTextPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        'Send us an email for detailed inquiries',
                        style: TextStyle(
                          color: HiPopColors.darkTextSecondary,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: HiPopColors.darkTextTertiary,
                        size: 16,
                      ),
                      onTap: _sendEmail,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Legal & Policies Section
                  _buildSectionTitle('Legal & Policies'),
                  const SizedBox(height: 12),

                  // Legal Documents
                  _buildMenuItem(
                    context: context,
                    icon: Icons.description,
                    title: 'Terms & Privacy',
                    subtitle: 'View our terms of service and privacy policy',
                    onTap: () => context.push('/legal'),
                  ),

                  const SizedBox(height: 24),

                  // FAQs Section
                  _buildSectionTitle('Frequently Asked Questions'),
                  const SizedBox(height: 12),

                  _buildFAQItem(
                    question: 'How do I apply to a market?',
                    answer:
                        'Navigate to the Markets tab, find a market you\'re interested in, and tap "Apply Now". Fill out the application form and submit it for review.',
                  ),
                  _buildFAQItem(
                    question: 'How do vendor payments work?',
                    answer:
                        'Customers pay through the app when they pre-order. Vendors receive payouts after successful market completion, minus a small platform fee.',
                  ),
                  _buildFAQItem(
                    question: 'Can I sell at multiple markets?',
                    answer:
                        'Yes! You can apply to and participate in as many markets as you\'d like. Each market application is reviewed separately.',
                  ),
                  _buildFAQItem(
                    question: 'How do I manage my inventory?',
                    answer:
                        'Set quantity limits when creating products. The app automatically tracks inventory and prevents overselling.',
                  ),

                  const SizedBox(height: 24),

                  // App Info Section
                  _buildSectionTitle('App Information'),
                  const SizedBox(height: 12),

                  Card(
                    color: HiPopColors.darkSurfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'App Version',
                                style: TextStyle(
                                  color: HiPopColors.darkTextSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              const Text(
                                '1.0.0', // TODO: Get from package info
                                style: TextStyle(
                                  color: HiPopColors.darkTextPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Platform',
                                style: TextStyle(
                                  color: HiPopColors.darkTextSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                Theme.of(context).platform == TargetPlatform.iOS
                                    ? 'iOS'
                                    : 'Android',
                                style: const TextStyle(
                                  color: HiPopColors.darkTextPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: HiPopColors.darkTextPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: HiPopColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: HiPopColors.darkBorder.withOpacity(0.5)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: HiPopColors.primaryDeepSage.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: HiPopColors.primaryDeepSage, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: HiPopColors.darkTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: HiPopColors.darkTextSecondary, fontSize: 14),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: HiPopColors.darkTextTertiary,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFAQItem({required String question, required String answer}) {
    return Card(
      color: HiPopColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: HiPopColors.darkBorder.withOpacity(0.5)),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(
            Icons.help_outline,
            color: HiPopColors.vendorAccent,
            size: 24,
          ),
          title: Text(
            question,
            style: const TextStyle(
              color: HiPopColors.darkTextPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
          children: [
            Text(
              answer,
              style: TextStyle(
                color: HiPopColors.darkTextSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
