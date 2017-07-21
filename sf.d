#line 1553 "sf.nw"
import std.string    : toStringz;
import std.stdio     : writeln, write, stderr, stdin;
import std.format    : format;
import std.file      : DirEntry, dirEntries,
                       SpanMode, FileException;
import std.path      : baseName, extension, globMatch;
import std.traits    : isAssignable, TemplateOf;
import std.range     : isInputRange, isRandomAccessRange,
                       ElementType, hasSlicing, hasLength,
		       iota, InputRange, inputRangeObject;
import std.array     : array;
import std.ascii     : isWhite, isDigit;
import std.typecons  : Nullable;
import std.getopt    : defaultGetoptPrinter, getopt, config;
import std.conv      : to, dtext;
import std.exception : enforce;

import core.stdc.stdlib : exit, malloc, free;
import core.stdc.stdio  : FILE, fopen, fclose;
import core.stdc.locale : setlocale, LC_ALL;

import algo = std.algorithm;
import deimos.ncurses;

#line 1589 "sf.nw"
struct Index(string cookie)
{
  size_t i_;
  alias i_ this;
  Index opBinary(string op)(in int rhs)
  {
    Index other = this;
    mixin("other.i_ = i_ " ~ op ~ " rhs;");
    return other;
  }
  auto ref opAssign(in Index other)
  {
    i_ = other.i_;
  }
}

#line 1608 "sf.nw"
int toInt(T : Index!s, alias s)(in T x)
{
  return cast(int)x;
}

struct SafeRange(R, U)
  if (isRandomAccessRange!R &&
      hasSlicing!R          &&
      hasLength!R           &&
      is(U : size_t))
{
  alias IndexType = U;
  
  R list_;
  alias list_ this;

  auto ref opAssign(R other) {
    list_ = other;
    return this;
  }

  @property
  SafeRange save() { return this; }

  auto ref opIndex(in U i) inout {
    return list_[i];
  }

  SafeRange opSlice(in U l, in U h)
  {
    SafeRange other = this;
    other.list_ = list_[l .. h];
    return other;
  }

  @property
  U opDollar() const { return U(length); }

  private alias T = ElementType!R;
  static if (isAssignable!T) {
    auto ref opIndexAssign(in T val, in U i) {
      list_[i] = val;
      return list_[i];
    }
  }
}

struct VanillaIndexed(R)
  if (__traits(isSame, TemplateOf!R, SafeRange))
{
  R r_;
  alias r_ this;

  this(R r) {r_ = r;}

  @property
  VanillaIndexed save() { return this; }

  auto ref opIndex(in size_t i) inout {
    return r_[R.IndexType(i)];
  }

  VanillaIndexed opSlice(in size_t l, in size_t h)
  {
    VanillaIndexed other = this;
    other.r_ = r_[R.IndexType(l) .. R.IndexType(h)];
    return other;
  }

  private alias T = ElementType!R;
  static if (isAssignable!(T)) {
    auto ref opIndexAssign(in T val, in size_t i) {
      r_[R.IndexType(i)] = val;
      return r_[R.IndexType(i)];
    }
  }
}

// For automatic type deduction of R.
auto vanillaIndexed(R)(R r)
{
  return VanillaIndexed!(R)(r);
}

#line 1695 "sf.nw"
auto ifNull(T : Nullable!U, U)(in T x, in U d)
{
  return x.isNull ? d : x.get;
}

auto bound(int val, int min, int max)
{
  if (val < min) return min;
  else if (val > max) return max;
  return val;
}

auto lbound(int val, int min)
{
  if (val < min) return min;
  return val;
}

auto ubound(int val, int max)
{
  if (val > max) return max;
  return val;
}

auto quitIf(bool check, lazy string msg)
{
  if (check) {
    stderr.writeln(msg);
    exit(1);
  }
}

auto quitOnError(E)(lazy E expr, lazy string msg)
{
  try {
    static if (is(E == void)) {
      expr();
      return;
    } else {
      auto result = expr();
      return result;
    }
  } catch (Exception e) {
    stderr.writeln(msg);
    exit(1);
  }
  assert(0);
}

