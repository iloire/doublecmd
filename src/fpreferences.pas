{
   Double Commander
   -------------------------------------------------------------------------
   Simple, macOS-style Preferences window.

   Holds the handful of settings people actually change, on three tabs.
   Every change applies immediately; the configuration is written when the
   window closes. "Advanced..." opens the full Options dialog.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
}

unit fPreferences;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ComCtrls, ExtCtrls, Dialogs;

type

  { TfrmPreferences }

  TfrmPreferences = class(TForm)
  private
    FLoading: Boolean;
    FPages: TPageControl;
    FTop: Integer;
    // General
    cmbAppearance: TComboBox;
    chkUseTrash: TCheckBox;
    chkOneInstance: TCheckBox;
    chkConfirmCopy, chkConfirmMove, chkConfirmDelete, chkConfirmTrash: TCheckBox;
    // View
    lblFont: TLabel;
    cmbRowSpacing: TComboBox;
    chkHidden, chkHiddenDimmed, chkGridLines: TCheckBox;
    cmbDateFormat: TComboBox;
    cmbSizeFormat: TComboBox;
    cmbFolders: TComboBox;
    chkNatural: TCheckBox;
    // Layout
    chkTabs, chkPath, chkHeader, chkStatus, chkFreeSpace,
    chkDriveBar, chkDrivesButton, chkCmdLine, chkKeyButtons: TCheckBox;
    function NewPage(const ACaption: String): TTabSheet;
    procedure AddLabel(AParent: TWinControl; const ACaption: String);
    function AddCheck(AParent: TWinControl; const ALabel, ACaption: String): TCheckBox;
    function AddCombo(AParent: TWinControl; const ALabel: String; const AItems: array of String): TComboBox;
    procedure Gap;
    procedure BuildGeneral;
    procedure BuildView;
    procedure BuildLayout;
    procedure LoadSettings;
    procedure UpdateFontLabel;
    procedure SettingChanged(Sender: TObject);
    procedure FontClick(Sender: TObject);
    procedure AdvancedClick(Sender: TObject);
    procedure DoClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure DoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  public
    constructor Create(TheOwner: TComponent); override;
  end;

procedure ShowPreferences;

implementation

uses
  LCLType, Graphics, uGlobs, uTypes, uEarlyConfig, fMain, fOptions
  {$IFDEF DARWIN}, uDarwinApplication{$ENDIF};

resourcestring
  rsPrefTitle = 'Preferences';
  rsPrefGeneral = 'General';
  rsPrefView = 'View';
  rsPrefLayout = 'Layout';
  rsPrefAdvanced = 'Advanced...';
  rsPrefAppearance = 'Appearance:';
  rsPrefAppearanceItems = 'System;Dark;Light';
  rsPrefDelete = 'Delete:';
  rsPrefUseTrash = 'Move files to the Trash';
  rsPrefStartup = 'Startup:';
  rsPrefOneInstance = 'Allow only one window';
  rsPrefConfirm = 'Ask before:';
  rsPrefConfirmCopy = 'Copying';
  rsPrefConfirmMove = 'Moving';
  rsPrefConfirmDelete = 'Deleting';
  rsPrefConfirmTrash = 'Moving to the Trash';
  rsPrefFont = 'Font:';
  rsPrefChange = 'Change...';
  rsPrefRows = 'Row spacing:';
  rsPrefRowsItems = 'Compact;Standard;Roomy';
  rsPrefShow = 'Show:';
  rsPrefHidden = 'Hidden files';
  rsPrefHiddenDimmed = 'Dim hidden files';
  rsPrefGridLines = 'Grid lines';
  rsPrefDates = 'Dates:';
  rsPrefSizes = 'Sizes:';
  rsPrefSizesItems = 'Automatic (1.2 M);Bytes;Kilobytes;Megabytes';
  rsPrefFolders = 'Folders:';
  rsPrefFoldersItems = 'On top, sorted by name;On top, sorted like files;Mixed with files';
  rsPrefSorting = 'Sorting:';
  rsPrefNatural = 'Natural (file2 before file10)';
  rsPrefWindow = 'Window:';
  rsPrefTabs = 'Folder tabs';
  rsPrefPath = 'Current path';
  rsPrefHeader = 'Column headers';
  rsPrefStatus = 'Status bar';
  rsPrefFreeSpace = 'Free space';
  rsPrefDriveBar = 'Drive buttons bar';
  rsPrefDrivesButton = 'Drives menu button';
  rsPrefCmdLine = 'Command line';
  rsPrefKeyButtons = 'Function key buttons';

const
  LABEL_WIDTH = 130;
  CONTROL_LEFT = LABEL_WIDTH + 24;
  CONTROL_WIDTH = 260;
  ROW_HEIGHT = 30;
  ROW_SPACING: array[0..2] of Integer = (2, 4, 8);
  SIZE_FORMATS: array[0..3] of TFileSizeFormat = (fsfFloat, fsfByte, fsfKilo, fsfMega);

