
----------------------- 1 Catálogos

CREATE TABLE Puesto ( Id INT IDENTITY(1,1) PRIMARY KEY,  Nombre VARCHAR(100) NOT NULL UNIQUE, SalarioxHora DECIMAL(10,2) NOT NULL)

--(1=Diurno, 2=Vespertino, 3=Nocturno).
CREATE TABLE TipoJornada (Id INT PRIMARY KEY, Nombre VARCHAR(50) NOT NULL,HoraInicio TIME NOT NULL,HoraFin TIME NOT NULL)

CREATE TABLE Feriado (Id INT PRIMARY KEY,Nombre VARCHAR(100) NOT NULL,Fecha DATE NOT NULL UNIQUE)

CREATE TABLE TipoEvento (Id INT PRIMARY KEY, Nombre VARCHAR(100) NOT NULL)

-- C o D
CREATE TABLE TipoMovimiento (Id INT PRIMARY KEY, Nombre VARCHAR(100) NOT NULL,Accion CHAR(1) NOT NULL CHECK (Accion IN ('C', 'D')))

-- TipoDeduccion: NO usa identity. Id directo del XML. Relacionado con TipoMovimiento.
CREATE TABLE TipoDeduccion (
    Id INT PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    EsObligatoria BIT NOT NULL,  -- 0=No, 1=Si
    EsPorcentual BIT NOT NULL,   -- 0=No, 1=Si
    Valor DECIMAL(5,4) NOT NULL, -- Ej: 0.0950
    IdTipoMovimiento INT FOREIGN KEY REFERENCES TipoMovimiento(Id)
);

-- Error: Catálogo de errores específicos del sistema.
CREATE TABLE Error (
    Codigo INT PRIMARY KEY, -- El XML usa "Codigo" como PK directa
    Descripcion VARCHAR(255) NOT NULL
);



------------------- 2 Entidades

-- Tipo: 1=Administrador, 2=Empleado.
CREATE TABLE Usuario (
    Id INT PRIMARY KEY, 
    Username VARCHAR(50) NOT NULL UNIQUE, 
    PasswordHash VARCHAR(100) NOT NULL,
    Tipo INT NOT NULL CHECK (Tipo IN (1, 2)) 
);


CREATE TABLE Empleado (
    Id INT IDENTITY(1,1) PRIMARY KEY, 
    IdPuesto INT FOREIGN KEY REFERENCES Puesto(Id) NOT NULL, 
    ValorDocumentoIdentidad VARCHAR(50) NOT NULL UNIQUE, 
    Nombre VARCHAR(100) NOT NULL,
    FechaContratacion DATE NOT NULL,
    SaldoVacaciones DECIMAL(10,2) DEFAULT 0.00,
    EsActivo BIT DEFAULT 1 NOT NULL,
    IdUsuario INT FOREIGN KEY REFERENCES Usuario(Id) NULL 
);



----------------------- 3 Tablas tiempo


CREATE TABLE MesPlanilla (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    FechaInicio DATE NOT NULL,
    FechaFin DATE NOT NULL,
    EsCerrado BIT DEFAULT 0 NOT NULL
);


CREATE TABLE SemanaPlanilla (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdMesPlanilla INT FOREIGN KEY REFERENCES MesPlanilla(Id) NOT NULL,
    FechaInicio DATE NOT NULL,
    FechaFin DATE NOT NULL,
    CantidadJuevesMes INT NOT NULL, -- Útil para saber si se divide la deducción fija entre 4 o 5
    EsCerrado BIT DEFAULT 0 NOT NULL
);


----------------------- 4 Asistencia y planificación turnos
CREATE TABLE CalendarioJornadaEmpleado (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdEmpleado INT FOREIGN KEY REFERENCES Empleado(Id) NOT NULL,
    IdSemanaPlanilla INT FOREIGN KEY REFERENCES SemanaPlanilla(Id) NOT NULL,
    IdTipoJornada INT FOREIGN KEY REFERENCES TipoJornada(Id) NOT NULL,
    UNIQUE (IdEmpleado, IdSemanaPlanilla) -- Un turno por semana por empleado
);


CREATE TABLE Asistencia (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdEmpleado INT FOREIGN KEY REFERENCES Empleado(Id) NOT NULL,
    IdSemanaPlanilla INT FOREIGN KEY REFERENCES SemanaPlanilla(Id) NOT NULL,
    Fecha DATE NOT NULL,
    HoraEntrada DATETIME NOT NULL,
    HoraSalida DATETIME NULL -- Puede quedar null temporalmente si solo marca entrada
);


--------------- 5 Deducciones



CREATE TABLE DeduccionXEmpleado (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdEmpleado INT FOREIGN KEY REFERENCES Empleado(Id) NOT NULL,
    IdTipoDeduccion INT FOREIGN KEY REFERENCES TipoDeduccion(Id) NOT NULL,
    PorcentajeOMonto DECIMAL(10,2) NOT NULL, -- Aquí va el factor custom del XML (ej: pensión alimenticia)
    EsActiva BIT DEFAULT 1 NOT NULL,
    UNIQUE(IdEmpleado, IdTipoDeduccion)
);


------------------ 6 Transacciones y acumulados

