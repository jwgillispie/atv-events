// Conditional export based on platform
export 'ticket_scanner_screen_stub.dart'
    if (dart.library.io) 'ticket_scanner_screen_mobile.dart';