auto continueOnError(E)(lazy E expr, lazy string msg)
{
  try {
    static if (is(E == void)) {
      expr();
      return;
    } else {
      auto result = expr();
      return result;
    }
  } catch (Exception e) {
    // Ignore exception.
    stderr.writeln(msg);
  }
}

auto dstringz(string s)
{
  auto r = cast(dchar*)malloc(dchar.sizeof * s.length + 1);
  auto x = dtext(s);
  for (auto i = 0; i < x.length; ++i) {
    r[i] = x[i];
  }
  r[x.length] = 0;
  return r;
}

struct Percent
{
  int value;
}

auto percent(int val)
{
  assert(0 <= val && val <= 100,
         "Invalid percentage value.");
  return Percent(val);
}

#line 534 "sf.nw"
struct FileList
{
  
#line 170 "sf.nw"
alias FileIndex = Index!("F");
alias ViewIndex = Index!("V");
alias GlobIndex = Index!("G");

#line 189 "sf.nw"
private {
  
#line 127 "sf.nw"
struct FileImpl
{
  private:
  const string path;
  const string name;
  const string type;
  const ulong  size;
  const long   atime;
  const long   mtime;

  public:
  // XXX: May throw Exception.
  this(in string p)
  {
    this(DirEntry(p));
  }

  this(DirEntry d)
  {
    path = d.name;
    name = baseName(path);
    if (d.isDir)
      type = "Directory";
    else if (d.isSymlink)
      type = "Symlink";
    else if (!extension(name))
      type = "Unknown";
    else
      type = extension(name);
    size = d.size;
    atime = d.timeLastAccessed.toUnixTime;
    mtime = d.timeLastModified.toUnixTime;
  }
}

#line 191 "sf.nw"
  SafeRange!(FileImpl[],  FileIndex) list_;
  SafeRange!(FileIndex[], ViewIndex) file_;
  SafeRange!(ViewIndex[], FileIndex) view_;
  SafeRange!(FileIndex[], GlobIndex) glob_;
  SafeRange!(bool[], FileIndex)      selected_;
}

alias list_ this;

#line 537 "sf.nw"
  
#line 204 "sf.nw"
int opApply(scope int delegate(ViewIndex) dg) {
  int result = 0;
  for (auto i = ViewIndex(0);
            i < list_.length;
	    ++i) {
    result = dg(i);
    if (result) break;
  }
  return result;
}

#line 219 "sf.nw"
int opApply(scope int delegate(GlobIndex) dg) {
  int result = 0;
  for (auto i = GlobIndex(0);
            i < glob_.length;
	    ++i) {
    result = dg(i);
    if (result) break;
  }
  return result;
}

#line 235 "sf.nw"
To convert(To, From)(in From index) const {
  static if (is(To == From)) return index;
  
  static if (is(To == FileIndex)) {
    static if (is(From == ViewIndex)) {
      return file_[index];
    } else static if (is(From == GlobIndex)) {
      return glob_[index];
    }
  } else static if (is(To == ViewIndex)) {
    static if (is(From == FileIndex)) {
      return view_[index];
    } else static if (is(From == GlobIndex)) {
      return convert!To(glob_[index]);
    }
  } else {
    static assert(false, "convert: Unsupported conversion.");
  }
}


#line 261 "sf.nw"
template isIndexType(T)
{
  enum isIndexType =
    is(T == FileIndex) ||
    is(T == ViewIndex) ||
    is(T == GlobIndex);
}

const {
  auto name(T)(in T f) if (isIndexType!T)
  {
    return list_[convert!FileIndex(f)].name;
  }

  auto path(T)(in T f) if (isIndexType!T)
  {
    return list_[convert!FileIndex(f)].path;
  }
  
  auto type(T)(in T f) if (isIndexType!T)
  {
    return list_[convert!FileIndex(f)].type;
  }
  
  auto size(T)(in T f) if (isIndexType!T)
  {
    return list_[convert!FileIndex(f)].size;
  }
  
  auto mtime(T)(in T f) if (isIndexType!T)
  {
    return list_[convert!FileIndex(f)].mtime;
  }
  
  auto atime(T)(in T f) if (isIndexType!T)
  {
    return list_[convert!FileIndex(f)].atime;
  }
}

#line 426 "sf.nw"
@property
auto globMatches() const
{
  return glob_.length;
}

#line 538 "sf.nw"
  
#line 313 "sf.nw"
private void moveToFront(R)(in R s)
  if (isInputRange!R && hasLength!R &&
      is(ElementType!R == FileIndex))
{
  assert (s.length < file_.length);
  
  auto i = ViewIndex(0);
  foreach (e; s) {
    auto tf   = file_[i];
    auto tv   = view_[e];
    file_[i]  = e;
    view_[e]  = i;
    file_[tv] = tf;
    view_[tf] = tv;
    i++;
  }
}

enum SortField
{
  NAME,
  MTIME,
  ATIME,
  SIZE,
  GLOB,
  SELECT,
  FILETYPE
}

void sort(SortField sf)()
  if (sf == GLOB)
{
  moveToFront(glob_);
}

void sort(SortField sf)()
  if (sf == SELECT)
{
  auto s = &this.isSelected!FileIndex;
  algo.partition!(s, algo.SwapStrategy.stable)(vanillaIndexed(file_));
  algo.partition!(s, algo.SwapStrategy.stable)(vanillaIndexed(glob_));
  fixupView();
}

#line 363 "sf.nw"
private bool fileLess(SortField sf)(in FileIndex i, in FileIndex j)
{
  switch (sf) {
    case NAME:     return name(i)  < name(j);
    case MTIME:    return mtime(i) < mtime(j);
    case ATIME:    return atime(i) < atime(j);
    case SIZE:     return size(i)  < size(j);
    case FILETYPE: return type(i)  < type(j);
    default: assert(false, "BUG: Invalid sort field\n");
  }
}

private void fixupView()
{
  auto i = ViewIndex(0);
  foreach (f; file_) {
    view_[f] = i;
    i++;
  }
}

void sort(SortField sf)()
  if (sf == NAME     ||
      sf == FILETYPE ||
      sf == MTIME    ||
      sf == ATIME    ||
      sf == SIZE)
{
  auto less   = &this.fileLess!sf;
  algo.sort!(less, algo.SwapStrategy.stable)(vanillaIndexed(file_));
  algo.sort!(less, algo.SwapStrategy.stable)(vanillaIndexed(glob_));
  fixupView();
}

#line 401 "sf.nw"
void reverse()
{
  algo.reverse(vanillaIndexed(file_));
  algo.reverse(vanillaIndexed(glob_));
  fixupView();
}

#line 412 "sf.nw"
void glob(in string pattern)
{
  glob_ = [];
  foreach (f; file_) {
    if (globMatch(name(f), pattern)) {
      glob_ ~= f;
    }
  }
}

#line 440 "sf.nw"
void select(T)(in T f) if (isIndexType!T)
{
  selected_[convert!FileIndex(f)] = true;
}

void deselect(T)(in T f) if (isIndexType!T)
{
  selected_[convert!FileIndex(f)] = false;
}

bool isSelected(T)(in T f) const if (isIndexType!T)
{
  return selected_[convert!FileIndex(f)];
}

#line 461 "sf.nw"
@property
auto selected()
{
  auto pred = &this.isSelected!FileIndex;
  return algo.filter!(pred)(vanillaIndexed(file_));
}

#line 539 "sf.nw"
  
#line 474 "sf.nw"
static FileList loadDirectory(in string path)
{
  FileList result;

  auto files = dirEntries(path, SpanMode.shallow);

  foreach (f; files) {
    continueOnError(
      { result.list_ ~= FileImpl(f); }(),
      "sf: Failed to load " ~ f.name
    );
  }

  
#line 515 "sf.nw"
if (result.list_.length > 0) {
  result.view_.reserve(result.list_.length);
  result.file_.reserve(result.list_.length);

  result.selected_ = new bool[result.list_.length];
  result.view_     = array(
                      iota(
                      ViewIndex(0),
                      ViewIndex(result.list_.length)));
  result.file_     = array(
                      iota(
                       FileIndex(0),
                       FileIndex(result.list_.length)));
}

#line 488 "sf.nw"
  return result;
}

#line 495 "sf.nw"
static FileList fromPaths(in string[] paths)
{
  FileList result;

  result.list_.reserve(paths.length);

  foreach (p; paths) {
    continueOnError(
      { result.list_ ~= FileImpl(p); }(),
      "sf: Failed to load " ~ p
    );
  }
  
#line 515 "sf.nw"
if (result.list_.length > 0) {
  result.view_.reserve(result.list_.length);
  result.file_.reserve(result.list_.length);

  result.selected_ = new bool[result.list_.length];
  result.view_     = array(
                      iota(
                      ViewIndex(0),
                      ViewIndex(result.list_.length)));
  result.file_     = array(
                      iota(
                       FileIndex(0),
                       FileIndex(result.list_.length)));
}

#line 508 "sf.nw"
  return result;
}

#line 540 "sf.nw"
}

