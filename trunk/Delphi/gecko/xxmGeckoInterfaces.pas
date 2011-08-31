unit xxmGeckoInterfaces;

interface

uses nsXPCOM, nsTypes, nsGeckoStrings;

const
  NS_OK = 0;
  NS_ERR = 1;
  NS_NOENT = 2;

  NS_ISTANDARDURL_CONTRACT='@mozilla.org/network/standard-url;1';
  NS_IHTTPPROTOCOLHANDLER_CONTRACT='@mozilla.org/network/protocol;1?name=http';
  NS_IINPUTSTREAMPUMP_CONTRACT='@mozilla.org/network/input-stream-pump;1';

  URLTYPE_STANDARD     = 1;
  URLTYPE_AUTHORITY    = 2;
  URLTYPE_NO_AUTHORITY = 3;

  NS_SEEK_SET = 0;
  NS_SEEK_CUR = 1;
  NS_SEEK_END = 2;

  REDIRECT_TEMPORARY  = $1;
  REDIRECT_PERMANENT  = $2;
  REDIRECT_INTERNAL   = $4;

type
  nsIMutable = interface(nsISupports)
  ['{321578d0-03c1-4d95-8821-021ac612d18d}']
    function GetMutable(): PRBool; safecall;
    procedure SetMutable(aMutable: PRBool); safecall;
    property Mutable: PRBool read GetMutable write SetMutable;
  end;

  nsIStandardURL = interface(nsIMutable)
  ['{babd6cca-ebe7-4329-967c-d6b9e33caa81}']
    //const URLTYPE_STANDARD        = 1;
    //const URLTYPE_AUTHORITY       = 2;
    //const URLTYPE_NO_AUTHORITY    = 3;
    procedure Init(aUrlType, aDefaultPort: PRInt32;aSpec: nsACString;
      aOriginCharset: PAnsiChar; aBaseURI: nsIURI); safecall;
  end;

  nsISeekableStream = interface(nsISupports)
  ['{8429d350-1040-4661-8b71-f2a6ba455980}']
    //const NS_SEEK_* see above
    procedure seek(whence:PRUint32;offset:PRUint64); safecall;
    function tell:PRUint64; safecall;
    procedure setEOF(); safecall;
  end;

  nsIProgressEventSink = interface(nsISupports)
  ['{d974c99e-4148-4df9-8d98-de834a2f6462}']
    procedure onProgress(aRequest: nsIRequest; aContext: nsISupports;
      aProgress, aProgressMax: PRUint64); safecall;
    procedure onStatus(aRequest: nsIRequest; aContext: nsISupports;
      aStatus: NSRESULT; aStatusArg: PWideChar); safecall;//wstring?
  end;

  nsIAsyncVerifyRedirectCallback = interface(nsISupports)
  ['{8d171460-a716-41f1-92be-8c659db39b45}']
    procedure OnRedirectVerifyCallback(aResult: nsresult); safecall;
  end;

  nsIChannelEventSink = interface(nsISupports)
  ['{a430d870-df77-4502-9570-d46a8de33154}']
    //const REDIRECT_* see above
    procedure onChannelRedirect(oldChannel: nsIChannel;
      newChannel: nsIChannel; flags: PRUint32; callback: nsIAsyncVerifyRedirectCallback); safecall;
  end;

  nsIHttpChannelInternal = interface(nsISupports)
  ['{9363fd96-af59-47e8-bddf-1d5e91acd336}']
    function GetDocumentURI: nsIURI; safecall;
    procedure SetDocumentURI(aDocumentURI: nsIURI); safecall;
    procedure getRequestVersion(var major:PRUint32; var minor:PRUint32); safecall;
    procedure getResponseVersion(var major:PRUint32; var minor:PRUint32); safecall;
    procedure setCookie(aCookieHeader:PAnsiChar); safecall;//string?
    procedure setupFallbackChannel(aFallbackKey:PAnsiChar); safecall;//string?
    function GetForceAllowThirdPartyCookie: PRBool; safecall;
    procedure SetForceAllowThirdPartyCookie(aForceAllowThirdPartyCookie: PRBool); safecall;
    function GetCanceled: PRBool; safecall;
    function GetChannelIsForDownload: PRBool; safecall;
    procedure SetChannelIsForDownload(aChannelIsForDownload: PRBool); safecall;
    procedure GetLocalAddress(aLocalAddress: nsAUTF8String); safecall;
    function GetLocalPort: PRUint32; safecall;
    procedure GetRemoteAddress(aRemoteAddress: nsAUTF8String); safecall;
    function GetRemotePort: PRUint32; safecall;
    procedure setCacheKeysRedirectChain(cacheKeys:pointer); safecall;//StringArray:nsTArray<nsCString>
    procedure HTTPUpgrade(aProtocolName: nsACString; aListener: nsISupports); safecall; //nsIHttpUpgradeListener
  end;

  nsIProtocolHandler = interface;
  nsIProxiedProtocolHandler = interface;
  nsIHttpProtocolHandler = interface;
  nsIProxyInfo = interface end;
  nsIProtocolHandler = interface(nsISupports)
  ['{15fd6940-8ea7-11d3-93ad-00104ba0fd40}']
    procedure GetScheme(aScheme: nsACString); safecall;
    function GetDefaultPort(): PRInt32; safecall;
    property DefaultPort: PRInt32 read GetDefaultPort;
    function GetProtocolFlags(): PRUint32; safecall;
    property ProtocolFlags: PRUint32 read GetProtocolFlags;
    function NewURI(const aSpec: nsACString; const aOriginCharset: PAnsiChar; aBaseURI: nsIURI): nsIURI; safecall;
    function NewChannel(aURI: nsIURI): nsIChannel; safecall;
    function AllowPort(port: PRInt32; const scheme: PAnsiChar): PRBool; safecall;
  end;

  nsIProxiedProtocolHandler = interface(nsIProtocolHandler)
  ['{0a24fed4-1dd2-11b2-a75c-9f8b9a8f9ba7}']
    function NewProxiedChannel(uri: nsIURI; proxyInfo: nsIProxyInfo): nsIChannel; safecall;
  end;

  nsIHttpProtocolHandler = interface(nsIProxiedProtocolHandler)
  ['{9814fdf0-5ac3-11e0-80e3-0800200c9a66}']
    procedure GetUserAgent(aUserAgent: nsACString); safecall;
    procedure GetAppName(aAppName: nsACString); safecall;
    procedure GetAppVersion(aAppVersion: nsACString); safecall;
    procedure GetProduct(aProduct: nsACString); safecall;
    procedure GetProductSub(aProductSub: nsACString); safecall;
    procedure GetPlatform(aPlatform: nsACString); safecall;
    procedure GetOscpu(aOscpu: nsACString); safecall;
    procedure GetMisc(aMisc: nsACString); safecall;
  end;

procedure SetCString(x:nsACString;v:AnsiString);
function GetCString(const x:nsACString):AnsiString;

implementation

uses
  nsInit;

procedure SetCString(x:nsACString;v:AnsiString);
begin
  NS_CStringSetData(x,PAnsiChar(v),Length(v));
end;

function GetCString(const x:nsACString):AnsiString;
var
  l: Longword;
  p: PAnsiChar;
begin
  l:=NS_CStringGetData(x,p);
  SetLength(Result,l);
  Move(p^,PAnsiChar(Result)^,l);
end;

end.
