unit xxmHandler;

{$WARN SYMBOL_PLATFORM OFF}

interface

//https://msdn.microsoft.com/en-us/library/aa767743.aspx

uses
  Windows, SysUtils, ActiveX, Classes, ComObj, UrlMon, xxm, xxmContext;

type
  //odd, old UrlMon.pas has an error in ParseUrl?
  IInternetProtocolInfoX = interface
    ['{79eac9ec-baf9-11ce-8c82-00aa004ba90b}']
    function ParseUrl(pwzUrl: LPCWSTR; ParseAction: TParseAction; dwParseFlags: DWORD;
      pwzResult: LPWSTR; cchResult: DWORD; out pcchResult: DWORD;
      dwReserved: DWORD): HResult; stdcall;
    function CombineUrl(pwzBaseUrl, pwzRelativeUrl: LPCWSTR; dwCombineFlags: DWORD;
      pwzResult: LPWSTR; cchResult: DWORD; out pcchResult: DWORD;
      dwReserved: DWORD): HResult; stdcall;
    function CompareUrl(pwzUrl1, pwzUrl2: LPCWSTR; dwCompareFlags: DWORD): HResult; stdcall;
    function QueryInfo(pwzUrl: LPCWSTR; QueryOption: TQueryOption; dwQueryFlags: DWORD;
      pBuffer: Pointer; cbBuffer: DWORD; var cbBuf: DWORD; dwReserved: DWORD): HResult; stdcall;
  end;

  TXxmLocalHandler=class(TComObject, IInternetProtocol, IWinInetHttpInfo, IInternetProtocolInfoX)
  private
    FDataPos: Int64;
    FContext: TXxmGeneralContext;
    FTerminateTC: cardinal;
  protected
    { IInternetProtocolRoot }
    function Start(szUrl: PWideChar; OIProtSink: IInternetProtocolSink;
      OIBindInfo: IInternetBindInfo; grfPI: Cardinal;
      dwReserved: Cardinal): HRESULT; stdcall;
    function Suspend: HRESULT; stdcall;
    function Resume: HRESULT; stdcall;
    function Continue(const ProtocolData: _tagPROTOCOLDATA): HRESULT; stdcall;
    function Abort(hrReason: HRESULT; dwOptions: Cardinal): HRESULT; stdcall;
    function Terminate(dwOptions: Cardinal): HRESULT; stdcall;
    { IInternetProtocol }
    function LockRequest(dwOptions: Cardinal): HRESULT; stdcall;
    function Read(pv: Pointer; cb: Cardinal; out cbRead: Cardinal): HRESULT;
      stdcall;
    function Seek(dlibMove: _LARGE_INTEGER; dwOrigin: Cardinal;
      out libNewPosition: ULARGE_INTEGER): HRESULT; stdcall;
    function UnlockRequest: HRESULT; stdcall;
    { IWinInetInfo }
    function QueryOption(dwOption: DWORD; Buffer: Pointer; var cbBuf: DWORD): HResult; stdcall;
    { IWinInetHttpInfo }
    function QueryInfo(dwOption: DWORD; Buffer: Pointer;
      var cbBuf, dwFlags, dwReserved: DWORD): HResult; stdcall;
    { IInternetProtocolInfo }
    function ParseUrl(pwzUrl: LPCWSTR; ParseAction: TParseAction; dwParseFlags: DWORD;
      pwzResult: LPWSTR; cchResult: DWORD; out pcchResult: DWORD;
      dwReserved: DWORD): HResult; stdcall;
    function CombineUrl(pwzBaseUrl, pwzRelativeUrl: LPCWSTR; dwCombineFlags: DWORD;
      pwzResult: LPWSTR; cchResult: DWORD; out pcchResult: DWORD;
      dwReserved: DWORD): HResult; stdcall;
    function CompareUrl(pwzUrl1, pwzUrl2: LPCWSTR; dwCompareFlags: DWORD): HResult; stdcall;
    function P1QueryInfo(pwzUrl: LPCWSTR; QueryOption: TQueryOption; dwQueryFlags: DWORD;
      pBuffer: Pointer; cbBuffer: DWORD; var cbBuf: DWORD; dwReserved: DWORD): HResult; stdcall;
    function IInternetProtocolInfoX.QueryInfo=P1QueryInfo;

  public
    procedure Initialize; override;
    destructor Destroy; override;
  end;

  TXxmLocalHandlerFactory=class(TComObjectFactory)
  public
    procedure UpdateRegistry(Register: Boolean); override;
  end;

var
  XxmLocalHandlerFactory:TXxmLocalHandlerFactory;
  URLSchema,URLSchemaDescription:string;

