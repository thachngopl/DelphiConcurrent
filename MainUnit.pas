unit MainUnit;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, System.SyncObjs,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.Controls.Presentation,
  FMX.StdCtrls, FMX.ScrollBox, FMX.Memo, DelphiConcurrent, ThreadsUnit,
  FMX.Edit, FMX.EditBox, FMX.SpinBox;

type
  TMainForm = class(TForm)
    StartButton: TButton;
    Memo1: TMemo;
    StopButton: TButton;
    Label1: TLabel;
    ExecTimeLabel: TLabel;
    Label2: TLabel;
    ProducersNbr_SpinBox: TSpinBox;
    Label3: TLabel;
    ConsumersNbr_SpinBox: TSpinBox;
    Label4: TLabel;
    MessagesNbrPerProducer_SpinBox: TSpinBox;
    GroupBox1: TGroupBox;
    Monitor_RadioButton: TRadioButton;
    CriticalSection_RadioButton: TRadioButton;
    DCAdlThreaded_RadioButton: TRadioButton;
    procedure StartButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure StopButtonClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { D�clarations priv�es }
    SharedRessource: TDCAdlThreaded;
    ProducersLst: array of TProducer;
    ConsumersLst: array of TConsumer;
    TestStartTime, TestEndTime, TestDuration: Cardinal;
    ProducersNbr, ConsumersNbr, MessagesNbrPerProducer : Integer;
    MessagesLockType: TDCLockType;
  public
    { D�clarations publiques }
    procedure UpdateTestResult(const msg: String);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

procedure TMainForm.FormCreate(Sender: TObject);
begin
  StartButton.Enabled := True;
  StopButton.Enabled := False;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  if StopButton.Enabled
    then StopButtonClick(nil);
end;

procedure TMainForm.StartButtonClick(Sender: TObject);
var
  i: Integer;
begin
  StartButton.Enabled := False;
  ProducersNbr := Trunc(ProducersNbr_SpinBox.Value);
  ConsumersNbr := Trunc(ConsumersNbr_SpinBox.Value);
  MessagesNbrPerProducer := Trunc(MessagesNbrPerProducer_SpinBox.Value);
  if (DCAdlThreaded_RadioButton.IsChecked)
    then MessagesLockType := ltAdlMREW
  else
  if (CriticalSection_RadioButton.IsChecked)
    then MessagesLockType := ltCriticalSection
  else
    MessagesLockType := ltMonitor;

  SharedRessource := TDCAdlThreaded.Create(TDCReadableOnlyList, MessagesLockType);
  SetLength(ProducersLst, ProducersNbr);
  SetLength(ConsumersLst, ConsumersNbr);

  ExecTimeLabel.Text := '';
  Memo1.Lines.Clear;
  Memo1.Lines.BeginUpdate;
  StopButton.Enabled := True;
  Application.ProcessMessages; // force mainform update

  TestStartTime := TThread.GetTickCount;
  for i:=0 to ProducersNbr-1 do
    ProducersLst[i] := TProducer.Create(i, MessagesNbrPerProducer, SharedRessource);
  for i:=0 to ConsumersNbr-1 do
    ConsumersLst[i] := TConsumer.Create(i, MessagesNbrPerProducer * ProducersNbr, SharedRessource);
end;

procedure TMainForm.StopButtonClick(Sender: TObject);
var
  i: Integer;
  LRessourcePointer: TDCReadableOnly;
begin
  StopButton.Enabled := False;
  Memo1.Lines.EndUpdate;

  for i:=0 to ProducersNbr-1 do
  begin
    if Assigned(ProducersLst[i]) then
    begin
      ProducersLst[i].Terminate;
      ProducersLst[i].WaitFor;
      ProducersLst[i] := nil;
    end;
  end;
  for i:=0 to ConsumersNbr-1 do
  begin
    if Assigned(ConsumersLst[i]) then
    begin
      ConsumersLst[i].Terminate;
      ConsumersLst[i].WaitFor;
      ConsumersLst[i] := nil;
    end;
  end;
  Finalize(ProducersLst);
  Finalize(ConsumersLst);
  LRessourcePointer := SharedRessource.Lock(); // ReadOnly: Boolean=True
  try
    if (LRessourcePointer is TDCReadableOnlyList) then
    begin
      for i:=0 to TDCReadableOnlyList(LRessourcePointer).Count-1 do
      begin
         TExchangedMessage(TDCReadableOnlyList(LRessourcePointer)[i]).Free;
      end;
    end;
  finally
    SharedRessource.Unlock;
  end;
  FreeAndNil(SharedRessource);
  StartButton.Enabled := True;
end;

procedure TMainForm.UpdateTestResult(const msg: String);
begin
  Memo1.Lines.Add('Line n�' + IntToStr(Memo1.Lines.Count+1) + ': ' + msg);
  // each thread (Producer or Consumer) will insert 2 messages in the memo in his life
  // so we except at the end 2 * (ProducersNbr + ConsumersNbr) messages in the memo
  if (Memo1.Lines.Count = 2 * (ProducersNbr + ConsumersNbr)) then
  begin
    TestEndTime := TThread.GetTickCount;
    TestDuration := TestEndTime - TestStartTime;
    ExecTimeLabel.Text := Format('%f', [TestDuration / 1000]) + ' sec';
    StopButtonClick(nil);
  end;
end;

end.
