unit Example.Simple.Service;

interface

uses
  Loom.Attributes;

type
  [Service]
  TGreetingService = class
  private
    FMsg : String;

  public
    constructor Create;
    function GetGreeting: string;
  end;

implementation

{ TGreetingService }

constructor TGreetingService.Create;
begin
  FMsg := 'Hello from Loom Container!';
end;

function TGreetingService.GetGreeting: string;
begin
  Result := FMsg;
end;

end.
