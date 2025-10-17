import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/blocs/auth/auth_bloc.dart';
import 'package:atv_events/blocs/auth/auth_state.dart';
import '../services/ceo_email_blast_service.dart';

/// CEO-only screen for sending email blasts to users
class CeoEmailBlastScreen extends StatefulWidget {
  const CeoEmailBlastScreen({super.key});

  @override
  State<CeoEmailBlastScreen> createState() => _CeoEmailBlastScreenState();
}

class _CeoEmailBlastScreenState extends State<CeoEmailBlastScreen> {
  final CeoEmailBlastService _emailService = CeoEmailBlastService();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  String? _selectedUserType;
  bool? _filterPhoneVerified;
  bool? _filterPremium;
  bool? _filterVerified;

  Map<String, int> _userCounts = {};
  bool _isLoading = false;
  bool _isSending = false;
  List<Map<String, String>> _previewRecipients = [];

  @override
  void initState() {
    super.initState();
    _loadUserCounts();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadUserCounts() async {
    setState(() => _isLoading = true);
    try {
      final counts = await _emailService.getUserCounts();
      if (mounted) {
        setState(() {
          _userCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Error loading user counts: $e');
      }
    }
  }

  Future<void> _loadPreviewRecipients() async {
    setState(() => _isLoading = true);
    try {
      final recipients = await _emailService.getUserEmailsWithType(
        userType: _selectedUserType,
        phoneVerified: _filterPhoneVerified,
        isPremium: _filterPremium,
        isVerified: _filterVerified,
      );

      if (mounted) {
        setState(() {
          _previewRecipients = recipients;
          _isLoading = false;
        });

        _showPreviewDialog(recipients);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Error loading recipients: $e');
      }
    }
  }

  Future<void> _sendEmail() async {
    if (_subjectController.text.trim().isEmpty) {
      _showError('Please enter a subject');
      return;
    }
    if (_bodyController.text.trim().isEmpty) {
      _showError('Please enter email body');
      return;
    }
    if (_previewRecipients.isEmpty) {
      _showError('Please preview recipients first');
      return;
    }

    // Confirm before sending
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Send'),
        content: Text(
          'Send email to ${_previewRecipients.length} recipients?\n\n'
          'Subject: ${_subjectController.text}\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.accentDustyPlum,
            ),
            child: const Text('Send Email'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSending = true);

    try {
      final success = await _emailService.sendEmailBlast(
        subject: _subjectController.text.trim(),
        messageBody: _bodyController.text.trim(),
        recipients: _previewRecipients,
        fromName: 'HiPop Markets',
      );

      if (success && mounted) {
        // Log the blast
        final authState = context.read<AuthBloc>().state;
        if (authState is Authenticated) {
          await _emailService.logEmailBlast(
            subject: _subjectController.text.trim(),
            recipientCount: _previewRecipients.length,
            filters: _getFiltersDescription(),
            ceoUserId: authState.user.uid,
          );
        }

        setState(() => _isSending = false);
        _showSuccess('Email sent to ${_previewRecipients.length} recipients!');

        // Clear form
        _subjectController.clear();
        _bodyController.clear();
        setState(() => _previewRecipients = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _showError('Error sending email: $e');
      }
    }
  }

  String _getFiltersDescription() {
    final filters = <String>[];
    if (_selectedUserType != null) filters.add(_selectedUserType!);
    if (_filterPhoneVerified == true) filters.add('Phone Verified');
    if (_filterPremium == true) filters.add('Premium');
    if (_filterVerified == true) filters.add('Verified');
    return filters.isEmpty ? 'All Users' : filters.join(', ');
  }

  void _showPreviewDialog(List<Map<String, String>> recipients) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Preview: ${recipients.length} Recipients'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Text(
                'Filters: ${_getFiltersDescription()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: recipients.length,
                  itemBuilder: (context, index) {
                    final recipient = recipients[index];
                    final email = recipient['email'] ?? '';
                    final name = recipient['name'] ?? '';
                    final userType = recipient['userType'] ?? '';

                    return ListTile(
                      dense: true,
                      leading: Text('${index + 1}.'),
                      title: Text(
                        email,
                        style: const TextStyle(fontSize: 12),
                      ),
                      subtitle: name.isNotEmpty
                        ? Text(
                            '$name - $userType',
                            style: const TextStyle(fontSize: 10),
                          )
                        : Text(
                            userType,
                            style: const TextStyle(fontSize: 10),
                          ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendEmail();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.successGreen,
            ),
            child: const Text('Send Now'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: HiPopColors.errorPlum,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: HiPopColors.successGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return const Scaffold(
            body: Center(child: Text('Please sign in')),
          );
        }

        final userProfile = state.userProfile;
        if (userProfile == null || !userProfile.isCEO) {
          return const Scaffold(
            body: Center(child: Text('CEO access only')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Email Blast'),
            backgroundColor: HiPopColors.accentDustyPlum,
            foregroundColor: Colors.white,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // User counts card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'User Statistics',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  _buildStatChip('Total', _userCounts['total'] ?? 0),
                                  _buildStatChip('Vendors', _userCounts['vendors'] ?? 0),
                                  _buildStatChip('Shoppers', _userCounts['shoppers'] ?? 0),
                                  _buildStatChip('Organizers', _userCounts['organizers'] ?? 0),
                                  _buildStatChip('Verified', _userCounts['verified'] ?? 0),
                                  _buildStatChip('Phone Verified', _userCounts['phoneVerified'] ?? 0),
                                  _buildStatChip('Premium', _userCounts['premium'] ?? 0),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Filters
                      const Text(
                        'Filter Recipients',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: _selectedUserType,
                        decoration: const InputDecoration(
                          labelText: 'User Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All Users')),
                          DropdownMenuItem(value: 'vendor', child: Text('Vendors Only')),
                          DropdownMenuItem(value: 'shopper', child: Text('Shoppers Only')),
                          DropdownMenuItem(value: 'market_organizer', child: Text('Organizers Only')),
                        ],
                        onChanged: (value) => setState(() => _selectedUserType = value),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Phone Verified'),
                              value: _filterPhoneVerified ?? false,
                              tristate: true,
                              onChanged: (value) => setState(() => _filterPhoneVerified = value),
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Premium'),
                              value: _filterPremium ?? false,
                              tristate: true,
                              onChanged: (value) => setState(() => _filterPremium = value),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Email composition
                      const Text(
                        'Compose Email',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _bodyController,
                        decoration: const InputDecoration(
                          labelText: 'Message (will be wrapped in HiPop template)',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                          helperText: 'Your message will include HiPop branding and user-specific CTAs',
                        ),
                        maxLines: 10,
                      ),
                      const SizedBox(height: 12),

                      // Template preview
                      Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Email will include:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '• HiPop logo header\n'
                                '• Your custom message\n'
                                '• User-specific CTA button:\n'
                                '  - Vendors: "View Your Dashboard"\n'
                                '  - Shoppers: "Explore Popups"\n'
                                '  - Organizers: "Manage Your Markets"\n'
                                '• HiPop footer with links',
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _loadPreviewRecipients,
                              icon: const Icon(Icons.preview),
                              label: const Text('Preview Recipients'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_isSending || _previewRecipients.isEmpty) ? null : _sendEmail,
                              icon: _isSending
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label: Text(_isSending ? 'Sending...' : 'Send Email'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: HiPopColors.successGreen,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_previewRecipients.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Ready to send to ${_previewRecipients.length} recipients',
                          style: TextStyle(
                            color: HiPopColors.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildStatChip(String label, int count) {
    return Chip(
      label: Text('$label: $count'),
      backgroundColor: HiPopColors.accentDustyPlum.withOpacity(0.1),
      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
    );
  }
}
