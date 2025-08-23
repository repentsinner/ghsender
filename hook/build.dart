import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:flutter_gpu_shaders/build.dart';

void main(List<String> args) async {
  await build(args, (config, output) async {
    await buildShaderBundleJson(
      // This compiles shaders defined in the manifest into a binary bundle
      // that is embedded in the application. This allows for synchronous
      // loading at runtime via `gpu.ShaderLibrary.fromAsset()`.
      buildInput: config,
      buildOutput: output,
      manifestFileName: 'shaders/ghsender.shaderbundle.json',
    );
  });
}
