unit Loom.Container.Injection.Test;

interface

uses
  DUnitX.TestFramework,
  Loom.Attributes,
  Loom.Container.Resolver,
  Loom.Container.Registry,
  Loom.Container.DataTypes,
  System.SysUtils,
  System.Generics.Collections;

type
  ITestService = interface
    ['{B7623735-B192-4318-965D-109B5BF8F34D}']
    function GetName: string;
  end;

  IAnotherService = interface
    ['{BDD82872-F48A-41CF-ABDE-ED142F01D5BD}']
  end;

  TTestService = class(TInterfacedObject, ITestService)
  public
    function GetName: string;
  end;

  TTestComponent = class
  private
    [Autowired]
    FFieldService: TTestService;  // Field injection of class
    [Autowired]
    FFieldIntf: ITestService;     // Field injection of interface
  end;

  TCircularB = class;

  TCircularA = class
  private
    [Autowired]
    FB: TCircularB;
  end;

  TCircularB = class
  private
    [Autowired]
    FA: TCircularA;
  end;

  TestContainerResolver = class
  private
    FRegistry: TContainerRegistry;
    FResolver: TContainerResolver;
  public
    [Setup]
    procedure Setup;

    [Teardown]
    procedure Teardown;

    [Test]
    procedure TestFieldInjection_Class;

    [Test]
    procedure TestFieldInjection_Interface;

    [Test]
    procedure TestPropertyInjection_Class;

    [Test]
    procedure TestPropertyInjection_Interface;

    [Test]
    procedure TestCircularDependencyDetection;
  end;

implementation

{ TTestService }

function TTestService.GetName: string;
begin
  Result := 'TTestService';
end;

{ TestTContainerResolver }

procedure TestContainerResolver.Setup;
begin
  FRegistry := TContainerRegistry.Create;
  FRegistry.RegisterComponent(TTestService, TScope.Singleton);
  FRegistry.RegisterComponent(TTestComponent, TScope.Prototype);
  FRegistry.RegisterInterface(ITestService, TTestService, TScope.Singleton);
  FResolver := TContainerResolver.Create(FRegistry);
end;

procedure TestContainerResolver.Teardown;
begin
  FResolver.Free;
  FRegistry.Free;
end;

procedure TestContainerResolver.TestFieldInjection_Class;
var
  Component: TTestComponent;
begin
  Component := FResolver.Resolve(TTestComponent) as TTestComponent;
  try
    Assert.IsNotNull(Component.FFieldService, 'Field service (class) not injected');
    Assert.IsTrue(Component.FFieldService is TTestService, 'Incorrect type for field service');
  finally
    Component.Free;
  end;
end;

procedure TestContainerResolver.TestFieldInjection_Interface;
var
  Component: TTestComponent;
begin
  Component := FResolver.Resolve(TTestComponent) as TTestComponent;
  try
    Assert.IsNotNull(Component.FFieldIntf, 'Field service (interface) not injected');
    Assert.IsTrue(Component.FFieldIntf <> nil, 'Incorrect type for field interface');
  finally
    Component.Free;
  end;
end;

[Test]
procedure TestContainerResolver.TestPropertyInjection_Class;
begin

end;

[Test]
procedure TestContainerResolver.TestPropertyInjection_Interface;
begin

end;

procedure TestContainerResolver.TestCircularDependencyDetection;
begin
  FRegistry.RegisterComponent(TCircularA, TScope.Prototype);
  FRegistry.RegisterComponent(TCircularB, TScope.Prototype);

  Assert.WillRaise(
    procedure
    begin
      FResolver.Resolve(TCircularA);
    end,
    ECircularDependencyError,
    'Circular dependency should be detected'
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TestContainerResolver);
end.
