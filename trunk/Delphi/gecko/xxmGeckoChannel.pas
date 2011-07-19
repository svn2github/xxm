unit xxmGeckoChannel;

interface

uses nsXPCOM, nsTypes, nsGeckoStrings, nsThreadUtils, xxm, xxmContext,
  Windows, Classes, SysUtils, ActiveX, xxmHeaders, xxmParUtils,
  xxmPReg, xxmPRegLocal, xxmParams, xxmGeckoInterfaces, xxmGeckoStreams;

type
  TxxmChannel=class(TXxmGeneralContext,
    nsIRequest,
    nsIChannel,
    nsIHttpChannel,
    nsIHttpChannelInternal,
    //nsIClassInfo,
    //nsIInterfaceRequestor,
    //nsITransportEventSink,??
    nsIUploadChannel,
    //nsIPropertyBag2
    //nsIXPCScriptable,
    //nsIXPConnectWrappedJS,
    //nsISecurityCheckedComponent,
    nsIInputStream,//!
    //nsISeekableStream?
    //IxxmContext,//see TXxmGeneralContext
    IxxmHttpHeaders)
  private
    FOwner:nsISupports;
    FURI,FOrigURI,FDocURI,FReferer:nsIURI;
    FLoadFlags:nsLoadFlags;
    FLoadGroup:nsILoadGroup;
    FListenerContext:nsISupports;
    FListener:nsIStreamListener;
    FCallBacks:nsIInterfaceRequestor;
    FReportToThread:nsIThread;
    FConnected,FComplete,FAllowPipelining,FGotSessionID:boolean;
    FStatus,FSuspendCount,FRedirectionLimit:integer;
    FVerb,FQueryString:AnsiString;
    FRequestHeaders,FResponseHeaders:TResponseHeaders;//both TResponseHeaders?! see Create
    FCookie:AnsiString;
    FCookieIdx: TParamIndexes;
    FCookieParsed: boolean;
    FTotalSize,FOutputSize,FExportSize,FReportSize:int64;
    FReportPending:boolean;
    FData:TMemoryStream;
    FLock:TRTLCriticalSection;
    FRedirectChannel:nsIChannel;//see Redirect
    procedure CheckSuspend;
    procedure Lock;
    procedure Unlock;
    procedure ReportData;//call within lock!
    function Write(const Buffer; Count: Longint): Longint;//call within lock!
    procedure ReadCheck;
    procedure RedirectSync;
  protected
    //nsIInterfaceRequestor
    //procedure nsGetInterface(const uuid: TGUID; out _result); safecall;
    //procedure nsIInterfaceRequestor.GetInterface=nsGetInterface;
    //nsIRequest
    procedure GetName(aName: nsAUTF8String); safecall;
    function IsPending: PRBool; safecall;
    function GetStatus: nsresult; safecall;
    property Status: nsresult read GetStatus;
    procedure Cancel(aStatus: nsresult); safecall;
    procedure Suspend; safecall;
    procedure Resume; safecall;
    function GetLoadGroup: nsILoadGroup; safecall;
    procedure SetLoadGroup(aLoadGroup: nsILoadGroup); safecall;
    property LoadGroup: nsILoadGroup read GetLoadGroup write SetLoadGroup;
    function GetLoadFlags: nsLoadFlags; safecall;
    procedure SetLoadFlags(aLoadFlags: nsLoadFlags); safecall;
    property LoadFlags: nsLoadFlags read GetLoadFlags write SetLoadFlags;
    //nsIChannel
    function Open: nsIInputStream; safecall;
    procedure AsyncOpen(aListener: nsIStreamListener;
      aContext: nsISupports); safecall;
    function GetOriginalURI: nsIURI; safecall;
    procedure SetOriginalURI(aOriginalURI: nsIURI); safecall;
    function GetURI: nsIURI; safecall;
    function GetOwner: nsISupports; safecall;
    procedure SetOwner(aOwner: nsISupports); safecall;
    function GetNotificationCallbacks: nsIInterfaceRequestor; safecall;
    procedure SetNotificationCallbacks(aNotificationCallbacks: nsIInterfaceRequestor);
      safecall;
    function GetSecurityInfo: nsISupports; safecall;
    procedure GetContentType(aContentType: nsACString); overload; safecall;
    procedure SetContentType(const aContentType: nsACString); overload; safecall;
    procedure GetContentCharset(aContentCharset: nsACString); safecall;
    procedure SetContentCharset(const aContentCharset: nsACString);
      safecall;
    function GetContentLength: Integer; safecall;
    procedure SetContentLength(aContentLength: Integer); safecall;
    //nsIHttpChannel
    procedure GetRequestMethod(aRequestMethod: nsACString); safecall;
    procedure SetRequestMethod(const aRequestMethod: nsACString); safecall;
    function GetReferrer: nsIURI; safecall;
    procedure SetReferrer(aReferrer: nsIURI); safecall;
    property Referrer: nsIURI read GetReferrer write SetReferrer;
    function GetRequestHeader(const aHeader: nsACString): nsACString; safecall;
    procedure SetRequestHeader(const aHeader: nsACString; const aValue: nsACString; aMerge: PRBool); safecall;
    procedure VisitRequestHeaders(aVisitor: nsIHttpHeaderVisitor); safecall;
    function GetAllowPipelining: PRBool; safecall;
    procedure SetAllowPipelining(aAllowPipelining: PRBool); safecall;
    property AllowPipelining: PRBool read GetAllowPipelining write SetAllowPipelining;
    function GetRedirectionLimit: PRUint32; safecall;
    procedure SetRedirectionLimit(aRedirectionLimit: PRUint32); safecall;
    property RedirectionLimit: PRUint32 read GetRedirectionLimit write SetRedirectionLimit;
    function GetResponseStatus: PRUint32; safecall;
    property ResponseStatus: PRUint32 read GetResponseStatus;
    procedure GetResponseStatusText(aResponseStatusText: nsACString); safecall;
    function GetRequestSucceeded: PRBool; safecall;
    property RequestSucceeded: PRBool read GetRequestSucceeded;
    function GetResponseHeader(const header: nsACString): nsACString; safecall;
    procedure SetResponseHeader(const header: nsACString; const value: nsACString; merge: PRBool); safecall;
    procedure VisitResponseHeaders(aVisitor: nsIHttpHeaderVisitor); safecall;
    function IsNoStoreResponse: PRBool; safecall;
    function IsNoCacheResponse: PRBool; safecall;
    //nsIHttpChannelInternal
    function GetDocumentURI: nsIURI; safecall;
    procedure SetDocumentURI(aDocumentURI: nsIURI); safecall;
    procedure getRequestVersion(var major:PRUint32; var minor:PRUint32); safecall;
    procedure getResponseVersion(var major:PRUint32; var minor:PRUint32); safecall;
    procedure nsIHttpChannelInternal.setCookie=SetCookieHttpInt;
    procedure SetCookieHttpInt(aCookieHeader:PAnsiChar); safecall;//string?
    procedure setupFallbackChannel(aFallbackKey:PAnsiChar); safecall;//string?
    //nsIUploadChannel
    procedure SetUploadStream(aStream: nsIInputStream; const aContentType: nsACString; aContentLength: PRInt32); safecall;
    function GetUploadStream(): nsIInputStream; safecall;
    //nsIInputStream (attention: interface on channel object for convenience)
    function Available: Cardinal; safecall;
    procedure Close; safecall;
    function IsNonBlocking: LongBool; safecall;
    function Read(aBuf: PAnsiChar; aCount: Cardinal): Cardinal; safecall;
    function ReadSegments(aWriter: nsWriteSegmentFun; aClosure: Pointer;
      aCount: Cardinal): Cardinal; safecall;
{
//exclude seekable stream interface, to allow collapsing datastream when empty
    //nsISeekableStream
    procedure seek(whence:PRUint32;offset:PRUint64);
    function tell:PRUint64;
    procedure setEOF();
}

    //IxxmContext
    function GetSessionID: WideString; override;
    procedure DispositionAttach(FileName: WideString); override;
    procedure SendRaw(Data: WideString); override;
    procedure SendStream(s: IStream); override;
    function ContextString(cs: TXxmContextString): WideString; override;
    function Connected: Boolean; override;
    procedure Redirect(RedirectURL: WideString; Relative:boolean); override;
    function GetCookie(Name: WideString): WideString; override;
    procedure SetCookie(Name: WideString; Value: WideString); overload; override;
    procedure SetCookie(Name,Value:WideString; KeepSeconds:cardinal;
      Comment,Domain,Path:WideString; Secure,HttpOnly:boolean); overload; override;

    //other TXxmGeneralContext abstract methods
    function GetProjectEntry(ProjectName: WideString):TXxmProjectEntry; override;
    procedure SendHeader; override;
    procedure AddResponseHeader(Name, Value: WideString); override;

    //IxxmHttpHeaders
    function GetRequestHeaders:IxxmDictionaryEx;
    function GetResponseHeaders:IxxmDictionaryEx;
  public
    //
    Queue:TxxmChannel;//used by thread pool
    constructor Create(aURI: nsIURI);
    destructor Destroy; override;
    procedure Execute;
  end;

  TXxmGeckoLoader=class(TThread)
  private
    FInUse:boolean;
  protected
    procedure Execute; override;
  public
    constructor Create;
    property InUse:boolean read FInUse;
  end;

  TXxmGeckoLoaderPool=class(TObject)
  private
    FLoaders:array of TXxmGeckoLoader;
    FLoadersSize:integer;
    FLock:TRTLCriticalSection;
    FQueue:TxxmChannel;
    procedure SetSize(x:integer);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Queue(Channel:TxxmChannel);//called from handler
    function Unqueue:TxxmChannel;//called from threads
  end;

  TxxmListenerCall=(lcActivate,lcStart,lcData,lcStop,lcAbort,lcRedirect);

  TxxmListenerCaller=class(TInterfacedObject,
    nsIRunnable)
  private
    FOwner:TxxmChannel;
    FCall:TxxmListenerCall;
    FOffset,FCount:cardinal;
  protected
    procedure run; safecall;
  public
    constructor Create(Owner:TxxmChannel;Call:TxxmListenerCall;
      Offset,Count:cardinal);
    destructor Destroy; override;
  end;

  EXxmContextStringUnknown=class(Exception);
  EXxmAutoBuildFailed=class(Exception);
  EXxmPageRedirected=class(Exception);

