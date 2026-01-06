#!/usr/bin/env bash
# =============================================================================
# repo-crafter.sh - A safe, interactive Git repository manager for GitHub & GitLab
# =============================================================================
set -euo pipefail 

# ======================= CONFIGURATION & GLOBALS =============================
# Restricted directories
FORBIDDEN_DIRS=("/etc" "/etc/nixos" "/root" "/bin" "/sbin" "/usr")

# Path variables
LOCAL_ROOT="$HOME/Projects/Local_Projects"
REMOTE_ROOT="$HOME/Projects/Remote_Projects"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Config file is in the SAME directory as this script
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/repo-crafterFiles"
CONFIG_FILE="$CONFIG_DIR/platforms.conf"

# Global associative arrays
declare -A PLATFORM_ENABLED
declare -A PLATFORM_API_BASE
declare -A PLATFORM_SSH_HOST
declare -A PLATFORM_REPO_DOMAIN
declare -A PLATFORM_TOKEN_VAR
declare -A PLATFORM_REPO_CHECK_ENDPOINT
declare -A PLATFORM_REPO_CHECK_METHOD
declare -A PLATFORM_REPO_CHECK_SUCCESS_KEY
declare -A PLATFORM_REPO_CREATE_ENDPOINT
declare -A PLATFORM_REPO_CREATE_METHOD
declare -A PLATFORM_REPO_LIST_ENDPOINT
declare -A PLATFORM_REPO_LIST_SUCCESS_KEY
declare -A PLATFORM_WORK_DIR
declare -A PLATFORM_PAYLOAD_TEMPLATE
declare -A PLATFORM_SSH_URL_TEMPLATE
declare -A PLATFORM_DISPLAY_FORMAT
declare -A PLATFORM_AUTH_HEADER
# declare -A PLATFORM_AUTH_HEADER_OVERRIDES
AVAILABLE_PLATFORMS=()

# ======================= PLATFORM CONFIGURATION ===========================
# uses the platform.conf file to load available platforms
load_platform_config() {
    local current_section=""

    # Check if config file exists in script directory
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}❌ Configuration file 'platforms.conf' not found.${NC}"
        echo ""
        echo "Please create a 'platforms.conf' file in the usual config folder with the script's name:"
        echo -e "${YELLOW}  $CONFIG_DIR/platforms.conf${NC}"
        echo ""
        echo "With content like this example:"
        cat << 'EOF'

[github]
enabled = true
api_base = https://api.github.com
ssh_host = github.com
repo_domain = github.com
token_var = GITHUB_API_TOKEN
repo_check_endpoint = /repos/{owner}/{repo}
repo_check_method = GET
repo_check_success_key = id

[gitlab]
enabled = true
api_base = https://gitlab.com/api/v4
ssh_host = gitlab.com
repo_domain = gitlab.com
token_var = GITLAB_API_TOKEN
repo_check_endpoint = /projects/{owner}%2F{repo}
repo_check_method = GET
repo_check_success_key = id

