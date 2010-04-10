unit xxmIsapiPReg;

interface

uses Windows, SysUtils, xxm, xxmPReg, MSXML2_TLB;

type
  TXxmProjectCacheEntry=class(TXxmProjectEntry)
  private
    FName,FFilePath:WideString;
    FProject: IXxmProject;
    FHandle:THandle;
    FContextCount:integer;
    function GetProject: IXxmProject;
  protected
    procedure SetSignature(const Value: AnsiString); override;
    function GetModulePath: WideString; override;
  published
    constructor Create(Name,FilePath:WideString);
  public
    procedure Release; override;
    destructor Destroy; override;
    procedure GetFilePath(Address:WideString;var Path,MimeType:AnsiString);
    procedure OpenContext;
    procedure CloseContext;
    property Name:WideString read FName;
    property Project: IXxmProject read GetProject;
  end;

  TXxmProjectCache=class(TObject)
  private
    ProjectCacheSize:integer;
    ProjectCache:array of TXxmProjectCacheEntry;
    FRegFilePath,FDefaultProject,FSingleProject:AnsiString;
    FRegFileLoaded:boolean;
    procedure ClearAll;
    function Grow:integer;
    function FindOpenProject(LowerCaseName:AnsiString):integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Refresh;

    function GetProject(Name:WideString):TXxmProjectCacheEntry;
    procedure ReleaseProject(Name:WideString);
    property DefaultProject:AnsiString read FDefaultProject;
    property SingleProject:AnsiString read FSingleProject;
  end;

  TXxmAutoBuildHandler=function(pce:TXxmProjectCacheEntry;
    Context: IXxmContext; ProjectName:WideString):boolean;

  EXxmProjectRegistryError=class(Exception);
  EXxmProjectNotFound=class(Exception);
  EXxmModuleNotFound=class(Exception);
  EXxmProjectLoadFailed=class(Exception);
  EXxmFileTypeAccessDenied=class(Exception);
  EXxmProjectAliasDepth=class(Exception);

var
  XxmProjectCache:TXxmProjectCache;

implementation

uses Registry, Variants;

resourcestring
  SXxmProjectRegistryError='Could not open project registry "__"';
  SXxmProjectNotFound='xxm Project "__" not defined.';
  SXxmModuleNotFound='xxm Module "__" does not exist.';
  SXxmProjectLoadFailed='xxm Project load "__" failed.';
  SXxmFileTypeAccessDenied='Access denied to this type of file';
  SXxmProjectAliasDepth='xxm Project "__": aliasses are limited to 8 in sequence';

{ TXxmProjectCacheEntry }

constructor TXxmProjectCacheEntry.Create(Name, FilePath: WideString);
begin
  inherited Create;
  FName:=LowerCase(Name);//lowercase here!
  FFilePath:=FilePath;
  FProject:=nil;
  FHandle:=0;
  FContextCount:=0;
  LastCheck:=GetTickCount-100000;
end;

procedure TXxmProjectCacheEntry.Release;
begin
  //attention for deadlocks! use OpenContext/CloseContext
  //XxmAutoBuildHandler is supposed to lock any new requests
  while not(FContextCount=0) do Sleep(1);

  //finalization gets called on last-loaded libraries first,
  //so FProject release may fail on finalization
  try
    FProject:=nil;
  except
    pointer(FProject):=nil;
  end;
  if not(FHandle=0) then
   begin
    FreeLibrary(FHandle);
    FHandle:=0;
   end;
end;

destructor TXxmProjectCacheEntry.Destroy;
begin
  pointer(FProject):=nil;//strange, project modules get closed before this happens
  Release;
  inherited;
end;

procedure TXxmProjectCacheEntry.GetFilePath(Address:WideString;
  var Path, MimeType: AnsiString);
var
  rf,sf,s:AnsiString;
  i,j,l:integer;
  r:TRegistry;
