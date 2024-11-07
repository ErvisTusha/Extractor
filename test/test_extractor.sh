#!/usr/bin/env bash

#set -euo pipefail
IFS=$'\n\t'
#set -x # Enable debugging
# Test constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR="${SCRIPT_DIR}/testdata"
readonly EXTRACT_DIR="${SCRIPT_DIR}/extracted"
readonly ARCHIVES_DIR="${SCRIPT_DIR}/archives"
readonly EXTRACTOR_SCRIPT="${SCRIPT_DIR}/../extractor.sh"
readonly TEST_PASSWORD="test123"  # Add this with other constants

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Update check_prerequisites function
check_prerequisites() {
    local required_tools=("zip" "tar" "gzip" "bzip2" "xz" "cmp" "grep")
    local optional_tools=("rar" "unrar")
    local missing_tools=()
    local missing_optional=()

    # Check required tools
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    # Check optional tools
    for tool in "${optional_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_optional+=("$tool")
        fi
    done

    # Check RAR version if available
    if command -v unrar >/dev/null 2>&1; then
        if ! unrar --version | grep -q "RAR.*[3-9]"; then
            missing_optional+=("modern-unrar")
        fi
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo -e "${RED}Error: Missing required tools: ${missing_tools[*]}${NC}"
        echo -e "${YELLOW}Please install the missing tools and try again${NC}"
        exit 1
    fi

    if [ ${#missing_optional[@]} -ne 0 ]; then
        echo -e "${YELLOW}Warning: Missing optional tools: ${missing_optional[*]}${NC}"
        echo -e "${YELLOW}Some tests will be skipped${NC}"
    fi
}

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Summary tracking
declare -A TEST_RESULTS=()
declare -A COMPRESSION_TYPES=()

# Test result function
test_result() {
    local test_name="$1"
    local result="$2"
    local compression_type="${3:-UNKNOWN}"
    ((TESTS_RUN++))
    
    # Store test result
    TEST_RESULTS["$test_name"]=$result
    COMPRESSION_TYPES["$test_name"]=$compression_type
    
    if [ "$result" -eq 0 ]; then
        echo -e "${GREEN}✓ $test_name passed${NC}"
        ((TESTS_PASSED++))
        # Cleanup on success
        rm -rf "$EXTRACT_DIR"/* "$ARCHIVES_DIR/$test_name"* 2>/dev/null || true
    else
        echo -e "${RED}✗ $test_name failed${NC}"
    fi
}

# Enhanced verify_extraction function to match actual files
verify_extraction() {
    local test_dir="$1"
    local extract_dir="$2"
    local verified=0
    local expected_files=0
    
    # Check if both directories exist
    [[ -d "$test_dir" ]] || { echo "Test directory does not exist"; return 1; }
    [[ -d "$extract_dir" ]] || { echo "Extract directory does not exist"; return 1; }
    
    # Get absolute paths
    test_dir=$(cd "$test_dir" && pwd)
    extract_dir=$(cd "$extract_dir" && pwd)
    
    # Verify each test file
    for file in "${SAMPLE_FILES[@]}"; do
        ((expected_files++))
        
        # Check root directory files
        if [[ -f "$extract_dir/$file" ]]; then
            if [[ "$file" == *".jpg" ]]; then
                cmp -s "$test_dir/$file" "$extract_dir/$file" && ((verified++))
            else
                grep -q "$TEST_CONTENT" "$extract_dir/$file" 2>/dev/null && ((verified++))
            fi
        fi
        
        # Check subdirectory files
        for dir in "${SAMPLE_DIRS[@]}"; do
            ((expected_files++))
            if [[ -f "$extract_dir/$dir/$file" ]]; then
                if [[ "$file" == *".jpg" ]]; then
                    cmp -s "$test_dir/$dir/$file" "$extract_dir/$dir/$file" && ((verified++))
                else
                    grep -q "$TEST_CONTENT" "$extract_dir/$dir/$file" 2>/dev/null && ((verified++))
                fi
            fi
        done
    done
    
    # Verify directories exist (including hidden ones)
    for dir in "${SAMPLE_DIRS[@]}"; do
        [[ -d "$extract_dir/$dir" ]] || return 1
    done
    
    # Return success only if all files verified
    [[ $verified -eq $expected_files ]]
}

# Enhanced test_single_extraction function with error output
test_single_extraction() {
    local archive="$1"
    local test_name="$(basename "$archive")"
    local compression_type="$2"
    local exp_fail="${3:-false}"
    
    echo -e "\n${BLUE}Testing:${NC} ${YELLOW}$test_name${NC}"
    
    # Prepare command based on archive type
    local cmd_str="$EXTRACTOR_SCRIPT"
    cmd_str+=" -o $EXTRACT_DIR"
    if [[ "$test_name" == *"password"* ]]; then
        cmd_str+=" -P $TEST_PASSWORD"
    fi
    cmd_str+=" $ARCHIVES_DIR/$archive"
    
    # Show command in a single line
    echo -e "${CYAN}Command:${NC} $cmd_str"
    rm -rf "$EXTRACT_DIR"/* 2>/dev/null || true
    
    # Run extraction command using array
    local cmd=("$EXTRACTOR_SCRIPT" "-o" "$EXTRACT_DIR")
    if [[ "$test_name" == *"password"* ]]; then
        cmd+=("-P" "$TEST_PASSWORD")
    fi
    cmd+=("$ARCHIVES_DIR/$archive")
    
    # Execute command
    local output
    output=$("${cmd[@]}" 2>&1)
    local status=$?
    
    # Handle results
    if [[ $status -ne 0 ]]; then
        if [[ "$exp_fail" == "true" ]]; then
            test_result "$test_name" 0 "$compression_type"
            return 0
        else
            echo -e "${RED}Extraction failed${NC}"
            echo -e "${YELLOW}Error output:${NC}\n$output"
            test_result "$test_name" 1 "$compression_type"
            return 1
        fi
    fi
    
    if [[ "$exp_fail" == "true" ]]; then
        echo -e "${YELLOW}Expected failure but extraction succeeded${NC}"
        test_result "$test_name" 1 "$compression_type"
        return 1
    fi
    
    # Compare directories instead of listing contents
    echo -e "${CYAN}Comparing extracted files with test data...${NC}"
    if verify_extraction "$TEST_DIR" "$EXTRACT_DIR"; then
        echo -e "${GREEN}File comparison successful${NC}"
        test_result "$test_name" 0 "$compression_type"
        return 0
    else
        echo -e "${RED}File comparison failed${NC}"
        test_result "$test_name" 1 "$compression_type"
        return 1
    fi
}

# Function to test parallel extraction
test_parallel_extraction() {
    echo -e "\n${BLUE}Testing:${NC} ${YELLOW}parallel extraction${NC}"
    
    # Find available non-password-protected archives
    shopt -s nullglob
    local archives=()
    for ext in zip tar.gz tar.bz2 7z; do
        # Exclude password-protected archives from parallel testing
        for archive in "$ARCHIVES_DIR"/*."$ext"; do
            [[ "$(basename "$archive")" != *"password"* ]] && archives+=("$archive")
        done
    done
    shopt -u nullglob

    if [ ${#archives[@]} -eq 0 ]; then
        echo -e "${YELLOW}No suitable archives found for parallel testing${NC}"
        test_result "parallel_extraction" 1 "PARALLEL"
        return 1
    fi

    echo -e "${CYAN}Command:${NC} $EXTRACTOR_SCRIPT -p -o $EXTRACT_DIR ${archives[*]}"
    rm -rf "$EXTRACT_DIR"/* 2>/dev/null || true
    
    # Extract multiple archives in parallel
    "$EXTRACTOR_SCRIPT" -p -o "$EXTRACT_DIR" "${archives[@]}" > /dev/null 2>&1
    local status=$?
    
    verify_extraction "$TEST_DIR" "$EXTRACT_DIR"
    status=$?
    
    test_result "parallel_extraction" "$status" "PARALLEL"
}

# Function to print test summary
print_summary() {
    echo
    echo -e "${BLUE}=== Test Summary ===${NC}"
    echo "Total tests: $TESTS_RUN"
    echo "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo "Failed: ${RED}$((TESTS_RUN - TESTS_PASSED))${NC}"
    echo
    
    echo -e "${YELLOW}Results by compression type:${NC}"
    declare -A type_stats=()
    
    # Collect statistics by compression type
    for test_name in "${!TEST_RESULTS[@]}"; do
        local comp_type="${COMPRESSION_TYPES[$test_name]}"
        local result="${TEST_RESULTS[$test_name]}"
        
        if [[ ! ${type_stats[$comp_type]+_} ]]; then
            type_stats[$comp_type]="0:0" # passed:total
        fi
        
        local curr_stats=(${type_stats[$comp_type]//:/ })
        local passed=${curr_stats[0]}
        local total=${curr_stats[1]}
        
        ((total++))
        [[ $result -eq 0 ]] && ((passed++))
        
        type_stats[$comp_type]="$passed:$total"
    done
    
    # Print statistics
    for type in "${!type_stats[@]}"; do
        local stats=(${type_stats[$type]//:/ })
        echo -e "$type: ${GREEN}${stats[0]}${NC}/${stats[1]} passed"
    done
}

# Add test case definitions
declare -A TEST_CASES=(
    ["Basic Archives"]="test.tar:TAR test.zip:ZIP test.7z:7Z"
    ["Compressed Archives"]="test.tar.gz:GZIP test.tar.bz2:BZIP2 test.tar.xz:XZ"
    ["Single File Compression"]="test.txt.gz:GZIP test.txt.bz2:BZIP2 test.txt.xz:XZ test.txt.Z:COMPRESS"
    ["Compression Levels"]="test-store.zip:ZIP test-max.zip:ZIP test-store.7z:7Z test-max.7z:7Z"
    ["Special Formats"]="test.jar:JAR test.war:WAR test.a:AR test.cpio:CPIO"
    ["Password Protected"]="test-password.zip:ZIP:true test-password.7z:7Z:true"
    ["RAR Archives"]="test.rar:RAR test-store.rar:RAR test-max.rar:RAR test-password.rar:RAR:true"
)

# Main test function
run_tests() {
    local total_tests=0
    local current_test=0

    # Count total tests
    for category in "${!TEST_CASES[@]}"; do
        for test in ${TEST_CASES[$category]}; do
            ((total_tests++))
        done
    done

    # Run tests by category
    for category in "${!TEST_CASES[@]}"; do
        echo -e "\n${BLUE}=== Testing ${category} ===${NC}"
        
        # Process each test in the category
        IFS=' ' read -ra tests <<< "${TEST_CASES[$category]}"
        for test in "${tests[@]}"; do
            # Parse test definition (format: filename:type[:expected_fail])
            IFS=':' read -r file type exp_fail <<< "$test"
            exp_fail=${exp_fail:-false}
            
            # Skip RAR tests if RAR is not available
            if [[ "$type" == "RAR" ]] && ! command -v rar >/dev/null; then
                echo -e "${YELLOW}Skipping RAR test ($file) - RAR support not available${NC}"
                continue
            fi
            
            # Run the test
            ((current_test++))
            echo -e "\n${CYAN}[$current_test/$total_tests]${NC} Testing $file..."
            test_single_extraction "$file" "$type" "$exp_fail"
        done
    done

    # Run parallel extraction test
    echo -e "\n${BLUE}=== Testing Parallel Extraction ===${NC}"
    test_parallel_extraction

    # Print final summary
    echo -e "\n${BLUE}=== Final Test Results ===${NC}"
    print_summary
}

# Cleanup function
cleanup() {
    echo "Cleaning up test environment..."
    rm -rf "$EXTRACT_DIR"/* 2>/dev/null || true
}

# Main function
main() {
    # Check prerequisites first
    check_prerequisites

    # Verify directories exist and are accessible
    local required_dirs=("$TEST_DIR" "$ARCHIVES_DIR" "$SCRIPT_DIR")
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            echo -e "${RED}Error: Required directory not found: $dir${NC}"
            echo -e "${YELLOW}Please run setup_test_environment.sh first${NC}"
            exit 1
        fi
        if [ ! -r "$dir" ] || [ ! -x "$dir" ]; then
            echo -e "${RED}Error: Insufficient permissions for directory: $dir${NC}"
            exit 1
        fi
    done

    # Check if test environment is set up
    if [[ ! -d "$TEST_DIR" ]] || [[ ! -d "$ARCHIVES_DIR" ]]; then
        echo -e "${RED}Error: Test environment not set up${NC}"
        echo -e "${YELLOW}Please run setup_test_environment.sh first${NC}"
        exit 1
    fi

    # Check if we have any archives to test
    if [[ -z "$(ls -A "$ARCHIVES_DIR" 2>/dev/null)" ]]; then
        echo -e "${RED}Error: No archives found in $ARCHIVES_DIR${NC}"
        echo -e "${YELLOW}Please run setup_test_environment.sh first${NC}"
        exit 1
    fi

    # Create necessary directories
    mkdir -p "$EXTRACT_DIR"
    
    # Clear screen
    clear
    
    echo -e "${BLUE}=== Running Extractor Tests ===${NC}\n"
    
    # Run tests
    run_tests
    
    # Cleanup
    cleanup
    
    # Exit with success if all tests passed
    exit $(( TESTS_RUN - TESTS_PASSED ))
}

# Run main if script is executed directly
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"