const
  Class_xxmLocalHandler:TGUID='{78786D00-0000-0001-C000-000000000001}';

implementation

uses ComServ, Registry, xxmWinInet, xxmThreadPool, xxmLoader;

{ TXxmLocalHandler }

procedure TXxmLocalHandler.Initialize;
begin
  inherited;
  FContext:=nil;
  FDataPos:=0;
  FTerminateTC:=0;
end;

destructor TXxmLocalHandler.Destroy;
begin
  //FContext.Recycle: see Terminate
  inherited;
end;

{ TXxmLocalHandler::IInternetProtocolRoot }

function TXxmLocalHandler.Start(szUrl: PWideChar;
  OIProtSink: IInternetProtocolSink; OIBindInfo: IInternetBindInfo; grfPI,
  dwReserved: Cardinal): HRESULT;
begin
  FContext:=ContextPool.GetContext;
  (FContext as TXxmLocalContext).Load(szUrl,OIProtSink,OIBindInfo);
  if PageLoaderPool=nil then PageLoaderPool:=TXxmPageLoaderPool.Create($10);
  //SetThreadName('xxmLocalHandler:'+szUrl);
  PageLoaderPool.Queue(FContext,ctHeaderNotSent);
  Result:=HResult(E_PENDING);
end;

function TXxmLocalHandler.Suspend: HRESULT;
begin
  //Context.Loader.Suspend;Result:=S_OK;
  Result:=E_NOTIMPL;
end;

function TXxmLocalHandler.Resume: HRESULT;
begin
  //Context.Loader.Resume;Result:=S_OK;
  Result:=E_NOTIMPL;
end;

function TXxmLocalHandler.Continue(const ProtocolData: _tagPROTOCOLDATA): HRESULT;
begin
  Result:=E_NOTIMPL;
end;

function TXxmLocalHandler.Abort(hrReason: HRESULT; dwOptions: Cardinal): HRESULT;
begin
  (FContext as TXxmLocalContext).Terminated:=true;
  Result:=S_OK;
end;

function TXxmLocalHandler.Terminate(dwOptions: Cardinal): HRESULT;
begin
  if FContext<>nil then
   begin
    if FContext.State=ctSpooling then FContext.State:=ctResponding;
    if (FContext as TXxmLocalContext).Terminated then
     begin
      //SetThreadName('(xxmLocalHandler)');
      //ContextPool.AddContext(FContext);
      FContext.Recycle;
     end
    else
      (FContext as TXxmLocalContext).Terminated:=true;
   end;
  Result:=S_OK;
end;

{ TXxmLocalHandler::IInternetProtocol }

function TXxmLocalHandler.LockRequest(dwOptions: Cardinal): HRESULT;
begin
  Result:=S_OK;
end;

function TXxmLocalHandler.UnlockRequest: HRESULT;
begin
  Result:=S_OK;
end;

function TXxmLocalHandler.Read(pv: Pointer; cb: Cardinal;
  out cbRead: Cardinal): HRESULT;
type
  TBArr=array[0..0] of byte;
  PBArr=^TBArr;
var
  ctx:TXxmLocalContext;
  ReadSize:integer;
  BArr:PBArr;
const
  CollapseThreshold=$20000;//128KB
begin
  ctx:=FContext as TXxmLocalContext;
  ctx.Lock;
  try
    //read how much now?
    ReadSize:=cb;
    if FDataPos+ReadSize>ctx.OutputSize then
      ReadSize:=ctx.OutputSize-FDataPos;
    if ReadSize<0 then ReadSize:=0;

    //read!
    if ReadSize=0 then cbRead:=0 else
     begin
      ctx.OutputData.Position:=FDataPos;
      cbRead:=ctx.OutputData.Read(pv^,ReadSize);
      FDataPos:=FDataPos+cbRead;
      //cache to file??
     end;

    if (FDataPos>=ctx.OutputSize) then
     begin
      if (ctx.OutputData is TMemoryStream) then
       begin
        ctx.OutputSize:=0;//no SetSize, just reset pointer, saves on realloc calls
        FDataPos:=0;
       end;
      ReadSize:=0;
     end;

    if ReadSize=0 then
     begin
      if ctx.Terminated then
       begin
        //if ctx.State=ctRedirected then
        //  Result:=INET_E_USE_DEFAULT_PROTOCOLHANDLER else
        Result:=S_FALSE;
       end
      else
        Result:=HResult(E_PENDING);
     end
    else
     begin
      if (ctx.OutputData is TMemoryStream) and (FDataPos>=CollapseThreshold) then
       begin
        ctx.OutputSize:=ctx.OutputSize-FDataPos;
        BArr:=PBArr((ctx.OutputData as TMemoryStream).Memory);
        Move(BArr[FDataPos],BArr[0],ctx.OutputSize);
        FDataPos:=0;
       end;
      Result:=S_OK;
     end;

    //INET_E_DATA_NOT_AVAILABLE //all read but more data was expected
    //except Result:=INET_E_DOWNLOAD_FAILURE?
  finally
    ctx.DataRead:=true;
    ctx.Unlock;
  end;