const
  PoolMaxThreads=64;//TODO: setting?

var
  GeckoLoaderPool:TXxmGeckoLoaderPool;
  //see xxmSettings
  StatusBuildError,StatusException,StatusFileNotFound:integer;
  DefaultProjectName:AnsiString;

procedure SetThreadName(ThreadDisplayName:AnsiString);
function IsDebuggerPresent: BOOL; stdcall;

implementation

uses Variants, nsInit, nsNetUtil, xxmCommonUtils, ComObj, nsXPCOMGlue;

resourcestring
  SXxmContextStringUnknown='Unknown ContextString __';

function IsDebuggerPresent; external 'kernel32.dll';

procedure SetThreadName(ThreadDisplayName:AnsiString);
var
  ThreadInfo:record
    dwType:LongWord;
    szName:PAnsiChar;
    dwThreadID:LongWord;
    dwFlags:LongWord;
  end;
begin
  if IsDebuggerPresent then
    begin
      ThreadInfo.dwType:=$1000;
      ThreadInfo.szName:=PAnsiChar(ThreadDisplayName);
      ThreadInfo.dwThreadID:=LongWord(-1);//calling thread
      ThreadInfo.dwFlags:=0;
      try
        RaiseException($406D1388,0,SizeOf(ThreadInfo) div SizeOf(LongWord),@ThreadInfo);
      except
        //
      end;
    end;
