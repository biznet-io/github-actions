#!/bin/bash

# Simple script to debug JSON parsing issues
# Usage: ./debug-json.sh

echo "=== ASDF Plugins JSON Debug Tool ==="
echo ""

if [[ -z "${ASDF_PLUGINS:-}" ]]; then
    echo "❌ ASDF_PLUGINS environment variable is not set"
    echo ""
    echo "Set it like this:"
    echo 'export ASDF_PLUGINS='\''[{"name": "deno", "version": "2.3.1"}]'\'''
    exit 1
fi

echo "✅ ASDF_PLUGINS is set"
echo "Length: ${#ASDF_PLUGINS} characters"
echo ""

echo "=== Raw Content ==="
echo "First 200 characters:"
echo "${ASDF_PLUGINS:0:200}"
echo ""
echo "Last 200 characters:"
echo "${ASDF_PLUGINS: -200}"
echo ""

echo "=== Character Analysis ==="
if [[ "$ASDF_PLUGINS" == *$'\r'* ]]; then
    echo "⚠️  Contains Windows line endings (\\r)"
else
    echo "✅ No Windows line endings detected"
fi

if [[ "$ASDF_PLUGINS" == *$'\t'* ]]; then
    echo "ℹ️  Contains tab characters"
else
    echo "✅ No tab characters"
fi

echo ""
echo "=== JSON Validation ==="

if ! command -v jq &> /dev/null; then
    echo "❌ jq is not installed"
    exit 1
fi

echo "✅ jq is available"

if echo "$ASDF_PLUGINS" | jq empty 2>/dev/null; then
    echo "✅ Valid JSON syntax"
else
    echo "❌ Invalid JSON syntax"
    echo ""
    echo "jq error:"
    echo "$ASDF_PLUGINS" | jq empty 2>&1
    exit 1
fi

json_type=$(echo "$ASDF_PLUGINS" | jq -r 'type' 2>/dev/null)
if [[ "$json_type" == "array" ]]; then
    echo "✅ JSON is an array"
else
    echo "❌ JSON is not an array, it's: $json_type"
    exit 1
fi

plugin_count=$(echo "$ASDF_PLUGINS" | jq length 2>/dev/null)
echo "✅ Array contains $plugin_count plugin(s)"

echo ""
echo "=== Pretty Printed JSON ==="
echo "$ASDF_PLUGINS" | jq .

echo ""
echo "=== Plugin Analysis ==="
for ((i=0; i<plugin_count; i++)); do
    echo "Plugin $((i+1)):"
    plugin_data=$(echo "$ASDF_PLUGINS" | jq -r ".[$i]" 2>/dev/null)
    
    name=$(echo "$plugin_data" | jq -r '.name // "MISSING"' 2>/dev/null)
    version=$(echo "$plugin_data" | jq -r '.version // "MISSING"' 2>/dev/null)
    url=$(echo "$plugin_data" | jq -r '.url // "not specified"' 2>/dev/null)
    env=$(echo "$plugin_data" | jq -c '.env // {}' 2>/dev/null)
    
    echo "  Name: $name"
    echo "  Version: $version"
    echo "  URL: $url"
    echo "  Env: $env"
    
    if [[ "$name" == "MISSING" || "$version" == "MISSING" ]]; then
        echo "  ❌ Missing required fields"
    else
        echo "  ✅ Valid plugin configuration"
    fi
    echo ""
done

echo "=== Debug Complete ==="