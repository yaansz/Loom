unit Loom.Container.Tests;

interface

uses
  DUnitX.TestFramework,
  Loom.Attributes,
  Loom.Container,
  System.SysUtils;

type
  IWeapon = interface
    ['{6D1D35A0-7F4C-4E4A-88A9-0E9A73D58C6C}']
    function Damage: Integer;
  end;

  IShield = interface
    ['{C0D5D5C1-3D7F-4F2A-9F3E-1D9F8B7A8C1D}']
    function Defense: Integer;
  end;

  TSword = class(TInterfacedObject, IWeapon)
  public
    function Damage: Integer;
  end;

  TShuriken = class(TInterfacedObject, IWeapon)
  public
    function Damage: Integer;
  end;

  TKnightShield = class(TInterfacedObject, IShield)
  public
    function Defense: Integer;
  end;

  [Component]
  TWarrior = class
  private
    FWeapon: IWeapon;
  public
    constructor Create(AWeapon: IWeapon);
    property Weapon: IWeapon read FWeapon;
  end;

  TCustomWarrior = class
  private
    FWeapon: IWeapon;
    FShield: IShield;
  public
    constructor Create(AWeapon: IWeapon; AShield: IShield);
    property Weapon: IWeapon read FWeapon;
    property Shield: IShield read FShield;
  end;

  TSingletonTest = class
  public
    ID: Integer;
  end;

  TPrototypeTest = class
  public
    ID: Integer;
  end;

  TCircularB = class;

  TCircularA = class
  private
    FB: TCircularB;
  public
    constructor Create(B: TCircularB);
  end;

  TCircularB = class
  private
    FA: TCircularA;
  public
    constructor Create(A: TCircularA);
  end;

  TInvalidDependency = class
  public
    constructor Create(Value: Integer);
  end;

  [TestFixture]
  TLoomContainerTests = class
  private
    FContainer: LoomContainer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_RegisterComponent_ResolvesClass;

    [Test]
    procedure Test_RegisterType_WithFactory;

    [Test]
    procedure Test_InterfaceResolution_ManualRegistration;

    [Test]
    procedure Test_NamedInterfaceResolution;

    [Test]
    procedure Test_SingletonScope;

    [Test]
    procedure Test_PrototypeScope;

    [Test]
    procedure Test_ConstructorInjection;

    [Test]
    procedure Test_CircularDependency_ThrowsException;

    [Test]
    procedure Test_UnregisteredClass_ThrowsException;

    [Test]
    procedure Test_UnregisteredInterface_ThrowsException;

    [Test]
    procedure Test_InvalidDependencyType_ThrowsException;

    [Test]
    procedure Test_DefaultContainer_SingletonBehavior;
  end;

implementation

uses
  Loom.Container.Resolver;

{ TSword }

function TSword.Damage: Integer;
begin
  Result := 10;
end;

{ TShuriken }

function TShuriken.Damage: Integer;
begin
  Result := 5;
end;

{ TKnightShield }

function TKnightShield.Defense: Integer;
begin
  Result := 15;
end;

{ TWarrior }

constructor TWarrior.Create(AWeapon: IWeapon);
begin
  FWeapon := AWeapon;
end;

{ TCustomWarrior }

constructor TCustomWarrior.Create(AWeapon: IWeapon; AShield: IShield);
begin
  FWeapon := AWeapon;
  FShield := AShield;
end;

{ TCircularA }

constructor TCircularA.Create(B: TCircularB);
begin
  FB := B;
end;

{ TCircularB }

constructor TCircularB.Create(A: TCircularA);
begin
  FA := A;
end;

{ TInvalidDependency }

constructor TInvalidDependency.Create(Value: Integer);
begin
  // Invalid dependency type
end;

{ TLoomContainerTests }

procedure TLoomContainerTests.Setup;
begin
  FContainer := LoomContainer.Create;
end;

procedure TLoomContainerTests.TearDown;
begin
  FContainer.Free;
end;

procedure TLoomContainerTests.Test_RegisterComponent_ResolvesClass;
begin
  FContainer.RegisterComponent(TWarrior);
  FContainer.RegisterInterface(IWeapon, TSword);

  var Warrior := FContainer.Resolve(TWarrior);
  Assert.IsNotNull(Warrior, 'Warrior should be resolved');
  Assert.IsTrue(Warrior is TWarrior, 'Resolved instance should be TWarrior');
  Assert.AreEqual(10, TWarrior(Warrior).Weapon.Damage, 'Weapon damage should be 10');
end;

procedure TLoomContainerTests.Test_RegisterType_WithFactory;
begin
  FContainer.RegisterType(TSingletonTest,
    function: TObject
    begin
      Result := TSingletonTest.Create;
      TSingletonTest(Result).ID := 42;
    end);

  var Instance := FContainer.Resolve(TSingletonTest);
  Assert.AreEqual(42, TSingletonTest(Instance).ID, 'Factory should set ID to 42');