var
  frmPreferences: TfrmPreferences = nil;

function DateFormats: TStringArray;
begin
  Result:= [FormatSettings.ShortDateFormat + ' hh:nn',
            FormatSettings.ShortDateFormat + ' hh:nn:ss',
            'yyyy-mm-dd hh:nn',
            'd mmm yyyy hh:nn'];
end;

procedure ShowPreferences;
begin
  if frmPreferences = nil then
    frmPreferences:= TfrmPreferences.Create(Application);
  frmPreferences.Show;
  frmPreferences.BringToFront;
end;

{ TfrmPreferences }

constructor TfrmPreferences.Create(TheOwner: TComponent);
var
  Bottom: TPanel;
  Button: TButton;
  MaxTop: Integer = 0;
begin
  inherited CreateNew(TheOwner);
  Caption:= rsPrefTitle;
  BorderStyle:= bsDialog;
  Position:= poMainFormCenter;
  KeyPreview:= True;
  OnKeyDown:= @DoKeyDown;
  OnClose:= @DoClose;

  FPages:= TPageControl.Create(Self);
  FPages.Parent:= Self;
  FPages.Align:= alClient;
  FPages.BorderSpacing.Around:= 12;

  Bottom:= TPanel.Create(Self);
  Bottom.Parent:= Self;
  Bottom.Align:= alBottom;
  Bottom.BevelOuter:= bvNone;
  Bottom.Height:= 44;

  Button:= TButton.Create(Self);
  Button.Parent:= Bottom;
  Button.Caption:= rsPrefAdvanced;
  Button.AutoSize:= True;
  Button.AnchorSideRight.Control:= Bottom;
  Button.AnchorSideRight.Side:= asrRight;
  Button.AnchorSideTop.Control:= Bottom;
  Button.AnchorSideTop.Side:= asrCenter;
  Button.Anchors:= [akTop, akRight];
  Button.BorderSpacing.Right:= 16;
  Button.OnClick:= @AdvancedClick;

  BuildGeneral;
  if FTop > MaxTop then MaxTop:= FTop;
  BuildView;
  if FTop > MaxTop then MaxTop:= FTop;
  BuildLayout;
  if FTop > MaxTop then MaxTop:= FTop;

  ClientWidth:= CONTROL_LEFT + CONTROL_WIDTH + 80;
  ClientHeight:= MaxTop + Bottom.Height + 70;

  LoadSettings;
end;

function TfrmPreferences.NewPage(const ACaption: String): TTabSheet;
begin
  Result:= FPages.AddTabSheet;
  Result.Caption:= ACaption;
  FTop:= 16;
end;

procedure TfrmPreferences.AddLabel(AParent: TWinControl; const ACaption: String);
var
  L: TLabel;
begin
  if ACaption = '' then Exit;
  L:= TLabel.Create(Self);
  L.Parent:= AParent;
  L.AutoSize:= False;
  L.Alignment:= taRightJustify;
  L.Layout:= tlCenter;
  L.Caption:= ACaption;
  L.SetBounds(8, FTop, LABEL_WIDTH, 24);
end;

function TfrmPreferences.AddCheck(AParent: TWinControl; const ALabel, ACaption: String): TCheckBox;
begin
  AddLabel(AParent, ALabel);
  Result:= TCheckBox.Create(Self);
  Result.Parent:= AParent;
  Result.Caption:= ACaption;
  Result.SetBounds(CONTROL_LEFT, FTop, CONTROL_WIDTH, 24);
  Result.OnChange:= @SettingChanged;
  Inc(FTop, ROW_HEIGHT - 6);
end;

function TfrmPreferences.AddCombo(AParent: TWinControl; const ALabel: String; const AItems: array of String): TComboBox;
var
  S: String;
begin
  AddLabel(AParent, ALabel);
  Result:= TComboBox.Create(Self);
  Result.Parent:= AParent;
  Result.Style:= csDropDownList;
  for S in AItems do Result.Items.Add(S);
  Result.SetBounds(CONTROL_LEFT, FTop, CONTROL_WIDTH, 24);
  Result.OnChange:= @SettingChanged;
  Inc(FTop, ROW_HEIGHT);
end;

procedure TfrmPreferences.Gap;
begin
  Inc(FTop, 12);
end;

procedure TfrmPreferences.BuildGeneral;
var
  Page: TTabSheet;
