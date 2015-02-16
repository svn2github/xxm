unit xxm;

interface

uses SysUtils, Classes, ActiveX;

const
  //$Date$
  XxmRevision = '$Rev$';

type
  IXxmContext = interface;//forward
  IXxmFragment = interface;//forward

  IXxmProject = interface
    ['{78786D00-0000-0002-C000-000000000002}']
    function GetProjectName: WideString;
    property Name: WideString read GetProjectName;
    function LoadPage(Context: IXxmContext; Address: WideString): IXxmFragment;
    function LoadFragment(Context: IXxmContext;
      Address, RelativeTo: WideString):IXxmFragment;
    procedure UnloadFragment(Fragment: IXxmFragment);
  end;

  TXxmProjectLoadProc = function(AProjectName: WideString): IXxmProject; stdcall;

  TXxmContextString = integer;//enumeration values see below

  TXxmVersion = record
    Major, Minor, Release, Build: integer;
  end;

  TXxmAutoEncoding = (
    aeContentDefined, //content will specify which content to use
    aeUtf8,           //send UTF-8 byte order mark
    aeUtf16,          //send UTF-16 byte order mark
    aeIso8859         //send using the closest new thing to ASCII
  );

  IXxmParameter = interface
    ['{78786D00-0000-0007-C000-000000000007}']
    function GetName: WideString;
    function GetValue: WideString;
    property Name: WideString read GetName;
    property Value: WideString read GetValue;
    function AsInteger: integer;
    function NextBySameName: IXxmParameter;
  end;

  IXxmParameterGet = interface(IXxmParameter)
    ['{78786D00-0000-0008-C000-000000000008}']
  end;

  IxxmParameterPost = interface(IXxmParameter)
    ['{78786D00-0000-0009-C000-000000000009}']
  end;

  IxxmParameterPostFile = interface(IxxmParameterPost)
    ['{78786D00-0000-000A-C000-00000000000A}']
    function GetSize: integer;
    function GetMimeType: WideString;
    property Size: integer read GetSize;
    property MimeType: WideString read GetMimeType;
    procedure SaveToFile(FilePath: AnsiString);//TODO: WideString
    function SaveToStream(Stream: IStream): integer;
  end;

  IXxmContext = interface
    ['{78786D00-0000-0003-C000-000000000003}']
    function GetURL: WideString;
    function GetPage: IXxmFragment;
    function GetContentType: WideString;
    procedure SetContentType(const Value: WideString);
    function GetAutoEncoding: TXxmAutoEncoding;
    procedure SetAutoEncoding(const Value: TXxmAutoEncoding);
    function GetParameter(Key: OleVariant): IXxmParameter;
    function GetParameterCount: integer;
    function GetSessionID: WideString;

    procedure Send(Data: OleVariant); overload;
    procedure SendHTML(Data: OleVariant); overload;
    procedure SendFile(FilePath: WideString);
    procedure SendStream(s:IStream);
    procedure Include(Address: WideString); overload;
    procedure Include(Address: WideString;
      const Values: array of OleVariant); overload;
    procedure Include(Address: WideString;
      const Values: array of OleVariant;
      const Objects: array of TObject); overload;
    procedure DispositionAttach(FileName: WideString);

    function ContextString(cs: TXxmContextString): WideString;
    function PostData: IStream;
    function Connected: boolean;

    //(local:)progress
    procedure SetStatus(Code: integer; Text: WideString);
    procedure Redirect(RedirectURL: WideString; Relative: boolean);
    function GetCookie(Name: WideString): WideString;
    procedure SetCookie(Name, Value: WideString); overload;
    procedure SetCookie(Name, Value: WideString; KeepSeconds: cardinal;
      Comment, Domain, Path: WideString; Secure, HttpOnly: boolean); overload;
    //procedure SetCookie2();

    procedure Send(Value: integer); overload;
    procedure Send(Value: int64); overload;
    procedure Send(Value: cardinal); overload;
    procedure Send(const Values:array of OleVariant); overload;
    procedure SendHTML(const Values:array of OleVariant); overload;

    function GetBufferSize: integer;
    procedure SetBufferSize(ABufferSize: integer);
    procedure Flush;

    property URL:WideString read GetURL;
    property ContentType:WideString read GetContentType write SetContentType;
    property AutoEncoding:TXxmAutoEncoding read GetAutoEncoding
      write SetAutoEncoding;
    property Page:IXxmFragment read GetPage;
    property Parameter[Key: OleVariant]: IXxmParameter
      read GetParameter; default;
    property ParameterCount:integer read GetParameterCount;
    property SessionID:WideString read GetSessionID;
    property Cookie[Name: WideString]: WideString read GetCookie;
    property BufferSize: integer read GetBufferSize write SetBufferSize;
  end;

  IXxmFragment = interface
    ['{78786D00-0000-0004-C000-000000000004}']
    function GetProject: IXxmProject;
    function ClassNameEx: WideString;
    procedure Build(const Context:IXxmContext; const Caller:IXxmFragment;
      const Values: array of OleVariant;
      const Objects: array of TObject);
    function GetRelativePath: WideString;
    property Project:IXxmProject read GetProject;
    property RelativePath: WideString read GetRelativePath;
  end;

  IXxmPage = interface(IXxmFragment)
    ['{78786D00-0000-0005-C000-000000000005}']
  end;

  IXxmInclude = interface(IXxmFragment)
    ['{78786D00-0000-0006-C000-000000000006}']
  end;

  IXxmProjectEvents = interface
    ['{78786D00-0000-0013-C000-000000000013}']
    function HandleException(Context: IXxmContext; PageClass: WideString;
      Ex: Exception): boolean;
  end;

  IXxmProjectEvents1 = interface
    ['{78786D00-0000-0014-C000-000000000014}']
    function HandleException(Context: IXxmContext; PageClass,
      ExceptionClass, ExceptionMessage: WideString): boolean;
    procedure ReleasingContexts;
    procedure ReleasingProject;
  end;

  IXxmContextSuspend = interface
    ['{78786D00-0000-0015-C000-000000000015}']
    procedure Suspend(const EventKey: WideString;
      CheckIntervalMS, MaxWaitTimeSec: cardinal;
      const ResumeFragment: WideString; ResumeValue: OleVariant;
      const DropFragment: WideString; DropValue: OleVariant);
  end;

  IXxmProjectEvents2 = interface
    ['{78786D00-0000-0016-C000-000000000016}']
    function CheckEvent(const EventKey: WideString;
      var CheckIntervalMS: cardinal): boolean;
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
  IID_IXxmProjectEvents: TGUID = '{78786D00-0000-0013-C000-000000000013}';
  IID_IXxmProjectEvents1: TGUID = '{78786D00-0000-0014-C000-000000000014}';
  IID_IXxmContextSuspend: TGUID = '{78786D00-0000-0015-C000-000000000015}';
  IID_IXxmProjectEvents2: TGUID = '{78786D00-0000-0016-C000-000000000016}';

