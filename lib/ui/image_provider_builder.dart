/// A strategy that converts an asset path into an [ImageProvider].
///
/// Used by widget tests to inject [MemoryImage]s without ever touching
/// `Image.asset` and the on-disk asset manifest. Production code leaves
/// the value `null` everywhere along the chain and falls back to
/// `Image.asset(path, bundle: imageBundle)`.
library;

import 'package:flutter/widgets.dart';

typedef ImageProviderBuilder = ImageProvider? Function(String assetPath);
