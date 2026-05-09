Vendored from `x_amap_flutter_map` 1.0.2 with a single Android fix:

- `ConvertUtil.java`: replace deprecated `io.flutter.view.FlutterMain` with `FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(...)` so the project builds on current Flutter (FlutterMain was removed; `FlutterLoader.getInstance()` is also gone).

- `AMapFlutterMapPlugin.java`: removed legacy v1 `registerWith(PluginRegistry.Registrar)` (type removed in current Flutter Android embedding); v2 `FlutterPlugin` registration remains.

Keep this directory in sync if you intentionally upgrade the upstream `x_amap_flutter_map` package.