end;

{ TxxmChannel }

constructor TxxmChannel.Create(aURI: nsIURI);
var
  x:IInterfacedUTF8String;
begin
  x:=NewUTF8String;
  aURI.GetSpec(x.AUTF8String);
  inherited Create(UTF8Decode(x.ToString));
  FOwner:=nil;
  FLoadGroup:=nil;
  FLoadFlags:=0;//?
  FListener:=nil;
  FCallBacks:=nil;
  FURI:=aURI;
  FOrigURI:=aURI;
  FDocURI:=nil;
  FReferer:=nil;
  FGotSessionID:=false;
  FData:=TMemoryStream.Create;
  InitializeCriticalSection(FLock);
  FReportPending:=false;
  FOutputSize:=0;
  FReportSize:=0;
  FTotalSize:=0;
  FExportSize:=0;
  //FRequestHeaders is TResponseHeaders because data is set later
  //and because TResponseHeaders has full IxxmDictionaryEx implementation
  FRequestHeaders:=TResponseHeaders.Create();
  (FRequestHeaders as IUnknown)._AddRef;
  FResponseHeaders:=TResponseHeaders.Create;
  (FResponseHeaders as IUnknown)._AddRef;
  FCookieParsed:=false;
  FSuspendCount:=1;//see AsyncOpen, TxxmListenerCaller/lcActivate
  FConnected:=false;//see AsyncOpen
  FComplete:=false;
  FAllowPipelining:=true;//?
  FStatus:=NS_OK;
  FVerb:='GET';//default, see SetRequestMethod
  FResponseHeaders['Content-Type']:='text/html';//default (setting?)
  FResponseHeaders['Content-Charset']:='utf-8';//used by GetContentCharset/SetContentCharset
  FQueryString:='';//parsed from URL
  FRedirectionLimit:=32;//set later?
  FRedirectChannel:=nil;
end;

destructor TxxmChannel.Destroy;
begin
  FOwner:=nil;
  FListenerContext:=nil;
  FListener:=nil;
  FCallBacks:=nil;
  FOrigURI:=nil;
  FDocURI:=nil;
  FReferer:=nil;
  FURI:=nil;
  //assert not ReportPending
  FData.Free;
  DeleteCriticalSection(FLock);
  (FRequestHeaders as IUnknown)._Release;
  FRequestHeaders:=nil;
  (FResponseHeaders as IUnknown)._Release;
  FResponseHeaders:=nil;
  inherited;
end;

function TxxmChannel.Open: nsIInputStream;
begin
  //deprecated: use AsyncOpen
  Result:=nil;
  raise EInvalidOperation.Create('Not implemented');
end;

procedure TxxmChannel.AsyncOpen(aListener: nsIStreamListener;
  aContext: nsISupports);
var
  CompMgr:nsIComponentManager;
  ThMgr:nsIThreadManager;
begin
  FConnected:=true;
  FListener:=aListener;
  FListenerContext:=aContext;
  FReportToThread:=NS_GetCurrentThread;
  if FLoadGroup<>nil then FLoadGroup.AddRequest(Self as nsIRequest,nil);
  NS_GetComponentManager(CompMgr);
  CompMgr.CreateInstanceByContractID(NS_THREADMANAGER_CONTRACTID,nil,nsIThreadManager,ThMgr);
  FReportToThread:=ThMgr.currentThread;
  GeckoLoaderPool.Queue(Self);
end;

procedure TxxmChannel.Execute;
var
  i,j,l:integer;
  x:WideString;
begin
  //called from TXxmGeckoLoader
  try
    //TODO: use FLoadFlags?

    //parse URL
    //TODO: use FURI?
    l:=Length(FURL);
    i:=1;
    while (i<=l) and (FURL[i]<>':') do inc(i); //skip "xxm://"
    inc(i);
    if FURL[i]='/' then inc(i);
    if FURL[i]='/' then inc(i);
    j:=i;
    while (i<=l) and not(char(FURL[i]) in ['/','?','&','$','#']) do inc(i);
    //if server then remote?
    FProjectName:=Copy(FURL,j,i-j);
    if FProjectName='' then
     begin
      FProjectName:=DefaultProjectName;
      FURL:=Copy(FURL,1,j-1)+FProjectName+Copy(FURL,i,Length(FURL)-i+1);
      FURI.SetSpec(NewCString(FURL).ACString);
     end;
    FPageClass:='['+FProjectName+']';
    if (i>l) then
     begin
      FURL:=FURL+'/';
      FURI.SetSpec(NewCString(FURL).ACString);
      inc(l);
     end;
    if (FURL[i]='/') then inc(i);

    j:=i;
    while (i<=l) and not(char(FURL[i]) in ['?','&','$','#']) do inc(i);
    FFragmentName:=Copy(FURL,j,i-j);
    if (FURL[i]='?') then inc(i);
    j:=i;
    while (j<=l) and (FURL[j]<>'#') do inc(j);
    FQueryString:=Copy(FURL,i,j-i);

    //activate
    Resume;

    BuildPage;

  except
    on EXxmPageRedirected do
     begin
      ForceStatus(301,'Moved Permanently');
      //SendHTML('Redirected to <a href=""></a>')?
     end;

    on EXxmAutoBuildFailed do
     begin
      //assert AutoBuild handler already displays message
      ForceStatus(StatusBuildError,'BUILDFAILED');
     end;

    on e:Exception do
     begin
      ForceStatus(StatusException,'ERROR');
      //TODO: get fragment 500.xxm?
      try
        if FPostData=nil then x:='none' else x:=IntToStr(FPostData.Size)+' bytes';
      except
        x:='unknown';
      end;
      SendError('error',[
        'URL',HTMLEncode(FURL),
        'CLASS',FPageClass,
        'POSTDATA',x,
        'QUERYSTRING',FQueryString,
        'ERROR',HTMLEncode(e.Message),
        'ERRORCLASS',e.ClassName,
        'VERSION',ContextString(csVersion)
      ]);
     end;
  end;

  try
    if FConnected and not(FReportPending) then
     begin
      CheckSuspend;
      FReportToThread.dispatch(TxxmListenerCaller.Create(Self,lcStop,0,0),NS_DISPATCH_NORMAL);//_SYNC?
      FConnected:=false;
     end;
  except
    //silent!
  end;

  FComplete:=true;
