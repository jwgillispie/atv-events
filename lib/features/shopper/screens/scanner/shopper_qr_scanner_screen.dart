// Conditional export based on platform
export 'shopper_qr_scanner_screen_stub.dart'
    if (dart.library.io) 'shopper_qr_scanner_screen_mobile.dart';
