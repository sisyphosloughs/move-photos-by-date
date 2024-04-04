# Move Photos by Date

This script sorts photos into folders organized by their [Exif](#what-is-Exif-data) creation date.

Features:

- Allows for organizing photos into a new or existing folder.
- Organizes photos into year, month, and optionally day folders. Example:
    - Year and month folders (`y-m` the pattern): `/your-folder/Pictures/2024/03`.
    - Year, month, and day folders (`y-m-d` the pattern): `/your-folder/Pictures/2024/03/26`.
- Optional specification of file extensions for image types.
- Optional exclusion of folders.
- Also moves XMP and DOP [Sidecar](#what-are-sidecar-files) files.
- Excludes images and sidecar files that are already present in the target folder.
- Does not move files automatically; you review the candidates for new organization.

## Requirements

- Basic knowledge of using the shell on Linux or macOS is required.
- `exiftool` must be installed. See [How do I install `exiftool`](#how-do-i-install-exiftool).
- Optional: Git installation on your computer.

## Installation

1. Download the script.
2. Make the script executable: `chmod +x move-photos-by-date.sh`.

> [!TIP]
> Run the script in its own folder to keep your folder structure clean.

## Usage

> [!NOTE]
> - Create a backup of your data before running the script.
> - Test the script with a small set of photos to ensure it works as expected.

### Organizing Photos

1. Determine the source folder containing your photos.
2. Determine the target folder where the photos will be organized.
3. Open the shell.
4. Change to the folder containing the script.
5. Create the command to organize the photos:  
   `./move-photos-by-date.sh -s <Sourcefolder> -t <Targetfolder> -p <Pattern> [-e <Excludedfolders>] [-f <FileExtensions>]`  
   > [!TIP]
   > - `<Pattern>` must be either `y-m-d` or `y-m`, depending on how you want to organize the photos.
   > - `<Excludedfolders>` is a comma-separated list of folders you want to exclude.
   > - `<FileExtensions>` is a comma-separated list of file extensions to consider (e.g., `jpg,png`).

6. Execute the command.

**Results:**

The script creates two files in the folder from which it is run:
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

**Result:** The photos have been organized according to their Exif creation date.

### Clean up

After the Photos have ben organized in a new structure, it might happen, that orphaned files might exist in the old source folder. Examples, why this might happen:

- In the target folder sidecar files of the photo exists. These sidecar files are not overwritten by this script. Though the sidecar files remain in the source folder structure.
- In the source folder, some other file types exist.

If only a few folders exist in the source folder, you can manually check them with the file manager of your choice.

#### Search for Remaining Files

1. Use the following command to search for the remaining files:  
  ```sh
  find /your/old/folder/ -type f | while read -r file; do echo "rm \"$file\""; done > rest.sh
  ```
  > [!NOTE]
  > This command will not delete the files.

2. Review the `rest.sh` file. Remove the lines with files, you don't want to delete.
3. Make the script executable: `chmod +x rest.sh`.
4. Execute `./rest.sh` to delete the files.
5. Optionally: Move other files to another place with the file manager of your choice.
6. Remove the folder.

**Result**: The old folder no longer exists.

> [!Tip]
> If you only want to clean up sidecar files, you can use my script [Photo-Sidecar-Cleaner](https://github.com/sisyphosloughs/photo-sidecar-cleaner).

## FAQ

### What is Exif data?

Exif data is metadata stored in photos that contain information such as the date of capture, camera settings, and possibly location. This script uses the capture date from the Exif data to organize photos.

See also: [Exif (Wikipedia)](https://en.wikipedia.org/wiki/Exif)

### What are sidecar files?

Typically, metadata such as tags or ratings of photos are stored not in the photo file itself but externally. This protects the photo file. Most often, sidecar files have the extension XMP. These sidecar files differ from a photo file only by the extension.

See also: [Sidecar file (Wikipedia)](https://en.wikipedia.org/wiki/Sidecar_file)

### Why are some files not moved?

Files that cannot be moved either lack the required EXIF data, or there was a conflict (e.g., a file with the same name in the target folder). Check `cannot_move.txt` for details.

### Can I run the script on a Windows system?

Yes, but you need to install the [Windows Subsystem for Linux](https://learn.microsoft.com/en-us/windows/wsl/about) and install `exiftool` within that subsystem.

### How do I install `exiftool`?

On most Linux distributions, you can install `exiftool` via your package manager. On macOS, you can install `exiftool` with [Homebrew](https://brew.sh/): `brew install exiftool`.

## See also

- [Photo-Sidecar-Cleaner: My script to find and remove orphaned sidecar files](https://github.com/sisyphosloughs/photo-sidecar-cleaner)
- [Exif (Wikipedia)](https://en.wikipedia.org/wiki/Exif)
- [Sidecar file (Wikipedia)](https://en.wikipedia.org/wiki/Sidecar_file)