end;

function TxxmChannel.GetProjectEntry(ProjectName: WideString):TXxmProjectEntry;
begin
  if XxmProjectCache=nil then XxmProjectCache:=TXxmProjectCache.Create;
  Result:=XxmProjectCache.GetProject(ProjectName);
end;

procedure TxxmChannel.GetName(aName: nsAUTF8String);
var
  x:UTF8String;
begin
  x:=UTF8Encode(FURL);
  NS_CStringSetData(aName,PAnsiChar(x),Length(x));
end;

function TxxmChannel.GetURI: nsIURI;
begin
  Result:=FURI;
end;

function TxxmChannel.GetRequestSucceeded: PRBool;
begin
  Result:=StatusCode=200;//FStatus=NS_OK?
  //Result:=StatusCode in [200,404,500]??
end;

function TxxmChannel.GetStatus: nsresult;
begin
  Result:=FStatus;
end;

function TxxmChannel.GetResponseStatus: PRUint32;
begin
  //CheckHeaderNotSent;?
  Result:=StatusCode;
end;

procedure TxxmChannel.GetResponseStatusText(
  aResponseStatusText: nsACString);
begin
  //CheckHeaderSent;?
  SetCString(aResponseStatusText,StatusText);
end;

function TxxmChannel.GetSecurityInfo: nsISupports;
begin
  Result:=nil;
  //TODO: find out more!
  //http://mxr.mozilla.org/firefox/source/netwerk/base/public/nsIChannel.idl#111
end;

function TxxmChannel.IsNoCacheResponse: PRBool;
begin
  //TODO
  Result:=(SingleFileSent='');
end;

function TxxmChannel.IsNoStoreResponse: PRBool;
begin
  //TODO: ?
  Result:=(SingleFileSent='');
end;

procedure TxxmChannel.Cancel(aStatus: nsresult);
begin
  //TODO: test here
  if FConnected then FReportToThread.dispatch(TxxmListenerCaller.Create(Self,lcAbort,0,0),NS_DISPATCH_NORMAL);//_SYNC?
  FStatus:=aStatus;
  FConnected:=false;
end;

function TxxmChannel.GetAllowPipelining: PRBool;
begin
  Result:=FAllowPipelining;
end;

procedure TxxmChannel.SetAllowPipelining(aAllowPipelining: PRBool);
begin
  FAllowPipelining:=aAllowPipelining;
end;

procedure TxxmChannel.GetContentCharset(aContentCharset: nsACString);
begin
  SetCString(aContentCharset,FResponseHeaders['Content-Charset']);
end;

procedure TxxmChannel.SetContentCharset(const aContentCharset: nsACString);
begin
  CheckHeaderNotSent;
  FAutoEncoding:=aeContentDefined;
  FResponseHeaders['Content-Charset']:=GetCString(aContentCharset);
end;

function TxxmChannel.GetContentLength: Integer;
begin
  //TODO:
  //check FComplete?
  Result:=FTotalSize;
end;

procedure TxxmChannel.SetContentLength(aContentLength: Integer);
begin
  raise EInvalidOperation.Create('Not implemented');
end;

procedure TxxmChannel.GetContentType(aContentType: nsACString);
begin
  SetCString(aContentType,FContentType);
end;

procedure TxxmChannel.SetContentType(const aContentType: nsACString);
begin
  SetContentType(GetCString(aContentType));
end;

function TxxmChannel.GetLoadFlags: nsLoadFlags;
begin
  Result:=FLoadFlags;
end;

procedure TxxmChannel.SetLoadFlags(aLoadFlags: nsLoadFlags);
begin
  FLoadFlags:=aLoadFlags;
end;

function TxxmChannel.GetLoadGroup: nsILoadGroup;
begin
  Result:=FLoadGroup;
end;

procedure TxxmChannel.SetLoadGroup(aLoadGroup: nsILoadGroup);
begin
  //TODO: unregister if not nil?
  FLoadGroup:=aLoadGroup;
end;

function TxxmChannel.GetNotificationCallbacks: nsIInterfaceRequestor;
begin
  Result:=FCallBacks;
end;

procedure TxxmChannel.SetNotificationCallbacks(
  aNotificationCallbacks: nsIInterfaceRequestor);
begin
  FCallBacks:=aNotificationCallbacks;
  //TODO: nsIProgressEventSink, nsIPrompt, nsIAuthPrompt/nsIAuthPrompt2
  //if aNotificationCallbacks.GetInterface()=NS_NOINTERFACE then :=nil;
end;

function TxxmChannel.GetOriginalURI: nsIURI;
begin
  Result:=FOrigURI;
end;

procedure TxxmChannel.SetOriginalURI(aOriginalURI: nsIURI);
begin
  FOrigURI:=aOriginalURI;
end;

function TxxmChannel.GetOwner: nsISupports;
begin
  Result:=FOwner;
end;

procedure TxxmChannel.SetOwner(aOwner: nsISupports);
begin
  FOwner:=aOwner;
end;

function TxxmChannel.GetRedirectionLimit: PRUint32;
begin
  Result:=FRedirectionLimit;
end;

procedure TxxmChannel.SetRedirectionLimit(aRedirectionLimit: PRUint32);
begin
  FRedirectionLimit:=aRedirectionLimit;
end;

function TxxmChannel.GetReferrer: nsIURI;
begin
  Result:=FReferer;
end;

procedure TxxmChannel.SetReferrer(aReferrer: nsIURI);
var
  x:IInterfacedUTF8String;
