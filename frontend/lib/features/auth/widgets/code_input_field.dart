import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smart_home_security/core/theme/app_colors.dart';

/// حقل إدخال الكود المتقدم
class CodeInputField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool isValid;
  final String hintText;
  final String? Function(String?)? validator;

  const CodeInputField({
    super.key,
    required this.controller,
    this.onChanged,
    this.isValid = false,
    this.hintText = '',
    this.validator,
  });

  @override
  State<CodeInputField> createState() => _CodeInputFieldState();
}

class _CodeInputFieldState extends State<CodeInputField>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
      if (_focusNode.hasFocus) {
        _glowController.repeat(reverse: true);
      } else {
        _glowController.stop();
        _glowController.reset();
      }
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: (widget.isValid ? AppColors.secure : AppColors.neonBlue)
                          .withValues(alpha: _glowAnimation.value * 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            validator: widget.validator,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
              letterSpacing: 4,
            ),
            inputFormatters: [
              UpperCaseTextFormatter(),
              LengthLimitingTextInputFormatter(12),
              HomeCodeFormatter(),
            ],
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                fontSize: 20.sp,
                color: AppColors.silver.withValues(alpha: 0.3),
                letterSpacing: 4,
              ),
              prefixIcon: Container(
                padding: EdgeInsets.all(12.w),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    widget.isValid ? Icons.check_circle : Icons.home,
                    key: ValueKey(widget.isValid),
                    color: widget.isValid ? AppColors.secure : AppColors.silver,
                    size: 24.sp,
                  ),
                ),
              ),
              suffixIcon: widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: AppColors.silver,
                        size: 20.sp,
                      ),
                      onPressed: () {
                        widget.controller.clear();
                        widget.onChanged?.call('');
                        HapticFeedback.lightImpact();
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.charcoal,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20.w,
                vertical: 20.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(
                  color: widget.isValid
                      ? AppColors.secure.withValues(alpha: 0.5)
                      : AppColors.darkGrey,
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(
                  color: widget.isValid ? AppColors.secure : AppColors.neonBlue,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: const BorderSide(
                  color: AppColors.error,
                  width: 2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// تحويل النص إلى أحرف كبيرة
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// تنسيق كود المنزل تلقائياً (DZ-XXXX-XXXX)
class HomeCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('-', '');
    final buffer = StringBuffer();
    
    for (int i = 0; i < text.length && i < 10; i++) {
      if (i == 2 || i == 6) {
        buffer.write('-');
      }
      buffer.write(text[i]);
    }
    
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
