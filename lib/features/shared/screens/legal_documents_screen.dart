import 'package:flutter/material.dart';
import 'package:hipop/features/shared/services/utilities/url_launcher_service.dart';
import '../../../core/theme/hipop_colors.dart';

class LegalDocumentsScreen extends StatelessWidget {
  const LegalDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              HiPopColors.primaryDeepSage,
              HiPopColors.secondarySoftSage,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Legal Documents',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      
                      // Header Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity( 0.95),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: HiPopColors.primaryDeepSage.withOpacity( 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.security,
                              size: 48,
                              color: HiPopColors.primaryDeepSage,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Legal Information',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: HiPopColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your trust and safety are our top priorities',
                              style: TextStyle(
                                fontSize: 15,
                                color: HiPopColors.lightTextSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Legal Document Cards
                      _buildDocumentCard(
                        context: context,
                        title: 'Terms of Service',
                        description: 'Comprehensive terms for the HiPop three-sided marketplace platform',
                        icon: Icons.description_outlined,
                        color: HiPopColors.primaryDeepSage,
                        onTap: () => _navigateToDocument(context, 'terms'),
                      ),
                      const SizedBox(height: 12),
                      
                      _buildDocumentCard(
                        context: context,
                        title: 'Privacy Policy',
                        description: 'Data collection, analytics usage, and privacy protection details',
                        icon: Icons.privacy_tip_outlined,
                        color: HiPopColors.accentMauve,
                        onTap: () => _navigateToDocument(context, 'privacy'),
                      ),
                      const SizedBox(height: 12),
                      
                      _buildDocumentCard(
                        context: context,
                        title: 'Payment Terms',
                        description: 'Vendor and organizer subscriptions, Stripe integration, and payment security',
                        icon: Icons.payment_outlined,
                        color: HiPopColors.accentDustyPlum,
                        onTap: () => _navigateToDocument(context, 'payment'),
                      ),
                      const SizedBox(height: 24),

                      // Contact Support Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              HiPopColors.surfacePalePink.withOpacity( 0.9),
                              HiPopColors.surfaceSoftPink.withOpacity( 0.9),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: HiPopColors.lightBorder,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: HiPopColors.primaryDeepSage.withOpacity( 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.support_agent,
                                color: HiPopColors.primaryDeepSage,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Need Help?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: HiPopColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Contact us for any questions about our legal documents',
                              style: TextStyle(
                                fontSize: 14,
                                color: HiPopColors.lightTextSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _launchEmail(context),
                              icon: const Icon(Icons.email_outlined, size: 20),
                              label: const Text('hipopmarkets@gmail.com'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: HiPopColors.primaryDeepSage,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Footer
                      Center(
                        child: Text(
                          '© 2025 HiPop Markets. All rights reserved.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity( 0.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity( 0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity( 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity( 0.15),
                      color.withOpacity( 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: HiPopColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: HiPopColors.lightTextSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                color: color.withOpacity( 0.5),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDocument(BuildContext context, String documentType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LegalDocumentDetailScreen(
          documentType: documentType,
        ),
      ),
    );
  }

  Future<void> _launchEmail(BuildContext context) async {
    try {
      await UrlLauncherService.launchEmail('hipopmarkets@gmail.com');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to open email app. Please contact hipopmarkets@gmail.com'),
            backgroundColor: HiPopColors.primaryDeepSage,
          ),
        );
      }
    }
  }
}

// Separate screen for each legal document
class LegalDocumentDetailScreen extends StatelessWidget {
  final String documentType;

  const LegalDocumentDetailScreen({
    super.key,
    required this.documentType,
  });

  @override
  Widget build(BuildContext context) {
    String title;
    String content;

    switch (documentType) {
      case 'terms':
        title = 'Terms of Service';
        content = _getTermsOfService();
        break;
      case 'privacy':
        title = 'Privacy Policy';
        content = _getPrivacyPolicy();
        break;
      case 'payment':
        title = 'Payment Terms';
        content = _getPaymentTerms();
        break;
      default:
        title = 'Legal Document';
        content = 'Document not found.';
    }

    return Scaffold(
      backgroundColor: HiPopColors.lightBackground,
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            color: HiPopColors.lightTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(
          color: HiPopColors.primaryDeepSage,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              HiPopColors.surfacePalePink.withOpacity( 0.3),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Document Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: HiPopColors.primaryDeepSage.withOpacity( 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: HiPopColors.primaryDeepSage.withOpacity( 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getIconForDocument(documentType),
                      color: HiPopColors.primaryDeepSage,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: HiPopColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Last updated: January 2025',
                            style: TextStyle(
                              fontSize: 12,
                              color: HiPopColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Document Content
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: HiPopColors.primaryDeepSage.withOpacity( 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SelectableText(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    color: HiPopColors.lightTextPrimary,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Contact Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      HiPopColors.surfaceSoftPink.withOpacity( 0.5),
                      HiPopColors.surfacePalePink.withOpacity( 0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.help_outline,
                      color: HiPopColors.primaryDeepSage,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Questions? Contact us at hipopmarkets@gmail.com',
                        style: TextStyle(
                          fontSize: 13,
                          color: HiPopColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForDocument(String type) {
    switch (type) {
      case 'terms':
        return Icons.description_outlined;
      case 'privacy':
        return Icons.privacy_tip_outlined;
      case 'payment':
        return Icons.payment_outlined;
      default:
        return Icons.article_outlined;
    }
  }

  String _getTermsOfService() {
    return '''HiPop Markets Terms of Service

ABOUT HIPOP MARKETS
HiPop is a comprehensive three-sided marketplace platform that connects vendors, shoppers, and market organizers in the local pop-up market ecosystem. Our app facilitates discovery, booking, payment processing, and analytics across all user types.

USER TYPES AND FEATURES:

1. SHOPPERS (Free)
   • Discover local pop-up markets and vendors
   • Browse vendor products and services
   • Save favorite vendors and events
   • Access enhanced search and filtering
   • All features are free for shoppers

2. VENDORS (\$29/month premium tier)
   • Create and manage vendor profiles
   • Post products and services
   • Apply to participate in markets
   • Track sales and analytics
   • Premium: Advanced analytics, priority market placement, bulk messaging

3. MARKET ORGANIZERS (\$69/month premium tier)
   • Create and manage market events
   • Recruit and approve vendors
   • Manage market logistics
   • Access comprehensive analytics
   • Premium: Advanced reporting, vendor directory access, bulk communications

PAYMENT PROCESSING:
• All payments are processed securely through Stripe
• Subscription billing is automated and recurring
• Payment methods include cards, Apple Pay, and Google Pay
• All transactions are encrypted and PCI compliant
• Refunds are processed according to our refund policy

ANALYTICS AND DATA USAGE:
• We collect usage data to improve platform performance
• Analytics help vendors understand customer engagement
• Market organizers receive attendance and vendor performance metrics
• All data collection complies with privacy regulations
• Users can request data deletion per GDPR/CCPA requirements

MARKETPLACE RULES:
• All content must be accurate and appropriate
• Vendors must honor posted prices and availability
• Market organizers must provide accurate event information
• Users are responsible for their own transactions and agreements
• HiPop facilitates connections but does not guarantee outcomes

PLATFORM RESPONSIBILITIES:
• Maintain secure, reliable platform access
• Process payments and subscriptions accurately
• Provide customer support and dispute resolution
• Protect user data and privacy
• Ensure platform compliance with applicable laws

LIABILITY LIMITATIONS:
• HiPop Markets is not responsible for disputes between users
• We do not guarantee vendor or market quality
• Users participate at their own risk
• Maximum liability limited to subscription fees paid
• No warranty for uninterrupted service access

INTELLECTUAL PROPERTY:
• Users retain ownership of their content
• HiPop has license to use content for platform operations
• Respect copyright and trademark rights
• Report violations to hipopmarkets@gmail.com

ACCOUNT TERMINATION:
• We may suspend accounts for terms violations
• Users may cancel subscriptions anytime
• Data deletion available upon request
• Refunds subject to refund policy

MODIFICATIONS:
• Terms may be updated with notice
• Continued use constitutes acceptance
• Major changes communicated via email
• Current version always available in app

GOVERNING LAW:
• Governed by laws of Delaware, USA
• Disputes resolved through arbitration
• Class action waiver applies
• Legal notices to hipopmarkets@gmail.com

By using HiPop, you agree to these terms, our Privacy Policy, and Payment Terms.

Last updated: January 2025''';
  }

  String _getPrivacyPolicy() {
    return '''HiPop Markets Privacy Policy

DATA COLLECTION:
We collect information you provide directly, including:
• Account registration data (name, email, user type)
• Profile information and preferences
• Payment and subscription information
• Content you create (vendor posts, market listings)
• Communication and support interactions

ANALYTICS AND USAGE DATA:
• App usage patterns and feature interactions
• Device information and technical specifications
• Location data (when permitted) for market discovery
• Performance metrics and error reporting
• User engagement and session analytics

THIRD-PARTY INTEGRATIONS:
• Stripe for payment processing and subscription management
• Google Cloud Platform for data storage and analytics
• Firebase for user authentication and real-time features
• Google Maps for location services

HOW WE USE YOUR DATA:
• Provide and improve platform services
• Process payments and manage subscriptions
• Generate analytics and insights for all user types
• Send relevant notifications and updates
• Ensure platform security and prevent fraud
• Comply with legal and regulatory requirements

DATA SHARING:
• We do not sell personal information to third parties
• Aggregate analytics may be shared with market organizers
• Payment processing requires sharing data with Stripe
• We may share data to comply with legal requirements

YOUR RIGHTS:
• Access and update your profile information
• Request data deletion (subject to legal requirements)
• Opt out of non-essential communications
• Control location sharing permissions
• Review and manage subscription settings

DATA PROTECTION:
• Industry-standard encryption for data transmission
• Secure cloud storage with access controls
• Regular security audits and updates
• Employee access limited and monitored
• Incident response procedures in place

COOKIES AND TRACKING:
• Essential cookies for app functionality
• Analytics cookies for service improvement
• No third-party advertising cookies
• Cookie preferences manageable in settings

CHILDREN'S PRIVACY:
• Service not intended for users under 13
• No knowing collection from minors
• Parental requests honored promptly
• Age verification for certain features

INTERNATIONAL USERS:
• Data may be processed in the United States
• Appropriate safeguards for international transfers
• GDPR rights for European users
• CCPA rights for California residents

SECURITY MEASURES:
• End-to-end encryption for sensitive data
• Regular security audits and penetration testing
• Secure cloud infrastructure with access controls
• PCI DSS compliance for payment processing
• Employee data access is strictly limited and monitored

RETENTION:
• Account data retained while account is active
• Payment records retained per legal requirements
• Analytics data may be retained in aggregate form
• Deleted account data purged within 30 days

BREACH NOTIFICATION:
• Users notified within 72 hours of confirmed breach
• Detailed information about affected data provided
• Steps to protect yourself communicated
• Regulatory authorities notified as required

CONTACT US:
For privacy questions or concerns:
• Email: hipopmarkets@gmail.com
• Response time: Within 48 hours
• Data protection officer available
• Privacy complaints addressed promptly

CHANGES TO POLICY:
• Updates posted with effective date
• Material changes communicated via email
• 30-day notice for significant changes
• Previous versions available upon request

For questions about privacy, contact: hipopmarkets@gmail.com

Last updated: January 2025''';
  }

  String _getPaymentTerms() {
    return '''HiPop Markets Payment Terms

SUBSCRIPTION TIERS:

Vendor Premium - \$29.00/month
• Advanced analytics dashboard
• Priority placement in market search results
• Bulk messaging capabilities
• Enhanced vendor profile features
• Sales tracking and performance metrics
• Customer engagement tools
• Inventory management features
• Multi-market application management

Market Organizer Premium - \$69.00/month
• Comprehensive vendor management tools
• Advanced reporting and analytics
• Vendor directory access and recruitment tools
• Bulk communication features
• Priority support and consultation
• Event scheduling and coordination
• Revenue optimization insights
• Custom market branding options

PAYMENT PROCESSING:
• All payments processed through Stripe, Inc.
• Stripe handles payment security and PCI compliance
• Automatic recurring billing on subscription date
• Payment methods: Credit/debit cards, Apple Pay, Google Pay
• Secure tokenization prevents storage of payment details
• 3D Secure authentication when required
• Real-time payment verification
• Instant payment confirmation

BILLING POLICIES:
• Subscriptions billed monthly in advance
• Payment due on signup date each month
• Failed payments result in immediate service suspension
• Grace period of 3 days for payment resolution
• Account closure after 7 days of non-payment
• Proration for mid-cycle upgrades
• No partial month refunds
• Annual billing options available (contact support)

FREE TRIAL:
• 7-day free trial for new premium subscribers
• Full access to premium features during trial
• Automatic conversion to paid subscription
• Cancel anytime during trial period
• No charges if cancelled before trial ends
• One trial per user account
• Previous subscribers not eligible

PROMO CODES AND DISCOUNTS:
• Promotional codes may be available for new subscribers
• Discounts apply to first billing cycle unless specified
• Cannot be combined with other promotional offers
• Expires if not used within specified timeframe
• Subject to verification and fraud prevention
• Referral discounts available
• Seasonal promotions offered periodically
• Volume discounts for multiple accounts (contact sales)

REFUND POLICY:
• No refunds for partial month usage
• Technical issues may warrant prorated refunds
• Refund requests must be made within 30 days
• Processing time: 5-10 business days
• Refunds issued to original payment method
• Subscription cancellation doesn't guarantee refund
• Service credits offered for minor issues
• Exceptional circumstances reviewed case-by-case

PAYMENT SECURITY:
• End-to-end encryption for all transactions
• Tokenization prevents storage of card numbers
• Regular security audits and compliance checks
• Fraud detection and prevention systems
• Immediate notification of suspicious activity
• Two-factor authentication available
• Secure payment pages (SSL/TLS)
• PCI DSS Level 1 compliance

SUBSCRIPTION MANAGEMENT:
• Cancel anytime through app settings
• Cancellation effective at end of billing period
• Automatic renewal unless cancelled
• Upgrade/downgrade processed immediately
• Prorated charges for mid-cycle changes
• Pause subscription option available
• Reactivation retains previous data
• Subscription history accessible

DISPUTE RESOLUTION:
• Contact support within 60 days of charge
• Detailed transaction records provided
• Good faith effort to resolve disputes
• Chargeback prevention program
• Mediation available if needed
• Written documentation required
• Response within 5 business days

TAXES:
• Prices do not include applicable taxes
• Tax calculation based on billing address
• Compliance with state and federal tax laws
• Tax receipts available upon request
• VAT/GST added where applicable
• Tax exemption certificates accepted
• Quarterly tax statements available
• International taxes user responsibility

CURRENCY AND INTERNATIONAL PAYMENTS:
• Prices displayed in USD
• International cards accepted
• Currency conversion at current rates
• Additional fees may apply for international payments
• Local payment methods coming soon

ENTERPRISE BILLING:
• Custom pricing for 10+ accounts
• Invoice billing available
• Net 30 payment terms
• Volume discounts negotiable
• Dedicated account management
• Custom contracts available
• Contact: enterprise@hipopmarkets.com

PAYMENT FAILURE PROCEDURES:
1. Immediate email notification
2. 3 retry attempts over 72 hours
3. Account features limited after 3 days
4. Full suspension after 7 days
5. Data retained for 30 days
6. Reactivation upon successful payment

For payment support, contact: hipopmarkets@gmail.com

Last updated: January 2025''';
  }
}