begin
  FReferer:=aReferrer;
  x:=NewUTF8String;
  aReferrer.GetSpec(x.AUTF8String);
  FRequestHeaders['Referer']:=UTF8Decode(x.ToString);
end;

function TxxmChannel.GetRequestHeader(
  const aHeader: nsACString): nsACString;
begin
  SetCString(Result,FRequestHeaders[GetCString(aHeader)]);
end;

procedure TxxmChannel.SetRequestHeader(const aHeader, aValue: nsACString;
  aMerge: PRBool);
begin
  if aMerge then
    FRequestHeaders[GetCString(aHeader)]:=GetCString(aValue)
  else
    FRequestHeaders.Add(GetCString(aHeader),GetCString(aValue));
end;

procedure TxxmChannel.GetRequestMethod(aRequestMethod: nsACString);
begin
  SetCString(aRequestMethod,FVerb);
end;

procedure TxxmChannel.SetRequestMethod(const aRequestMethod: nsACString);
begin
  FVerb:=GetCString(aRequestMethod);
end;

function TxxmChannel.GetResponseHeader(
  const header: nsACString): nsACString;
begin
  SetCString(Result,FResponseHeaders[GetCString(header)]);
end;

procedure TxxmChannel.SetResponseHeader(const header, value: nsACString;
  merge: PRBool);
begin
  if not(merge) then raise Exception.Create('set header without merge not supported');
  FResponseHeaders[GetCString(header)]:=GetCString(value);
end;

procedure TxxmChannel.AddResponseHeader(Name, Value: WideString);
begin
  FResponseHeaders[Name]:=Value;
end;

function TxxmChannel.IsPending: PRBool;
begin
  Result:=FComplete;
end;

procedure TxxmChannel.Suspend;
begin
  InterlockedIncrement(FSuspendCount);
  //raise EInvalidOperation.Create('Not implemented');
end;

procedure TxxmChannel.Resume;
begin
  if FSuspendCount<=0 then raise Exception.Create('Can''t resume, not suspended') else
    InterlockedDecrement(FSuspendCount);
  //raise EInvalidOperation.Create('Not implemented');
end;

procedure TxxmChannel.VisitRequestHeaders(aVisitor: nsIHttpHeaderVisitor);
var
  i:integer;
begin
  for i:=0 to FRequestHeaders.Count-1 do
    aVisitor.VisitHeader(
      NewCString(FRequestHeaders.Name[i]).ACString,
      NewCString(FRequestHeaders.Item[i]).ACString);
end;

procedure TxxmChannel.VisitResponseHeaders(aVisitor: nsIHttpHeaderVisitor);
var
  i:integer;
begin
  for i:=0 to FResponseHeaders.Count-1 do
    aVisitor.VisitHeader(
      NewCString(FResponseHeaders.Name[i]).ACString,
      NewCString(FResponseHeaders.Item[i]).ACString);
end;

//IxxmContext

function TxxmChannel.Connected: boolean;
begin
  //TODO: test this!
  Result:=FConnected;
end;

function TxxmChannel.ContextString(cs: TXxmContextString): WideString;
begin
  case cs of
    csVersion:
      Result:=SelfVersion;
    csExtraInfo:
      Result:='';//???
    csVerb:
      Result:=FVerb;
    csQueryString:
      Result:=FQueryString;
    csUserAgent:
      Result:=FRequestHeaders['user-agent'];
    csAcceptedMimeTypes:
      Result:=FRequestHeaders['accept-mime-type'];
    csPostMimeType:
      Result:=FRequestHeaders['content-type'];
    csURL:
      Result:=FURL;//FURI.GetSpec?
    csReferer:
      Result:=FRequestHeaders['referer'];
    csLanguage:
      Result:=FRequestHeaders['accept-language'];
    csRemoteAddress:
      Result:='127.0.0.1';//TODO: IPV6?
    csRemoteHost:
      Result:='localhost';
    csAuthUser:
      //TODO: GetUserNameEx?
      Result:=GetEnvironmentVariable('USERDOMAIN')+'\'+GetEnvironmentVariable('USERNAME');
    csAuthPassword:
      Result:='';
    csProjectName:
      Result:=FProjectName;
    csLocalURL:
      Result:=FFragmentName;
    else
      raise EXxmContextStringUnknown.Create(StringReplace(
        SXxmContextStringUnknown,'__',IntToHex(integer(cs),8),[]));
  end;
end;

procedure TxxmChannel.DispositionAttach(FileName: WideString);
var
  x:WideString;
  i:integer;
begin
  x:=FileName;
  for i:=1 to Length(x) do if x[i]='"' then x[i]:='_';
  FResponseHeaders['Content-Disposition']:='attachment; filname="'+x+'"';
end;

function TxxmChannel.GetCookie(Name: WideString): WideString;
begin
  if not(FCookieParsed) then
   begin
    FCookie:=FRequestHeaders['Cookie'];
    SplitHeaderValue(FCookie,0,Length(FCookie),FCookieIdx);
    FCookieParsed:=true;
   end;
  Result:=GetParamValue(FCookie,FCookieIdx,Name);
end;

function TxxmChannel.GetSessionID: WideString;
begin
  if not FGotSessionID then CheckHeaderNotSent;
  FGotSessionID:=true;
  Result:=IntToHex(HInstance,8)+IntToHex(GetCurrentProcessId,8);
end;

procedure TxxmChannel.Redirect(RedirectURL: WideString; Relative: boolean);
const
  NS_BINDING_REDIRECTED=$804B000A;//1 shl 31 or ($45+6) shl 16 or 10
  NS_ERROR_REDIRECT_LOOP=$804B0020;//1 shl 31 or ($45+6) shl 16 or 32
var
  u:nsIURI;
  x:IInterfacedCString;
