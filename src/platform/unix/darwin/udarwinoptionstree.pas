{
   Double Commander
   -------------------------------------------------------------------------
   macOS look for the Options tree: pages grouped into sections, each with
   a System Settings-style icon (white SF Symbol on a coloured rounded square).

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
}

unit uDarwinOptionsTree;

{$mode objfpc}{$H+}
{$modeswitch objectivec2}

interface

uses
  Classes, SysUtils, Graphics;

type
  TOptionsTreeEntry = record
    Section: String;    // non-empty: starts a new section with this title
    EditorClass: String;
    Level: Integer;     // 0 = directly under the section, 1 = sub-page
  end;

resourcestring
  rsOptSectionGeneral = 'General';
  rsOptSectionAppearance = 'Appearance';
  rsOptSectionPanels = 'File Panels';
  rsOptSectionFiles = 'Files';
  rsOptSectionInput = 'Keyboard & Mouse';
  rsOptSectionTools = 'Tools';
  rsOptSectionPlugins = 'Plugins';
  rsOptSectionOther = 'Other';

// The tree layout, in display order. Pages not listed land under "Other".
function OptionsTreeLayout: specialize TArray<TOptionsTreeEntry>;

// Icon for an options page, rendered at Size points and Scale x.
// Returns nil when SF Symbols are unavailable (macOS < 11).
function OptionsPageIcon(const EditorClassName: String; Size, Scale: Integer): TBitmap;

implementation

uses
  MacOSAll, CocoaAll, CocoaUtils, Cocoa_Extra, uClassesEx;

type
  TIconSpec = record
    EditorClass: String;
    Symbol: String;
    Color: LongWord;  // $RRGGBB
  end;

