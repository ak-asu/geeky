<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" class="logo" width="120"/>

# Implementing Flutter App Share Functionality: Receiving Content from Other Apps

Implementing the ability to receive shared content from other applications in Flutter, similar to how WhatsApp handles sharing, is a powerful feature that enhances user experience and app integration. This functionality allows your Flutter app to appear in the system share sheet and receive various types of content even when the app is not actively running.

## Understanding the Share Intent System

When users share content from other applications, the operating system presents a share sheet with available target applications[^1]. Your Flutter app can register itself as a recipient for specific types of content through intent filters on Android and share extensions on iOS[^2][^3]. The key aspect of this functionality is that it works regardless of whether your app is currently running, closed, or even removed from recent apps[^4][^5].

## Available Flutter Packages

Several Flutter packages facilitate share receiving functionality, each with different strengths and maintenance levels[^2][^3][^6]:


| Package | Latest Version | Platform Support | Key Features | Maintenance Status |
| :-- | :-- | :-- | :-- | :-- |
| `receive_sharing_intent` | 1.8.1 | Android 19+, iOS 12+ | Receive photos, videos, text, URLs, files from other apps. Supports iOS Share extension with auto-launch[^2] | Active but slower updates |
| `share_handler` | 0.0.23 | Android, iOS | Handle incoming shared content + add share suggestions/shortcuts. Better maintained than receive_sharing_intent[^3] | Actively maintained |
| `flutter_sharing_intent` | 1.1.1 | Android, iOS | Receive photos, videos, text, URLs, files. Supports multiple media sharing[^7] | Less active |

The `share_handler` package is currently recommended due to its active maintenance and additional features like share suggestions[^3][^8].

## Android Implementation

### AndroidManifest.xml Configuration

For Android, you need to configure intent filters in your `android/app/src/main/AndroidManifest.xml` file to register your app as a share target[^2][^3][^8]:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    
    <application android:name="io.flutter.app.FlutterApplication">
        <activity
            android:name=".MainActivity"
            android:launchMode="singleTask"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <!-- Intent filter for sharing text -->
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="text/*" />
            </intent-filter>
            
            <!-- Intent filter for sharing images -->
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="image/*" />
            </intent-filter>
            
            <!-- Intent filter for sharing multiple images -->
            <intent-filter>
                <action android:name="android.intent.action.SEND_MULTIPLE" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="image/*" />
            </intent-filter>
            
            <!-- Intent filter for sharing videos -->
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="video/*" />
            </intent-filter>
            
            <!-- Intent filter for sharing any file type -->
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="*/*" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```


### Launch Mode Configuration

The critical configuration for receiving intents when the app is closed is setting the `android:launchMode="singleTask"`[^2][^9][^10]. This launch mode ensures that only one instance of your activity exists in the system, and when a new intent is received, the `onNewIntent()` method is called instead of creating a new activity instance[^9][^11].

The `singleTask` launch mode provides several benefits[^10][^11]:

- Prevents creating multiple app instances when sharing content
- Ensures proper handling of intents when the app is backgrounded
- Maintains app state across share operations
- Enables the app to receive intents even when closed


## Flutter Code Implementation

### Basic Setup

Here's a complete implementation using the `share_handler` package[^3]:

```dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_handler/share_handler.dart';

class ShareReceiver extends StatefulWidget {
  @override
  _ShareReceiverState createState() => _ShareReceiverState();
}

class _ShareReceiverState extends State<ShareReceiver> {
  SharedMedia? sharedMedia;
  late StreamSubscription _streamSubscription;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    final handler = ShareHandlerPlatform.instance;
    
    // Get initial shared media when app is launched from share
    sharedMedia = await handler.getInitialSharedMedia();
    
    // Listen for shared media when app is already running
    _streamSubscription = handler.sharedMediaStream.listen((SharedMedia media) {
      if (!mounted) return;
      setState(() {
        sharedMedia = media;
      });
      _handleSharedContent(media);
    });
    