CREATE TABLE Movimiento (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdEmpleado INT FOREIGN KEY REFERENCES Empleado(Id) NOT NULL,
    IdTipoMovement INT FOREIGN KEY REFERENCES TipoMovimiento(Id) NOT NULL, 
    IdSemanaPlanilla INT FOREIGN KEY REFERENCES SemanaPlanilla(Id) NOT NULL, -- Enlace clave al tiempo
    Fecha DATETIME DEFAULT GETDATE() NOT NULL,
    Monto DECIMAL(10,2) NOT NULL,
    NuevoSaldo DECIMAL(10,2) NOT NULL, -- Saldo acumulado semanal/vacacional del empleado
    IdPostByUser INT FOREIGN KEY REFERENCES Usuario(Id) NOT NULL,
    PostInIP VARCHAR(50) NOT NULL,
    PostTime DATETIME DEFAULT GETDATE() NOT NULL
);


CREATE TABLE PlanillaSemXEmpleado (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdEmpleado INT FOREIGN KEY REFERENCES Empleado(Id) NOT NULL,
    IdSemanaPlanilla INT FOREIGN KEY REFERENCES SemanaPlanilla(Id) NOT NULL,
    SalarioBruto DECIMAL(10,2) DEFAULT 0.00 NOT NULL,
    TotalDeducciones DECIMAL(10,2) DEFAULT 0.00 NOT NULL,
    SalarioNeto DECIMAL(10,2) DEFAULT 0.00 NOT NULL,
    HorasOrdinarias INT DEFAULT 0 NOT NULL,
    HorasExtrasNormales INT DEFAULT 0 NOT NULL,
    HorasExtrasDobles INT DEFAULT 0 NOT NULL,
    UNIQUE (IdEmpleado, IdSemanaPlanilla)
);
ALTER TABLE PlanillaSemXEmpleado
ADD IdTipoJornada INT
CREATE TABLE PlanillaMesXEmpleado (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdEmpleado INT FOREIGN KEY REFERENCES Empleado(Id) NOT NULL,
    IdMesPlanilla INT FOREIGN KEY REFERENCES MesPlanilla(Id) NOT NULL,
    SalarioBrutoMensual DECIMAL(10,2) DEFAULT 0.00 NOT NULL,
    DeduccionesMensuales DECIMAL(10,2) DEFAULT 0.00 NOT NULL,
    SalarioNetoMensual DECIMAL(10,2) DEFAULT 0.00 NOT NULL,
    UNIQUE (IdEmpleado, IdMesPlanilla)
);


CREATE TABLE DeduccionesXEmpleadoXMes (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdEmpleado INT FOREIGN KEY REFERENCES Empleado(Id) NOT NULL,
    IdMesPlanilla INT FOREIGN KEY REFERENCES MesPlanilla(Id) NOT NULL,
    IdTipoDeduccion INT FOREIGN KEY REFERENCES TipoDeduccion(Id) NOT NULL,
    MontoAcumulado DECIMAL(10,2) DEFAULT 0.00 NOT NULL,
    UNIQUE (IdEmpleado, IdMesPlanilla, IdTipoDeduccion)
);
ALTER TABLE dbo.DeduccionSemanalXEmpleado ADD IdTipoDeduccion INT NULL


--------------- 7 Auditoría y errores

-- Bitácora de eventos con soporte para JSON en la descripción como pide el R07
CREATE TABLE BitacoraEvento (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    idTipoEvento INT FOREIGN KEY REFERENCES TipoEvento(Id) NOT NULL, 
    Descripcion VARCHAR(MAX) NOT NULL, -- Aquí se guardará el string estructurado en JSON (Campos antes/después, parámetros)
    IdPostByUser INT FOREIGN KEY REFERENCES Usuario(Id) NOT NULL,
    PostInIP VARCHAR(50) NOT NULL,
    PostTime DATETIME DEFAULT GETDATE() NOT NULL
);


CREATE TABLE DBError (
    ID INT IDENTITY(1,1) PRIMARY KEY, 
    UserName VARCHAR(100) NULL, 
    Number INT NOT NULL, 
    State INT NOT NULL, 
    Severity INT NOT NULL, 
    Line INT NOT NULL, 
    [Procedure] VARCHAR(100) NOT NULL, 
    Message VARCHAR(MAX) NOT NULL, 
    DateTime DATETIME DEFAULT GETDATE() NOT NULL
);
USE Proyecto03BDD


SELECT * FROM BitacoraEvento




CREATE TABLE dbo.DeduccionSemanalXEmpleado (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdEmpleado INT NOT NULL,
    IdSemanaPlanilla INT NOT NULL,
    Detalle VARCHAR(250) NOT NULL,
    Monto DECIMAL(12,2) NOT NULL,
    
    -- Restricciones de Llaves Foráneas para mantener la integridad relacional
    CONSTRAINT FK_DeduccionSemanal_Empleado FOREIGN KEY (IdEmpleado) 
        REFERENCES dbo.Empleado(Id),
    CONSTRAINT FK_DeduccionSemanal_SemanaPlanilla FOREIGN KEY (IdSemanaPlanilla) 
        REFERENCES dbo.SemanaPlanilla(Id)
);
GO