const
  // System Settings palette
  cBlue   = $0A84FF;
  cIndigo = $5E5CE6;
  cPurple = $BF5AF2;
  cPink   = $FF375F;
  cRed    = $FF453A;
  cOrange = $FF9F0A;
  cYellow = $FFB800;
  cGreen  = $30B94D;
  cTeal   = $30A0C8;
  cBrown  = $A2845E;
  cGray   = $8E8E93;
  cGraphite = $5A5A5F;

  ICONS: array[0..54] of TIconSpec = (
    (EditorClass: 'TfrmOptionsLanguage';            Symbol: 'globe';                       Color: cBlue),
    (EditorClass: 'TfrmOptionsBehavior';            Symbol: 'gearshape';                   Color: cGray),
    (EditorClass: 'TfrmOptionsConfiguration';       Symbol: 'doc.badge.gearshape';         Color: cGray),
    (EditorClass: 'TfrmOptionsAutoRefresh';         Symbol: 'arrow.clockwise';             Color: cGreen),
    (EditorClass: 'TfrmOptionsMisc';                Symbol: 'ellipsis';                    Color: cGray),
    (EditorClass: 'TfrmOptionsiCloud';              Symbol: 'icloud';                      Color: cBlue),
    (EditorClass: 'TfrmOptionsToolTips';            Symbol: 'text.bubble';                 Color: cYellow),
    (EditorClass: 'TfrmOptionsLog';                 Symbol: 'list.bullet.rectangle';       Color: cGraphite),

    (EditorClass: 'TfrmOptionsColors';              Symbol: 'paintpalette';                Color: cPink),
    (EditorClass: 'TfrmOptionsFilePanelsColors';    Symbol: 'rectangle.split.2x1';         Color: cPink),
    (EditorClass: 'TfrmOptionsFileTypesColors';     Symbol: 'doc.text';                    Color: cPink),
    (EditorClass: 'TfrmOptionsFonts';               Symbol: 'textformat';                  Color: cGraphite),
    (EditorClass: 'TfrmOptionsIcons';               Symbol: 'square.grid.2x2';             Color: cPurple),
    (EditorClass: 'TfrmOptionsLayout';              Symbol: 'macwindow';                   Color: cIndigo),
    (EditorClass: 'TfrmOptionsDrivesListButton';    Symbol: 'internaldrive';               Color: cIndigo),
    (EditorClass: 'TfrmOptionsTreeViewMenu';        Symbol: 'list.bullet.indent';          Color: cIndigo),
    (EditorClass: 'TfrmOptionsTreeViewMenuColor';   Symbol: 'paintbrush';                  Color: cIndigo),
    (EditorClass: 'TfrmOptionsToolbar';             Symbol: 'menubar.rectangle';           Color: cIndigo),
    (EditorClass: 'TfrmOptionsToolbarMiddle';       Symbol: 'rectangle.split.3x1';         Color: cIndigo),
    (EditorClass: 'TfrmOptionsToolbarExtra';        Symbol: 'slider.horizontal.3';         Color: cIndigo),

    (EditorClass: 'TfrmOptionsFilesViews';          Symbol: 'list.bullet';                 Color: cBlue),
    (EditorClass: 'TfrmOptionsFilesViewsComplement';Symbol: 'slider.horizontal.3';         Color: cBlue),
    (EditorClass: 'TfrmOptionsBriefView';           Symbol: 'square.grid.3x2';             Color: cBlue),
    (EditorClass: 'TfrmOptionsColumnsView';         Symbol: 'tablecells';                  Color: cBlue),
    (EditorClass: 'TfrmOptionsCustomColumns';       Symbol: 'rectangle.split.3x1';         Color: cBlue),
    (EditorClass: 'TfrmOptionsTabs';                Symbol: 'square.on.square';            Color: cTeal),
    (EditorClass: 'TfrmOptionsFavoriteTabs';        Symbol: 'star';                        Color: cTeal),
    (EditorClass: 'TfrmOptionsTabsExtra';           Symbol: 'plus.square.on.square';       Color: cTeal),
    (EditorClass: 'TfrmOptionsQuickSearchFilter';   Symbol: 'magnifyingglass';             Color: cOrange),
    (EditorClass: 'TfrmOptionsIgnoreList';          Symbol: 'eye.slash';                   Color: cGray),
    (EditorClass: 'TfrmOptionsDirectoryHotlist';    Symbol: 'bookmark';                    Color: cOrange),
    (EditorClass: 'TfrmOptionsDirectoryHotlistExtra';Symbol: 'bookmark.circle';            Color: cOrange),

    (EditorClass: 'TfrmOptionsFileOperations';      Symbol: 'doc.on.doc';                  Color: cGreen),
    (EditorClass: 'TfrmOptionsFileSearch';          Symbol: 'doc.text.magnifyingglass';    Color: cGreen),
    (EditorClass: 'TfrmOptionsMultiRename';         Symbol: 'character.cursor.ibeam';      Color: cGreen),
    (EditorClass: 'TfrmOptionsFileAssoc';           Symbol: 'arrow.up.forward.app';        Color: cPurple),
    (EditorClass: 'TfrmOptionsFileAssocExtra';      Symbol: 'app.badge';                   Color: cPurple),
    (EditorClass: 'TfrmOptionsArchivers';           Symbol: 'archivebox';                  Color: cBrown),

    (EditorClass: 'TfrmOptionsKeyboard';            Symbol: 'keyboard';                    Color: cGraphite),
    (EditorClass: 'TfrmOptionsHotkeys';             Symbol: 'command';                     Color: cGraphite),
    (EditorClass: 'TfrmOptionsMouse';               Symbol: 'computermouse';               Color: cGraphite),
    (EditorClass: 'TfrmOptionsDragDrop';            Symbol: 'hand.draw';                   Color: cGraphite),

    (EditorClass: 'TfrmOptionsViewer';              Symbol: 'eye';                         Color: cBlue),
    (EditorClass: 'TfrmOptionsEditor';              Symbol: 'pencil';                      Color: cOrange),
    (EditorClass: 'TfrmOptionsEditorColors';        Symbol: 'highlighter';                 Color: cOrange),
    (EditorClass: 'TfrmOptionsDiffer';              Symbol: 'arrow.left.arrow.right';      Color: cRed),
    (EditorClass: 'TfrmOptionsTerminal';            Symbol: 'terminal';                    Color: cGraphite),

    (EditorClass: 'TfrmOptionsPluginsGroup';        Symbol: 'puzzlepiece.extension';       Color: cGreen),
    (EditorClass: 'TfrmOptionsPluginsWCX';          Symbol: 'archivebox';                  Color: cGreen),
    (EditorClass: 'TfrmOptionsPluginsWFX';          Symbol: 'externaldrive.connected.to.line.below'; Color: cGreen),
    (EditorClass: 'TfrmOptionsPluginsWLX';          Symbol: 'eye';                         Color: cGreen),
    (EditorClass: 'TfrmOptionsPluginsWDX';          Symbol: 'tag';                         Color: cGreen),
    (EditorClass: 'TfrmOptionsPluginsDSX';          Symbol: 'magnifyingglass';             Color: cGreen),

    (EditorClass: '';                               Symbol: 'gearshape';                   Color: cGray),
    (EditorClass: '';                               Symbol: 'gearshape';                   Color: cGray)
  );

