{
   Double Commander
   -------------------------------------------------------------------------
   SF Symbols rendered into LCL bitmaps: plain toolbar glyphs for commands,
   and System Settings-style badges (white glyph on a coloured square).

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
}

unit uDarwinSymbols;

{$mode objfpc}{$H+}
{$modeswitch objectivec2}

interface

uses
  Classes, SysUtils, Graphics, CocoaAll;

// Symbol drawn into a Px x Px bitmap. With BadgeColor <> nil the glyph sits
// on a rounded square of that colour. Returns nil before macOS 11.
function RenderSymbol(const Symbol: String; Px: Integer; GlyphColor: NSColor;
  BadgeColor: NSColor = nil): TBitmap;

// Toolbar glyph for a command icon name such as 'cm_refresh', in the text
// colour of the current appearance. nil when the command has no symbol.
function CommandSymbolBitmap(const IconName: String; Px: Integer): TBitmap;

function RGBColor(RGB: LongWord): NSColor;

implementation

uses
  MacOSAll, CocoaUtils, Cocoa_Extra, uClassesEx;

type
  TCommandSymbol = record
    Command: String;
    Symbol: String;
  end;

const
  COMMAND_SYMBOLS: array[0..57] of TCommandSymbol = (
    (Command: 'cm_refresh';             Symbol: 'arrow.clockwise'),
    (Command: 'cm_runterm';             Symbol: 'terminal'),
    (Command: 'cm_options';             Symbol: 'gearshape'),
    (Command: 'cm_briefview';           Symbol: 'rectangle.split.3x1'),
    (Command: 'cm_columnsview';         Symbol: 'list.bullet'),
    (Command: 'cm_thumbnailsview';      Symbol: 'square.grid.2x2'),
    (Command: 'cm_flatview';            Symbol: 'square.stack.3d.down.right'),
    (Command: 'cm_viewhistoryprev';     Symbol: 'chevron.left'),
    (Command: 'cm_viewhistorynext';     Symbol: 'chevron.right'),
    (Command: 'cm_viewhistory';         Symbol: 'clock'),
    (Command: 'cm_markplus';            Symbol: 'plus.circle'),
    (Command: 'cm_markminus';           Symbol: 'minus.circle'),
    (Command: 'cm_markinvert';          Symbol: 'circle.lefthalf.filled'),
    (Command: 'cm_markmarkall';         Symbol: 'checkmark.circle'),
    (Command: 'cm_markunmarkall';       Symbol: 'circle'),
    (Command: 'cm_packfiles';           Symbol: 'archivebox'),
    (Command: 'cm_extractfiles';        Symbol: 'tray.and.arrow.up'),
    (Command: 'cm_openarchive';         Symbol: 'archivebox'),
    (Command: 'cm_testarchive';         Symbol: 'checkmark.seal'),
    (Command: 'cm_networkconnect';      Symbol: 'network'),
    (Command: 'cm_networkdisconnect';   Symbol: 'xmark.icloud'),
    (Command: 'cm_search';              Symbol: 'magnifyingglass'),
    (Command: 'cm_multirename';         Symbol: 'character.cursor.ibeam'),
    (Command: 'cm_rename';              Symbol: 'pencil'),
    (Command: 'cm_renameonly';          Symbol: 'pencil'),
    (Command: 'cm_syncdirs';            Symbol: 'arrow.triangle.2.circlepath'),
    (Command: 'cm_comparecontents';     Symbol: 'arrow.left.arrow.right.square'),
    (Command: 'cm_copyfullnamestoclip'; Symbol: 'doc.on.clipboard'),
    (Command: 'cm_copynamestoclip';     Symbol: 'doc.on.clipboard'),
    (Command: 'cm_copytoclipboard';     Symbol: 'doc.on.clipboard'),
    (Command: 'cm_cuttoclipboard';      Symbol: 'scissors'),
    (Command: 'cm_pastefromclipboard';  Symbol: 'clipboard'),
    (Command: 'cm_copy';                Symbol: 'doc.on.doc'),
    (Command: 'cm_copynoask';           Symbol: 'doc.on.doc'),
    (Command: 'cm_move';                Symbol: 'arrow.right.doc.on.clipboard'),
    (Command: 'cm_delete';              Symbol: 'trash'),
    (Command: 'cm_wipe';                Symbol: 'trash.slash'),
    (Command: 'cm_edit';                Symbol: 'square.and.pencil'),
    (Command: 'cm_editnew';             Symbol: 'doc.badge.plus'),
    (Command: 'cm_view';                Symbol: 'eye'),
    (Command: 'cm_quickview';           Symbol: 'eye.square'),
    (Command: 'cm_makedir';             Symbol: 'folder.badge.plus'),
    (Command: 'cm_changedir';           Symbol: 'folder'),
    (Command: 'cm_changedirtoroot';     Symbol: 'externaldrive'),
    (Command: 'cm_changedirtohome';     Symbol: 'house'),
    (Command: 'cm_changedirtoparent';   Symbol: 'arrow.turn.left.up'),
    (Command: 'cm_dirhotlist';          Symbol: 'bookmark'),
    (Command: 'cm_swappanels';          Symbol: 'arrow.left.arrow.right'),
    (Command: 'cm_targetequalsource';   Symbol: 'equal.square'),
    (Command: 'cm_showsysfiles';        Symbol: 'eye.slash'),
    (Command: 'cm_newtab';              Symbol: 'plus.square.on.square'),
    (Command: 'cm_calculatespace';      Symbol: 'chart.pie'),
    (Command: 'cm_filespliter';         Symbol: 'scissors'),
    (Command: 'cm_filelinker';          Symbol: 'link'),
    (Command: 'cm_symlink';             Symbol: 'link'),
    (Command: 'cm_setfileproperties';   Symbol: 'info.circle'),
    (Command: 'cm_fileproperties';      Symbol: 'info.circle'),
    (Command: 'cm_exit';                Symbol: 'power')
  );

