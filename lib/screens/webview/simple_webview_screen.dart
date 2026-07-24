import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../theme/app_colors.dart';
import '../../widgets/neon_button.dart';

class WebViewArgs {
  final String url;
  final String title;
  final bool whiteBackground;
  const WebViewArgs({required this.url, required this.title, this.whiteBackground = false});
}

/// Generic in-app browser used for both Privacy Policy and Support pages.
class SimpleWebViewScreen extends StatefulWidget {
  final WebViewArgs args;
  const SimpleWebViewScreen({super.key, required this.args});

  @override
  State<SimpleWebViewScreen> createState() => _SimpleWebViewScreenState();
}

class _SimpleWebViewScreenState extends State<SimpleWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final bg = widget.args.whiteBackground ? Colors.white : AppColors.background;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(bg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (error) => setState(() {
            _loading = false;
            _error = error.description;
          }),
        ),
      )
      ..loadRequest(Uri.parse(widget.args.url));
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.args.whiteBackground ? Colors.white : AppColors.background;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(widget.args.title),
        backgroundColor: widget.args.whiteBackground ? Colors.white : AppColors.panel,
        foregroundColor: widget.args.whiteBackground ? Colors.black : AppColors.textPrimary,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            Container(
              color: bg,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: AppColors.accentCyan),
            ),
          if (_error != null && !_loading)
            Container(
              color: bg,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, size: 48, color: widget.args.whiteBackground ? Colors.black45 : AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load the page. Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: widget.args.whiteBackground ? Colors.black87 : AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  NeonButton.primary(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    size: NeonButtonSize.medium,
                    fullWidth: false,
                    onPressed: () {
                      setState(() => _error = null);
                      _controller.reload();
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