end;

function TXxmLocalHandler.Seek(dlibMove: _LARGE_INTEGER;
  dwOrigin: Cardinal; out libNewPosition: ULARGE_INTEGER): HRESULT;
begin
  Result:=E_NOTIMPL;
end;

function TXxmLocalHandler.QueryOption(dwOption: DWORD; Buffer: Pointer;
  var cbBuf: DWORD): HResult;
begin
  //Result:=E_NOTIMPL;
  case dwOption of
    INTERNET_OPTION_REQUEST_FLAGS:
     begin
      //assert(cbBuf=4)
      PDWORD(Buffer)^:=0;
      //INTERNET_REQFLAG_VIA_PROXY?
      //INTERNET_REQFLAG_NET_TIMEOUT?
      //if not(SingleFileSent then INTERNET_REQFLAG_FROM_CACHE?
      Result:=S_OK;
     end;
    INTERNET_OPTION_SECURITY_FLAGS:
     begin
      //assert(cbBuf=4)
      PDWORD(Buffer)^:=0;
      Result:=S_OK;
     end;

    INTERNET_OPTION_ERROR_MASK:
     begin
      PDWORD(Buffer)^:=10;
      Result:=S_OK;
     end;

    else Result:=S_FALSE;
  end;
end;

function TXxmLocalHandler.QueryInfo(dwOption: DWORD; Buffer: Pointer;
  var cbBuf, dwFlags, dwReserved: DWORD): HResult;
var
  s:AnsiString;
  f:HFILE;
  dt1,dt2,dt3:TFileTime;
  st:TSystemTime;
