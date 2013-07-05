unit xxmSock;

interface

uses SysUtils, Classes;

{$D-}

type
  TSocketAddress=record
    family:word;
    port:word;
    data:array[0..3] of cardinal;
  end;
  PSocketAddress=^TSocketAddress;

  THostEntry=record
    h_name:PAnsiChar;
    h_aliases:^PAnsiChar;
    h_addrtype:word;
    h_length:word;
    h_addr:^PAnsiChar;
    //TODO: IPv6
  end;
  PHostEntry = ^THostEntry;

  TFDSet = record
    fd_count: cardinal;
    fd_array: array[0..63] of THandle;
  end;
  PFDSet = ^TFDSet;

  TTimeVal = record
    tv_sec: cardinal;
    tv_usec: cardinal;
  end;
  PTimeVal = ^TTimeVal;

type
  TTcpSocket=class(TObject)
  private
    FSocket:THandle;
    FAddr:TSocketAddress;
    FConnected:boolean;
  protected
    constructor Create(ASocket:THandle); overload;
    function GetPort:word;
    function GetAddress:string;
    function GetHostName:string;
  public
    constructor Create; overload;
    destructor Destroy; override;
    procedure Connect(const Address:AnsiString;Port:word);
    procedure Disconnect;
    function ReceiveBuf(var Buf; BufSize: Integer): Integer;
    function SendBuf(var Buf; BufSize: Integer): Integer;
    property Handle:THandle read FSocket;
    property Connected:boolean read FConnected;
    property Port:word read GetPort;
    property Address:string read GetAddress;
    property HostName:string read GetHostName;
  end;

  TTcpServer=class(TObject)
  private
    FSocket:THandle;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Bind(const Address:AnsiString;Port:word);
    procedure Listen;
    procedure WaitForConnection;
    function Accept:TTcpSocket;
    property Handle:THandle read FSocket;
  end;

  ETcpSocketError=class(Exception);

function WSAStartup(wVersionRequired: word; WSData: pointer): integer; stdcall;
function WSACleanup: integer; stdcall;
function WSAGetLastError: integer; stdcall;
function htons(hostshort: word): word; stdcall;
function inet_addr(cp: PAnsiChar): cardinal; stdcall;
function inet_ntoa(inaddr: cardinal): PAnsiChar; stdcall;
function gethostbyaddr(addr: pointer; len, Struct: integer): PHostEntry; stdcall;
function gethostbyname(name: PAnsiChar): PHostEntry; stdcall;
//TODO: getaddrinfo
function socket(af, Struct, protocol: integer): THandle; stdcall;
function setsockopt(s: THandle; level, optname: integer; optval: PAnsiChar;
  optlen: integer): integer; stdcall;
function listen(socket: THandle; backlog: integer): integer; stdcall;
function bind(s: THandle; var addr: TSocketAddress; namelen: integer): integer; stdcall;
function accept(s: THandle; addr: PSocketAddress; addrlen: PInteger): THandle; stdcall;
function connect(s: THandle; var name: TSocketAddress; namelen: integer): integer; stdcall;
function recv(s: THandle; var Buf; len, flags: integer): integer; stdcall;
function select(nfds: integer; readfds, writefds, exceptfds: PFDSet;
  timeout: PTimeVal): integer; stdcall;
function send(s: THandle; var Buf; len, flags: integer): integer; stdcall;
function shutdown(s: THandle; how: integer): integer; stdcall;
function closesocket(s: THandle): integer; stdcall;
//function __WSAFDIsSet(s: THandle; var FDSet: TFDSet): Boolean; stdcall;

const
  INVALID_SOCKET = THandle(not(0));
  AF_INET = 2;
  SOCKET_ERROR = -1;
  SOCK_STREAM = 1;
  IPPROTO_IP = 0;
  SOMAXCONN = 5;
  SOL_SOCKET = $FFFF;
  SO_SNDTIMEO = $1005;
  SO_RCVTIMEO = $1006;
  SD_BOTH = 2;
  IPPROTO_TCP = 6;
  TCP_NODELAY = 1;

implementation

uses Math;

var
  WSAData:record // !!! also WSDATA
    wVersion:word;
    wHighVersion:word;
    szDescription:array[0..256] of AnsiChar;
    szSystemStatus:array[0..128] of AnsiChar;
    iMaxSockets:word;
    iMaxUdpDg:word;
    lpVendorInfo:PAnsiChar;
  end;

procedure RaiseLastWSAError;
begin
  raise ETcpSocketError.Create(SysErrorMessage(WSAGetLastError));
end;

procedure PrepareSockAddr(var addr: TSocketAddress; port: word;
  const host: AnsiString);
var
  e:PHostEntry;
begin
  addr.family:=AF_INET;
  addr.port:=htons(port);
  addr.data[0]:=0;
  addr.data[1]:=0;
  addr.data[2]:=0;
  addr.data[3]:=0;
  //TODO: IPv6
  if host<>'' then
    if char(host[1]) in ['0'..'9'] then
      addr.data[0]:=inet_addr(PAnsiChar(host))
    else
     begin
      //TODO: getaddrinfo
      e:=gethostbyname(PAnsiChar(host));
      if e=nil then RaiseLastWSAError;
      addr.family:=e.h_addrtype;
      Move(e.h_addr^[0],addr.data[0],e.h_length);
     end;
