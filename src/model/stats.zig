const sqlite = @import("sqlite");
const root = @import("root");

const c = root.c;
const data = root.data;
const query = root.query;
const model = root.model;
const util = model.util;

const Context = root.Context;

const Error = model.Error;

pub fn get(context: Context) !data.Stats {
    const q = "get_stats";
    return (try util.oneAlloc(data.Stats, context, q, .{})).?;
}
