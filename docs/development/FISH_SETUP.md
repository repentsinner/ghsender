# Fish Shell Setup for ghSender

This guide helps you automatically activate Flutter tools when entering the ghSender project directory in Fish shell.

## Option 1: Manual Activation (Simple)

Every time you enter the project directory, run:
```fish
source ./tools/setup-fish.fish
```

## Option 2: Automatic with direnv (Recommended)

1. **Install direnv** (if not already installed):
   ```fish
   brew install direnv
   ```

2. **Add direnv to Fish config** (add to `~/.config/fish/config.fish`):
   ```fish
   direnv hook fish | source
   ```

3. **Allow the project** (run this once in the project directory):
   ```fish
   direnv allow
   ```

Now Flutter tools will automatically be available whenever you `cd` into the project!

## Option 3: Fish Directory Functions (Advanced)

Add this to your `~/.config/fish/config.fish`:

```fish
# Auto-activate ghSender environment
function __ghsender_check_directory --on-variable PWD
    if test -f "$PWD/.fish_env"
        source "$PWD/.fish_env"
    else if set -q __GHSENDER_ORIGINAL_PATH
        # Restore original PATH when leaving project
        set -gx PATH $__GHSENDER_ORIGINAL_PATH
        set -e __GHSENDER_ORIGINAL_PATH
        set -e FLUTTER_HOME
        set -e PUB_CACHE  
        set -e FLUTTER_ROOT
        echo "🐠 ghSender environment deactivated"
    end
end
```

## Verification

After setup, verify it works:
```fish
cd /Users/ritchie/development/ghsender
flutter --version
dart --version
```

## Troubleshooting

**Flutter not found?**
- Check that `toolchain/flutter/bin/flutter` exists
- Verify you're in the project root directory
- Try manual activation first: `source ./tools/setup-fish.fish`

**Path not updating?**
- Restart your terminal
- Check Fish config: `echo $PATH`
- Verify direnv is properly hooked in Fish