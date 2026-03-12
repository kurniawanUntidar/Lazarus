unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Menus, Grids, ExtCtrls,
  StdCtrls, ComCtrls, Buttons, LazSerial, fpJson, jsonparser, Types;

type

  { TForm1 }

  TForm1 = class(TForm)
    btnConnect: TSpeedButton;
    cbChip: TComboBox;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    LazSerial1: TLazSerial;
    MainMenu1: TMainMenu;
    Memo1: TMemo;
    MenuItem1: TMenuItem;
    Edit: TMenuItem;
    menuRead: TMenuItem;
    ProgressBar1: TProgressBar;
    ReadId: TMenuItem;
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
    SpeedButton4: TSpeedButton;
    SpeedButton5: TSpeedButton;
    StatusBar1: TStatusBar;
    StringGrid1: TStringGrid;
    ToolBar1: TToolBar;
    procedure btnConnectClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure ExitMenuClick(Sender: TObject);
    procedure LazSerial1RxData(Sender: TObject);
    procedure menuReadClick(Sender: TObject);
    procedure ReadIdClick(Sender: TObject);
    procedure OpenMenuClick(Sender: TObject);
    procedure SaveAsMenuClick(Sender: TObject);
    procedure SaveMenuClick(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure SpeedButton4Click(Sender: TObject);
    procedure SpeedButton5Click(Sender: TObject);
    procedure StringGrid1DrawCell(Sender: TObject; aCol, aRow: integer;
      aRect: TRect; aState: TGridDrawState);
    procedure ToolBar1Click(Sender: TObject);
    procedure RequestNextBlock;
    procedure loadItemCombobox;
  private

  public

  end;

var
  Form1: TForm1;
  RxData: string;
  header:Array [0..2] of byte;
  Buffer: array of byte;
  LenBuffer: integer;
  FileData: TMemoryStream;   // Tempat menyimpan hasil dump BIOS
  CurrentAddr: Cardinal;     // Alamat yang sedang dibaca
  MaxAddr: Cardinal;         // Total ukuran chip (misal 2MB = 2097152)
  IsReading: Boolean;        // Flag untuk menandakan proses sedang berjalan

implementation

{$R *.lfm}

{ TForm1 }
procedure TForm1.loadItemCombobox;
var
  LJsonData: string;
  LJsonValue, LItem: TJSONValue;
  LJsonArray: TJSONArray;
  I: Integer;
begin
end;

procedure TForm1.RequestNextBlock;
var
  Packet: array[0..6] of Byte;
begin
  if CurrentAddr < MaxAddr then
  begin
    Packet[0] := $AA;
    Packet[1] := $03; // CMD_READ_BLOCK
    Packet[2] := $03; // Panjang parameter alamat (3 byte)
    //Packet[3] := (CurrentAddr shr 16) and $FF;
    //Packet[4] := (CurrentAddr shr 8) and $FF;
    //Packet[5] := CurrentAddr and $FF;
    Packet[3] := $00;
    Packet[4] := $00;
    Packet[5] := $0B;
    Packet[6] := Packet[0] xor Packet[1] xor Packet[2] xor Packet[3] xor Packet[4] xor Packet[5];

    LazSerial1.WriteBuffer(Packet[0], 7);
  end
  else
  begin
    IsReading := False;
    ShowMessage('Pembacaan BIOS Selesai!');
  end;
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  LazSerial1.Close;
end;

procedure TForm1.btnConnectClick(Sender: TObject);
var
  Packet: array[0..3] of byte;
begin
  Packet[0] := $AA; // Header
  Packet[1] := $06; // CMD_CHECK_CONN
  Packet[2] := $00; // Length 0
  Packet[3] := $AA xor $06 xor $00; // Checksum

  LazSerial1.Open;
  //LazSerial1.WriteData('a');

  LazSerial1.WriteBuffer(Packet[0], 4);

end;

procedure TForm1.FormCreate(Sender: TObject);
var
  vendorList: TStringList;
  s: string;
begin
  StatusBar1.Panels.Items[0].Width := Form1.Width div 4;
  StatusBar1.Panels.Items[1].Width := Form1.Width div 2;
  StatusBar1.Panels.Items[2].Width := Form1.Width div 4;
  Memo1.Lines.Clear;
  Memo1.Lines.AddText('Open Aplikasi');
end;

procedure TForm1.ExitMenuClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TForm1.LazSerial1RxData(Sender: TObject);
var
  S: String;
  CalcChecksum: Byte;
  i, MsgLen, CmdID: Integer;
  PNG: TPortableNetworkGraphic;
begin
  S := LazSerial1.ReadData;
  if Length(S) < 4 then Exit; // Abaikan jika paket terlalu pendek

  if Byte(S[1]) = $AA then
  begin
    CmdID := Byte(S[2]);
    MsgLen := Byte(S[3]);

    // --- LOGIKA UNTUK PEMBACAAN BLOK DATA (CMD 0x03) ---
    if CmdID = $03 then
    begin
      // Paket blok: Header(1) + Cmd(1) + Len(1) + Data(256) + Checksum(1) = 260 byte
      // Kita asumsikan Len=0 dari Arduino berarti 256 byte
      if Length(S) >= 260 then
      begin
        CalcChecksum := 0;
        for i := 1 to 259 do CalcChecksum := CalcChecksum xor Byte(S[i]);

        if CalcChecksum = Byte(S[260]) then
        begin
          // Simpan data ke MemoryStream
          FileData.Position := CurrentAddr;
          // Salin 256 byte data (mulai dari karakter ke-4)
          FileData.Write(S[4], 256);

          // Update Progress
          CurrentAddr := CurrentAddr + 256;
          ProgressBar1.Position := CurrentAddr;

          // Update Grid setiap 1KB agar tidak lambat
          if CurrentAddr mod 1024 = 0 then
          begin
            StringGrid1.Invalidate;
            Application.ProcessMessages;
          end;

          // Minta blok berikutnya
          RequestNextBlock;
        end
        else
          Memo1.Lines.Add('Error: Checksum Data di ' + IntToHex(CurrentAddr, 6));
      end;
    end

    // --- LOGIKA UNTUK PESAN TEKS BIASA (CMD LAINNYA) ---
    else
    begin
      // Verifikasi Checksum untuk pesan teks
      CalcChecksum := 0;
      for i := 1 to (3 + MsgLen) do CalcChecksum := CalcChecksum xor Byte(S[i]);

      if CalcChecksum = Byte(S[4 + MsgLen]) then
      begin
        // Jika CMD_CHECK_CONN (0x06)
        if CmdID = $06 then
        begin
          PNG := TPortableNetworkGraphic.Create;
          try
            PNG.LoadFromFile(ExtractFilePath(Application.ExeName) + 'Image/Connection_05_24.png');
            btnConnect.Glyph.Assign(PNG);
          finally
            PNG.Free;
          end;
        end;

        Memo1.Lines.Add('Valid [' + IntToHex(CmdID, 2) + ']: ' + Copy(S, 4, MsgLen));
      end;
    end;
  end;
end;

procedure TForm1.menuReadClick(Sender: TObject);
begin
  if not LazSerial1.Active then begin
    ShowMessage('Hubungkan Serial Port Terlebih Dahulu!');
    Exit;
  end;

  // Inisialisasi
  if Assigned(FileData) then FileData.Clear else FileData := TMemoryStream.Create;

  MaxAddr := 2 * 1024 * 1024; // 2MB untuk EF4018
  FileData.SetSize(MaxAddr);
  CurrentAddr := 0;
  IsReading := True;

  ProgressBar1.Max := MaxAddr;
  ProgressBar1.Position := 0;

  // Mulai permintaan pertama
  RequestNextBlock;
end;

procedure TForm1.ReadIdClick(Sender: TObject);
var
Packet: array[0..3] of Byte;
begin
  Packet[0] := $AA;
  Packet[1] := $01; // CMD_GET_ID
  Packet[2] := $00;
  Packet[3] := $AA xor $01 xor $00;

  LazSerial1.WriteBuffer(Packet[0], 4);
end;


procedure TForm1.OpenMenuClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
  begin
    if Assigned(FileData) then FileData.Clear
    else FileData := TMemoryStream.Create;

    FileData.LoadFromFile(OpenDialog1.FileName);

    // Tentukan jumlah baris secara instan
    StringGrid1.RowCount := (FileData.Size div 16) + 1;
    StringGrid1.Invalidate; // Perintahkan grid untuk menggambar ulang

    StatusBar1.Panels.Items[1].Text := StatusBar1.Panels.Items[1].Text +
      OpenDialog1.FileName;
    Memo1.Lines.AddText('File open:'+OpenDialog1.FileName);
  end
  else Memo1.Lines.AddText('File open canceled');

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

procedure TForm1.SpeedButton4Click(Sender: TObject);
var
  Packet: array[0..3] of byte;
begin
  Packet[0] := $AA; // Header
  Packet[1] := $07; // CMD_SCAN
  Packet[2] := $00; // Length 0
  Packet[3] := $AA xor $07 xor $00; // Checksum

  LazSerial1.WriteBuffer(Packet[0], 4);

end;

procedure TForm1.SpeedButton5Click(Sender: TObject);
begin

end;

procedure TForm1.StringGrid1DrawCell(Sender: TObject; aCol, aRow: integer;
  aRect: TRect; aState: TGridDrawState);
var
  Offset: int64;
  B: byte;
  S: string;
  BytesToRead: integer; // <--- Tipe data Integer
  i: integer;
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
    end
    else
      S := '';
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

procedure TForm1.ToolBar1Click(Sender: TObject);
begin

end;

end.
