
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
------------------- INSERCIÓN DE USUARIOS EMPLEADO-------------------------
ALTER TABLE Empleado
ADD CuentaBancaria VARCHAR(256)
USE Proyecto03BDD

INSERT INTO Usuario (Id,Username, PasswordHash, Tipo) 
    VALUES (10,'Mencar', 'Gojira', 2);
    
    INSERT INTO Empleado (ValorDocumentoIdentidad, Nombre, IdPuesto, CuentaBancaria, IdUsuario, FechaContratacion)
    VALUES ('110011001', 'Carlos Mendoza', (SELECT Id FROM Puesto WHERE Nombre = 'Electricista'), 'CR2415115201001026284066', SCOPE_IDENTITY(), '2026-03-06');

    -- Empleado 2: Ana Rodriguez
    INSERT INTO Usuario (Id, Username, PasswordHash, Tipo) 
    VALUES (20,'Rodrigo', 'Seguridad', 2);
    SELECT * FROM Empleado
    SELECT * From Usuario
    USE Proyecto03BDD
    INSERT INTO Empleado (ValorDocumentoIdentidad, Nombre, IdPuesto, CuentaBancaria, IdUsuario, FechaContratacion)
    VALUES ('30582792', 'Rodriguez', (SELECT Id FROM Puesto WHERE Nombre = 'Cajero'), 'CR2415115201901026284067', 20, '2026-03-06');

    -- Empleado 3: Nicolas Vargas
    INSERT INTO Usuario (Id, Username, PasswordHash, Tipo) 
    VALUES (12,'Varnic', 'EndgamE', 2);
    
    INSERT INTO Empleado (ValorDocumentoIdentidad, Nombre, IdPuesto, CuentaBancaria, IdUsuario, FechaContratacion)
    VALUES ('194739285', 'Nicolas Vargas', (SELECT Id FROM Puesto WHERE Nombre = 'Conductor'), 'CR2415115201901026392748', SCOPE_IDENTITY(), '2026-03-06');

    -- Empleado 4: Laura Castro
    INSERT INTO Usuario (Id, Username, PasswordHash, Tipo) 
    VALUES (13,'Caslaur', 'Laura123', 2);
    
    INSERT INTO Empleado (ValorDocumentoIdentidad, Nombre, IdPuesto, CuentaBancaria, IdUsuario, FechaContratacion)
    VALUES ('222333444', 'Laura Castro', (SELECT Id FROM Puesto WHERE Nombre = 'Recepcionista'), 'CR2415115201901026111001', SCOPE_IDENTITY(), '2026-03-06');

    -- Empleado 5: Pedro Arias
    INSERT INTO Usuario (Id, Username, PasswordHash, Tipo) 
    VALUES (14,'Ariped', 'Pedro456', 2);
    
    INSERT INTO Empleado (ValorDocumentoIdentidad, Nombre, IdPuesto, CuentaBancaria, IdUsuario, FechaContratacion)
    VALUES ('333444555', 'Pedro Arias', (SELECT Id FROM Puesto WHERE Nombre = 'Fontanero'), 'CR2415115201901026111002', SCOPE_IDENTITY(), '2026-03-06');

    SELECT * FROM Empleado
    -- ============================================================================
    -- 2. ASOCIAR EMPLEADOS CON DEDUCCIONES
    -- ============================================================================
    SELECT * FROM DeduccionXEmpleado
    -- Carlos Mendoza - Ahorro Asociacion Solidarista
    INSERT INTO DeduccionXEmpleado (IdEmpleado, IdTipoDeduccion, PorcentajeOMonto)
    VALUES ((SELECT Id FROM Empleado WHERE ValorDocumentoIdentidad = '110011001'), (SELECT Id FROM TipoDeduccion WHERE Nombre = 'Ahorro Asociacion Solidarista'), 0.00);

    -- Nicolas Vargas - Pension Alimenticia
    INSERT INTO DeduccionXEmpleado (IdEmpleado, IdTipoDeduccion, PorcentajeOMonto)
    VALUES ((SELECT Id FROM Empleado WHERE ValorDocumentoIdentidad = '194739285'), (SELECT Id FROM TipoDeduccion WHERE Nombre = 'Pension Alimenticia'), 50000.00);

    -- Laura Castro - Ahorro Vacacional
    INSERT INTO DeduccionXEmpleado (IdEmpleado, IdTipoDeduccion, PorcentajeOMonto)
    VALUES ((SELECT Id FROM Empleado WHERE ValorDocumentoIdentidad = '222333444'), (SELECT Id FROM TipoDeduccion WHERE Nombre = 'Ahorro Vacacional'), 20000.00);

    -- Pedro Arias - Ahorro Asociacion Solidarista
    INSERT INTO DeduccionXEmpleado (IdEmpleado, IdTipoDeduccion, PorcentajeOMonto)
    VALUES ((SELECT Id FROM Empleado WHERE ValorDocumentoIdentidad = '333444555'), (SELECT Id FROM TipoDeduccion WHERE Nombre = 'Ahorro Asociacion Solidarista'), 0.00);


    -- ============================================================================
    -- 3. ASIGNAR JORNADAS SEMANALES
    -- ============================================================================

    -- Carlos Mendoza - Diurno
    INSERT INTO JornadaXEmpleado (IdEmpleado, IdTipoJornada, FechaInicioSemana)
    VALUES ((SELECT Id FROM Empleado WHERE ValorDocumentoIdentidad = '110011001'), (SELECT Id FROM TipoJornada WHERE Nombre = 'Diurno'), '2026-03-06');

    -- Ana Rodriguez - Vespertino
    INSERT INTO JornadaXEmpleado (IdEmpleado, IdTipoJornada, FechaInicioSemana)
    VALUES ((SELECT Id FROM Empleado WHERE ValorDocumentoIdentidad = '305827920'), (SELECT Id FROM TipoJornada WHERE Nombre = 'Vespertino'), '2026-03-06');

    -- Nicolas Vargas - Nocturno
    INSERT INTO JornadaXEmpleado (IdEmpleado, IdTipoJornada, FechaInicioSemana)
    VALUES ((SELECT Id FROM Empleado WHERE ValorDocumentoIdentidad = '194739285'), (SELECT Id FROM TipoJornada WHERE Nombre = 'Nocturno'), '2026-03-06');

    -- Laura Castro - Diurno
    INSERT INTO JornadaXEmpleado (IdEmpleado, IdTipoJornada, FechaInicioSemana)
    VALUES ((SELECT Id FROM Empleado WHERE ValorDocumentoIdentidad = '222333444'), (SELECT Id FROM TipoJornada WHERE Nombre = 'Diurno'), '2026-03-06');

    -- Pedro Arias - Vespertino
    INSERT INTO JornadaXEmpleado (IdEmpleado, IdTipoJornada, FechaInicioSemana)
    VALUES ((SELECT Id FROM Empleado WHERE ValorDocumentoIdentidad = '333444555'), (SELECT Id FROM TipoJornada WHERE Nombre = 'Vespertino'), '2026-03-06');


    INSERT INTO PlanillaSemXEmpleado (IdEmpleado, IdSemanaPlanilla, IdTipoJornada, SalarioBruto, TotalDeducciones, SalarioNeto, HorasOrdinarias, HorasExtrasNormales, HorasExtrasDobles)
    VALUES (
        (SELECT Id FROM Empleado WHERE ValorDocumentoIdentidad = '110011001'), 
        (SELECT Id FROM SemanaPlanilla WHERE '2026-03-06' BETWEEN FechaInicio AND FechaFin),
        (SELECT Id FROM TipoJornada WHERE Nombre = 'Diurno'),
        0, 0, 0, 0, 0, 0 -- Inician en cero, luego se actualizan con las asistencias
    );

    -- Ana Rodriguez - Vespertino
    INSERT INTO PlanillaSemXEmpleado (IdEmpleado, IdSemanaPlanilla, IdTipoJornada, SalarioBruto, TotalDeducciones, SalarioNeto, HorasOrdinarias, HorasExtrasNormales, HorasExtrasDobles)
    VALUES (
        (SELECT Id FROM Empleado WHERE ValorDocumentoIdentidad = '305827920'), 
        (SELECT Id FROM SemanaPlanilla WHERE '2026-03-06' BETWEEN FechaInicio AND FechaFin),
        (SELECT Id FROM TipoJornada WHERE Nombre = 'Vespertino'),
        0, 0, 0, 0, 0, 0
    );

    -- Nicolas Vargas - Nocturno
    INSERT INTO PlanillaSemXEmpleado (IdEmpleado, IdSemanaPlanilla, IdTipoJornada, SalarioBruto, TotalDeducciones, SalarioNeto, HorasOrdinarias, HorasExtrasNormales, HorasExtrasDobles)
    VALUES (
        (SELECT Id FROM Empleado WHERE ValorDocumentoIdentidad = '194739285'), 
        (SELECT Id FROM SemanaPlanilla WHERE '2026-03-06' BETWEEN FechaInicio AND FechaFin),
        (SELECT Id FROM TipoJornada WHERE Nombre = 'Nocturno'),
        0, 0, 0, 0, 0, 0
    );

    -- Laura Castro - Diurno
    INSERT INTO PlanillaSemXEmpleado (IdEmpleado, IdSemanaPlanilla, IdTipoJornada, SalarioBruto, TotalDeducciones, SalarioNeto, HorasOrdinarias, HorasExtrasNormales, HorasExtrasDobles)
    VALUES (
        (SELECT Id FROM Empleado WHERE ValorDocumentoIdentidad = '222333444'), 
        (SELECT Id FROM SemanaPlanilla WHERE '2026-03-06' BETWEEN FechaInicio AND FechaFin),
        (SELECT Id FROM TipoJornada WHERE Nombre = 'Diurno'),
        0, 0, 0, 0, 0, 0
    );

    -- Pedro Arias - Vespertino
    INSERT INTO PlanillaSemXEmpleado (IdEmpleado, IdSemanaPlanilla, IdTipoJornada, SalarioBruto, TotalDeducciones, SalarioNeto, HorasOrdinarias, HorasExtrasNormales, HorasExtrasDobles)
    VALUES (
        (SELECT Id FROM Empleado WHERE ValorDocumentoIdentidad = '333444555'), 
        (SELECT Id FROM SemanaPlanilla WHERE '2026-03-06' BETWEEN FechaInicio AND FechaFin),
        (SELECT Id FROM TipoJornada WHERE Nombre = 'Vespertino'),
        0, 0, 0, 0, 0, 0
    );

SELECT * FROM SemanaPlanilla

INSERT INTO SemanaPlanilla (FechaInicio, FechaFin)
    VALUES ('2026-03-06', '2026-03-12');