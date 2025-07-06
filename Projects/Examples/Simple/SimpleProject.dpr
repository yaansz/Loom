program SimpleProject;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Example.Simple.Service in 'Example.Simple.Service.pas',
  Example.Simple.App in 'Example.Simple.App.pas',
  Loom.Attributes in '..\..\..\Source\Loom.Attributes.pas',
  Loom.Container.DataTypes in '..\..\..\Source\Loom.Container.DataTypes.pas',
  Loom.Container in '..\..\..\Source\Loom.Container.pas',
  Loom.Container.Registry in '..\..\..\Source\Loom.Container.Registry.pas',
  Loom.Container.Resolver in '..\..\..\Source\Loom.Container.Resolver.pas',
  Loom.Container.Injector in '..\..\..\Source\Loom.Container.Injector.pas';

var
  Container: LoomContainer;
  App: TApp;
begin
  try
    Container := LoomContainer.Create;
    Container.RegisterComponent(TGreetingService);
    Container.RegisterComponent(TApp);

    App := Container.Resolve<TApp>;
    App.Run;

    App.Free;
  except
    on E: Exception do
      WriteLn('Error: ', E.Message);
  end;
  ReadLn;
end.
