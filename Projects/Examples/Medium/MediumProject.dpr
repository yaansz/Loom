program MediumProject;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Loom.Attributes in '..\..\..\Source\Loom.Attributes.pas',
  Loom.Container in '..\..\..\Source\Loom.Container.pas',
  Example.Medium.Logger in 'Example.Medium.Logger.pas',
  Example.Medium.DatabaseService in 'Example.Medium.DatabaseService.pas',
  Example.Medium.App in 'Example.Medium.App.pas',
  Loom.Container.Registry in '..\..\..\Source\Loom.Container.Registry.pas',
  Loom.Container.Resolver in '..\..\..\Source\Loom.Container.Resolver.pas',
  Loom.Container.DataTypes in '..\..\..\Source\Loom.Container.DataTypes.pas',
  Example.Medium.Main in 'Example.Medium.Main.pas',
  Loom.Container.Injector in '..\..\..\Source\Loom.Container.Injector.pas';

var
  Container: LoomContainer;
  App: TApp;
begin
  try
    Container := LoomContainer.Create;
    Container.AutoRegister('Example.Medium.*');

    App := Container.Resolve<TApp>;
    App.Run;

    App.Free;
  except
    on E: Exception do
      WriteLn('Error: ', E.Message);
  end;
  ReadLn;

end.


