unit xxmPRegXml;

interface

uses Windows, SysUtils, xxm, xxmPReg, MSXML2_TLB;

type
  TXxmProjectCacheEntry=class(TXxmProjectEntry)
  private
    FAllowInclude:boolean;
  protected
    procedure SetSignature(const Value: AnsiString); override;
    function GetExtensionMimeType(const x: AnsiString): AnsiString; override;
    function GetAllowInclude: boolean; override;
  published
    constructor Create(const Name, FilePath: WideString;
      LoadCopy, AllowInclude: boolean);
    destructor Destroy; override;
  end;

  TXxmProjectCache=class(TObject)
  private
    FLock:TRTLCriticalSection;
    FProjectsLength,FProjectsCount:integer;
    FProjects:array of record
      Name,Alias:AnsiString;
      Entry:TXxmProjectCacheEntry;
      LoadCopy,LoadCheck:boolean;
    end;
    FRegFilePath,FRegSignature,FDefaultProject,FSingleProject:AnsiString;
    FRegLastCheckTC:cardinal;
    function FindProject(const Name:WideString):integer;
    function GetRegistrySignature: AnsiString;
    function GetRegistryXML: IXMLDOMElement;
    procedure SetSignature(const Name: WideString;
      const Value: AnsiString);
  public
    constructor Create;
    destructor Destroy; override;
    procedure CheckRegistry;

    function GetProject(const Name:WideString):TXxmProjectCacheEntry;
    function DefaultProject:AnsiString;
    function SingleProject:AnsiString;
    procedure ReleaseProject(const Name:WideString);
  end;

  EXxmProjectRegistryError=class(Exception);
  EXxmFileTypeAccessDenied=class(Exception);
  EXxmProjectAliasDepth=class(Exception);

var
  XxmProjectCache:TXxmProjectCache;
  GlobalAllowLoadCopy:boolean;

implementation

uses Registry, Variants;

resourcestring
  SXxmProjectRegistryError='Could not open project registry "__"';
  SXxmFileTypeAccessDenied='Access denied to this type of file';
  SXxmProjectAliasDepth='xxm Project "__": aliasses are limited to 8 in sequence';

const
  XxmRegFileName='xxm.xml';
  XxmRegCheckIntervalMS=1000;//TODO: setting

{
function PathIsRelative(lpszPath:PWideChar):LongBool;
  stdcall; external 'shlwapi.dll' name 'PathIsRelativeW';
function PathCombine(lpszDest,lpszDir,lpszFile:PWideChar):PWideChar;
  stdcall; external 'shlwapi.dll' name 'PathRelativePathToW';
}

{ TXxmProjectCacheEntry }

constructor TXxmProjectCacheEntry.Create(const Name, FilePath: WideString;
  LoadCopy, AllowInclude: boolean);
begin
  inherited Create(LowerCase(Name));//lowercase here!
  FFilePath:=FilePath;
  FAllowInclude:=AllowInclude;
  if LoadCopy then FLoadPath:=FFilePath+'_'+IntToHex(GetCurrentProcessId,4);
end;

destructor TXxmProjectCacheEntry.Destroy;
begin
  //pointer(FProject):=nil;//strange, project modules get closed before this happens
  inherited;
end;

function TXxmProjectCacheEntry.GetExtensionMimeType(const x: AnsiString): AnsiString;
begin
  if (x='.xxl') or (x='.xxu') or (x='.exe') or (x='.dll') or (x='.xxmp') or (x='.udl') then //more? settings?
    raise EXxmFileTypeAccessDenied.Create(SXxmFileTypeAccessDenied);
  Result:=inherited GetExtensionMimeType(x);
end;

procedure TXxmProjectCacheEntry.SetSignature(const Value: AnsiString);
begin
  FSignature := Value;
  XxmProjectCache.SetSignature(Name,Value);
end;

function TXxmProjectCacheEntry.GetAllowInclude: boolean;
begin
  XxmProjectCache.CheckRegistry;
  Result:=FAllowInclude;
end;

{ TXxmProjectCache }

constructor TXxmProjectCache.Create;
var
  i:integer;
begin
  inherited;
  InitializeCriticalSection(FLock);
  //assert coinitialize called?
  FProjectsLength:=0;
  FProjectsCount:=0;
  FRegSignature:='-';
  FRegLastCheckTC:=GetTickCount-XxmRegCheckIntervalMS-1;

  SetLength(FRegFilePath,MAX_PATH);
  SetLength(FRegFilePath,GetModuleFileNameA(HInstance,PAnsiChar(FRegFilePath),MAX_PATH));
  if Copy(FRegFilePath,1,4)='\\?\' then FRegFilePath:=Copy(FRegFilePath,5,Length(FRegFilePath)-4);
  i:=Length(FRegFilePath);
  while (i<>0) and (FRegFilePath[i]<>PathDelim) do dec(i);
  FRegFilePath:=Copy(FRegFilePath,1,i);

  //settings?

  CheckRegistry;
