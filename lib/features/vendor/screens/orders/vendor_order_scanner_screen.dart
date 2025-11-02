// Conditional export based on platform
export 'vendor_order_scanner_screen_stub.dart'
    if (dart.library.io) 'vendor_order_scanner_screen_mobile.dart';
