ALTER PROCEDURE sp_CargarTodoXML
    @inXmlData XML
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        --- PUESTOS
        INSERT INTO Puesto (Nombre, SalarioxHora)
        SELECT 
            T.Node.value('@Nombre', 'VARCHAR(100)'),
            T.Node.value('@SalarioXHora', 'DECIMAL(10,2)')
        FROM @inXmlData.nodes('/Datos/Puestos/Puesto') AS T(Node)
        WHERE T.Node.value('@Nombre', 'VARCHAR(100)') NOT IN (SELECT Nombre FROM Puesto);

        --- TIPOS DE JORNADA
        INSERT INTO TipoJornada (Id, Nombre, HoraInicio, HoraFin)
        SELECT 
            T.Node.value('@Id', 'INT'),
            T.Node.value('@Nombre', 'VARCHAR(50)'),
            T.Node.value('@HoraInicio', 'TIME'),
            T.Node.value('@HoraFin', 'TIME')
        FROM @inXmlData.nodes('/Datos/TiposJornada/TipoJornada') AS T(Node)
        WHERE T.Node.value('@Id', 'INT') NOT IN (SELECT Id FROM TipoJornada);

        --- FERIADOS

        INSERT INTO Feriado (Id, Nombre, Fecha)
        SELECT 
            T.Node.value('@Id', 'INT'),
            T.Node.value('@Nombre', 'VARCHAR(100)'),
            T.Node.value('@Fecha', 'DATE')
        FROM @inXmlData.nodes('/Datos/Feriados/Feriado') AS T(Node)
        WHERE T.Node.value('@Id', 'INT') NOT IN (SELECT Id FROM Feriado);

        --- TIPOS DE EVENTO
        INSERT INTO TipoEvento (Id, Nombre)
        SELECT 
            T.Node.value('@Id', 'INT'),
            T.Node.value('@Nombre', 'VARCHAR(100)')
        FROM @inXmlData.nodes('/Datos/TiposEvento/TipoEvento') AS T(Node)
        WHERE T.Node.value('@Id', 'INT') NOT IN (SELECT Id FROM TipoEvento);

        -- TIPOS DE MOVIMIENTO
        INSERT INTO TipoMovimiento (Id, Nombre, Accion)
        SELECT 
            T.Node.value('@Id', 'INT'),
            T.Node.value('@Nombre', 'VARCHAR(100)'),
            T.Node.value('@Accion', 'CHAR(1)')
        FROM @inXmlData.nodes('/Datos/TiposMovimiento/TipoMovimiento') AS T(Node)
        WHERE T.Node.value('@Id', 'INT') NOT IN (SELECT Id FROM TipoMovimiento); -- <-- CORREGIDO AQU�

        
        --- TIPOS DE DEDUCCI�N
        INSERT INTO TipoDeduccion (Id, Nombre, EsObligatoria, EsPorcentual, Valor, IdTipoMovimiento)
        SELECT 
            T.Node.value('@Id', 'INT'),
            T.Node.value('@Nombre', 'VARCHAR(100)'),
            T.Node.value('@EsObligatoria', 'BIT'),
            T.Node.value('@EsPorcentual', 'BIT'),
            T.Node.value('@Valor', 'DECIMAL(5,4)'),
            (SELECT Id FROM TipoMovimiento WHERE Nombre = T.Node.value('@TipoMovimiento', 'VARCHAR(100)'))
        FROM @inXmlData.nodes('/Datos/TiposDeduccion/TipoDeduccion') AS T(Node)
        WHERE T.Node.value('@Id', 'INT') NOT IN (SELECT Id FROM TipoDeduccion);

        --- USUARIOS
        INSERT INTO Usuario (Id, Username, PasswordHash, Tipo)
        SELECT 
            T.Node.value('@Id', 'INT'),
            T.Node.value('@Username', 'VARCHAR(50)'),
            T.Node.value('@PasswordHash', 'VARCHAR(100)'),
            T.Node.value('@Tipo', 'INT')
        FROM @inXmlData.nodes('/Datos/Usuarios/Usuario') AS T(Node)
        WHERE T.Node.value('@Id', 'INT') NOT IN (SELECT Id FROM Usuario);

        --- ERRORES
        INSERT INTO Error (Codigo, Descripcion)
        SELECT 
            T.Node.value('@Codigo', 'INT'),
            T.Node.value('@Descripcion', 'VARCHAR(255)')
        FROM @inXmlData.nodes('/Datos/Error/error') AS T(Node)
        WHERE T.Node.value('@Codigo', 'INT') NOT IN (SELECT Codigo FROM Error);

        COMMIT TRANSACTION;

        SELECT 1 AS Codigo, 'Carga masiva de cat�logos ejecutada con �xito' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        INSERT INTO DBError (UserName, Number, State, Severity, Line, [Procedure], Message)
        VALUES (
            SUSER_SNAME(),
            ERROR_NUMBER(),
            ERROR_STATE(),
            ERROR_SEVERITY(),
            ERROR_LINE(),
            OBJECT_NAME(@@PROCID),
            ERROR_MESSAGE()
        );

        SELECT -1 AS Codigo, 'Error interno al procesar el XML: ' + ERROR_MESSAGE() AS Mensaje;
    END CATCH