end;

procedure TLoomContainerTests.Test_InterfaceResolution_ManualRegistration;
begin
  FContainer.RegisterComponent(TCustomWarrior);
  FContainer.RegisterInterface(IWeapon, TSword);
  FContainer.RegisterInterface(IShield, TKnightShield);

  var Warrior := FContainer.Resolve(TCustomWarrior);
  Assert.AreEqual(10, TCustomWarrior(Warrior).Weapon.Damage, 'Weapon damage should be 10');
  Assert.AreEqual(15, TCustomWarrior(Warrior).Shield.Defense, 'Shield defense should be 15');
end;

procedure TLoomContainerTests.Test_NamedInterfaceResolution;
begin
  FContainer.RegisterInterface(IWeapon, TSword, TScope.Singleton, 'Sword');
  FContainer.RegisterInterface(IWeapon, TShuriken, TScope.Singleton, 'Shuriken');

  var Sword := FContainer.ResolveInterface<IWeapon>('Sword');
  var Shuriken := FContainer.ResolveInterface<IWeapon>('Shuriken');

  Assert.AreEqual(10, Sword.Damage, 'Sword damage should be 10');
  Assert.AreEqual(5, Shuriken.Damage, 'Shuriken damage should be 5');
end;

procedure TLoomContainerTests.Test_SingletonScope;
begin
  FContainer.RegisterComponent(TSingletonTest, TScope.Singleton);

  var Instance1 := FContainer.Resolve(TSingletonTest);
  var Instance2 := FContainer.Resolve(TSingletonTest);

  Assert.AreSame(Instance1, Instance2, 'Singleton instances should be the same');
end;

procedure TLoomContainerTests.Test_PrototypeScope;
begin
  FContainer.RegisterComponent(TPrototypeTest, TScope.Prototype);

  var Instance1 := FContainer.Resolve(TPrototypeTest);
  var Instance2 := FContainer.Resolve(TPrototypeTest);

  Assert.AreNotSame(Instance1, Instance2, 'Prototype instances should be different');
end;

procedure TLoomContainerTests.Test_ConstructorInjection;
begin
  FContainer.RegisterComponent(TCustomWarrior);
  FContainer.RegisterInterface(IWeapon, TSword);
  FContainer.RegisterInterface(IShield, TKnightShield);

  var Warrior := FContainer.Resolve(TCustomWarrior);
  Assert.IsNotNull(Warrior, 'Warrior should be resolved');
  Assert.AreEqual(10, TCustomWarrior(Warrior).Weapon.Damage, 'Constructor-injected weapon should work');
end;

procedure TLoomContainerTests.Test_CircularDependency_ThrowsException;
begin
  FContainer.RegisterComponent(TCircularA);
  FContainer.RegisterComponent(TCircularB);

  Assert.WillRaise(
    procedure
    begin
      FContainer.Resolve(TCircularA);
    end,
    ECircularDependencyError,
    'Should raise circular dependency exception'
  );
end;

procedure TLoomContainerTests.Test_UnregisteredClass_ThrowsException;
begin
  Assert.WillRaise(
    procedure
    begin
      FContainer.Resolve(TWarrior);
    end,
    EContainerResolveException,
    'Should raise exception for unregistered class'
  );
end;

procedure TLoomContainerTests.Test_UnregisteredInterface_ThrowsException;
begin
  FContainer.RegisterComponent(TWarrior);

  Assert.WillRaise(
    procedure
    begin
      FContainer.Resolve(TWarrior);
    end,
    EContainerResolveException,
    'Should raise exception for unregistered interface dependency'
  );
end;

procedure TLoomContainerTests.Test_InvalidDependencyType_ThrowsException;
begin
  FContainer.RegisterComponent(TInvalidDependency);

  Assert.WillRaise(
    procedure
    begin
      FContainer.Resolve(TInvalidDependency);
    end,
    EContainerResolveException,
    'Should raise exception for unsupported dependency type'
  );
end;

procedure TLoomContainerTests.Test_DefaultContainer_SingletonBehavior;
begin
  var Container1 := LoomContainer.GetDefaultContainer;
  var Container2 := LoomContainer.GetDefaultContainer;

  Assert.AreSame(Container1, Container2, 'Default container should be singleton');

  LoomContainer.SetDefaultContainer(nil);
  var Container3 := LoomContainer.GetDefaultContainer;

  Assert.IsNotNull(Container3, 'New default container should be created');
  Assert.AreNotSame(Container1, Container3, 'New container should be different instance');
end;

initialization
  TDUnitX.RegisterTestFixture(TLoomContainerTests);

end.
