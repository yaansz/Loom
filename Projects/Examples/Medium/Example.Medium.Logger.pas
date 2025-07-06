unit Example.Medium.Logger;

interface

uses
  Loom.Attributes;

type
  ILogger = interface
    ['{925DF3BE-4E87-4167-938D-5D25FCA24CBB}']
    procedure Log(Msg: string);
  end;

  [Component]
  [Implements(ILogger)]
  TConsoleLogger = class(TInterfacedObject, ILogger)
  public
    procedure Log(Msg: string);
  end;

implementation

uses
  Loom.Container;

{ TConsoleLogger }

procedure TConsoleLogger.Log(Msg: string);
begin
  WriteLn('[LOG] ' + Msg);
end;

initialization
  TConsoleLogger.ClassName;

end.
