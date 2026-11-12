{
   Double Commander
   -------------------------------------------------------------------------
   Implementing of Options dialog

   Copyright (C) 2006-2023 Alexander Koblov (alexx2000@mail.ru)

   contributors:

   Radek Cervinka  <radek.cervinka@centrum.cz>

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program. If not, see <http://www.gnu.org/licenses/>.
}

unit fOptions;

{$mode objfpc}{$H+}

interface

uses
  ActnList, SysUtils, Classes, Controls, Forms, Dialogs, ExtCtrls, ComCtrls,
  Buttons, StdCtrls, LMessages, TreeFilterEdit, KASButtonPanel, fgl, uGlobs,
  fOptionsFrame, uDCUtils, EditBtn;

type

  { TOptionsEditorView }

  TOptionsEditorView = class
    EditorClass: TOptionsEditorClass;
    Instance: TOptionsEditor;
    TreeNode: TTreeNode;
    LegacyOrderIndex: integer;
  end;

  TOptionsEditorViews = specialize TFPGObjectList<TOptionsEditorView>;

  { TfrmOptions }

  TfrmOptions = class(TForm, IOptionsDialog)
    btnHelp: TBitBtn;
    lblEmptyEditor: TLabel;
    OptionsEditorsImageList: TImageList;
    pnlButtons: TKASButtonPanel;
    Panel3: TPanel;
    pnlCaption: TPanel;
    btnOK: TBitBtn;
    btnApply: TBitBtn;
    btnCancel: TBitBtn;
    sboxOptionsEditor: TScrollBox;
    TreeFilterEdit: TTreeFilterEdit;
    tvTreeView: TTreeView;
    splOptionsSplitter: TSplitter;
    procedure btnCancelClick(Sender: TObject);
    procedure btnCancelMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure btnHelpClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnApplyClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure splOptionsSplitterMoved(Sender: TObject);
    function TreeFilterEditFilterItem(ItemData: Pointer;
                                      out Done: Boolean): Boolean;
    procedure tvTreeViewChange(Sender: TObject; Node: TTreeNode);
  private
    FOptionsEditorList: TOptionsEditorViews;
    FOldEditor: TOptionsEditorView;
    function CreateEditor(EditorClass: TOptionsEditorClass): TOptionsEditor;
    procedure CreateOptionsEditorList;
    function GetEditor(EditorClass: TOptionsEditorClass): TOptionsEditor;
    procedure LoadSettings;
    procedure SelectEditor(EditorClassName: String);
    function CompareTwoNodeOfConfigurationOptionTree(Node1, Node2: TTreeNode): integer;
    function CycleThroughOptionEditors(bForceSaving:boolean):boolean;
    procedure MakeVisible(Data: PtrInt);
{$IFDEF DARWIN}
    procedure BuildDarwinTree;
    procedure ApplyDarwinStyle;
    procedure tvDarwinCustomDrawItem(Sender: TCustomTreeView; Node: TTreeNode;
      State: TCustomDrawState; Stage: TCustomDrawStage;
      var PaintImages, DefaultDraw: Boolean);
    procedure tvDarwinChanging(Sender: TObject; Node: TTreeNode; var AllowChange: Boolean);
    procedure tvDarwinCollapsing(Sender: TObject; Node: TTreeNode; var AllowCollapse: Boolean);
{$ENDIF}
  protected
    procedure CMThemeChanged(var Message: TLMessage); message CM_THEMECHANGED;
  public
    constructor Create(TheOwner: TComponent); override;
    constructor Create(TheOwner: TComponent; EditorClass: TOptionsEditorClass); overload;
    constructor Create(TheOwner: TComponent; EditorClassName: String); overload;
    procedure LoadConfig;
    procedure SaveConfig;
  end;

  function ShowOptions(EditorClass: TOptionsEditorClass = nil): IOptionsDialog;
  function ShowOptions(EditorClassName: String): IOptionsDialog;
  procedure SortConfigurationOptionsOnLeftTree; //If the var "frmOptions" would be in the interface section, we could have called directly "frmOptions.tvTreeView.CustomSort(@frmOptions.CompareTwoNodeOfConfigurationOptionTree);"
                                                //But it's not the case... Let's create this routine and respect the wish of original authors to have it there. Maybe there is a raison why so let's play safe.
  function GetOptionsForm: TfrmOptions;

