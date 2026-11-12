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

  final localEndpoint = TextEditingController(
    text: GStorage.getSetting(SettingsKeys.subtitleLocalAiEndpoint),
  );
  final localModel = TextEditingController(
    text: GStorage.getSetting(SettingsKeys.subtitleLocalAiModel),
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
                      DropdownMenuItem(value: 3, child: Text('本地 AI（Ollama / LM Studio）')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => mode = value);
                      }
                    },
                  ),
                  if (mode == 2) ...[
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
                  ],
                  if (mode == 3) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: localEndpoint,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: '本地 AI 地址',
                        hintText: 'http://127.0.0.1:11434/v1/chat/completions',
                        helperText: 'Android 请填电脑局域网 IP，不能用手机自身的 localhost',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: localModel,
                      decoration: const InputDecoration(
                        labelText: '模型名称',
                        hintText: 'qwen2.5:3b',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    '仅处理播放器可读取的文字字幕轨道，不支持直接转换视频画面中烧录的字幕。'
                    '翻译模式将字幕发送到指定接口；本地 AI 请使用本机或可信局域网服务。API Key 保存在本机设置中，未加密。',
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
                final localUrl = Uri.tryParse(localEndpoint.text.trim());
                if (mode == 3 &&
                    (localUrl == null ||
                        (localUrl.scheme != 'http' &&
                            localUrl.scheme != 'https') ||
                        localUrl.host.isEmpty ||
                        localModel.text.trim().isEmpty)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('请填写有效的本地 AI 地址和模型名称')),
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
                await GStorage.putSetting(
                    SettingsKeys.subtitleLocalAiEndpoint,
                    localEndpoint.text.trim());
                await GStorage.putSetting(
                    SettingsKeys.subtitleLocalAiModel,
                    localModel.text.trim());
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
    localEndpoint.dispose();
    localModel.dispose();
  }
}
