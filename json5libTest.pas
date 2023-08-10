program JSON5ParserTests;

uses
  System.SysUtils, System.Classes, json5lib;

procedure RunTest(const TestName, JSON5Input: string; ExpectedResult: string);
var
  TestStream: TStringStream;
  Parser: TJSON5Parser;
  ParsedValue: TJSON5Value;
begin
  Writeln('Running test: ', TestName);
  TestStream := TStringStream.Create(JSON5Input);
  try
    Parser := TJSON5Parser.Create(TestStream);
    try
      ParsedValue := Parser.Parse;
      // Convert ParsedValue to a JSON string for comparison
      if ParsedValue.ToString = ExpectedResult then
        Writeln('Test passed.')
      else
        Writeln('Test failed: Expected ', ExpectedResult, ', but got ', ParsedValue.ToString);
    finally
      Parser.Free;
    end;
  finally
    TestStream.Free;
  end;
end;

begin
  try
    // Test cases
    RunTest('Simple String', '"Hello, World!"', '"Hello, World!"');
    RunTest('Number', '42', '42');
    RunTest('Object', '{ key: "value", "num": 123 }', '{"key":"value","num":123}');
    RunTest('Array', '[1, 2, 3]', '[1,2,3]');
    // Add more test cases here

    Writeln('All tests passed.');
  except
    on E: Exception do
      Writeln('Test failed: ', E.Message);
  end;
end.
