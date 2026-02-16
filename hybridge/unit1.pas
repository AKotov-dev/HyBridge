unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, StrUtils, FileUtil,
  Buttons, Process, ClipBrd, ExtCtrls, IniPropStorage, ubarcodes, DefaultTranslator;

type

  { TMainForm }

  TMainForm = class(TForm)
    BarcodeQR1: TBarcodeQR;
    BypassBox: TComboBox;
    EditLocalSocks: TEdit;
    EditLocalHTTP: TEdit;
    Image1: TImage;
    IniPropStorage1: TIniPropStorage;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    MaskBox: TComboBox;
    CreateBtn: TBitBtn;
    CopyBtn: TBitBtn;
    EditTCPPort: TEdit;
    EditUDPPort: TEdit;
    EditServerIP: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Memo1: TMemo;
    SaveDialog1: TSaveDialog;
    Shape1: TShape;
    StartBtn: TSpeedButton;
    StopBtn: TSpeedButton;
    StaticText1: TStaticText;
    procedure CopyBtnClick(Sender: TObject);
    procedure CreateBtnClick(Sender: TObject);
    procedure EditServerIPKeyPress(Sender: TObject; var Key: char);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure StartBtnClick(Sender: TObject);
    procedure StartProcess(command: string);
    procedure StopBtnClick(Sender: TObject);
    procedure LoadConfiguration;
    procedure CreateClientConfig(AUTH_PASS, OBFS_PASS: string);
    procedure CreateSWProxy;

  private

  public

  end;

var
  MainForm: TMainForm;

implementation

uses
  portscan_trd, JSONHelper;

  {$R *.lfm}

  { TMainForm }

//Получение URI
function BuildHysteria2URI(Server: string; Port: string; Password: string;
  ObfsType: string; ObfsPassword: string; Insecure: boolean; Name: string): string;
var
  Params: string;
begin
  Params := '';

  if Insecure then
    Params := Params + 'insecure=1&';

  if ObfsType <> '' then
    Params := Params + 'obfs=' + ObfsType + '&';

  if ObfsPassword <> '' then
    Params := Params + 'obfs-password=' + ObfsPassword + '&';

  if Params.EndsWith('&') then
    Delete(Params, Length(Params), 1);

  Result := Format('hy2://%s@%s:%s/?%s#%s', [Password, Server, Port, Params, Name]);
end;

//Получение из YAML
function GetNestedYAMLValue(const FileName: string; const Path: array of string): string;
var
  SL: TStringList;
  I, Level: integer;
  Line, Trimmed, Key, Value: string;
  CurrentLevel: integer;
  ColonPos: integer;
begin
  Result := '';
  if not FileExists(FileName) then Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(FileName);
    CurrentLevel := -1;

    for I := 0 to SL.Count - 1 do
    begin
      Line := SL[I];
      Trimmed := Trim(Line);
      if Trimmed = '' then Continue;

      // уровень отступа (2 пробела = 1 уровень)
      Level := (Length(Line) - Length(TrimLeft(Line))) div 2;

      // найдём ключ и значение через двоеточие
      ColonPos := Pos(':', Trimmed);
      if ColonPos = 0 then Continue;

      Key := Trim(Copy(Trimmed, 1, ColonPos - 1));
      Value := Trim(Copy(Trimmed, ColonPos + 1, MaxInt));

      // если ключ совпадает с текущим уровнем пути
      if (Level <= High(Path)) and (Key = Path[Level]) then
        CurrentLevel := Level;

      // если мы дошли до последнего элемента пути — берём значение
      if CurrentLevel = High(Path) then
      begin
        Result := Value;

        // убираем ведущий двоеточие
        if (Result <> '') and (Result[1] = ':') then
          Delete(Result, 1, 1);

        Result := Trim(Result);
        Exit;
      end;
    end;
  finally
    SL.Free;
  end;
end;

//Общая процедура запуска команд (асинхронная)
procedure TMainForm.StartProcess(command: string);
var
  ExProcess: TProcess;
begin
  ExProcess := TProcess.Create(nil);
  try
    ExProcess.Executable := '/bin/bash';
    ExProcess.Parameters.Add('-c');
    ExProcess.Parameters.Add(command);
    ExProcess.Options := ExProcess.Options + [poWaitOnExit];
    ExProcess.Execute;
  finally
    ExProcess.Free;
  end;
end;

//Create ~/config/hybridge/swproxy.sh
procedure TMainForm.CreateSWProxy;
var
  S: ansistring;
  A: TStringList;
