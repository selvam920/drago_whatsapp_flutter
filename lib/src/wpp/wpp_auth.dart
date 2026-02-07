import 'package:drago_whatsapp_flutter/whatsapp_bot_platform_interface.dart';

class WppAuth {
  WpClientInterface wpClient;
  WppAuth(this.wpClient);

  /// check if User is Authenticated on current opened Page
  Future<bool> isAuthenticated() async {
    try {
      final result = await wpClient.evaluateJs(
          '''typeof window.WPP !== 'undefined' && window.WPP.conn.isAuthenticated();''');
      return result == true || result?.toString() == "true";
    } catch (e) {
      WhatsappLogger.log(e.toString());
      return false;
    }
  }

  /// to check if ChatScreen is loaded on the page
  Future<bool> isMainReady() async {
    try {
      final result = await wpClient.evaluateJs(
          '''typeof window.WPP !== 'undefined' && window.WPP.conn.isMainReady();''');
      return result == true || result?.toString() == "true";
    } catch (e) {
      WhatsappLogger.log(e.toString());
      return false;
    }
  }

  /// check if main is loaded
  Future<bool> isMainLoaded() async {
    try {
      final result = await wpClient.evaluateJs(
          '''
          (function() {
            if (typeof window.WPP === 'undefined') return false;
            if (window.WPP.conn.isMainLoaded()) return true;
            // Fallback: Check for Chat list existence or absence of loading screen
            const hasChatList = !!(document.getElementById('pane-side') || 
                                 document.querySelector('[data-testid="pane-side"]') ||
                                 document.querySelector('._3u6yB'));
            if (hasChatList) return true;

            const isLoading = !!(document.querySelector('[data-testid="loading-screen"]') || 
                               document.querySelector('.loading-screen'));
            
            // If we are authenticated but not loading anymore, we might be on main
            if (!isLoading && window.WPP.conn.isAuthenticated()) {
                 // Final check: is there something that looks like the app?
                 return !!document.querySelector('#app');
            }
            return false;
          })()
          ''',
          tryPromise: false,
        );
      return result == true || result?.toString() == "true";
    } catch (e) {
      WhatsappLogger.log(e.toString());
      return false;
    }
  }
  /// check if data is synced
  Future<bool> isSynced() async {
    try {
      final result = await wpClient.evaluateJs(
          '''typeof window.WPP !== 'undefined' && 
             typeof window.WPP.conn.isSynced === 'function' && 
             window.WPP.conn.isSynced();''');
      return result == true || result?.toString() == "true";
    } catch (e) {
      return false;
    }
  }
  /// To Logout
  Future logout() async {
    try {
      await wpClient.evaluateJs('''window.WPP.conn.logout();''');
    } catch (e) {
      throw "Logout Failed";
    }
  }
}