function OptionsTreeLayout: specialize TArray<TOptionsTreeEntry>;
var
  Count: Integer = 0;

  procedure Add(const ASection, AClass: String; ALevel: Integer = 0);
  begin
    if Count >= Length(Result) then SetLength(Result, Count + 16);
    Result[Count].Section:= ASection;
    Result[Count].EditorClass:= AClass;
    Result[Count].Level:= ALevel;
    Inc(Count);
  end;

begin
  Result:= nil;
  Add(rsOptSectionGeneral, 'TfrmOptionsBehavior');
  Add('', 'TfrmOptionsLanguage');
  Add('', 'TfrmOptionsConfiguration');
  Add('', 'TfrmOptionsAutoRefresh');
  Add('', 'TfrmOptionsiCloud');
  Add('', 'TfrmOptionsToolTips');
  Add('', 'TfrmOptionsLog');
  Add('', 'TfrmOptionsMisc');

  Add(rsOptSectionAppearance, 'TfrmOptionsLayout');
  Add('', 'TfrmOptionsDrivesListButton', 1);
  Add('', 'TfrmOptionsTreeViewMenu', 1);
  Add('', 'TfrmOptionsTreeViewMenuColor', 1);
  Add('', 'TfrmOptionsColors');
  Add('', 'TfrmOptionsFilePanelsColors', 1);
  Add('', 'TfrmOptionsFileTypesColors', 1);
  Add('', 'TfrmOptionsFonts');
  Add('', 'TfrmOptionsIcons');
  Add('', 'TfrmOptionsToolbar');
  Add('', 'TfrmOptionsToolbarMiddle', 1);
  Add('', 'TfrmOptionsToolbarExtra', 1);

  Add(rsOptSectionPanels, 'TfrmOptionsFilesViews');
  Add('', 'TfrmOptionsFilesViewsComplement', 1);
  Add('', 'TfrmOptionsBriefView', 1);
  Add('', 'TfrmOptionsColumnsView', 1);
  Add('', 'TfrmOptionsCustomColumns', 1);
  Add('', 'TfrmOptionsTabs');
  Add('', 'TfrmOptionsFavoriteTabs', 1);
  Add('', 'TfrmOptionsTabsExtra', 1);
  Add('', 'TfrmOptionsQuickSearchFilter');
  Add('', 'TfrmOptionsIgnoreList');
  Add('', 'TfrmOptionsDirectoryHotlist');
  Add('', 'TfrmOptionsDirectoryHotlistExtra', 1);

  Add(rsOptSectionFiles, 'TfrmOptionsFileOperations');
  Add('', 'TfrmOptionsFileSearch');
  Add('', 'TfrmOptionsMultiRename');
  Add('', 'TfrmOptionsFileAssoc');
  Add('', 'TfrmOptionsFileAssocExtra', 1);
  Add('', 'TfrmOptionsArchivers');

  Add(rsOptSectionInput, 'TfrmOptionsKeyboard');
  Add('', 'TfrmOptionsHotkeys');
  Add('', 'TfrmOptionsMouse');
  Add('', 'TfrmOptionsDragDrop');

  Add(rsOptSectionTools, 'TfrmOptionsViewer');
  Add('', 'TfrmOptionsEditor');
  Add('', 'TfrmOptionsEditorColors', 1);
  Add('', 'TfrmOptionsDiffer');
  Add('', 'TfrmOptionsTerminal');

  Add(rsOptSectionPlugins, 'TfrmOptionsPluginsGroup');
  Add('', 'TfrmOptionsPluginsWCX');
  Add('', 'TfrmOptionsPluginsWFX');
  Add('', 'TfrmOptionsPluginsWLX');
  Add('', 'TfrmOptionsPluginsWDX');
  Add('', 'TfrmOptionsPluginsDSX');
  SetLength(Result, Count);
end;

function FindIcon(const EditorClassName: String): TIconSpec;
var
  I: Integer;
