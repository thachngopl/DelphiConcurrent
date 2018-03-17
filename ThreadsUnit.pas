unit ThreadsUnit;

interface

uses
  System.Classes, System.Types, System.SyncObjs, System.SysUtils, System.Contnrs, System.Generics.Collections,
  DelphiConcurrent;

type
  TExchangedMessage = class
    FID: Integer;
    FDT: TDateTime;
    constructor Create(const AID: Integer; const ADT: TDateTime);
  public
    procedure Assign(ASrcMsg: TExchangedMessage);
    property ID: Integer read FID write FID;
    property DT: TDateTime read FDT write FDT;
  end;

  TProducer = class(TThread)
  private
    FThreadNum, FMessagesNbr: Integer; // here FMessagesNbr = Nbr of messages to produce
    FSharedRessource: TDCAdlThreaded;
  public
    constructor Create(const AThreadNum, AMessagesNbr: Integer; ASharedRessource: TDCAdlThreaded);
    procedure Execute; override;
    procedure NotifyToUI(const msg: String);
    property ThreadNum: Integer read FThreadNum write FThreadNum;
  end;

  TConsumer = class(TThread)
  private
    FThreadNum, FMessagesNbr: Integer; // here FMessagesNbr = Nbr of messages to consume
    FSharedRessource: TDCAdlThreaded;
    FReceivedMessagesCopies: TObjectList<TExchangedMessage>;
  public
    constructor Create(const AThreadNum, AMessagesNbr: Integer; ASharedRessource: TDCAdlThreaded);
    destructor Destroy; override;
    procedure Execute; override;
    procedure NotifyToUI(const msg: String);
    property ThreadNum: Integer read FThreadNum write FThreadNum;
  end;

implementation

uses
  MainUnit;

{ TProducer }

constructor TProducer.Create(const AThreadNum, AMessagesNbr: Integer; ASharedRessource: TDCAdlThreaded);
begin
  inherited Create();
  FThreadNum := AThreadNum;
  FMessagesNbr := AMessagesNbr;
  FSharedRessource := ASharedRessource;
end;

procedure TProducer.Execute;
var
  i: Integer;
  LExchangedMessage: TExchangedMessage;
  LRessourcePointer: TDCReadableOnly;
begin
  inherited;
  NotifyToUI(Format('Producer Thread n�%d Started', [FThreadNum]));
  i:=1;
  while (i <= FMessagesNbr) and (not Terminated) do
  begin
    LExchangedMessage := TExchangedMessage.Create(i, Now());
    LRessourcePointer := FSharedRessource.Lock(False); // ReadOnly: Boolean=True
    try
      if (LRessourcePointer is TDCReadableOnlyList) then
      begin
        TDCReadableOnlyList(LRessourcePointer).Add(LExchangedMessage);
      end;
    finally
      FSharedRessource.Unlock;
    end;
    Inc(i);
    Sleep(5);
  end;
  NotifyToUI(Format('Producer Thread n�%d Terminated', [FThreadNum]));
end;

procedure TProducer.NotifyToUI(const msg: String);
begin
  TThread.Queue(nil, procedure begin
    MainForm.UpdateTestResult(msg);
  end);
end;

{ TConsumer }

constructor TConsumer.Create(const AThreadNum, AMessagesNbr: Integer; ASharedRessource: TDCAdlThreaded);
begin
  inherited Create();
  FThreadNum := AThreadNum;
  FMessagesNbr := AMessagesNbr;
  FSharedRessource := ASharedRessource;
  FReceivedMessagesCopies := TObjectList<TExchangedMessage>.Create(True);
end;

destructor TConsumer.Destroy;
begin
  FreeAndNil(FReceivedMessagesCopies);
  inherited;
end;

procedure TConsumer.Execute;
var
  i: Integer;
  LRessourcePointer: TDCReadableOnly;
  LExchangedMessageCopy: TExchangedMessage;
begin
  inherited;
  NotifyToUI(Format('Consumer Thread n�%d Started', [FThreadNum]));
  while (FReceivedMessagesCopies.Count < FMessagesNbr) and (not Terminated) do
  begin
    LRessourcePointer := FSharedRessource.Lock(); // ReadOnly: Boolean=True
    try
      if (LRessourcePointer is TDCReadableOnlyList) then
      begin
        for i:=0 to TDCReadableOnlyList(LRessourcePointer).Count-1 do
        begin
          if (FReceivedMessagesCopies.IndexOf(TDCReadableOnlyList(LRessourcePointer)[i]) < 0) then
          begin
            LExchangedMessageCopy := TExchangedMessage.Create(0, 0);
            LExchangedMessageCopy.Assign(TDCReadableOnlyList(LRessourcePointer)[i]);
            FReceivedMessagesCopies.Add(LExchangedMessageCopy);
          end;
        end;
      end;
    finally
      FSharedRessource.Unlock;
    end;
    Sleep(5);
  end;
  NotifyToUI(Format('Consumer Thread n�%d Terminated', [FThreadNum]));
end;

procedure TConsumer.NotifyToUI(const msg: String);
begin
  TThread.Queue(nil, procedure begin
    MainForm.UpdateTestResult(msg);
  end);
end;

{ TExchangedMessage }

procedure TExchangedMessage.Assign(ASrcMsg: TExchangedMessage);
begin
  FID := ASrcMsg.ID;
  FDT := ASrcMsg.DT;
end;

constructor TExchangedMessage.Create(const AID: Integer; const ADT: TDateTime);
begin
  FID := AID;
  FDT := ADT;
end;

end.
