#!/usr/bin/env bash

# Enable strict mode
#set -euo pipefail
IFS=$'\n\t'

# Script constants
readonly AUTHOR="Ervis Tusha"
readonly VERSION="1.0.3"
readonly SCRIPT="extractor"
readonly SCRIPT_NAME="Extractor"
readonly SCRIPT_URL="https://raw.githubusercontent.com/ErvisTusha/extractor/main/extractor.sh"
readonly DEFAULT_OUTPUT_DIR="./"
readonly INSTALL_DIR="/usr/local/bin"
readonly SYSTEM_LOG_DIR="/var/log"
readonly USER_LOG_DIR="${HOME}/.local/log"
readonly MAX_PARALLEL_JOBS=4


# Add LOG_FILE as a variable instead
declare LOG_FILE="${USER_LOG_DIR}/${SCRIPT}.log"

# Add log levels
declare -rA LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 [FATAL]=4)
LOG_LEVEL=${LOG_LEVEL:-INFO}

# Temporary files array for cleanup
declare -a TEMP_FILES=()

# Add password option to command-line arguments
declare PASSWORD=""

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'
readonly GRAY='\033[0;90m'
readonly WHITE='\033[1;37m'

# Enhanced logging function with colors
log() {
    local level=$1
    shift
    local message="$*"
    local color=""
    
    # Assign colors based on log level
    case "$level" in
        DEBUG)   color="$GRAY" ;;
        INFO)    color="$CYAN" ;;
        WARN)    color="$YELLOW" ;;
        ERROR)   color="$RED" ;;
        FATAL)   color="$RED$BOLD" ;;
        *)       color="$NC" ;;
    esac
    
    # Check if we should log this level
    [[ ${LOG_LEVELS[$level]:-3} -ge ${LOG_LEVELS[$LOG_LEVEL]:-1} ]] || return 0
    
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="${WHITE}[${timestamp}]${NC} ${color}[${level}]${NC} ${message}"
    
    # Try to write to log file if it exists and is writable
    if [[ -w "$LOG_FILE" ]] || [[ -w "$(dirname "$LOG_FILE")" ]]; then
        # Write colored output to terminal, plain text to log file
        echo -e "$log_entry"
        echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
    else
        # Fallback to stdout only with colors
        echo -e "$log_entry"
    fi
}

# Cleanup function
cleanup() {
    local exit_code=$?
    for temp_file in "${TEMP_FILES[@]}"; do
        [[ -f "$temp_file" ]] && rm -f "$temp_file"
    done
    exit "$exit_code"
}

# Signal handling
handle_signal() {
    log "ERROR" "Received signal to terminate"
    cleanup
}

# Enhance USAGE with colors
USAGE() {
    echo -e "
${BOLD}${WHITE}Usage:${NC} ${CYAN}$SCRIPT${NC} [${GREEN}OPTIONS${NC}] ${YELLOW}FILE...${NC}

${BOLD}${WHITE}Options:${NC}
    ${GREEN}-h, --help          | ${NC}Show this help message
    ${GREEN}-v, --version       | ${NC}Show version information
    ${GREEN}-o, --output        | ${NC}Specify output directory (default: current directory)
    ${GREEN}-p, --parallel      | ${NC}Enable parallel extraction
    ${GREEN}-P, --password PWD  | ${NC}Specify password for encrypted archives
    ${GREEN}--dry-run           | ${NC}Perform a dry run without extracting files
    ${GREEN}--force             | ${NC}Force extraction even if collisions are detected
    ${GREEN}install             | ${NC}Install the script globally
    ${GREEN}uninstall           | ${NC}Remove the script
    ${GREEN}update              | ${NC}Update to the latest version

${BOLD}${WHITE}Examples:${NC}
    ${CYAN}$SCRIPT${NC} ${YELLOW}file.tar.gz${NC}
    ${CYAN}$SCRIPT${NC} ${GREEN}-o${NC} ${YELLOW}/path/to/output${NC} ${YELLOW}file.zip file.tar.gz${NC}
    ${CYAN}$SCRIPT${NC} ${GREEN}-P${NC} ${YELLOW}mypassword${NC} ${YELLOW}encrypted.zip${NC}
    ${CYAN}$SCRIPT${NC} ${GREEN}-p${NC} ${YELLOW}file1.zip file2.tar.gz file3.tar${NC}"
    exit 0
}