#line 1786 "sf.nw"
alias FileList.ViewIndex ViewIndex;
alias FileList.FileIndex FileIndex;
alias FileList.GlobIndex GlobIndex;

alias NAME     = FileList.SortField.NAME;
alias MTIME    = FileList.SortField.MTIME;
alias ATIME    = FileList.SortField.ATIME;
alias SIZE     = FileList.SortField.SIZE;
alias GLOB     = FileList.SortField.GLOB;
alias SELECT   = FileList.SortField.SELECT;
alias FILETYPE = FileList.SortField.FILETYPE;

#line 845 "sf.nw"
struct MainUI
{
  
#line 548 "sf.nw"
static struct Rectangle {
  int height;
  int width;
  int x;
  int y;
  WINDOW *win;
}

Rectangle screen;
Rectangle fileListWin;
Rectangle fileListPad;
Rectangle echoWin;

#line 782 "sf.nw"
FileList fileList;
ViewIndex current = ViewIndex(0);
Nullable!GlobIndex globCurrent;
bool writeFiles = false;
FILE* infile;
FILE* outfile;

#line 799 "sf.nw"
FieldSpec formatFile;

FieldSpec makeFileFormat(FieldSpec[] args...)
{
  int total;

  foreach (arg; args) {
    arg.realWidth = lbound(
      (arg.preferredWidth.value * fileListWin.width) / 100,
      arg.minWidth);
    total += arg.realWidth;
  }

  enforce(
    total <= fileListWin.width,
    "sf: screen not wide enough to display files."
  );

  return new class FieldSpec {
    this() { super(100.percent, fileListWin.width); }
    override string print(in FileList fl, in ViewIndex v) {
      string result;
      foreach (arg; args) {
        result ~= arg.print(fl, v);
      }
      return result;
    }
  };
}

#line 834 "sf.nw"
alias SinkType =
  void function(InputRange!(const(string)) files);
SinkType sink;

#line 1428 "sf.nw"
ViewIndex first = ViewIndex(0);

#line 848 "sf.nw"
  