implementation

{$R *.lfm}

uses
  HelpIntfs, LCLProc, LCLVersion, LazUTF8, LResources, Menus, Translations, Graphics,
  DCStrUtils, uTranslator, uLng, uGlobsPaths, fMain
  {$IFDEF DARWIN}, ImgList, uDarwinOptionsTree{$ENDIF};

var
  LastOpenedEditor: TOptionsEditorClass = nil;
  OptionsSearchFile: TPOFile = nil;
  OptionsSearchCache: TList = nil;
  frmOptions: TfrmOptions = nil;

procedure CreateSearchCache;
var
  POFile: TPOFile;

  procedure FillCache(AList: TOptionsEditorClassList);
  var
    I, J: Integer;
    AClassName: String;
    PoFileItem: TPoFileItem;
    AEditor: TOptionsEditorRec;
  begin
    for I:= 0 to AList.Count - 1 do
    begin
      AEditor:= AList[I];
      AClassName:= LowerCase(AEditor.EditorClass.ClassName);

      for J:= 0 to POFile.Count - 1 do
      begin
        PoFileItem:= POFile.PoItems[J];
        if StrBegins(PoFileItem.IdentifierLow, AClassName) then
        begin
          OptionsSearchCache.Add(PoFileItem);
        end;
      end;
      if AEditor.HasChildren then FillCache(AEditor.Children);
    end;
  end;

begin
  OptionsSearchCache:= TList.Create;
  try
    if Assigned(LRSTranslator) then
      POFile:= (LRSTranslator as TTranslator).POFile
    else begin
      POFile:= TPOFile.Create(gpLngDir + gPOFileName, True);
      OptionsSearchFile:= POFile;
    end;
    FillCache(OptionsEditorClassList);
  except
    // Skip
  end;
end;

{ GetOptionsForm }
// To get a point on the frmOptions.
// Could have been simple to place "frmOptions" in the "interface" section but not sure why original author hide it under. Let's play safe.
function GetOptionsForm: TfrmOptions;
begin
  Result := frmOptions;
end;

function ShowOptions(EditorClass: TOptionsEditorClass): IOptionsDialog;
begin
  Result := ShowOptions(EditorClass.ClassName);
end;

function ShowOptions(EditorClassName: String): IOptionsDialog;
begin
  if (OptionsSearchCache = nil) then
  begin
    CreateSearchCache;
  end;
  if Assigned(frmOptions) then
    begin
      if frmOptions.WindowState = wsMinimized then
        frmOptions.WindowState:= wsNormal
      else
        frmOptions.BringToFront;

      frmOptions.SelectEditor(EditorClassName);
    end
  else
    begin
      if EditorClassName = '' then
        frmOptions := TfrmOptions.Create(Application)
      else
        frmOptions := TfrmOptions.Create(Application, EditorClassName);

      frmOptions.Show;
  end;
  Result := frmOptions;
end;

procedure SortConfigurationOptionsOnLeftTree;
begin
{$IFDEF DARWIN}
  Exit; // the macOS tree keeps its fixed section order
{$ENDIF}
  if frmOptions<>nil then frmOptions.tvTreeView.CustomSort(@frmOptions.CompareTwoNodeOfConfigurationOptionTree);
end;

{ TfrmOptions }

procedure TfrmOptions.FormCreate(Sender: TObject);
begin
  // Initialize property storage
  InitPropStorage(Self);
  TreeFilterEdit.Visible:= (OptionsSearchCache.Count > 0);
{$IFDEF DARWIN}
  self.BorderIcons:= self.BorderIcons - [biMinimize];
  // Room for the wider sidebar plus the widest pages
  if Width < 1000 then Width:= 1000;
  if Height < 640 then Height:= 640;
{$ENDIF}
end;

procedure TfrmOptions.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction:= caFree;
  frmOptions:= nil;
end;