# You can add other platforms similarly
EOF
        echo ""
        echo -e "${YELLOW}Then set the environment variables mentioned above (GITHUB_API_TOKEN, etc.).${NC}"
        exit 1
    fi

    echo -n "Loading platform configuration... "

    # Reset arrays
    AVAILABLE_PLATFORMS=()
    for array_name in PLATFORM_ENABLED PLATFORM_API_BASE PLATFORM_SSH_HOST \
                      PLATFORM_REPO_DOMAIN PLATFORM_TOKEN_VAR \
                      PLATFORM_REPO_CHECK_ENDPOINT PLATFORM_REPO_CHECK_METHOD \
                      PLATFORM_REPO_CHECK_SUCCESS_KEY \ PLATFORM_AUTH_HEADER \
                      PLATFORM_PAYLOAD_TEMPLATE \ PLATFORM_SSH_URL_TEMPLATE \
                      PLATFORM_DISPLAY_FORMAT \
                      PLATFORM_WORK_DIR ; do
        declare -gA "$array_name"
    done

    # Parse the INI file
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Remove comments and trim whitespace
        line=$(echo "$line" | sed 's/#.*$//;s/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$line" ]] && continue

        # Detect section header [platform]
        if [[ "$line" =~ ^\[([a-zA-Z0-9_-]+)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            PLATFORM_ENABLED["$current_section"]=false
            continue
        fi

        # Parse key = value pairs
        if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            case "$key" in
                # In the key parsing section, add:
                auth_header)
                    declare -g "PLATFORM_AUTH_HEADER"["$current_section"]="$value"
                    ;;
                work_dir)
                    PLATFORM_WORK_DIR["$current_section"]="$value"
                    ;;
                enabled)
                    [[ "$value" == "true" ]] && PLATFORM_ENABLED["$current_section"]=true
                    ;;
                api_base|ssh_host|repo_domain|token_var)
                    declare -g "PLATFORM_${key^^}"["$current_section"]="$value"
                    ;;
                repo_check_endpoint|repo_check_method|repo_check_success_key)
                    local array_key="${key^^}"
                    declare -g "PLATFORM_${array_key}"["$current_section"]="$value"
                    ;;
                repo_create_endpoint|repo_create_method|repo_list_endpoint|repo_list_success_key)
                    local array_key="${key^^}"
                    declare -g "PLATFORM_${array_key}"["$current_section"]="$value"
                    ;;
            esac
        fi
    done < "$CONFIG_FILE"

    # Build list of ENABLED platforms
    for platform in "${!PLATFORM_ENABLED[@]}"; do
        if [[ "${PLATFORM_ENABLED[$platform]}" == "true" ]] && \
           [[ -n "${PLATFORM_API_BASE[$platform]:-}" ]] && \
           [[ -n "${PLATFORM_TOKEN_VAR[$platform]:-}" ]]; then
            AVAILABLE_PLATFORMS+=("$platform")
        fi
    done

    if [[ ${#AVAILABLE_PLATFORMS[@]} -eq 0 ]]; then
        echo -e "${RED}❌ No properly configured platforms found in config.${NC}"
        echo -e "${YELLOW}   Check $CONFIG_FILE - ensure sections have enabled=true${NC}"
        return 1
    fi

    echo -e "${GREEN}✅ Loaded ${#AVAILABLE_PLATFORMS[@]} platform(s): ${AVAILABLE_PLATFORMS[*]}${NC}"
    return 0
}

# Reliable platform selection function
select_platforms() {
    local prompt="$1"
    local allow_multiple="$2"
    local choices=()

    # Display everything directly to the terminal first
    {
        echo ""
        echo -e "${BLUE}$prompt${NC}"

        # Show platform list
        for i in "${!AVAILABLE_PLATFORMS[@]}"; do
            echo "  $((i+1))) ${AVAILABLE_PLATFORMS[i]}"
        done

        if [[ "$allow_multiple" == "true" ]]; then
            echo "  a) All platforms"
            echo "  m) Multiple selection (e.g., 1,3,5)"
        fi
        echo "  x) Cancel"
        echo ""
    } > /dev/tty

    # Read input from the terminal
    read -rp "Enter your choice: " input < /dev/tty

    [[ "$input" == "x" ]] && return 1

    if [[ "$allow_multiple" == "true" ]]; then
        if [[ "$input" == "a" ]]; then
            choices=("${AVAILABLE_PLATFORMS[@]}")
        elif [[ "$input" == "m" ]]; then
            {
                echo "Enter platform numbers separated by commas (e.g., 1,3,5):"
            } > /dev/tty
            read -rp "Selection: " multi_input < /dev/tty
            IFS=',' read -ra selected_indices <<< "$multi_input"
            for idx in "${selected_indices[@]}"; do
                idx=$((idx-1))
                if [[ $idx -ge 0 && $idx -lt ${#AVAILABLE_PLATFORMS[@]} ]]; then
                    choices+=("${AVAILABLE_PLATFORMS[$idx]}")
                fi
            done
        elif [[ "$input" =~ ^[0-9]+$ ]]; then
            # Single number selection
            idx=$((input-1))
            [[ $idx -ge 0 && $idx -lt ${#AVAILABLE_PLATFORMS[@]} ]] && choices+=("${AVAILABLE_PLATFORMS[$idx]}")
        else
            # Assume comma-separated list directly
            IFS=',' read -ra selected_indices <<< "$input"
            for idx in "${selected_indices[@]}"; do
                idx=$((idx-1))
                if [[ $idx -ge 0 && $idx -lt ${#AVAILABLE_PLATFORMS[@]} ]]; then
                    choices+=("${AVAILABLE_PLATFORMS[$idx]}")
                fi
            done
        fi
    else
        # Single selection mode
        idx=$((input-1))
        if [[ $idx -ge 0 && $idx -lt ${#AVAILABLE_PLATFORMS[@]} ]]; then
            choices+=("${AVAILABLE_PLATFORMS[$idx]}")
        fi
    fi

    [[ ${#choices[@]} -eq 0 ]] && return 1

    # Output only the selected platforms (for command substitution)
    printf '%s\n' "${choices[@]}"
}

# Cleaner test function
test_platform_config() {
    echo -e "\n${BLUE}=== TESTING PLATFORM CONFIGURATION ===${NC}"

    # Skip option upfront
    if confirm_action "Run platform configuration tests?" "n" "Test config"; then
        echo -e "${YELLOW}Skipping tests.${NC}"
        return 0
    fi

    # Show loaded platforms
    echo "Available platforms: ${AVAILABLE_PLATFORMS[*]}"

    # Quick token check
    echo -e "\nToken status:"
    for platform in "${AVAILABLE_PLATFORMS[@]}"; do
        local token_var="${PLATFORM_TOKEN_VAR[$platform]}"
        local token_value="${!token_var}"
        if [[ -n "$token_value" ]]; then
            echo -e "  ${platform}: ${GREEN}✓ Token set${NC}"
        else
            echo -e "  ${platform}: ${RED}✗ Token NOT set${NC}"
        fi
        check_ssh_auth "${PLATFORM_SSH_HOST[$platform]}" "$platform"
    done

    echo -e "\nTesting platform selection..."
    local selected
    selected=$(select_platforms "Choose platform(s):" "true")

    if [[ -n "$selected" ]]; then
        echo -e "\n${GREEN}Selected:${NC}"
        while IFS= read -r platform; do
            echo "  - $platform"
        done <<< "$selected"
    else
        echo -e "\n${YELLOW}No selection made${NC}"
    fi

    echo ""
    read -rp "Press Enter to continue..." -n 1
    echo ""
    warn_duplicate_remote_connections
}

# ======================= CORE VALIDATION FUNCTIONS ===========================
# Check if a local Git repo exists
check_local_exists() {
    [[ -d "$1/.git" ]]
}

# Check SSH authentication for a given host
check_ssh_auth() {
    local host="$1"
    local platform_name="$2"  # Optional: platform name for display

    echo -n "Testing SSH connection to ${platform_name:-$host}... "

    local ssh_output
    ssh_output=$(ssh -T git@"$host" 2>&1)

    if echo "$ssh_output" | grep -q -E "successfully authenticated|Welcome to GitLab|You've successfully authenticated"; then
        echo -e "${GREEN}✅ Connected${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed${NC}"
        echo -e "${YELLOW}   Run 'ssh -T git@$host' to debug.${NC}"
        echo -e "${YELLOW}   Output: ${ssh_output:0:100}...${NC}"
        return 1
    fi
}

# Ensure we're not in a system directory
is_safe_directory() {
    local target_dir="$1"

    # First check for root directory
    if [[ "$target_dir" == "/" ]]; then
        echo -e "${RED}❌ ERROR: Cannot operate in root directory '/'.${NC}"
        echo "Please run from a safe directory (e.g., ~/Projects)."
        return 1
    fi

    # Then check other forbidden prefixes
    for dir in "${FORBIDDEN_DIRS[@]}"; do
        if [[ "$target_dir" == "$dir"* ]]; then
            echo -e "${RED}❌ ERROR: Cannot operate in system directory '$dir'.${NC}"
            return 1
        fi
    done
    return 0
}

# Check for existing Git repos with the same name in other directories
warn_duplicate_repo_name() {
    local project_name="$1"
    local parent_dir="$2"
    local existing_repos=()

    # Define where to search for existing projects (customize this list!)
    local search_dirs=("$HOME/Projects" "$HOME/Work" "$HOME/Development" "$HOME/git")

    # Get the absolute path of the parent directory for accurate comparison
    local abs_parent_dir
    abs_parent_dir=$(realpath -s "$parent_dir" 2>/dev/null || echo "$parent_dir")

    echo -n "Scanning for existing repos named '$project_name'... "

    # Search only in our specified project directories
    while IFS= read -r git_dir; do

        local repo_dir=$(dirname "$git_dir")
        local dir_name=$(basename "$repo_dir")

        # Get the absolute path of the found repo
        local abs_repo_dir
        abs_repo_dir=$(realpath -s "$repo_dir" 2>/dev/null || echo "$repo_dir")

        # Check if: 1) names match, AND 2) it's NOT within our target parent directory
        if [[ "$dir_name" == "$project_name" ]] && \
           [[ "$abs_repo_dir" != "$abs_parent_dir"* ]]; then
            existing_repos+=("$repo_dir")
        fi
    done < <(find "${search_dirs[@]}" -type d -name ".git" 2>/dev/null)

    if [[ ${#existing_repos[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  FOUND${NC}"
        echo -e "${YELLOW}Found ${#existing_repos[@]} existing repository(ies) with the same name:${NC}"
        for repo in "${existing_repos[@]}"; do
            echo -e "  - ${YELLOW}$repo${NC}"
        done
        echo -e "${YELLOW}You might want to use a different name to avoid confusion.${NC}"
        confirm_action "Continue creating a NEW repository with this name?" || return 1
    else
        echo -e "${GREEN}✅ Clear${NC}"
    fi
    return 0
}

# Warn about existing remote repos with similar names
# Uses the platform's API to list user repos and warn of similar names
warn_similar_remote_repos() {
    local platform="$1"
    local new_name="$2"
    local user_name="$3"

    echo -n "Checking for similar repositories on $platform... "

    local endpoint="${PLATFORM_REPO_LIST_ENDPOINT[$platform]}"
    if [[ -z "$endpoint" ]]; then
        echo -e "${YELLOW}⚠️  Skipped (list not configured).${NC}"
        return 0
    fi

    local response
    response=$(platform_api_call "$platform" "$endpoint" "GET")

    if [[ $? -ne 0 ]] || [[ -z "$response" ]]; then
        echo -e "${YELLOW}⚠️  API call failed.${NC}"
        return 0
    fi

    # Use jq to find repos where the name contains the new_name (case-insensitive)
    local similar_repos
    similar_repos=$(echo "$response" | jq -r --arg new_name "$new_name" \
        '.[] | select(.name | test($new_name; "i")) | .name' | head -5)

    if [[ -n "$similar_repos" ]]; then
        echo -e "${YELLOW}⚠️  FOUND${NC}"
        echo -e "${YELLOW}  Existing $platform repos with similar names:${NC}"
        while IFS= read -r repo; do
            echo -e "    - $repo"
        done <<< "$similar_repos"
        echo ""
        return 1 # Return a warning status
    else
        echo -e "${GREEN}✅ Clear${NC}"
        return 0
    fi
}

# Scans defined project directories and warns if multiple local folders point to the same remote
warn_duplicate_remote_connections() {
    local search_dirs=("$REMOTE_ROOT" "$LOCAL_ROOT") # Scan both trees
    echo -n "Checking for duplicate remote connections... "

    # Use associative array: key=remote_url, value="list_of_paths"
    declare -A remote_map
    local duplicate_found=0

    while IFS= read -r git_dir; do
        local repo_dir=$(dirname "$git_dir")
        local remote_url=$(cd "$repo_dir" && git remote get-url origin 2>/dev/null || git remote get-url github 2>/dev/null || echo "")

        if [[ -n "$remote_url" ]]; then
            remote_map["$remote_url"]+="|$repo_dir"
        fi
    done < <(find "${search_dirs[@]}" -type d -name ".git" 2>/dev/null)

    # Check which remotes have more than one path
    for url in "${!remote_map[@]}"; do
        local paths="${remote_map[$url]}"
        # Count the delimiters to get number of paths
        local count=$(echo "$paths" | tr '|' '\n' | grep -c .)
        ((count--)) # Subtract the initial empty element

        if [[ $count -gt 1 ]]; then
            if [[ $duplicate_found -eq 0 ]]; then
                echo -e "${YELLOW}⚠️  WARNING${NC}"
                duplicate_found=1
            fi
            echo -e "${YELLOW}  Remote: $url${NC}"
            echo "$paths" | tr '|' '\n' | grep -v "^$" | while IFS= read -r path; do
                echo -e "    -> $path"
            done
            echo ""
        fi
    done

    if [[ $duplicate_found -eq 0 ]]; then
        echo -e "${GREEN}✅ Clear${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Multiple local directories are connected to the same remote."
        echo -e "  This can cause confusion when pushing/pulling.${NC}"
        return 1
    fi
    return 0
}



# ========================================= REPOSITORIES FUNCTIONS ===================================


# Generic function to call a platform's API
platform_api_call() {
    local platform="$1"
    local endpoint="$2"
    local method="${3:-GET}"
    local data="${4:-}"

    local api_base="${PLATFORM_API_BASE[$platform]}"
    local token_var_name="${PLATFORM_TOKEN_VAR[$platform]}"
    local token_value="${!token_var_name}"

    # Get authentication template from config, default to "Bearer {token}"
    local auth_template="${PLATFORM_AUTH_HEADER[$platform]:-Bearer {token}}"
    # Check for endpoint-specific auth (advanced feature)
#    local endpoint_auth="${PLATFORM_AUTH_HEADER_OVERRIDES[$platform]}"
#    if [[ -n "$endpoint_auth" ]]; then
#        # Parse JSON to see if this endpoint has special auth
#        local override=$(echo "$endpoint_auth" | jq -r --arg ep "$endpoint" '.[$ep] // empty')
#        if [[ -n "$override" ]]; then
#            auth_template="$override"
#        fi
#    fi

    # After setting auth_header, handle special cases:
#    local auth_query="${PLATFORM_AUTH_QUERY_PARAM[$platform]:-}"
#    if [[ -n "$auth_query" ]]; then
#        # Add token as query parameter instead of header
#        endpoint="${endpoint}?${auth_query//\{token\}/$token_value}"
#    elif [[ -n "$auth_header" ]]; then
#        # Use header-based auth as before
#        curl_args+=(-H "Authorization: $auth_header")
#    fi

    #platform specific
    if [[ -z "$api_base" ]]; then
        echo -e "${RED}❌ No API base URL configured for platform: $platform${NC}" >&2
        return 1
    fi

    if [[ -z "$token_value" ]]; then
        echo -e "${RED}❌ Token for '$platform' (from \$$token_var_name) is not set.${NC}" >&2
        return 1
    fi

    # Build curl command
    local curl_args=(-s --max-time 30 -X "$method" -H "Content-Type: application/json")

    # GENERIC authentication: Replace {token} placeholder in template
    local auth_header="${auth_template//\{token\}/$token_value}"
    curl_args+=(-H "Authorization: $auth_header")

    # Add data payload if present
    [[ -n "$data" ]] && curl_args+=(-d "$data")

    # Execute
    curl "${curl_args[@]}" "${api_base}${endpoint}"
}

check_remote_exists() {
    local platform="$1"
    local repo_name="$2"
    local user_name="$3"

    # 1. Get all rules from configuration
    local endpoint="${PLATFORM_REPO_CHECK_ENDPOINT[$platform]}"
    local method="${PLATFORM_REPO_CHECK_METHOD[$platform]:-GET}"
    local success_key="${PLATFORM_REPO_CHECK_SUCCESS_KEY[$platform]:-id}"

    if [[ -z "$endpoint" ]]; then
        echo -e "${YELLOW}⚠️  Platform '$platform' not configured for repository checks.${NC}"
        echo -e "${YELLOW}   Add 'repo_check_endpoint' to its section in $CONFIG_FILE${NC}"
        return 2  # Configuration error
    fi

    # 2. GENERIC parameter substitution (works for ANY platform)
    # Replace {owner} and {repo} placeholders in the endpoint template
    endpoint="${endpoint//\{owner\}/$user_name}"
    endpoint="${endpoint//\{repo\}/$repo_name}"

    # Debug output (optional, remove in production)
    # echo -e "${BLUE}[DEBUG] Platform: $platform, Endpoint: $endpoint, Method: $method${NC}"

    # 3. Use the generic API caller
    local response
    if ! response=$(platform_api_call "$platform" "$endpoint" "$method"); then
        echo -e "${RED}❌ API call to $platform failed.${NC}"
        return 1
    fi

    # 4. GENERIC success detection using jq
    # The success_key (like 'id') is defined in config
    if echo "$response" | jq -e ".${success_key}" >/dev/null 2>&1; then
        return 0  # Repository exists
    else
        return 1  # Repository doesn't exist
    fi
}

# ==========================

# List existing remote repositories for a platform
list_remote_repos() {
    local platform="$1"

    echo -n "Fetching repositories from $platform... "
    local response
    response=$(platform_api_call "$platform" "${PLATFORM_REPO_LIST_ENDPOINT[$platform]}" "GET")

    if [[ $? -ne 0 ]] || [[ -z "$response" ]]; then
        echo -e "${RED}❌ Failed${NC}"
        return 1
    fi

    # Check if we got valid repos
    if ! echo "$response" | jq -e '.[]' >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  No repositories found${NC}"
        return 0
    fi

    echo -e "${GREEN}✅ Found${NC}"

    # Display with configurable format
    local format="${PLATFORM_DISPLAY_FORMAT[$platform]:-"{name} ({visibility}) - git@{ssh_host}:{path}.git"}"

    echo "$response" | jq -r --arg format "$format" \
        --arg ssh_host "${PLATFORM_SSH_HOST[$platform]}" \
        '.[] |
        ($format |
        gsub("{name}"; .name // "unnamed") |
        gsub("{visibility}"; (.private? // .visibility // "unknown") | if type == "boolean" then (if . then "private" else "public" end) else . end) |
        gsub("{ssh_host}"; $ssh_host) |
        gsub("{owner}"; (.owner.login // .namespace.path // .owner.username // "user")) |
        gsub("{path}"; (.full_name // .path_with_namespace // .full_path // (.owner.login + "/" + .name))))'
}

# Creating a new repository in remote platform of choice
create_remote_repo() {
    local platform="$1" repo_name="$2" visibility="$3" user_name="$4"

    # Recovery option
    echo -n "Creating repository on $platform... "
    if ! response=$(platform_api_call "$platform" "${PLATFORM_REPO_CREATE_ENDPOINT[$platform]}" "POST" "$template"); then
        echo -e "${RED}❌ API call failed${NC}"
        if confirm_action "Retry with different settings?" "n" "Retry"; then
            # Let user adjust something
            return 1
        fi
        return 1
    fi

    # Get template from config
    local template="${PLATFORM_PAYLOAD_TEMPLATE[$platform]:-{\"name\":\"{repo}\"}}"

    # Replace ALL placeholders GENERICALLY
    template="${template//\{repo\}/$repo_name}"
    template="${template//\{owner\}/$user_name}"

    # Handle {private} placeholder (true/false based on visibility)
    if [[ "$visibility" == "private" ]]; then
        template="${template//\{private\}/true}"
    else
        template="${template//\{private\}/false}"
    fi

    # Handle {visibility} placeholder
    template="${template//\{visibility\}/$visibility}"

    # Remove any remaining placeholders (platforms that don't use them)
    template="${template//\{private\}/}"
    template="${template//\{visibility\}/}"

    # Send request
    local response
    response=$(platform_api_call "$platform" "${PLATFORM_REPO_CREATE_ENDPOINT[$platform]}" "POST" "$template")

    # UX progress for repo creation through specific platform
    echo -n "Creating repository on $platform... "
    local response
    response=$(platform_api_call "$platform" "${PLATFORM_REPO_CREATE_ENDPOINT[$platform]}" "POST" "$template")
    if [[ $? -ne 0 ]] || [[ -z "$response" ]]; then
        echo -e "${RED}❌ API failed${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ Created${NC}"

    # ✅ CRITICAL: Check if API call succeeded
    # Use the configured success key (default to 'id')
    local success_key="${PLATFORM_REPO_CHECK_SUCCESS_KEY[$platform]:-id}"

    if ! echo "$response" | jq -e ".${success_key}" >/dev/null 2>&1; then
        echo "ERROR: Failed to create repository on $platform" >&2
        echo "API response: $response" >&2
        return 1
    fi

    # ✅ Try to extract SSH URL from API response first
    local ssh_url=""

    # Different platforms put SSH URL in different JSON fields
    ssh_url=$(echo "$response" | jq -r '.ssh_url // .ssh_url_to_repo // .clone_url // empty')

    # ✅ If API didn't return SSH URL, generate it from template
    if [[ -z "$ssh_url" ]]; then
        local ssh_template="${PLATFORM_SSH_URL_TEMPLATE[$platform]:-git@{ssh_host}:{owner}/{repo}.git}"
        ssh_url="${ssh_template//\{ssh_host\}/${PLATFORM_SSH_HOST[$platform]}}"
        ssh_url="${ssh_url//\{owner\}/$user_name}"
        ssh_url="${ssh_url//\{repo\}/$repo_name}"
    fi

    # ✅ PRESERVE YOUR ORIGINAL ERROR CHECKING
    if [[ -n "$ssh_url" ]]; then
        echo "$ssh_url"
        return 0
    else
        echo "ERROR: Failed to create repository (no SSH URL generated)" >&2
        return 1
    fi
}

# ======================= INTERACTIVE WORKFLOW FUNCTIONS ======================
##### Create a new project #####
create_new_project_workflow() {
  echo -e "\n${BLUE}=== CREATE NEW PROJECT ===${NC}"

  warn_duplicate_remote_connections

  echo "How do you want to start?"
  echo "  1) Create new local + remote repo (API)"
  echo "  2) Clone existing remote repo"
  echo "  3) Create local-only project (no binding)"
  echo "  x) ← Back to Main Menu"
  read -rp "Choice (1-3 or x): " choice

  case "$choice" in
    1) _create_with_new_remote ;;
    2) _clone_existing_remote ;;
    3) _create_local_only ;;
    x|X) echo -e "${YELLOW}Cancelled.${NC}" return ;;
    *) echo -e "${RED}Invalid choice.${NC}" ;;
  esac
}

# Helper: Create local repo + API remote
_create_with_new_remote() {
  local project_name platforms platform_array visibility target_dir user_name

  # Get project name
  project_name=$(_prompt_project_name)
  [[ -z "$project_name" ]] && return


  # Select platforms
  platforms=$(select_platforms "Choose platforms:" "true") || return
  IFS=$'\n' read -ra platform_array <<< "$platforms"

  # Determine directory
  if [[ ${#platform_array[@]} -eq 1 ]]; then
    target_dir="$REMOTE_ROOT/${PLATFORM_WORK_DIR[${platform_array[0]}]}/$project_name"
  else
    target_dir="$REMOTE_ROOT/Multi-server/$project_name"
  fi

  # Warning about duplicate local repo
  if ! warn_duplicate_repo_name "$project_name" "$(dirname "$target_dir")"; then
    echo -e "${YELLOW}Operation cancelled.${NC}"
    return 1
  fi

  # checking duplicate repo names
  for platform in "${platform_array[@]}"; do
    echo -n "Checking for similar repos on $platform... "
    # This function needs to be written/adapted to use the new config system
    if warn_similar_remote_repos "$platform" "$project_name" "$user_name"; then
        echo -e "${YELLOW}Similar names found. Please review.${NC}"
        confirm_action "Continue creating '$project_name' on $platform?" || continue
    else
        echo -e "${GREEN}Clear.${NC}"
    fi
  done

  # Select visibility
  visibility=$(_prompt_visibility)
  [[ -z "$visibility" ]] && return


  # Create local
  execute_safe "Create project directory" mkdir -p "$target_dir"
  execute_safe "Change directory" cd "$target_dir"
  execute_safe "Initialize git" git init -b main
  execute_safe "Create README" sh -c "echo '# $project_name' > README.md"

  # Setup gitignore
  gitignore_maker "$target_dir" "first-push"
  local gitignore_result=$?
  local gitignore_strategy="normal"
  # Returns: 0=success, 1=cancelled
  if [[ $gitignore_result -eq 0 ]]; then
  echo -e "${GREEN}✅ Gitignore configured${NC}"
  else
  echo -e "${YELLOW}⚠️  Gitignore setup cancelled${NC}"
  fi


  # Create remotes
  user_name=$(git config --global user.name)
  for platform in "${platform_array[@]}"; do
    echo -n "Creating $platform repo... "
    warn_similar_remote_repos "$platform" "$project_name" "$user_name"
    if [[ $? -eq 1 ]]; then
        read -rp "Continue creating '$project_name' on $platform? (y/N): " -n 1
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && continue
    fi
    if remote_url=$(execute_dangerous "Create $platform repository" create_remote_repo "$platform" "$project_name" "$visibility" "$user_name"); then
      echo -e "${GREEN}✅${NC}"
      execute_dangerous "Add git remote" git remote add "$platform" "$remote_url"

      # Add files & push
      if [[ "$gitignore_strategy" == "exclude" ]]; then
        # Already moved to .git/info/exclude, just add other files
        execute_safe "Stage files" git add :/ 2>/dev/null || execute_safe "Stage files" git add .
      else
        execute_safe "Stage files" git add .
      fi
      execute_safe "Initial commit" git commit -m "Initial commit"
      execute_dangerous "Push to $platform" git push -u "$platform" main && echo -e "${GREEN}✅ Pushed${NC}" || echo -e "${YELLOW}⚠️ Push failed${NC}"
    else
      echo -e "${RED}❌ Failed${NC}"
    fi
  done

  # Generate manifest for multi-platform
  if [[ ${#platform_array[@]} -gt 1 ]]; then
    cat > "$target_dir/PLATFORMS.md" << EOF
# Multi-Platform Project: $project_name
**Created:** $(date)

## Platforms
$(printf '- %s\n' "${platform_array[@]}")

## Remote URLs
$(cd "$target_dir" && for p in "${platform_array[@]}"; do echo "- $p: $(git remote get-url "$p")"; done)

## Push Commands
$(printf 'git push %s main\n' "${platform_array[@]}")
EOF
    git add PLATFORMS.md && execute_safe commit --amend --no-edit >/dev/null
  fi

  cd - >/dev/null
  echo -e "\n${GREEN}✅ Done!${NC}"
  sleep 5
  _pause_if_dry_run
}

# Helper: Clone existing repo
_clone_existing_remote() {
  echo -e "\n${YELLOW}Select platform:${NC}"
  platforms=$(select_platforms "Choose platform:" "false") || return
  local platform="$platforms"

  list_remote_repos "$platform"
  echo -e "${YELLOW}Note: For organization repos, use 'org-name/repo-name' format${NC}"
  read -rp "Repository to clone (owner/repo): " repo_path
  [[ -z "$repo_path" ]] && return

  local dest_dir="$REMOTE_ROOT/${PLATFORM_WORK_DIR[$platform]}/$(basename "$repo_path" .git)"
  check_ssh_auth "${PLATFORM_SSH_HOST[$platform]}" "$platform"
  if [[ $? -ne 0 ]]; then
      echo -e "${RED}❌ SSH not configured for $platform. Cannot clone.${NC}"
      return 1
  fi
  execute_dangerous "Clone repository" git clone "git@${PLATFORM_SSH_HOST[$platform]}:$repo_path.git" "$dest_dir" && \
    echo -e "${GREEN}✅ Cloned to $dest_dir${NC}" || \
    echo -e "${RED}❌ Clone failed${NC}"
  sleep 5
  _pause_if_dry_run
}

# Helper: Create local-only project
_create_local_only() {
  local project_name dest_dir

  read -rp "Project name: " project_name
  [[ -z "$project_name" ]] && return

  dest_dir="$LOCAL_ROOT/$project_name"
  [[ -d "$dest_dir" ]] && { echo -e "${RED}Exists.${NC}"; return; }

  execute_safe "Create project directory" mkdir -p "$dest_dir"
  execute_safe "Change to project directory" cd "$dest_dir"
  execute_safe "Initialize git repository" git init -b main
  execute_safe "Create README.md" sh -c "echo '# $project_name' > README.md"
  git add README.md && git commit -m "Initial commit" >/dev/null

  echo -e "${GREEN}✅ Created at $dest_dir${NC}"
  echo -e "${YELLOW}Note: Unbound project. Use 'Bind Local → Remote' later if needed.${NC}"
  sleep 5
  _pause_if_dry_run
}

##### Convert a local project #####
convert_local_to_remote_workflow() {
  echo -e "\n${BLUE}=== BIND LOCAL PROJECT TO REMOTE ===${NC}"

  # === LIST PROJECTS BEFORE SELECTION ===
  local source_dir
  source_dir=$(_select_project_from_dir "$LOCAL_ROOT" "Projects available to bind:") || return
  project_name=$(basename "$source_dir")

  # 2. Choose platform(s) (single or multi)
  platforms=$(select_platforms "Bind to which platform(s)?" "true")
  [[ $? -ne 0 ]] && return
  IFS=$'\n' read -ra platform_array <<< "$platforms"

  # 3. Determine destination
  local dest_dir
  if [[ ${#platform_array[@]} -eq 1 ]]; then
    dest_dir="$REMOTE_ROOT/${PLATFORM_WORK_DIR[${platform_array[0]}]}/$project_name"
  else
    dest_dir="$REMOTE_ROOT/Multi-server/$project_name"
  fi

  # 4. Move project
  if [[ -d "$dest_dir" ]]; then
    echo -e "${RED}Destination exists: $dest_dir${NC}"
    confirm_action "Destination exists. Overwrite?" || return
  fi

  execute_dangerous "Move project to remote directory" mv "$source_dir" "$dest_dir" || {
    echo -e "${RED}Move failed.${NC}"; return
  }

  cd "$dest_dir"

  # 5. Initialize git if needed
  if ! check_local_exists "$dest_dir"; then
    git init -b main
  fi

  # 6. Add remote(s)
  for platform in "${platform_array[@]}"; do
    local user_name=$(git config --global user.name)
    local remote_url="git@${PLATFORM_SSH_HOST[$platform]}:$user_name/$project_name.git"

    if git remote get-url "$platform" &>/dev/null; then
      execute_dangerous remote set-url "$platform" "$remote_url"
    else
      execute_dangerous remote add "$platform" "$remote_url"
    fi
    echo -e "${GREEN}✓ Added remote: $platform → $remote_url${NC}"
  done

  # 7. Create manifest for multi-platform
  if [[ ${#platform_array[@]} -gt 1 ]]; then
    cat > PLATFORMS.md << EOF
# Multi-Platform Project: $project_name
...
EOF
  fi

  echo -e "\n${GREEN}✅ Project bound and moved to $dest_dir${NC}"
  cd - >/dev/null
  _pause_if_dry_run
}

##### Convert a remote project #####
convert_remote_to_local_workflow() {
  echo -e "\n${BLUE}=== UNBIND REMOTE PROJECT TO LOCAL ===${NC}"

  # === LIST BOUND PROJECTS ===
  local projects=()
  while IFS= read -r git_dir; do
    projects+=("$(dirname "$git_dir")")
  done < <(find "$REMOTE_ROOT" -name ".git" -type d)

  local source_dir
  source_dir=$(_select_project_from_dir "$REMOTE_ROOT" "Projects available to bind:") || return
  project_name=$(basename "$source_dir")
  local dest_dir="$LOCAL_ROOT/$project_name"

  # 2. Confirm unbinding
  echo -e "${YELLOW}This will:${NC}"
  echo "  - Remove ALL git remotes"
  echo "  - Move project to $dest_dir"
  echo "  - Delete PLATFORMS.md if exists"
  confirm_action "This will remove ALL git remotes and move project to Local_Projects/" || return

  cd "$source_dir"

  # 3. Remove remotes
  git remote | while read -r remote; do
      execute_dangerous "Remove remote $remote" git remote remove "$remote" && \
      echo -e "${GREEN}✓ Removed remote: $remote${NC}"
  done

  # 4. Delete manifest
  [[ -f "PLATFORMS.md" ]] && execute_safe rm -f "PLATFORMS.md"

  cd - >/dev/null

  # 5. Move directory
  if [[ -d "$dest_dir" ]]; then
    echo -e "${RED}Destination exists: $dest_dir${NC}"
    confirm_action "Destination exists. Overwrite?" || return
  fi

  execute_dangerous "Move project to local directory" mv "$source_dir" "$dest_dir" || {
    echo -e "${RED}Move failed.${NC}"; return
  }

  echo -e "\n${GREEN}✅ Project unbound and moved to $dest_dir${NC}"
  _pause_if_dry_run
}



# Function to list repos from available platform (given user account)
list_remote_repos_workflow() {
    echo -e "\n${BLUE}=== LIST REMOTE REPOSITORIES ===${NC}"

    # Select platforms
    local platforms
    platforms=$(select_platforms "Choose platform(s) to list:" "true")
    if [[ $? -ne 0 ]] || [[ -z "$platforms" ]]; then
        echo -e "${YELLOW}Cancelled.${NC}"
        return
    fi

    # Process each selected platform
    local platform_count=0
    while IFS= read -r platform; do
        [[ -z "$platform" ]] && continue

        echo -e "\n${YELLOW}=== $platform ===${NC}"
        if list_remote_repos "$platform"; then
            ((platform_count++))
        else
            echo -e "${RED}Failed to list repositories for $platform.${NC}"
        fi
    done <<< "$platforms"

    if [[ $platform_count -gt 0 ]]; then
        echo -e "\n${GREEN}✅ Listed repositories from $platform_count platform(s).${NC}"
    else
        echo -e "\n${RED}❌ No repositories could be listed.${NC}"
    fi

    read -rp $'\n'"Press Enter to continue..." -n 1
}


manage_project_workflow() {
  echo -e "\n${RED}=== DELETE PROJECT (SAFE) ===${NC}"

  echo "Delete what?"
  echo "  1) Delete local copy (keeps remote repo)"
  echo "  2) Unbind from remote (keeps local, moves to Local_Projects/)"
  echo "  3) Delete BOTH (TYPE PROJECT NAME TO CONFIRM)"
  echo "  x) Cancel"
  read -rp "Choice (1-3 or x): " choice

  case "$choice" in
    1) _delete_local_copy ;;
    2) convert_remote_to_local_workflow ;;  # Reuse unbind logic!
    3) _delete_both ;;
    x) return ;;
    *) echo -e "${RED}Invalid.${NC}" ;;
  esac
}

# Delete local copy only
_delete_local_copy() {
  local source_dir project_name

  # Use helper for listing, bounds checking, and selection
  source_dir=$(_select_project_from_dir "$LOCAL_ROOT" "Select project to DELETE LOCALLY:") || return
  [[ -z "$source_dir" ]] && return

  project_name=$(basename "$source_dir")
  confirm_action "Are you sure you want to DELETE $project_name?" || return

  execute_dangerous "Delete local directory" rm -rf "$source_dir" && echo -e "${GREEN}✅ Deleted local copy${NC}" || echo -e "${RED}❌ Failed${NC}"
  sleep 5
  _pause_if_dry_run
}
# Helper: Delete both local and remote
_delete_both() {
  local source_dir project_name platform user_name

  # Use helper for listing, bounds checking, and selection
  source_dir=$(_select_project_from_dir "$REMOTE_ROOT" "Select project to DELETE EVERYTHING:") || return
  [[ -z "$source_dir" ]] && return

  project_name=$(basename "$source_dir")
  echo -e "${RED}WARNING: This deletes the remote repo AND local files!${NC}"
  read -rp "Type the project name '$project_name' to confirm: " confirm

  if [[ "$confirm" != "$project_name" ]]; then
    echo -e "${YELLOW}Names don't match. Aborting.${NC}"
    return
  fi

  cd "$source_dir"
  platform=$(git remote | head -1)
  user_name=$(git config --global user.name)

  # Delete remote via API
  echo -n "Deleting remote repo... "
  execute_dangerous "Delete remote repository" platform_api_call "$platform" "/repos/$user_name/$project_name" "DELETE" >/dev/null && \
    echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}"

  # Delete local
  cd "$HOME"
  execute_dangerous "Delete local directory" rm -rf "$source_dir" && echo -e "${GREEN}✅ Deleted everything${NC}" || echo -e "${RED}❌ Failed${NC}"
  sleep 5
  _pause_if_dry_run
}

# =================================  GITIGNORE WORKFLOW ====================================
# Standalone gitignore maker
gitignore_maker() {
  local project_dir="$1"
  local ignore_file="$project_dir/.gitignore"
  local mode="${2:-}"  # "first-push" or "standalone"

  echo ""
  echo "${YELLOW}=== Gitignore Setup ===${NC}"

  # === DRY-RUN HANDLING AT ENTRY ===
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}┌─────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│            DRY RUN MODE             │${NC}"
    echo -e "${YELLOW}│      (No changes will be made)      │${NC}"
    echo -e "${YELLOW}└─────────────────────────────────────┘${NC}"
    echo -e "${YELLOW}[DRY RUN] Gitignore workflow simulation${NC}"
    echo "Project directory: $project_dir"
    echo "Mode: ${mode:-standalone}"
      # Show mode selection menu
    {
      echo ""
      echo "${BLUE}Select mode:${NC}"
      echo "  1) Simple - add rules, commit immediately"
      echo "  2) Cautious - add rules with templates, review before commit"
      echo "  3) Local-only - don't commit .gitignore (warning: only for personal patterns)"
    } > /dev/tty

    read -rp "Choice (1-3): " mode_choice < /dev/tty

    # Simulate what would happen
    case $mode_choice in
      1)
        echo -e "${YELLOW}[DRY RUN] Would create .gitignore (simple mode)${NC}"
        echo "Would: Show rule input, create .gitignore, commit immediately"
        ;;
      2)
        echo -e "${YELLOW}[DRY RUN] Would create .gitignore (cautious mode)${NC}"
        echo "Would: Show rule input, create templates, open nano for review"
        ;;
      3)
        echo -e "${YELLOW}[DRY RUN] Would use .git/info/exclude (local-only)${NC}"
        echo "exclude"  # This tells caller about the strategy
        return 0
        ;;
      *)
        echo -e "${YELLOW}[DRY RUN] Gitignore setup cancelled${NC}"
        return 1
        ;;
    esac

    # For modes 1 & 2, simulate rule collection
    echo -e "${YELLOW}[DRY RUN] Would prompt for ignore patterns...${NC}"
    echo "normal"  # Return non-"exclude" string
    return 0
  fi

  # Check existence
  if [[ -f "$ignore_file" ]]; then
    if [[ "$mode" == "first-push" ]]; then
      echo -e "${YELLOW}⚠️  .gitignore exists. Overwriting will erase previous rules.${NC}"
      confirm_action ".gitignore exists. Overwrite will erase previous rules." || return 1
      echo
      [[ ! $REPLY =~ ^[Yy]$ ]] && return 1
    else
      # Standalone mode: offer sub-options
      echo -e "${YELLOW}⚠️  .gitignore already exists.${NC}"
      echo "  1) Review/edit existing"
      echo "  2) Overwrite (dangerous)"
      echo "  3) Delete (not recommended)"
      echo "  x) Cancel"
      read -rp "Choice: " subchoice
      case $subchoice in
        1) nano "$ignore_file"; return 0 ;;
        2) ;;
        3) rm "$ignore_file"; echo -e "${GREEN}Deleted.${NC}"; return 0 ;;
        *) return 1 ;;
      esac
    fi
  fi

  # Create base file
  echo "# Generated by repo-crafter" > "$ignore_file"
  echo ""
  echo "${BLUE}Add common patterns automatically?${NC}"
  echo "  1) Yes, add basic patterns (node_modules/, .env, etc.)"
  echo "  2) No, I'll add everything manually"
  read -rp "Choice (1-2): " auto_choice

  if [[ "$auto_choice" == "1" ]]; then
    {
      echo ""
      echo "# Common development patterns"
      echo "node_modules/"
      echo "__pycache__/"
      echo ".env"
      echo ".env.local"
      echo "*.log"
      echo ".DS_Store"
      echo "Thumbs.db"
      echo "dist/"
      echo "build/"
      echo "target/"  # Rust
      echo "*.o"      # C/C++
      echo "*.so"     # Shared objects
      echo "*.dll"    # Windows
    } >> "$ignore_file"
    echo -e "${GREEN}✓ Added common patterns${NC}"
  fi


  # Show mode selection
  {
   echo ""
   echo "${BLUE}Select mode:${NC}"
   echo "  1) Simple - add rules, commit immediately"
   echo "  2) Cautious - add rules with templates, review before commit"
   echo "  3) Local-only - don't commit .gitignore (warning: only for personal patterns)"
  } > /dev/tty
  read -rp "Choice (1-3): " mode_choice

  case $mode_choice in
    1)
      _select_and_template_files "$project_dir" "$ignore_file" "false"
      local commit_choice="1"
      ;;
    2)
      _select_and_template_files "$project_dir" "$ignore_file" "true"
      echo ""
      echo "${BLUE}Review final .gitignore in nano:${NC}"
      execute_dangerous "Edit .gitignore file (nano)" nano "$ignore_file"
      commit_choice="1"
      ;;
    3)
      _select_and_template_files "$project_dir" "$ignore_file" "false"
      echo -e "${RED}⚠️  WARNING: Moving to .git/info/exclude (never pushed)${NC}"
      mv "$ignore_file" "$project_dir/.git/info/exclude"
      echo "exclude"
      ;;
    *)
      return 1
      ;;
  esac

  # Create documented template for documentation
  cat > "$project_dir/.gitignore.template" << 'EOF'
# Optional patterns to copy to .gitignore:
# my-personal-ide-temp/
# experiment-notes.md
EOF

  return 0
}

# ======================= UTILITY HELPERS ==========================
# Pausing for viewer during dry-run

_pause_if_dry_run() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "\n${YELLOW}=== DRY-RUN COMPLETE ===${NC}"
        read -rp "Press Enter to continue..." -n 1
        echo
    fi
}

# Gitignore Helper wrapper
gitignore_maker_interactive() {
  echo -e "\n${BLUE}=== Gitignore Manager ===${NC}"
  local dir
  read -rp "Project directory: " dir
  dir="${dir/#\~/$HOME}"
  if [[ ! -d "$dir" ]]; then
    echo -e "${RED}Directory not found${NC}"
    return 1
  fi
  gitignore_maker "$dir" "standalone"
}

# Interactive file selection with optional templating
# Returns: 0=success, 1=cancelled
_select_and_template_files() {
  local project_dir="$1"
  local ignore_file="$2"
  local use_nano="$3"  # "true" or "false"

  echo ""
  echo "${BLUE}Enter files/directories to ignore (one per line):${NC}"
  echo "Examples: .env, node_modules/, *.log"
  echo "Press Enter on empty line to finish."

  while true; do
    read -rp "Ignore: " entry
    [[ -z "$entry" ]] && break

    echo "$entry" >> "$ignore_file"
    echo "  Added: $entry"

    # Template existing files if requested
    if [[ -f "$project_dir/$entry" && "$use_nano" == "true" ]]; then
      if confirm_action "Create .example template?" "n" "Create template"; then
        cp "$project_dir/$entry" "$project_dir/${entry}.example"
        sed -i 's/=.*/=YOUR_VALUE_HERE/' "$project_dir/${entry}.example" 2>/dev/null
        nano "$project_dir/${entry}.example"
      fi
    fi
  done

  return 0
}


# Prompt for project name with validation
_prompt_project_name() {
  local name
  while true; do
    read -rp "Project name: " name
    [[ -z "$name" ]] && continue
    [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] && { echo "$name"; return 0; }
    echo -e "${RED}Invalid name (use a-z, 0-9, -, _)${NC}"
  done
}

# Prompt for visibility (private/public)
_prompt_visibility() {
  echo -e "\n${YELLOW}Repository visibility?${NC}"
  echo "  1) Private  2) Public"
  read -rp "Choice (1-2): " choice
  [[ "$choice" == "1" ]] && echo "private" || echo "public"
}

# Select project from directory with bounds checking
_select_project_from_dir() {
  local dir="$1" prompt="$2"
  local projects=() i

  while IFS= read -r p; do
    projects+=("$p")
  done < <(find "$dir" -maxdepth 1 -type d ! -path "$dir" -print)

  [[ ${#projects[@]} -eq 0 ]] && { echo -e "${YELLOW}No projects in $dir${NC}"; return 1; }

  echo "$prompt"
  for i in "${!projects[@]}"; do
    local name=$(basename "${projects[i]}")
    local size=$(du -sh "${projects[i]}" 2>/dev/null | cut -f1 || echo "0B")
    local branch=$(git -C "${projects[i]}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "[no branch]")
    echo "  $((i+1))) $name [${size}] ($branch)"
  done
  echo ""

  read -rp "Select number: " idx
  [[ ! "$idx" =~ ^[0-9]+$ ]] && return 1
  idx=$((idx-1))
  [[ $idx -lt 0 || $idx -ge ${#projects[@]} ]] && return 1

  echo "${projects[$idx]}"
}

# Before destructive actions, show exactly what will happen
preview_action() {
    echo -e "${BLUE}📋 Action Preview:${NC}"
    echo "  Command: $*"
    echo "  Working dir: $(pwd)"
    echo "  Git status: $(git status --short 2>/dev/null | wc -l) changes"
}

# ======================= EXECUTION HELPERS ==========================

# For DANGEROUS operations (always preview + confirm)
execute_dangerous() {
    local description="$1"
    shift

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}┌─────────────────────────────────────┐${NC}"
        echo -e "${YELLOW}│             DRY RUN MODE            │${NC}"
        echo -e "${YELLOW}│      (No changes will be made)      │${NC}"
        echo -e "${YELLOW}└─────────────────────────────────────┘${NC}"
        echo -e "${YELLOW}[DRY RUN]${NC} $description"
        echo -e "  $(printf '%q ' "$@")"
        return 0
    fi

    # Normal mode: Show preview → Ask → Execute
    echo -e "${YELLOW}[PREVIEW]${NC} $description"
    echo -e "  $(printf '%q ' "$@")"
    confirm_action "Execute command?" && "$@" || return 1
}

# For SAFE operations (only preview with --dry-run)
execute_safe() {
    local description="$1"
    shift

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} $description"
        echo -e "  $(printf '%q ' "$@")"
        return 0
    fi

    # Normal mode: Execute silently
    "$@"
}

# ======================= UX and navigation FUNCTIONS ====================================


# Create a standard confirmation function
confirm_action() {
    local message="$1"
    local default="${2:-n}"  # Default to "no" for dangerous actions

    echo -e "${YELLOW}⚠️  $message${NC}"
    if [[ "$default" == "y" ]]; then
        read -rp "Proceed? (Y/n): " -n 1
        echo
        [[ ! $REPLY =~ ^[Nn]$ ]]
    else
        read -rp "Proceed? (y/N): " -n 1
        echo
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}


# ======================= MAIN MENU & ENTRY POINT =============================
main_menu() {
    while true; do
        clear
        echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║     /   REPO-CRAFTER v0.1.0    \     ║${NC}"
        echo -e "${BLUE}║     | Generic Platform Edition |     ║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
        echo -e "${RED}⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️⚡️${NC}"
        echo -e "${YELLOW}┌ Platforms: ${GREEN}${AVAILABLE_PLATFORMS[*]}${NC}"
        echo -e "${YELLOW}└ Root: ${GREEN}$HOME/Projects/${NC}"

        echo -e "\n${BLUE}🛠  CREATE NEW PROJECT${NC}"
        echo -e "\n${BLUE}📦 PROJECT MANAGEMENT${NC}"
        echo "  1) 🆕 Create New Project"
        echo "  2) 🔗 Convert Local → Remote"
        echo "  3) 🔓 Convert Remote → Local"
        echo "  4) 🗑️  Manage/Delete Project"

        echo -e "\n${BLUE}🌐 REMOTE OPERATIONS${NC}"
        echo "  5) 📋 List Remote Repositories"
        echo "  6) ⚙️  Configure .gitignore"

        echo -e "\n${BLUE}⚙️  SYSTEM${NC}"
        echo "  7) 🧪 Test Configuration"
        echo "  8) 🚪 Exit"
        echo ""
        read -rp "Select (1-8): " choice

        case $choice in
            1) create_new_project_workflow ;;
            2) convert_local_to_remote_workflow ;;
            3) convert_remote_to_local_workflow ;;
            4) manage_project_workflow ;;
            5) list_remote_repos_workflow ;;
            6) gitignore_maker_interactive ;;
            7) test_platform_config ;;
            8) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}


# ======================= DRY-RUN AND PLATFORM-TESTING CONFIGURATION ==============================
DRY_RUN=false  # Set to true via --dry-run flag

# Parse command line arguments (before any operations)
parse_args() {
    case "${1:-}" in
        --dry-run|-n)
            DRY_RUN=true
            echo -e "${YELLOW}=== DRY-RUN MODE (preview only) ===${NC}"
            ;;
        --test|-t)
            if ! load_platform_config; then exit 1; fi
            test_platform_config
            exit 0
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run|-n|--test|-t]"
            exit 0
            ;;
    esac
}
parse_args "$@"

# ======================= SCRIPT INITIALIZATION ===============================
main() {
    # 1. Check for essential tools
    for cmd in git curl jq ssh; do
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "${RED}Error: '$cmd' is not installed.${NC}"
            exit 1
        fi
    done

    # 2. Load platform configuration (REPLACES old token checks)
    if ! load_platform_config; then
        echo -e "${RED}Failed to load platform configuration. Exiting.${NC}"
        exit 1
    fi

    # 3. Optional: Test configuration (skip if .no-auto-test exists)
    echo -e "${YELLOW}Run configuration test? (Recommended)${NC}"
    if confirm_action "Test platform configuration now?" "y" "Run test"; then
        test_platform_config
    fi

    # 4. Safety check for current directory
    if ! is_safe_directory "$(pwd)"; then
        echo -e "${RED}Please run from a safe directory (e.g., ~/Projects).${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Status:${NC}"   # lastly done, needed to be reviewed.
    for platform in "${AVAILABLE_PLATFORMS[@]}"; do
        token_var="${PLATFORM_TOKEN_VAR[$platform]}"
        if [[ -n "${!token_var}" ]]; then
            echo -e "  ${GREEN}●${NC} $platform (API: ✓)"
        else
            echo -e "  ${RED}○${NC} $platform (API: ✗)"
        fi
    done
    # 5. Start the interactive menu
    main_menu
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
