import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  final TextEditingController _messageController = TextEditingController();
  final Set<String> _selectedClassIds = {};
  bool _sending = false;
  String? _error;
  bool _sent = false;

  List<Map<String, dynamic>> get _classes {
    final ctx = AuthService.instance.userContext;
    if (ctx == null) return [];
    return ctx.classes
        .map((c) => Map<String, dynamic>.from(c))
        .toList();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    if (_selectedClassIds.isEmpty) {
      setState(() => _error = 'Please select at least one class.');
      return;
    }
    if (_messageController.text.trim().isEmpty) {
      setState(() => _error = 'Please write a message.');
      return;
    }

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Send Broadcast?'),
        content: Text(
          'This will send your message to all parents in '
          '${_selectedClassIds.length} class(es). '
          'Each parent will also receive an SMS.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await ApiService.sendBroadcast({
        'class_ids': _selectedClassIds.toList(),
        'message_type': 'text',
        'content': _messageController.text.trim(),
      });
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = 'Failed to send broadcast. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: const Text('New Broadcast'),
      ),
      body: _sent ? _buildSuccessState() : _buildForm(),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.campaign_rounded,
                  size: 40, color: AppColors.primary),
            )
                .animate()
                .scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            const Text(
              'Broadcast Sent!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ).animate(delay: 200.ms).fadeIn(),
            const SizedBox(height: 8),
            const Text(
              'Your message has been queued for delivery.\n'
              'Each parent will receive a push notification and SMS.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ).animate(delay: 300.ms).fadeIn(),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ).animate(delay: 400.ms).fadeIn(),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Broadcast info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.accent, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Broadcast messages are sent individually to each parent. '
                    'Replies will appear in their private thread.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.primaryDark),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 24),

          // Class selection
          const Text(
            'Select Class(es)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          if (_classes.isEmpty)
            const Text(
              'No classes assigned. Contact your school admin.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _classes.map((cls) {
                final id = cls['class_id'] as String? ?? '';
                final name =
                    '${cls['class_name'] ?? ''} ${cls['section'] ?? ''}';
                final selected = _selectedClassIds.contains(id);
                return FilterChip(
                  label: Text(name),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _selectedClassIds.add(id);
                    } else {
                      _selectedClassIds.remove(id);
                    }
                  }),
                  selectedColor: AppColors.primarySurface,
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 24),

          // Message
          const Text(
            'Message',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _messageController,
            maxLines: 6,
            maxLength: 1000,
            decoration: const InputDecoration(
              hintText: 'Type your announcement here…',
              alignLabelWithHint: true,
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ],

          const SizedBox(height: 24),

          // Preview label
          if (_selectedClassIds.isNotEmpty &&
              _messageController.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '📢 Class Announcement — '
                      '${_selectedClassIds.length} class(es) selected',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Send button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _sendBroadcast,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_sending ? 'Sending…' : 'Send Broadcast'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
