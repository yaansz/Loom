unit Example.Medium.DatabaseService;

interface

uses
  Loom.Attributes,
  Example.Medium.Logger;

type
  IDataService = interface
    ['{638AD52A-E2F1-4076-84FF-D38EED644F9F}']
    function GetData: string;
  end;

  [Component]
  [Implements(IDataService)]
  TDatabaseService = class(TInterfacedObject, IDataService)
  private
    FLogger: ILogger;
  public
    constructor Create(Logger: ILogger);
    function GetData: string;
  end;

implementation

{ TDatabaseService }

constructor TDatabaseService.Create(Logger: ILogger);
begin
  FLogger := Logger;
  FLogger.Log('Database service initialized');
end;

function TDatabaseService.GetData: string;
begin
  FLogger.Log('Fetching data from database');
  Result := 'Data: 42';
end;

initialization
  TDatabaseService.ClassName;

end.
