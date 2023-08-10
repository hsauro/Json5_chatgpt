unit json5lib;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
type
  TJSON5ValueType = (jvString, jvNumber, jvObject, jvArray, jvBoolean, jvNull);

  TJSON5Value = class
  private
    FValueType: TJSON5ValueType;
    FStringValue: string;
    FNumberValue: Double;
    FObjectValue: TDictionary<string, TJSON5Value>;
    FArrayValue: TArray<TJSON5Value>;
  public
    constructor CreateString(const Value: string);
    constructor CreateNumber(const Value: Double);
    constructor CreateObject;
    constructor CreateArray;
    function GetType: TJSON5ValueType;
    function ToString: string; override;

    // Additional methods to interact with specific value types
    function GetStringValue: string;
    function GetNumberValue: Double;
    function GetObjectValue: TDictionary<string, TJSON5Value>;
    function GetArrayValue: TArray<TJSON5Value>;
  end;

  TJSON5Parser = class
  private
    FStream: TStream;
    FBuffer: TStringBuilder;
    FCurrentChar: Char;
    function ReadChar: Char;
    function PeekChar: Char;
    function IsWhitespace(c: Char): Boolean;
    function ParseValue: TJSON5Value;
    function ParseString: TJSON5Value;
    function ParseNumber: TJSON5Value;
    function ParseObject: TDictionary<string, TJSON5Value>;
    function ParseArray: TArray<TJSON5Value>;
    procedure SkipWhitespace;
    procedure SkipComments;
  public
    constructor Create(Stream: TStream);
    destructor Destroy; override;
    function Parse: TJSON5Value;
  end;

implementation

// ...

constructor TJSON5Value.CreateString(const Value: string);
begin
  FValueType := jvString;
  FStringValue := Value;
end;

constructor TJSON5Value.CreateNumber(const Value: Double);
begin
  FValueType := jvNumber;
  FNumberValue := Value;
end;

constructor TJSON5Value.CreateObject;
begin
  FValueType := jvObject;
  FObjectValue := TDictionary<string, TJSON5Value>.Create;
end;

constructor TJSON5Value.CreateArray;
begin
  FValueType := jvArray;
  FArrayValue := [];
end;

function TJSON5Value.GetType: TJSON5ValueType;
begin
  Result := FValueType;
end;

function TJSON5Value.ToString: string;
begin
  case FValueType of
    jvString: Result := '"' + FStringValue + '"';
    jvNumber: Result := FloatToStr(FNumberValue);
    jvObject: Result := ''; // Implement object serialization here
    jvArray: Result := '';  // Implement array serialization here
    jvBoolean: Result := ''; // Implement boolean serialization here
    jvNull: Result := 'null';
  end;
end;

function TJSON5Value.GetStringValue: string;
begin
  if FValueType = jvString then
    Result := FStringValue
  else
    raise Exception.Create('Value is not a string');
end;

function TJSON5Value.GetNumberValue: Double;
begin
  if FValueType = jvNumber then
    Result := FNumberValue
  else
    raise Exception.Create('Value is not a number');
end;

function TJSON5Value.GetObjectValue: TDictionary<string, TJSON5Value>;
begin
  if FValueType = jvObject then
    Result := FObjectValue
  else
    raise Exception.Create('Value is not an object');
end;

function TJSON5Value.GetArrayValue: TArray<TJSON5Value>;
begin
  if FValueType = jvArray then
    Result := FArrayValue
  else
    raise Exception.Create('Value is not an array');
end;

constructor TJSON5Parser.Create(Stream: TStream);
begin
  FStream := Stream;
  FBuffer := TStringBuilder.Create;
  FCurrentChar := ReadChar;
end;

destructor TJSON5Parser.Destroy;
begin
  FBuffer.Free;
  inherited;
end;

function TJSON5Parser.ReadChar: Char;
var
  ByteRead: Byte;
begin
  if FStream.Position < FStream.Size then
  begin
    FStream.Read(ByteRead, SizeOf(Byte));
    Result := Char(ByteRead);
  end
  else
    Result := #0;  // End of stream
end;

function TJSON5Parser.PeekChar: Char;
var
  StreamPos: Int64;
begin
  StreamPos := FStream.Position;
  Result := ReadChar;
  FStream.Position := StreamPos;
end;

