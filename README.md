# Extractor

![Version](https://img.shields.io/badge/version-1.0.1-blue)

## Overview

Extractor is a Bash script utility designed to handle the extraction of various compressed file formats. It not only extracts but also has built-in functionalities to install, uninstall, and update itself. Ideal for both individuals and system administrators who frequently interact with compressed files.

## Features

- 🗂 Supports Multiple File Types: `.tar.gz`, `.tar`, `.zip`, and more.
- ⚙️ Install, Uninstall, Update: Easily manage the script version.
- 🔒 Root Privilege Check: Ensures that the script runs with appropriate permissions.
- 📂 Custom Output Directory: Extract files to a directory of your choice.

## Requirements

- Bash shell
- root or sudo privileges for installation/uninstallation
- wget or curl or python for updating
- Required utilities for each supported file format (e.g., tar, unzip, etc.)

## Installation

Run the following steps to install Extractor:

```bash
#Download
wget -q --show-progress https://raw.githubusercontent.com/ErvisTusha/Extractor/main/extractor.sh -O ./extractor.sh

#Change permission
chmod +x extractor.sh

#Install
sudo ./extractor.sh install
```

## Usage

```bash
# To extract a file
$ extractor your_file.tar.gz

# To extract multiple files
$ extractor your_file.tar your_file.zip your_file.tar.gz

# To specify an output directory
$ extractor -o output_directory your_file.tar.gz
$ extractor -o output_directory your_file.tar your_file.zip your_file.tar.gz
$ extractor --output output_directory your_file.tar.gz
$ extractor --output output_directory your_file.tar your_file.zip your_file.tar.gz
$ extractor your_file.tar.gz -o output_directory
$ extractor your_file.tar your_file.zip your_file.tar.gz -o output_directory


# To uninstall
$ extractor uninstall

# To update
$ extractor update
```

## Supported File Types

- `.tar.gz` / `.tgz`
- `.tar`
- `.zip`
- More coming soon!

## Contributing

Pull requests are welcome. Please make sure to update tests as appropriate.

## License

MIT License


## Author

- [Ervis Tusha](https://github.com/ErvisTusha)
- [Twitter](https://X.com/ET)
- 📧 ERVISTUSHA[at]GMAIL.COM