  this(FileList fl, SinkType s) {
    fileList = fl;
    sink     = s;

    setlocale(LC_ALL, "");

    infile  = fopen("/dev/tty", "rb");
    scope (failure) fclose(infile);
    
    outfile = fopen("/dev/tty", "wb");
    scope (failure) fclose(outfile);
    
    enforce(
      newterm(cast(char*)null, outfile, infile),
      "sf: Failed to initialize UI."
    );

    scope (failure) endwin();
    
    // endwin() restores everything if anything follows fails.
    
    enforce(
      OK == noecho() &&
      OK == nonl()   &&
      ERR != curs_set(0),
      "sf: Failed to initialize UI."
    );
    
    
#line 578 "sf.nw"
int x, y;

getmaxyx(stdscr, y, x);
screen.height = y + 1;
screen.width  = x + 1;
screen.x      = 0;
screen.y      = 0;
screen.win    = stdscr;

fileListWin.height = screen.height - 1;
fileListWin.width  = screen.width;
fileListWin.x      = screen.x;
fileListWin.y      = screen.y;
fileListWin.win    = subwin(screen.win,
  fileListWin.height,
  fileListWin.width,
  fileListWin.y,
  fileListWin.x);

echoWin.height = 1;
echoWin.width  = screen.width;
echoWin.x      = screen.x;
echoWin.y      = screen.y + fileListWin.height;
echoWin.win    = subwin(stdscr,
  echoWin.height,
  echoWin.width,
  echoWin.y,
  echoWin.x);
enforce(
  OK == keypad(echoWin.win, true),
  "sf: Failed to initialize UI."
);

fileListPad.height = cast(int)fileList.length + fileListWin.height;
fileListPad.width  = screen.width;
fileListPad.x      = 0;
fileListPad.y      = 0;
fileListPad.win    = newpad(
  fileListPad.height,
  fileListPad.width);


#line 879 "sf.nw"
    formatFile = makeFileFormat(
      line(0.percent, 5),
      fcurrent(">"),
      space(),
      selected("*"),
      space(),
      name(50.percent, 15),
      size(15.percent, 10)
    );

    reloadPad();
    show();
    loop();
  }