begin
  //TODO: widestring all the way?

  //TODO: virtual directories?
  rf:=FFilePath;
  i:=Length(rf);
  while not(i=0) and not(rf[i]=PathDelim) do dec(i);
  SetLength(rf,i);
  sf:='';

  i:=1;
  l:=Length(Address);
  while (i<=l) do
   begin

    j:=i;
    while (j<=l) and not(char(Address[j]) in ['/','\']) do inc(j);
    s:=Copy(Address,i,j-i);
    i:=j+1;

    if (s='') or (s='.') then
     begin
      //nothing
     end
    else
    if (s='..') then
     begin
      //try to go back, but not into rf (raise?)
      j:=Length(sf)-1;
      while (j>0) and not(sf[j]=PathDelim) do dec(j);
      SetLength(sf,j);
     end
    else
     begin
      sf:=sf+s+PathDelim;
      //DirectoryExists()??
     end;

   end;

  Path:=rf+Copy(sf,1,Length(sf)-1);

  i:=Length(sf)-1;
  while (i>0) and not(sf[i]='.') do dec(i);
  sf:=LowerCase(copy(sf,i,Length(sf)-i));

  if (sf='.xxl') or (sf='.exe') or (sf='.dll') or (sf='.xxmp') then //more? settings?
    raise EXxmFileTypeAccessDenied.Create(SXxmFileTypeAccessDenied);

  r:=TRegistry.Create;
  try
    r.RootKey:=HKEY_CLASSES_ROOT;
    if r.OpenKeyReadOnly(sf) and r.ValueExists('Content Type') then
      MimeType:=r.ReadString('Content Type');
    if MimeType='' then MimeType:='application/octet-stream';
  finally
    r.Free;
  end;

end;

function TXxmProjectCacheEntry.GetProject: IXxmProject;
var
  lp:TXxmProjectLoadProc;
begin
  if FProject=nil then
   begin
    if not(FileExists(FFilePath)) then
      raise EXxmModuleNotFound.Create(StringReplace(
        SXxmModuleNotFound,'__',FFilePath,[]));
    FHandle:=LoadLibraryW(PWideChar(FFilePath));
    if FHandle=0 then RaiseLastOSError;
    @lp:=GetProcAddress(FHandle,'XxmProjectLoad');
    if @lp=nil then RaiseLastOSError;
    FProject:=lp(Name);//try?
    if FProject=nil then
     begin
      FFilePath:='';//force refresh next time
      raise EXxmProjectLoadFailed.Create(StringReplace(
        SXxmProjectLoadFailed,'__',FFilePath,[]));
     end;
   end;
  Result:=FProject;
end;

procedure TXxmProjectCacheEntry.SetSignature(const Value: AnsiString);
var
  doc:DOMDocument;
  x:IXMLDOMElement;
begin
  FSignature := Value;
  doc:=CoDOMDocument.Create;
  try
    doc.async:=false;
    if not(doc.load(XxmProjectCache.FRegFilePath)) then
      raise EXxmProjectRegistryError.Create(StringReplace(
        SXxmProjectRegistryError,'__',XxmProjectCache.FRegFilePath,[])+#13#10+
        doc.parseError.reason);
    x:=doc.documentElement.selectSingleNode(
      'Project[@Name="'+FName+'"]') as IXMLDOMElement;
    if x=nil then
      raise EXxmProjectNotFound.Create(StringReplace(
        SXxmProjectNotFound,'__',FName,[]));
    x.setAttribute('Signature',FSignature);
    doc.save(XxmProjectCache.FRegFilePath);
    //force XxmProjectCache.Refresh?
  finally
    x:=nil;
    doc:=nil;
  end;
end;

procedure TXxmProjectCacheEntry.OpenContext;
begin
  InterlockedIncrement(FContextCount);
end;

procedure TXxmProjectCacheEntry.CloseContext;
begin
  InterlockedDecrement(FContextCount);
end;

function TXxmProjectCacheEntry.GetModulePath: WideString;
begin
  Result:=FFilePath;
end;

{ TXxmProjectCache }

constructor TXxmProjectCache.Create;
var
  i:integer;
begin
  inherited;
  ProjectCacheSize:=0;
  FDefaultProject:='xxm';
  FSingleProject:='';

  SetLength(FRegFilePath,$400);
  SetLength(FRegFilePath,GetModuleFileNameA(HInstance,PAnsiChar(FRegFilePath),$400));
  if Copy(FRegFilePath,1,4)='\\?\' then FRegFilePath:=Copy(FRegFilePath,5,Length(FRegFilePath)-4);
  i:=Length(FRegFilePath);
  while not(i=0) and not(FRegFilePath[i]=PathDelim) do dec(i);
  FRegFilePath:=Copy(FRegFilePath,1,i)+'xxm.xml';
  FRegFileLoaded:=false;

  //settings?
end;

destructor TXxmProjectCache.Destroy;
begin
  ClearAll;
  inherited;
end;

function TXxmProjectCache.Grow: integer;
var
  i:integer;
begin
  i:=ProjectCacheSize;
  Result:=i;
  inc(ProjectCacheSize,16);//const growstep
  SetLength(ProjectCache,ProjectCacheSize);
  while (i<ProjectCacheSize) do
   begin
    ProjectCache[i]:=nil;
    inc(i);
   end;
end;

function TXxmProjectCache.FindOpenProject(LowerCaseName: AnsiString): integer;
begin
  Result:=0;
  //assert cache stores ProjectName already LowerCase!
  while (Result<ProjectCacheSize) and (
    (ProjectCache[Result]=nil) or not(ProjectCache[Result].Name=LowerCaseName)) do inc(Result);
  if Result=ProjectCacheSize then Result:=-1;
end;

procedure TXxmProjectCache.Refresh;
var
  doc:DOMDocument;
begin
  if not(FRegFileLoaded) then
   begin
    doc:=CoDOMDocument.Create;
    try
      doc.async:=false;
      if not(doc.load(FRegFilePath)) then
        raise EXxmProjectRegistryError.Create(StringReplace(
          SXxmProjectRegistryError,'__',FRegFilePath,[])+#13#10+
          doc.parseError.reason);
      FSingleProject:=VarToStr(doc.documentElement.getAttribute('SingleProject'));
      FDefaultProject:=VarToStr(doc.documentElement.getAttribute('DefaultProject'));
      if FDefaultProject='' then FDefaultProject:='xxm';
    finally
      doc:=nil;
    end;
    FRegFileLoaded:=true;
   end;
end;

function TXxmProjectCache.GetProject(Name: WideString): TXxmProjectCacheEntry;
var
  i,d:integer;
  n:AnsiString;
  found:boolean;
  doc:DOMDocument;
  xl:IXMLDOMNodeList;
  x,y:IXMLDOMElement;
begin
  Result:=nil;//counter warning
  n:=LowerCase(Name);
  i:=FindOpenProject(n);
  if i=-1 then
   begin
    //assert CoInitialize called
    doc:=CoDOMDocument.Create;
    try
      doc.async:=false;
      if not(doc.load(FRegFilePath)) then
       begin
        FRegFileLoaded:=false;
        raise EXxmProjectRegistryError.Create(StringReplace(
          SXxmProjectRegistryError,'__',FRegFilePath,[])+#13#10+
          doc.parseError.reason);
       end;
      //assert documentElement.nodeName='ProjectRegistry'
      FSingleProject:=VarToStr(doc.documentElement.getAttribute('SingleProject'));
      //TODO: if changed then update? raise?
      FDefaultProject:=VarToStr(doc.documentElement.getAttribute('DefaultProject'));
      if FDefaultProject='' then FDefaultProject:='xxm';
      d:=0;
      found:=false;
      while not(found) do
       begin
        //TODO: selectSingleNode case-insensitive?
        xl:=doc.documentElement.selectNodes('Project');
        x:=xl.nextNode as IXMLDOMElement;
        while not(found) and not(x=nil) do
          if LowerCase(VarToStr(x.getAttribute('Name')))=n then
            found:=true
          else
            x:=xl.nextNode as IXMLDOMElement;
        if found then
         begin
          n:=LowerCase(VarToStr(x.getAttribute('Alias')));
          if not(n='') then
           begin
            inc(d);
            if d=8 then raise EXxmProjectAliasDepth.Create(StringReplace(
              SXxmProjectAliasDepth,'__',Name,[]));
            found:=false;
           end;
         end
        else
         begin
          raise EXxmProjectNotFound.Create(StringReplace(
            SXxmProjectNotFound,'__',Name,[]));
         end;
       end;
      y:=x.selectSingleNode('ModulePath') as IXMLDOMElement;
      if y=nil then n:='' else n:=y.text;
      Result:=TXxmProjectCacheEntry.Create(Name,n);
      Result.FSignature:=LowerCase(VarToStr(x.getAttribute('Signature')));
    finally
      y:=nil;
      x:=nil;
      xl:=nil;
      doc:=nil;
    end;
    i:=0;
    while (i<ProjectCacheSize) and not(ProjectCache[i]=nil) do inc(i);
    if (i=ProjectCacheSize) then i:=Grow;
    ProjectCache[i]:=Result;
   end
  else
    Result:=ProjectCache[i];
end;

procedure TXxmProjectCache.ReleaseProject(Name: WideString);
var
  i:integer;
begin
  i:=FindOpenProject(LowerCase(Name));
  //if i=-1 then raise?
  if not(i=-1) then FreeAndNil(ProjectCache[i]);
end;

procedure TXxmProjectCache.ClearAll;
var
  i:integer;
begin
  for i:=0 to ProjectCacheSize-1 do FreeAndNil(ProjectCache[i]);
  SetLength(ProjectCache,0);
  ProjectCacheSize:=0;
end;

initialization
  XxmProjectCache:=TXxmProjectCache.Create;
finalization
  XxmProjectCache.Free;

end.
