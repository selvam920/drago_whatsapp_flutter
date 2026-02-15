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
      await wpClient.evaluateJs(
        '''
        (async () => {
          if (typeof window.WPP !== 'undefined' && window.WPP.conn) {
             try {
                await window.WPP.conn.logout();
             } catch (e) {
                console.error("WPP.conn.logout Error", e);
             }
          }
          
          // Emit logout event before clearing data and reloading
          if (typeof window.onCustomEvent === 'function') {
            window.onCustomEvent("connectionEvent", "${ConnectionEvent.logout.name}");
          }

          try {
            window.localStorage.clear();
            window.sessionStorage.clear();
            
            // Unregister service workers
            if (navigator.serviceWorker) {
                const registrations = await navigator.serviceWorker.getRegistrations();
                for (const registration of registrations) {
                  await registration.unregister();
                }
            }

            // Clear IndexedDB
            if (window.indexedDB && window.indexedDB.databases) {
                const dbs = await window.indexedDB.databases();
                dbs.forEach(db => {
                    if (db.name) window.indexedDB.deleteDatabase(db.name);
                });
            }
          } catch (e) {}
          location.reload();
        })()
        ''',
        methodName: "logout",
      );
    } catch (e) {
      WhatsappLogger.log("Logout Error: $e");
      try {
        await wpClient.evaluateJs(
          'window.localStorage.clear(); window.sessionStorage.clear(); location.reload();',
          tryPromise: false,
        );
      } catch (_) {}
      throw "Logout Failed";
    }
  }
}
