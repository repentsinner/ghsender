#!/usr/bin/env fish
# Fish shell setup for ghSender project
# Usage: source ./tools/setup-fish.fish

set -l project_root (cd (dirname (status --current-filename))/..; and pwd)

# Set Flutter environment variables
set -gx FLUTTER_HOME "$project_root/toolchain/flutter"
set -gx PUB_CACHE "$project_root/toolchain/cache/pub"
set -gx FLUTTER_ROOT "$FLUTTER_HOME"

# Set GEM_HOME and add to PATH for Cocoapods
set -gx GEM_HOME "$project_root/toolchain/gems"

# Set Chrome executable for Flutter web development
set -gx CHROME_EXECUTABLE "$HOME/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Add Flutter to PATH (prepend to ensure local version takes priority)
if not contains "$FLUTTER_HOME/bin" $PATH
    set -gx PATH "$FLUTTER_HOME/bin" $PATH
end

# Add Cocoapods bin to PATH (prepend to ensure local version takes priority)
if not contains "$GEM_HOME/bin" $PATH
    set -gx PATH "$GEM_HOME/bin" $PATH
end

# Create cache directories if they don't exist
mkdir -p "$PUB_CACHE"

echo "✅ Activated ghSender Flutter toolchain for Fish"
echo "   Flutter Home: $FLUTTER_HOME"
echo "   Flutter: "(which flutter 2>/dev/null; or echo 'not found in PATH')
echo "   Dart: "(which dart 2>/dev/null; or echo 'not found in PATH')
echo "   Chrome: $CHROME_EXECUTABLE"
echo "   Pub Cache: $PUB_CACHE"
# Check if Cocoapods is available
if type -q pod
    echo "   Cocoapods: "(which pod)
else
    echo "   Cocoapods: not found in PATH"
end