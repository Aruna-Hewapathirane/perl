program sysinfo;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, { this includes the LCL widgetset }
  Forms, MainUnit;

begin
  RequireDerivedFormResource := False;  { MainForm has no .lfm file }
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
