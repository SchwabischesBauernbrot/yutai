drop table if exists address;
create table address (
    address varchar(64),
    board varchar(32),
    hash varchar(128),
    
    primary key(address, board),
    foreign key(board)
        references board(board)
        on delete cascade
);

drop table if exists ban;
create table ban (
    ban_id integer,
    board varchar(32),
    address varchar(64),
    date integer,
    expires integer,
    reason text,
    moderator varchar(32),
    
    primary key(ban_id),
    foreign key(board)
        references board(board)
        on delete cascade
);

drop table if exists board;
create table board (
    board varchar(32),
    name varchar(128),
    description text,
    owner varchar(32),
    address_salt varchar(32),
    post_count integer default 1,
    
    primary key(board),
    foreign key(owner)
        references user(name)
);

drop table if exists captcha;
create table captcha (
    address varchar(64),
    expires integer,
    code varchar(8),
    path varchar(64),
    
    primary key(address)
);

drop table if exists entry;
create table entry (
    entry_id integer,
    subject varchar(128),
    body text,
    html integer,
    date integer,
    name varchar(32),
    
    primary key(entry_id),
    foreign key(name)
        references user(name)
);

drop table if exists image;
create table image (
    hash varchar(128),
    ext varchar(8),
    width integer,
    height integer,
    thumb_width integer,
    thumb_height integer,
    size integer,
    refs integer default 0,
    file_date integer default 0,
    file_state integer default 0,
    file_moderator varchar(32) default null,
    
    primary key(hash)
);

drop table if exists log;
create table log (
    log_id integer,
    board varchar(32),
    date integer,
    message text,
    address varchar(64),
    
    primary key(log_id),
    foreign key(board)
        references board(board)
        on delete cascade
);

drop table if exists moderator;
create table moderator (
    name varchar(32),
    board varchar(32),
    
    primary key(board, name),
    foreign key(board)
        references board(board)
        on delete cascade,
    foreign key(name)
        references user(name)
        on delete cascade
);

drop table if exists post_image;
create table post_image (
    post_image_id integer,
    hash varchar(128),
    board varchar(32),
    post integer,
    filename varchar(128),
    image_removed integer default 0,
    image_moderator varchar(32) default null,
    
    primary key(post_image_id),
    foreign key(hash)
        references image(hash)
        on delete cascade,
    foreign key(board, post)
        references post(board, post)
        on delete cascade
);

drop table if exists post;
create table post (
    board varchar(32),
    thread integer,
    post integer,
    date integer,
    subject varchar(128) default null,
    message text,
    removed integer default 0,
    reason text default null,
    moderator varchar(32) default null,
    address varchar(64),
    email varchar(128) default null,
    name varchar(128),
    
    primary key(board, post),
    foreign key(board)
        references board(board)
        on delete cascade,
    foreign key(board, thread)
        references thread(board, post)
        on delete cascade
);

drop table if exists reply;
create table reply (
    board varchar(32),
    post integer,
    sage integer,
    
    primary key(board, post),
    foreign key(board, post)
        references post(board, post)
        on delete cascade
);

drop table if exists report;
create table report (
    report_id integer,
    board varchar(32),
    thread integer,
    post integer,
    reason text,
    date integer,
    address varchar(64),
    global integer,
    closed integer default 0,
    message text default null,
    moderator varchar(32) default null,
    
    primary key(report_id),
    foreign key(board)
        references board(board)
        on delete cascade,
    foreign key(board, thread)
        references thread(board, post),
    foreign key(board, post)
        references post(board, post),
    foreign key(moderator)
        references user(name)
);

drop table if exists thread;
create table thread (
    board varchar(32),
    post integer,
    address_salt varchar(32),
    last_reply integer,
    sticky integer default false,
    
    primary key(board, post),
    foreign key(board, post)
        references post(board, post)
        on delete cascade
);

drop table if exists user;
create table user (
    name varchar(32),
    pass varchar(128),  --hash
    salt varchar(32),
    theme varchar(32),
    
    session varchar(64) default null,
    session_expires integer default 0,
    
    primary key(name)
);

drop view if exists post_image_view;
create view post_image_view as
    select *
    from post_image natural join image
;

drop view if exists post_image_rows_view;
create view post_image_rows_view as
    select *
    from post_image_view natural join post
;

drop view if exists thread_image_count_view;
create view thread_image_count_view as
    select count(post_image_id) as images, thread as post, board
    from post natural join post_image
    where removed = 0 and image_removed = 0 and thread is not null
    group by board, thread
;

drop view if exists thread_reply_count_view;
create view thread_reply_count_view as
    select count(post) as replies, thread as post, board
    from post
    where removed = 0 and thread is not null
    group by board, thread
;
    
drop view if exists thread_op_view;
create view thread_op_view as
    select *
    from thread
        natural join post
        natural left join post_image_view
    group by board, post
;

drop view if exists catalog_view;
create view catalog_view as
    select thread_op_view.*,
        ifnull(replies, 0) as replies,
        ifnull(images, 0) as images
    from thread_op_view
        natural left join thread_image_count_view
        natural left join thread_reply_count_view
    order by sticky desc, last_reply desc
;
