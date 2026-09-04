# Original game audio

Composed and rendered by an OpenAI Codex agent for this project. These assets have not been reviewed by a human.

All melodies, arrangements, synthesized instrument samples, and sound effects in this folder are original to this project. No third-party recordings or game melodies are included. These original audio files and their composition source are released under CC0 1.0 Universal, to the extent permitted by law: <https://creativecommons.org/publicdomain/zero/1.0/>.

The soundtrack uses warm harmonic flute, bell, plucked, bass, and brass voices with enveloped percussion. All audio is stored as actual 22,050 Hz, stereo, 16-bit PCM WAV assets. The game plays these files; it does not synthesize audio at runtime.

| File | Purpose | Duration |
| --- | --- | --- |
| title.wav | "A Small Quest for a Big Idea" — relaxed adventure theme | 38.4 seconds, looping |
| meadow.wav | "Tokens in the Tall Grass" — cheerful meadow theme | 33.1 seconds, looping |
| boss.wav | "The Scaling Showdown" — playful minor-key boss theme | 28.2 seconds, looping |
| victory.wav | "One Step Closer" — victory fanfare | 5.4 seconds |
| jump.wav | Rising jump chirp | 0.25 seconds |
| token.wav | Two-note collectible sparkle | 0.40 seconds |
| stomp.wav | Rounded impact | 0.25 seconds |
| hurt.wav | Descending damage effect | 0.46 seconds |
| powerup.wav | Ascending power-up flourish | 1.15 seconds |
| checkpoint.wav | Checkpoint chord chime | 1.00 second |
| select.wav | Menu confirmation | 0.25 seconds |
| death.wav | Gentle descending retry cue | 1.30 seconds |
| shield.wav | Protective shield sparkle | 0.72 seconds |
| boss_warn.wav | Three-note attack warning | 0.75 seconds |
| boss_land.wav | Heavy landing impact | 0.48 seconds |
| boss_hit.wav | Successful boss hit | 0.38 seconds |
| boss_defeat.wav | Defeat tumble and resolving sparkle | 1.50 seconds |

Rebuild with `python3 tools/compose_audio.py` from the project directory. Verify existing files without rebuilding with `python3 tools/compose_audio.py --verify`. The renderer uses only the Python standard library, seeds its percussion noise, wraps note and echo tails across music loop boundaries, and checks duration, stereo format, peaks, RMS amplitude, and loop boundary continuity. Godot's `Audio` singleton enables whole-file looping for title, meadow, and boss music.
