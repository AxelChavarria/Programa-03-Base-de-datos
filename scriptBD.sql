-- Catálogos
CREATE TABLE Puesto (Id INT PRIMARY KEY, Nombre VARCHAR(100), SalarioxHora DECIMAL(10,2));
CREATE TABLE TipoMovimiento (Id INT PRIMARY KEY, Nombre VARCHAR(100));
CREATE TABLE TipoEvento (Id INT PRIMARY KEY, Nombre VARCHAR(100));
CREATE TABLE Error (Id INT PRIMARY KEY, Codigo INT, Descripcion VARCHAR(255));






--Tablas
CREATE TABLE Empleado (
    Id INT IDENTITY(1,1) PRIMARY KEY, 
    IdPuesto INT FOREIGN KEY REFERENCES Puesto(Id), 
    ValorDocumentoIdentidad VARCHAR(50) UNIQUE,
    Nombre VARCHAR(100),
    FechaContratacion DATE,
    SaldoVacaciones DECIMAL(10,2) DEFAULT 0,
    EsActivo BIT DEFAULT 1
);

CREATE TABLE Usuario (
    Id INT IDENTITY(1,1) PRIMARY KEY, 
    Username VARCHAR(50) UNIQUE, 
    Password VARCHAR(50)
);


CREATE TABLE Movimiento (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdEmpleado INT FOREIGN KEY REFERENCES Empleado(Id),
    IdTipoMovimiento INT FOREIGN KEY REFERENCES TipoMovimiento(Id), 
    Fecha DATETIME DEFAULT GETDATE(),
    Monto DECIMAL(10,2),
    NuevoSaldo DECIMAL(10,2),
    IdPostByUser INT FOREIGN KEY REFERENCES Usuario(Id),
    PostInIP VARCHAR(50),
    PostTime DATETIME DEFAULT GETDATE()
);

CREATE TABLE BitacoraEvento (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    idTipoEvento INT FOREIGN KEY REFERENCES TipoEvento(Id), 
    Descripcion VARCHAR(MAX),
    IdPostByUser INT FOREIGN KEY REFERENCES Usuario(Id),
    PostInIP VARCHAR(50),
    PostTime DATETIME DEFAULT GETDATE()
);

CREATE TABLE DBError (
    ID INT IDENTITY(1,1) PRIMARY KEY, 
    UserName VARCHAR(100), 
    Number INT, 
    State INT, 
    Severity INT, 
    Line INT, 
    [Procedure] VARCHAR(100), 
    Message VARCHAR(MAX), 
    DateTime DATETIME DEFAULT GETDATE()
);