begin
  //TODO:
  //if 307 then forward as POST else as GET? (see RedirectSync)

  if FRedirectionLimit=0 then
   begin
    Cancel(NS_ERROR_REDIRECT_LOOP);
    raise Exception.Create('Redirection limit reached');
   end;

  x:=NewCString;
  u:=FURI.Clone;
  if Relative then
    FURI.Resolve(NewCString(RedirectURL).ACString,x.ACString)
  else
    x.Assign(RedirectURL);
  u.SetSpec(x.ACString);

  FRedirectChannel:=NS_GetIOService.NewChannelFromURI(u);

  FReportToThread.dispatch(TxxmListenerCaller.Create(Self,lcRedirect,0,0),NS_DISPATCH_NORMAL);

  FStatus:=integer(NS_BINDING_REDIRECTED);
  FConnected:=false;
  raise EXxmPageRedirected.Create(x.ToString);

  //TODO: PromptTempRedirect?
end;

procedure TxxmChannel.RedirectSync;
const
  LOAD_REPLACE=$40000;//1 shl 18
var
  h:nsIHttpChannel;
  hi:nsIHttpChannelInternal;
  uc:nsIUploadChannel;
  inst:nsIInputStream;
begin
  try
    //http://mxr.mozilla.org/mozilla2.0/source/netwerk/base/src/nsBaseChannel.cpp#107

    FRedirectChannel.OriginalURI:=FOrigURI;
    FRedirectChannel.LoadGroup:=FLoadGroup;
    FRedirectChannel.NotificationCallbacks:=FCallBacks;
    FRedirectChannel.LoadFlags:=FLoadFlags or LOAD_REPLACE;
    if FRedirectChannel.QueryInterface(NS_IHTTPCHANNEL_IID,h)=S_OK then
     begin
      //h.SetRequestMethod(NewCString('GET').ACString);//FVerb?
      if FReferer<>nil then h.Referrer:=FReferer;
      h.AllowPipelining:=FAllowPipelining;
      h.RedirectionLimit:=FRedirectionLimit-1;
      h:=nil;
     end;

    //if FVerb='POST'?
    if FRedirectChannel.QueryInterface(NS_IUPLOADCHANNEL_IID,uc)=S_OK then
     begin
      if FPostData<>nil then
       begin
        inst:=(FPostData as TxxmGeckoUploadStream).InputStream;
        (inst as nsISeekableStream).seek(NS_SEEK_SET,0);
        uc.SetUploadStream(inst,NewCString('').ACString,-1);
       end;
      uc:=nil;
     end;

    if FRedirectChannel.QueryInterface(NS_IHTTPCHANNELINTERNAL_IID,hi)=S_OK then
     begin
      hi.SetDocumentURI(FDocURI);
      hi:=nil;
     end;

    //nsIEncodedChannel?
    //nsIResumableChannel?
    //nsIWritablePropertyBag, CopyProperties?

    try
      if FCallBacks<>nil then
        (FCallBacks as nsIChannelEventSink).onChannelRedirect(Self,
          FRedirectChannel,REDIRECT_PERMANENT);//temporary?
    except
      //silent?
    end;

    FRedirectChannel.AsyncOpen(FListener,FListenerContext);//???

  finally
    FRedirectChannel:=nil;
  end;
end;

procedure TxxmChannel.SendStream(s: IStream);
const
  SendBufferSize=$10000;
var
  l:integer;
  d:array[0..SendBufferSize-1] of byte;
begin
  inherited;
  //if s.Size<>0 then
   begin
    CheckSendStart; //SendHeader out of lock
    //no autoencoding here!
    l:=SendBufferSize;
    repeat
      Lock;
      try
        OleCheck(s.Read(@d[0],l,@l));
        Write(d[0],l);
      finally
        Unlock;
      end;
      ReportData;
    until (l<>SendBufferSize) or not(FConnected);
   end;
end;

procedure TxxmChannel.SendHeader;
begin
  //assert not in Lock
  if FConnected then
   begin
    CheckSuspend;
    FResponseHeaders['Content-Type']:=FContentType;
    FReportToThread.dispatch(TxxmListenerCaller.Create(Self,lcStart,0,0),NS_DISPATCH_NORMAL);
   end;
end;

procedure TxxmChannel.SetCookie(Name, Value: WideString);
begin
  CheckHeaderNotSent;
  //check name?
  //TODO: "quoted string"?
  FResponseHeaders['Cache-Control']:='no-cache="set-cookie"';
  FResponseHeaders.Add('Set-Cookie',Name+'="'+Value+'"');
end;

procedure TxxmChannel.SetCookie(Name, Value: WideString;
  KeepSeconds: cardinal; Comment, Domain, Path: WideString; Secure,
  HttpOnly: boolean);
var
  x:WideString;
begin
  CheckHeaderNotSent;
  //check name?
  //TODO: "quoted string"?
  FResponseHeaders['Cache-Control']:='no-cache="set-cookie"';
  x:=Name+'="'+Value+'"';
  //'; Version=1';
  if Comment<>'' then
    x:=x+'; Comment="'+Comment+'"';
  if Domain<>'' then
    x:=x+'; Domain="'+Domain+'"';
  if Path<>'' then
    x:=x+'; Path="'+Path+'"';
  x:=x+'; Max-Age='+IntToStr(KeepSeconds)+
    '; Expires="'+RFC822DateGMT(Now+KeepSeconds/86400)+'"';
  if Secure then
    x:=x+'; Secure'+#13#10;
  if HttpOnly then
    x:=x+'; HttpOnly'+#13#10;
  FResponseHeaders.Add('Set-Cookie',x);
  //TODO: Set-Cookie2
end;

{
procedure TxxmChannel.nsGetInterface(const uuid: TGUID; out _result);
begin
  if not(GetInterface(uuid,_result)) then
    raise EIntfCastError.Create('Interface not supported');
end;
}

procedure TxxmChannel.CheckSuspend;
begin
  while FSuspendCount<>0 do Sleep(5);
end;

const
  Utf8ByteOrderMark=#$EF#$BB#$BF;
  Utf16ByteOrderMark=#$FF#$FE;