begin
  try
    A := TStringList.Create;
    A.Add('#!/bin/bash');
    A.Add('');
    A.Add('if [[ "$1" == "set" ]]; then');
    A.Add('  echo "set proxy..."');
    A.Add('');
    A.Add('  # GNOME / GTK-based');
    A.Add('  if [[ "$XDG_CURRENT_DESKTOP" =~ GNOME|Budgie|Cinnamon|MATE|XFCE|LXDE ]]; then');
    A.Add('    gsettings set org.gnome.system.proxy mode manual');
    A.Add('    gsettings set org.gnome.system.proxy.http  host "127.0.0.1"');
    A.Add('    gsettings set org.gnome.system.proxy.http  port ' + EditLocalHTTP.Text);
    A.Add('    gsettings set org.gnome.system.proxy.https host "127.0.0.1"');
    A.Add('    gsettings set org.gnome.system.proxy.https port ' + EditLocalHTTP.Text);
    A.Add('    gsettings set org.gnome.system.proxy.ftp   host "127.0.0.1"');
    A.Add('    gsettings set org.gnome.system.proxy.ftp   port ' + EditLocalHTTP.Text);
    A.Add('    gsettings set org.gnome.system.proxy.socks host "127.0.0.1"');
    A.Add('    gsettings set org.gnome.system.proxy.socks port ' + EditLocalSocks.Text);
    A.Add('    gsettings set org.gnome.system.proxy ignore-hosts "[' +
      '''' + 'localhost' + '''' + ', ' + '''' + '127.0.0.1' + '''' +
      ', ' + '''' + '::1' + '''' + ']"');
    A.Add('  fi');
    A.Add('');
    A.Add('  # KDE Plasma');
    A.Add('  if [[ "$XDG_CURRENT_DESKTOP" == KDE ]]; then');
    A.Add('    if command -v kwriteconfig5 >/dev/null; then');
    A.Add('      v=5');
    A.Add('    elif command -v kwriteconfig6 >/dev/null; then');
    A.Add('      v=6');
    A.Add('    else');
    A.Add('      echo "No kwriteconfig found"');
    A.Add('      exit 1');
    A.Add('  fi');
    A.Add('');
    A.Add('    kwriteconfig$v --file kioslaverc --group "Proxy Settings" --key ProxyType 1');
    A.Add('    kwriteconfig$v --file kioslaverc --group "Proxy Settings" --key httpProxy  "http://127.0.0.1:' + EditLocalHTTP.Text + '"');
    A.Add('    kwriteconfig$v --file kioslaverc --group "Proxy Settings" --key httpsProxy "http://127.0.0.1:' + EditLocalHTTP.Text + '"');
    A.Add('    kwriteconfig$v --file kioslaverc --group "Proxy Settings" --key ftpProxy   "http://127.0.0.1:' + EditLocalHTTP.Text + '"');
    A.Add('    kwriteconfig$v --file kioslaverc --group "Proxy Settings" --key socksProxy "socks5h://127.0.0.1:' + EditLocalSocks.Text + '"');
    A.Add('    kwriteconfig$v --file kioslaverc --group "Proxy Settings" --key NoProxy    "['
      + '''' + 'localhost' + '''' + ', ' + '''' + '127.0.0.1' + '''' +
      ', ' + '''' + '::1' + '''' + ']"');
    A.Add('  fi');
    A.Add('else');
    A.Add('  echo "unset proxy..."');
    A.Add('');
    A.Add('  # GNOME / GTK-based');
    A.Add('  if [[ "$XDG_CURRENT_DESKTOP" =~ GNOME|Budgie|Cinnamon|MATE|XFCE|LXDE ]]; then');
    A.Add('    gsettings set org.gnome.system.proxy mode none');
    A.Add('  fi');
    A.Add('');
    A.Add('  # KDE Plasma');
    A.Add('  if [[ "$XDG_CURRENT_DESKTOP" == KDE ]]; then');
    A.Add('    if command -v kwriteconfig5 >/dev/null; then');
    A.Add('      v=5');
    A.Add('    elif command -v kwriteconfig6 >/dev/null; then');
    A.Add('      v=6');
    A.Add('    else');
    A.Add('      echo "No kwriteconfig found"');
    A.Add('      exit 1');
    A.Add('    fi');
    A.Add('');
    A.Add('    kwriteconfig$v --file kioslaverc --group "Proxy Settings" --key ProxyType 0');
    A.Add('  fi');
    A.Add('fi');
    A.Add('');

    A.SaveToFile(GetUserDir + '.config/hybridge/swproxy.sh');
    RunCommand('/bin/bash', ['-c', 'chmod +x ~/.config/hybridge/swproxy.sh'], S);
  finally
    A.Free;
  end;
