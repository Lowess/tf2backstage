# customize.py - make the entire parsed data available as `root`
def alter_context(ctx: dict) -> dict:
    ctx["root"] = ctx
    return ctx
