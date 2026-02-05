# Repo-Crafter Changelog

All notable changes to Repo-Crafter will be documented in this file.

## [1.1.2-beta] - 2026-02-05

### Fixed
- Fixed JSON payload corruption caused by bash brace interpretation in template defaults
- Fixed missing `Accept` header for GitHub API (required: `application/vnd.github+json`)
- Fixed hardcoded DELETE endpoint - now uses platform-specific `repo_delete_endpoint`
- Fixed unbound variable error in `urls` array handling
- Fixed manifest (`REMOTE_STATE.yml`) being created for single-platform projects
- Fixed menu prompts being captured by command substitution (now output to stderr with /dev/tty fallback)
- Fixed missing return statement causing execution continuation after errors
- Fixed syntax error in create_new_project_workflow() cancel handler
- Fixed sleep timing from 10s to 5s for better UX

### Added
- Unified `detect_platform_from_url()` helper function (replaces 3 duplicate implementations)
- Unified `extract_host_from_url()` helper function
- Conflict detection showing "Remote has X new commits" / "You have X local commits not pushed"
- Platform selection removed from test_platform_config() to avoid interactive prompts
- Added /dev/tty fallback for stdin in interactive functions

### Changed
- Improved error handling with better I/O separation
- Platform configuration now fully declarative (no hardcoded endpoints in code)
- Enhanced stdin handling in select_platforms() and _select_project_from_dir()

### Notes
- This version includes critical bug fixes for API interactions and I/O handling
- All platforms now require `accept_header` and `repo_delete_endpoint` in config

## [1.1.1-beta] - 2026-01-16

### Security
- Added comprehensive input validation to prevent command injection attacks
- Implemented project name sanitization with whitelist validation
- Added path traversal protection
- Enhanced SSH authentication timeout handling and error exit.

### Added
- Support for platform-specific authentication header names (`PLATFORM_AUTH_HEADER_NAME`)
- Support for authentication query parameters (`PLATFORM_AUTH_QUERY_PARAM`)
- Enhanced error messages with detailed debugging information
- Improved multi-platform selection with proper validation
- Added validation for numeric input in platform selection
- Better command line tool verification with optional/required tool distinction
- New workflow: Convert single-platform projects to multi-platform configuration

### Fixed
- Fixed bounds checking in multi-platform selection (used `$idx` instead of `$input`)
- Improved SSH connection test to handle GitHub's "no shell access" response (exit code 1)
- Enhanced git repository initialization with better error handling
- Fixed repository deletion endpoint to use platform-specific format instead of hardcoded GitHub style
- Improved remote repository listing workflow with proper array handling

### Changed
- Updated script size from 1,04,103 to 1,06,442 bytes (significant feature additions)
- Enhanced user interface with more descriptive error messages
- Improved safety checks across all operations

### Notes
- This version includes substantial security improvements and user experience enhancements
- Backward compatibility maintained with existing platforms.conf configuration

## [1.0.0-beta] - 2026-01-12

### Fizes
- Full revamp of api-calling, conversion workflows, etc.

### Changed
- Initial beta release with basic GitHub and GitLab platform support
- Initial version branding as v1.0.0-beta

## [0.1.1-beta] - 2026-01-11

### Fixed
- Various bug fixes and improvements

## [0.1.0-beta] - 2026-01-11

Initial beta release with core functionality.

---

This changelog follows Semantic Versioning guidelines for beta releases.
