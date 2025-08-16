/*
 * TransparentMaterial base class for materials requiring non-premultiplied alpha blending
 * 
 * Provides correct blend mode setup for materials that need transparent rendering
 * without the premultiplied alpha that Flutter Scene's default renderer expects
 */

import 'package:flutter_scene/scene.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;

/// Base class for materials that require non-premultiplied alpha blending
/// 
/// Flutter Scene's default translucent pass expects premultiplied alpha output from shaders,
/// but the UnlitFragment shader outputs non-premultiplied colors. This base class provides
/// the correct blend equation for non-premultiplied alpha rendering.
abstract class TransparentMaterial extends UnlitMaterial {
  TransparentMaterial({super.colorTexture});

  @override
  bool isOpaque() {
    // Transparent materials always render in the translucent pass
    return false;
  }

  @override
  void bind(
    gpu.RenderPass pass,
    gpu.HostBuffer transientsBuffer,
    Environment environment,
  ) {
    // Call parent bind first for standard material setup
    super.bind(pass, transientsBuffer, environment);

    // Set correct blend equation for non-premultiplied alpha
    // Standard alpha blending: source * sourceAlpha + destination * (1 - sourceAlpha)
    pass.setColorBlendEnable(true);
    pass.setColorBlendEquation(
      gpu.ColorBlendEquation(
        colorBlendOperation: gpu.BlendOperation.add,
        sourceColorBlendFactor: gpu.BlendFactor.sourceAlpha,
        destinationColorBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha,
        alphaBlendOperation: gpu.BlendOperation.add,
        sourceAlphaBlendFactor: gpu.BlendFactor.one,
        destinationAlphaBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha,
      ),
    );
  }
}