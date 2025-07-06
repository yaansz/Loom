unit Example.Medium.App;

interface

uses
  Loom.Attributes,
  Example.Medium.Logger,
  Example.Medium.DatabaseService;

type
  [Component]
  TApp = class
  private
    FLogger      : ILogger;
    FDataService : IDataService;
  public
    constructor Create(Logger: ILogger; DataService: IDataService);
    procedure Run;
  end;

implementation

{ TApp }

constructor TApp.Create(Logger: ILogger; DataService: IDataService);
begin
  FLogger := Logger;
  FDataService := DataService;
  FLogger.Log('App created');
end;

procedure TApp.Run;
begin
  FLogger.Log('Starting application');
  WriteLn(FDataService.GetData);
  FLogger.Log('Application completed');
end;

initialization
  TApp.ClassName;

end.
