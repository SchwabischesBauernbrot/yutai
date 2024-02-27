drop trigger if exists cache_post_address;
create trigger cache_post_address
    after insert on post
    when (select count(1) from address where board = new.board and address = new.address) = 0
begin
    insert into address (
        board,
        address,
        hash
    ) values (
        new.board,
        new.address,
        sha256(new.address || (select address_salt from board where board = new.board))
    );
end;

drop trigger if exists cache_report_address;
create trigger cache_report_address
    after insert on report
    when (select count(1) from address where board = new.board and address = new.address) = 0
begin
    insert into address (
        board,
        address,
        hash
    ) values (
        new.board,
        new.address,
        sha256(new.address || (select address_salt from board where board = new.board))
    );
end;