  ~this() {
    endwin();
    fclose(infile);
    fclose(outfile);
    if (writeFiles) {
        sink(inputRangeObject(
	       algo.map!(f => fileList.path(f))
	                (fileList.selected)
	     )
	);
    }
  }

  
#line 624 "sf.nw"
private void show() {
  int sminrow, smincol, smaxrow, smaxcol;
  int fst = cast(int)first;

  assert(fst >= 0);

  sminrow = fileListWin.y;
  smincol = fileListWin.x;
  
  int nfiles = cast(int)fileList.length - fst;

  smaxrow = sminrow + fileListWin.height - 1,
  smaxcol = smincol + fileListWin.width  - 1;
  
  prefresh(fileListPad.win,
           fst,
	   0,
	   sminrow,
	   smincol,
	   smaxrow,
   	   smaxcol);
}

#line 908 "sf.nw"
  
#line 922 "sf.nw"
auto readKey()
{
  dchar c;
  enforce(
    wget_wch(echoWin.win, &c) == OK,
    "sf: Failed to initialize UI."
  );
  return c;
}

void writeChar(dchar ch)
{
  writeStr(to!string(ch));
}

void writeStr(string s)
{
  waddstr(echoWin.win, toStringz(s));
}

void clearEcho()
{
  wclear(echoWin.win);
}

void pushBackKey(dchar ch)
{
  unget_wch(ch);
}

#line 909 "sf.nw"
  
#line 665 "sf.nw"
private void reloadPad()
{
  foreach (ViewIndex v; fileList) {
    
#line 653 "sf.nw"
auto i = toInt(v);
auto line = formatFile.print(this.fileList, v);
wmove(fileListPad.win, i, 0);
wclrtoeol(fileListPad.win);
auto ncline = dstringz(line);
waddwstr(fileListPad.win, ncline);
free(ncline);

#line 669 "sf.nw"
  }
}

private void reloadPad(R)(R files)
  if (isInputRange!R && is(ElementType!R == ViewIndex))
{
  foreach (ViewIndex v; files) {
    
#line 653 "sf.nw"
auto i = toInt(v);
auto line = formatFile.print(this.fileList, v);
wmove(fileListPad.win, i, 0);
wclrtoeol(fileListPad.win);
auto ncline = dstringz(line);
waddwstr(fileListPad.win, ncline);
free(ncline);

#line 677 "sf.nw"
  }
}

#line 910 "sf.nw"
  
#line 691 "sf.nw"
private static class FieldSpec
{
  Percent preferredWidth;
  int     minWidth;
  int     realWidth;

  this(Percent p, int min) {
    preferredWidth = p;
    minWidth = min;
  }