procedure TfrmOptions.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  CanClose := (ModalResult in [mrOK, mrCancel]) or CycleThroughOptionEditors(False);
end;

procedure TfrmOptions.btnCancelMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  // set ModalResult when mouse click, to pass FormCloseQuery
  ModalResult:= mrCancel;
end;

procedure TfrmOptions.btnCancelClick(Sender: TObject);
begin
  // close window
  Close;
end;

procedure TfrmOptions.btnHelpClick(Sender: TObject);
begin
  ShowHelpOrErrorForKeyword('', HelpKeyword);
end;

procedure TfrmOptions.btnOKClick(Sender: TObject);
begin
  // save all configuration
  SaveConfig;
  // write to config file
  SaveGlobs;
  // close window
  Close;
end;

procedure TfrmOptions.btnApplyClick(Sender: TObject);
begin
  // save all configuration
  SaveConfig;
  // write to config file
  SaveGlobs;
end;

procedure TfrmOptions.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FOptionsEditorList);
end;

procedure TfrmOptions.splOptionsSplitterMoved(Sender: TObject);
var
  ARight, ADelta: Integer;
begin
  ADelta:= ScaleX(8, DesignTimePPI) * 2 + btnHelp.Width;
  ARight:= splOptionsSplitter.Left;
  if (ARight > (btnOK.Left - ADelta)) then
  begin
    ARight:= btnOK.Left - ADelta;
  end;
  TreeFilterEdit.Width:= (ARight - TreeFilterEdit.Left);
end;

function TfrmOptions.TreeFilterEditFilterItem(ItemData: Pointer; out
  Done: Boolean): Boolean;
var
  Index: Integer;
  AClassName: String;
  AFind, AText: String;
  POFileItem: TPOFileItem;
  aOptionsEditorView: TOptionsEditorView absolute ItemData;
begin
  Done:= True;
  AFind:= TreeFilterEdit.Text;
  if Length(AFind) = 0 then Exit(True);
  // Section headers have no editor; they show when a page under them matches
  if aOptionsEditorView = nil then Exit(False);

  AFind:= UTF8LowerCase(AFind);
  AClassName:= LowerCase(aOptionsEditorView.EditorClass.ClassName);

  for Index:= 0 to OptionsSearchCache.Count - 1 do
  begin
    POFileItem:= TPOFileItem(OptionsSearchCache[Index]);

    if Length(POFileItem.Translation) = 0 then
      AText:= POFileItem.Original
    else begin
      AText:= POFileItem.Translation;
    end;
    AText:= UTF8LowerCase(StripHotkey(AText));

    if Pos(AFind, AText) > 0 then
    begin
      if StrBegins(POFileItem.IdentifierLow, AClassName) then
      begin
        // DebugLn(AClassName + ': ' + AText);
        Exit(True);
      end;
    end;
  end;
  Result:= False;
end;

function TfrmOptions.CompareTwoNodeOfConfigurationOptionTree(Node1, Node2: TTreeNode): integer;
begin
  case gSortOrderOfConfigurationOptionsTree of
    scoClassicLegacy:
      begin
        if TOptionsEditorView(Node1.Data).LegacyOrderIndex < TOptionsEditorView(Node2.Data).LegacyOrderIndex then result:=-1 else result:=1;
      end;

    scoAlphabeticalButLanguage:
      begin
        if (TOptionsEditorView(Node1.Data).EditorClass.ClassName='TfrmOptionsLanguage') or (TOptionsEditorView(Node1.Data).EditorClass.ClassName='TfrmOptionsFilesViewsComplement') then
          result:=-1
        else
          if (TOptionsEditorView(Node2.Data).EditorClass.ClassName='TfrmOptionsLanguage') or (TOptionsEditorView(Node1.Data).EditorClass.ClassName='TfrmOptionsFilesViewsComplement') then
            result:=1
          else
            result:=CompareStrings(Node1.Text, Node2.Text, gSortNatural, gSortSpecial, gSortCaseSensitivity)
      end;
  end;
end;