# Installation function
INSTALL() {
    IS_SUDO
    log "INFO" "Installing $SCRIPT_NAME to $INSTALL_DIR"
    cp "$0" "$INSTALL_DIR/$SCRIPT" || {
        log "ERROR" "Failed to install script"
        return 1
    }
    chmod 755 "$INSTALL_DIR/$SCRIPT"
    log "INFO" "Installation successful"
}

# Uninstallation function
UNINSTALL() {
    IS_SUDO
    log "INFO" "Uninstalling $SCRIPT_NAME from $INSTALL_DIR"
    rm -f "$INSTALL_DIR/$SCRIPT" || {
        log "ERROR" "Failed to uninstall script"
        return 1
    }
    log "INFO" "Uninstallation successful"
}

# Update function
UPDATE() {
    IS_SUDO
    log "INFO" "Updating $SCRIPT_NAME"
    local temp_file
    temp_file=$(mktemp)
    TEMP_FILES+=("$temp_file")
    
    if ! DOWNLOAD "$SCRIPT_URL" "$temp_file" false; then
        log "ERROR" "Failed to download update"
        return 1
    fi
    
    # Basic validation of downloaded file
    if [[ ! -s "$temp_file" ]]; then
        log "ERROR" "Downloaded file is empty"
        return 1
    fi
    
    if ! grep -q "SCRIPT=\"$SCRIPT\"" "$temp_file"; then
        log "ERROR" "Downloaded file appears invalid"
        return 1
    fi
    
    chmod 755 "$temp_file"
    mv "$temp_file" "$INSTALL_DIR/$SCRIPT"
    log "INFO" "Update successful"
}

# Check bash version
check_bash_version() {
    if ((BASH_VERSINFO[0] < 4)); then
        log "ERROR" "Bash version ${BASH_MIN_VERSION} or higher is required"
        exit 1
    fi
}

# Improved IS_SUDO with better error message
IS_SUDO() {
    if ! ((EUID == 0)); then
        log "ERROR" "This operation requires root privileges"
        log "ERROR" "Please run with sudo or as root"
        exit 1
    fi
}

# Improved IS_INSTALLED with tool name parameter validation
IS_INSTALLED() {
    local tool_name="$1"
    
    if [[ -z "$tool_name" ]]; then
        log "ERROR" "Tool name parameter is required"
        return 1
    fi
    
    if command -v "$tool_name" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Add checksum verification
verify_checksum() {
    local file=$1
    local expected_checksum=$2
    
    local actual_checksum
    if IS_INSTALLED "sha256sum"; then
        actual_checksum=$(sha256sum "$file" | cut -d' ' -f1)
    elif IS_INSTALLED "shasum"; then
        actual_checksum=$(shasum -a 256 "$file" | cut -d' ' -f1)
    else
        log "WARN" "No checksum tool available, skipping verification"
        return 0
    fi
    
    [[ "$actual_checksum" == "$expected_checksum" ]]
}

# Enhanced download function
DOWNLOAD() {
    local url="$1"
    local output="$2"
    local verify=${3:-false}  # Changed default to false
    
    [[ -z "$url" || -z "$output" ]] && {
        log "ERROR" "URL and output path are required"
        return 1
    }
    
    # Perform download with progress
    local temp_output
    temp_output=$(mktemp)
    TEMP_FILES+=("$temp_output")
    
    if IS_INSTALLED "wget"; then
        wget -q --show-progress "$url" -O "$temp_output" || {
            log "ERROR" "Failed to download $url"
            return 1
        }
    elif IS_INSTALLED "curl"; then
        curl -#L "$url" -o "$temp_output" || {
            log "ERROR" "Failed to download $url"
            return 1
        }
    elif IS_INSTALLED "python"; then
        python -c "
import sys, urllib.request
def progress(count, block_size, total_size):
    percent = int(count * block_size * 100 / total_size)
    sys.stderr.write('\r%d%%' % percent)
urllib.request.urlretrieve('$url', '$temp_output', reporthook=progress)
print('')" || {
            log "ERROR" "Failed to download $url"
            return 1
        }
    else
        log "ERROR" "wget, curl, or python is required for downloads"
        return 1
    fi
    
    # Verify checksum if enabled
    if [[ "$verify" == true ]]; then
        log "DEBUG" "Downloading checksum file"
        local checksum_file
        checksum_file=$(mktemp)
        TEMP_FILES+=("$checksum_file")
        
        # Attempt to download checksum file
        if ! curl -sL "${url}.sha256" -o "$checksum_file" 2>/dev/null; then
            log "WARN" "Could not download checksum file, skipping verification"
        else
            local expected_checksum
            expected_checksum=$(cat "$checksum_file")
            if ! verify_checksum "$temp_output" "$expected_checksum"; then
                log "ERROR" "Checksum verification failed"
                return 1
            fi
            log "DEBUG" "Checksum verification passed"
        fi
    fi
    
    mv "$temp_output" "$output"
    return 0
}

