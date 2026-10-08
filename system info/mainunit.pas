unit MainUnit;

{ Debian System Information
  A sidebar of buttons; each one runs a shell command and shows its output
  in a read-only monospace view. The whole UI is built in code, so this unit
  has no .lfm file. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls, Process;

type
  TMainForm = class(TForm)
  private
    FSidebar: TPanel;
    FOutput: TMemo;
    procedure BuildUI;
    procedure InfoButtonClick(Sender: TObject);
    procedure RunAndShow(const ACommand: string);
  public
    { Not loaded from a .lfm, so we build the form with CreateNew }
    constructor Create(TheOwner: TComponent); override;
  end;

var
  MainForm: TMainForm;

implementation

const
  SidebarWidth = 230;

type
  TInfoItem = record
    Caption: string;
    Command: string;   { empty = this entry is a section heading }
  end;

const
  { Edit this table to add, remove or change buttons }
  InfoItems: array[0..13] of TInfoItem = (
    (Caption: 'SYSTEM OVERVIEW';        Command: ''),
    (Caption: 'System Info (uname)';    Command: 'uname -a'),
    (Caption: 'OS-Release';             Command: 'cat /etc/os-release'),
    (Caption: 'System Load (uptime)';   Command: 'uptime'),
    (Caption: 'CPU Info (lscpu)';       Command: 'lscpu'),
    (Caption: 'Memory Usage (free)';    Command: 'free -h'),
    (Caption: 'Sensors Data';           Command: 'sensors'),

    (Caption: 'STORAGE & FILESYSTEMS';  Command: ''),
    (Caption: 'Storage (lsblk)';        Command: 'lsblk'),
    (Caption: 'Disk Space (df)';        Command: 'df -h'),

    (Caption: 'HARDWARE & NETWORKING';  Command: ''),
    (Caption: 'USB Busses (lsusb)';     Command: 'lsusb'),
    (Caption: 'PCI Devices (lspci)';    Command: 'lspci'),
    (Caption: 'Network IPs (ip)';       Command: 'ip -brief address')
  );

constructor TMainForm.Create(TheOwner: TComponent);
begin
  inherited CreateNew(TheOwner);

  Caption := 'Debian System Information';
  Position := poScreenCenter;
  ClientWidth := 960;
  ClientHeight := 640;
  Constraints.MinWidth := 600;
  Constraints.MinHeight := 420;

  BuildUI;
  RunAndShow(InfoItems[1].Command);   { start with the uname output }
end;

procedure TMainForm.BuildUI;
var
  i, Y: Integer;
  Lbl: TLabel;
  Btn: TButton;
begin
  { left column }
  FSidebar := TPanel.Create(Self);
  FSidebar.Parent := Self;
  FSidebar.Align := alLeft;
  FSidebar.Width := SidebarWidth;
  FSidebar.BevelOuter := bvNone;
  FSidebar.Caption := '';

  { output area fills the rest of the window }
  FOutput := TMemo.Create(Self);
  FOutput.Parent := Self;
  FOutput.Align := alClient;
  FOutput.BorderSpacing.Around := 8;
  FOutput.ReadOnly := True;
  FOutput.WordWrap := False;            { long lines scroll sideways }
  FOutput.ScrollBars := ssAutoBoth;
  FOutput.Font.Name := 'Monospace';
  FOutput.Font.Size := 10;

  { headings and buttons, stacked top to bottom }
  Y := 14;
  for i := Low(InfoItems) to High(InfoItems) do
  begin
    if InfoItems[i].Command = '' then
    begin
      if i > 0 then
        Inc(Y, 14);                     { extra gap before a new section }

      Lbl := TLabel.Create(Self);
      Lbl.Parent := FSidebar;
      Lbl.ShowAccelChar := False;       { so the "&" in a heading is shown }
      Lbl.Caption := InfoItems[i].Caption;
      Lbl.Font.Style := [fsBold];
      Lbl.Left := 14;
      Lbl.Top := Y;
      Inc(Y, 28);
    end
    else
    begin
      Btn := TButton.Create(Self);
      Btn.Parent := FSidebar;
      Btn.Caption := InfoItems[i].Caption;
      Btn.Tag := i;                     { index into InfoItems }
      Btn.SetBounds(12, Y, SidebarWidth - 24, 32);
      Btn.Anchors := [akLeft, akTop, akRight];
      Btn.OnClick := @InfoButtonClick;
      Inc(Y, 40);
    end;
  end;
end;

procedure TMainForm.InfoButtonClick(Sender: TObject);
begin
  RunAndShow(InfoItems[(Sender as TButton).Tag].Command);
end;

procedure TMainForm.RunAndShow(const ACommand: string);
var
  Res: string;
  Ok: Boolean;
begin
  Res := '';
  Screen.Cursor := crHourGlass;
  try
    { run through the shell and capture stderr too, so a missing program
      shows "not found" instead of an empty page }
    Ok := RunCommand('/bin/sh', ['-c', ACommand], Res, [poStderrToOutPut]);
  finally
    Screen.Cursor := crDefault;
  end;

  Res := TrimRight(Res);
  if Res = '' then
    Res := '(no output)';
  if not Ok then
    Res := Res + LineEnding + LineEnding +
           '[the command failed - is the program installed?]';

  FOutput.Lines.Text := Res;
  FOutput.SelStart := 0;                { scroll back to the top }
end;

end.