procedure TfrmOptions.CreateOptionsEditorList;
  procedure AddEditors(EditorClassList: TOptionsEditorClassList; RootNode: TTreeNode);
  var
    I: LongInt;
    aOptionsEditorClass: TOptionsEditorClass;
    aOptionsEditorView: TOptionsEditorView;
    TreeNode: TTreeNode;
    IconIndex: Integer;
  begin
    for I:= 0 to EditorClassList.Count - 1 do
    begin
      aOptionsEditorClass := EditorClassList[I].EditorClass;

      aOptionsEditorView := TOptionsEditorView.Create;
      aOptionsEditorView.EditorClass := aOptionsEditorClass;
      aOptionsEditorView.Instance    := nil;
      aOptionsEditorView.LegacyOrderIndex:=I;
      FOptionsEditorList.Add(aOptionsEditorView);

      TreeNode := tvTreeView.Items.AddChild(RootNode,
{$IF lcl_fullversion >= 093100}
        aOptionsEditorClass.GetTitle
{$ELSE}
        StringReplace(aOptionsEditorClass.GetTitle, '&', '&&', [rfReplaceAll])
{$ENDIF}
        );
      if Assigned(TreeNode) then
      begin
        IconIndex := aOptionsEditorClass.GetIconIndex;
        TreeNode.ImageIndex    := IconIndex;
        TreeNode.SelectedIndex := IconIndex;
        TreeNode.StateIndex    := IconIndex;
        TreeNode.Data          := aOptionsEditorView;
      end;

      aOptionsEditorView.TreeNode := TreeNode;

      if EditorClassList[I].HasChildren then
        AddEditors(EditorClassList[I].Children, TreeNode);
    end;

    //2014-08-12:Let's sort by alphabetical order this list.
    tvTreeView.CustomSort(@CompareTwoNodeOfConfigurationOptionTree);
  end;
begin
  FOptionsEditorList:= TOptionsEditorViews.Create;
{$IFDEF DARWIN}
  BuildDarwinTree;
  Exit;
{$ENDIF}
  AddEditors(OptionsEditorClassList, nil);
  case gCollapseConfigurationOptionsTree of
    ctsFullExpand: ; //By legacy, it was doing automaticall the tvTreeView.FullExpand;
    ctsFullCollapse: tvTreeView.FullCollapse;
  end;
end;

function TfrmOptions.GetEditor(EditorClass: TOptionsEditorClass): TOptionsEditor;
var
  I: Integer;
begin
  for I := 0 to FOptionsEditorList.Count - 1 do
  begin
    if FOptionsEditorList[I].EditorClass = EditorClass then
    begin
      if not Assigned(FOptionsEditorList[I].Instance) then
        FOptionsEditorList[I].Instance := CreateEditor(FOptionsEditorList[I].EditorClass);
      Result := FOptionsEditorList[I].Instance;
      Exit;
    end;
  end;
  Result := nil;
end;

procedure TfrmOptions.LoadSettings;
begin
  LoadConfig;
end;

procedure TfrmOptions.SelectEditor(EditorClassName: String);
var
  I: Integer;
begin
  for I := 0 to FOptionsEditorList.Count - 1 do
  begin
    if (FOptionsEditorList[I].EditorClass.ClassName = EditorClassName) then
      if Assigned(FOptionsEditorList[I].TreeNode) then
      begin
        FOptionsEditorList[I].TreeNode.Selected := True;
        Application.QueueAsyncCall(@MakeVisible, PtrInt(FOptionsEditorList[I].TreeNode));
        Break;
      end;
  end;
end;

constructor TfrmOptions.Create(TheOwner: TComponent);
begin
  if not Assigned(LastOpenedEditor) and (OptionsEditorClassList.Count > 0) then
    LastOpenedEditor := OptionsEditorClassList[0].EditorClass; // Select first editor.
  Create(TheOwner, LastOpenedEditor);
end;

constructor TfrmOptions.Create(TheOwner: TComponent; EditorClass: TOptionsEditorClass);
begin
  if Assigned(EditorClass) then
    Create(TheOwner, EditorClass.ClassName)
  else
    Create(TheOwner, '');
end;

