# Repo-Crafter Changelog

All notable changes to Repo-Crafter will be documented in this file.

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
