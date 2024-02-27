Yutai - A small imageboard.
=====

It should be fast and straight forward to use, but bear in mind that it is written in a compiled, unsafe language (Zig). It supports TLS through a C library ([BearSSL](https://bearssl.org/)).

Dependencies
------------
- Zig = 0.11.0
- SQLite >= 3.40.0
- ImageMagick >= 7.1.1

Cloning the repository
----------------------
    git clone --recurse-submodule https://codeberg.org/cirefl/yutai

Initializing the database
-------------------------
    ./script/reset_db.sh

Configuring the server
----------------------
1. Open the `config.json` file
2. Set a random address salt
3. Set a root user
4. Save the changes
5. Run the imageboard
6. Register a user with the new root name

Note that you have to restart the imageboard for the `config.json` changes to take effect.

Running
-------
    zig build run