procedure TxxmChannel.SendRaw(Data: WideString);
var
  s:AnsiString;
  startdata:boolean;
begin
  inherited;
  if Data<>'' then
   begin
    startdata:=CheckSendStart; //SendHeader outside of lock
    Lock;
    try
      if startdata then
        case FAutoEncoding of
          aeUtf8:Write(Utf8ByteOrderMark,3);
          aeUtf16:Write(Utf16ByteOrderMark,2);
        end;
      case FAutoEncoding of
        aeUtf16:Write(Data[1],Length(Data)*2);
        aeUtf8:
         begin
          s:=UTF8Encode(Data);
          Write(s[1],Length(s));
         end;
        else
         begin
          s:=Data;
          Write(s[1],Length(s));
         end;
        end;
      ReportData;
    finally
      Unlock;
    end;
   end;
end;

procedure TxxmChannel.ReportData;
begin
  //assert within Lock/Unlock try/finally!
  if FConnected and not(FReportPending) and (FReportSize<>0) then
   begin
    CheckSuspend;//is this no problem inside of lock?
    FReportPending:=true;
    FReportToThread.dispatch(TxxmListenerCaller.Create(Self,lcData,0,FReportSize),NS_DISPATCH_NORMAL);
   end;
end;

procedure TxxmChannel.Lock;
begin
  EnterCriticalSection(FLock);
end;

procedure TxxmChannel.Unlock;
begin
  LeaveCriticalSection(FLock);
end;

function TxxmChannel.Write(const Buffer; Count: Integer): Longint;
begin
  //assert between Lock/Unlock try/finally calls!
  FData.Position:=FOutputSize;
  Result:=FData.Write(Buffer,Count);
  //Result=Count
  FOutputSize:=FOutputSize+Result;
  FTotalSize:=FTotalSize+Result;
  FReportSize:=FReportSize+Result;
end;

function TxxmChannel.Available: Cardinal;
begin
  Result:=FReportSize;
end;

procedure TxxmChannel.Close;
begin
  FConnected:=false;
  //raise Exception.Create('Closing stream not supported.');
end;

function TxxmChannel.IsNonBlocking: LongBool;
begin
  Result:=true;//????
end;

function TxxmChannel.Read(aBuf: PAnsiChar; aCount: Cardinal): Cardinal;
begin
  Lock;
  try
    //assert aCount is size of data reported
    FData.Position:=FExportSize;
    Result:=FData.Read(aBuf^,aCount);
    //assert Result=aCount
    FExportSize:=FExportSize+Result;
    if aCount>FReportSize then FReportSize:=0 else FReportSize:=FReportSize-aCount;
    if FExportSize=FOutputSize then
     begin
      //assert FReportSize=0
      FOutputSize:=0; //don't set size, this saves on allocations
      FExportSize:=0;
     end;
    ReadCheck;
  finally
    Unlock;
  end;
end;

function TxxmChannel.ReadSegments(aWriter: nsWriteSegmentFun;
  aClosure: Pointer; aCount: Cardinal): Cardinal;
var
  p:pointer;
begin
  Lock;
  try
    //assert aCount is size of data reported
    p:=FData.Memory;
    inc(integer(p),FExportSize);
    aWriter(Self,aClosure,p,0,aCount,Result);
    //assert Result=aCount
    FExportSize:=FExportSize+Result;
    if aCount>FReportSize then FReportSize:=0 else FReportSize:=FReportSize-aCount;
    if FExportSize=FOutputSize then
     begin
      //assert FReportSize=0
      FOutputSize:=0; //don't set size, this saves on allocations
      FExportSize:=0;
     end;
    ReadCheck;
  finally
    Unlock;
  end;
end;

procedure TxxmChannel.ReadCheck;
begin
  //don't call CheckSuspend here, since called from main thread!
  FReportPending:=false;
  if FConnected then
    if FReportSize=0 then
     begin
      if FComplete then
       begin
        FReportToThread.dispatch(TxxmListenerCaller.Create(Self,lcStop,0,0),NS_DISPATCH_NORMAL);
        FConnected:=false;
       end;
     end
    else
      if FSuspendCount=0 then
       begin
        FReportPending:=true;
        FReportToThread.dispatch(TxxmListenerCaller.Create(Self,lcData,0,FReportSize),NS_DISPATCH_NORMAL);
       end;
end;

function TxxmChannel.GetRequestHeaders: IxxmDictionaryEx;
begin
  Result:=FRequestHeaders;
end;

function TxxmChannel.GetResponseHeaders: IxxmDictionaryEx;
begin
  Result:=FResponseHeaders;
end;

function TxxmChannel.GetUploadStream: nsIInputStream;
begin
  Result:=(FPostData as TxxmGeckoUploadStream).InputStream;
end;

procedure TxxmChannel.SetUploadStream(aStream: nsIInputStream;
  const aContentType: nsACString; aContentLength: PRInt32);
var
  ct:AnsiString;
begin
  if @aContentType=nil then ct:='' else ct:=GetCString(aContentType);
  FPostData:=TxxmGeckoUploadStream.Create(aStream);
  if aContentLength<>-1 then FRequestHeaders['Content-Length']:=IntToStr(aContentLength);
  //if aContentLength=-1 then aStream.Available?
  if ct='' then
    (FPostData as TxxmGeckoUploadStream).ParseHeader(FRequestHeaders)
  else
    FRequestHeaders['Content-Type']:=ct;
end;

function TxxmChannel.GetDocumentURI: nsIURI;
begin
  Result:=FDocURI;
end;

procedure TxxmChannel.SetDocumentURI(aDocumentURI: nsIURI);
begin
  FDocURI:=aDocumentURI;
end;

procedure TxxmChannel.getRequestVersion(var major, minor: PRUint32);
begin
  //fake HTTP/1.1
  major:=1;
  minor:=1;
end;

