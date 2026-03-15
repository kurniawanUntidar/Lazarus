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
    cbDevice: TComboBox;
    cbManufacture: TComboBox;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox3: TGroupBox;
    GroupBox4: TGroupBox;
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
    procedure cbManufactureChange(Sender: TObject);
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
    procedure StringGrid1DrawCell(Sender: TObject; aCol, aRow: integer;
      aRect: TRect; aState: TGridDrawState);
    procedure RequestNextBlock;
    procedure LoadChipDatabase;
    procedure IdentifyChip(ReceivedID: String);
    procedure StringGrid1GetEditText(Sender: TObject; ACol, ARow: Integer;
      var Value: string);
  private
         RxBuffer: String; // Untuk menampung potongan data yang masuk
         procedure checkConnection(msg:String);
         procedure readBlock(dataRx:string);
  public

  end;

var
  Form1: TForm1;
  RxData: string;
  header:Array [0..2] of byte;
  Buffer: array of byte;
  LenBuffer: integer;
  JSONData: TJSONData; // Variabel global untuk menampung database chip
  FileData: TMemoryStream;   // Tempat menyimpan hasil dump BIOS
  CurrentAddr: Cardinal;     // Alamat yang sedang dibaca
  MaxAddr: Cardinal;         // Total ukuran chip (misal 2MB = 2097152)
  IsReading: Boolean;        // Flag untuk menandakan proses sedang berjalan

implementation

{$R *.lfm}

{ TForm1 }
procedure TForm1.readBlock(dataRx:String);
var
  i : integer;
begin
  Memo1.Lines.Add('Data Received') ;
 for i:=1 to Length(dataRx) do Memo1.Lines.Add(intToHex(byte(dataRx[i])));
end;

procedure TForm1.checkConnection(msg:String);
var
  PNG: TPortableNetworkGraphic;
begin
     PNG := TPortableNetworkGraphic.Create;
          try
            PNG.LoadFromFile(ExtractFilePath(Application.ExeName) + 'Image/Connection_05_24.png');
            btnConnect.Glyph.Assign(PNG);
          finally
            PNG.Free;
          end;
     Memo1.Lines.Add('Valid : ' + msg);
end;

procedure TForm1.IdentifyChip(ReceivedID: String);
var
  i, j: Integer;
  Devices: TJSONArray;
  TargetID: String;
begin
  for i := 0 to JSONData.Count - 1 do
  begin
    Devices := TJSONArray(JSONData.Items[i].FindPath('devices'));
    for j := 0 to Devices.Count - 1 do
    begin
      TargetID := Devices.Items[j].FindPath('id').AsString;
      if TargetID = ReceivedID then
      begin
        cbManufacture.ItemIndex := i;
        cbManufactureChange(Self); // Trigger untuk isi cbDevice
        cbDevice.ItemIndex := j;

        // Update ukuran maksimal pembacaan secara otomatis
        MaxAddr := Devices.Items[j].FindPath('size_kb').AsInteger * 1024;
        Memo1.Lines.Add('Chip Terdeteksi: '+ TargetID);
        Memo1.Lines.Add('Manufacture: ' + cbManufacture.Text);
        Memo1.Lines.Add('Device: ' + cbDevice.Text);
        Memo1.Lines.Add('Capacity: ' + Devices.Items[j].FindPath('size_kb').AsString+' Kb');
        Exit;
      end;
    end;
  end;
  Memo1.Lines.Add('ID tidak dikenal dalam database.');
end;

procedure TForm1.StringGrid1GetEditText(Sender: TObject; ACol, ARow: Integer; var Value: string);
var
  ByteVal: Byte;
  Posisi: Int64;
begin
  if (ARow = 0) or (not Assigned(FileData)) then Exit;

  // Hitung posisi byte di dalam FileData
  Posisi := (ARow - 1) * 16;

  if ACol = 0 then // Kolom Alamat
    Value := IntToHex(Posisi, 8)
  else if (ACol >= 1) and (ACol <= 16) then // Kolom Hex
  begin
    Posisi := Posisi + (ACol - 1);
    if Posisi < FileData.Size then
    begin
      FileData.Position := Posisi;
      FileData.Read(ByteVal, 1);
      Value := IntToHex(ByteVal, 2);
    end;
  end;
end;

procedure TForm1.LoadChipDatabase;
var
  FileStream: TFileStream;
  Parser: TJSONParser;
  i: Integer;
