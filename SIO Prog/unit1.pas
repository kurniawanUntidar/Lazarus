unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Menus, Grids, ExtCtrls,
  StdCtrls, ComCtrls, Types;

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
    procedure FormCreate(Sender: TObject);
    procedure MenuItem5Click(Sender: TObject);
    procedure OpenClick(Sender: TObject);
    procedure StringGrid1DrawCell(Sender: TObject; aCol, aRow: Integer;
      aRect: TRect; aState: TGridDrawState);
  private

  public

  end;

var
  Form1: TForm1;
  FileData: TMemoryStream;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.ControlBar1Click(Sender: TObject);
begin

end;

procedure TForm1.FormCreate(Sender: TObject);
begin

end;

procedure TForm1.MenuItem5Click(Sender: TObject);
begin
   Application.Terminate;
end;


procedure TForm1.OpenClick(Sender: TObject);
begin
   if OpenDialog1.Execute then
   begin
     if Assigned(FileData) then FileData.Clear else FileData := TMemoryStream.Create;
    FileData.LoadFromFile(OpenDialog1.FileName);

    // Tentukan jumlah baris secara instan
    StringGrid1.RowCount := (FileData.Size div 16) + 1;
    StringGrid1.Invalidate; // Perintahkan grid untuk menggambar ulang

    StatusBar1.Panels.Items[1].Text:=StatusBar1.Panels.Items[1].Text + OpenDialog1.FileName;
   end;

end;

procedure TForm1.StringGrid1DrawCell(Sender: TObject; aCol, aRow: Integer;
  aRect: TRect; aState: TGridDrawState);
var
  Offset: Int64;
  B: Byte;
  S: String;
  BytesToRead: Integer; // <--- Tipe data Integer
  i: Integer;
begin
  if (ARow = 0) or (not Assigned(FileData)) then Exit; // Abaikan Header

  Offset := (ARow - 1) * 16; // Hitung posisi data berdasarkan baris

  // Kolom 0: Alamat
  if ACol = 0 then
    S := IntToHex(Offset, 8) + ':'

  // Kolom 1-16: Data Hex
  else if (ACol >= 1) and (ACol <= 16) then
  begin
    if (Offset + ACol - 1) < FileData.Size then
    begin
      FileData.Position := Offset + ACol - 1;
      FileData.Read(B, 1);
      S := IntToHex(B, 2);
    end else S := '';
  end

  // Kolom 17: ASCII
  else if ACol = 17 then
  begin
    S := '';
  // Pastikan posisi tidak melebihi ukuran file
  if Offset < FileData.Size then
  begin
    // Tentukan berapa byte yang tersisa (maksimal 16)
    BytesToRead := FileData.Size - Offset;
    if BytesToRead > 16 then BytesToRead := 16;

    // Set kapasitas string untuk performa (menghindari realokasi memori)
    SetLength(S, BytesToRead);

    // Pindahkan posisi stream ke offset baris ini
    FileData.Position := Offset;

    // Baca blok data sekaligus ke dalam string (casting pointer)
    FileData.Read(S[1], BytesToRead);

    // Filter karakter: Ubah karakter non-printable menjadi titik (.)
    for i := 1 to Length(S) do
    begin
      if not (S[i] in [#32..#126]) then
        S[i] := '.';
    end;
  end;

  end;

  StringGrid1.Canvas.TextRect(aRect, aRect.Left + 2, aRect.Top + 2, S);
end;

end.