procedure TxxmChannel.getResponseVersion(var major, minor: PRUint32);
begin
  //fake HTTP/1.1
  major:=1;
  minor:=1;
end;

procedure TxxmChannel.SetCookieHttpInt(aCookieHeader: PAnsiChar);
begin
  //TODO:
  raise EInvalidOp.Create('Not implemented');
end;

procedure TxxmChannel.setupFallbackChannel(aFallbackKey: PAnsiChar);
begin
  //TODO:
  raise EInvalidOp.Create('Not implemented');
end;

{ TXxmGeckoLoader }

constructor TXxmGeckoLoader.Create;
begin
  inherited Create(false);
  //FInUse:=false;
end;

procedure TXxmGeckoLoader.Execute;
var
  Channel:TxxmChannel;
begin
  CoInitialize(nil);
  SetErrorMode(SEM_FAILCRITICALERRORS);
  while not(Terminated) do
   begin
    Channel:=GeckoLoaderPool.Unqueue;
    if Channel=nil then
     begin
      FInUse:=false;//used by PageLoaderPool.Queue
      SetThreadName('(xxmPageLoader)');
      Suspend;
      FInUse:=true;
     end
    else
     begin
      Sleep(10);//let AsyncOpen return...
      SetThreadName('xxmPageLoader:'+Channel.FURL);
      Channel.Execute;//assert all exceptions handled!
      Channel._Release;
     end;
   end;
  //CoUninitialize;
end;

{ TXxmGeckoLoaderPool }

constructor TXxmGeckoLoaderPool.Create;
begin
  inherited Create;
  FLoadersSize:=0;
  FQueue:=nil;
  InitializeCriticalSection(FLock);
  SetSize(PoolMaxThreads);//TODO: setting
  //TODO: setting no pool
end;

destructor TXxmGeckoLoaderPool.Destroy;
begin
  SetSize(0);
  DeleteCriticalSection(FLock);
  inherited;
end;

procedure TXxmGeckoLoaderPool.SetSize(x: integer);
begin
  EnterCriticalSection(FLock);
  try
    if FLoadersSize<x then
     begin
      SetLength(FLoaders,x);
      while FLoadersSize<>x do
       begin
        FLoaders[FLoadersSize]:=nil;
        inc(FLoadersSize);
       end;
     end
    else
     begin
      while FLoadersSize<>x do
       begin
        dec(FLoadersSize);
        //FreeAndNil(FLoaders[FLoadersSize]);
        if FLoaders[FLoadersSize]<>nil then
         begin
          FLoaders[FLoadersSize].FreeOnTerminate:=true;
          FLoaders[FLoadersSize].Terminate;
          FLoaders[FLoadersSize].Resume;
          FLoaders[FLoadersSize]:=nil;
         end;
       end;
      SetLength(FLoaders,x);
     end;
    //if FLoaderIndex>=FLoadersSize then FLoaderIndex:=0;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TXxmGeckoLoaderPool.Queue(Channel: TxxmChannel);
var
  c:TxxmChannel;
  i:integer;
begin
  EnterCriticalSection(FLock);
  try
    //add to queue
    Channel._AddRef;
    if FQueue=nil then FQueue:=Channel else
     begin
      c:=FQueue;
      while c.Queue<>nil do c:=c.Queue;
      c.Queue:=Channel;
     end;
  finally
    LeaveCriticalSection(FLock);
  end;

  //fire thread
  //TODO: see if a rotary index matters in any way
  i:=0;
  while (i<FLoadersSize) and (FLoaders[i]<>nil) and FLoaders[i].InUse do inc(i);
  if i=FLoadersSize then
   begin
    //pool full, leave on queue
   end
  else
   begin
    if FLoaders[i]=nil then
      FLoaders[i]:=TxxmGeckoLoader.Create //start thread
    else
      FLoaders[i].Resume; //resume on waiting unqueues
    //TODO: expire unused threads on low load
   end;
end;

function TXxmGeckoLoaderPool.Unqueue: TxxmChannel;
begin
  if FQueue=nil then Result:=nil else
   begin
    EnterCriticalSection(FLock);
    try
      Result:=FQueue;
      if Result<>nil then
       begin
        FQueue:=FQueue.Queue;
        Result.Queue:=nil;
       end;
    finally
      LeaveCriticalSection(FLock);
    end;
   end;
end;

{ TxxmListenerCaller }

const
  lcName:array[TxxmListenerCall] of string=(
    'SyncActivate',
    'OnStartRequest',
    'OnDataAvailable',
    'OnStopRequest',
    'SyncAbort',
    'SyncRedirect');

constructor TxxmListenerCaller.Create(Owner: TxxmChannel;
  Call: TxxmListenerCall;Offset,Count:cardinal);
begin
  inherited Create;
  FOwner:=Owner;
  FOwner._AddRef;
  FCall:=Call;
  FOffset:=Offset;
  FCount:=Count;
end;

destructor TxxmListenerCaller.Destroy;
begin
  FOwner._Release;
  //if FCall=lcStop then FOwner._Release;
  inherited;
end;

procedure TxxmListenerCaller.run;
begin
  case FCall of
    lcActivate:FOwner.Resume;
    lcStart:FOwner.FListener.OnStartRequest(FOwner,FOwner.FListenerContext);
    lcData:FOwner.FListener.OnDataAvailable(FOwner,FOwner.FListenerContext,FOwner,FOffset,FCount);
    lcStop:FOwner.FListener.OnStopRequest(FOwner,FOwner.FListenerContext,FOwner.StatusCode);
    lcRedirect:FOwner.RedirectSync;
  end;
  if (FCall in [lcStop,lcAbort,lcRedirect]) and (FOwner.FLoadGroup<>nil) then
    FOwner.FLoadGroup.RemoveRequest(FOwner as nsIRequest,nil,NS_OK);
end;

initialization
  GeckoLoaderPool:=TXxmGeckoLoaderPool.Create;
finalization
  FreeAndNil(GeckoLoaderPool);
end.
