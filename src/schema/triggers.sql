drop trigger if exists update_file_state;
create trigger update_file_state
    instead of update of file_state, file_moderator on post_image_rows_view
begin
    update image
        set file_state = new.file_state,
            file_moderator = new.file_moderator,
            file_date = unixepoch()
        where hash = new.hash;
end;

drop trigger if exists update_image_removed;
create trigger update_image_removed
    instead of update of image_moderator on post_image_rows_view
begin
    update post_image
        set image_moderator = new.image_moderator,
            image_removed = unixepoch()
        where post_image_id = new.post_image_id;
end;

drop trigger if exists init_last_reply;
create trigger init_last_reply
    after insert on thread
begin
    update thread
        set last_reply = new.post
        where post = new.post and board = new.board;
end;

drop trigger if exists remove_replies;
create trigger remove_replies
    after delete on thread
begin
    delete from post
        where board = old.board and
            (thread = old.post or post = old.post);
end;

drop trigger if exists update_post_count;
create trigger update_post_count
    after insert on post
begin
    update board
        set post_count = post_count + 1
        where board = new.board;
end;

drop trigger if exists increase_ref_count;
create trigger increase_ref_count
    after insert on post_image
begin
    update image
        set refs = refs + 1
        where hash = new.hash;
end;

drop trigger if exists decrease_ref_count;
create trigger decrease_ref_count
    after delete on post_image
begin
    update image
        set refs = refs - 1
        where hash = old.hash;
end;

--logs

drop trigger if exists log_thread;
create trigger log_thread
    after insert on thread
begin
    insert into log (board, date, message, address)
        values (
            new.board,
            unixepoch(),
            printf('Posted a new thread (>>%u)', new.post),
            (select address from post where board = new.board and post = new.post)
        );
end;

drop trigger if exists log_reply;
create trigger log_reply
    after insert on reply
begin
    insert into log (board, date, message, address)
        values (
            new.board,
            unixepoch(),
            printf('Posted a reply (>>%u)', new.post),
            (select address from post where board = new.board and post = new.post)
        );
end;

drop trigger if exists log_upload;
create trigger log_upload
    after insert on post_image
begin
    insert into log (board, date, message, address)
        values (
            new.board,
            unixepoch(),
            printf('Uploaded %s (%s)', new.filename, new.hash),
            (select address from post where board = new.board and post = new.post)
        );
end;

drop trigger if exists log_report;
create trigger log_report
    after insert on report
begin
    insert into log (board, date, message, address)
        values (
            new.board,
            unixepoch(),
            printf('Opened a report (%u) on >>%u', new.report_id, new.post),
            new.address
        );
end;

drop trigger if exists log_close_report;
create trigger log_close_report
    after update on report
    when new.closed <> 0
begin
    insert into log (board, date, message, address)
        values (
            new.board,
            unixepoch(),
            printf('Report (%u) on >>%u closed by %s', new.report_id, new.post, new.moderator),
            new.address
        );
end;

drop trigger if exists log_remove_post_mod;
create trigger log_remove_post_mod
    after update on post
    when new.removed <> 0 and new.moderator is not null
begin
    insert into log (board, date, message, address)
        values (
            new.board,
            unixepoch(),
            printf('Post >>%u removed by %s', new.post, new.moderator),
            new.address
        );
end;

drop trigger if exists log_remove_post;
create trigger log_remove_post
    after update on post
    when new.removed <> 0 and new.moderator is null
begin
    insert into log (board, date, message, address)
        values (
            new.board,
            unixepoch(),
            printf('Post >>%u removed by poster', new.post),
            new.address
        );
end;

drop trigger if exists log_remove_post_image;
create trigger log_remove_post_image
    after update on post_image
    when new.image_removed <> 0
begin
    insert into log (board, date, message, address)
        values (
            new.board,
            unixepoch(),
            printf('File %s (%s) removed by %s', new.filename, new.hash, new.image_moderator),
            (select address from post where board = new.board and post = new.post)
        );
end;

drop trigger if exists log_ban;
create trigger log_ban
    after insert on ban
begin
    insert into log (board, date, message, address)
        values (
            new.board,
            unixepoch(),
            printf('Banned by %s (expires %u)', new.moderator, new.expires),
            new.address
        );
end;

drop trigger if exists log_remove_ban;
create trigger log_remove_ban
    after update on ban
begin
    insert into log (board, date, message, address)
        values (
            new.board,
            unixepoch(),
            printf('Ban (%u) updated by %s (expires %u)', new.ban_id, new.moderator, new.expires),
            new.address
        );
end;