constructor TfrmOptions.Create(TheOwner: TComponent; EditorClassName: String);
begin
  if (EditorClassName = '') and Assigned(LastOpenedEditor) then
    EditorClassName := LastOpenedEditor.ClassName;
  FOldEditor := nil;
  inherited Create(TheOwner);
{$IFDEF DARWIN}
  // Before any page is created: pages can force the native buttons into
  // existence, after which glyph changes no longer reach them
  ApplyDarwinStyle;
{$ENDIF}
  CreateOptionsEditorList;
  SelectEditor(EditorClassName);
{$if lcl_fullversion >= 2030000}
  // Lazarus 2.3 workaround (fixes selection reset)
  TreeFilterEdit.IdleConnected := False;
{$endif}
end;

procedure TfrmOptions.tvTreeViewChange(Sender: TObject; Node: TTreeNode);
var
  SelectedEditorView: TOptionsEditorView;
begin
  if (Node = nil) then Exit;
  SelectedEditorView := TOptionsEditorView(Node.Data);

  if Assigned(SelectedEditorView) and (FOldEditor <> SelectedEditorView) then
  begin
    if Assigned(FOldEditor) and Assigned(FOldEditor.Instance) then
      FOldEditor.Instance.Visible := False;

    if not Assigned(SelectedEditorView.Instance) then
      SelectedEditorView.Instance := CreateEditor(SelectedEditorView.EditorClass);

    if Assigned(SelectedEditorView.Instance) then
      SelectedEditorView.Instance.Visible := True;

    lblEmptyEditor.Visible := not Assigned(SelectedEditorView.Instance);

    FOldEditor := SelectedEditorView;
    LastOpenedEditor := SelectedEditorView.EditorClass;

    pnlCaption.Caption := SelectedEditorView.EditorClass.GetTitle;

    if Assigned(SelectedEditorView.Instance) then
    begin
      HelpKeyword:= SelectedEditorView.Instance.HelpKeyword;
      btnHelp.Visible := HelpKeyword <> '';
    end
    else
      btnHelp.Visible:= False;
  end;
end;

function TfrmOptions.CreateEditor(EditorClass: TOptionsEditorClass): TOptionsEditor;
begin
  if Assigned(EditorClass) and not EditorClass.IsEmpty then
  begin
    Result := EditorClass.Create(Self);
    Result.Align   := alClient;
    Result.Visible := False;
    Result.Init(sboxOptionsEditor, Self, [oeifLoad]);
  end
  else
    Result := nil;
end;

procedure TfrmOptions.LoadConfig;
var
  I: LongInt;
begin
  { Load options to frames }
  for I:= 0 to FOptionsEditorList.Count - 1 do
  begin
    if Assigned(FOptionsEditorList[I].Instance) then
      FOptionsEditorList[I].Instance.LoadSettings;
  end;
end;

procedure TfrmOptions.SaveConfig;
begin
  CycleThroughOptionEditors(True);
end;

{ TfrmOptions.CycleThroughOptionEditors }
// -Will cycle through all option editors to either:
//   >Prompt user to save change if any, discard change if any, etc.
//   >Force saving eventual modification without asking.
// -In case we prompt user save changes or not, user may answer that he wants to
//  CANCEL exit. If so, that's the only case where the function will return FALSE.
// -Could be call from a simple "APPLY" or "OK" from the main option window and
//  if so, will save any modification.
// -Could be call from "CANCEL" or "Attempt to close with the 'x' of the window
//  and if so, will prompt user to save modifications, discard modification or
//  cancel exiting.
function TfrmOptions.CycleThroughOptionEditors(bForceSaving: boolean): boolean;
var
  I: integer;
  SaveFlags: TOptionsEditorSaveFlags = [];
  bNeedsRestart: boolean = False;