end;

{ TTcpSocket }

procedure TTcpSocket.Connect(const Address: AnsiString; Port: word);
begin
  PrepareSockAddr(FAddr,Port,Address);
  if xxmSock.connect(FSocket,FAddr,SizeOf(TSocketAddress))=SOCKET_ERROR then
    RaiseLastWSAError
  else
    FConnected:=true;
end;

constructor TTcpSocket.Create;
begin
  inherited Create;
  FConnected:=false;
  FSocket:=socket(AF_INET,SOCK_STREAM,IPPROTO_IP);//PF_INET6?
  if FSocket=INVALID_SOCKET then RaiseLastWSAError;
  FillChar(FAddr,SizeOf(TSocketAddress),#0);
end;

constructor TTcpSocket.Create(ASocket: THandle);
var
  i:integer;
begin
  inherited Create;
  FSocket:=ASocket;
  if FSocket=INVALID_SOCKET then RaiseLastWSAError;
  i:=1;
  if setsockopt(FSocket,IPPROTO_TCP,TCP_NODELAY,@i,4)<>0 then
    RaiseLastWSAError;
  FConnected:=true;//?
end;

destructor TTcpSocket.Destroy;
begin
  //Disconnect;?
  closesocket(FSocket);
  inherited;
end;

procedure TTcpSocket.Disconnect;
begin
  if FConnected then
   begin
    FConnected:=false;
    shutdown(FSocket,SD_BOTH);
   end;
end;

function TTcpSocket.GetPort: word;
begin
  Result:=FAddr.port;
end;

function TTcpSocket.GetAddress: string;
begin
  Result:=inet_ntoa(FAddr.data[0]);
end;

function TTcpSocket.GetHostName: string;
var
  e:PHostEntry;
begin
  e:=gethostbyaddr(@FAddr.data[0],SizeOf(TSocketAddress),AF_INET);
  if e=nil then
    Result:=inet_ntoa(FAddr.data[0])
  else
    Result:=e.h_name;
end;

function TTcpSocket.ReceiveBuf(var Buf; BufSize: Integer): Integer;
begin
  Result:=recv(FSocket,Buf,BufSize,0);
  if Result=SOCKET_ERROR then
   begin
    Disconnect;
    RaiseLastWSAError;
   end;
end;

function TTcpSocket.SendBuf(var Buf; BufSize: Integer): Integer;
begin
  Result:=send(FSocket,Buf,BufSize,0);
  if Result=SOCKET_ERROR then
   begin
    Disconnect;
    RaiseLastWSAError;
   end;
end;

{ TTcpServer }

constructor TTcpServer.Create;
begin
  inherited Create;
  FSocket:=socket(AF_INET,SOCK_STREAM,IPPROTO_IP);
  if FSocket=INVALID_SOCKET then RaiseLastWSAError;
end;

destructor TTcpServer.Destroy;
begin
  closesocket(FSocket);
  inherited;
end;

procedure TTcpServer.Bind(const Address: AnsiString; Port: word);
var
  a:TSocketAddress;
begin
  PrepareSockAddr(a,Port,Address);
  if xxmSock.bind(FSocket,a,SizeOf(TSocketAddress))=SOCKET_ERROR then
    RaiseLastWSAError;
end;

procedure TTcpServer.Listen;
begin
  if xxmSock.listen(FSocket,SOMAXCONN)=SOCKET_ERROR then
    RaiseLastWSAError;
end;

procedure TTcpServer.WaitForConnection;
var
  r,x:TFDSet;
begin
  r.fd_count:=1;
  r.fd_array[0]:=FSocket;
  x.fd_count:=1;
  x.fd_array[0]:=FSocket;
  if select(FSocket+1,@r,nil,@x,nil)=SOCKET_ERROR then RaiseLastWSAError;
  if x.fd_count=1 then //if __WSAFDIsSet(FSocket,x) then
    raise ETcpSocketError.Create('Socket in error state');//?
  if r.fd_count=0 then //if not __WSAFDIsSet(FSocket,r) then
    raise ETcpSocketError.Create('Select without error nor result');//??
end;

function TTcpServer.Accept: TTcpSocket;
var
  a:TSocketAddress;
  l:integer;
begin
  l:=SizeOf(TSocketAddress);
  FillChar(a,l,#0);
  Result:=TTcpSocket.Create(xxmSock.accept(FSocket,@a,@l));
  Result.FAddr:=a;
end;

const
  winsockdll='wsock32.dll';

function WSAStartup; external winsockdll;
function WSACleanup; external winsockdll;
function WSAGetLastError; external winsockdll;
function htons; external winsockdll;
function inet_addr; external winsockdll;
function inet_ntoa; external winsockdll;
function gethostbyaddr; external winsockdll;
function gethostbyname; external winsockdll;
function socket; external winsockdll;
function setsockopt; external winsockdll;
function listen; external winsockdll;
function bind; external winsockdll;
function accept; external winsockdll;
function connect; external winsockdll;
function recv; external winsockdll;
function select; external winsockdll;
function send; external winsockdll;
function shutdown; external winsockdll;
function closesocket; external winsockdll;
//function __WSAFDIsSet; external winsockdll;

initialization
  WSAStartup($0101,@WSAData);
finalization
  WSACleanup;
end.
