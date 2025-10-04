{
  programs = {
    bash = {
      enable = true;
      enableCompletion = true;
      enableVteIntegration = true;
      historyControl = [
        "ignoreboth"
        "erasedups"
      ];
      historyIgnore = [
        "$"
        "[ ]*"
        "exit"
        "ls"
        "bg"
        "fg"
        "history"
        "clear"
        "cd"
        "rm"
        "cat"
      ];
      shellOptions = [
        # Default
        "checkwinsize" # Checks window size after each command.
        "complete_fullquote"
        "expand_aliases"

        # Default from home manager
        "checkjobs"
        "extglob"
        "globstar"
        "histappend"

        # Other
        "cdspell" # Tries to fix minor errors in the directory spellings
        "dirspell"
        "shift_verbose"
        "cmdhist" # Save multi-line commands as one command
      ];
      initExtra = ''
        # Enable history expansion with space
        # E.g. typing !!<space> will replace the !! with your last command
        bind Space:magic-space

        # Custom bash functions

        # Create compressed tar.gz archive
        compress() {
          if [ $# -eq 0 ]; then
            echo "Usage: compress <directory_or_file>"
            return 1
          fi
          tar czf "''${1%/}.tar.gz" "$1"
        }

        # Write ISO file to SD card
        iso2sd() {
          if [ $# -ne 2 ]; then
            echo "Usage: iso2sd <iso_file> <device>"
            echo "Example: iso2sd image.iso /dev/sdb"
            echo ""
            echo "Available devices:"
            lsblk -d -o NAME,SIZE,TYPE,MOUNTPOINT | grep disk
            return 1
          fi

          echo "WARNING: This will erase all data on $2"
          read -p "Continue? (y/N) " -n 1 -r
          echo
          if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
          fi

          sudo dd if="$1" of="$2" bs=4M status=progress oflag=sync
          sudo eject "$2"
        }

        # Format drive with single ext4 partition
        format-drive() {
          if [ $# -ne 2 ]; then
            echo "Usage: format-drive <device> <label>"
            echo "Example: format-drive /dev/sdb MyDrive"
            return 1
          fi

          echo "WARNING: This will DESTROY ALL DATA on $1"
          read -p "Type 'YES' to continue: " -r
          if [[ $REPLY != "YES" ]]; then
            return 1
          fi

          sudo wipefs -af "$1"
          sudo parted "$1" --script mklabel gpt
          sudo parted "$1" --script mkpart primary ext4 0% 100%
          sudo mkfs.ext4 -F -L "$2" "''${1}1"
          sudo e2label "''${1}1" "$2"
          echo "Drive formatted successfully as $2"
        }

        # Convert video to 1080p
        transcode-video-1080p() {
          if [ $# -eq 0 ]; then
            echo "Usage: transcode-video-1080p <input_file> [output_file]"
            return 1
          fi

          local input="$1"
          local output="''${2:-''${input%.*}_1080p.mp4}"

          ffmpeg -i "$input" -vf scale=-2:1080 -c:v libx264 -preset slow -crf 22 -c:a aac -b:a 128k "$output"
        }

        # Convert video to 4K
        transcode-video-4K() {
          if [ $# -eq 0 ]; then
            echo "Usage: transcode-video-4K <input_file> [output_file]"
            return 1
          fi

          local input="$1"
          local output="''${2:-''${input%.*}_4K.mp4}"

          ffmpeg -i "$input" -vf scale=-2:2160 -c:v libx265 -preset slow -crf 24 -c:a aac -b:a 192k "$output"
        }

        # Convert image to high-quality JPG
        img2jpg() {
          if [ $# -eq 0 ]; then
            echo "Usage: img2jpg <input_file> [output_file]"
            return 1
          fi

          local input="$1"
          local output="''${2:-''${input%.*}.jpg}"

          convert "$input" -quality 95 "$output"
        }

        # Convert image to smaller web-friendly JPG
        img2jpg-small() {
          if [ $# -eq 0 ]; then
            echo "Usage: img2jpg-small <input_file> [output_file]"
            return 1
          fi

          local input="$1"
          local output="''${2:-''${input%.*}_small.jpg}"

          convert "$input" -resize 1080x -quality 95 "$output"
        }

        # Convert image to compressed PNG
        img2png() {
          if [ $# -eq 0 ]; then
            echo "Usage: img2png <input_file> [output_file]"
            return 1
          fi

          local input="$1"
          local output="''${2:-''${input%.*}.png}"

          convert "$input" -define png:compression-level=9 "$output"
        }
      '';
    };
    readline = {
      bindings = {
        # Up and down arrows search through the history for the characters before the cursor
        "\\e[A" = "history-search-backward";
        "\\e[B" = "history-search-forward";
      };

      variables = {
        colored-completion-prefix = true; # Enable coloured highlighting of completions
        completion-ignore-case = true; # Auto-complete files with the wrong case
        revert-all-at-newline = true; # Don't save edited commands until run
        show-all-if-ambiguous = true;

      };
    };
  };
}