end;


//Создание конфига клиента
procedure TMainForm.CreateClientConfig(AUTH_PASS, OBFS_PASS: string);
var
  Conf: TStringList;
begin
  Conf := TStringList.Create;

  try
    Conf.Add('{');
    Conf.Add('"log": {');
    Conf.Add('  "level": "info"');
    Conf.Add('},');
    Conf.Add('');
    Conf.Add('"dns": {');
    Conf.Add('  "servers": [');
    Conf.Add('    {');
    Conf.Add('      "tag": "remote",');
    Conf.Add('      "type": "https",');
    Conf.Add('      "server": "1.1.1.1"');
    Conf.Add('    },');
    Conf.Add('    {');
    Conf.Add('      "tag": "local",');
    Conf.Add('      "type": "udp",');
    Conf.Add('      "server": "8.8.8.8"');
    Conf.Add('    }');
    Conf.Add('  ],');
    Conf.Add('  "rules": [');
    Conf.Add('    {');
    Conf.Add('      "domain_suffix": ["' + BypassBox.Text + '"],');
    Conf.Add('      "server": "local"');
    Conf.Add('    }');
    Conf.Add('  ]');
    Conf.Add('},');
    Conf.Add('');
    Conf.Add('"inbounds": [');
    Conf.Add('  {');
    Conf.Add('    "type": "socks",');
    Conf.Add('    "tag": "socks-in",');
    Conf.Add('    "listen": "127.0.0.1",');
    Conf.Add('    "listen_port": ' + EditLocalSocks.Text);
    Conf.Add('  },');
    Conf.Add('  {');
    Conf.Add('    "type": "http",');
    Conf.Add('    "tag": "http-in",');
    Conf.Add('    "listen": "127.0.0.1",');
    Conf.Add('    "listen_port": ' + EditLocalHTTP.Text);
    Conf.Add('  }');
    Conf.Add('],');
    Conf.Add('');
    Conf.Add('"outbounds": [');
    Conf.Add('  {');
    Conf.Add('    "type": "hysteria2",');
    Conf.Add('    "tag": "proxy",');
    Conf.Add('    "server": "' + EditServerIP.Text + '",');
    Conf.Add('    "server_port": ' + EditUDPPort.Text + ',');
    Conf.Add('    "password": "' + AUTH_PASS + '",');
    Conf.Add('');
    Conf.Add('    "tls": {');
    Conf.Add('      "enabled": true,');
    Conf.Add('      "insecure": true');
    Conf.Add('    },');
    Conf.Add('');
    Conf.Add('    "obfs": {');
    Conf.Add('      "type": "salamander",');
    Conf.Add('      "password": "' + OBFS_PASS + '"');
    Conf.Add('    }');
    Conf.Add('  },');
    Conf.Add('  {');
    Conf.Add('    "type": "direct",');
    Conf.Add('    "tag": "direct"');
    Conf.Add('  }');
    Conf.Add('],');
    Conf.Add('');
    Conf.Add('"route": {');
    Conf.Add('  "default_domain_resolver": "remote",');
    Conf.Add('');
    Conf.Add('  "rules": [');
    Conf.Add('    {');
    Conf.Add('      "domain_suffix": ["' + BypassBox.Text + '"],');
    Conf.Add('      "outbound": "direct"');
    Conf.Add('    }');
    Conf.Add('  ],');
    Conf.Add('');
    Conf.Add('  "final": "proxy"');
    Conf.Add('}');
    Conf.Add('}');

    // Сохраняем конфиг клиента
    Conf.SaveToFile(GetUserDir + '.config/hybridge/config/client.json');

    //Получаем URI
    Memo1.Text := BuildHysteria2URI(EditServerIP.Text, EditUDPPort.Text,
      AUTH_PASS, 'salamander', OBFS_PASS, True, 'HyBridge');

    //Показываем QR-код (LazBarCodes)
    BarCodeQR1.Text := Memo1.Text;
  finally
    Conf.Free;
  end;
end;

//Загрузка конфигурации клиента и байпас
procedure TMainForm.LoadConfiguration;
var
  AUTH_PASS, OBFS_PASS, config: string;
