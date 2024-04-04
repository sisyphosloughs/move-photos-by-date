# move-photos-by-date

This script organizes photos into directories based on their [EXIF](#what-are-EXIF-data) creation date.

Features:

- Allows for organizing photos into a new or existing folder.
- Organizes photos into year, month, and optionally day directories. Example:
    - Year and month directories (`y-m` the pattern): `/your-folder/Pictures/2024/03`.
    - Year, month, and day directories (`y-m-d` the pattern): `/your-folder/Pictures/2024/03/26`.
- Optional specification of file extensions for image types.
- Optional exclusion of directories.
- Also moves XMP and DOP [Sidecar](#what-are-sidecar-files) files.
- Excludes images and sidecar files that are already present in the target directory.
- Does not move files automatically; you review the candidates for new organization.

## Requirements


- Basic knowledge of using the shell on Linux or macOS is required.
- `exiftool` must be installed. See [How do I install `exiftool`](#how-do-i-install-exiftool).
- Optional: Git installation on your computer.

## Installation

1. Download the script.
2. Make the script executable: `chmod +x move-photos-by-date.sh`.

> [!TIP]
> Run the script in its own directory to keep your folder structure clean.

## Usage

> [!NOTE]
> - Create a backup of your data before running the script.
> - Test the script with a small set of photos to ensure it works as expected.

### Organizing Photos

1. Determine the source directory containing your photos.
2. Determine the target directory where the photos will be organized.
3. Open the shell.
4. Change to the directory containing the script.
5. Create the command to organize the photos:  
   `./move-photos-by-date.sh -s <SourceDirectory> -t <TargetDirectory> -p <Pattern> [-e <ExcludedDirectories>] [-f <FileExtensions>]`  
   > [!TIP]
   > - `<Pattern>` must be either `y-m-d` or `y-m`, depending on how you want to organize the photos.
   > - `<ExcludedDirectories>` is a comma-separated list of directories you want to exclude.
   > - `<FileExtensions>` is a comma-separated list of file extensions to consider (e.g., `jpg,png`).

6. Execute the command.

**Results:**

The script creates two files in the directory from which it is run:
| File               | Remark                                         |
| ------------------ | ---------------------------------------------- |
| `move.sh`          | Commands to move the photos.                   |
| `cannot_move.txt`  | List of files that cannot be moved.            |

> [!NOTE]
> These files are overwritten each time the script is run.

### Review and Move

1. Review the `move.sh` file to see the move commands.
2. Check the `cannot_move.txt` file for files that could not be processed.
3. Execute `./move.sh` to move the photos.

**Result:** The photos have been organized according to their EXIF creation date.

## FAQ

### What is EXIF data?

EXIF data is metadata stored in photos that contain information such as the date of capture, camera settings, and possibly location. This script uses the capture date from the EXIF data to organize photos. See 

### What are sidecar files?

Typically, metadata such as tags or ratings of photos are stored not in the photo file itself but externally. This protects the photo file. Most often, sidecar files have the extension XMP. These sidecar files differ from a photo file only by the extension.

### Why are some files not moved?

Files that cannot be moved either lack the required EXIF data, or there was a conflict (e.g., a file with the same name in the target directory). Check `cannot_move.txt` for details.

### Can I run the script on a Windows system?

Yes, but you need to install the [Windows Subsystem for Linux](https://learn.microsoft.com/en-us/windows/wsl/about) and install `exiftool` within that subsystem.

### How do I install `exiftool`?

On most Linux distributions, you can install `exiftool` via your package manager. On macOS, you can install `exiftool` with [Homebrew](https://brew.sh/): `brew install exiftool`.

## See also

- [Photo-Sidecar-Cleaner: My script to find and remove orphaned sidecar files](https://github.com/sisyphosloughs/photo-sidecar-cleaner)
