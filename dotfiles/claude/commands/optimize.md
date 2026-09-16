---
description: Analyze and optimize code for performance
argument-hint: <file-path> [--apply]
allowed-tools: ['Read', 'Grep', 'Edit', 'Bash']
model: sonnet
---

# Code Optimization Analysis

Please analyze the code at **$1** for performance optimization opportunities.

## Analysis Focus Areas

1. **Algorithm Complexity**
   - Identify O(n²) or worse operations that could be optimized
   - Look for unnecessary nested loops
   - Check for redundant computations

2. **Memory Usage**
   - Detect memory leaks or excessive allocations
   - Find unnecessary object copies or clones
   - Identify large data structures that could be optimized

3. **Bundle Size** (for JS/TS)
   - Check for large dependencies that could be tree-shaken
   - Identify unused imports
   - Suggest code-splitting opportunities

4. **Rendering Performance** (for React/UI)
   - Find missing React.memo or useMemo/useCallback
   - Detect unnecessary re-renders
   - Check for expensive operations in render path

5. **Database/Network**
   - Identify N+1 query problems
   - Find missing indexes or inefficient queries
   - Detect excessive API calls that could be batched

6. **General Best Practices**
   - Use of modern language features (map/filter/reduce vs loops)
   - Early returns to reduce nesting
   - Lazy loading opportunities
   - Caching opportunities

## Output Format

For each issue found, provide:

- **Location**: File path and line number
- **Issue**: Description of the performance problem
- **Impact**: Low/Medium/High severity
- **Suggestion**: Specific code improvement with example
- **Reasoning**: Why this optimization helps

## Auto-Apply Mode

If the arguments include `--apply`, automatically implement the HIGH impact optimizations using the Edit tool. For medium/low impact changes, provide the suggestions but don't apply them automatically.

## Additional Context

- Check if there are existing tests for the code
- Consider the trade-off between readability and performance
- Flag any optimizations that might affect behavior
- Use profiling data if available in comments or nearby files

## Documentation Requirements

**IMPORTANT**: If a tracking document exists (e.g., `docs/features/mass-cleanup-refactor.md`, `docs/ROADMAP.md`, or similar), you MUST:

1. **Update progress as you go** - Mark tasks as in_progress when starting, completed when done
2. **Document changes made** - Add notes about what was optimized and the impact
3. **Update metrics** - Adjust effort estimates, completion percentages, etc.
4. **Add new issues found** - Document any new technical debt or issues discovered during optimization
5. **Keep it current** - The tracking document should always reflect the latest state of work

This ensures continuity across sessions and helps track progress toward project goals.

---

**Remember**: Premature optimization is the root of all evil. Only suggest optimizations that have measurable impact.