begin
  if not FileExists('chips.json') then
  begin
    Showmessage('File not Found');
    Exit;
  end;

  FileStream := TFileStream.Create('chips.json', fmOpenRead);
  Parser := TJSONParser.Create(FileStream);
  try
    JSONData := Parser.Parse;
    cbManufacture.Items.Clear;
    for i := 0 to JSONData.Count - 1 do
    begin
      cbManufacture.Items.Add(JSONData.Items[i].FindPath('manufacture').AsString);
    end;
  finally
    Parser.Free;
    FileStream.Free;
  end;
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
    Packet[3] := (CurrentAddr shr 16) and $FF;
    Packet[4] := (CurrentAddr shr 8) and $FF;
    Packet[5] := CurrentAddr and $FF;
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
  LazSerial1.WriteBuffer(Packet[0], 4);

end;

procedure TForm1.cbManufactureChange(Sender: TObject);
var
  i, j: Integer;
  Devices: TJSONArray;
begin
  cbDevice.Items.Clear;
  i := cbManufacture.ItemIndex;

  // Ambil array 'devices' berdasarkan index manufacture yang dipilih
  Devices := TJSONArray(JSONData.Items[i].FindPath('devices'));

  for j := 0 to Devices.Count - 1 do
  begin
    cbDevice.Items.Add(Devices.Items[j].FindPath('name').AsString);
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  StatusBar1.Panels.Items[0].Width := Form1.Width div 4;
  StatusBar1.Panels.Items[1].Width := Form1.Width div 2;
  StatusBar1.Panels.Items[2].Width := Form1.Width div 4;
  Memo1.Lines.Clear;
  Memo1.Lines.AddText('Open Aplikasi');
  LoadChipDatabase();
  isReading := false;
  RxData :='';
end;

procedure TForm1.ExitMenuClick(Sender: TObject);
begin
  Application.Terminate;
end;
// RX DATA
//=============================================================================//
procedure TForm1.LazSerial1RxData(Sender: TObject);
var
  S: String;
  i, HeaderPos: Integer;
  CalcChecksum: Byte;
  DataByte: Byte;
begin
  // 1. Ambil potongan data (misal 32 byte) dan gabungkan ke penampung utama
  S := LazSerial1.ReadData;
  RxBuffer := RxBuffer + S;

  // Debug untuk memantau akumulasi
  // MemoLog.Lines.Add('Buffer sekarang: ' + IntToStr(Length(RxBuffer)));

  // 2. Cari Header $AA agar kita tidak salah posisi jika ada data sampah
  HeaderPos := Pos(#$AA, RxBuffer);
  if HeaderPos > 1 then
    Delete(RxBuffer, 1, HeaderPos - 1);

  // 3. Hanya proses jika di dalam ember sudah terkumpul MINIMAL 260 byte
  while (Length(RxBuffer) >= 260) do
  begin
    // Pastikan ini paket yang benar (Header AA, Cmd 03)
    if (Byte(RxBuffer[1]) = $AA) and (Byte(RxBuffer[2]) = $03) then
    begin
      // 4. Hitung Checksum paket utuh (1 s/d 259)
      CalcChecksum := 0;
      for i := 1 to 259 do
        CalcChecksum := CalcChecksum xor Byte(RxBuffer[i]);

      if CalcChecksum = Byte(RxBuffer[260]) then
      begin
        // DATA VALID! Tulis ke MemoryStream
        FileData.Position := CurrentAddr;
        for i := 0 to 255 do
        begin
          DataByte := Byte(RxBuffer[4 + i]);
          FileData.Write(DataByte, 1);
        end;

        // 5. Buang paket yang sudah diproses (260 byte) dari ember
        Delete(RxBuffer, 1, 260);

        // 6. Update progres & Minta blok berikutnya
        CurrentAddr := CurrentAddr + 256;
        ProgressBar1.Position := CurrentAddr;

        // Refresh Tampilan Grid (Virtual Mode)
        StringGrid1.Invalidate;

        // Kirim permintaan blok berikutnya ke Arduino
        RequestNextBlock;
      end
      else
      begin
        // Jika checksum salah, mungkin AA ini bukan header asli, buang 1 byte cari AA lagi
        Delete(RxBuffer, 1, 1);
      end;
    end
    else
    begin
      // Jika bukan paket kita, buang 1 byte
      Delete(RxBuffer, 1, 1);
    end;

    // Cari lagi Header di sisa buffer jika ada
    HeaderPos := Pos(#$AA, RxBuffer);
    if (HeaderPos > 1) then Delete(RxBuffer, 1, HeaderPos - 1);
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

  MaxAddr := 16 * 1024 * 1024; // 2MB untuk EF4018
  RxBuffer := ''; // RESET BUFFER DI SINI
  FileData.SetSize(MaxAddr);
  CurrentAddr := 0;
  IsReading := True;

  StringGrid1.RowCount := (MaxAddr div 16) + 1;

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

end.