# Add functions for compression detection and handling
detect_compression() {
    local file="$1"
    local mime
    
    if IS_INSTALLED "file"; then
        mime=$(file --mime-type -b "$file")
        case "$mime" in
            application/x-gzip|application/gzip) echo "gzip" ;;
            application/x-bzip2) echo "bzip2" ;;
            application/x-xz) echo "xz" ;;
            application/zip|application/java-archive) echo "zip" ;;
            application/x-7z-compressed) echo "7z" ;;
            application/x-rar) echo "rar" ;;
            application/x-tar) echo "tar" ;;
            application/x-cpio) echo "cpio" ;;
            application/x-archive) echo "ar" ;;
            application/x-compress) echo "compress" ;;
            *) case "${file,,}" in
                *.Z|*.tar.Z) echo "compress" ;;
                *) echo "unknown" ;;
               esac
            ;;
        esac
    else
        case "${file,,}" in
            *.tar.gz|*.tgz) echo "gzip" ;;
            *.tar.bz2|*.tbz2) echo "bzip2" ;;
            *.tar.xz|*.txz) echo "xz" ;;
            *.zip|*.zipx|*.jar|*.war) echo "zip" ;;
            *.7z) echo "7z" ;;
            *.rar) echo "rar" ;;
            *.tar) echo "tar" ;;
            *.gz) echo "gzip" ;;
            *.bz2) echo "bzip2" ;;
            *.xz) echo "xz" ;;
            *.Z|*.tar.Z) echo "compress" ;;
            *.a) echo "ar" ;;
            *.cpio) echo "cpio" ;;
            *) echo "unknown" ;;
        esac
    fi
}

# Modify is_password_protected function
is_password_protected() {
    local archive="$1"
    local type="$2"
    
    case "$type" in
        zip)
            # Check if zip file is encrypted using unzip -l
            unzip -l "$archive" >/dev/null 2>&1
            local status=$?
            # Status 82 specifically indicates encryption
            [[ $status -eq 82 ]] && return 0
            ;;
        7z)
            7z l "$archive" 2>&1 | grep -q "Encrypted = +" && return 0
            ;;
        rar)
            unrar l "$archive" 2>&1 | grep -q "^\* $" && return 0
            ;;
    esac
    return 1
}

# Add password detection function
is_password_protected() {
    local archive="$1"
    local type="$2"
    
    case "$type" in
        zip)
            unzip -l "$archive" >/dev/null 2>&1 || return 0
            ;;
        7z)
            7z l "$archive" >/dev/null 2>&1 || return 0
            ;;
        rar)
            unrar l "$archive" >/dev/null 2>&1 || return 0
            ;;
    esac
    return 1
}

# Add progress tracking
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r${BOLD}Progress:${NC} [${GREEN}%s${GRAY}%s${NC}] ${CYAN}%d%%${NC}" \
        "$(printf '#%.0s' $(seq 1 "$filled"))" \
        "$(printf ' %.0s' $(seq 1 "$empty"))" \
        "$percent"
}

# Enhance prompt_password with colors
prompt_password() {
    local archive="$1"
    local attempts=0
    local max_attempts=3
    local password=""
    
    while ((attempts < max_attempts)); do
        if [[ -t 0 ]]; then  # Check if running in interactive terminal
            echo -en "${CYAN}Enter password for${NC} ${YELLOW}$archive${NC}: "
            read -s password
            echo  # Add newline after password input
            if [[ -n "$password" ]]; then
                PASSWORD="$password"
                return 0
            fi
        else
            log "ERROR" "Cannot prompt for password: not running in interactive terminal"
            return 1
        fi
        ((attempts++))
        [[ $attempts -lt $max_attempts ]] && echo -e "${RED}Invalid password, please try again${NC}"
    done
    
    log "ERROR" "Maximum password attempts reached"
    return 1
}

