"""
yt-dlp download bridge for Oddtunes Android.
Called from Kotlin via Chaquopy's Python API.
"""

import json
import os
import glob


def download_audio(video_id, output_dir, filename):
    """
    Downloads audio from YouTube using yt-dlp.

    Args:
        video_id: YouTube video ID (e.g., 'dQw4w9WgXcQ')
        output_dir: Directory to save the downloaded file
        filename: Base filename (without extension)

    Returns:
        JSON string: {"status": "ok", "path": "/path/to/file.m4a"}
                  or {"status": "error", "message": "error details"}
    """
    try:
        from yt_dlp import YoutubeDL

        url = f"https://www.youtube.com/watch?v={video_id}"
        output_template = os.path.join(output_dir, f"{filename}.%(ext)s")

        ydl_opts = {
            # Fallback chain: m4a audio -> any audio in m4a container -> best audio -> best
            'format': 'bestaudio[ext=m4a]/bestaudio/best',
            'outtmpl': output_template,
            'noplaylist': True,
            'no_warnings': True,
            'quiet': True,
            'extract_flat': False,
            'retries': 5,
            'fragment_retries': 5,
            # Do NOT use FFmpeg postprocessors — no ffmpeg binary on Android.
            # Format 140 is already m4a so no conversion needed.
            # If we get webm/opus, Dart-side ffmpeg_kit handles conversion.
            'updatetime': False,
            # Workaround for Android: disable cache to avoid permission issues
            'cachedir': False,
            # Workaround for YouTube Bot Protection:
            'extractor_args': {'youtube': {'player_client': ['android', 'web']}},
        }

        with YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            # yt-dlp returns the actual filename it wrote
            if info:
                downloaded_file = ydl.prepare_filename(info)
                if os.path.exists(downloaded_file):
                    return json.dumps({"status": "ok", "path": downloaded_file})

        # Fallback: find the file by pattern
        m4a_path = os.path.join(output_dir, f"{filename}.m4a")
        if os.path.exists(m4a_path):
            return json.dumps({"status": "ok", "path": m4a_path})

        # Try webm (if bestaudio was webm)
        webm_path = os.path.join(output_dir, f"{filename}.webm")
        if os.path.exists(webm_path):
            return json.dumps({"status": "ok", "path": webm_path})

        # Last resort: find any file matching the filename
        pattern = os.path.join(output_dir, f"{filename}.*")
        matches = glob.glob(pattern)
        if matches:
            matches.sort(key=os.path.getmtime, reverse=True)
            return json.dumps({"status": "ok", "path": matches[0]})

        return json.dumps({
            "status": "error",
            "message": f"Download completed but no output file found in {output_dir}"
        })

    except Exception as e:
        return json.dumps({
            "status": "error",
            "message": str(e)
        })


def get_version():
    """Returns yt-dlp version info for diagnostics."""
    try:
        import yt_dlp
        return json.dumps({
            "status": "ok",
            "version": yt_dlp.version.__version__,
            "python": f"{__import__('sys').version}"
        })
    except Exception as e:
        return json.dumps({
            "status": "error",
            "message": str(e)
        })