begin
  for I:= Low(ICONS) to High(ICONS) do
    if SameText(ICONS[I].EditorClass, EditorClassName) then
      Exit(ICONS[I]);
  Result:= ICONS[High(ICONS)];
end;

function SymbolImage(const Name: String; PointSize: CGFloat): NSImage;
var
  Config: NSImageSymbolConfiguration;
begin
  Result:= NSImage.imageWithSystemSymbolName_accessibilityDescription(StrToNSString(Name), nil);
  if Result = nil then
    Result:= NSImage.imageWithSystemSymbolName_accessibilityDescription(NSSTR('gearshape'), nil);
  if Result = nil then Exit;
  Config:= NSImageSymbolConfiguration.configurationWithPointSize(PointSize, 0.23 { medium });
  Result:= Result.imageWithSymbolConfiguration(Config);
end;

function OptionsPageIcon(const EditorClassName: String; Size, Scale: Integer): TBitmap;
var
  Spec: TIconSpec;
  Px: Integer;
  Rep: NSBitmapImageRep;
  Symbol, Tinted: NSImage;
  SymSize: NSSize;
  R: NSRect;
  Color: NSColor;
  Data: NSData;
  Stream: TBlobStream;
  Png: TPortableNetworkGraphic;
begin
  Result:= nil;
  if not NSImage.instancesRespondToSelector(ObjCSelector('imageWithSymbolConfiguration:')) then
    Exit;

  Spec:= FindIcon(EditorClassName);
  Px:= Size * Scale;
  Symbol:= SymbolImage(Spec.Symbol, Px * 0.5);
  if Symbol = nil then Exit;

  // White glyph: draw the template symbol, then paint white over its pixels
  SymSize:= Symbol.size;
  Tinted:= NSImage.alloc.initWithSize(SymSize).autorelease;
  Tinted.lockFocus;
  Symbol.drawInRect(NSMakeRect(0, 0, SymSize.width, SymSize.height));
  NSColor.whiteColor.set_;
  NSRectFillUsingOperation(NSMakeRect(0, 0, SymSize.width, SymSize.height), NSCompositeSourceAtop);
  Tinted.unlockFocus;

  Rep:= NSBitmapImageRep.alloc.initWithBitmapDataPlanes_pixelsWide_pixelsHigh__colorSpaceName_bytesPerRow_bitsPerPixel(
    nil, Px, Px, 8, 4, True, False, NSDeviceRGBColorSpace, 0, 0).autorelease;

  NSGraphicsContext.classSaveGraphicsState;
  try
    NSGraphicsContext.setCurrentContext(NSGraphicsContext.graphicsContextWithBitmapImageRep(Rep));

    // Badge: 1px inset so the rounded corners are not clipped
    Color:= NSColor.colorWithCalibratedRed_green_blue_alpha(
      ((Spec.Color shr 16) and $FF) / 255, ((Spec.Color shr 8) and $FF) / 255,
      (Spec.Color and $FF) / 255, 1);
    Color.setFill;
    R:= NSMakeRect(Scale, Scale, Px - 2 * Scale, Px - 2 * Scale);
    NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius(R, Px * 0.22, Px * 0.22).fill;

    // Symbol, centred, fitted into 62% of the badge
    if (SymSize.width > 0) and (SymSize.height > 0) then
    begin
      R.size.width:= Px * 0.62;
      R.size.height:= R.size.width * SymSize.height / SymSize.width;
      if R.size.height > Px * 0.62 then
      begin
        R.size.height:= Px * 0.62;
        R.size.width:= R.size.height * SymSize.width / SymSize.height;
      end;
      R.origin.x:= (Px - R.size.width) / 2;
      R.origin.y:= (Px - R.size.height) / 2;
      Tinted.drawInRect_fromRect_operation_fraction(R, NSZeroRect, NSCompositeSourceOver, 1);
    end;
  finally
    NSGraphicsContext.classRestoreGraphicsState;
  end;

  Data:= Rep.representationUsingType_properties(NSPNGFileType, nil);
  Stream:= TBlobStream.Create(Data.bytes, Data.length);
  Png:= TPortableNetworkGraphic.Create;
  try
    Png.LoadFromStream(Stream);
    Result:= TBitmap.Create;
    Result.Assign(Png);
  finally
    Png.Free;
    Stream.Free;
  end;
end;

end.
