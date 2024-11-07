#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR="${SCRIPT_DIR}/testdata"
readonly EXTRACT_DIR="${SCRIPT_DIR}/extracted"
readonly ARCHIVES_DIR="${SCRIPT_DIR}/archives"
readonly SAMPLE_FILES=("test.txt" "image.jpg" "document.pdf" "script.sh" "test.json" ".hidden")
readonly SAMPLE_DIRS=("dir1" "dir2/subdir" "empty_dir" ".hidden_dir")
readonly TEST_CONTENT="This is test content"
# Replace the problematic line with this safer binary content generation
readonly TEST_BINARY_CONTENT="$(head -c 1024 /dev/urandom | base64)"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m' # No Color
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'

# Enhanced color and style definitions
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly UNDERLINE='\033[4m'

# Add counters for summary
declare -i TOTAL_FILES_CREATED=0
declare -i TOTAL_ARCHIVES_CREATED=0
declare -A ARCHIVE_TYPES=()

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local message=$3
    local width=40
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    # Calculate gradient colors
    local color
    if [ $percentage -lt 33 ]; then
        color='\033[38;5;39m'  # Light blue
    elif [ $percentage -lt 66 ]; then
        color='\033[38;5;44m'  # Cyan
    else
        color='\033[38;5;49m'  # Green
    fi
    
    printf "\r ${BOLD}⚡${NC} ${YELLOW}%-20s${NC} ${color}[" "$message"
    printf "▰%.0s" $(seq 1 $filled)
    printf "▱%.0s" $(seq 1 $empty)
    printf "]${NC} ${BOLD}%3d%%${NC}" "$percentage"
}

