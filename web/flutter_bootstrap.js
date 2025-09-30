/*
 * This file is a custom bootstrap script for the Flutter web app.
 * It is responsible for initializing the Flutter engine and running the app.
 */

{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: function(engineInitializer) {
    var loading = document.querySelector('#loading');
    engineInitializer.initializeEngine().then(function(appRunner) {
      loading.remove();
      appRunner.runApp();
    });
  }
});