function RGBColor(RGB: LongWord): NSColor;
begin
  Result:= NSColor.colorWithCalibratedRed_green_blue_alpha(
    ((RGB shr 16) and $FF) / 255, ((RGB shr 8) and $FF) / 255, (RGB and $FF) / 255, 1);
end;

function SymbolImage(const Name: String; PointSize: CGFloat): NSImage;
var
  Config: NSImageSymbolConfiguration;
begin
  Result:= NSImage.imageWithSystemSymbolName_accessibilityDescription(StrToNSString(Name), nil);
  if Result = nil then Exit;
  Config:= NSImageSymbolConfiguration.configurationWithPointSize(PointSize, 0.23 { medium });
  Result:= Result.imageWithSymbolConfiguration(Config);
end;

function RepToBitmap(Rep: NSBitmapImageRep): TBitmap;
var
  Data: NSData;
  Stream: TBlobStream;
  Png: TPortableNetworkGraphic;
begin
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

function RenderSymbol(const Symbol: String; Px: Integer; GlyphColor: NSColor;
  BadgeColor: NSColor): TBitmap;
var
  Rep: NSBitmapImageRep;
  Image, Tinted: NSImage;
  SymSize: NSSize;
  R: NSRect;
  Fraction: Double;
begin
  Result:= nil;
  if not NSImage.instancesRespondToSelector(ObjCSelector('imageWithSymbolConfiguration:')) then
    Exit;

  if Assigned(BadgeColor) then Fraction:= 0.62 else Fraction:= 0.9;
  Image:= SymbolImage(Symbol, Px * Fraction * 0.8);
  if Image = nil then Exit;
  SymSize:= Image.size;
  if (SymSize.width <= 0) or (SymSize.height <= 0) then Exit;

  // Template symbols draw black: paint the colour over their pixels
  Tinted:= NSImage.alloc.initWithSize(SymSize).autorelease;
  Tinted.lockFocus;
  Image.drawInRect(NSMakeRect(0, 0, SymSize.width, SymSize.height));
  GlyphColor.set_;
  NSRectFillUsingOperation(NSMakeRect(0, 0, SymSize.width, SymSize.height), NSCompositeSourceAtop);
  Tinted.unlockFocus;

  Rep:= NSBitmapImageRep.alloc.initWithBitmapDataPlanes_pixelsWide_pixelsHigh__colorSpaceName_bytesPerRow_bitsPerPixel(
    nil, Px, Px, 8, 4, True, False, NSDeviceRGBColorSpace, 0, 0).autorelease;

  NSGraphicsContext.classSaveGraphicsState;
  try
    NSGraphicsContext.setCurrentContext(NSGraphicsContext.graphicsContextWithBitmapImageRep(Rep));

    if Assigned(BadgeColor) then
    begin
      // Inset so the rounded corners are not clipped
      BadgeColor.setFill;
      R:= NSMakeRect(Px / 20, Px / 20, Px * 0.9, Px * 0.9);
      NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius(R, Px * 0.22, Px * 0.22).fill;
    end;

    // Centred, fitted into Fraction of the square, aspect kept
    R.size.width:= Px * Fraction;
    R.size.height:= R.size.width * SymSize.height / SymSize.width;
    if R.size.height > Px * Fraction then
    begin
      R.size.height:= Px * Fraction;
      R.size.width:= R.size.height * SymSize.width / SymSize.height;
    end;
    R.origin.x:= (Px - R.size.width) / 2;
    R.origin.y:= (Px - R.size.height) / 2;
    Tinted.drawInRect_fromRect_operation_fraction(R, NSZeroRect, NSCompositeSourceOver, 1);
  finally
    NSGraphicsContext.classRestoreGraphicsState;
  end;

  Result:= RepToBitmap(Rep);
end;

function CommandSymbolBitmap(const IconName: String; Px: Integer): TBitmap;
var
  I: Integer;
begin
  Result:= nil;
  for I:= Low(COMMAND_SYMBOLS) to High(COMMAND_SYMBOLS) do
    if SameText(COMMAND_SYMBOLS[I].Command, IconName) then
    begin
      // controlTextColor follows the app appearance (light/dark)
      Result:= RenderSymbol(COMMAND_SYMBOLS[I].Symbol, Px, NSColor.controlTextColor);
      Exit;
    end;
end;

end.
