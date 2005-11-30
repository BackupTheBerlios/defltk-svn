
private import std.c.stdio;
extern(C) int setlocale(int, char*);

static this()
{
    fwide(stdout, 1);
    setlocale(0, "china");    
}