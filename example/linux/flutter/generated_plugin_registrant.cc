//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <drago_inappwebview/drago_inappwebview_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) drago_inappwebview_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "DragoInappwebviewPlugin");
  drago_inappwebview_plugin_register_with_registrar(drago_inappwebview_registrar);
}
