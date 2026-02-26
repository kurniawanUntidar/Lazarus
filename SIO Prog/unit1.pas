unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Menus, Grids, ExtCtrls,
  StdCtrls, ComCtrls;

type

  { TForm1 }

  TForm1 = class(TForm)
    MainMenu1: TMainMenu;
    MenuItem1: TMenuItem;
    Edit: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem7: TMenuItem;
    MenuItem8: TMenuItem;
    MenuItem9: TMenuItem;
    Open: TMenuItem;
    MenuItem6: TMenuItem;
    OpenDialog1: TOpenDialog;
    SaveAs: TMenuItem;
    StatusBar1: TStatusBar;
    StringGrid1: TStringGrid;
    procedure ControlBar1Click(Sender: TObject);
    procedure MenuItem5Click(Sender: TObject);
    procedure OpenClick(Sender: TObject);
  private

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.MenuItem5Click(Sender: TObject);
begin
   Application.Terminate;
end;

procedure TForm1.ControlBar1Click(Sender: TObject);
begin

end;

procedure TForm1.OpenClick(Sender: TObject);
var
  FS: TFileStream;
  Buffer: Byte;
  RowData: String;
  ASCIIStr: String;
  RowIndex, ColIndex: Integer;
  Addr: Int64;
begin
   if OpenDialog1.Execute then
   begin
     FS:= TFileStream.Create(OpenDialog1.FileName,fmOpenRead);
     try
       StringGrid1.RowCount := (FS.Size div 16)+1;
       Addr:=0;
       RowIndex := 1;
       while FS.Position < FS.Size do
             // Tampilkan alamat di kolom 0
             begin
                  StringGrid1.Cells[0,RowIndex]:= IntToHex(Addr,8)+' :';  // konvert int to hex dari addr dalam format 8 bit
                  ASCIIStr := '';
                  //Tampilkan 16 byte per baris
                  for ColIndex := 1 to 16 do
                  begin
                       if FS.Position < FS.Size then
                       begin
                         FS.Read(Buffer,1);
                         StringGrid1.Cells[ColIndex,RowIndex]:=IntToHex(Buffer,2);
                         // Konversi ke karakter ASCII jika data printable
                         if Buffer in [32..126] then
                         ASCIIStr := ASCIIStr + Chr(Buffer)
                         else
                           ASCIIStr := ASCIIStr + '.';
                       end;
                  end;
                  StringGrid1.Cells[17,RowIndex]:= ASCIIStr; // Menampilkan ASCII di kolom 17

                  inc(RowIndex);
                  Inc(Addr,16);
             end;
     finally
       FS.Free;
     end;
   end;

end;

end.

