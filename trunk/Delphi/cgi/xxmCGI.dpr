program xxmCGI;

uses
  Windows,
  xxmCGIHeader in 'xxmCGIHeader.pas',
  xxmCGIThread in 'xxmCGIThread.pas';

{$APPTYPE CONSOLE}

const
  WM_QUIT             = $0012;

var
  hIn,hPipe,hOut,hSPRoc,hReq,hRes:THandle;
  PipeName,s:string;
  pIn:TForwardThread;
  running:boolean;
  l:cardinal;
  d:array[0..$FFF] of byte;
  ch:TxxmCGIHeader;
begin
  PipeName:='xxm';
  //TODO parse command line

  hIn:=GetStdHandle(STD_INPUT_HANDLE);
  hOut:=GetStdHandle(STD_OUTPUT_HANDLE);
  hPipe:=CreateFile(PChar('\\.\pipe\'+PipeName),GENERIC_READ,0,nil,OPEN_EXISTING,0,0);
  if (hPipe=INVALID_HANDLE_VALUE) or
    not(ReadFile(hPipe,ch,SizeOf(ch),l,nil)) then
   begin
    //TODO: auto-start xxmHost?
    s:='500 ERROR'#13#10'Content-type: text/plain'#13#10#13#10'Error connecting to xxm request handler process'#13#10;
    l:=Length(s);
    WriteFile(hOut,s[1],l,l,nil);
   end
  else
   begin
    //assert l>4 and l=ch.Size
    CloseHandle(hPipe);

    hSPRoc:=OpenProcess(PROCESS_DUP_HANDLE,false,ch.ServerProcessID);
    DuplicateHandle(hSProc,ch.PipeRequest,GetCurrentProcess,@hReq,0,true,DUPLICATE_CLOSE_SOURCE or DUPLICATE_SAME_ACCESS);
    DuplicateHandle(hSPRoc,ch.PipeResponse,GetCurrentProcess,@hRes,0,true,DUPLICATE_CLOSE_SOURCE or DUPLICATE_SAME_ACCESS);

    //TODO: revise thread into async io
    pIn:=TForwardThread.Create(hIn,hReq);
    try

      running:=true;
      while running do
       begin
        l:=$10000;
        if not(ReadFile(hRes,d[0],$1000,l,nil) and WriteFile(hOut,d[0],l,l,nil)) then running:=false;
       end;

    finally
      CloseHandle(hReq);
      CloseHandle(hRes);
      CloseHandle(hIn);//force thread out of ReadFile on hIn
      pIn.Free;
    end;

   end;
end.