begin
  Result := True;

  I := 0;
  while (I < FOptionsEditorList.Count) and (Result) do
  begin
    if Assigned(FOptionsEditorList[I].Instance) then
    begin
      try
        Result := FOptionsEditorList[I].Instance.CanWeClose(SaveFlags, bForceSaving);

        if oesfNeedsRestart in SaveFlags then
          bNeedsRestart := True;

      except
        on E: Exception do
          MessageDlg(FOptionsEditorList[I].Instance.GetTitle, E.Message, mtError, [mbOK], 0);
      end;
    end;

    Inc(I);
  end;

  if bNeedsRestart then
    MessageDlg(rsMsgRestartForApplyChanges, mtInformation, [mbOK], 0);

  frmMain.UpdateWindowView; // Let's refresh the views.
                            // In fact, may settings would not really require it since they don't have an immediate visual impact.
                            // But let's do it for two reasons:
                            //  1st) Previously with "SaveConfig" it was updating it no matter what.
                            //  2nd) The little delay and visual blink it gives to user is a good feedback to him confirming him he just saved settings.
end;

procedure TfrmOptions.MakeVisible(Data: PtrInt);
var
  TreeNode: TTreeNode absolute Data;
begin
  TreeNode.MakeVisible;
  TreeFilterEdit.StoreSelection;
end;

procedure TfrmOptions.CMThemeChanged(var Message: TLMessage);
var
  Index: Integer;
begin
  for Index:= 0 to FOptionsEditorList.Count - 1 do
  begin
    if Assigned(FOptionsEditorList[Index].Instance) then
    begin
      FOptionsEditorList[Index].Instance.Perform(CM_THEMECHANGED, 0, 0);
    end;
  end;
end;

{$IFDEF DARWIN}
procedure TfrmOptions.BuildDarwinTree;
var
  Images: TImageList;
  Entry: TOptionsTreeEntry;
  Section, ParentNode, Node: TTreeNode;
  View: TOptionsEditorView;
  I: Integer;

  procedure CollectViews(List: TOptionsEditorClassList);
  var
    J: Integer;
    V: TOptionsEditorView;
  begin
    for J:= 0 to List.Count - 1 do
    begin
      V:= TOptionsEditorView.Create;
      V.EditorClass:= List[J].EditorClass;
      V.LegacyOrderIndex:= FOptionsEditorList.Count;
      FOptionsEditorList.Add(V);
      if List[J].HasChildren then CollectViews(List[J].Children);
    end;
  end;

  function FindView(const AClassName: String): TOptionsEditorView;
  var
    J: Integer;
  begin
    for J:= 0 to FOptionsEditorList.Count - 1 do
      if SameText(FOptionsEditorList[J].EditorClass.ClassName, AClassName) then
        Exit(FOptionsEditorList[J]);
    Result:= nil;
  end;

  function AddSection(const ATitle: String): TTreeNode;
  begin
    Result:= tvTreeView.Items.Add(nil, ATitle);
    Result.ImageIndex:= -1;
    Result.SelectedIndex:= -1;
    Result.Data:= nil;
  end;

  function AddPage(AParent: TTreeNode; V: TOptionsEditorView): TTreeNode;
  var
    Small, Large: TBitmap;
  begin
    Result:= tvTreeView.Items.AddChild(AParent, V.EditorClass.GetTitle);
    Result.Data:= V;
    Result.ImageIndex:= -1;
    Small:= OptionsPageIcon(V.EditorClass.ClassName, Images.Width, 1);
    Large:= OptionsPageIcon(V.EditorClass.ClassName, Images.Width, 2);
    try
      if Assigned(Small) and Assigned(Large) then
        Result.ImageIndex:= Images.AddMultipleResolutions([TCustomBitmap(Small), TCustomBitmap(Large)]);
    finally
      Small.Free;
      Large.Free;
    end;
    Result.SelectedIndex:= Result.ImageIndex;
    V.TreeNode:= Result;
  end;

