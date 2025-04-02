# Merge Comparison Tool

This tool helps compare changes between official repository versions and your custom forked repository versions, making it easier to identify potential merge conflicts or issues when updating your fork with new upstream changes.

## Overview

The script:

1. Compares changes between two commits/tags/branches in the official repository
2. Compares changes between two commits/tags/branches in your custom fork
3. Generates a detailed report of differences between these two sets of changes
4. Identifies files that were modified differently in both repositories
5. Lists files that were only changed in one repository but not the other

## Configuration

Create a `commits.conf` file with the following format:

```
official_old  tag:v1.2.3
official_new  tag:v1.2.4
debank_old    branch:your-branch
debank_new    branch:your-new-branch
working_directory /path/to/git/repository
```

### Configuration parameters:

- `official_old`: Starting point for official repository (tag, branch, or commit)
- `official_new`: Ending point for official repository (tag, branch, or commit)
- `debank_old`: Starting point for your custom fork (tag, branch, or commit)
- `debank_new`: Ending point for your custom fork (tag, branch, or commit)
- `working_directory`: Path to the Git repository where the comparison will be performed

### Reference formats:

References can be specified in the following formats:

- `tag:name` - A Git tag
- `branch:name` - A Git branch
- Direct commit hash

## Usage

1. Configure your comparison points in `commits.conf`
2. Run the script:
   ```bash
   chmod +x merge.sh
   ./merge.sh
   ```

## Output

The script creates a timestamped directory with:

1. `debank_changes/` - Diffs for changes in your fork
2. `official_changes/` - Diffs for changes in the official repository
3. `comparison/` - Files highlighting the differences between the two sets of changes
4. `comparison_report.txt` - Summary report

### Report categories:

- **FILES WITH DIFFERENT CHANGES**: Files that were modified in both repositories, but in different ways
- **FILES ONLY CHANGED IN OFFICIAL BRANCH**: Files modified in the official repository but not in your fork
- **FILES ONLY CHANGED IN DEBANK BRANCH**: Files modified in your fork but not in the official repository

## Use cases

- Verifying that upstream changes have been properly merged into your fork
