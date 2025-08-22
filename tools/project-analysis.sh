#!/bin/bash
# Project Analysis Helper Tool
# Analyzes project structure and generates reports

# Determine project root relative to this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== ghSender Project Analysis ==="
echo "Generated: $(date)"
echo "Project Root: $PROJECT_ROOT"
echo

echo "=== Project Structure ==="
find "$PROJECT_ROOT" -type f -name "*.md" | head -20
echo

echo "=== Documentation Coverage ==="
echo "Workflow docs: $(find "$PROJECT_ROOT/docs/workflows" -name "*.md" 2>/dev/null | wc -l)"
echo "Architecture docs: $(find "$PROJECT_ROOT/docs" -name "*.md" 2>/dev/null | wc -l)"
echo "Team docs: $(find "$PROJECT_ROOT/team" -name "*.md" 2>/dev/null | wc -l)"
echo

echo "=== Recent Changes ==="
cd "$PROJECT_ROOT"
git log --oneline -5 2>/dev/null || echo "No git history available"