begin
  CollectViews(OptionsEditorClassList);

  Images:= TImageList.Create(Self);
  Images.Width:= 20;
  Images.Height:= 20;
  Images.Scaled:= True;
  Images.RegisterResolutions([20, 40]);

  tvTreeView.Items.BeginUpdate;
  try
    Section:= nil;
    ParentNode:= nil;
    for Entry in OptionsTreeLayout do
    begin
      if Entry.Section <> '' then
        Section:= AddSection(Entry.Section);
      View:= FindView(Entry.EditorClass);
      if (View = nil) or Assigned(View.TreeNode) or (Section = nil) then Continue;
      if (Entry.Level > 0) and Assigned(ParentNode) then
        AddPage(ParentNode, View)
      else
        ParentNode:= AddPage(Section, View);
    end;

    // Pages the layout doesn't know about (new upstream pages) still show up
    Section:= nil;
    for I:= 0 to FOptionsEditorList.Count - 1 do
      if FOptionsEditorList[I].TreeNode = nil then
      begin
        if Section = nil then Section:= AddSection(rsOptSectionOther);
        AddPage(Section, FOptionsEditorList[I]);
      end;

    // Drop sections that ended up empty
    Node:= tvTreeView.Items.GetFirstNode;
    while Assigned(Node) do
    begin
      ParentNode:= Node.GetNextSibling;
      if not Node.HasChildren then Node.Delete;
      Node:= ParentNode;
    end;
  finally
    tvTreeView.Items.EndUpdate;
  end;

  tvTreeView.Images:= Images;
  tvTreeView.ImagesWidth:= Images.Width;
  tvTreeView.FullExpand;
end;

procedure TfrmOptions.ApplyDarwinStyle;
begin
  with tvTreeView do
  begin
    Options:= [tvoReadOnly, tvoRowSelect, tvoToolTips, tvoKeepCollapsedNodes];
    BorderStyle:= bsNone;
    DefaultItemHeight:= 28;
    Indent:= 16;
    // Fits the longest page title ("Tree View Menu Colors") at depth 2
    Constraints.MinWidth:= 250;
    if Width < 250 then Width:= 250;
    OnAdvancedCustomDrawItem:= @tvDarwinCustomDrawItem;
    OnChanging:= @tvDarwinChanging;
    OnCollapsing:= @tvDarwinCollapsing;
  end;

  // Page title: large, left-aligned text instead of a grey bar
  with pnlCaption do
  begin
    ParentColor:= True;
    ParentBackground:= True;
    BevelOuter:= bvNone;
    Alignment:= taLeftJustify;
    BorderSpacing.Left:= 16;
    BorderSpacing.Top:= 8;
    Height:= 40;
    Font.Color:= clDefault;
    Font.Size:= 17;
    Font.Style:= [fsBold];
  end;

  // Plain macOS push buttons: drop the stock check/cross/question glyphs
  btnOK.Kind:= bkCustom;
  btnCancel.Kind:= bkCustom;
  btnHelp.Kind:= bkCustom;
  btnOK.GlyphShowMode:= gsmNever;
  btnCancel.GlyphShowMode:= gsmNever;
  btnHelp.GlyphShowMode:= gsmNever;
  TreeFilterEdit.TextHint:= 'Search';
end;

procedure TfrmOptions.tvDarwinCustomDrawItem(Sender: TCustomTreeView;
  Node: TTreeNode; State: TCustomDrawState; Stage: TCustomDrawStage;
  var PaintImages, DefaultDraw: Boolean);
begin
  if Stage <> cdPrePaint then Exit;
  if Node.Data = nil then
  begin
    // Section header: small, bold, grey
    Sender.Canvas.Font.Style:= [fsBold];
    Sender.Canvas.Font.Size:= 11;
    Sender.Canvas.Font.Color:= clGrayText;
  end
  else
  begin
    Sender.Canvas.Font.Style:= [];
    Sender.Canvas.Font.Size:= 0;
    Sender.Canvas.Font.Color:= clDefault;
  end;
end;

procedure TfrmOptions.tvDarwinChanging(Sender: TObject; Node: TTreeNode;
  var AllowChange: Boolean);
begin
  AllowChange:= (Node = nil) or (Node.Data <> nil);
end;

procedure TfrmOptions.tvDarwinCollapsing(Sender: TObject; Node: TTreeNode;
  var AllowCollapse: Boolean);
begin
  AllowCollapse:= False;
end;
{$ENDIF}

finalization
  FreeAndNil(OptionsSearchCache);
  FreeAndNil(OptionsSearchFile);

end.
