# Computer test audio

The user requested silent tests while using the computer (2026-10-11). Native integration harnesses turn application sound off before opening activities and synchronize the SDK mute setting. The smoke test checks native playback at player volume zero, then stops it. The dedicated Android emulator is launched with `-no-audio`. Do not play pronunciation samples or enable simulator/app audio without a new user instruction. Pronunciation review remains open.