begin
  Page:= NewPage(rsPrefGeneral);
{$IFDEF DARWIN}
  cmbAppearance:= AddCombo(Page, rsPrefAppearance, rsPrefAppearanceItems.Split(';'));
  Gap;
{$ENDIF}
  chkUseTrash:= AddCheck(Page, rsPrefDelete, rsPrefUseTrash);
  chkOneInstance:= AddCheck(Page, rsPrefStartup, rsPrefOneInstance);
  Gap;
  chkConfirmCopy:= AddCheck(Page, rsPrefConfirm, rsPrefConfirmCopy);
  chkConfirmMove:= AddCheck(Page, '', rsPrefConfirmMove);
  chkConfirmDelete:= AddCheck(Page, '', rsPrefConfirmDelete);
  chkConfirmTrash:= AddCheck(Page, '', rsPrefConfirmTrash);
end;

procedure TfrmPreferences.BuildView;
var
  Page: TTabSheet;
  Button: TButton;
  S: String;
begin
  Page:= NewPage(rsPrefView);

  AddLabel(Page, rsPrefFont);
  lblFont:= TLabel.Create(Self);
  lblFont.Parent:= Page;
  lblFont.Layout:= tlCenter;
  lblFont.AutoSize:= False;
  lblFont.SetBounds(CONTROL_LEFT, FTop, CONTROL_WIDTH - 100, 24);
  Button:= TButton.Create(Self);
  Button.Parent:= Page;
  Button.Caption:= rsPrefChange;
  Button.SetBounds(CONTROL_LEFT + CONTROL_WIDTH - 96, FTop - 2, 96, 28);
  Button.OnClick:= @FontClick;
  Inc(FTop, ROW_HEIGHT);

  cmbRowSpacing:= AddCombo(Page, rsPrefRows, rsPrefRowsItems.Split(';'));
  Gap;
  chkHidden:= AddCheck(Page, rsPrefShow, rsPrefHidden);
  chkHiddenDimmed:= AddCheck(Page, '', rsPrefHiddenDimmed);
  chkGridLines:= AddCheck(Page, '', rsPrefGridLines);
  Gap;
  cmbDateFormat:= AddCombo(Page, rsPrefDates, []);
  for S in DateFormats do
    cmbDateFormat.Items.Add(FormatDateTime(S, Now));
  cmbSizeFormat:= AddCombo(Page, rsPrefSizes, rsPrefSizesItems.Split(';'));
  Gap;
  cmbFolders:= AddCombo(Page, rsPrefFolders, rsPrefFoldersItems.Split(';'));
  chkNatural:= AddCheck(Page, rsPrefSorting, rsPrefNatural);
end;

procedure TfrmPreferences.BuildLayout;
var
  Page: TTabSheet;
begin
  Page:= NewPage(rsPrefLayout);
  chkTabs:= AddCheck(Page, rsPrefWindow, rsPrefTabs);
  chkPath:= AddCheck(Page, '', rsPrefPath);
  chkHeader:= AddCheck(Page, '', rsPrefHeader);
  chkStatus:= AddCheck(Page, '', rsPrefStatus);
  chkFreeSpace:= AddCheck(Page, '', rsPrefFreeSpace);
  Gap;
  chkDriveBar:= AddCheck(Page, '', rsPrefDriveBar);
  chkDrivesButton:= AddCheck(Page, '', rsPrefDrivesButton);
  chkCmdLine:= AddCheck(Page, '', rsPrefCmdLine);
  chkKeyButtons:= AddCheck(Page, '', rsPrefKeyButtons);
end;

procedure TfrmPreferences.LoadSettings;
var
  I: Integer;
  Formats: TStringArray;
begin
  FLoading:= True;
  try
    if Assigned(cmbAppearance) then
      cmbAppearance.ItemIndex:= gAppMode - 1;
    chkUseTrash.Checked:= gUseTrash;
    chkOneInstance.Checked:= gOnlyOneAppInstance;
    chkConfirmCopy.Checked:= focCopy in gFileOperationsConfirmations;
    chkConfirmMove.Checked:= focMove in gFileOperationsConfirmations;
    chkConfirmDelete.Checked:= focDelete in gFileOperationsConfirmations;
    chkConfirmTrash.Checked:= focDeleteToTrash in gFileOperationsConfirmations;

    UpdateFontLabel;
    cmbRowSpacing.ItemIndex:= -1;
    for I:= Low(ROW_SPACING) to High(ROW_SPACING) do
      if ROW_SPACING[I] = gExtraLineSpan then cmbRowSpacing.ItemIndex:= I;
    chkHidden.Checked:= gShowSystemFiles;
    chkHiddenDimmed.Checked:= gShowHiddenDimmed;
    chkGridLines.Checked:= gGridHorzLine;
    Formats:= DateFormats;
    cmbDateFormat.ItemIndex:= -1;
    for I:= 0 to High(Formats) do
      if Formats[I] = gDateTimeFormat then cmbDateFormat.ItemIndex:= I;
    cmbSizeFormat.ItemIndex:= -1;
    for I:= Low(SIZE_FORMATS) to High(SIZE_FORMATS) do
      if SIZE_FORMATS[I] = gFileSizeFormat then cmbSizeFormat.ItemIndex:= I;
    cmbFolders.ItemIndex:= Ord(gSortFolderMode);
    chkNatural.Checked:= gSortNatural;

    chkTabs.Checked:= gDirectoryTabs;
    chkPath.Checked:= gCurDir;
    chkHeader.Checked:= gTabHeader;
    chkStatus.Checked:= gStatusBar;
    chkFreeSpace.Checked:= gDriveFreeSpace;
    chkDriveBar.Checked:= gDriveBar1;
    chkDrivesButton.Checked:= gDrivesListButton;
    chkCmdLine.Checked:= gCmdLine;
    chkKeyButtons.Checked:= gKeyButtons;
  finally
    FLoading:= False;
  end;
