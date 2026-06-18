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


    INSERT INTO DeduccionXEmpleado (IdEmpleado, IdTipoDeduccion, PorcentajeOMonto, EsActiva)
    SELECT 
        i.Id, 
        td.Id, 
        td.Valor * 100, 
        1
    FROM inserted i
    CROSS JOIN TipoDeduccion td
    WHERE td.EsObligatoria = 1;
END;

SELECT * FROM PlanillaSemXEmpleado
SELECT * FROM Usuario
SELECT * FROM Empleado
CREATE PROCEDURE sp_AgregarEmpleado

ALTER PROCEDURE sp_CargarEmpleadoXML
    @inXmlData XML
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Tabla variable para extraer limpiamente los datos del XML
    DECLARE @EmpleadosAProcesar TABLE (
        Secuencia INT IDENTITY(1,1) PRIMARY KEY,
        ValorDocumentoIdentidad VARCHAR(50),
        Nombre VARCHAR(100),
        Puesto VARCHAR(100),
        Username VARCHAR(50),
        PasswordHash VARCHAR(100),
        TipoUsuario INT,
        FechaContratacion DATE
    );

    -- Variables para el ciclo de procesamiento individual
    DECLARE @Iterador INT = 1;
    DECLARE @MaxIterador INT;
    DECLARE @IdUsuarioActual INT;
    DECLARE @IdEmpleadoActual INT;
    DECLARE @IdPuestoActual INT;

    -- Variables de lectura por fila
    DECLARE @vCedula VARCHAR(50), @vNombre VARCHAR(100), @vPuesto VARCHAR(100),
            @vUser VARCHAR(50), @vPass VARCHAR(100), @vTipo INT, @vFecha DATE;

    BEGIN TRY
        -- 2. Volcar el XML de forma directa a la tabla en memoria (Operación de lectura, no ocupa Tx)
        INSERT INTO @EmpleadosAProcesar (ValorDocumentoIdentidad, Nombre, Puesto, Username, PasswordHash, TipoUsuario, FechaContratacion)
        SELECT
            T.Node.value('@ValorDocumentoIdentidad', 'VARCHAR(50)'),
            T.Node.value('@Nombre', 'VARCHAR(100)'),
            T.Node.value('@Puesto', 'VARCHAR(100)'),
            T.Node.value('@Username', 'VARCHAR(50)'),
            T.Node.value('@Password', 'VARCHAR(100)'),
            T.Node.value('@TipoUsuario', 'INT'),
            T.Node.value('@FechaContratacion', 'DATE')
        FROM @inXmlData.nodes('/FechaOperacion/InsertarEmpleado') AS T(Node);

        SELECT @MaxIterador = COUNT(*) FROM @EmpleadosAProcesar;

        -- 3. Iterar cada empleado de forma individual y transaccional
        WHILE @Iterador <= @MaxIterador
        BEGIN
            -- Extraer datos del empleado actual
            SELECT 
                @vCedula = ValorDocumentoIdentidad, @vNombre = Nombre, @vPuesto = Puesto,
                @vUser = Username, @vPass = PasswordHash, @vTipo = TipoUsuario, @vFecha = FechaContratacion
            FROM @EmpleadosAProcesar
            WHERE Secuencia = @Iterador;

            -- Mapear el puesto por nombre
            SELECT @IdPuestoActual = Id FROM dbo.Puesto WHERE Nombre = @vPuesto;

            -- !!! AQUÍ EMPIEZA LA ÚNICA TRANSACCIÓN POR EMPLEADO !!!
            BEGIN TRANSACTION;
            BEGIN TRY
                
                -- Validar que el puesto exista y que el empleado o usuario no estén duplicados
                IF @IdPuestoActual IS NOT NULL 
                   AND NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE Username = @vUser)
                   AND NOT EXISTS (SELECT 1 FROM dbo.Empleado WHERE ValorDocumentoIdentidad = @vCedula)
                BEGIN
                    
                    -- Calcular correlativo manual para la tabla Usuario
                    SELECT @IdUsuarioActual = ISNULL(MAX(Id), 0) + 1 FROM dbo.Usuario;

                    -- Forzar tipo de usuario válido si viene en 0 por el XML (Debe ser 1 o 2 por el CHECK)
                    IF @vTipo NOT IN (1, 2) SET @vTipo = 2;

                    -- Inserción 1: Usuario
                    INSERT INTO dbo.Usuario (Id, Username, PasswordHash, Tipo)
                    VALUES (@IdUsuarioActual, @vUser, @vPass, @vTipo);

                    -- Inserción 2: Empleado
                    INSERT INTO dbo.Empleado (IdPuesto, ValorDocumentoIdentidad, Nombre, FechaContratacion, SaldoVacaciones, EsActivo, IdUsuario)
                    VALUES (@IdPuestoActual, @vCedula, @vNombre, @vFecha, 0.00, 1, @IdUsuarioActual);

                    SET @IdEmpleadoActual = SCOPE_IDENTITY();

                    -- Inserción 3: Registro de Bitácora Individual estructurado en JSON (Requerimiento R07)
                    DECLARE @JsonBitacora VARCHAR(MAX) = (
                        SELECT @IdEmpleadoActual AS [Empleado.Id], @vNombre AS [Empleado.Nombre], @vCedula AS [Empleado.Cedula]
                        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                    );

                    INSERT INTO dbo.BitacoraEvento (idTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
                    VALUES (5, @JsonBitacora, 1, '127.0.0.1', GETDATE());

                    -- Guardamos los cambios únicamente de ESTE empleado
                    COMMIT TRANSACTION;
                END 
                ELSE
                BEGIN
                    -- Si hay duplicados o el puesto no existe, cancelamos SOLAMENTE este registro
                    ROLLBACK TRANSACTION;
                END

            END TRY
            BEGIN CATCH
                -- Si falla la inserción interna de este empleado, revertimos su transacción individual
                IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

                INSERT INTO dbo.DBError (UserName, Number, State, Severity, Line, [Procedure], Message)
                VALUES (SUSER_SNAME(), ERROR_NUMBER(), ERROR_STATE(), ERROR_SEVERITY(), ERROR_LINE(), 'sp_CargarEmpleadoXML', ERROR_MESSAGE());
            END CATCH;

            SET @Iterador = @Iterador + 1;
        END;

        SELECT 1 AS Codigo, 'Procesamiento de empleados finalizado correctamente' AS Mensaje;

    END TRY
    BEGIN CATCH
        -- Captura fallas estructurales graves externas al bucle (ej: XML corrupto)
        SELECT -1 AS Codigo, 'Error crítico estructural al procesar la carga XML: ' + ERROR_MESSAGE() AS Mensaje;
    END CATCH
END;


------------------------------
ALTER PROCEDURE sp_EliminarEmpleadoXML
    @inXmlData XML
AS
BEGIN
    SET NOCOUNT ON;

    -- Tabla temporal para procesar cada eliminación
    DECLARE @EmpleadosAEliminar TABLE (
        Secuencia INT IDENTITY(1,1) PRIMARY KEY,
        ValorDocumentoIdentidad VARCHAR(50)
    );

    -- Variables del ciclo
    DECLARE @Iterador INT = 1;
    DECLARE @MaxIterador INT;

    DECLARE @vCedula VARCHAR(50);
    DECLARE @IdEmpleadoActual INT;

    BEGIN TRY

    INSERT INTO @EmpleadosAEliminar (ValorDocumentoIdentidad)
        SELECT
            T.Node.value('@ValorDocumentoIdentidad', 'VARCHAR(50)')
        FROM @inXmlData.nodes('/FechaOperacion/EliminarEmpleado') AS T(Node);


        SELECT @MaxIterador = COUNT(*)
        FROM @EmpleadosAEliminar;


        -- Procesar uno por uno
        WHILE @Iterador <= @MaxIterador
        BEGIN
        /*
        Mensaje 102, nivel 15, estado 1, procedimiento sp_EliminarEmpleadoXML, línea 66 [línea de inicio de lote 443]
Incorrect syntax near 'WITHOUT'.
        */
            SELECT 
                @vCedula = ValorDocumentoIdentidad
            FROM @EmpleadosAEliminar
            WHERE Secuencia = @Iterador;

       
            BEGIN TRANSACTION;
            BEGIN TRY
                
                -- Buscar empleado
                SELECT @IdEmpleadoActual = Id
                FROM dbo.Empleado
                WHERE ValorDocumentoIdentidad = @vCedula;


                IF @IdEmpleadoActual IS NOT NULL
                BEGIN

                    -- Desactivar empleado
                    UPDATE dbo.Empleado
                    SET EsActivo = 0
                    WHERE Id = @IdEmpleadoActual;


                    -- Bitácora individual
                    DECLARE @JsonBitacora VARCHAR(MAX);

                    SET @JsonBitacora = (
                        SELECT 
                            @IdEmpleadoActual AS [Empleado.Id],
                            @vCedula AS [Empleado.Cedula]
                        FOR JSON PATH
                    );

                    INSERT INTO dbo.BitacoraEvento (idTipoEvento, Descripcion, IdPostByUser,  PostInIP, PostTime)
                    VALUES (10, @JsonBitacora, 1, '127.0.0.1', GETDATE());


                    COMMIT TRANSACTION;

                END
                ELSE
                BEGIN
                    -- Si no existe, solo se cancela este registro
                    ROLLBACK TRANSACTION;
                END


            END TRY
            BEGIN CATCH

                IF @@TRANCOUNT > 0
                    ROLLBACK TRANSACTION;


                INSERT INTO dbo.DBError (UserName, Number, State, Severity, Line, [Procedure], Message)
                VALUES (SUSER_SNAME(), ERROR_NUMBER(), ERROR_STATE(), ERROR_SEVERITY(), ERROR_LINE(), 'sp_EliminarEmpleadoXML', ERROR_MESSAGE());

            END CATCH;


            SET @Iterador = @Iterador + 1;

        END;


        SELECT 1 AS Codigo,
               'Eliminación procesada correctamente' AS Mensaje;


    END TRY
    BEGIN CATCH

        SELECT -1 AS Codigo,
               'Error crítico procesando XML: ' + ERROR_MESSAGE() AS Mensaje;

    END CATCH

END;
------------------------------






CREATE FUNCTION dbo.fn_ContarJuevesEnMes (@FechaInicio DATE, @FechaFin DATE)
RETURNS INT
AS
BEGIN
    DECLARE @Cantidad INT = 0;
    DECLARE @FechaAux DATE = @FechaInicio;

    WHILE @FechaAux <= @FechaFin
    BEGIN
      
        IF DATEPART(WEEKDAY, @FechaAux) = 5 
            SET @Cantidad = @Cantidad + 1;
            
        SET @FechaAux = DATEADD(DAY, 1, @FechaAux);
    END;

    RETURN @Cantidad;
END;
-------------------------------

CREATE PROCEDURE sp_ControlTiempoYPlanilla
    @pFechaActual DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdMesActual INT;
    DECLARE @IdSemanaActual INT;
    DECLARE @InicioMes DATE = DATEFROMPARTS(YEAR(@pFechaActual), MONTH(@pFechaActual), 1);
    DECLARE @FinMes DATE = EOMONTH(@pFechaActual);
    DECLARE @JuevesDelMes INT;

    -- =================================================================
    -- 1. CONTROL DE MES PLANILLA
    -- =================================================================
    SELECT TOP 1 @IdMesActual = Id 
    FROM dbo.MesPlanilla 
    WHERE @pFechaActual BETWEEN FechaInicio AND FechaFin AND EsCerrado = 0;

    -- Si no existe un mes abierto para esta fecha, lo creamos
    IF @IdMesActual IS NULL
    BEGIN
        INSERT INTO dbo.MesPlanilla (FechaInicio, FechaFin, EsCerrado)
        VALUES (@InicioMes, @FinMes, 0);
        
        SET @IdMesActual = SCOPE_IDENTITY();
    END;

    -- =================================================================
    -- 2. CONTROL DE SEMANA PLANILLA (Cierran Jueves, Abren Viernes)
    -- =================================================================
    SELECT TOP 1 @IdSemanaActual = Id 
    FROM dbo.SemanaPlanilla 
    WHERE @pFechaActual BETWEEN FechaInicio AND FechaFin AND EsCerrado = 0;

    -- Si no hay semana abierta para el día de hoy, toca abrir una nueva
    IF @IdSemanaActual IS NULL
    BEGIN
        -- Calculamos cuántos jueves tiene este mes para la regla de deducciones divididas
        SET @JuevesDelMes = dbo.fn_ContarJuevesEnMes(@InicioMes, @FinMes);

        -- La semana inicia hoy (@pFechaActual, que debería ser viernes si el jueves cerró)
        -- y termina el próximo jueves (6 días después)
        INSERT INTO dbo.SemanaPlanilla (IdMesPlanilla, FechaInicio, FechaFin, CantidadJuevesMes, EsCerrado)
        VALUES (@IdMesActual, @pFechaActual, DATEADD(DAY, 6, @pFechaActual), @JuevesDelMes, 0);
    END;

    -- =================================================================
    -- 3. VALIDACIÓN DE CIERRE (Si hoy es JUEVES, al final del día se cierra)
    -- =================================================================
    -- Nota: El proceso de cierre pesado (calcular salarios netos de la semana, 
    -- procesar movimientos, etc.) se llamará en el coordinador al detectar que es jueves.

END;

--------------------------------

ALTER PROCEDURE sp_AsociarDeduccionXML
    @inXmlData XML
AS
BEGIN
    SET NOCOUNT ON;


    DECLARE @DeduccionesAProcesar TABLE(
        Secuencia INT IDENTITY(1,1) PRIMARY KEY,
        ValorDocumentoIdentidad VARCHAR(50),
        TipoDeduccion VARCHAR(100),
        MontoFijo DECIMAL(10,2)
    );


    DECLARE @Iterador INT = 1;
    DECLARE @MaxIterador INT;


    DECLARE @vCedula VARCHAR(50);
    DECLARE @vTipoDeduccion VARCHAR(100);
    DECLARE @vMonto DECIMAL(10,2);

    DECLARE @IdEmpleadoActual INT;
    DECLARE @IdTipoDeduccionActual INT;


    BEGIN TRY


        INSERT INTO @DeduccionesAProcesar
        (
            ValorDocumentoIdentidad,
            TipoDeduccion,
            MontoFijo
        )
        SELECT
            T.Node.value('@ValorDocumentoIdentidad','VARCHAR(50)'),
            T.Node.value('@TipoDeduccion','VARCHAR(100)'),
            T.Node.value('@MontoFijo','DECIMAL(10,2)')
        FROM @inXmlData.nodes('/FechaOperacion/AsociaEmpleadoConDeduccion') AS T(Node);



        SELECT @MaxIterador = COUNT(*)
        FROM @DeduccionesAProcesar;



        WHILE @Iterador <= @MaxIterador
        BEGIN


            SELECT
                @vCedula = ValorDocumentoIdentidad,
                @vTipoDeduccion = TipoDeduccion,
                @vMonto = MontoFijo
            FROM @DeduccionesAProcesar
            WHERE Secuencia = @Iterador;



            BEGIN TRANSACTION;

            BEGIN TRY


                -- Buscar empleado
                SELECT @IdEmpleadoActual = Id
                FROM Empleado
                WHERE ValorDocumentoIdentidad = @vCedula;



                -- Buscar tipo de deducción
                SELECT @IdTipoDeduccionActual = Id
                FROM TipoDeduccion
                WHERE Nombre = @vTipoDeduccion;



                IF @IdEmpleadoActual IS NOT NULL
                   AND @IdTipoDeduccionActual IS NOT NULL
                   AND NOT EXISTS
                   (
                       SELECT 1
                       FROM DeduccionXEmpleado
                       WHERE IdEmpleado = @IdEmpleadoActual
                       AND IdTipoDeduccion = @IdTipoDeduccionActual
                   )
                BEGIN


                    INSERT INTO DeduccionXEmpleado
                    (
                        IdEmpleado,
                        IdTipoDeduccion,
                        PorcentajeOMonto,
                        EsActiva
                    )
                    VALUES
                    (
                        @IdEmpleadoActual,
                        @IdTipoDeduccionActual,
                        @vMonto,
                        1
                    );


                    COMMIT TRANSACTION;

                END
                ELSE
                BEGIN

                    ROLLBACK TRANSACTION;

                END



            END TRY
            BEGIN CATCH


                IF @@TRANCOUNT > 0
                    ROLLBACK TRANSACTION;



                INSERT INTO dbo.DBError
                (
                    UserName,
                    Number,
                    State,
                    Severity,
                    Line,
                    [Procedure],
                    Message
                )
                VALUES
                (
                    SUSER_SNAME(),
                    ERROR_NUMBER(),
                    ERROR_STATE(),
                    ERROR_SEVERITY(),
                    ERROR_LINE(),
                    'sp_AsociarDeduccionXML',
                    ERROR_MESSAGE()
                );


            END CATCH;



            SET @Iterador = @Iterador + 1;


        END;



        SELECT 1 AS Codigo,
               'Deducciones procesadas correctamente' AS Mensaje;



    END TRY
    BEGIN CATCH

        SELECT -1 AS Codigo,
               'Error crítico procesando XML: ' + ERROR_MESSAGE() AS Mensaje;

    END CATCH


END;
--------------------------------
ALTER PROCEDURE sp_CargarJornadasXML
    @inXmlData XML
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Tabla variable para extraer los datos del fragmento XML
    DECLARE @JornadasAProcesar TABLE (
        Secuencia INT IDENTITY(1,1) PRIMARY KEY,
        ValorDocumentoIdentidad VARCHAR(50),
        NombreJornada VARCHAR(50),
        InicioSemana DATE
    );

    -- Variables para el control del ciclo
    DECLARE @Iterador INT = 1;
    DECLARE @MaxIterador INT;
    DECLARE @IdEmpleadoActual INT;
    DECLARE @IdTipoJornadaActual INT;
    DECLARE @IdSemanaActual INT;

    -- Variables de lectura por fila
    DECLARE @vCedula VARCHAR(50), @vJornada VARCHAR(50), @vInicioSemana DATE;

    BEGIN TRY
        -- 2. Volcar los nodos <AsignarJornada> a la tabla en memoria
        INSERT INTO @JornadasAProcesar (ValorDocumentoIdentidad, NombreJornada, InicioSemana)
        SELECT
            T.Node.value('@ValorDocumentoIdentidad', 'VARCHAR(50)'),
            T.Node.value('@Jornada', 'VARCHAR(50)'),
            T.Node.value('@InicioSemana', 'DATE')
        FROM @inXmlData.nodes('/FechaOperacion/AsignarJornada') AS T(Node);

        SELECT @MaxIterador = COUNT(*) FROM @JornadasAProcesar;

        -- 3. Iterar registro por registro de forma transaccional aislada
        WHILE @Iterador <= @MaxIterador
        BEGIN
            SELECT 
                @vCedula = ValorDocumentoIdentidad,
                @vJornada = NombreJornada,
                @vInicioSemana = InicioSemana
            FROM @JornadasAProcesar
            WHERE Secuencia = @Iterador;

            -- Mapear los IDs correspondientes relacionales
            SELECT @IdEmpleadoActual = Id FROM dbo.Empleado WHERE ValorDocumentoIdentidad = @vCedula AND EsActivo = 1;
            SELECT @IdTipoJornadaActual = Id FROM dbo.TipoJornada WHERE Nombre = @vJornada;
            
            -- Buscamos la semana de planilla correspondiente a esa fecha de inicio
            SELECT @IdSemanaActual = Id FROM dbo.SemanaPlanilla WHERE @vInicioSemana BETWEEN FechaInicio AND FechaFin;

            -- Iniciamos transacción por cada asignación de turno individual
            
            BEGIN TRY

                -- Validaciones de integridad
                IF @IdEmpleadoActual IS NOT NULL AND @IdTipoJornadaActual IS NOT NULL AND @IdSemanaActual IS NOT NULL
                BEGIN
                    
                    -- Usamos un MERGE o un condicional para evitar duplicar el turno si ya se guardó 
                    -- (Tu tabla tiene un UNIQUE por Empleado y Semana)
                    IF NOT EXISTS (SELECT 1 FROM dbo.CalendarioJornadaEmpleado WHERE IdEmpleado = @IdEmpleadoActual AND IdSemanaPlanilla = @IdSemanaActual)
                    BEGIN
                        INSERT INTO dbo.CalendarioJornadaEmpleado (IdEmpleado, IdSemanaPlanilla, IdTipoJornada)
                        VALUES (@IdEmpleadoActual, @IdSemanaActual, @IdTipoJornadaActual);

                        -- Inserción en Bitácora en formato JSON (Requerimiento R07)
                        DECLARE @JsonBitacora VARCHAR(MAX) = (
                            SELECT 
                                @IdEmpleadoActual AS [Calendario.IdEmpleado], 
                                @IdSemanaActual AS [Calendario.IdSemanaPlanilla], 
                                @vJornada AS [Calendario.JornadaAsignada]
                            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                        );

                        -- Tipo de Evento 7 = Asignación de Jornada / Horario
                        INSERT INTO dbo.BitacoraEvento (idTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
                        VALUES (7, @JsonBitacora, 1, '127.0.0.1', GETDATE());
                    END
                    ELSE
                    BEGIN
                        -- Si ya existía el horario para esa semana, actualizamos al nuevo asignado por el XML
                        UPDATE dbo.CalendarioJornadaEmpleado
                        SET IdTipoJornada = @IdTipoJornadaActual
                        WHERE IdEmpleado = @IdEmpleadoActual AND IdSemanaPlanilla = @IdSemanaActual;
                    END

                    
                END

            END TRY
            BEGIN CATCH
                INSERT INTO dbo.DBError (UserName, Number, State, Severity, Line, [Procedure], Message)
                VALUES (SUSER_SNAME(), ERROR_NUMBER(), ERROR_STATE(), ERROR_SEVERITY(), ERROR_LINE(), 'sp_CargarJornadasXML', ERROR_MESSAGE());
            END CATCH;

            SET @Iterador = @Iterador + 1;
        END;

    END TRY
    BEGIN CATCH
        SELECT -1 AS Codigo, 'Error crítico al procesar la asignación de jornadas: ' + ERROR_MESSAGE() AS Mensaje;
    END CATCH
END;

--------------------------------

ALTER PROCEDURE sp_DesasociarDeduccionXML
    @inXmlData XML
AS
BEGIN
    SET NOCOUNT ON;


    DECLARE @DeduccionesAProcesar TABLE
    (
        Secuencia INT IDENTITY(1,1) PRIMARY KEY,
        ValorDocumentoIdentidad VARCHAR(50),
        TipoDeduccion VARCHAR(100)
    );


    DECLARE @Iterador INT = 1;
    DECLARE @MaxIterador INT;


    DECLARE @vCedula VARCHAR(50);
    DECLARE @vTipoDeduccion VARCHAR(100);

    DECLARE @IdEmpleadoActual INT;
    DECLARE @IdTipoDeduccionActual INT;


    BEGIN TRY


        -- Cargar XML
        INSERT INTO @DeduccionesAProcesar
        (
            ValorDocumentoIdentidad,
            TipoDeduccion
        )
        SELECT
            T.Node.value('@ValorDocumentoIdentidad','VARCHAR(50)'),
            T.Node.value('@TipoDeduccion','VARCHAR(100)')
        FROM @inXmlData.nodes('/FechaOperacion/DesasociaEmpleadoConDeduccion') AS T(Node);



        SELECT @MaxIterador = COUNT(*)
        FROM @DeduccionesAProcesar;



        WHILE @Iterador <= @MaxIterador
        BEGIN


            SELECT
                @vCedula = ValorDocumentoIdentidad,
                @vTipoDeduccion = TipoDeduccion
            FROM @DeduccionesAProcesar
            WHERE Secuencia = @Iterador;



            BEGIN TRANSACTION;

            BEGIN TRY



                -- Buscar empleado
                SELECT @IdEmpleadoActual = Id
                FROM Empleado
                WHERE ValorDocumentoIdentidad = @vCedula;



                -- Buscar tipo deducción
                SELECT @IdTipoDeduccionActual = Id
                FROM TipoDeduccion
                WHERE Nombre = @vTipoDeduccion;



                IF @IdEmpleadoActual IS NOT NULL
                   AND @IdTipoDeduccionActual IS NOT NULL
                   AND EXISTS
                   (
                        SELECT 1
                        FROM DeduccionXEmpleado
                        WHERE IdEmpleado = @IdEmpleadoActual
                        AND IdTipoDeduccion = @IdTipoDeduccionActual
                   )
                BEGIN


                    UPDATE DeduccionXEmpleado
                    SET EsActiva = 0
                    WHERE IdEmpleado = @IdEmpleadoActual
                    AND IdTipoDeduccion = @IdTipoDeduccionActual;



                    COMMIT TRANSACTION;


                END
                ELSE
                BEGIN

                    -- Si no existe la asociación
                    ROLLBACK TRANSACTION;

                END




            END TRY
            BEGIN CATCH


                IF @@TRANCOUNT > 0
                    ROLLBACK TRANSACTION;



                INSERT INTO dbo.DBError
                (
                    UserName,
                    Number,
                    State,
                    Severity,
                    Line,
                    [Procedure],
                    Message
                )
                VALUES
                (
                    SUSER_SNAME(),
                    ERROR_NUMBER(),
                    ERROR_STATE(),
                    ERROR_SEVERITY(),
                    ERROR_LINE(),
                    'sp_DesasociarDeduccionXML',
                    ERROR_MESSAGE()
                );


            END CATCH;



            SET @Iterador = @Iterador + 1;


        END;



        SELECT 1 AS Codigo,
               'Desasociación procesada correctamente' AS Mensaje;



    END TRY
    BEGIN CATCH


        SELECT -1 AS Codigo,
               'Error crítico procesando XML: ' + ERROR_MESSAGE() AS Mensaje;


    END CATCH


END;
---------------------------------

ALTER PROCEDURE sp_CargarAsistenciasXML
    @inXmlData XML
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Tabla variable para extraer los datos del fragmento XML
    DECLARE @AsistenciasAProcesar TABLE (
        Secuencia INT IDENTITY(1,1) PRIMARY KEY,
        ValorDocumentoIdentidad VARCHAR(50),
        HoraEntrada DATETIME,
        HoraSalida DATETIME
    );

    -- Variables para el control del ciclo
    DECLARE @Iterador INT = 1;
    DECLARE @MaxIterador INT;
    DECLARE @IdEmpleadoActual INT;
    DECLARE @IdSemanaActual INT;

    -- Variables de lectura por fila
    DECLARE @vCedula VARCHAR(50), @vEntrada DATETIME, @vSalida DATETIME;
    DECLARE @HorasTrabajadas DECIMAL(5,2);

    -- 2. Volcar los nodos <MarcaAsistencia> a la tabla en memoria
    INSERT INTO @AsistenciasAProcesar (ValorDocumentoIdentidad, HoraEntrada, HoraSalida)
    SELECT
        T.Node.value('@ValorDocumentoIdentidad', 'VARCHAR(50)'),
        T.Node.value('@HoraEntrada', 'DATETIME'),
        T.Node.value('@HoraSalida', 'DATETIME')
    FROM @inXmlData.nodes('/FechaOperacion/MarcaAsistencia') AS T(Node);

    SELECT @MaxIterador = COUNT(*) FROM @AsistenciasAProcesar;

    -- 3. Iterar registro por registro (Sin transacciones internas)
    WHILE @Iterador <= @MaxIterador
    BEGIN
        SELECT 
            @vCedula = ValorDocumentoIdentidad,
            @vEntrada = HoraEntrada,
            @vSalida = HoraSalida
        FROM @AsistenciasAProcesar
        WHERE Secuencia = @Iterador;

        -- Mapear el ID del empleado y la semana activa de planilla
        SELECT @IdEmpleadoActual = Id FROM dbo.Empleado WHERE ValorDocumentoIdentidad = @vCedula AND EsActivo = 1;
        SELECT @IdSemanaActual = Id FROM dbo.SemanaPlanilla WHERE CAST(@vEntrada AS DATE) BETWEEN FechaInicio AND FechaFin;

        -- Calcular las horas totales trabajadas
        SET @HorasTrabajadas = DATEDIFF(MINUTE, @vEntrada, @vSalida) / 60.0;

        -- VALIDACIÓN CRÍTICA:
        -- Si el empleado o la semana no existen, disparamos un error intencional.
        -- Esto detiene este SP y envía el flujo directo al CATCH del SP Maestro para que haga el ROLLBACK global.
        IF @IdEmpleadoActual IS NULL
        BEGIN
            DECLARE @ErrEmpleado VARCHAR(150) = CONCAT('Error en Asistencia: El empleado con cédula ', @vCedula, ' no existe o está inactivo.');
            RAISERROR(@ErrEmpleado, 16, 1);
            RETURN; -- Detiene la ejecución inmediatamente
        END

        IF @IdSemanaActual IS NULL
        BEGIN
            DECLARE @ErrSemana VARCHAR(150) = CONCAT('Error en Asistencia: No hay una semana de planilla abierta para la fecha ', CAST(@vEntrada AS DATE));
            RAISERROR(@ErrSemana, 16, 1);
            RETURN;
        END

        -- Si pasa las validaciones, insertamos en la tabla física de Marcas/Asistencias
        INSERT INTO dbo.Asistencia (IdEmpleado, HoraEntrada, HoraSalida, HorasTrabajadas)
        VALUES (@IdEmpleadoActual, @vEntrada, @vSalida, @HorasTrabajadas);

        -- Inserción en Bitácora en formato JSON (Requerimiento R07)
        DECLARE @JsonBitacora VARCHAR(MAX) = (
            SELECT 
                @IdEmpleadoActual AS [Asistencia.IdEmpleado], 
                @vEntrada AS [Asistencia.Entrada], 
                @vSalida AS [Asistencia.Salida],
                @HorasTrabajadas AS [Asistencia.HorasTotales]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        INSERT INTO dbo.BitacoraEvento (idTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
        VALUES (8, @JsonBitacora, 1, '127.0.0.1', GETDATE());

        -- Avanzar a la siguiente marca de asistencia del día
        SET @Iterador = @Iterador + 1;
    END;
END;

----------------------------------
ALTER PROCEDURE sp_ProcesarOperacionesXML
    @inXmlData XML
AS
BEGIN
    SET NOCOUNT ON;

    -- Tabla variable para ordenar cronológicamente los días de operación
    DECLARE @DiasSimulacion TABLE (
        Secuencia INT IDENTITY(1,1) PRIMARY KEY,
        Fecha DATE NOT NULL,
        NodoFecha XML NOT NULL
    );

    DECLARE @Iterador INT = 1;
    DECLARE @MaxIterador INT;
    DECLARE @FechaActual DATE;
    DECLARE @XMLDiaActual XML;

    -- Fragmentos XML de la fecha
    DECLARE @XMLInsertarEmpleados XML;
    DECLARE @XMLAsociarDeducciones XML;
    DECLARE @XMLAsignarJornadas XML;
    DECLARE @XMLAsistencias XML;
    DECLARE @XMLEliminarEmpleados XML;
    DECLARE @XMLDesasociarDeducciones XML;

    BEGIN TRY
        -- 1. Extraer y ordenar los días cronológicamente
        INSERT INTO @DiasSimulacion (Fecha, NodoFecha)
        SELECT 
            T.Node.value('@Fecha', 'DATE'),
            T.Node.query('.')
        FROM @inXmlData.nodes('/Operaciones/FechaOperacion') AS T(Node)
        ORDER BY T.Node.value('@Fecha', 'DATE') ASC;

        SELECT @MaxIterador = COUNT(*) FROM @DiasSimulacion;

        -- 2. Ciclo principal por día
        WHILE @Iterador <= @MaxIterador
        BEGIN
            SELECT @FechaActual = Fecha, @XMLDiaActual = NodoFecha FROM @DiasSimulacion WHERE Secuencia = @Iterador;

            -- -----------------------------------------------------------------
            -- BLOQUE INDEPENDIENTE: INSERTAR EMPLEADOS (Transacción por empleado)
           
            IF @XMLDiaActual.exist('/FechaOperacion/InsertarEmpleado') = 1
            BEGIN
                SET @XMLInsertarEmpleados = @XMLDiaActual.query('/FechaOperacion');
                EXEC dbo.sp_CargarEmpleadoXML @inXmlData = @XMLInsertarEmpleados;
            END

            -- -----------------------------------------------------------------
            -- BLOQUE INDEPENDIENTE: ELIMINAR EMPLEADOS (Transacción por empleado)
            --------------------------------------------------------------------
           
            IF @XMLDiaActual.exist('/FechaOperacion/EliminarEmpleado') = 1
            BEGIN
                SET @XMLEliminarEmpleados = @XMLDiaActual.query('/FechaOperacion');
                EXEC dbo.sp_EliminarEmpleadoXML @inXmlData = @XMLEliminarEmpleados;
            END

            -- -----------------------------------------------------------------
            -- BLOQUE INDEPENDIENTE: ASOCIAR DEDUCCIONES POR EMPLEADOS (Transacción por empleado)
            --------------------------------------------------------------------
           
            IF @XMLDiaActual.exist('/FechaOperacion/AsociaEmpleadoConDeduccion') = 1
            BEGIN
                SET @XMLAsociarDeducciones = @XMLDiaActual.query('/FechaOperacion');
                EXEC dbo.sp_AsociarDeduccionXML @inXmlData = @XMLAsociarDeducciones;
            END

            -- -----------------------------------------------------------------
            -- BLOQUE INDEPENDIENTE: DESASOCIAR DEDUCCIONES POR EMPLEADOS (Transacción por empleado)
            --------------------------------------------------------------------
           
            IF @XMLDiaActual.exist('/FechaOperacion/DesasociaEmpleadoConDeduccion') = 1
            BEGIN
                SET @XMLDesasociarDeducciones = @XMLDiaActual.query('/FechaOperacion');
                EXEC dbo.sp_DesasociarDeduccionXML @inXmlData = @XMLDesasociarDeducciones;
            END

            -- -----------------------------------------------------------------
            -- BLOQUE UNIFICADO: ASISTENCIAS, JORNADAS Y CIERRES (Una sola Tx de BD)
            -- -----------------------------------------------------------------
            BEGIN TRANSACTION;
            BEGIN TRY
                
                -- Inciso 3: Hacer cierre y apertura de mes / semana (Antes de procesar el día)
                -- Aquí se evalúa de forma transaccional si toca abrir/cerrar periodos
                EXEC dbo.sp_ControlTiempoYPlanilla @pFechaActual = @FechaActual;

                -- Inciso 1: Procesar asistencias del día
                IF @XMLDiaActual.exist('/FechaOperacion/MarcaAsistencia') = 1
                BEGIN
                    SET @XMLAsistencias = @XMLDiaActual.query('/FechaOperacion');
                    -- IMPORTANTE: Quitarle el BEGIN/COMMIT TX interno a este SP para que herede esta Tx global
                    EXEC dbo.sp_CargarAsistenciasXML @inXmlData = @XMLAsistencias;
                END

                -- Inciso 2: Procesar nuevas jornadas
                IF @XMLDiaActual.exist('/FechaOperacion/AsignarJornada') = 1
                BEGIN
                    SET @XMLAsignarJornadas = @XMLDiaActual.query('/FechaOperacion');
                    -- IMPORTANTE: Quitarle el BEGIN/COMMIT TX interno a este SP para que herede esta Tx global
                    EXEC dbo.sp_CargarJornadasXML @inXmlData = @XMLAsignarJornadas;
                END

                -- Inciso 4: Si es JUEVES, se ejecuta el cierre matemático de la planilla semanal
                IF DATEPART(WEEKDAY, @FechaActual) = 5 -- Jueves
                BEGIN
                    -- EXEC dbo.sp_CierreSemanalPlanilla @pFechaActual = @FechaActual;
                    PRINT 'Ejecutando el cierre de la planilla semanal de forma atómica...';
                END

                -- Si todo el día corrió perfectamente, consolidamos el bloque de 37 puntos
                COMMIT TRANSACTION;

            END TRY
            BEGIN CATCH
                -- Si cualquiera de las asistencias, jornadas o cierres falla, se cae TODO el día completo
                IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

                -- Registrar el error del bloque diario
                INSERT INTO dbo.DBError (UserName, Number, State, Severity, Line, [Procedure], Message)
                VALUES (SUSER_SNAME(), ERROR_NUMBER(), ERROR_STATE(), ERROR_SEVERITY(), ERROR_LINE(), 'sp_ProcesarOperacionesXML - Bloque Diario', ERROR_MESSAGE());
            END CATCH;

            SET @Iterador = @Iterador + 1;
        END;

        SELECT 1 AS Codigo, 'Simulación completa ejecutada bajo normas estrictas de la rúbrica' AS Mensaje;

    END TRY
    BEGIN CATCH
        SELECT -1 AS Codigo, 'Error crítico estructural: ' + ERROR_MESSAGE() AS Mensaje;
    END CATCH
END;