const table = @import("table/table.zig");
const util = @import("util.zig");

const Join = util.Join;
const LeftJoin = util.LeftJoin;

pub const Ban = table.Ban;
pub const Board = table.Board;
pub const Captcha = table.Captcha;
pub const Entry = table.Entry;
pub const Log = table.Log;
pub const Mod = table.Mod;
pub const Report = table.Report;
pub const Stats = table.Stats;
pub const User = table.User;
pub const Image = table.Image;
pub const Post = table.Post;

const FileRow = Join(table.PostImage, Image);
const PostRow = LeftJoin(Post, FileRow);
pub const Reply = Join(table.Reply, PostRow);
pub const Thread = Join(table.Thread, PostRow);
pub const CatalogThread = Join(Thread, table.CatalogRow);
pub const PostImage = Join(Post, FileRow);
