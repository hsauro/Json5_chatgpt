unit JSON5Parser;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  TJSON5Value = class
    // Define properties and methods for various value types (string, number, object, array, etc.)
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
    function ParseString: string;
    function ParseNumber: Double;
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

function TJSON5Parser.ParseString: string;
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

  Result := FBuffer.ToString;
end;


function TJSON5Parser.ParseNumber: Double;
var
  NumberStr: string;
begin
  FBuffer.Clear;
  
  if FCurrentChar = '-' then
  begin
    FBuffer.Append('-');
    FCurrentChar := ReadChar;
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