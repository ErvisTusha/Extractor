# 📦 Extractor - Advanced Archive Extraction Tool

![Version](https://img.shields.io/badge/version-1.0.3-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Bash](https://img.shields.io/badge/bash-%3E%3D4.0-orange.svg)

A powerful, feature-rich bash script for extracting various archive formats with advanced capabilities.

<p align="center">
  <img src="https://raw.githubusercontent.com/ErvisTusha/extractor/main/assets/logo.png" alt="Extractor Logo" width="600"/>
</p>

## ✨ Features

- 📚 Supports multiple archive formats:
  - ZIP (including password-protected)
  - TAR (and variants: tar.gz, tar.bz2, tar.xz)
  - RAR (including password-protected)
  - 7Z (including password-protected)
  - GZIP, BZIP2, XZ
  - JAR, WAR
  - Compressed archives (.Z)
  - CPIO and AR archives

- 🛡️ Advanced Security Features:
  - Password protection detection
  - Secure password handling

  - Clean password memory after extraction

- 🚀 Performance Features:
  - Parallel extraction support
  - System load monitoring
  - Progress tracking
  - Efficient memory usage

- 📊 Robust Logging:
  - Colored output
  - Multiple log levels (DEBUG, INFO, WARN, ERROR, FATAL)
  - Configurable log locations
  - Detailed error reporting

## Installation

```bash
# Direct installation
curl -sSL https://raw.githubusercontent.com/ErvisTusha/extractor/main/extractor.sh | sudo bash -s install

# Or clone and install
git clone https://github.com/ErvisTusha/extractor.git
cd extractor
sudo ./extractor.sh install
```

### Basic Usage

```bash
# Extract a single file
extractor file.zip

# Extract to specific directory
extractor -o /path/to/output file.tar.gz

# Extract password-protected archive
extractor -P mypassword encrypted.zip

# Extract multiple files in parallel
extractor -p file1.zip file2.tar.gz file3.rar
```

## 🎯 Command Line Options

```
Options:
    -h, --help          | Show this help message
    -v, --version       | Show version information
    -o, --output        | Specify output directory (default: current directory)
    -p, --parallel      | Enable parallel extraction
    -P, --password PWD  | Specify password for encrypted archives
    --dry-run          | Perform a dry run without extracting files
    --force            | Force extraction even if collisions are detected
    install            | Install the script globally
    uninstall          | Remove the script
    update             | Update to the latest version
```

## 🔧 Requirements

- Bash 4.0 or higher
- Standard Unix tools (tar, gzip, etc.)
- Optional tools for specific formats:
  - `unzip` for ZIP files
  - `unrar` for RAR files
  - `7z` for 7Z files

## 🏗️ Development

This script was developed using:
- VSCode as the primary IDE
- Claude 3.5 Sonnet for AI assistance
- Modern bash scripting practices

### Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

Distributed under the MIT License. See `LICENSE` file for more information.

## 👤 Author

**Ervis Tusha**
- X: [@ET](https://twitter.com/ET)
- Github: [@ErvisTusha](https://github.com/ErvisTusha)

## 🙏 Acknowledgments

- VSCode team for the excellent IDE
- Claude AI for development assistance
- The open-source community for inspiration

---
<p align="center">
  Made with ❤️ by Ervis Tusha
</p>