const
  //TXxmContextString enumeration values
  csVersion           = -1000;
  csProjectName       = -1001;
  csURL               = -1002;
  csLocalURL          = -1003;
  csVerb              = -1004;
  csExtraInfo         = -1005;
  csUserAgent         = -1006;
  csQueryString       = -1007;
  csPostMimeType      = -1008;
  csReferer           = -1009;
  csLanguage          = -1010;
  csAcceptedMimeTypes = -1011;
  csRemoteAddress     = -1012;
  csRemoteHost        = -1013;
  csAuthUser          = -1014;
  csAuthPassword      = -1015;
  //
  cs_Max              = -1100;//used by GetParameter
  
type
  TXxmProject = class(TInterfacedObject, IXxmProject)//abstract
  private
    FProjectName: WideString;
    function GetProjectName: WideString;
  public
    constructor Create(AProjectName: WideString);
    destructor Destroy; override;
    function LoadPage(Context: IXxmContext;
      Address: WideString): IXxmFragment; virtual; abstract;
    function LoadFragment(Context: IXxmContext;
      Address, RelativeTo: WideString): IXxmFragment; virtual; abstract;
    procedure UnloadFragment(Fragment: IXxmFragment); virtual; abstract;
    property Name:WideString read GetProjectName;
  end;

  TXxmFragment = class(TInterfacedObject, IXxmFragment)//abstract
  private
    FProject: TXxmProject;
    FRelativePath: WideString;
    function GetProject: IXxmProject;
    procedure SetRelativePath(const Value: WideString);
  public
    constructor Create(AProject: TXxmProject);
    destructor Destroy; override;
    function ClassNameEx: WideString; virtual;
    procedure Build(const Context: IXxmContext; const Caller: IXxmFragment;
      const Values: array of OleVariant;
      const Objects: array of TObject); virtual; abstract;
    function GetRelativePath: WideString;
    property Project:IXxmProject read GetProject;
    property RelativePath: WideString read GetRelativePath
      write SetRelativePath;
  end;

  TXxmPage = class(TXxmFragment, IXxmPage)
  end;

  TXxmInclude = class(TXxmFragment, IXxmInclude)
  end;

function XxmVersion: TXxmVersion;
function HTMLEncode(const Data: WideString): WideString; overload;
function HTMLEncode(const Data: OleVariant): WideString; overload;
function URLEncode(const Data: OleVariant): AnsiString; overload;
function URLDecode(const Data: AnsiString): WideString;
function URLEncode(const KeyValuePairs: array of OleVariant): AnsiString;
  overload;