# Enhanced extract function
EXTRACT() {
    local archive="$1"
    local output_dir="${2:-$DEFAULT_OUTPUT_DIR}"
    local dry_run="${3:-false}"
    
    # Verify file exists and is readable
    [[ -f "$archive" && -r "$archive" ]] || {
        log "ERROR" "File '$archive' not found or not readable"
        return 1
    }
    
    # Create and verify output directory
    mkdir -p "$output_dir" || {
        log "ERROR" "Failed to create output directory '$output_dir'"
        return 1
    }
    
    [[ -w "$output_dir" ]] || {
        log "ERROR" "Output directory '$output_dir' is not writable"
        return 1
    }
    
    local type=$(detect_compression "$archive")
    
    # Check if archive is password protected and no password was provided via command line
    if [[ -z "$PASSWORD" ]] && is_password_protected "$archive" "$type"; then
        log "INFO" "Archive appears to be password protected"
        if ! prompt_password "$archive"; then
            log "ERROR" "Password required but could not prompt for input"
            return 1
        fi
    fi
    
    # Extract based on file type with password support
    case "$type" in
        zip|jar|war)
            if [[ -n "$PASSWORD" ]]; then
                # Use provided password
                unzip -P "$PASSWORD" -o "$archive" -d "$output_dir" || {
                    log "ERROR" "Failed to extract with provided password"
                    return 1
                }
            elif is_password_protected "$archive" "zip"; then
                if ! prompt_password "$archive"; then
                    return 1
                fi
                unzip -P "$PASSWORD" -o "$archive" -d "$output_dir" || {
                    log "ERROR" "Failed to extract with entered password"
                    return 1
                }
            else
                unzip -o "$archive" -d "$output_dir"
            fi
            ;;
        tar)
            tar xf "$archive" -C "$output_dir" --no-same-owner ;;
        gzip)
            if [[ "$archive" == *.tar.gz || "$archive" == *.tgz ]]; then
                tar xzf "$archive" -C "$output_dir" --no-same-owner
            else
                gzip -dc "$archive" > "$output_dir/$(basename "${archive%.*}")"
            fi ;;
        bzip2)
            if [[ "$archive" == *.tar.bz2 || "$archive" == *.tbz2 ]]; then
                tar xjf "$archive" -C "$output_dir"
            else
                bzip2 -dc "$archive" > "$output_dir/$(basename "${archive%.*}")"
            fi ;;
        xz)
            if [[ "$archive" == *.tar.xz || "$archive" == *.txz ]]; then
                tar xJf "$archive" -C "$output_dir"
            else
                xz -dc "$archive" > "$output_dir/$(basename "${archive%.*}")"
            fi ;;
        compress)
            if [[ "$archive" == *.tar.Z ]]; then
                zcat "$archive" | tar xf - -C "$output_dir" --no-same-owner
            else
                zcat "$archive" > "$output_dir/$(basename "${archive%.*}")"
            fi ;;
        7z)
            if is_password_protected "$archive" "7z"; then
                if [[ -z "$PASSWORD" ]]; then
                    7z x "$archive" -o"$output_dir"
                else
                    7z x -p"$PASSWORD" "$archive" -o"$output_dir" || {
                        log "ERROR" "Failed to extract password-protected 7Z archive (wrong password?)"
                        return 1
                    }
                fi
            else
                7z x "$archive" -o"$output_dir"
            fi ;;
        rar)
            # Check for proper RAR support
            if ! command -v unrar >/dev/null 2>&1; then
                log "ERROR" "unrar is not installed"
                return 1
            fi
            
            # Check for modern unrar version
            if ! unrar --version | grep -q "RAR.*[3-9]"; then
                log "ERROR" "Installed unrar version is too old. Please install a newer version."
                return 1
            fi
            
            if [[ -n "$PASSWORD" ]]; then
                unrar x -p"$PASSWORD" "$archive" "$output_dir" || {
                    log "ERROR" "Failed to extract RAR archive (wrong password?)"
                    return 1
                }
            else
                unrar x "$archive" "$output_dir" || {
                    log "ERROR" "Failed to extract RAR archive"
                    return 1
                }
            fi ;;
        *)
            log "ERROR" "Unsupported archive format: $archive"
            return 1 ;;
    esac
    
    local status=$?
    if [[ $status -ne 0 ]]; then
        log "ERROR" "Failed to extract $archive"
        return 1
    fi
    
    # Clear password after extraction for security
    PASSWORD=""
    
    return 0
}

