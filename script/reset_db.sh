#!/bin/bash
rm -f data.db
rm -f static/images/*
rm -f static/captcha/*
rm -f static/thumbs/*
sqlite3 data.db ".read src/schema/schema.sql"
sqlite3 data.db ".read src/schema/triggers.sql"
#sqlite3 data.db ".read test_data.sql"
