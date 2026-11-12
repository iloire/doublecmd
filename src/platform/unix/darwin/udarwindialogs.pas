unit uDarwinDialogs;

{
  Gives every dialog a macOS look without touching each form:
  Cancel to the left of OK, no Windows-style mnemonic underlines,
  and the roomier margins Mac dialogs use.
}

{$mode objfpc}{$H+}

interface

procedure InitDarwinDialogs;

implementation

uses
  Classes, Controls, Forms, StdCtrls, ButtonPanel, LCLProc;

const
  // Extra inner padding, so content sits ~20px from the window edge
  DIALOG_PADDING = 12;

type
  TFormAccess = class(TCustomForm);
  TLabelAccess = class(TCustomLabel);

  { TDarwinDialogs }

  TDarwinDialogs = class
    procedure FormAdded(Sender: TObject; Form: TCustomForm);
    procedure FormFirstShow(Sender: TObject);
  end;

var
  Dialogs: TDarwinDialogs = nil;

procedure PolishControls(Control: TWinControl);
var
  I: Integer;
  Child: TControl;
begin
  for I:= 0 to Control.ControlCount - 1 do
  begin
    Child:= Control.Controls[I];
    if Child is TCustomButtonPanel then
      TCustomButtonPanel(Child).ButtonOrder:= boCloseCancelOK
    else if (Child is TCustomLabel) and TLabelAccess(Child).ShowAccelChar then
    begin
      TLabelAccess(Child).Caption:= RemoveAmpersands(TLabelAccess(Child).Caption);
      TLabelAccess(Child).ShowAccelChar:= False;
    end;
    if Child is TWinControl then
      PolishControls(TWinControl(Child));
  end;
end;

{ TDarwinDialogs }

procedure TDarwinDialogs.FormAdded(Sender: TObject; Form: TCustomForm);
begin
  Form.AddHandlerFirstShow(@FormFirstShow);
end;

procedure TDarwinDialogs.FormFirstShow(Sender: TObject);
var
  Form: TFormAccess absolute Sender;
begin
  // Dialogs: fixed-border forms, and resizable ones that size themselves
  // (Copy/Move, About, message boxes). Splash and other borderless forms stay as is.
  if (Form.BorderStyle = bsNone) or
     not ((Form.BorderStyle = bsDialog) or Form.AutoSize) then Exit;

  Form.DisableAutoSizing;
  try
    PolishControls(Form);
    // Only padded when the form sizes itself, fixed-size forms would clip
    if Form.AutoSize then
      Form.BorderWidth:= Form.BorderWidth + Form.Scale96ToForm(DIALOG_PADDING);
  finally
    Form.EnableAutoSizing;
  end;
  // The position was computed for the old size
  if Form.Position in [poScreenCenter, poDesktopCenter, poMainFormCenter, poOwnerFormCenter] then
    Form.MoveToDefaultPosition;
end;

procedure InitDarwinDialogs;
begin
  if Assigned(Dialogs) then Exit;
  Dialogs:= TDarwinDialogs.Create;
  // Native macOS buttons never carry icons
  Application.ShowButtonGlyphs:= sbgNever;
  Screen.AddHandlerFormAdded(@Dialogs.FormAdded);
end;

finalization
  Dialogs.Free;

end.
