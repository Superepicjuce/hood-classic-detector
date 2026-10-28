
import subprocess
import time
import unicodedata
from pathlib import Path

import pandas as pd

HERE = Path(__file__).resolve().parent
DATABASE = HERE / "songs.xlsx"
SOUND = HERE / "certified_hood_classic.mp3"
POLL = 0.001


def norm(value):
    value = unicodedata.normalize("NFKC", str(value or ""))
    return " ".join(value.strip().casefold().split())


def current_track():
    script = '''
    tell application "Music"
        if player state is stopped then return ""
        try
            return (persistent ID of current track) & linefeed & ¬
                (name of current track) & linefeed & ¬
                (artist of current track) & linefeed & ¬
                (player state as string)
        on error
            return ""
        end try
    end tell
    '''
    try:
        result = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True, text=True, timeout=3
        )
        lines = result.stdout.strip().splitlines()
        if len(lines) < 4:
            return None
        return {
            "id": lines[0],
            "title": lines[1],
            "artist": lines[2],
            "state": lines[3],
        }
    except (subprocess.TimeoutExpired, OSError):
        return None


def load_database():
    df = pd.read_excel(DATABASE).fillna("")
    required = {"title", "artist"}
    columns = {str(c).strip().casefold(): c for c in df.columns}

    if not required.issubset(columns):
        raise ValueError("Excel needs title and artist columns.")

    result = {}
    for _, row in df.iterrows():
        key = (
            norm(row[columns["title"]]),
            norm(row[columns["artist"]]),
        )
        if not all(key):
            continue

        custom = str(row[columns["sound_file"]]).strip() \
            if "sound_file" in columns else ""
        result[key] = Path(custom).expanduser() if custom else SOUND

    return result


def main():
    database = load_database()
    last_id = None
    db_mtime = DATABASE.stat().st_mtime

    print("Watching Apple Music. Press Ctrl+C to quit.")

    while True:
        try:
            # Reload the Excel sheet if it changes.
            mtime = DATABASE.stat().st_mtime
            if mtime != db_mtime:
                database = load_database()
                db_mtime = mtime
                print("Reloaded Excel database.")

            track = current_track()

            if track and track["id"] != last_id:
                last_id = track["id"]
                key = (norm(track["title"]), norm(track["artist"]))

                print(f"Now playing: {track['title']} — {track['artist']}")

                if key in database:
                    sound = database[key]
                    print("🔥 CERTIFIED HOOD CLASSIC!")

                    # Pause the song, play the effect, then resume.
                    if track["state"] == "playing":
                        subprocess.run(
                            ["osascript", "-e",
                             'tell application "Music" to pause'],
                            capture_output=True
                        )

                    if sound.is_file():
                        subprocess.run(["afplay", str(sound)])

                    if track["state"] == "playing":
                        subprocess.run(
                            ["osascript", "-e",
                             'tell application "Music" to play'],
                            capture_output=True
                        )
                    else:
                        print(f"Sound file missing: {sound}")

            time.sleep(POLL)

        except KeyboardInterrupt:
            print("\nStopped.")
            break
        except Exception as exc:
            print(f"Error: {exc}")
            time.sleep(2)


if __name__ == "__main__":
    main()