end;

destructor TXxmProjectCache.Destroy;
var
  i:integer;
begin
  for i:=0 to FProjectsCount-1 do FreeAndNil(FProjects[i].Entry);
  SetLength(FProjects,0);
  DeleteCriticalSection(FLock);
  inherited;
end;

function TXxmProjectCache.FindProject(const Name: WideString): integer;
var
  l:AnsiString;
begin
  l:=LowerCase(Name);
  //assert cache stores ProjectName already LowerCase!
  //TODO: sorted?
  Result:=0;
  while (Result<FProjectsCount) and (FProjects[Result].Name<>l) do inc(Result);
  if Result=FProjectsCount then Result:=-1;
end;

function TXxmProjectCache.GetRegistrySignature:AnsiString;
var
  fh:THandle;
  fd:TWin32FindDataA;
begin
  //assert in FLock
  FRegLastCheckTC:=GetTickCount;
  fh:=FindFirstFileA(PAnsiChar(FRegFilePath+XxmRegFileName),fd);
  if fh=INVALID_HANDLE_VALUE then Result:='' else
   begin
    Result:=IntToHex(fd.ftLastWriteTime.dwHighDateTime,8)+
      IntToHex(fd.ftLastWriteTime.dwLowDateTime,8)+
      IntToStr(fd.nFileSizeLow);
    Windows.FindClose(fh);
   end;
end;

function TXxmProjectCache.GetRegistryXML:IXMLDOMElement;
var
  doc:DOMDocument;
begin
  //assert in FLock
  //assert CoInitialize called
  doc:=CoDOMDocument.Create;
  doc.async:=false;
  if not(doc.load(FRegFilePath+XxmRegFileName)) then
    raise EXxmProjectRegistryError.Create(StringReplace(
      SXxmProjectRegistryError,'__',FRegFilePath+XxmRegFileName,[])+#13#10+
      doc.parseError.reason);
  //assert doc.documentElement.nodeName='ProjectRegistry'
  Result:=doc.documentElement;
end;

procedure TXxmProjectCache.CheckRegistry;
var
  s:AnsiString;
  p:WideString;
  i:integer;
  xl:IXMLDOMNodeList;
  x,y:IXMLDOMElement;