  string print(in FileList fl, in ViewIndex v) {
    assert(0);
  }
}

private static auto name(Percent p, int min)
{
  return new class FieldSpec {
    this() { super(p, min); }
    override string print(in FileList fl, in ViewIndex v)
    {
      auto w = to!string(realWidth);
      return format("%-" ~ w ~ "." ~ w ~ "s", fl.name(v));
    }
  };
}

private static auto line(Percent p, int min)
{
  return new class FieldSpec {
    this() { super(p, min); }
    override string print(in FileList fl, in ViewIndex v)
    {
      auto w = to!string(realWidth);
      return format("%-" ~ w ~ "d", v);
    }
  };
}

private static auto space(int n = 1)
{
  return new class FieldSpec {
    this() { super(0.percent, n); }
    override string print(in FileList fl, in ViewIndex v)
    {
      return " ";
    }
  };
}

private static auto selected(string marker)
{
  return new class FieldSpec {
    this() { super(0.percent, 1); }
    override string print(in FileList fl, in ViewIndex v)
    {
      auto selectedp = &fl.isSelected!ViewIndex;
      return selectedp(v) ? marker : " ";
    }
  };
}

private auto fcurrent(string marker)
{
  return new class FieldSpec {
    this() { super(0.percent, 1); }
    override string print(in FileList fl, in ViewIndex v)
    {
      return current == v ? marker : " ";
    }
  };
}

private static auto size(Percent p, int min)
{
  return new class FieldSpec {
    this() { super(p, min); }
    override string print(in FileList fl, in ViewIndex v)
    {
      return format("%" ~ to!string(realWidth) ~ "d", fl.size(v));
    }
  };
}

#line 911 "sf.nw"
  
#line 1392 "sf.nw"
void loop()
{
  
#line 1359 "sf.nw"
void setCurrent(in int newcur)
{
  alias VI = ViewIndex;
  current = VI(bound(
                 newcur,
                 0,
                 cast(int)fileList.length - 1));
}

@property
int cur()
{
  return toInt(current);
}

void setGlobCurrent(in int newcur)
{
  alias GI = GlobIndex;
  globCurrent = GI(bound(
                 newcur,
                 0,
                 cast(int)fileList.globMatches - 1));
}

static int charToInt(in dchar c)
{
  assert(c.isDigit);
  return c - '0';
}

#line 1395 "sf.nw"
  
#line 1098 "sf.nw"
dchar c;

#line 1139 "sf.nw"
int n;
string s;

#line 1226 "sf.nw"
int m, beg, end;

#line 1396 "sf.nw"
  
#line 964 "sf.nw"
static struct DataStack(size_t nelems) {
  static struct DataStackElem {
    enum _Type { NODATA, NUM, STR, CH, MARK }

    _Type type;
  
    union _Data {
      int num;
      string str;
      dchar ch;
    }

    _Data data;
  
    alias data this;
    
    void set(T, _Type t = _Type.NODATA)(in T data) {
      static if (is(T == int)) {
        static assert(t != _Type.NODATA,
          "DataStackElem: Specify type of int.");
        type = t;
        num  = cast(int)data;
      } else static if (is(T == string)) {
        type = STR;
        str = cast(string)data;
      } else static if (is(T == dchar)) {
        type = CH;
        ch = cast(dchar)data;
      } else {
        static assert(false,
	  "DataStackElem: Unsupported data type.");
      }
    }

    string toString() const {
      final switch (type) {
      case _Type.NUM:    return to!string(num);
      case _Type.STR:    return "\"" ~ to!string(str) ~ "\"";
      case _Type.CH:     return "\'" ~ to!string(ch);
      case _Type.MARK:   return to!string(num) ~ "m";
      case _Type.NODATA: assert(0);
      }
    }
  }

  DataStackElem[nelems] stack;
  int top = 0;

  alias SType = DataStackElem._Type;

  template STypeToType(SType t) {
    static if (t == SType.NUM || t == SType.MARK)
      alias STypeToType = int;
    else static if (t == SType.CH)
      alias STypeToType = dchar;
    static if (t == SType.STR)
      alias STypeToType = string;
  }

  void push(SType t, T = STypeToType!t)(in T d)
  {
    assert (top < nelems);
    stack[top].set!(T, t)(d);
    ++top;
  }

  auto pop(SType t)()
  {
    Nullable!(STypeToType!t) result;

    if (top == 0) return result;
    if (t == stack[top - 1].type) {
      static if (t == SType.NUM ||
                 t == SType.MARK) {
       	--top;
        result = stack[top].num;
      } else static if (t == SType.STR) {
        --top;
        result = stack[top].str;
      } else static if (t == SType.CH) {
        --top;
        result = stack[top].ch;
      } else {
        static assert(false, "pop: Invalid type.");
      }
    }
    return result;
  }

  auto peek()
  {
    Nullable!DataStackElem result;
    if (top > 0) {
      result = stack[top - 1];
    }
    return result;
  }

  void popAny()
  {
    if (top > 0) --top;
  }
}

DataStack!100 dataStack;

alias SType  = dataStack.SType;
alias NUM    = SType.NUM;
alias MARK   = SType.MARK;
alias CH     = SType.CH;
alias STR    = SType.STR;
alias NODATA = SType.NODATA;

#line 1397 "sf.nw"
  
#line 1083 "sf.nw"
enum {
  START,
  READ_CH,
  READ_STR,
  READ_NUM,
  READ_COMMAND,
  QUIT
}

int state = START;


#line 1399 "sf.nw"
  while (true) {
    
#line 1107 "sf.nw"
c   = cast(dchar)readKey();

#line 1401 "sf.nw"
    switch(state) {
      
#line 1113 "sf.nw"
case START:
  clearEcho();
  if (c.isWhite) {
    state = START;
  } else if (c == '\"') {
    s = "";
    writeChar('\"');
    state = READ_STR;
  } else if (c == '\'') {
    writeChar('\'');
    state = READ_CH;
  } else if (c.isDigit) {
    n = 0;
    pushBackKey(c);
    state = READ_NUM;
  } else {
    pushBackKey(c);
    state = READ_COMMAND;
  }
  break;

#line 1403 "sf.nw"
      
#line 1143 "sf.nw"
case READ_CH:
  writeChar(c);
  dataStack.push!CH(c);
  state = START;
  break;

case READ_STR:
  if (c != '\"') {
    writeChar(c);
    s ~= c;
  } else {
    writeChar('\"');
    dataStack.push!STR(s);
    state = START;
  }
  break;

case READ_NUM:
  if (c.isDigit) {
    writeChar(c);
    n = n * 10 + charToInt(c);
  } else {
    dataStack.push!NUM(n);
    pushBackKey(c);
    state = START;
  }
  break;

#line 1404 "sf.nw"
      
#line 1178 "sf.nw"
case READ_COMMAND:
  switch (c) {
    
#line 1190 "sf.nw"
case 'r':
  fileList.reverse(); break;

#line 1201 "sf.nw"
case 'j':
  setCurrent(cur + dataStack.pop!NUM().ifNull(1));
  break;
case 'k':
  setCurrent(cur - dataStack.pop!NUM().ifNull(1));
  break;
case ';':
  auto x = dataStack.pop!MARK();
  if (x.isNull) {
    x = dataStack.pop!NUM();
  }
  auto dest = x.ifNull(0);
  setCurrent(dest);
  break;
case 'm':
  dataStack.push!MARK(cur);
  break;

#line 1240 "sf.nw"
case 's':
  
#line 1229 "sf.nw"
m = dataStack.pop!MARK().ifNull(cur);

if (m > cur) {
  beg = cur;
  end = m + 1;
} else {
  beg = m;
  end = cur + 1;
}

#line 1242 "sf.nw"
  foreach (v; beg .. end) {
    auto v1 = ViewIndex(v);
    fileList.select(v1);
  }
  break;
case 'S':
  
#line 1229 "sf.nw"
m = dataStack.pop!MARK().ifNull(cur);

if (m > cur) {
  beg = cur;
  end = m + 1;
} else {
  beg = m;
  end = cur + 1;
}

#line 1249 "sf.nw"
  foreach (v; beg .. end) {
    auto v1 = ViewIndex(v);
    fileList.deselect(v1);
  }
  break;
case 't':
  
#line 1229 "sf.nw"
m = dataStack.pop!MARK().ifNull(cur);

if (m > cur) {
  beg = cur;
  end = m + 1;
} else {
  beg = m;
  end = cur + 1;
}

#line 1256 "sf.nw"
  foreach (v; beg .. end) {
    auto v1 = ViewIndex(v);
    if (fileList.isSelected(v1))
      fileList.deselect(v1);
    else
      fileList.select(v1);
  }
  break;

#line 1269 "sf.nw"
case 'a':
  auto sortarg = dataStack.pop!CH().ifNull(dchar('n'));
  switch (sortarg) {
    case 'n': fileList.sort!(NAME);     break;
    case 'm': fileList.sort!(MTIME);    break;
    case 'a': fileList.sort!(ATIME);    break;
    case 's': fileList.sort!(SIZE);     break;
    case 'g': fileList.sort!(GLOB);     break;
    case 'u': fileList.sort!(SELECT);   break;
    case 't': fileList.sort!(FILETYPE); break;
    default:  break;
  }
  break;

#line 1288 "sf.nw"
case 'g':
  string globarg = dataStack.pop!STR().ifNull("");
  fileList.glob(globarg);
  if (fileList.globMatches) {
    setGlobCurrent(0);
    setCurrent(
      toInt(fileList
            .convert!ViewIndex(
              globCurrent.get)));
  }
  state = START;
  break;

case 'n':
  if (!globCurrent.isNull) {
    auto g = toInt(globCurrent.get);
    setGlobCurrent(g + 1);
    setCurrent(
      toInt(fileList
            .convert!ViewIndex(
              globCurrent.get)));
  }
  state = START;
  break;

case 'N':
  if (!globCurrent.isNull) {
    auto g = toInt(globCurrent.get);
    setGlobCurrent(g - 1);
    setCurrent(
      toInt(fileList
            .convert!ViewIndex(
              globCurrent.get)));
  }
  state = START;
  break;

#line 1328 "sf.nw"
case 'q':
  writeFiles = true;
  goto quit;

case 'Q':
  writeFiles = false;
  goto quit;

#line 1337 "sf.nw"
default: break; // Unknown command letter.

#line 1344 "sf.nw"
case 'p':
  clearEcho();
  auto top = dataStack.peek();
  if (!top.isNull) {
    writeStr(top.get.toString());
  }
  break;
case 'P':
  dataStack.popAny();
  break;

#line 1181 "sf.nw"
  }
  state = START;
  break;

default: assert(0);

#line 1405 "sf.nw"
    }
    
#line 1431 "sf.nw"
int nlines = fileListWin.height;

if (current < first) {
  first = ViewIndex(lbound(cur - 4 * nlines/5, 0));
} else if (cur >= first + nlines) {
  first = ViewIndex(lbound(cur - nlines/5, 0));
}

ViewIndex last = ViewIndex(
  ubound(toInt(first) + nlines,
         cast(int)fileList.length));
reloadPad(iota(first, last));
show();

#line 1407 "sf.nw"
  }

quit: return;
}

#line 912 "sf.nw"
}

