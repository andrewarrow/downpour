
    "-o", "./data/%(id)s.%(ext)s",
    "-f", "bv*[vcodec^=avc1][ext=mp4]+ba[acodec^=mp4a][ext=m4a]/best[ext=mp4][vcodec^=avc1]",
    "--merge-output-format", "mp4",
