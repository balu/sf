#line 1303 "sf.nw"
import std.string    : toStringz;
import std.stdio     : writeln, write, stderr;
import std.format    : format;
import std.file      : DirEntry, dirEntries,
                       SpanMode, FileException;
import std.path      : baseName, extension, globMatch;
import std.traits    : isAssignable, TemplateOf;
import std.range     : isInputRange, isRandomAccessRange,
                       ElementType, hasSlicing, hasLength,
		       iota;
import std.array     : array;
import std.ascii     : isWhite, isDigit;
import std.typecons  : Nullable;
import std.getopt    : defaultGetoptPrinter, getopt;
import std.conv      : to;

import core.stdc.stdlib : exit;
import core.stdc.stdio  : FILE, fopen, fclose;
    


import algo = std.algorithm;
import deimos.ncurses;

#line 1339 "sf.nw"
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

#line 1358 "sf.nw"
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

#line 1445 "sf.nw"
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

auto quitOnError(E)(lazy E expr, in string msg)
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
    stderr.writeln (msg);
    exit(1);
  }
  assert(0);
}


#line 492 "sf.nw"
struct FileList
{
  
#line 148 "sf.nw"
alias FileIndex = Index!("F");
alias ViewIndex = Index!("V");
alias GlobIndex = Index!("G");

#line 167 "sf.nw"
private {
  
#line 105 "sf.nw"
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

#line 169 "sf.nw"
  SafeRange!(FileImpl[],  FileIndex) list_;
  SafeRange!(FileIndex[], ViewIndex) file_;
  SafeRange!(ViewIndex[], FileIndex) view_;
  alias list_ this;

  SafeRange!(FileIndex[], GlobIndex) glob_;
  SafeRange!(bool[], FileIndex)      selected_;
}

#line 495 "sf.nw"
  
#line 182 "sf.nw"
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

#line 197 "sf.nw"
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

#line 213 "sf.nw"
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


#line 239 "sf.nw"
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

#line 404 "sf.nw"
@property
auto globMatches() const
{
  return glob_.length;
}

#line 496 "sf.nw"
  
#line 291 "sf.nw"
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
  algo.partition!(s)(vanillaIndexed(file_));
  algo.partition!(s)(vanillaIndexed(glob_));
  fixupView();
}

#line 341 "sf.nw"
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
  algo.sort!(less)(vanillaIndexed(file_));
  algo.sort!(less)(vanillaIndexed(glob_));
  fixupView();
}

#line 379 "sf.nw"
void reverse()
{
  algo.reverse(vanillaIndexed(file_));
  algo.reverse(vanillaIndexed(glob_));
  fixupView();
}

#line 390 "sf.nw"
void glob(in string pattern)
{
  glob_ = [];
  foreach (f; file_) {
    if (globMatch(name(f), pattern)) {
      glob_ ~= f;
    }
  }
}

#line 418 "sf.nw"
void select(T)(in T f) if (isIndexType!T)
{
  selected_[convert!FileIndex(f)] = true;
}

void deselect(T)(in T f) if (isIndexType!T)
{
  selected_[convert!FileIndex(f)] = false;
}

bool isSelected(T)(in T f) if (isIndexType!T)
{
  return selected_[convert!FileIndex(f)];
}

#line 439 "sf.nw"
@property
auto selected()
{
  auto pred = &this.isSelected!FileIndex;
  return algo.filter!(pred)(vanillaIndexed(file_));
}

#line 497 "sf.nw"
  
#line 452 "sf.nw"
static FileList loadDirectory(in string path)
{
  FileList result;

  auto files = dirEntries(path, SpanMode.shallow);
  while (!files.empty) { // nothrow?
    auto f = files.front; // nothrow?
    try {
      result.list_ ~= FileImpl(f);
    } catch (Exception e) {
      stderr.writeln("sf: Failed to load ", f.name);
    } finally {
      quitOnError(
        files.popFront,
	"sf: Failed to iterate directory " ~ path);
    }
  }

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
 
  return result;
}

#line 498 "sf.nw"
}

#line 1490 "sf.nw"
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

#line 659 "sf.nw"
struct MainUI(alias sink)
{
  
#line 506 "sf.nw"
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

#line 647 "sf.nw"
FileList fileList;
ViewIndex current = ViewIndex(0);
Nullable!GlobIndex globCurrent;
bool writeFiles = false;
FILE* infile;
FILE* outfile;

#line 1211 "sf.nw"
ViewIndex first = ViewIndex(0);

#line 662 "sf.nw"
  