end;

procedure TfrmPreferences.UpdateFontLabel;
begin
  with gFonts[dcfMain] do
    if (Name = '') or SameText(Name, 'default') then
      lblFont.Caption:= Format('System, %d pt', [Size])
    else
      lblFont.Caption:= Format('%s, %d pt', [Name, Size]);
end;

procedure TfrmPreferences.SettingChanged(Sender: TObject);

  procedure SetConfirm(Item: TFileOperationsConfirmation; Value: Boolean);
  begin
    if Value then
      Include(gFileOperationsConfirmations, Item)
    else
      Exclude(gFileOperationsConfirmations, Item);
  end;

begin
  if FLoading then Exit;

{$IFDEF DARWIN}
  if (Sender = cmbAppearance) and (cmbAppearance.ItemIndex >= 0) then
  begin
    gAppMode:= cmbAppearance.ItemIndex + 1;
    TDarwinApplicationUtil.setTheme(gAppMode);
  end;
{$ENDIF}

  // Toggling hidden files needs the panels reloaded, which the command does
  if (Sender = chkHidden) and (chkHidden.Checked <> gShowSystemFiles) then
    frmMain.Commands.cm_ShowSysFiles([]);

  gUseTrash:= chkUseTrash.Checked;
  gOnlyOneAppInstance:= chkOneInstance.Checked;
  SetConfirm(focCopy, chkConfirmCopy.Checked);
  SetConfirm(focMove, chkConfirmMove.Checked);
  SetConfirm(focDelete, chkConfirmDelete.Checked);
  SetConfirm(focDeleteToTrash, chkConfirmTrash.Checked);

  if cmbRowSpacing.ItemIndex >= 0 then
    gExtraLineSpan:= ROW_SPACING[cmbRowSpacing.ItemIndex];
  gShowHiddenDimmed:= chkHiddenDimmed.Checked;
  gGridHorzLine:= chkGridLines.Checked;
  gGridVertLine:= chkGridLines.Checked;
  if cmbDateFormat.ItemIndex >= 0 then
    gDateTimeFormat:= DateFormats[cmbDateFormat.ItemIndex];
  if cmbSizeFormat.ItemIndex >= 0 then
    gFileSizeFormat:= SIZE_FORMATS[cmbSizeFormat.ItemIndex];
  if cmbFolders.ItemIndex >= 0 then
    gSortFolderMode:= TSortFolderMode(cmbFolders.ItemIndex);
  gSortNatural:= chkNatural.Checked;

  gDirectoryTabs:= chkTabs.Checked;
  gCurDir:= chkPath.Checked;
  gTabHeader:= chkHeader.Checked;
  gStatusBar:= chkStatus.Checked;
  gDriveFreeSpace:= chkFreeSpace.Checked;
  gDriveBar1:= chkDriveBar.Checked;
  gDrivesListButton:= chkDrivesButton.Checked;
  gCmdLine:= chkCmdLine.Checked;
  gKeyButtons:= chkKeyButtons.Checked;

  frmMain.UpdateWindowView;
end;

procedure TfrmPreferences.FontClick(Sender: TObject);
var
  Dlg: TFontDialog;
begin
  Dlg:= TFontDialog.Create(Self);
  try
    FontOptionsToFont(gFonts[dcfMain], Dlg.Font);
    if Dlg.Execute then
    begin
      FontToFontOptions(Dlg.Font, gFonts[dcfMain]);
      UpdateFontLabel;
      frmMain.UpdateWindowView;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TfrmPreferences.AdvancedClick(Sender: TObject);
begin
  Close;
  ShowOptions('');
end;

procedure TfrmPreferences.DoClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  SaveGlobs;
  CloseAction:= caFree;
  frmPreferences:= nil;
end;

procedure TfrmPreferences.DoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) or ((Key = VK_W) and (ssMeta in Shift)) then
  begin
    Key:= 0;
    Close;
  end;
end;


end.
