import 'package:flutter/material.dart';
import 'package:hyposense/l10n/gen/app_localizations.dart';

class FaqItem {
  final String question;
  final String answer;

  const FaqItem({required this.question, required this.answer});
}

class FaqCategory {
  final String title;
  final List<FaqItem> items;

  const FaqCategory({required this.title, required this.items});
}

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  static const _textGray = Color(0xFF9AA0A6);

  final Set<int> _expandedQuestions = {};

  AppLocalizations get t => AppLocalizations.of(context);

  /// Konten FAQ dibangun dari l10n sehingga ikut bahasa aplikasi.
  List<FaqCategory> get _categories => [
        FaqCategory(
          title: t.faqCatAbout,
          items: [
            FaqItem(question: t.faqQWhat, answer: t.faqAWhat),
            FaqItem(question: t.faqQHow, answer: t.faqAHow),
          ],
        ),
        FaqCategory(
          title: t.faqCatWearable,
          items: [
            FaqItem(question: t.faqQWear, answer: t.faqAWear),
            FaqItem(question: t.faqQMulti, answer: t.faqAMulti),
          ],
        ),
        FaqCategory(
          title: t.faqCatAlerts,
          items: [
            FaqItem(question: t.faqQAlarm, answer: t.faqAAlarm),
          ],
        ),
        FaqCategory(
          title: t.faqCatPrivacy,
          items: [
            FaqItem(question: t.faqQSecure, answer: t.faqASecure),
            FaqItem(question: t.faqQExport, answer: t.faqAExport),
          ],
        ),
      ];

  void _toggleQuestion(int id) {
    setState(() {
      if (_expandedQuestions.contains(id)) {
        _expandedQuestions.remove(id);
      } else {
        _expandedQuestions.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var itemId = 0;
    final categories = _categories;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final category in categories) ...[
                      _buildCategory(category, () => itemId++),
                      const SizedBox(height: 16),
                    ],
                    _buildDisclaimer(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.faqTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          t.faqSubtitle,
          style: const TextStyle(fontSize: 13, color: _textGray),
        ),
      ],
    );
  }

  Widget _buildCategory(FaqCategory category, int Function() nextId) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final item in category.items) _buildFaqItem(item, nextId()),
        ],
      ),
    );
  }

  Widget _buildFaqItem(FaqItem item, int id) {
    final isExpanded = _expandedQuestions.contains(id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _toggleQuestion(id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.question,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: _textGray,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState:
              isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              item.answer,
              style: const TextStyle(
                fontSize: 12.5,
                color: _textGray,
                height: 1.4,
              ),
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
        Divider(
            height: 1, color: Theme.of(context).colorScheme.outlineVariant),
      ],
    );
  }

  Widget _buildDisclaimer() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF16233A) : const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        t.faqDisclaimer,
        style: const TextStyle(fontSize: 12, height: 1.4),
      ),
    );
  }

  Widget _card({required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
