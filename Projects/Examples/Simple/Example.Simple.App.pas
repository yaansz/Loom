unit Example.Simple.App;

interface

uses
  Loom.Attributes,
  Example.Simple.Service;

type
  [Component]
  TApp = class
  private
    FGreetingService: TGreetingService;
  public
    procedure Run;

    [Autowired]
    property GreetingService : TGreetingService read FGreetingService write FGreetingService;
  end;

implementation

{ TApp }

procedure TApp.Run;
begin
  WriteLn(FGreetingService.GetGreeting);
end;

end.
