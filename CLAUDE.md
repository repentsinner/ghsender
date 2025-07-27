## Development Notes

- Note that we don't want a web build as we can't use websockets from Chrome due to cross-site scripting issues. Please only focus on a macOS build/implementation for now
- Rather than downgrading dependencies when running into build issues, please attempt to upgrade other dependencies (e.g., run flutter pub upgrade or flutter upgrade as necessary)
- Don't rely on .backup files for file recovery; use git to handle version control and file recovery instead
- We never want to install CocoaPods globally. it should only be installed within the project. we never want to install _any_ tooling outside of the project root directory
- When faced with a toolchain error, do not try to go around the tooling we're trying to use. fix the tooling first
- do not use system tools. only use tools within the project root