implementation

uses Variants;

{ Delphi cross-version declarations }

{$IF not Declared(UTF8ToWideString)}
function UTF8ToWideString(const s: UTF8String): WideString;
begin
  Result:=UTF8Decode(s);
end;
{$IFEND}

{ Helper Functions }

function HTMLEncode(const Data:OleVariant):WideString;
begin
  Result:=HTMLEncode(VarToWideStr(Data));
end;

function HTMLEncode(const Data:WideString):WideString;
const
  GrowStep=$1000;
var
  i,di,ri,dl,rl:integer;
  x:WideString;
begin
  Result:=Data;
  di:=1;
  dl:=Length(Data);
  while (di<=dl) and not(AnsiChar(Data[di]) in ['&','<','"','>',#13,#10]) do
    inc(di);
  if di<=dl then
   begin
    ri:=di;
    rl:=((dl div GrowStep)+1)*GrowStep;
    SetLength(Result,rl);
    while (di<=dl) do
     begin
      case Data[di] of
        '&':x:='&amp;';
        '<':x:='&lt;';
        '>':x:='&gt;';
        '"':x:='&quot;';
        #13,#10:
         begin
          if (di<dl) and (Data[di]=#13) and (Data[di+1]=#10) then inc(di);
          x:='<br />'#13#10;
         end;
        else x:=Data[di];
      end;
      if ri+Length(x)>rl then
       begin
        inc(rl,GrowStep);
        SetLength(Result,rl);
       end;
      for i:=1 to Length(x) do
       begin
        Result[ri]:=x[i];
        inc(ri);
       end;
      inc(di);
     end;
    SetLength(Result,ri-1);
   end;
end;

const
  Hex: array[0..15] of AnsiChar='0123456789ABCDEF';

function URLEncode(const Data:OleVariant):AnsiString;
var
  s,t:AnsiString;
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
      case char(s[p]) of
        #0..#31,'"','#','$','%','&','''','+','/',
        '<','>','?','@','[','\',']','^','`','{','|','}','�':
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

function URLDecode(const Data:AnsiString):WideString;
var
  t:AnsiString;
  p,q,l:integer;
  b:byte;
begin
  l:=Length(Data);
  SetLength(t,l);
  q:=1;
  p:=1;
  while (p<=l) do
   begin
    case char(Data[p]) of
      '+':t[q]:=' ';
      '%':
       begin
        inc(p);
        b:=0;
        case char(Data[p]) of
          '0'..'9':inc(b,byte(Data[p]) and $F);
          'A'..'F','a'..'f':inc(b,(byte(Data[p]) and $F)+9);
        end;
        inc(p);
        b:=b shl 4;
        case char(Data[p]) of
          '0'..'9':inc(b,byte(Data[p]) and $F);
          'A'..'F','a'..'f':inc(b,(byte(Data[p]) and $F)+9);
        end;
        t[q]:=AnsiChar(b);
       end
      else
        t[q]:=Data[p];
    end;
    inc(p);
    inc(q);
   end;
  SetLength(t,q-1);
  Result:=UTF8ToWideString(t);
  //plain decode in case of encoding error?
  if (q>1) and (Result='') then Result:=WideString(t);
end;

function URLEncode(const KeyValuePairs:array of OleVariant):AnsiString;
  overload;
var
  i,l:integer;
begin
  Result:='';
  l:=Length(KeyValuePairs);
  if l<>0 then
   begin
    i:=0;
    while i<l do
     begin
      Result:=Result+'&'+URLEncode(KeyValuePairs[i])+'=';
      inc(i);
      if i<l then
        if VarIsNumeric(KeyValuePairs[i]) then
          Result:=Result+AnsiString(VarToStr(KeyValuePairs[i]))
        else
          Result:=Result+URLEncode(KeyValuePairs[i]);
      inc(i);
     end;
    if i<l then
      Result:=Result+'&'+URLEncode(KeyValuePairs[i])+'=';
    Result[1]:='?';
   end;
end;

function XxmVersion: TXxmVersion;
var
  s:string;
begin
  s:=XxmRevision;
  Result.Major:=1;
  Result.Minor:=2;
  Result.Release:=2;
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
  FRelativePath:='';//set by xxmFReg, used for relative includes
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

function TXxmFragment.GetRelativePath: WideString;
begin
  Result:=FRelativePath;
end;

procedure TXxmFragment.SetRelativePath(const Value: WideString);
begin
  FRelativePath:=Value;
end;

initialization
  IsMultiThread:=true;
end.
