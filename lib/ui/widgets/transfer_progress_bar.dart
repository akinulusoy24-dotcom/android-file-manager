import 'package:material_ui/material_ui.dart';

class TransferProgressBar extends StatelessWidget {
  final bool isTransferring;
  final String statusText;

  const TransferProgressBar({
    super.key,
    required this.isTransferring,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isTransferring
                    ? Icons.sync_rounded
                    : Icons.check_circle_outline_rounded,
                size: 16,
                color: isTransferring
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
          if (isTransferring) ...[
            const SizedBox(height: 6),
            const LinearProgressIndicator(minHeight: 4),
          ],
        ],
      ),
    );
  }
}
