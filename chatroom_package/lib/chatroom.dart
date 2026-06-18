/// Netrack Chatroom Package — Main Export
/// Exposes the public API for integrating the chatroom into any Flutter app.
library netrack_chatroom;

// Core service
export 'src/services/chatroom_service.dart';

// Main widget entry point
export 'src/widgets/chatroom_widget.dart';

// Models (for host app type safety)
export 'src/models/user_context.dart';
export 'src/models/chat_thread.dart';
export 'src/models/chat_message.dart';

// Theme
export 'src/theme/app_theme.dart';
