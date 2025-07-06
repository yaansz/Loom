unit Loom.Container.AutoRegister.Classes;

interface

uses
  Loom.Attributes;

type
  // Test classes in units matching the pattern
  [Component]
  TAutoTestComponent = class
  end;

  [Service]
  TAutoTestService = class
  end;

  // Test class in a unit that DOES NOT match the pattern
  [Component]
  TExcludedComponent = class
  end;

  // Class without attributes (should not register)
  TUnattributedClass = class
  end;

implementation

initialization
  // Force linker to include test classes (alternative to ForceReferenceToClass)
  TAutoTestComponent.ClassName;
  TAutoTestService.ClassName;
  TExcludedComponent.ClassName;
  TUnattributedClass.ClassName;

end.