begin
  if cardinal(GetTickCount-FRegLastCheckTC)>XxmRegCheckIntervalMS then
   begin
    EnterCriticalSection(FLock);
    try
      //check again for threads that were waiting for lock
      if cardinal(GetTickCount-FRegLastCheckTC)>XxmRegCheckIntervalMS then
       begin
        //signature
        s:=GetRegistrySignature;
        if FRegSignature<>s then
         begin
          FRegSignature:=s;
          for i:=0 to FProjectsCount-1 do FProjects[i].LoadCheck:=false;
          y:=GetRegistryXML;
          FDefaultProject:=VarToStr(y.getAttribute('DefaultProject'));
          if FDefaultProject='' then FDefaultProject:='xxm';
          FSingleProject:=VarToStr(y.getAttribute('SingleProject'));
          xl:=y.selectNodes('Project');
          x:=xl.nextNode as IXMLDOMElement;
          while (x<>nil) do
           begin
            s:=VarToStr(x.getAttribute('Name'));
            i:=FindProject(s);
            if (i<>-1) and (FProjects[i].LoadCheck) then i:=-1;//duplicate! raise?
            if i=-1 then
             begin
              //new
              if FProjectsCount=FProjectsLength then
               begin
                inc(FProjectsLength,8);
                SetLength(FProjects,FProjectsLength);
               end;
              i:=FProjectsCount;
              inc(FProjectsCount);
              FProjects[i].Name:=s;
              FProjects[i].Entry:=nil;//create see below
             end;
            FProjects[i].LoadCheck:=true;
            FProjects[i].Alias:=VarToStr(x.getAttribute('Alias'));
            if FProjects[i].Alias='' then
             begin
              s:=VarToStr(x.getAttribute('Name'));
              y:=x.selectSingleNode('ModulePath') as IXMLDOMElement;
              if y=nil then raise EXxmProjectNotFound.Create(StringReplace(
                SXxmProjectNotFound,'__',s,[]));

              p:=y.text;
              {
              if PathIsRelative(PWideChar(p)) then
               begin
                SetLength(p,MAX_PATH);
                PathCombine(PWideChar(p),PWideChar(WideString(FRegFilePath)),PWideChar(y.text));
                SetLength(p,Length(p));
               end;
              }
              if (Length(p)>2) and not((p[2]=':') or ((p[1]='\') and (p[2]='\'))) then
                p:=FRegFilePath+p;

              if FProjects[i].Entry=nil then
                FProjects[i].Entry:=TXxmProjectCacheEntry.Create(s,p,
                  GlobalAllowLoadCopy and (VarToStr(x.getAttribute('LoadCopy'))<>'0'),
                  VarToStr(x.getAttribute('AllowInclude'))<>'0')
              else
               begin
                if p<>FProjects[i].Entry.FFilePath then
                 begin
                  //TODO: move this into method of TXxmProjectCacheEntry?
                  FProjects[i].Entry.Release;
                  FProjects[i].Entry.FFilePath:=p;
                  if GlobalAllowLoadCopy and (VarToStr(x.getAttribute('LoadCopy'))<>'0') then
                    FProjects[i].Entry.FLoadPath:=
                      p+'_'+IntToHex(GetCurrentProcessId,4)
                  else
                    FProjects[i].Entry.FLoadPath:='';
                  FProjects[i].Entry.FAllowInclude:=
                    VarToStr(x.getAttribute('AllowInclude'))<>'0';
                 end;
               end;
              FProjects[i].Entry.FSignature:=VarToStr(x.getAttribute('Signature'));
              //TODO: extra flags,settings?

             end
            else
              FreeAndNil(FProjects[i].Entry);

            x:=xl.nextNode as IXMLDOMElement;
           end;
          //clean-up items removed from XML
          for i:=0 to FProjectsCount-1 do
            if not FProjects[i].LoadCheck then
             begin
              //TODO: collapse?
              FProjects[i].Name:='';
              FProjects[i].Alias:='';
              FreeAndNil(FProjects[i].Entry);
             end;
         end;
      end;
    finally
      LeaveCriticalSection(FLock);
    end;
   end;
end;

procedure TXxmProjectCache.SetSignature(const Name:WideString; const Value:AnsiString);
var
  xl:IXMLDOMNodeList;
  x:IXMLDOMElement;
  s:AnsiString;
begin
  CheckRegistry;//?
  EnterCriticalSection(FLock);
  try
    s:=LowerCase(Name);
    xl:=GetRegistryXML.selectNodes('Project');
    x:=xl.nextNode as IXMLDOMElement;
    while (x<>nil) and (LowerCase(VarToStr(x.getAttribute('Name')))<>s) do
      x:=xl.nextNode as IXMLDOMElement;
    if x=nil then
      raise EXxmProjectNotFound.Create(StringReplace(
        SXxmProjectNotFound,'__',Name,[]));
    x.setAttribute('Signature',Value);
    x.ownerDocument.save(XxmProjectCache.FRegFilePath+XxmRegFileName);
    FRegSignature:=GetRegistrySignature;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TXxmProjectCache.GetProject(const Name: WideString): TXxmProjectCacheEntry;
var
  i,d:integer;
  found:boolean;
begin
  Result:=nil;//counter warning;
  CheckRegistry;
  EnterCriticalSection(FLock);
  try
    found:=false;
    d:=0;
    i:=FindProject(Name);
    while (i<>-1) and not(found) do
      if FProjects[i].Alias='' then found:=true else
       begin
        inc(d);
        if d=8 then raise EXxmProjectAliasDepth.Create(StringReplace(
          SXxmProjectAliasDepth,'__',Name,[]));
        i:=FindProject(FProjects[i].Alias);
       end;
    if i=-1 then raise EXxmProjectNotFound.Create(StringReplace(
      SXxmProjectNotFound,'__',Name,[]));
    Result:=FProjects[i].Entry;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TXxmProjectCache.ReleaseProject(const Name: WideString);
var
  i:integer;
begin
  //CheckRegistry?
  EnterCriticalSection(FLock);
  try
    i:=FindProject(Name);
    //if i=-1 then raise?
    if i<>-1 then
     begin
      FProjects[i].Name:='';
      FProjects[i].Alias:='';
      FreeAndNil(FProjects[i].Entry);
     end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TXxmProjectCache.DefaultProject: AnsiString;
begin
  CheckRegistry;
  Result:=FDefaultProject;
end;

function TXxmProjectCache.SingleProject: AnsiString;
begin
  CheckRegistry;
  Result:=FSingleProject;
end;

initialization
  GlobalAllowLoadCopy:=true;//default
  //XxmProjectCache:=TXxmProjectCache.Create;//moved to project source
finalization
  XxmProjectCache.Free;

end.