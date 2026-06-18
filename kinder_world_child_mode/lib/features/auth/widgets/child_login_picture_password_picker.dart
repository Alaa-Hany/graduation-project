import 'package:flutter/material.dart';
import 'package:kinder_world/core/constants/app_constants.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/widgets/picture_password_row.dart';
import 'package:kinder_world/core/utils/color_compat.dart';

class ChildLoginPicturePasswordPicker extends StatelessWidget {
  const ChildLoginPicturePasswordPicker({
    super.key,
    required this.l10n,
    required this.selectedPictures,
    required this.pictureOptions,
    required this.onTogglePicture,
  });

  final AppLocalizations l10n;
  final List<String> selectedPictures;
  final List<PicturePasswordOption> pictureOptions;
  final ValueChanged<String> onTogglePicture;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.selectPicturePassword,
          style: TextStyle(
            fontSize: AppConstants.fontSize,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: pictureOptions.length,
          itemBuilder: (context, index) {
            final option = pictureOptions[index];
            final isSelected = selectedPictures.contains(option.id);
            final optionColor = resolvePicturePasswordColor(context, option);
            return InkWell(
              onTap: () => onTogglePicture(option.id),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? optionColor.withValuesCompat(alpha: 0.2)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? optionColor
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    width: 2,
                  ),
                ),
                child: Icon(
                  option.icon,
                  size: 28,
                  color: optionColor,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        PicturePasswordRow(
          picturePassword: selectedPictures,
          size: 20,
          showPlaceholders: true,
        ),
      ],
    );
  }
}
