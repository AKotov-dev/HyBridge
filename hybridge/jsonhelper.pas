unit JSONHelper;

interface

uses
  Classes, SysUtils, fpjson, jsonparser;

function GetJSONValue(const FileName, Path: string): string;
procedure SetJSONValue(const FileName, Path, NewValue: string);

implementation

function LoadJSON(const FileName: string): TJSONObject;
var
  S: TStringList;
begin
  S := TStringList.Create;
  try
    S.LoadFromFile(FileName);
    Result := GetJSON(S.Text) as TJSONObject;
  finally
    S.Free;
  end;
end;

procedure SaveJSON(JSON: TJSONObject; const FileName: string);
var
  S: TStringList;
begin
  S := TStringList.Create;
  try
    S.Text := JSON.FormatJSON;
    S.SaveToFile(FileName);
  finally
    S.Free;
  end;
end;

function ExtractIndex(var Token: string; out Index: integer): boolean;
var
  p1, p2: integer;
begin
  Result := False;
  Index := -1;

  p1 := Pos('[', Token);
  p2 := Pos(']', Token);

  if (p1 > 0) and (p2 > p1) then
  begin
    Index := StrToIntDef(Copy(Token, p1 + 1, p2 - p1 - 1), -1);
    Token := Copy(Token, 1, p1 - 1);
    Result := True;
  end;
end;

function Navigate(JSON: TJSONData; const Path: string;
  CreateIfMissing: boolean): TJSONData;
var
  Parts: TStringArray;
  Part: string;
  i, Idx: integer;
  Obj: TJSONObject;
  Arr: TJSONArray;
  HasIndex: boolean;
begin
  Result := JSON;
  Parts := Path.Split('.');

  for i := 0 to High(Parts) do
  begin
    Part := Parts[i];
    HasIndex := ExtractIndex(Part, Idx);

    if Result.JSONType = jtObject then
    begin
      Obj := TJSONObject(Result);

      if Obj.Find(Part) = nil then
      begin
        if CreateIfMissing then
        begin
          if HasIndex then
            Obj.Add(Part, TJSONArray.Create)
          else
            Obj.Add(Part, TJSONObject.Create);
        end
        else
          Exit(nil);
      end;

      Result := Obj.Find(Part);
    end;

    if HasIndex and (Result.JSONType = jtArray) then
    begin
      Arr := TJSONArray(Result);

      while CreateIfMissing and (Arr.Count <= Idx) do
        Arr.Add(TJSONObject.Create);

      if Idx < Arr.Count then
        Result := Arr.Items[Idx]
      else
        Exit(nil);
    end;
  end;
end;

function GetJSONValue(const FileName, Path: string): string;
var
  JSON: TJSONObject;
  Val: TJSONData;
begin
  Result := '';

  JSON := LoadJSON(FileName);
  try
    Val := Navigate(JSON, Path, False);
    if Val <> nil then
      Result := Val.AsString;
  finally
    JSON.Free;
  end;
end;

procedure SetJSONValue(const FileName, Path, NewValue: string);
var
  JSON: TJSONObject;
  ParentPath, LastPart: string;
  p: integer;
  Parent: TJSONData;
  Obj: TJSONObject;
  Token: string;
  Idx: integer;
  Arr: TJSONArray;
  HasIndex: boolean;
begin
  JSON := LoadJSON(FileName);
  try
    p := LastDelimiter('.', Path);

    if p > 0 then
    begin
      ParentPath := Copy(Path, 1, p - 1);
      LastPart := Copy(Path, p + 1, MaxInt);
    end
    else
    begin
      ParentPath := '';
      LastPart := Path;
    end;

    if ParentPath = '' then
      Parent := JSON
    else
      Parent := Navigate(JSON, ParentPath, True);

    Token := LastPart;
    HasIndex := ExtractIndex(Token, Idx);

    if Parent.JSONType = jtObject then
    begin
      Obj := TJSONObject(Parent);

      if HasIndex then
      begin
        if Obj.Find(Token) = nil then
          Obj.Add(Token, TJSONArray.Create);

        Arr := TJSONArray(Obj.Find(Token));

        while Arr.Count <= Idx do
          Arr.Add('');

        Arr.Strings[Idx] := NewValue;
      end
      else
      begin
        Obj.Delete(Token);
        Obj.Add(Token, NewValue);
      end;
    end;

    SaveJSON(JSON, FileName);

  finally
    JSON.Free;
  end;
end;

end.
