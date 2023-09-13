#!/bin/bash

#Version
VERSION="1.0.0"

SCRIPT="extractor"
#SCRIPT NAME
SCRIPT_NAME="Extractor"
#SCRIPT URL
SCRIPT_URL="https://raw.githubusercontent.com/ErvisTusha/extractor/main/extractor.sh"
#OUTPUT DIRECTORY
OUTPUT_DIR="./"

#function check if the user has root or sudo privileges
CHECK_ROOT(){
    if ! (( EUID == 0 )); then
        echo "Please run as root or with sudo privileges"
        exit 1
    fi
}



#check if tool is installed
CHECK_TOOL(){
    if ! command -v $1 >/dev/null 2>&1; then
        echo "Error: $1 is not installed"
        exit 1
    fi
}

#function to download files
DOWNLOAD(){
    URL=$1
    OUTPUT=$2
    
    # if wget is installed then use wget else use check if curl is installed
    if ! command -v wget >/dev/null 2>&1; then
        wget -q "$URL" -O "$OUTPUT"
        elif ! command -v curl >/dev/null 2>&1; then
        curl -sL "$URL" -o "$OUTPUT"
        elif command -v python >/dev/null 2>&1; then
        python -c "import urllib; urllib.urlretrieve('$URL', '$OUTPUT')"
        echo "python -c \"import urllib; urllib.urlretrieve('$URL', '$OUTPUT')\""
    else
        echo "Error: wget or curl is not installed. Please install one of them and try again."
        exit 1
    fi
    
}

#function install the script
INSTALL(){
    #check if the user has root or sudo privileges
    CHECK_ROOT
    #check if /usr/local/bin/$SCRIPT exists
    if [ -f /usr/local/bin/$SCRIPT ]; then
        echo "$SCRIPT_NAME is already installed"
        #ask the user if they want to update the script else exit
        read -p "Do you want to update the script? [y/n]: " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            UPDATE
        else
            echo "Exiting..."
            exit 0
        fi
    fi
    #copy the script to /usr/local/bin
    cp "$0" /usr/local/bin/$SCRIPT
    #make the script executable
    chmod +x /usr/local/bin/$SCRIPT
    echo "$SCRIPT_NAME installed successfully"
    #print the version
    echo "$SCRIPT_NAME version $(grep "VERSION=" /usr/local/bin/$SCRIPT -m 1 | cut -d "=" -f 2 | tr -d '"')"
    exit 0
}

UNINSTALL(){
    #check if the user has root or sudo privileges
    CHECK_ROOT
    #check if /usr/local/bin/$SCRIPT exists
    if [ ! -f /usr/local/bin/$SCRIPT ]; then
        echo "$SCRIPT_NAME is not installed"
        exit 0
    fi
    #remove /usr/local/bin/$SCRIPT
    rm /usr/local/bin/$SCRIPT
    echo "$SCRIPT_NAME uninstalled successfully"
    exit 0
}

UPDATE(){
    #downdload VERSION from github
    #check if the user has root or sudo privileges
    CHECK_ROOT
    #if /usr/local/bin/$SCRIPT does not exist then run install
    if [ ! -f /usr/local/bin/$SCRIPT ]; then
        echo "$SCRIPT_NAME is not installed"
        INSTALL
    fi
    
    #Download the latest version from github to tmp
    echo "Downloading the latest version..."
    DOWNLOAD "$SCRIPT_URL"  /tmp/$SCRIPT
    #check if the download was successful
    if ! [ $? -eq 0 ]; then
        echo "Error: Failed to download the latest version"
        exit 1
    fi
    #check if the downloaded file is empty
    if [ ! -s /tmp/$SCRIPT ]; then
        echo "Error: Failed to download the latest version"
        exit 1
    fi
    #Grep the version from the downloaded file
    NEW_VERSION=$(grep "VERSION=" /tmp/$SCRIPT -m 1 | cut -d "=" -f 2 | tr -d '"')
    #Grep the version from the current file
    CURRENT_VERSION=$(grep "VERSION=" /usr/local/bin/$SCRIPT -m 1 | cut -d "=" -f 2 | tr -d '"')
    #compare the two versions
    if [[ "$NEW_VERSION" == "$CURRENT_VERSION" ]]; then
        echo "You already have the latest version"
        exit 0
    fi
    #copy the downloaded file to /usr/local/bin/$SCRIPT
    cp /tmp/$SCRIPT /usr/local/bin/$SCRIPT
    #make the script executable
    chmod +x /usr/local/bin/$SCRIPT
    echo "$SCRIPT_NAME updated successfully"
    #print the version
    echo "$SCRIPT_NAME new version is $NEW_VERSION"
    exit 0
}


USAGE() {
    echo "Usage: $SCRIPT_NAME [OPTION]... [FILE]..."
    echo "Extracts the given files"
    echo "Extractor version $VERSION"
    echo "Created by: Ervis Tusha"
    echo "Email: ERVISTUSHA[at]GMAIL.COM Github: https://github.com/ErvisTusha Twitter: https://X.com/ET"
    echo "Options:"
    echo "  -h, --help      display this help and exit"
    echo "  -v, --version   output version information and exit"
    echo "  -o, --output    specify output directory"
    echo "  install         install the script"
    echo "  uninstall       uninstall the script"
    echo "  update          update the script"
    echo "Supported file types: .tar.gz, .tar, .zip, .7z, .bz2, .gz, .rar, .xz, .Z, .a, .cpio, .deb, .rpm, .tar.xz, .tar.Z, .tgz, .zipx, .Z, .jar, .war"
    exit 0
}



#extract the file to the output directory
EXTRACT_FILE(){
    #check if tool is installed
    CHECK_TOOL "$1"
    #extract the file
    echo "$1 $2"
    $1 $2
}

EXTRACT() {
    #FIXME ASK THE USER IF THEY WANT TO REPLACE THE FILE
    case $1 in
        *.tar.gz|*.tgz) EXTRACT_FILE "tar" "-xzf $1 -C $2" ;;
        *.tar) EXTRACT_FILE "tar" "-xf $1 -C $2" ;;
        *.zip) EXTRACT_FILE "unzip" "-o -q $1 -d $2" ;;
        #TODO SUPPORT MORE FILE TYPES
    esac
}

#if no arguments are given, print usage
if [[ $# -eq 0 ]]; then
    USAGE
    exit 0
fi

ARG_LIST=$@


while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            USAGE
        ;;
        -v|--version)
            USAGE
        ;;
        -o|--output)
            OUTPUT_DIR=$2
            shift 2
        ;;
        install)
            INSTALL
        ;;
        uninstall)
            UNINSTALL
        ;;
        update)
            UPDATE
        ;;
        *)
            shift
        ;;
    esac
done


#for each file skip -o , --output  or arg is equal to OUTPUT_DIR
for file in $ARG_LIST; do
    if [[ $file == "-o" || $file == "--output" || $file == "$OUTPUT_DIR" ]]; then
        continue
    fi
    #check if the file exists
    if [ ! -f "$file" ]; then
        echo "Error: $file does not exist"
        exit 1
    fi
    #check if the file is empty
    if [ ! -s "$file" ]; then
        echo "Error: $file is empty"
        exit 1
    fi
    
    #create the output directory
    mkdir -p "$OUTPUT_DIR"
    
    EXTRACT "$file" "$OUTPUT_DIR"
done

if ! [ $? -eq 0 ]; then
    echo "Error: Failed to extract one or more files"
    exit 1
fi
