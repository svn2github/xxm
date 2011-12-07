unit xxmHSysHeaders;

interface

uses
  xxmHeaders, httpapi1;

type
  TxxmHeaderGet=function(Name: WideString): WideString of object;
  TxxmHeaderSet=procedure(Name, Value: WideString) of object;
  TxxmHeaderGetCount=function:integer of object;
  TxxmHeaderGetIndex=function(Idx: integer): WideString of object;
  TxxmHeaderSetIndex=procedure(Idx: integer; Value: WideString) of object;

  TxxmHSysResponseHeaders=class(TInterfacedObject, IxxmDictionary, IxxmDictionaryEx)
  private
    FGet:TxxmHeaderGet;
    FSet:TxxmHeaderSet;
    FCount:TxxmHeaderGetCount;
    FGetName,FGetIndex:TxxmHeaderGetIndex;
    FSetIndex:TxxmHeaderSetIndex;
  protected
    function GetItem(Name: OleVariant): WideString;
    procedure SetItem(Name: OleVariant; const Value: WideString);
    function GetName(Idx: integer): WideString;
    procedure SetName(Idx: integer; Value: WideString);
    function GetCount:integer;
    function Complex(Name: OleVariant; out Items: IxxmDictionary): WideString;
  public
    constructor Create(xGet:TxxmHeaderGet;xSet:TxxmHeaderSet;xCount:TxxmHeaderGetCount;
      XGetName,xGetIndex:TxxmHeaderGetIndex;xSetIndex:TxxmHeaderSetIndex);
  end;

const
  HttpRequestHeaderName:array[THTTP_HEADER_ID] of AnsiString=(
    'Cache-Control',
    'Connection',
    'Date',
    'Keep-Alive',
    'Pragma',
    'Trailer',
    'Transfer-Encoding',
    'Upgrade',
    'Via',
    'Warning',
    'Allow',
    'Content-Length',
    'Content-Type',
    'Content-Encoding',
    'Content-Language',
    'Content-Location',
    'Content-MD5',
    'Content-Range',
    'Expires',
    'Last-Modified',
    'Accept',
    'Accept-Charset',
    'Accept-Encoding',
    'Accept-Language',
    'Authorization',
    'Cookie',
    'Expect',
    'From',
    'Host',
    'If-Match',
    'If-Modified-Since',
    'If-None-Match',
    'If-Range',
    'If-Unmodified-Since',
    'Max-Forwards',
    'Proxy-Authorization',
    'Referer',
    'Range',
    'TE',
    'Translate',
    'User-Agent');

const
  HttpResponseHeaderName:array[THTTP_HEADER_ID] of AnsiString=(
    'Cache-Control',
    'Connection',
    'Date',
    'Keep-Alive',
    'Pragma',
    'Trailer',
    'Transfer-Encoding',
    'Upgrade',
    'Via',
    'Warning',
    'Allow',
    'Content-Length',
    'Content-Type',
    'Content-Encoding',
    'Content-Language',
    'Content-Location',
    'Content-MD5',
    'Content-Range',
    'Expires',
    'Last-Modified',
    'Accept-Ranges',
    'Age',
    'ETag',
    'Location',
    'Proxy-Authenticate',
    'Retry-After',
    'Server',
    'Set-Cookie',
    'Vary',
    'WWW-Authenticate',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '');

implementation

uses Variants, SysUtils;

{ TxxmHSysResponseHeaders }

constructor TxxmHSysResponseHeaders.Create(xGet:TxxmHeaderGet;xSet:TxxmHeaderSet;
  xCount:TxxmHeaderGetCount;xGetName,xGetIndex:TxxmHeaderGetIndex;xSetIndex:TxxmHeaderSetIndex);
begin
  inherited Create;
  FGet:=xGet;
  FSet:=xSet;
  FCount:=xCount;
  FGetName:=xGetName;
  FGetIndex:=xGetIndex;
  FSetIndex:=xSetIndex;
end;

function TxxmHSysResponseHeaders.GetCount: integer;
begin
  Result:=FCount;
end;

function TxxmHSysResponseHeaders.GetItem(Name: OleVariant): WideString;
begin
  if VarIsNumeric(Name) then
    Result:=FGetIndex(Name)
  else
    Result:=FGet(Name);
end;

function TxxmHSysResponseHeaders.GetName(Idx: integer): WideString;
begin
  Result:=FGetName(Idx);
end;

function TxxmHSysResponseHeaders.Complex(Name: OleVariant;
  out Items: IxxmDictionary): WideString;
begin
  raise Exception.Create('TxxmHSysResponseHeaders.Complex not implemented');
  //TODO:
end;

procedure TxxmHSysResponseHeaders.SetItem(Name: OleVariant;
  const Value: WideString);
begin
  if VarIsNumeric(Name) then
    FSetIndex(Name,Value)
  else
    FSet(Name,Value);
end;

procedure TxxmHSysResponseHeaders.SetName(Idx: integer; Value: WideString);
begin
  raise Exception.Create('TxxmHSysResponseHeaders.SetName not supported');
end;

end.