begin
  // Если конфигурация клиента существует - читаем настройки в поля
  config := GetUserDir + '.config/hybridge/config/client.json';

  if FileExists(config) then
  begin
    // server
    EditServerIP.Text := GetJSONValue(config, 'outbounds[0].server');

    // server_port UDP
    EditUDPPort.Text := GetJSONValue(config, 'outbounds[0].server_port');

    // Bypass
    BypassBox.Text := GetJSONValue(config, 'dns.rules[0].domain_suffix[0]');

    // local_port SOCKS5
    EditLocalSocks.Text := GetJSONValue(config, 'inbounds[0].listen_port');

    // local_port HTTP
    EditLocalHTTP.Text := GetJSONValue(config, 'inbounds[1].listen_port');


    AUTH_PASS := GetJSONValue(config, 'outbounds[0].password');

    OBFS_PASS := GetJSONValue(config, 'outbounds[0].obfs.password');

    //--server--
    config := GetUserDir + '.config/hybridge/config/server/etc/hysteria/config.yaml';
    //server_port TCP
    EditTCPPort.Text := GetNestedYAMLValue(config, ['tcp', 'listen']);

    //Masquerade (Mask)
    MaskBox.Text := GetNestedYAMLValue(config, ['masquerade', 'proxy', 'url']);

    //Получаем URI
    Memo1.Text := BuildHysteria2URI(EditServerIP.Text, EditUDPPort.Text,
      AUTH_PASS, 'salamander', OBFS_PASS, True, 'HyBridge');

    //Показываем QR-код (LazBarCodes)
    BarCodeQR1.Text := Memo1.Text;


    StartBtn.Enabled := True;
  end
  else
    //Иначе блокируем запуск и ждём создания конфигурации клиента
    StartBtn.Enabled := False;
end;

//Stop
procedure TMainForm.StopBtnClick(Sender: TObject);
begin
  StartProcess('~/.config/hybridge/swproxy.sh reset');
  StartProcess('systemctl --user stop hybridge.service; systemctl --user disable hybridge.service');
end;

//Создать конфиги, сертификаты и QR-код
procedure TMainForm.CreateBtnClick(Sender: TObject);
var
  Conf: TStringList;
  AUTH_PASS, OBFS_PASS: string;
