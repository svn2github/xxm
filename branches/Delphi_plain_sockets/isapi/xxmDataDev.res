        ��  ��                  4  (   �� B F A I L       0           <html><head><title>Build failed: [[ProjectName]]</title></head>
<body style="font-family:sans-serif;background-color:white;color:black;margin:0em;">
<h1 style="background-color:#0000CC;color:white;margin:0em;padding:0.2em;">Build failed: [[ProjectName]]</h1>
<xmp style="margin:0.1em;">[[Log]]</xmp>
<p style="background-color:#0000CC;color:white;font-size:0.8em;margin:0em;padding:0.2em;text-align:right;">
<a href="[[URL]]" style="float:left;color:white;">refresh</a>
<a href="http://yoy.be/xxm/" style="color:white;">xxm</a> [[DateTime]]</p></body></html>T  ,   �� B E R R O R         0           <html><head><title>Error building: [[ProjectName]]</title></head>
<body style="font-family:sans-serif;background-color:white;color:black;margin:0em;">
<h1 style="background-color:#0000CC;color:white;margin:0em;padding:0.2em;">Error building: [[ProjectName]]</h1>
<p style="margin:0.1em;">An error occurred while building the module.<br />
<i>[[ErrorClass]]</i><br /><b>[[ErrorMessage]]</b></p>
<p style="background-color:#0000CC;color:white;font-size:0.8em;margin:0em;padding:0.2em;text-align:right;">
<a href="http://yoy.be/xxm/" style="color:white;">xxm</a> [[DateTime]]</p></body></html>�(  $   ���X X M       0           unit xxm;

interface

uses SysUtils, Classes;

const
  //$Date: 2008-03-11 23:44:29 +0100 (di, 11 mrt 2008) $
  XxmRevision='$Rev: 201 $';
  
type
  IXxmContext=interface;//forward
  IXxmFragment=interface; //forward

  IXxmProject=interface
    ['{78786D00-0000-0002-C000-000000000002}']
    function GetProjectName: WideString;
    property Name:WideString read GetProjectName;
    function LoadPage(Context:IXxmContext;Address:WideString):IXxmFragment;
    function LoadFragment(Address:WideString):IXxmFragment;
    procedure UnloadFragment(Fragment: IXxmFragment);
  end;

  TXxmProjectLoadProc=function(AProjectName:WideString): IXxmProject; stdcall;

  TXxmContextString=(
    csVersion,
    csExtraInfo,
    csVerb,
    csQueryString,
    csUserAgent,
    csAcceptedMimeTypes,
    csPostMimeType,
    csURL,
    csReferer,
    csLanguage,
    csRemoteAddress,
    csRemoteHost,
    csAuthUser,
    csAuthPassword
  );

  TXxmVersion=record
    Major,Minor,Release,Build:integer;
  end;

  TXxmAutoEncoding=(
    aeContentDefined, //content will specify which content to use
    aeUtf8,           //send UTF-8 byte order mark
    aeUtf16,          //send UTF-16 byte order mark
    aeIso8859         //send using the closest new thing to ASCII
  );

  IXxmParameter=interface
    ['{78786D00-0000-0007-C000-000000000007}']
    function GetName:WideString;
    function GetValue:WideString;
    property Name:WideString read GetName;
    property Value:WideString read GetValue;
    function AsInteger:integer;
    function NextBySameName:IXxmParameter;
  end;

  IXxmParameterGet=interface(IXxmParameter)
    ['{78786D00-0000-0008-C000-000000000008}']
  end;

  IxxmParameterPost=interface(IXxmParameter)
    ['{78786D00-0000-0009-C000-000000000009}']
  end;

  IxxmParameterPostFile=interface(IxxmParameterPost)
    ['{78786D00-0000-000A-C000-00000000000A}']
    function GetSize:integer;
    function GetMimeType:WideString;
    property Size:integer read GetSize;
    property MimeType:WideString read GetMimeType;
    procedure SaveToFile(FilePath:string);//TODO: WideString
    function SaveToStream(Stream:TStream):integer;//TODO: IStream
  end;

  IXxmContext=interface
    ['{78786D00-0000-0003-C000-000000000003}']

    function GetURL:WideString;
    function GetPage:IXxmFragment;
    function GetContentType:WideString;
    procedure SetContentType(const Value: WideString);
    function GetAutoEncoding:TXxmAutoEncoding;
    procedure SetAutoEncoding(const Value: TXxmAutoEncoding);
    function GetParameter(Key:OleVariant):IXxmParameter;
    function GetParameterCount:integer;
    function GetSessionID:WideString;

    procedure Send(Data: OleVariant);
    procedure SendHTML(Data: OleVariant);
    procedure SendFile(FilePath: WideString);
    procedure SendStream(s:TStream); //TODO: IStream
    procedure Include(Address: WideString); overload;
    procedure Include(Address: WideString;
      const Values: array of OleVariant); overload;
    procedure Include(Address: WideString;
      const Values: array of OleVariant;
      const Objects: array of TObject); overload;
    procedure DispositionAttach(FileName: WideString);

    function ContextString(cs:TXxmContextString):WideString;
    function PostData:TStream; //TODO: IStream
    function Connected:boolean;

    //(local:)progress
    procedure SetStatus(Code:integer;Text:WideString);
    procedure Redirect(RedirectURL:WideString; Relative:boolean);
    function GetCookie(Name:WideString):WideString;
    procedure SetCookie(Name,Value:WideString); overload;
    procedure SetCookie(Name,Value:WideString; KeepSeconds:cardinal;
      Comment,Domain,Path:WideString; Secure,HttpOnly:boolean); overload;
    //procedure SetCookie2();

    //TODO: pointer to project?

    property URL:WideString read GetURL;
    property ContentType:WideString read GetContentType write SetContentType;
    property AutoEncoding:TXxmAutoEncoding read GetAutoEncoding write SetAutoEncoding;
    property Page:IXxmFragment read GetPage;
    property Parameter[Key:OleVariant]:IXxmParameter read GetParameter; default;
    property ParameterCount:integer read GetParameterCount;
    property SessionID:WideString read GetSessionID;
    property Cookie[Name:WideString]:WideString read GetCookie;
  end;

  IXxmFragment=interface
    ['{78786D00-0000-0004-C000-000000000004}']
    function GetProject: IXxmProject;
    property Project:IXxmProject read GetProject;
    function ClassNameEx: WideString;
    procedure Build(const Context:IXxmContext; const Caller:IXxmFragment;
      const Values: array of OleVariant;
      const Objects: array of TObject);
  end;

  IXxmPage=interface(IXxmFragment)
    ['{78786D00-0000-0005-C000-000000000005}']
  end;

  IXxmInclude=interface(IXxmFragment)
    ['{78786D00-0000-0006-C000-000000000006}']
  end;

const
  IID_IXxmProject: TGUID = '{78786D00-0000-0002-C000-000000000002}';
  IID_IXxmContext: TGUID = '{78786D00-0000-0003-C000-000000000003}';
  IID_IXxmFragment: TGUID = '{78786D00-0000-0004-C000-000000000004}';
  IID_IXxmPage: TGUID = '{78786D00-0000-0005-C000-000000000005}';
  IID_IXxmInclude: TGUID = '{78786D00-0000-0006-C000-000000000006}';
  IID_IXxmParameter: TGUID = '{78786D00-0000-0007-C000-000000000007}';
  IID_IXxmParameterGet: TGUID = '{78786D00-0000-0008-C000-000000000008}';
  IID_IXxmParameterPost: TGUID = '{78786D00-0000-0009-C000-000000000009}';
  IID_IXxmParameterPostFile: TGUID = '{78786D00-0000-000A-C000-00000000000A}';

type
  TXxmProject=class(TInterfacedObject, IXxmProject)//abstract
  private
    FProjectName: WideString;
    function GetProjectName: WideString;
  public
    constructor Create(AProjectName: WideString);
    destructor Destroy; override;
    function LoadPage(Context: IXxmContext; Address: WideString): IXxmFragment; virtual; abstract;
    function LoadFragment(Address: WideString): IXxmFragment; virtual; abstract;
    procedure UnloadFragment(Fragment: IXxmFragment); virtual; abstract;
    property Name:WideString read GetProjectName;
  end;

  TXxmFragment=class(TInterfacedObject, IXxmFragment)//abstract
  private
    FProject: TXxmProject;
    function GetProject: IXxmProject;
  public
    constructor Create(AProject: TXxmProject);
    destructor Destroy; override;
    function ClassNameEx: WideString; virtual;
    procedure Build(const Context: IXxmContext; const Caller: IXxmFragment;
      const Values: array of OleVariant;
      const Objects: array of TObject); virtual; abstract;
    property Project:IXxmProject read GetProject;
  end;

  TXxmPage=class(TXxmFragment, IXxmPage)
  end;

  TXxmInclude=class(TXxmFragment, IXxmInclude)
  end;


function XxmVersion:TXxmVersion;
function HTMLEncode(Data:WideString):WideString; overload;
function HTMLEncode(Data:OleVariant):WideString; overload;
function URLEncode(Data:OleVariant):string;
function URLDecode(Data:string):WideString;

implementation

uses Variants;

{ Helper Functions }

function HTMLEncode(Data:OleVariant):WideString;
begin
  if VarIsNull(Data) then Result:='' else Result:=HTMLEncode(VarToWideStr(Data));
end;

function HTMLEncode(Data:WideString):WideString;
begin
  if Data='' then Result:='' else
    Result:=
      UTF8Decode(
      StringReplace(
      StringReplace(
      StringReplace(
      StringReplace(
      StringReplace(
      UTF8Encode(
        Data),
        '&','&amp;',[rfReplaceAll]),
        '<','&lt;',[rfReplaceAll]),
        '>','&gt;',[rfReplaceAll]),
        '"','&quot;',[rfReplaceAll]),
        #13#10,'<br />'#13#10,[rfReplaceAll])
      );
end;

const
  Hex: array[0..15] of char='0123456789ABCDEF';

function URLEncode(Data:OleVariant):string;
var
  s,t:string;
  p,q,l:integer;
begin
  if VarIsNull(Data) then Result:='' else
   begin
    s:=UTF8Encode(VarToWideStr(Data));
    q:=1;
    l:=Length(s)+$80;
    SetLength(t,l);
    for p:=1 to Length(s) do
     begin
      if q+4>l then
       begin
        inc(l,$80);
        SetLength(t,l);
       end;
      case s[p] of
        #0..#31,'"','#','$','%','&','''','+','/','<','>','?','@','[','\',']','^','`','{','|','}','�':
         begin
          t[q]:='%';
          t[q+1]:=Hex[byte(s[p]) shr 4];
          t[q+2]:=Hex[byte(s[p]) and $F];
          inc(q,2);
         end;
        ' ':
          t[q]:='+';
        else
          t[q]:=s[p];
      end;
      inc(q);
     end;
    SetLength(t,q-1);
    Result:=t;
   end;
end;

function URLDecode(Data:string):WideString;
var
  t:string;
  p,q,l:integer;
  b:byte;
begin
  l:=Length(Data);
  SetLength(t,l);
  q:=1;
  p:=1;
  while (p<=l) do
   begin
    case Data[p] of
      '+':t[q]:=' ';
      '%':
       begin
        inc(p);
        b:=0;
        case Data[p] of
          '0'..'9':inc(b,byte(Data[p]) and $F);
          'A'..'F','a'..'f':inc(b,(byte(Data[p]) and $F)+9);
        end;
        inc(p);
        b:=b shl 4;
        case Data[p] of
          '0'..'9':inc(b,byte(Data[p]) and $F);
          'A'..'F','a'..'f':inc(b,(byte(Data[p]) and $F)+9);
        end;
        t[q]:=char(b);
       end
      else
        t[q]:=Data[p];
    end;
    inc(p);
    inc(q);
   end;
  SetLength(t,q-1);
  Result:=UTF8Decode(t);
  if not(q=0) and (Result='') then Result:=t;
end;

function XxmVersion: TXxmVersion;
var
  s:string;
begin
  s:=XxmRevision;
  Result.Major:=1;
  Result.Minor:=0;
  Result.Release:=0;
  Result.Build:=StrToInt(Copy(s,7,Length(s)-8));
end;

{ TXxpProject }

constructor TXxmProject.Create(AProjectName: WideString);
begin
  inherited Create;
  FProjectName:=AProjectName;
end;

destructor TXxmProject.Destroy;
begin
  inherited;
end;

function TXxmProject.GetProjectName: WideString;
begin
  Result:=FProjectName;
end;

{ TXxmFragment }

constructor TXxmFragment.Create(AProject: TXxmProject);
begin
  inherited Create;
  FProject:=AProject;
end;

function TXxmFragment.GetProject: IXxmProject;
begin
  Result:=FProject;
end;

function TXxmFragment.ClassNameEx: WideString;
begin
  Result:=ClassName;
end;

destructor TXxmFragment.Destroy;
begin
  inherited;
end;

initialization
  IsMultiThread:=true;
end.
   p  ,   ���X X M F R E G       0           unit xxmFReg;

interface

uses xxm, Classes;

//$Rev: 198 $
//$Date: 2008-01-21 22:52:37 +0100 (ma, 21 jan 2008) $

type
  TXxmFragmentClass=class of TXxmFragment;

  TXxmFragmentRegistry=class(TObject)
  private
    Registry:TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterClass(FName:string;FType:TXxmFragmentClass);
    function GetClass(FName:string):TXxmFragmentClass;
  end;

var
  XxmFragmentRegistry:TXxmFragmentRegistry;

const
  XXmDefaultPage:string='default.xxm';

implementation

uses SysUtils, Registry;

{ TXxmFragmentRegistry }

constructor TXxmFragmentRegistry.Create;
begin
  inherited Create;
  Registry:=TStringList.Create;
  Registry.Sorted:=true;
  Registry.Duplicates:=dupIgnore;//dupError?setting?
  Registry.CaseSensitive:=false;//setting?
end;

destructor TXxmFragmentRegistry.Destroy;
begin
  //Registry.Clear;//?
  Registry.Free;
  inherited;
end;

procedure TXxmFragmentRegistry.RegisterClass(FName: string;
  FType: TXxmFragmentClass);
begin
  Registry.AddObject(FName,TObject(FType));
end;

function TXxmFragmentRegistry.GetClass(FName: string): TXxmFragmentClass;
var
  i:integer;
begin
  i:=Registry.IndexOf(FName);
  if i=-1 then
    if (FName='') or (FName[Length(FName)]='/') then 
	  i:=Registry.IndexOf(FName+XxmDefaultPage)
	else
	  i:=Registry.IndexOf(FName+'/'+XxmDefaultPage);
  if i=-1 then Result:=nil else Result:=TXxmFragmentClass(Registry.Objects[i]);
end;

initialization
  XxmFragmentRegistry:=TXxmFragmentRegistry.Create;
finalization
  XxmFragmentRegistry.Free;

end.
  4   ���X X M S E S S I O N         0           unit xxmSession;

interface

uses Contnrs;

type
  TXxmSession=class(TObject)
  private
    FSessionID:WideString;
  public
    constructor Create(SessionID:WideString);
    property SessionID:WideString read FSessionID;
  end;

procedure SetSession(SessionID: WideString);
procedure AbandonSession;

threadvar
  Session: TXxmSession;

implementation

uses SysUtils;

//TODO: something better than plain objectlist
var
  SessionStore:TObjectList;

procedure SetSession(SessionID: WideString);
var
  i:integer;
begin
  if SessionStore=nil then SessionStore:=TObjectList.Create(true);
  i:=0;
  while (i<SessionStore.Count) and not(TXxmSession(SessionStore[i]).SessionID=SessionID) do inc(i);
  //TODO: session expiry!!!
  if (i<SessionStore.Count) then Session:=TXxmSession(SessionStore[i]) else
   begin
    Session:=TXxmSession.Create(SessionID);
    SessionStore.Add(Session);
   end;
end;

procedure AbandonSession;
begin
  SessionStore.Remove(Session);
  Session:=nil;
end;

{ TxxmSession }

constructor TXxmSession.Create(SessionID: WideString);
begin
  inherited Create;
  FSessionID:=SessionID;
  //TODO: initiate expiry
end;

initialization
  SessionStore:=nil;
finalization
  FreeAndNil(SessionStore);

end.
  \  0   ���X X M S T R I N G       0           unit xxmString;

interface

uses
  SysUtils, Classes, xxm;

const
  XxmMaxIncludeDepth=64;//TODO: setting?

type
  TStringContext=class(TInterfacedObject, IXxmContext)
  private
    FContext:IXxmContext;
    FBuilding:IXxmFragment;
    FIncludeDepth:integer;
    FOutput:TStringStream;
    function GetResult:string;
  protected
    function Connected: Boolean;
    function ContextString(cs: TXxmContextString): WideString;
    procedure DispositionAttach(FileName: WideString);
    function GetAutoEncoding: TXxmAutoEncoding;
    function GetContentType: WideString;
    function GetCookie(Name: WideString): WideString;
    function GetPage: IXxmFragment;
    function GetParameter(Key: OleVariant): IXxmParameter;
    function GetParameterCount: Integer;
    function GetSessionID: WideString;
    function GetURL: WideString;
    function PostData: TStream;
    procedure Redirect(RedirectURL: WideString; Relative: Boolean);
    procedure SetAutoEncoding(const Value: TXxmAutoEncoding);
    procedure SetContentType(const Value: WideString);
    procedure SetCookie(Name,Value:WideString); overload;
    procedure SetCookie(Name,Value:WideString; KeepSeconds:cardinal;
      Comment,Domain,Path:WideString; Secure,HttpOnly:boolean); overload;
    procedure SetStatus(Code: Integer; Text: WideString);
  public
    constructor Create(AContext: IXxmContext; ACaller: IXxmFragment);
    destructor Destroy; override;
    procedure Send(Data: OleVariant);
    procedure SendFile(FilePath: WideString);
    procedure SendHTML(Data: OleVariant);
    procedure SendStream(s: TStream);
    procedure Include(Address: WideString); overload;
    procedure Include(Address: WideString;
      const Values: array of OleVariant); overload;
    procedure Include(Address: WideString;
      const Values: array of OleVariant;
      const Objects: array of TObject); overload;
  	procedure Reset;

    property Result:string read GetResult;
    procedure SaveToFile(FileName:string);
  end;

  EXxmUnsupported=class(Exception);
  EXxmIncludeFragmentNotFound=class(Exception);
  EXxmIncludeStackFull=class(Exception);

implementation

uses
  Variants;

resourcestring
  SXxmIncludeFragmentNotFound='Include fragment not found "__"';
  SXxmIncludeStackFull='Maximum level of includes exceeded';

{ TStringContext }

constructor TStringContext.Create(AContext: IXxmContext; ACaller: IXxmFragment);
begin
  inherited Create;
  FContext:=AContext;
  FBuilding:=ACaller;
  FIncludeDepth:=0;
  FOutput:=TStringStream.Create('');
end;

destructor TStringContext.Destroy;
begin
  FContext:=nil;
  FBuilding:=nil;
  FOutput.Free;
  inherited;
end;

function TStringContext.Connected: Boolean;
begin
  Result:=FContext.Connected;
end;

function TStringContext.ContextString(cs: TXxmContextString): WideString;
begin
  Result:=FContext.ContextString(cs);
end;

function TStringContext.GetAutoEncoding: TXxmAutoEncoding;
begin
  Result:=FContext.AutoEncoding;
end;

function TStringContext.GetContentType: WideString;
begin
  Result:=FContext.ContentType;
end;

function TStringContext.GetCookie(Name: WideString): WideString;
begin
  Result:=FContext.Cookie[Name];
end;

function TStringContext.GetPage: IXxmFragment;
begin
  Result:=FContext.Page;
end;

function TStringContext.GetParameter(Key: OleVariant): IXxmParameter;
begin
  Result:=FContext.Parameter[Key];
end;

function TStringContext.GetParameterCount: Integer;
begin
  Result:=FContext.ParameterCount;
end;

function TStringContext.GetSessionID: WideString;
begin
  Result:=FContext.SessionID;
end;

function TStringContext.GetURL: WideString;
begin
  Result:=FContext.URL;
end;

function TStringContext.PostData: TStream;
begin
  Result:=FContext.PostData;
end;

procedure TStringContext.DispositionAttach(FileName: WideString);
begin
  raise EXxmUnsupported.Create('StringContext doesn''t support DispositionAttach');
end;

procedure TStringContext.Redirect(RedirectURL: WideString;
  Relative: Boolean);
begin
  raise EXxmUnsupported.Create('StringContext doesn''t support Redirect');
end;

procedure TStringContext.SetAutoEncoding(const Value: TXxmAutoEncoding);
begin
  raise EXxmUnsupported.Create('StringContext doesn''t support AutoEncoding');
end;

procedure TStringContext.SetContentType(const Value: WideString);
begin
  raise EXxmUnsupported.Create('StringContext doesn''t support ContentType');
end;

procedure TStringContext.SetStatus(Code: Integer; Text: WideString);
begin
  raise EXxmUnsupported.Create('StringContext doesn''t support Status');
end;

procedure TStringContext.Include(Address: WideString);
begin
  Include(Address, [], []);
end;

procedure TStringContext.Include(Address: WideString;
  const Values: array of OleVariant);
begin
  Include(Address, Values, []);
end;

procedure TStringContext.Include(Address: WideString;
  const Values: array of OleVariant;
  const Objects: array of TObject);
var
  p:IXxmProject;
  f,fb:IXxmFragment;
begin
  if FIncludeDepth=XxmMaxIncludeDepth then
    raise EXxmIncludeStackFull.Create(SXxmIncludeStackFull);
  p:=FContext.Page.Project;
  try
    f:=p.LoadFragment(Address);
    if f=nil then
      raise EXxmIncludeFragmentNotFound.Create(StringReplace(
        SXxmIncludeFragmentNotFound,'__',Address,[]));
    fb:=FBuilding;
    FBuilding:=f;
    inc(FIncludeDepth);
    try
      //TODO: catch exceptions?
      f.Build(Self,fb,Values,Objects);
    finally
      dec(FIncludeDepth);
      FBuilding:=fb;
      fb:=nil;
      p.UnloadFragment(f);
      f:=nil;
    end;
  finally
    p:=nil;
  end;
end;

procedure TStringContext.Send(Data: OleVariant);
begin
  FOutput.WriteString(HTMLEncode(VarToStr(Data)));
end;

procedure TStringContext.SendFile(FilePath: WideString);
var
  f:TFileStream;
begin
  f:=TFileStream.Create(FilePath, fmOpenRead or fmShareDenyNone);
  try
    SendStream(f);
  finally
    Free;
  end;
end;

procedure TStringContext.SendHTML(Data: OleVariant);
begin
  FOutput.WriteString(VarToStr(Data));
end;

procedure TStringContext.SendStream(s: TStream);
const
  BufferSize=$10000;
var
  d:array[0..BufferSize-1] of byte;
  i:integer;
begin
  //FOutput.CopyFrom(s,s.Size);
  repeat
    i:=s.Read(d[0],BufferSize);
    if not(i=0) then FOutput.Write(d[0],i);
  until not(i=BufferSize);
end;

procedure TStringContext.SetCookie(Name, Value: WideString);
begin
  FContext.SetCookie(Name, Value);
end;

procedure TStringContext.SetCookie(Name, Value: WideString;
  KeepSeconds: cardinal; Comment, Domain, Path: WideString; Secure,
  HttpOnly: boolean);
begin
  FContext.SetCookie(Name, Value, KeepSeconds, Comment, Domain, Path,
    Secure, HttpOnly);
end;

function TStringContext.GetResult: string;
begin
  Result:=FOutput.DataString;
end;

procedure TStringContext.Reset;
begin
  FOutput.Size:=0;
end;

procedure TStringContext.SaveToFile(FileName: string);
var
  f:TFileStream;
begin
  f:=TFileStream.Create(FileName,fmCreate);
  try
    f.Write(FOutput.DataString[1],Length(FOutput.DataString));
  finally
    f.Free;
  end;
end;

end.
�  8   ���W E B _ D P R _ P R O T O       0           library [[ProjectName]];

{
  --- ATTENTION! ---

  This file is re-constructed when the xxm source file changes.
  Any changes to this file will be overwritten.
  If you require changes to this file that can not be defined
  in the xxm source file, set up an alternate prototype-file.

  Prototype-file used:
  "[[ProtoFile]]"
  $Rev: 198 $ $Date: 2008-01-21 22:52:37 +0100 (ma, 21 jan 2008) $
}

uses
	[[@Include]][[IncludeUnit]] in '..\[[IncludePath]][[IncludeUnit]].pas',
	[[@]][[@Fragment]][[FragmentUnit]] in '[[FragmentPath]][[FragmentUnit]].pas', {[[FragmentAddress]]}
	[[@]][[UsesClause]]
	xxmp in '..\xxmp.pas';

{$E xxl}
[[ProjectHeader]]
exports
	XxmProjectLoad;
[[ProjectBody]]
end.
 [  <   ���X X M P _ P A S _ P R O T O         0           unit xxmp;

{
  $Rev: 204 $ $Date: 2008-04-08 21:39:14 +0200 (di, 08 apr 2008) $
}

interface

uses xxm;

type
  TXxm[[ProjectName]]=class(TXxmProject)
  public
    function LoadPage(Context: IXxmContext; Address: WideString): IXxmFragment; override;
    function LoadFragment(Address: WideString): IXxmFragment; override;
    procedure UnloadFragment(Fragment: IXxmFragment); override;
  end;

function XxmProjectLoad(AProjectName:WideString): IXxmProject; stdcall;

implementation

uses xxmFReg;

function XxmProjectLoad(AProjectName:WideString): IXxmProject;
begin
  Result:=TXxm[[ProjectName]].Create(AProjectName);
end;

{ TXxm[[ProjectName]] }

function TXxm[[ProjectName]].LoadPage(Context: IXxmContext; Address: WideString): IXxmFragment;
begin
  inherited;
  //TODO: link session to request
  Result:=LoadFragment(Address);
end;

function TXxm[[ProjectName]].LoadFragment(Address: WideString): IXxmFragment;
var
  fc:TXxmFragmentClass;
begin
  fc:=XxmFragmentRegistry.GetClass(Address);
  if fc=nil then Result:=nil else Result:=fc.Create(Self);
  //TODO: cache created instance, incease ref count
end;

procedure TXxm[[ProjectName]].UnloadFragment(Fragment: IXxmFragment);
begin
  inherited;
  //TODO: set cache TTL, decrease ref count
  //Fragment.Free;
end;

initialization
  IsMultiThread:=true;
end.
 j  8   ���X X M _ P A S _ P R O T O       0           unit [[FragmentUnit]];

{
  --- ATTENTION! ---

  This file is re-constructed when the xxm source file changes.
  Any changes to this file will be overwritten.
  If you require changes to this file that can not be defined
  in the xxm source file, set up an alternate prototype-file.

  Prototype-file used:
  "[[ProtoFile]]"
  $Rev: 200 $ $Date: 2008-01-25 19:05:51 +0100 (vr, 25 jan 2008) $
}

interface

uses xxm;

type
  [[FragmentID]]=class(TXxmPage)
  public
    procedure Build(const Context: IXxmContext; const Caller: IXxmFragment;
      const Values: array of OleVariant; const Objects: array of TObject); override;
  end;

implementation

uses 
  SysUtils, 
[[UsesClause]]
  xxmFReg;
  
[[FragmentDefinitions]]
{ [[FragmentID]] }

procedure [[FragmentID]].Build(const Context: IXxmContext; const Caller: IXxmFragment; 
      const Values: array of OleVariant; const Objects: array of TObject);
[[FragmentHeader]]
begin
  inherited;
[[FragmentBody]]
end;

initialization
  XxmFragmentRegistry.RegisterClass('[[FragmentAddress]]',[[FragmentID]]);
[[FragmentFooter]]

end.
  l  <   ���X X M I _ P A S _ P R O T O         0           unit [[FragmentUnit]];

{
  --- ATTENTION! ---

  This file is re-constructed when the xxm source file changes.
  Any changes to this file will be overwritten.
  If you require changes to this file that can not be defined
  in the xxm source file, set up an alternate prototype-file.

  Prototype-file used:
  "[[ProtoFile]]"
  $Rev: 200 $ $Date: 2008-01-25 19:05:51 +0100 (vr, 25 jan 2008) $
}

interface

uses xxm;

type
  [[FragmentID]]=class(TXxmInclude)
  public
    procedure Build(const Context: IXxmContext; const Caller: IXxmFragment;
      const Values: array of OleVariant; const Objects: array of TObject); override;
  end;

implementation

uses 
  SysUtils, 
[[UsesClause]]
  xxmFReg;
  
[[FragmentDefinitions]]
{ [[FragmentID]] }

procedure [[FragmentID]].Build(const Context: IXxmContext; const Caller: IXxmFragment;
      const Values: array of OleVariant; const Objects: array of TObject);
[[FragmentHeader]]
begin
  inherited;
[[FragmentBody]]
end;

initialization
  XxmFragmentRegistry.RegisterClass('[[FragmentAddress]]',[[FragmentID]]);
[[FragmentFooter]]

end.