#line 1449 "sf.nw"
alias IRS = InputRange!(const(string));

void printn(IRS files)
{
  foreach (f; files) writeln(f);
}

void printq(IRS files)
{
  foreach (f; files) {
    write("\""); write(f); write("\"");
    write(" ");
  }
}

void printz(IRS files)
{
  foreach (f; files) {
    write(f);
    write("\0");
  }
}


#line 1483 "sf.nw"
void main(string[] args)
{
  enum OutputFormat {
  n,
  q,
  z,
  }

  OutputFormat outFormat = OutputFormat.n;

  auto ohelp = r"Output format
    n - One file per-line. Assumes there are no newlines in filenames. (default)
    q - Double-quoted, separated by spaces.
    z - Separated by null bytes.";

  auto proghelp =
  r"sf <options> [<dir>]: Select files from <dir> or current directory.
sf <options> -: Select files from the list of files in standard input.";

  auto helpInformation =
    getopt(args,
     config.passThrough,
     "output|o", ohelp, &outFormat
    );

  if (helpInformation.helpWanted) {
    defaultGetoptPrinter(proghelp,
      helpInformation.options);
    return;
  }

  FileList fl =
  quitOnError(
    {
      if (args.length > 1) {
        if (args[$ - 1] == "-") {
          return FileList.fromPaths(stdin.byLineCopy.array);
        } else {
          return FileList.loadDirectory(args[$-1]);
        }
      } else {
        return FileList.loadDirectory(".");
      }
    }(),
    "sf: Failed to load file list."
  );

  quitIf(fl.length == 0,
         "sf: No files to select.");

  auto sink = 
  {
    final switch (outFormat) {
    case OutputFormat.n:
      return &printn;
    case OutputFormat.q:
      return &printq;
    case OutputFormat.z:
      return &printz;
    }
  }();

  try {
    MainUI(fl, sink);
  } catch (Exception e) {
    stderr.writeln(e.msg);
  }
}

