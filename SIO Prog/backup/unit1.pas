unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Menus, Grids, ExtCtrls,
  StdCtrls, ComCtrls, Buttons, Types;

type

  { TForm1 }

  TForm1 = class(TForm)
    MainMenu1: TMainMenu;
    MenuItem1: TMenuItem;
    Edit: TMenuItem;
    Panel1: TPanel;
    ReplaceMenu: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    ExitMenu: TMenuItem;
    FindMenu: TMenuItem;
    MenuItem8: TMenuItem;
    PasteMenu: TMenuItem;
    OpenMenu: TMenuItem;
    SaveMenu: TMenuItem;
    OpenDialog1: TOpenDialog;
    SaveAsMenu: TMenuItem;
    SpeedButton1: TSpeedButton;
    SpeedButton2: TSpeedButton;
    SpeedButton3: TSpeedButton;
    StatusBar1: TStatusBar;
    StringGrid1: TStringGrid;
    ToolBar1: TToolBar;
    procedure ControlBar1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ExitMenuClick(Sender: TObject);
    procedure OpenMenuClick(Sender: TObject);
    procedure SaveAsMenuClick(Sender: TObject);
    procedure SaveMenuClick(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
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
  StatusBar1.Panels.Items[0].Width:=Form1.Width div 4;
  StatusBar1.Panels.Items[1].Width:=Form1.Width div 2;
  StatusBar1.Panels.Items[2].Width:=Form1.Width div 4;
end;

procedure TForm1.ExitMenuClick(Sender: TObject);
begin
   Application.Terminate;
end;


procedure TForm1.OpenMenuClick(Sender: TObject);
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

procedure TForm1.SaveAsMenuClick(Sender: TObject);
begin
  //SaveAsMenuClick
end;

procedure TForm1.SaveMenuClick(Sender: TObject);
begin
   //saveKlik

end;

procedure TForm1.SpeedButton1Click(Sender: TObject);
begin

end;

procedure TForm1.StringGrid1DrawCell(Sender: TObject; aCol, aRow: Integer;
  aRect: TRect; aState: TGridDrawState);
var
  Offset: Int64;
  B: Byte;
  S: String;
  BytesToRead: Integer; // <--- Tipe data Integer
  i: Integer;
  TS: TTextStyle;
begin

   // Siapkan gaya teks agar rapi (Alignment)
  TS := StringGrid1.Canvas.TextStyle;
  TS.Alignment := taLeftJustify;
  TS.Layout := tlCenter;

  if (ARow = 0) or (not Assigned(FileData)) then Exit; // Abaikan Header

  Offset := (ARow - 1) * 16; // Hitung posisi data berdasarkan baris

  // Kolom 0: Alamat
  if ACol = 0 then
    S := IntToHex(Offset, 8) + ' :'

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

  StringGrid1.Canvas.TextRect(aRect, aRect.Left + 2, aRect.Top + 2, S, TS);
end;

end.