  this(in string dirpath) {
    fileList =
      quitOnError(
        FileList.loadDirectory(dirpath),
	"sf: Failed to load directory " ~ dirpath);
    
    infile  = fopen("/dev/tty", "rb");
    scope (failure) fclose(infile);
    
    outfile = fopen("/dev/tty", "wb");
    scope (failure) fclose(outfile);
    
    assert(newterm(cast(char*)null, outfile, infile));
    scope (failure) endwin();
    
    // endwin() restores everything if anything follows fails.
    
    assert(OK == noecho());
    assert(OK == nonl());
    assert(ERR != curs_set(0));
    
    
#line 537 "sf.nw"
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
assert(OK == keypad(echoWin.win, true));

fileListPad.height = cast(int)fileList.length + fileListWin.height;
fileListPad.width  = screen.width;
fileListPad.x      = 0;
fileListPad.y      = 0;
fileListPad.win    = newpad(
  fileListPad.height,
  fileListPad.width);

#line 685 "sf.nw"
    reloadPad();
    show();
    loop();
  }

  ~this() {
    endwin();
    fclose(infile);
    fclose(outfile);
    if (writeFiles) {
        sink(algo.map!(f => fileList.path(f))
	              (fileList.selected));
    }
  }
  
  
#line 580 "sf.nw"
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

#line 701 "sf.nw"
  
#line 714 "sf.nw"
auto readKey()
{
  return wgetch(echoWin.win);
}

void writeChar(char ch)
{
  waddch(echoWin.win, ch);
}

void writeStr(string s)
{
  waddstr(echoWin.win, toStringz(s));
}

void clearEcho()
{
  wclear(echoWin.win);
}

void pushBackKey(char ch)
{
  ungetch(ch);
}

#line 702 "sf.nw"
  
#line 626 "sf.nw"
private void reloadPad()
{
  foreach (ViewIndex v; fileList) {
    
#line 609 "sf.nw"
auto i = toInt(v);
auto line = toStringz(
  "%-5d %1s %1s %-20.20s %-d".
    format(
      i,
      current == v ? ">" : " ",
      fileList.isSelected(v) ? "*" : " ",
      fileList.name(v),
      fileList.size(v)));
wmove(fileListPad.win, i, 0);
wclrtoeol(fileListPad.win);
mvwprintw(fileListPad.win, i, 0, line);

#line 630 "sf.nw"
  }
}

private void reloadPad(R)(R files)
  if (isInputRange!R && is(ElementType!R == ViewIndex))
{
  foreach (ViewIndex v; files) {
    
#line 609 "sf.nw"
auto i = toInt(v);
auto line = toStringz(
  "%-5d %1s %1s %-20.20s %-d".
    format(
      i,
      current == v ? ">" : " ",
      fileList.isSelected(v) ? "*" : " ",
      fileList.name(v),
      fileList.size(v)));
wmove(fileListPad.win, i, 0);
wclrtoeol(fileListPad.win);
mvwprintw(fileListPad.win, i, 0, line);

#line 638 "sf.nw"
  }
}


#line 704 "sf.nw"
  
#line 1175 "sf.nw"
void loop()
{
  
#line 1142 "sf.nw"
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

static int charToInt(in char c)
{
  assert(c.isDigit);
  return c - '0';
}

#line 1178 "sf.nw"
  
#line 885 "sf.nw"
char c;

#line 926 "sf.nw"
int n;
string s;

#line 1013 "sf.nw"
int m, beg, end;

#line 1179 "sf.nw"
  
#line 751 "sf.nw"
static struct DataStack(size_t nelems) {
  static struct DataStackElem {
    enum _Type { NODATA, NUM, STR, CH, MARK }

    _Type type;
  
    union _Data {
      int num;
      string str;
      char ch;
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
      } else static if (is(T == char)) {
        type = CH;
        ch = cast(char)data;
      } else {
        static assert(false,
	  "DataStackElem: Unsupported data type.");
      }
    }

    string toString() const {
      final switch (type) {
      case NUM:    return to!string(num);
      case STR:    return "\"" ~ to!string(str) ~ "\"";
      case CH:     return "\'" ~ ch;
      case MARK:   return to!string(num) ~ "m";
      case NODATA: assert(0);
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
      alias STypeToType = char;
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

#line 1180 "sf.nw"
  
#line 870 "sf.nw"
enum {
  START,
  READ_CH,
  READ_STR,
  READ_NUM,
  READ_COMMAND,
  QUIT
}

int state = START;


#line 1182 "sf.nw"
  while (true) {
    
#line 894 "sf.nw"
c   = cast(char)readKey();

#line 1184 "sf.nw"
    switch(state) {
      
#line 900 "sf.nw"
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

#line 1186 "sf.nw"
      
#line 930 "sf.nw"
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

#line 1187 "sf.nw"
      
#line 965 "sf.nw"
case READ_COMMAND:
  switch (c) {
    
#line 977 "sf.nw"
case 'r':
  fileList.reverse(); break;

#line 988 "sf.nw"
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

#line 1027 "sf.nw"
case 's':
  
#line 1016 "sf.nw"
m = dataStack.pop!MARK().ifNull(cur);

if (m > cur) {
  beg = cur;
  end = m + 1;
} else {
  beg = m;
  end = cur + 1;
}

#line 1029 "sf.nw"
  foreach (v; beg .. end) {
    auto v1 = ViewIndex(v);
    fileList.select(v1);
  }
  break;
case 'S':
  
#line 1016 "sf.nw"
m = dataStack.pop!MARK().ifNull(cur);

if (m > cur) {
  beg = cur;
  end = m + 1;
} else {
  beg = m;
  end = cur + 1;
}

#line 1036 "sf.nw"
  foreach (v; beg .. end) {
    auto v1 = ViewIndex(v);
    fileList.deselect(v1);
  }
  break;
case 't':
  
#line 1016 "sf.nw"
m = dataStack.pop!MARK().ifNull(cur);

if (m > cur) {
  beg = cur;
  end = m + 1;
} else {
  beg = m;
  end = cur + 1;
}

#line 1043 "sf.nw"
  foreach (v; beg .. end) {
    auto v1 = ViewIndex(v);
    if (fileList.isSelected(v1))
      fileList.deselect(v1);
    else
      fileList.select(v1);
  }
  break;

#line 1056 "sf.nw"
case 'a':
  char sortarg = dataStack.pop!CH().ifNull('n');
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

#line 1075 "sf.nw"
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

#line 1115 "sf.nw"
case 'q':
  writeFiles = true;
  goto quit;

#line 1120 "sf.nw"
default: break; // Unknown command letter.

#line 1127 "sf.nw"
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

#line 968 "sf.nw"
  }
  state = START;
  break;

default: assert(0);

#line 1188 "sf.nw"
    }
    
#line 1214 "sf.nw"
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

#line 1190 "sf.nw"
  }

quit: return;
}

#line 705 "sf.nw"
}

#line 1232 "sf.nw"
void printn(R)(R files)
{
  foreach (f; files) writeln(f);
}

void printq(R)(R files)
{
  foreach (f; files) {
    write("\""); write(f); write("\"");
    write(" ");
  }
}

void printz(R)(R files)
{
  foreach (f; files) {
    write(f);
    write("\0");
  }
}


#line 1264 "sf.nw"
void main(string[] args)
{
  enum OutputFormat {
  n, // One file per-line. Assumes no newlines in filenames.
  q, // double-quoted separated by spaces.
  z, // separated by null bytes.
  }
  OutputFormat outFormat = OutputFormat.n;
  auto helpInformation =
    getopt(args,
           "output|o", r"Output format
    n - One file per-line. Assumes there are no newlines in filenames. (default)
    q - Double-quoted, separated by spaces.
    z - Separated by null bytes.", &outFormat
    );
  if (helpInformation.helpWanted) {
    defaultGetoptPrinter(
      "sf [-o{n|q|z}] [<dir>]: Select files from <dir> or current directory.",
      helpInformation.options);
    return;
  }
  string dirpath = ".";
  if (args.length > 1) {
    dirpath = args[$ - 1];
  }
  final switch (outFormat) {
  case OutputFormat.n:
    MainUI!printn(dirpath);
    break;
  case OutputFormat.q:
    MainUI!printq(dirpath);
    break;
  case OutputFormat.z:
    MainUI!printz(dirpath);
    break;
  }
}