begin
  try
    case dwOption and $F0000000 of
      HTTP_QUERY_FLAG_SYSTEMTIME:
        case dwOption and $0FFFFFFF of
          HTTP_QUERY_LAST_MODIFIED:
           begin
            s:=AnsiString(FContext.SingleFileSent);
            Result:=S_FALSE;//default
            if s<>'' then
             begin
              f:=CreateFileA(@s[1],GENERIC_READ,7,nil,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
              if f<>INVALID_HANDLE_VALUE then
               begin
                if GetFileTime(f,@dt1,@dt2,@dt3) and FileTimeToSystemTime(dt3,st) then
                 begin
                  //assert cbBuf=SizeOf(TSystemTime);
                  Move(st,Buffer^,cbBuf);
                  Result:=S_OK;
                 end;
                CloseHandle(f);
               end;
             end;
           end;
          else Result:=E_INVALIDARG;
        end;
      HTTP_QUERY_FLAG_NUMBER:
        case dwOption and $0FFFFFFF of
          HTTP_QUERY_STATUS_CODE:
           begin
            //assert cbBuf:=4;
            PDWORD(Buffer)^:=FContext.StatusCode;
            Result:=S_OK;
           end;
          else Result:=E_INVALIDARG;
        end;
      else
       begin
        Result:=S_FALSE;
        case dwOption and $0FFFFFFF of
          HTTP_QUERY_REFRESH:
            Result:=S_FALSE;
          HTTP_QUERY_STATUS_TEXT:
            s:=AnsiString(FContext.StatusText)+#0;
          HTTP_QUERY_REQUEST_METHOD:
            s:=AnsiString((FContext as TXxmLocalContext).Verb)+#0;
          HTTP_QUERY_CONTENT_TYPE:
            s:=AnsiString(FContext.ContentType)+#0;
          else
            Result:=E_INVALIDARG;
        end;
        if Result=S_OK then
          if cbBuf<DWORD(Length(s)) then Result:=E_OUTOFMEMORY else
           begin
            Move(s[1],Buffer^,Length(s));
            cbBuf:=Length(s);
           end;
       end;
    end;
  except
    Result:=E_FAIL;
  end;
end;

function TXxmLocalHandler.CombineUrl(pwzBaseUrl, pwzRelativeUrl: LPCWSTR;
  dwCombineFlags: DWORD; pwzResult: LPWSTR; cchResult: DWORD;
  out pcchResult: DWORD; dwReserved: DWORD): HResult;
begin
  //TODO: CombineURL
  Result:=INET_E_DEFAULT_ACTION;
end;

function TXxmLocalHandler.CompareUrl(pwzUrl1, pwzUrl2: LPCWSTR;
  dwCompareFlags: DWORD): HResult;
begin
  //TODO: CompareURL
  Result:=INET_E_DEFAULT_ACTION;
end;

function TXxmLocalHandler.P1QueryInfo(pwzUrl: LPCWSTR;
  QueryOption: TQueryOption; dwQueryFlags: DWORD; pBuffer: Pointer;
  cbBuffer: DWORD; var cbBuf: DWORD; dwReserved: DWORD): HResult;
begin
  Result:=INET_E_DEFAULT_ACTION;
end;

function TXxmLocalHandler.ParseUrl(pwzUrl: LPCWSTR; ParseAction: TParseAction;
  dwParseFlags: DWORD; pwzResult: LPWSTR; cchResult: DWORD; out pcchResult: DWORD;
  dwReserved: DWORD): HResult;
var
  i,j,l:integer;
  FURL,w:WideString;
  wr:boolean;
begin
  Result:=INET_E_DEFAULT_ACTION;//default value, counter warning
  wr:=false;//return w?
  case ParseAction of
    PARSE_SCHEMA:
     begin
      w:=URLSchema;
      wr:=true;
     end;
    PARSE_SERVER:
     begin
      w:='localhost';
      wr:=true;
     end;
    PARSE_DOMAIN, PARSE_SITE, PARSE_SECURITY_DOMAIN, PARSE_SECURITY_URL:
     begin
      //see also loader!!
      FURL:=pwzUrl;
      l:=Length(FURL);
      i:=1;
      while (i<=l) and (FURL[i]<>':') do inc(i);
      //assert starts with 'xxm:'
      inc(i);
      if (i<=l) and (FURL[i]='/') then inc(i);
      if (i<=l) and (FURL[i]='/') then inc(i);
      if ParseAction=PARSE_SECURITY_URL then
        w:='http://'+Copy(FURL,i,l-i+1)
      else
       begin
        j:=i;
        while (i<=Length(FURL)) and not(AnsiChar(FURL[i]) in ['/','?','&','$','#']) do inc(i);
        w:=Copy(FURL,j,i-j);
       end;
      wr:=true;
     end;
    //TODO: other PARSE_*
    else
      ;//Result:=INET_E_DEFAULT_ACTION;
  end;
  if wr then //return string in w
    if cchResult<cardinal(Length(w)+1) then Result:=S_FALSE else
     begin
      Move(PWideChar(w)^,pwzResult^,Length(w)*2+2);
      pcchResult:=Length(w)+1;
      Result:=S_OK;
     end;
end;

{ TXxmLocalHandlerFactory }

procedure TXxmLocalHandlerFactory.UpdateRegistry(Register: Boolean);
var
  r:TRegistry;
  fn,fn1:string;
  i:integer;
  procedure SimpleAdd(const Key,Value:string);
  begin
    r.OpenKey(Key,true);
    r.WriteString('',Value);
    r.CloseKey;
  end;
begin
  inherited;
  r:=TRegistry.Create;
  try
    if Register then
     begin
      fn:=ComServer.ServerFileName;

      r.RootKey:=HKEY_CLASSES_ROOT;
      r.OpenKey('\'+URLSchema,true);
      r.WriteString('','URL:'+URLSchemaDescription);
      r.WriteInteger('EditFlags',2);
      r.WriteString('FriendlyTypeName',URLSchemaDescription);
      r.WriteString('URL Protocol','');
      r.CloseKey;

      SimpleAdd('\'+URLSchema+'\shell','open');
      SimpleAdd('\'+URLSchema+'\shell\open','Open');
      SimpleAdd('\'+URLSchema+'\shell\open\command','iexplore "%l"');
      SimpleAdd('\'+URLSchema+'\DefaultIcon',fn+',1');

      //SimpleAdd(.OpenKey('\'+URLSchema+'\Extensions',
      //SimpleAdd(.OpenKey('\'+URLSchema+'\shell',
      //SimpleAdd(.OpenKey('\'+URLSchema+'\shell\open',
      //SimpleAdd(.OpenKey('\'+URLSchema+'\shell\open\command',

      r.OpenKey('\Protocols\Handler\'+URLSchema,true);
      r.WriteString('',URLSchemaDescription);
      r.WriteString('CLSID',GUIDToString(Class_xxmLocalHandler));
      r.CloseKey;

      //filetypes

      //SimpleAdd('.xxmp','xxmpfile');
      r.OpenKey('.xxmp',true);
      r.WriteString('','xxmpfile');
      r.WriteString('Content Type','text/json');
      r.CloseKey;
      SimpleAdd('xxmpfile','xxm Project File');
      i:=Length(fn);
      while (i<>0) and (fn[i]<>PathDelim) do dec(i);
      fn1:=Copy(fn,1,i)+'xxmProject.exe';
      if FileExists(fn1) then
       begin
        SimpleAdd('xxmpfile\shell','open');
        SimpleAdd('xxmpfile\shell\open','Properties');
        SimpleAdd('xxmpfile\shell\open\command','"'+fn1+'" "%l"');
        r.OpenKey('.xxmp\xxmpfile\ShellNew',true);
        r.WriteString('Command','"'+fn1+'" /n "%1"');
        r.CloseKey;
       end
      else
       begin
        SimpleAdd('xxmpfile\shell','');
       end;
      SimpleAdd('xxmpfile\DefaultIcon',fn+',3');
      //SimpleAdd('xxmpfile\CLSID',);

      SimpleAdd('.xxm','xxmfile');
      //TODO: mime type?
      SimpleAdd('xxmfile','xxm Page File');
      SimpleAdd('xxmfile\shell','');
      SimpleAdd('xxmfile\DefaultIcon',fn+',4');
      //SimpleAdd('xxmfile\CLSID',);
      SimpleAdd('.xxmi','xxmifile');
      SimpleAdd('xxmifile','xxm Include File');
      SimpleAdd('xxmifile\shell','');
      SimpleAdd('xxmifile\DefaultIcon',fn+',5');
      //SimpleAdd('xxmifile\CLSID',);
      SimpleAdd('.xxl','xxlfile');
      SimpleAdd('xxlfile','xxm Library');
      SimpleAdd('xxlfile\shell','');
      SimpleAdd('xxlfile\DefaultIcon',fn+',2');
      //SimpleAdd('xxlfile\CLSID',);

      SimpleAdd('xxlfile\Shell\RegLocal','Register for local handler');
      SimpleAdd('xxlfile\Shell\RegLocal\command','rundll32.exe "'+fn+'",XxmProjectRegister %l');

      SimpleAdd('.xxu','xxufile');
      SimpleAdd('xxufile','xxm Library Update');
      SimpleAdd('xxufile\shell','');
      SimpleAdd('xxufile\DefaultIcon',fn+',6');
      //SimpleAdd('xxufile\CLSID',);

      //Security Zone: Local Intranet
      r.RootKey:=HKEY_CURRENT_USER;
      r.OpenKey('\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\ProtocolDefaults',true);
      r.WriteInteger(URLSchema,1);
      r.CloseKey;
      r.RootKey:=HKEY_LOCAL_MACHINE;
      r.OpenKey('\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\ProtocolDefaults',true);
      r.WriteInteger(URLSchema,1);
      r.CloseKey;
      //HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\URL\Prefixes?

     end
    else
     begin
      r.RootKey:=HKEY_CLASSES_ROOT;
      r.DeleteKey('\'+URLSchema);
      r.DeleteKey('\Protocols\Handler\'+URLSchema);

      r.RootKey:=HKEY_CLASSES_ROOT;
      r.DeleteKey('.xxmp');
      r.DeleteKey('xxmpfile');
      r.DeleteKey('.xxm');
      r.DeleteKey('xxmfile');
      r.DeleteKey('.xxmi');
      r.DeleteKey('xxmifile');
      r.DeleteKey('.xxl');
      r.DeleteKey('xxlfile');

      r.RootKey:=HKEY_CURRENT_USER;
      r.OpenKey('\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\ProtocolDefaults',true);
      r.DeleteValue(URLSchema);
      r.CloseKey;

      r.RootKey:=HKEY_LOCAL_MACHINE;
      r.OpenKey('\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\ProtocolDefaults',true);
      r.DeleteValue(URLSchema);
      r.CloseKey;
      //TODO: switch keep project registry?
      r.DeleteKey('\Software\xxm');
     end;
  finally
    r.Free;
  end;
end;

initialization
  URLSchema:='xxm';//not consts for the 'skip the handler' builds
  URLSchemaDescription:='xxm Local Handler';
  XxmLocalHandlerFactory:=TXxmLocalHandlerFactory.Create(ComServer,
    TXxmLocalHandler, Class_xxmLocalHandler,
    'XxmLocalHandler', URLSchemaDescription,
    ciMultiInstance, tmApartment);
finalization
  FreeAndNil(PageLoaderPool);//clear all loader threads first!
  FreeAndNil(XxmLocalHandlerFactory);
end.
