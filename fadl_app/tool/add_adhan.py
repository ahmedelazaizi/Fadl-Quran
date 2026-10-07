"""Add a bundled adhan recording to the Android and iOS apps.

    python3 tool/add_adhan.py SOURCE ID [--start SECONDS] [--end SECONDS]

SOURCE is any audio or video file ffmpeg reads (for example a Wikimedia
Commons download). ID is the sound id, `adhan_<name>`, or `adhan_fajr_<name>`
for a recording with «الصلاة خير من النوم».

Writes, from the [start, end] span of SOURCE with the loudness levelled:
- android/app/src/main/res/raw/ID.ogg: the whole adhan, played by
  AdhanService on Android;
- ios/Runner/ID.caf: its first 29.5 s with a fade-out (Apple caps
  notification sounds at 30 s), registered in the Xcode project.

Then list the recording in lib/core/adhan_catalog.dart with its source,
author, licence and these changes. Needs ffmpeg.
"""

import argparse
import hashlib
import re
import subprocess
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
RAW = PROJECT / "android" / "app" / "src" / "main" / "res" / "raw"
RUNNER = PROJECT / "ios" / "Runner"
PBXPROJ = PROJECT / "ios" / "Runner.xcodeproj" / "project.pbxproj"

# Notification sounds must be shorter than 30 s on iOS.
IOS_CLIP_SECONDS = 29.5
IOS_FADE_SECONDS = 3.0


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", *args], check=True)


def duration(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
        check=True, capture_output=True, text=True,
    ).stdout
    return float(out)


def build_android(source, target, start, end):
    span = ["-ss", str(start)] + (["-to", str(end)] if end is not None else [])
    length = (end if end is not None else duration(source)) - start
    filters = ",".join([
        "highpass=f=70",  # wind and traffic rumble below the voice
        "loudnorm=I=-16:TP=-1.5:LRA=11",  # the same loudness for every muezzin
        "afade=t=in:d=0.3",
        f"afade=t=out:st={max(length - 2, 0):.2f}:d=2",
    ])
    ffmpeg(*span, "-i", str(source), "-vn", "-ac", "1", "-ar", "44100", "-af", filters,
           "-c:a", "libvorbis", "-q:a", "5", str(target))


def build_ios(android_file, target):
    fade_start = IOS_CLIP_SECONDS - IOS_FADE_SECONDS
    ffmpeg("-i", str(android_file), "-t", str(IOS_CLIP_SECONDS),
           "-af", f"afade=t=out:st={fade_start}:d={IOS_FADE_SECONDS}",
           "-ac", "1", "-ar", "22050", "-c:a", "adpcm_ima_qt", "-f", "caf", str(target))


def object_id(sound_id, kind):
    # Stable ids, so running the tool again changes nothing.
    return hashlib.sha1(f"fadl/{sound_id}/{kind}".encode()).hexdigest()[:24].upper()


def register_ios(sound_id):
    text = PBXPROJ.read_text(encoding="utf-8")
    name = f"{sound_id}.caf"
    if f"path = {name};" in text:
        return
    ref, build = object_id(sound_id, "ref"), object_id(sound_id, "build")

    def insert_after(anchor, line):
        nonlocal text
        if text.count(anchor) != 1:
            raise SystemExit(f"Xcode project anchor not found once: {anchor!r}")
        text = text.replace(anchor, anchor + line)

    insert_after(
        "/* Begin PBXBuildFile section */\n",
        f"\t\t{build} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};\n",
    )
    insert_after(
        "/* Begin PBXFileReference section */\n",
        f"\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = file; path = {name}; sourceTree = \"<group>\"; }};\n",
    )
    insert_after("\t\t\t\t97C146FD1CF9000F007C117D /* Assets.xcassets */,\n", f"\t\t\t\t{ref} /* {name} */,\n")
    insert_after(
        "\t\t\t\t97C146FE1CF9000F007C117D /* Assets.xcassets in Resources */,\n",
        f"\t\t\t\t{build} /* {name} in Resources */,\n",
    )
    PBXPROJ.write_text(text, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", type=Path)
    parser.add_argument("id")
    parser.add_argument("--start", type=float, default=0.0)
    parser.add_argument("--end", type=float)
    args = parser.parse_args()
    if not re.fullmatch(r"adhan_[a-z0-9_]+", args.id):
        raise SystemExit("ID must look like adhan_<name> or adhan_fajr_<name> (lowercase)")
    android = RAW / f"{args.id}.ogg"
    build_android(args.source, android, args.start, args.end)
    build_ios(android, RUNNER / f"{args.id}.caf")
    register_ios(args.id)
    print(f"{android.relative_to(PROJECT)}: {duration(android):.1f} s")
    print(f"ios/Runner/{args.id}.caf: {IOS_CLIP_SECONDS} s clip, registered in the Xcode project")


if __name__ == "__main__":
    main()
