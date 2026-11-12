import 'package:flutter/material.dart';
import 'package:kazumi/services/storage/storage.dart';

Future<void> showSubtitleSettingsDialog(BuildContext context) async {
  var mode = GStorage.getSetting(SettingsKeys.subtitleProcessingMode);
  final endpoint = TextEditingController(
    text: GStorage.getSetting(SettingsKeys.subtitleTranslateEndpoint),
  );
  final apiKey = TextEditingController(
    text: GStorage.getSetting(SettingsKeys.subtitleTranslateApiKey),
  );

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('视频字幕处理'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: mode,
                    decoration: const InputDecoration(labelText: '字幕模式'),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('原始字幕')),
                      DropdownMenuItem(value: 1, child: Text('繁体转简体（本地）')),
                      DropdownMenuItem(value: 2, child: Text('翻译为简体中文（联网）')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => mode = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: endpoint,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: '翻译接口地址',
                      hintText: 'https://example.com/translate',
                      helperText: '兼容 LibreTranslate POST /translate',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: apiKey,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'API Key（可选）',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '仅处理播放器可读取的文字字幕轨道，不支持直接转换视频画面中烧录的字幕。'
                    '联网翻译会把字幕发送到所填服务器；API Key 保存在本机设置中，未加密。',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final url = Uri.tryParse(endpoint.text.trim());
                if (mode == 2 &&
                    (url == null ||
                        (url.scheme != 'https' && url.scheme != 'http') ||
                        url.host.isEmpty)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('请填写有效的翻译接口地址')),
                  );
                  return;
                }
                await GStorage.putSetting(
                    SettingsKeys.subtitleProcessingMode, mode);
                await GStorage.putSetting(
                    SettingsKeys.subtitleTranslateEndpoint,
                    endpoint.text.trim());
                await GStorage.putSetting(
                    SettingsKeys.subtitleTranslateApiKey,
                    apiKey.text.trim());
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  } finally {
    endpoint.dispose();
    apiKey.dispose();
  }
}
