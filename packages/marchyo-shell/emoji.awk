# Parse unicode-emoji's emoji-test.txt into Commons/EmojiData.js RAW rows:
#   "<group>|<subgroup>|<chars>|<name>"
# Only fully-qualified entries are kept (those are the display forms); the
# Component group (skin-tone / ZWJ builder codepoints) is skipped whole.
# Input format reference (the lines we consume):
#   # group: Smileys & Emotion
#   # subgroup: face-smiling
#   1F600   ; fully-qualified  # 😀 E1.0 grinning face
# Run with gawk (3-arg match); see package.nix.
/^# group: / {
    gsub(/^# group: /, "");
    group = $0;
    next;
}
/^# subgroup: / {
    gsub(/^# subgroup: /, "");
    subgroup = $0;
    next;
}
/; fully-qualified/ && group != "Component" {
    line = $0;
    sub(/^.*# /, "", line);
    # line is now "<emoji> E<version> <name>"; names never contain "|" or
    # double quotes (Unicode data names use spaces and dashes).
    if (match(line, /^([^ ]+) E[0-9]+\.[0-9]+ (.*)$/, m) && m[2] != "")
        printf "    \"%s|%s|%s|%s\",\n", group, subgroup, m[1], m[2];
}
