// Copyright 2021 Sony Corporation. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <iostream>
#include <memory>
#include <string>
#include <vector>

#include <mechanix_common/dbus_instance_manager.h>
#include <mechanix_common/mechanix_common_plugin.h>

#include "flutter_embedder_options.h"
#include "flutter_window.h"

namespace {
constexpr char kAppId[] = "MechanixNotes";

// Returns true if the short flag takes a value as the next argument.
// These flags are used by flutter-elinux embedder.
bool ShortFlagTakesValue(char c) {
  switch (c) {
  case 'b': // --bundle
  case 'r': // --rotation
  case 'x': // --text-scaling-factor
  case 's': // --force-scale-factor
  case 't': // --title
  case 'a': // --app-id
  case 'w': // --width
  case 'h': // --height
    return true;
  default:
    return false;
  }
}
} // namespace

int main(int argc, char **argv) {
  // Separate engine arguments from Dart entrypoint arguments.
  // Engine args start with '--' or '-' (e.g., --bundle=/path, -b /path).
  // Everything else is passed to Dart as entrypoint arguments.
  std::vector<std::string> engine_args{argv[0]};
  std::vector<std::string> dart_args;

  for (int i = 1; i < argc; ++i) {
    std::string arg = argv[i];

    if (arg.rfind("--", 0) == 0) {
      // Long flag (--flag=value or --flag)
      engine_args.push_back(std::move(arg));
    } else if (arg.size() >= 2 && arg[0] == '-' && arg != "-") {
      // Short flag (-f or -f value)
      engine_args.push_back(std::move(arg));
      // If this flag takes a value, consume the next argument
      if (ShortFlagTakesValue(arg[1]) && i + 1 < argc) {
        engine_args.push_back(argv[++i]);
      }
    } else {
      // Non-flag argument: pass to Dart
      dart_args.push_back(std::move(arg));
    }
  }

  std::vector<char *> engine_argv;
  for (auto &s : engine_args) {
    engine_argv.push_back(s.data());
  }
  engine_argv.push_back(nullptr);

  FlutterEmbedderOptions options;
  if (!options.Parse(static_cast<int>(engine_args.size()),
                     engine_argv.data())) {
    return 0;
  }

  // Forward Dart args to the running instance (if any) and exit.
  if (!mechanix::MechanixCommon::GetInstance()->RegisterSingletonCheck(
          kAppId, dart_args)) {
    return 0;
  }

  // Creates the Flutter project.
  const auto bundle_path = options.BundlePath();
  const std::wstring fl_path(bundle_path.begin(), bundle_path.end());
  flutter::DartProject project(fl_path);
  project.set_dart_entrypoint_arguments(std::move(dart_args));

  flutter::FlutterViewController::ViewProperties view_properties = {};
  view_properties.width = options.WindowWidth();
  view_properties.height = options.WindowHeight();
  view_properties.view_mode = options.WindowViewMode();
  view_properties.view_rotation = options.WindowRotation();
  view_properties.title = options.WindowTitle();
  view_properties.app_id = options.WindowAppID();
  view_properties.use_mouse_cursor = options.IsUseMouseCursor();
  view_properties.use_onscreen_keyboard = options.IsUseOnscreenKeyboard();
  view_properties.use_window_decoration = options.IsUseWindowDecoraation();
  view_properties.text_scale_factor = options.TextScaleFactor();
  view_properties.enable_high_contrast = options.EnableHighContrast();
  view_properties.force_scale_factor = options.IsForceScaleFactor();
  view_properties.scale_factor = options.ScaleFactor();
  view_properties.enable_vsync = options.EnableVsync();

  // The Flutter instance hosted by this window.
  FlutterWindow window(view_properties, project);
  if (!window.OnCreate()) {
    return 0;
  }
  window.Run();
  window.OnDestroy();

  return 0;
}