function TJSON5Parser.IsWhitespace(c: Char): Boolean;
begin
  Result := CharInSet(c, [' ', #9, #10, #13]);
end;

procedure TJSON5Parser.SkipWhitespace;
begin
  while IsWhitespace(FCurrentChar) do
    FCurrentChar := ReadChar;
end;

procedure TJSON5Parser.SkipComments;
begin
  if FCurrentChar = '/' then
  begin
    FCurrentChar := ReadChar;
    if FCurrentChar = '/' then
    begin
      // Single-line comment
      repeat
        FCurrentChar := ReadChar;
      until (FCurrentChar = #0) or (FCurrentChar = #10) or (FCurrentChar = #13);
    end
    else if FCurrentChar = '*' then
    begin
      // Multi-line comment
      repeat
        FCurrentChar := ReadChar;
        if FCurrentChar = '*' then
        begin
          FCurrentChar := ReadChar;
          if FCurrentChar = '/' then
          begin
            FCurrentChar := ReadChar;
            Break;
          end;
        end;
      until FCurrentChar = #0;
    end;
  end;
end;


function TJSON5Parser.Parse: TJSON5Value;
begin
  Result := ParseValue;
  SkipWhitespace;
  if FCurrentChar <> #0 then
    raise Exception.Create('Expected end of input');
end;


function TJSON5Parser.ParseValue: TJSON5Value;
begin
  SkipWhitespace;
  SkipComments;

  case FCurrentChar of
    '"': Result := ParseString;
    '0'..'9', '-': Result := ParseNumber;
    '{': Result := ParseObject;
    '[': Result := ParseArray;
    // Add handling for other value types here
    else
      raise Exception.Create('Unexpected character: ' + FCurrentChar);
  end;

  SkipWhitespace;
  SkipComments;
end;

function TJSON5Parser.ParseString: TJSON5Value;
var
  ValueStr: string;
begin
  FBuffer.Clear;
  FCurrentChar := ReadChar; // Consume opening double quote

  while FCurrentChar <> #0 do
  begin
    case FCurrentChar of
      '\':
        begin
          FCurrentChar := ReadChar;
          case FCurrentChar of
            '"': FBuffer.Append('"');
            '\': FBuffer.Append('\');
            '/': FBuffer.Append('/');
            'b': FBuffer.Append(#8); // Backspace
            'f': FBuffer.Append(#12); // Form feed
            'n': FBuffer.Append(#10); // Newline
            'r': FBuffer.Append(#13); // Carriage return
            't': FBuffer.Append(#9); // Tab
            'u':
              begin
                // Unicode escape sequence
                // Implement parsing of Unicode escape sequences here
              end;
            else
              raise Exception.Create('Invalid escape sequence: \' + FCurrentChar);
          end;
        end;
      '"':
        begin
          FCurrentChar := ReadChar; // Consume closing double quote
          Break;
        end;
      else
        FBuffer.Append(FCurrentChar);
    end;

    FCurrentChar := ReadChar;
  end;

  ValueStr := FBuffer.ToString;
  Result := TJSON5Value.CreateString(ValueStr);
end;


function TJSON5Parser.ParseNumber: TJSON5Value;
var
  NumberStr: string;
  NumberValue: Double;
begin
  FBuffer.Clear;

  if FCurrentChar = '-' then
  begin
    FBuffer.Append('-');
    FCurrentChar := ReadChar;
  end;

  if FCurrentChar = '0' then
  begin
    FBuffer.Append(FCurrentChar);
    FCurrentChar := ReadChar;

    if CharInSet(FCurrentChar, ['x', 'X']) then
    begin
      FBuffer.Append(FCurrentChar);
      FCurrentChar := ReadChar;

      while CharInSet(FCurrentChar, ['0'..'9', 'a'..'f', 'A'..'F']) do
      begin
        FBuffer.Append(FCurrentChar);
        FCurrentChar := ReadChar;
      end;

      NumberStr := FBuffer.ToString;
      NumberValue := StrToFloat('$' + NumberStr); // Convert hexadecimal string to floating-point
      Exit(TJSON5Value.CreateNumber(NumberValue));
    end;
  end;

  while FCurrentChar in ['0'..'9'] do
  begin
    FBuffer.Append(FCurrentChar);
    FCurrentChar := ReadChar;
  end;

  if FCurrentChar = '.' then
  begin
    FBuffer.Append('.');
    FCurrentChar := ReadChar;

    while FCurrentChar in ['0'..'9'] do
    begin
      FBuffer.Append(FCurrentChar);
      FCurrentChar := ReadChar;
    end;
  end;

  if FCurrentChar in ['e', 'E'] then
  begin
    FBuffer.Append(FCurrentChar);
    FCurrentChar := ReadChar;

    if FCurrentChar in ['+', '-'] then
    begin
      FBuffer.Append(FCurrentChar);
      FCurrentChar := ReadChar;
    end;

    while FCurrentChar in ['0'..'9'] do
    begin
      FBuffer.Append(FCurrentChar);
      FCurrentChar := ReadChar;
    end;
  end;

  NumberStr := FBuffer.ToString;
  NumberValue := StrToFloat(NumberStr); // Convert decimal string to floating-point
  Result := TJSON5Value.CreateNumber(NumberValue);
end;



  if FCurrentChar in ['e', 'E'] then
  begin
    FBuffer.Append(FCurrentChar);
    FCurrentChar := ReadChar;

    if FCurrentChar in ['+', '-'] then
    begin
      FBuffer.Append(FCurrentChar);
      FCurrentChar := ReadChar;
    end;

    while FCurrentChar in ['0'..'9'] do
    begin
      FBuffer.Append(FCurrentChar);
      FCurrentChar := ReadChar;
    end;
  end;

  NumberStr := FBuffer.ToString;
  Result := StrToFloat(NumberStr); // You can use StrToFloatDef for error handling
end;


function TJSON5Parser.ParseObject: TDictionary<string, TJSON5Value>;
var
  Key: string;
  Value: TJSON5Value;
begin
  Result := TDictionary<string, TJSON5Value>.Create;
  FCurrentChar := ReadChar; // Consume opening curly brace

  SkipWhitespace;
  if FCurrentChar <> '}' then
  begin
    repeat
      SkipWhitespace;
      
      if FCurrentChar = '}' then
        Break;

      // Parse key (supports relaxed key names)
      if FCurrentChar = '"' then
        Key := ParseString
      else if (FCurrentChar in ['a'..'z', 'A'..'Z', '_', '$']) then
      begin
        FBuffer.Clear;
        while FCurrentChar in ['a'..'z', 'A'..'Z', '0'..'9', '_', '$'] do
        begin
          FBuffer.Append(FCurrentChar);
          FCurrentChar := ReadChar;
        end;
        Key := FBuffer.ToString;
        SkipWhitespace;
        if FCurrentChar <> ':' then
          raise Exception.Create('Expected colon after object key');
      end
      else
        raise Exception.Create('Invalid object key');

      // Consume colon
      FCurrentChar := ReadChar;

      // Parse value
      Value := ParseValue;
      Result.Add(Key, Value);

      SkipWhitespace;
      if FCurrentChar = ',' then
        FCurrentChar := ReadChar // Consume comma for potential next pair
      else if FCurrentChar <> '}' then
        raise Exception.Create('Expected comma or closing curly brace');
    until FCurrentChar = '}';
  end;

  if FCurrentChar = '}' then
    FCurrentChar := ReadChar; // Consume closing curly brace
  else
    raise Exception.Create('Expected closing curly brace');
end;


function TJSON5Parser.ParseArray: TArray<TJSON5Value>;
var
  Values: TList<TJSON5Value>;
  Value: TJSON5Value;
begin
  Values := TList<TJSON5Value>.Create;
  FCurrentChar := ReadChar; // Consume opening square bracket

  SkipWhitespace;
  if FCurrentChar <> ']' then
  begin
    repeat
      SkipWhitespace;

      if FCurrentChar = ']' then
        Break;

      // Parse value
      Value := ParseValue;
      Values.Add(Value);

      SkipWhitespace;
      if FCurrentChar = ',' then
        FCurrentChar := ReadChar // Consume comma for potential next value
      else if FCurrentChar <> ']' then
        raise Exception.Create('Expected comma or closing square bracket');
    until FCurrentChar = ']';
  end;

  if FCurrentChar = ']' then
    FCurrentChar := ReadChar; // Consume closing square bracket
  else
    raise Exception.Create('Expected closing square bracket');

  Result := Values.ToArray;
  Values.Free;
end;


end.
