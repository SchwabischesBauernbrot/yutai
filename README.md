Yutai - A small imageboard.
=====

It should be fast and straight forward to use, but bear in mind that it is written in a compiled, unsafe language (Zig). This version uses the system OpenSSL.

Dependencies
------------
- Zig = 0.11.0
- SQLite >= 3.21.0
- ImageMagick >= 7.1.1
- OpenSSL

Cloning the repository
----------------------
    git clone https://codeberg.org/cirefl/yutai

Initializing the database
-------------------------
    ./script/reset_db.sh

Configuring the server
----------------------
1. Set a root user and a random address salt in `config.json`
2. Run the imageboard
3. Register a user with the new root name

Note that you have to restart the imageboard for the `config.json` changes to take effect.
Consider updating `src/view/global/rules.html` and `src/view/global/faq.html`.

Running
-------
    zig build -Doptimize=ReleaseSafe run