begin
  Application.ProcessMessages;

  if (Trim(EditServerIP.Text) = '') or (Trim(EditUDPPort.Text) = '') or
    (Trim(EditTCPPort.Text) = '') or (Trim(MaskBox.Text) = '') or
    (Trim(ByPassBox.Text) = '') or (Trim(EditLocalSocks.Text) = '') or
    (Trim(EditLocalHTTP.Text) = '') then Exit;

  if FileExists(GetUserDir + '.config/hybridge/config/server/etc/hysteria/cert.pem') then
    if MessageDlg(
      'Конфигурации клиента и сервера уже созданы. Пересоздать?',
      mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;

  //Очищаем рабочий каталог рекурсивно
  StartProcess('[ -d ~/.config/hybridge/config ] && rm -rf ~/.config/hybridge/config');

  //Нарезаем директории для будущих конфигов
  ForceDirectories(GetUserDir + '.config/hybridge/config/server/etc/hysteria');

  // Генерация случайных паролей
  if RunCommand('bash', ['-c', 'head /dev/urandom | tr -dc A-Za-z0-9 | head -c16'],
    AUTH_PASS) then
    AUTH_PASS := Trim(AUTH_PASS);

  if RunCommand('bash', ['-c', 'head /dev/urandom | tr -dc A-Za-z0-9 | head -c16'],
    OBFS_PASS) then
    OBFS_PASS := Trim(OBFS_PASS);

  //Создание конфигов и комбинированного сертификата
  Conf := TStringList.Create;
  try
    // Генерация self-signed сертификата 100 лет
    StartProcess('openssl req -x509 -nodes -days 36500 -newkey rsa:2048 ' +
      '-keyout ~/.config/hybridge/config/server/etc/hysteria/cert.pem -out ' +
      '~/.config/hybridge/config/server/etc/hysteria/cert.pem -subj "/CN=localhost"');

    //Конфиг сервера
    Conf.Add('listen: :' + EditUDPPort.Text);
    Conf.Add('tcp:');
    Conf.Add('  listen: :' + EditTCPPort.Text);
    Conf.Add('  fallback: true');
    Conf.Add('');
    Conf.Add('tls:');
    Conf.Add('  cert: /etc/hysteria/cert.pem');
    Conf.Add('  key: /etc/hysteria/cert.pem');
    Conf.Add('');
    Conf.Add('auth:');
    Conf.Add('  type: password');
    Conf.Add('  password: ' + AUTH_PASS);
    Conf.Add('');
    Conf.Add('obfs:');
    Conf.Add('  type: salamander');
    Conf.Add('  salamander:');
    Conf.Add('    password: ' + OBFS_PASS);
    Conf.Add('');
    Conf.Add('masquerade:');
    Conf.Add('  type: proxy');
    Conf.Add('  proxy:');
    Conf.Add('    url: ' + MaskBox.Text);
    Conf.Add('    rewriteHost: true');

    //Сохраняем конфиг сервера
    Conf.SaveToFile(GetUserDir +
      '.config/hybridge/config/server/etc/hysteria/config.yaml');

    //Создаём конфиг Клиента
    CreateClientConfig(AUTH_PASS, OBFS_PASS);

    //Выгружаем архив конфигураций и сертификаты
    if not FileExists(GetUserDir + '.config/ss-cloak-client/server-conf.tar.gz') then
      Exit;

    if (SaveDialog1.Execute) then
    begin
      if not AnsiEndsText('.tar.gz', SaveDialog1.FileName) then
      begin
        if SameText(ExtractFileExt(SaveDialog1.FileName), '.gz') then
          SaveDialog1.FileName := ChangeFileExt(SaveDialog1.FileName, '.tar.gz')
        else
          SaveDialog1.FileName := SaveDialog1.FileName + '.tar.gz';
      end;

      //Создаём архив cd ~/.config/hybridge && tar czf config.tar.gz ./config и выгружаем
      StartProcess('cd ~/.config/hybridge && tar czf config.tar.gz ./config');

      CopyFile(GetUserDir + '.config/hybridge/config.tar.gz',
        SaveDialog1.FileName, [cffOverwriteFile]);
    end;


    if FileExists(GetUserDir + '.config/hybridge/config/client.json') then
      StartBtn.Enabled := True;

  finally
    Conf.Free;
  end;
end;


//Ввод цифр и точек
procedure TMainForm.EditServerIPKeyPress(Sender: TObject; var Key: char);
begin
  // Проверяем нажатую клавишу
  case Key of
    // Разрешаем цифры
    '0'..'9': key := key;
    // Разрешаем десятичный разделитель (только точку)
    '.', ',': key := '.';
    // Разрешаем BackSpace
    #8: key := key;
      // Все прочие клавиши «гасим»
    else
      key := #0;
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  bmp: TBitmap;
begin
  MainForm.Caption := Application.Title;

  // Устраняем баг иконки приложения
  bmp := TBitmap.Create;
  try
    bmp.PixelFormat := pf32bit;
    bmp.Assign(Image1.Picture.Graphic);
    Application.Icon.Assign(bmp);
  finally
    bmp.Free;
  end;

  //Рабочий каталог
  if not DirectoryExists(GetUserDir + '.config/hybridge') then
    ForceDirectories(GetUserDir + '.config/hybridge');

  IniPropStorage1.IniFileName := GetUserDir + '.config/hybridge/hybridge.conf';
end;

//Копирование URI в буфер
procedure TMainForm.CopyBtnClick(Sender: TObject);
begin
  ClipBoard.AsText := Memo1.Text;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  CopyBtn.Height := CreateBtn.Height;
  StartBtn.Height := CreateBtn.Height;
  StopBtn.Height := CreateBtn.Height;

  //Наполняем поля из конфигов клиента и сервера
  LoadConfiguration;

  //Запускаем поток сканирования порта
  PortScan.Create(False);
end;

//Start
procedure TMainForm.StartBtnClick(Sender: TObject);
var
  config, AUTH_PASS, OBFS_PASS: string;
begin
  if (Trim(EditServerIP.Text) = '') or (Trim(EditUDPPort.Text) = '') or
    (Trim(EditTCPPort.Text) = '') or (Trim(MaskBox.Text) = '') or
    (Trim(ByPassBox.Text) = '') or (Trim(EditLocalSocks.Text) = '') or
    (Trim(EditLocalHTTP.Text) = '') then Exit;

  config := GetUserDir + '.config/hybridge/config/client.json';

  if not FileExists(config) then Exit;

  //Забираем уже созданные пароли
  AUTH_PASS := GetJSONValue(config, 'outbounds[0].password');
  OBFS_PASS := GetJSONValue(config, 'outbounds[0].obfs.password');

  //Пересоздаём конфиг клиента
  CreateClientConfig(AUTH_PASS, OBFS_PASS);

  //Пересоздаём ~/.config/hybridge/swproxy.sh
  CreateSWProxy;
  StartProcess('~/.config/hybridge/swproxy.sh set');

  StartProcess('systemctl --user restart hybridge.service && systemctl --user enable hybridge.service');
end;

end.