# Add parallel extraction support
parallel_extract() {
    local -a files=("$@")
    local -A running_jobs=()
    local max_load=$(($(nproc) * 2))
    
    for file in "${files[@]}"; do
        # Wait if system load is too high
        while [[ $(cat /proc/loadavg | cut -d' ' -f1) > "$max_load" ]]; do
            sleep 1
        done
        
        # Clean up finished jobs
        for pid in "${!running_jobs[@]}"; do
            if ! kill -0 "$pid" 2>/dev/null; then
                wait "$pid"
                unset "running_jobs[$pid]"
            fi
        done
        
        # Start new extraction if below MAX_PARALLEL_JOBS
        if ((${#running_jobs[@]} < MAX_PARALLEL_JOBS)); then
            EXTRACT "$file" "$output_dir" &
            running_jobs[$!]="$file"
        else
            # Wait for any job to finish
            wait -n
        fi
    done
    
    # Wait for remaining jobs
    wait
}

# Add function to setup logging
setup_logging() {
    # Try system log directory first if we have sudo
    if [[ $EUID -eq 0 ]]; then
        LOG_FILE="${SYSTEM_LOG_DIR}/${SCRIPT}.log"
        if ! [[ -d "$SYSTEM_LOG_DIR" ]]; then
            mkdir -p "$SYSTEM_LOG_DIR"
        fi
    else
        # Fallback to user's home directory
        LOG_FILE="${USER_LOG_DIR}/${SCRIPT}.log"
        if ! [[ -d "$USER_LOG_DIR" ]]; then
            mkdir -p "$USER_LOG_DIR"
        fi
    fi
    
    # Test if we can write to the log file
    if ! touch "$LOG_FILE" 2>/dev/null; then
        echo "Warning: Cannot write to log file $LOG_FILE, logging to stdout only"
    fi
}

show_version() {
    echo -e "${BLUE}
    
    ███████╗██╗  ██╗████████╗██████╗  █████╗  ██████╗████████╗ ██████╗ ██████╗ 
    ██╔════╝╚██╗██╔╝╚══██╔══╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗
    █████╗   ╚███╔╝    ██║   ██████╔╝███████║██║        ██║   ██║   ██║██████╔╝
    ██╔══╝   ██╔██╗    ██║   ██╔══██╗██╔══██║██║        ██║   ██║   ██║██╔══██╗
    ███████╗██╔╝ ██╗   ██║   ██║  ██║██║  ██║╚██████╗   ██║   ╚██████╔╝██║  ██║
    ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝${NC}
    
    ${GREEN}${BOLD}EXTRACTOR${NC} v${YELLOW}${VERSION}${NC} - ${CYAN}${BOLD}Advanced Archive Extraction Tool${NC}    ${GREEN}${BOLD}From:${NC} ${RED}${BOLD}${AUTHOR}${NC}
    ${GREEN}${BOLD}GITHUB${NC}:${YELLOW}${BOLD}https://github.com/ErvisTusha/extractor${NC}   ${GREEN}${BOLD}X:${NC} ${YELLOW}${BOLD}https://www.x.com/ET${NC}
                                ${GREEN}${BOLD}LICENSE:${NC} ${YELLOW}${BOLD}MIT${NC}\n\n"
    
}

# Main script execution
main() {
    # Set up signal handlers
    trap cleanup EXIT
    trap handle_signal INT TERM
    
    # Setup logging before anything else
    setup_logging
    
    show_version

    check_bash_version
    
    # Process arguments
    local output_dir="$DEFAULT_OUTPUT_DIR"
    local files=()
    local parallel=false
    local dry_run=false
    local force=false
    

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)     USAGE ;;
            -v|--version)  exit 0 ;;
            -o|--output)   
                shift
                [[ $# -eq 0 ]] && {
                    log "ERROR" "Output directory not specified"
                    exit 1
                }
                output_dir="$1"
                shift
                ;;
            -P|--password)
                shift
                [[ $# -eq 0 ]] && {
                    log "ERROR" "Password not specified"
                    exit 1
                }
                PASSWORD="$1"
                shift
                ;;
            -p|--parallel) parallel=true; shift ;;
            --dry-run)     dry_run=true; shift ;;
            --force)       force=true; shift ;;
            install)       INSTALL; exit $? ;;
            uninstall)     UNINSTALL; exit $? ;;
            update)        UPDATE; exit $? ;;
            *)            files+=("$1"); shift ;;
        esac
    done
    
    # Validate we have files to process
    if ((${#files[@]} == 0)); then
        #log "ERROR" "No input files specified"
        USAGE
    fi
    
    # Process each file
    local exit_status=0
    if [[ "$parallel" == true ]]; then
        parallel_extract "${files[@]}"
    else
        for file in "${files[@]}"; do
            if ! EXTRACT "$file" "$output_dir" "$dry_run"; then
                [[ "$force" != true ]] && exit_status=1
            fi
        done
    fi
    
    exit "$exit_status"
}

# Execute main function with all arguments
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