# Add banner function for section headers
print_banner() {
    local text="$1"
    local width=60
    local padding=$(( (width - ${#text}) / 2 ))
    echo
    echo -e "${BLUE}═══${CYAN}${BOLD}$(printf '═%.0s' $(seq 1 $width))${BLUE}═══${NC}"
    echo -e "${BLUE}═══${CYAN}${BOLD}$(printf ' %.0s' $(seq 1 $padding))${text}$(printf ' %.0s' $(seq 1 $((padding - 1))))${BLUE}═══${NC}"
    echo -e "${BLUE}═══${CYAN}${BOLD}$(printf '═%.0s' $(seq 1 $width))${BLUE}═══${NC}"
    echo
}

# Function to track archive creation
track_archive() {
    local archive="$1"
    local type="$2"
    if [[ -f "$archive" && -s "$archive" ]]; then
        ((TOTAL_ARCHIVES_CREATED++))
        ARCHIVE_TYPES["$type"]=$((ARCHIVE_TYPES["$type"] + 1))
        return 0
    fi
    return 1
}

# Function to install required packages
install_dependencies() {
    print_banner "Installing Dependencies 📥"
    echo "Installing compression tools..."
    if command -v apt-get >/dev/null; then
        echo ""
        sudo apt-get update
        sudo apt-get install -y \
            zip unzip \
            gzip \
            bzip2 \
            xz-utils \
            p7zip-full \
            tar \
            rar unrar-free \
            ncompress \
            binutils \
            cpio \
            rpm \
            dpkg \
            build-essential
    elif command -v yum >/dev/null; then
        sudo yum install -y \
            zip unzip \
            gzip \
            bzip2 \
            xz \
            p7zip p7zip-plugins \
            tar \
            rar unrar \
            ncompress \
            binutils \
            cpio \
            rpm-build \
            dpkg \
            gcc make
    elif command -v pacman >/dev/null; then
        sudo pacman -Sy --noconfirm \
            zip unzip \
            gzip \
            bzip2 \
            xz \
            p7zip \
            tar \
            rar unrar \
            compress \
            binutils \
            cpio \
            rpm-tools \
            dpkg \
            base-devel
    else
        echo "Could not detect package manager. Please install compression tools manually."
        exit 1
    fi
}

# Add cleanup function after the constants
cleanup_environment() {
    print_banner "Cleaning Up Environment 🧹"
    echo -e "\n${GREEN}Removing existing files and directories...${NC}"
    
    # Remove test directories and their contents
    rm -rf "$TEST_DIR" "$EXTRACT_DIR" "$ARCHIVES_DIR" || {
        echo "Warning: Could not remove some directories"
        return 1
    }
    
    # Create fresh directories
    mkdir -p "$TEST_DIR" "$EXTRACT_DIR" "$ARCHIVES_DIR" || {
        echo "Error: Could not create directories"
        return 1
    }
    
    echo "Cleanup completed"
    return 0
}

# Modify setup_test_environment to show progress
setup_test_environment() {
    print_banner "Setting Up Test Environment 🛠"
    echo -e "\n${GREEN}Setting up test environment...${NC}"
    
    # Remove debug output and cleanup code since it's now in cleanup_environment
    local total_operations=$((${#SAMPLE_DIRS[@]} + ${#SAMPLE_FILES[@]} * (${#SAMPLE_DIRS[@]} + 1)))
    local current=0

    # Create sample directories with error checking
    echo "Creating sample directories..."
    for dir in "${SAMPLE_DIRS[@]}"; do
        echo "Creating directory: $TEST_DIR/$dir"
        mkdir -p "$TEST_DIR/$dir" || { echo "Error: Could not create directory $dir"; exit 1; }
        ((current++))
        show_progress "$current" "$total_operations" "Creating directories"
    done
    echo

    # Create sample files with content and error checking
    echo "Creating sample files..."
    for file in "${SAMPLE_FILES[@]}"; do
        echo "Creating file: $TEST_DIR/$file"
        if [[ "$file" == *".jpg" ]]; then
            echo "$TEST_BINARY_CONTENT" > "$TEST_DIR/$file" || { echo "Error: Could not create file $file"; exit 1; }
        else
            echo "$TEST_CONTENT" > "$TEST_DIR/$file" || { echo "Error: Could not create file $file"; exit 1; }
        fi
        ((current++))
        ((TOTAL_FILES_CREATED++))
        show_progress "$current" "$total_operations" "Creating files"

        # Also create files in subdirectories
        for dir in "${SAMPLE_DIRS[@]}"; do
            echo "Creating file in subdirectory: $TEST_DIR/$dir/$file"
            if [[ "$file" == *".jpg" ]]; then
                echo "$TEST_BINARY_CONTENT" > "$TEST_DIR/$dir/$file" || { echo "Error: Could not create file $file in $dir"; exit 1; }
            else
                echo "$TEST_CONTENT" > "$TEST_DIR/$dir/$file" || { echo "Error: Could not create file $file in $dir"; exit 1; }
            fi
            ((current++))
            ((TOTAL_FILES_CREATED++))
            show_progress "$current" "$total_operations" "Creating files"
        done
    done
    echo

    # Create symbolic links with error checking
    echo "Creating symbolic links..."
    ln -s "$TEST_DIR/test.txt" "$TEST_DIR/link_to_text" || echo "Warning: Could not create text symlink"
    ln -s "$TEST_DIR/dir1" "$TEST_DIR/link_to_dir" || echo "Warning: Could not create directory symlink"
    
    echo "Test environment setup completed"
}

# Add this function before create_test_archives
verify_archive() {
    local archive="$1"
    local type="$2"
    if [[ ! -f "$archive" ]]; then
        echo -e "${RED}Failed to create $type archive: $archive${NC}"
        return 1
    elif [[ ! -s "$archive" ]]; then
        echo -e "${YELLOW}Warning: $type archive is empty: $archive${NC}"
        return 2
    fi
    return 0
}

# Add debug function
debug_info() {
    echo -e "${YELLOW}Debug Info:${NC}"
    echo "Current directory: $(pwd)"
    echo "TEST_DIR contents:"
    ls -la "$TEST_DIR"
    echo "Checking compression tools:"
    for tool in zip unzip tar gzip bzip2 xz 7z; do
        if command -v $tool >/dev/null 2>&1; then
            echo "✓ $tool installed"
        else
            echo "✗ $tool missing"
        fi
    done
}

create_test_archives() {
    print_banner "Creating Test Archives 📦"
    echo -e "\n${GREEN}Creating test archives...${NC}"
    
    # Check if we're in the right directory and have files
    cd "$TEST_DIR" || {
        echo -e "${RED}Error: Could not change to test directory${NC}"
        debug_info
        return 1
    }
    
    # Create archives directory
    mkdir -p "$ARCHIVES_DIR"
    
    # Reset counters
    TOTAL_ARCHIVES_CREATED=0
    ARCHIVE_TYPES=()
    
    # Store current directory for absolute paths
    local current_dir=$(pwd)
    
    echo "Creating ZIP archives..."
    # ZIP archives with better error handling
    zip -r "$ARCHIVES_DIR/test.zip" . || return 1
    track_archive "$ARCHIVES_DIR/test.zip" "ZIP"
    
    zip -0 -r "$ARCHIVES_DIR/test-store.zip" . || return 1
    track_archive "$ARCHIVES_DIR/test-store.zip" "ZIP"
    
    zip -9 -r "$ARCHIVES_DIR/test-max.zip" . || return 1
    track_archive "$ARCHIVES_DIR/test-max.zip" "ZIP"
    
    echo "Creating TAR archives..."
    # TAR archives
    tar -cf "$ARCHIVES_DIR/test.tar" . || return 1
    track_archive "$ARCHIVES_DIR/test.tar" "TAR"
    
    tar -czf "$ARCHIVES_DIR/test.tar.gz" . || return 1
    track_archive "$ARCHIVES_DIR/test.tar.gz" "TAR.GZ"
    
    tar -cjf "$ARCHIVES_DIR/test.tar.bz2" . || return 1
    track_archive "$ARCHIVES_DIR/test.tar.bz2" "TAR.BZ2"
    
    tar -cJf "$ARCHIVES_DIR/test.tar.xz" . || return 1
    track_archive "$ARCHIVES_DIR/test.tar.xz" "TAR.XZ"
    
    echo "Creating 7Z archives..."
    # 7Z archives
    7z a "$ARCHIVES_DIR/test.7z" . || return 1
    track_archive "$ARCHIVES_DIR/test.7z" "7Z"
    
    7z a -mx=0 "$ARCHIVES_DIR/test-store.7z" . || return 1
    track_archive "$ARCHIVES_DIR/test-store.7z" "7Z"
    
    7z a -mx=9 "$ARCHIVES_DIR/test-max.7z" . || return 1
    track_archive "$ARCHIVES_DIR/test-max.7z" "7Z"
    
    echo "Creating single-file archives..."
    # Single file compression
    gzip -c "test.txt" > "$ARCHIVES_DIR/test.txt.gz" || return 1
    track_archive "$ARCHIVES_DIR/test.txt.gz" "GZIP"
    
    bzip2 -c "test.txt" > "$ARCHIVES_DIR/test.txt.bz2" || return 1
    track_archive "$ARCHIVES_DIR/test.txt.bz2" "BZIP2"
    
    xz -c "test.txt" > "$ARCHIVES_DIR/test.txt.xz" || return 1
    track_archive "$ARCHIVES_DIR/test.txt.xz" "XZ"
    
    compress -c "test.txt" > "$ARCHIVES_DIR/test.txt.Z" || return 1
    track_archive "$ARCHIVES_DIR/test.txt.Z" "COMPRESS"
    
    echo "Creating special format archives..."
    # Special formats
    zip -r "$ARCHIVES_DIR/test.jar" ./*.txt || return 1
    track_archive "$ARCHIVES_DIR/test.jar" "JAR"
    
    zip -r "$ARCHIVES_DIR/test.war" ./*.txt || return 1
    track_archive "$ARCHIVES_DIR/test.war" "WAR"
    
    ar cr "$ARCHIVES_DIR/test.a" test.txt image.jpg || return 1
    track_archive "$ARCHIVES_DIR/test.a" "AR"
    
    find . -type f | cpio -o > "$ARCHIVES_DIR/test.cpio" || return 1
    track_archive "$ARCHIVES_DIR/test.cpio" "CPIO"
    
    echo "Creating password-protected archives..."
    # Password-protected archives
    zip -P test123 "$ARCHIVES_DIR/test-password.zip" ./* || return 1
    track_archive "$ARCHIVES_DIR/test-password.zip" "ZIP"
    
    7z a -ptest123 "$ARCHIVES_DIR/test-password.7z" ./* || return 1
    track_archive "$ARCHIVES_DIR/test-password.7z" "7Z"
    
    # RAR archives if available
    if command -v rar >/dev/null; then
        echo "Creating RAR archives..."
        # Use RAR 2.0 compatible format
        rar a -ma2 "$ARCHIVES_DIR/test.rar" ./* || return 1
        track_archive "$ARCHIVES_DIR/test.rar" "RAR"
        
        rar a -ma2 -m0 "$ARCHIVES_DIR/test-store.rar" ./* || return 1
        track_archive "$ARCHIVES_DIR/test-store.rar" "RAR"
        
        rar a -ma2 -m5 "$ARCHIVES_DIR/test-max.rar" ./* || return 1
        track_archive "$ARCHIVES_DIR/test-max.rar" "RAR"
        
        rar a -ma2 -ptest123 "$ARCHIVES_DIR/test-password.rar" ./* || return 1
        track_archive "$ARCHIVES_DIR/test-password.rar" "RAR"
    fi
    
    echo -e "${GREEN}Archive creation completed${NC}"
    return 0
}

# Add summary function
print_summary() {
    print_banner "Setup Complete! 🎉"
    
    echo -e " ${BOLD}${GREEN}✓${NC} Files Created:    ${BOLD}${TOTAL_FILES_CREATED}${NC}"
    echo -e " ${BOLD}${GREEN}✓${NC} Archives Created: ${BOLD}${TOTAL_ARCHIVES_CREATED}${NC}"
    
    echo -e "\n ${UNDERLINE}${YELLOW}Archives by type:${NC}"
    for type in "${!ARCHIVE_TYPES[@]}"; do
        printf " ${CYAN}%-10s${NC} │ ${BOLD}%3d${NC} files\n" "$type" "${ARCHIVE_TYPES[$type]}"
    done
    
    echo -e "\n ${BOLD}📁 Locations${NC}"
    echo -e " ${BLUE}├─${NC} Archives: ${UNDERLINE}${ARCHIVES_DIR}${NC}"
    echo -e " ${BLUE}└─${NC} Test files: ${UNDERLINE}${TEST_DIR}${NC}\n"
}

# Modify main function
main() {
    # Ensure required tools are installed
    local missing_tools=()
    for tool in zip unzip tar gzip bzip2 xz 7z; do
        if ! command -v $tool >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if ((${#missing_tools[@]} > 0)); then
        echo -e "${RED}Error: Missing required tools: ${missing_tools[*]}${NC}"
        echo -e "${YELLOW}Please run './setup_test_environment.sh install' first${NC}"
        exit 1
    fi
    
    cleanup_environment || { echo "Error: Failed to cleanup environment"; exit 1; }
    setup_test_environment || { echo "Error: Failed to setup test environment"; exit 1; }
    create_test_archives || { echo "Error: Failed to create archives"; exit 1; }
    rm -rf "$EXTRACT_DIR"/* 2>/dev/null || true
    print_summary
}

main "$@"