END;



ALTER PROCEDURE sp_ValidarLogin
    @inUsername VARCHAR(50),
    @inPassword VARCHAR(50),
    @inIP VARCHAR(50),
    @outCodigo INT OUTPUT,
    @outMensaje VARCHAR(100) OUTPUT,
    @outIdUsuario INT OUTPUT,
    @outRol INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    --- Variables para la inserci�n
    DECLARE @TipoEvento INT;
    SET @outIdUsuario = NULL;
    DECLARE @MensajeBitacora VARCHAR(128)
    
    ---- Validar username
    IF NOT EXISTS (SELECT 1 FROM dbo.Usuario U WHERE @inUsername = U.Username)
    BEGIN
        SELECT @outCodigo = Codigo, @outMensaje = Descripcion 
        FROM dbo.Error WHERE Codigo = 50001; 
        SET @TipoEvento = 2
        SET @MensajeBitacora = 'Login No Exitoso'
    END

    ELSE
    BEGIN
    -- Validar Contrase�a
        IF NOT EXISTS (SELECT 1 FROM dbo.Usuario U WHERE U.PasswordHash = @inPassword AND U.Username = @inUsername)
        BEGIN 
            SELECT @outCodigo = Codigo, @outMensaje = Descripcion 
            FROM dbo.Error WHERE Codigo = 50002; 
            SET @TipoEvento = 2
            SET @MensajeBitacora = 'Login No Exitoso'
        END
        ELSE
        BEGIN

        SELECT @outIdUsuario = Id FROM dbo.Usuario U
        WHERE U.Username = @inUsername AND U.PasswordHash = @inPassword;


        IF @outIdUsuario IS NOT NULL -- Si hay usuario
        BEGIN
            SET @TipoEvento = 1
            SET @MensajeBitacora = 'Login Exitoso'
            SET @outCodigo = 0; SET @outMensaje = '�xito';
            SELECT @outRol = Tipo FROM dbo.Usuario U 
            WHERE U.Username = @inUsername
        END
      END
    END
    

    --- Bloque de inserci�n
    INSERT INTO dbo.BitacoraEvento (idTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
    VALUES (@TipoEvento, @MensajeBitacora +' : ' + @inUsername, 1, @inIP, GETDATE() AT TIME ZONE 'UTC' AT TIME ZONE 'Central America Standard Time')
END;

EXEC sp_ValidarLogin 'admin', 'admin123', 'ipprueba'
SELECT * FROM dbo.BitacoraEvento



CREATE PROCEDURE sp_RegistrarLogout
    @inIdUsuario INT,
    @inIP VARCHAR(50),
    @outCodigo INT OUTPUT,
    @outMensaje VARCHAR(100) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.BitacoraEvento (IdTipoEvento, IdPostByUser, PostInIP, PostTime, Descripcion)
    VALUES (4, @inIdUsuario, @inIP, GETDATE() AT TIME ZONE 'UTC' AT TIME ZONE 'Central America Standard Time', 'Cierre de sesi�n');
    
    SET @outCodigo = 0;
    SET @outMensaje = 'Logout registrado';
END;

SELECT * FROM dbo.BitacoraEvento




CREATE PROCEDURE sp_ListarEmpleados
    @inFiltro VARCHAR(100),
    @inIdPostByUser INT,
    @inIP VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @HayFiltro INT
    -- Sin filtro (retorna todo)
    IF @inFiltro IS NULL OR @inFiltro = ''
    BEGIN
        SELECT 
            E.Id, 
            E.Nombre, 
            E.ValorDocumentoIdentidad, 
            P.Nombre AS NombrePuesto, 
            E.SaldoVacaciones
        FROM dbo.Empleado E
        INNER JOIN dbo.Puesto P ON E.IdPuesto = P.Id
        WHERE E.EsActivo = 1
        ORDER BY E.Nombre ASC;
    END


    -- solo n�meros (c�dula)
    ELSE IF @inFiltro NOT LIKE '%[^0-9]%'
    BEGIN
        SELECT 
            E.Id, 
            E.Nombre, 
            E.ValorDocumentoIdentidad, 
            P.Nombre AS NombrePuesto, 
            E.SaldoVacaciones
        FROM dbo.Empleado E
        INNER JOIN dbo.Puesto P ON E.IdPuesto = P.Id
        WHERE E.ValorDocumentoIdentidad LIKE '%' + @inFiltro + '%'
          AND E.EsActivo = 1
        ORDER BY E.Nombre ASC;
        SET @HayFiltro = 1
            
    END


    --letras (por Nombre)
    ELSE
    BEGIN
        SELECT 
            E.Id, 
            E.Nombre, 
            E.ValorDocumentoIdentidad, 
            P.Nombre AS NombrePuesto, 
            E.SaldoVacaciones
        FROM dbo.Empleado E
        INNER JOIN dbo.Puesto P ON E.IdPuesto = P.Id
        WHERE E.Nombre LIKE '%' + @inFiltro + '%'
          AND E.EsActivo = 1
        ORDER BY E.Nombre ASC;

        SET @HayFiltro = 1
    END

    IF @HayFiltro = 1 -- Hubo filtro: inserci�n en bit�cora
    BEGIN
            INSERT INTO dbo.BitacoraEvento (idTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
            VALUES (11, 'Consulta con el filtro "'+ @inFiltro +'"',@inIdPostByUser, @inIP, GETDATE() AT TIME ZONE 'UTC' AT TIME ZONE 'Central America Standard Time');
    END
END;



CREATE PROCEDURE sp_GetPlanillasSemanales
    @inIdEmpleado INT,
    @inLimite INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@inLimite)
        P.Id AS IdPlanillaSemanal,
        P.IdSemanaPlanilla,
        -- Pegamos la fecha de inicio y fin para que se vea lindo: "18/05/2026 al 24/05/2026"
        CONVERT(VARCHAR, S.FechaInicio, 103) + ' al ' + CONVERT(VARCHAR, S.FechaFin, 103) AS Periodo,
        P.SalarioBruto,     -- <-- Esto ser� clickeable en tu pantalla
        P.TotalDeducciones, -- <-- Esto tambi�n ser� clickeable
        P.SalarioNeto,
        P.HorasOrdinarias,
        P.HorasExtrasNormales,
        P.HorasExtrasDobles
    FROM PlanillaSemXEmpleado P
    INNER JOIN SemanaPlanilla S ON P.IdSemanaPlanilla = S.Id
    WHERE P.IdEmpleado = @inIdEmpleado
    ORDER BY S.FechaInicio DESC; 








CREATE OR ALTER TRIGGER TR_Empleado_AsignarDeduccionesObligatorias
ON Empleado
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Insertar en DeduccionXEmpleado las deducciones obligatorias de ley (10.67%)
    -- Se mapea dinámicamente con las deducciones marcadas como obligatorias en el catálogo
    INSERT INTO DeduccionXEmpleado (IdEmpleado, IdTipoDeduccion, PorcentajeOMonto, EsActiva)
    SELECT 
        i.Id, 
        td.Id, 
        td.Valor * 100, -- Alombrado según el requerimiento (o td.Valor * 100 si se prefiere del catálogo)
        1
    FROM inserted i
    CROSS JOIN TipoDeduccion td
    WHERE td.EsObligatoria = 1;
END;

SELECT * FROM PlanillaSemXEmpleado

SELECT * FROM Usuario
SELECT * FROM Empleado
CREATE PROCEDURE sp_AgregarEmpleado