#!/usr/bin/env python3
import re

# Read the current Godot editor settings
with open('/Users/sal76/Library/Application Support/Godot/editor_settings-4.5.tres', 'r') as f:
    content = f.read()

# Replace Java 24 path with Java 17 path
content = re.sub(
    r'/opt/homebrew/Cellar/openjdk/24\.0\.2/libexec/openjdk\.jdk/Contents/Home',
    '/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home',
    content
)

# Write the updated settings back
with open('/Users/sal76/Library/Application Support/Godot/editor_settings-4.5.tres', 'w') as f:
    f.write(content)

print('Java SDK path updated to Java 17')
