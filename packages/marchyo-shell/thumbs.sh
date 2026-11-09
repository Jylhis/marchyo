# marchyo-thumbs SIZE IMAGE...
# Prints "IMAGE<TAB>THUMBNAIL" for each image, generating a missing thumbnail
# in $XDG_CACHE_HOME/marchyo/thumbs. The file name hashes the path, SIZE, the
# byte size and the mtime, so an edited image gets a new thumbnail. An image
# that cannot be read or converted prints nothing.
size=$1
shift
cache="${XDG_CACHE_HOME:-$HOME/.cache}/marchyo/thumbs"
mkdir -p "$cache"

for img in "$@"; do
  [ -f "$img" ] || continue
  stamp=$(stat -L -c '%s-%Y' -- "$img") || continue
  key=$(printf '%s|%s|%s' "$img" "$size" "$stamp" | sha1sum | cut -d' ' -f1)
  out="$cache/$key.png"
  if [ ! -s "$out" ]; then
    tmp=$(mktemp "$cache/.tmp.XXXXXX")
    if magick "${img}[0]" -thumbnail "${size}x${size}>" -strip "png:$tmp" 2>/dev/null; then
      mv -f "$tmp" "$out"
    else
      rm -f "$tmp"
      continue
    fi
  fi
  printf '%s\t%s\n' "$img" "$out"
done

find "$cache" -type f -mtime +90 -delete
