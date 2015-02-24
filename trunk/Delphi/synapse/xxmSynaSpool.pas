unit xxmSynaSpool;

interface

uses Windows, Classes, xxmSynaMain;

type
  TXxmSpoolingConnections=class(TThread)
  private
    FLock:TRTLCriticalSection;
    FAddEvent:THandle;
    FContexts:array of record
      Context:TXxmSynaContext;
      Buffer:TStream;
      DataLeft:int64;
      BufferFreeWhenDone:boolean;
    end;
    FContextIndex,FContextSize:integer;
    procedure DropContext(force:boolean;i:integer);
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(Context:TXxmSynaContext;
      Buffer:TStream;FreeWhenDone:boolean);
  end;


implementation

uses SysUtils, blcksock, synsock, xxmThreadPool, xxmCommonUtils, xxmContext;

{ TXxmSpoolingConnections }

constructor TXxmSpoolingConnections.Create;
begin
  inherited Create(false);
  Priority:=tpLower;//?
  FContextIndex:=0;
  FContextSize:=0;
  InitializeCriticalSection(FLock);
  FAddEvent:=CreateEventA(nil,true,false,
    PAnsiChar('xxmHttp:SpoolingConnection:'+IntToHex(ThreadID,8)));
end;

destructor TXxmSpoolingConnections.Destroy;
var
  i:integer;
begin
  Terminate;
  SetEvent(FAddEvent);//wake up thread
  WaitFor;
  CloseHandle(FAddEvent);
  DeleteCriticalSection(FLock);
  for i:=0 to FContextIndex-1 do DropContext(true,i);
  inherited;
end;

procedure TXxmSpoolingConnections.Add(Context:TXxmSynaContext;
  Buffer:TStream;FreeWhenDone:boolean);
const
  GrowStep=$100;
var
  i:integer;
begin
  EnterCriticalSection(FLock);
  try
    i:=0;
    while (i<FContextIndex) and (FContexts[i].Context<>nil) do inc(i);
    if i=FContextIndex then
     begin
      if FContextIndex=FContextSize then
       begin
        inc(FContextSize,GrowStep);
        SetLength(FContexts,FContextSize);
       end;
      inc(FContextIndex);
     end;
    FContexts[i].Context:=Context;
    FContexts[i].Buffer:=Buffer;
    FContexts[i].DataLeft:=Buffer.Position;
    FContexts[i].BufferFreeWhenDone:=FreeWhenDone;
    Buffer.Position:=0;
    Context.KeptCount:=0;
    //protect from destruction by TXxmPageLoader.Execute:
    Context.Next:=ntWasKept;
    (Context as IUnknown)._AddRef;
    SetEvent(FAddEvent);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TXxmSpoolingConnections.DropContext(force:boolean;i:integer);
begin
  if force then
    SafeFree(TInterfacedObject(FContexts[i].Context))
  else
    (FContexts[i].Context as IUnknown)._Release;
  if FContexts[i].BufferFreeWhenDone then
    FreeAndNil(FContexts[i].Buffer)
  else
    BufferStore.AddBuffer(TMemoryStream(FContexts[i].Buffer));
end;

procedure TXxmSpoolingConnections.Execute;
const
  dSize=$10000;
var
  d:array[0..dSize-1] of byte;
  w,x:TFDSet;
  i,j,k,l:integer;
  t:TTimeVal;
  h:TSocket;
begin
  inherited;
  i:=0;
  while not Terminated do
   begin
    EnterCriticalSection(FLock);
    try
      w.fd_count:=0;
      x.fd_count:=0;
      j:=0;
      while (j<FContextIndex) and (w.fd_count<64) do
       begin
        k:=(i+j) mod FContextIndex;
        if FContexts[k].Context<>nil then
         begin
          inc(FContexts[k].Context.KeptCount);
          //timed out? (see also t value below: 300x100ms~=30s)
          if FContexts[k].Context.KeptCount=300 then
            DropContext(true,k)
          else
           begin
            h:=FContexts[k].Context.Socket.Socket;
            w.fd_array[w.fd_count]:=h;
            inc(w.fd_count);
            x.fd_array[x.fd_count]:=h;
            inc(x.fd_count);
           end;
         end;
        inc(j);
       end;
    finally
      LeaveCriticalSection(FLock);
    end;
    if FContextIndex=0 then i:=0 else i:=(i+j) mod FContextIndex;
    if w.fd_count=0 then
     begin
      ResetEvent(FAddEvent);
      WaitForSingleObject(FAddEvent,INFINITE);
     end
    else
     begin
      t.tv_sec:=0;
      t.tv_usec:=100000;//microseconds
      if select(0,nil,@w,@x,@t)=SOCKET_ERROR then
       begin
        //TODO: raise? log? sleep?
       end
      else
       begin
        EnterCriticalSection(FLock);
        try
          //errors
          for k:=0 to x.fd_count-1 do
           begin
            j:=0;
            h:=x.fd_array[k];
            while (j<FContextIndex) and not((FContexts[j].Context<>nil)
              and (FContexts[j].Context.Socket.Socket=h)) do inc(j);
            if j<FContextIndex then DropContext(true,j); //else raise?
           end;
          //writables
          for k:=0 to w.fd_count-1 do
           begin
            j:=0;
            h:=w.fd_array[k];
            while (j<FContextIndex) and not((FContexts[j].Context<>nil)
              and (FContexts[j].Context.Socket.Socket=h)) do inc(j);
            if j<FContextIndex then
             begin
              if FContexts[j].DataLeft>dSize then l:=dSize
                else l:=FContexts[j].DataLeft;
              if l<>0 then l:=FContexts[j].Buffer.Read(d[0],l);
              if (l=0) or (FContexts[j].Context.Socket.SendBuffer(@d[0],l)<>l) then
                DropContext(true,j);//raise?
              dec(FContexts[j].DataLeft,l);
              if FContexts[j].DataLeft=0 then //done
               begin
                try
                  FContexts[j].Context.Next:=ntNormal;
                  FContexts[j].Context.PostExecute;
                except
                  //silent
                end;
                DropContext(false,j);
               end;
             end;
            //else raise?
           end;
          //clean-up
          while (FContextIndex>0) and (FContexts[FContextIndex-1].Context=nil) do
            dec(FContextIndex);
        finally
          LeaveCriticalSection(FLock);
        end;
       end;
     end;
   end;
end;

end.