    if (!mounted) return;
    setState(() {});
  }

  void _handleSharedContent(SharedMedia media) {
    // Handle different types of shared content
    if (media.content != null) {
      // Handle shared text
      print("Received shared text: ${media.content}");
      // Process text content here
    }
    
    if (media.attachments != null && media.attachments!.isNotEmpty) {
      // Handle shared files/media
      for (var attachment in media.attachments!) {
        print("Received shared file: ${attachment.path}, Type: ${attachment.type}");
        // Process file attachments here
      }
    }
  }

  @override
  void dispose() {
    _streamSubscription.cancel();
    super.dispose();
  }
}
```


### Handling Different Content Types

The share handler can process various types of shared content[^2][^3]:

```dart
void _handleSharedContent(SharedMedia media) {
  // Text content
  if (media.content != null) {
    if (media.content!.contains('http')) {
      // Handle URLs
      _processSharedUrl(media.content!);
    } else {
      // Handle plain text
      _processSharedText(media.content!);
    }
  }
  
  // File attachments
  if (media.attachments != null) {
    for (var attachment in media.attachments!) {
      switch (attachment.type) {
        case SharedAttachmentType.image:
          _processSharedImage(attachment.path);
          break;
        case SharedAttachmentType.video:
          _processSharedVideo(attachment.path);
          break;
        case SharedAttachmentType.file:
          _processSharedFile(attachment.path);
          break;
      }
    }
  }
}
```


## Receiving Content When App is Closed

The key to receiving content when your app is not running lies in the proper configuration of launch modes and intent handling[^4][^5]. When configured correctly, the system will:

1. **Android**: Launch your app with the `singleTask` launch mode, ensuring only one instance exists[^9][^10]
2. **iOS**: The Share Extension captures the content and launches your main app via deep linking[^12][^13]

Both scenarios result in your Flutter app being launched or brought to the foreground, where the shared content can be processed immediately[^2][^3].

### Background Processing Considerations

While Flutter apps cannot truly run in the background on mobile platforms due to system limitations[^14][^15], the share functionality works by:

1. The system capturing the share intent/extension
2. Launching or resuming your app
3. Delivering the shared content to your Flutter code
4. Your app processing the content immediately upon launch

This creates the user experience of seamless background sharing, even though the app is actually launched to handle the content[^16][^17].

## Advanced Features

### Share Suggestions and Shortcuts

The `share_handler` package supports adding your app to share suggestions and creating dynamic shortcuts[^3][^8]:

```dart
// Record a sent message to enable share suggestions
ShareHandlerPlatform.instance.recordSentMessage(
  conversationIdentifier: "user-123",
  conversationName: "John Doe",
  conversationImageFilePath: imagePath,
  serviceName: "MyApp",
);
```


### Custom Intent Filters

You can customize which types of content your app accepts by modifying the intent filters[^8][^16]:

```xml
<!-- Accept only specific file types -->
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="application/pdf" />
</intent-filter>

<!-- Accept multiple images at once -->
<intent-filter>
    <action android:name="android.intent.action.SEND_MULTIPLE" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="image/*" />
</intent-filter>
```


## Best Practices and Considerations

### Performance Optimization

When handling shared content, especially large files or multiple attachments, consider[^18]:

1. **Lazy Loading**: Process content incrementally to avoid blocking the UI
2. **Background Processing**: Use Flutter isolates for heavy processing tasks[^17][^14]
3. **Memory Management**: Dispose of resources properly and avoid memory leaks

### Error Handling

Implement robust error handling for various scenarios[^2][^4]:

```dart
Future<void> _handleSharedContent(SharedMedia media) async {
  try {
    if (media.attachments != null) {
      for (var attachment in media.attachments!) {
        final file = File(attachment.path);
        if (await file.exists()) {
          // Process the file
          await _processFile(file);
        } else {
          // Handle missing file
          _showError("Shared file not found");
        }
      }
    }
  } catch (e) {
    // Handle processing errors
    _showError("Error processing shared content: $e");
  }
}
```


### Security Considerations

When handling shared content, especially files, ensure proper validation[^2][^19]:

1. **File Type Validation**: Verify file types match expected formats
2. **Size Limits**: Implement reasonable file size restrictions
3. **Content Scanning**: Scan text content for malicious URLs or content
4. **Sandboxing**: Process files in isolated environments when possible

## Troubleshooting Common Issues

### Android Issues

1. **App doesn't appear in share sheet**[^1][^20]:
    - Verify intent filters are correctly configured
    - Check that the `android:mimeType` matches the content being shared
    - Ensure the app is properly installed and not disabled
2. **Multiple app instances created**[^5][^21]:
    - Set `android:launchMode="singleTask"` in AndroidManifest.xml
    - Implement proper `onNewIntent()` handling if using custom MainActivity
3. **Intent not received when app is running**[^5]:
    - Ensure the stream subscription is active
    - Check that the activity lifecycle is properly managed

### iOS Issues

1. **Share Extension not appearing**[^12][^13]:
    - Verify Share Extension target is properly configured
    - Check Info.plist activation rules match content types
    - Ensure App Groups are configured identically in both targets
2. **App not launching from Share Extension**[^12][^13]:
    - Verify deep link URL scheme configuration
    - Check that the main app's Info.plist includes the custom URL scheme
    - Ensure ShareViewController properly inherits from the package's base class

## Testing and Validation

### Testing Strategy

To thoroughly test your share functionality[^22][^23]:

1. **Content Type Testing**: Test with various content types (text, images, videos, files)
2. **App State Testing**: Test sharing when app is closed, backgrounded, and active
3. **Multiple Content Testing**: Test sharing multiple items simultaneously
4. **Cross-Platform Testing**: Verify functionality on both Android and iOS
5. **Device Testing**: Test on various devices and OS versions

### Validation Checklist

- [ ] App appears in system share sheet for intended content types
- [ ] Shared content is received when app is closed
- [ ] Shared content is received when app is running
- [ ] Multiple content items are handled correctly
- [ ] Error cases are handled gracefully
- [ ] UI remains responsive during content processing
- [ ] Memory usage is reasonable for large files