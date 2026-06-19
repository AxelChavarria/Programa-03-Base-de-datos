ALTER PROCEDURE sp_CargarTodoXML
    @inXmlData XML
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        --- PUESTOS
        INSERT INTO dbo.Puesto (Nombre, SalarioxHora)
        SELECT 
            T.Node.value('@Nombre', 'VARCHAR(100)'),
            T.Node.value('@SalarioXHora', 'DECIMAL(10,2)')
        FROM @inXmlData.nodes('/Datos/Puestos/Puesto') AS T(Node)
        WHERE T.Node.value('@Nombre', 'VARCHAR(100)') NOT IN (SELECT Nombre FROM Puesto);

        --- TIPOS DE JORNADA
        INSERT INTO dbo.TipoJornada (Id, Nombre, HoraInicio, HoraFin)
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
        INSERT INTO dbo.TipoEvento (Id, Nombre)
        SELECT 
            T.Node.value('@Id', 'INT'),
            T.Node.value('@Nombre', 'VARCHAR(100)')
        FROM @inXmlData.nodes('/Datos/TiposEvento/TipoEvento') AS T(Node)
        WHERE T.Node.value('@Id', 'INT') NOT IN (SELECT Id FROM dbo.TipoEvento);

        -- TIPOS DE MOVIMIENTO
        INSERT INTO dbo.TipoMovimiento (Id, Nombre, Accion)
        SELECT 
            T.Node.value('@Id', 'INT'),
            T.Node.value('@Nombre', 'VARCHAR(100)'),
            T.Node.value('@Accion', 'CHAR(1)')
        FROM @inXmlData.nodes('/Datos/TiposMovimiento/TipoMovimiento') AS T(Node)
        WHERE T.Node.value('@Id', 'INT') NOT IN (SELECT Id FROM dbo.TipoMovimiento); 

        
        --- TIPOS DE DEDUCCIN
        INSERT INTO dbo.TipoDeduccion (Id, Nombre, EsObligatoria, EsPorcentual, Valor, IdTipoMovimiento)
        SELECT 
            T.Node.value('@Id', 'INT'),
            T.Node.value('@Nombre', 'VARCHAR(100)'),
            T.Node.value('@EsObligatoria', 'BIT'),
            T.Node.value('@EsPorcentual', 'BIT'),
            T.Node.value('@Valor', 'DECIMAL(5,4)'),
            (SELECT Id FROM dbo.TipoMovimiento WHERE Nombre = T.Node.value('@TipoMovimiento', 'VARCHAR(100)'))
        FROM @inXmlData.nodes('/Datos/TiposDeduccion/TipoDeduccion') AS T(Node)
        WHERE T.Node.value('@Id', 'INT') NOT IN (SELECT Id FROM TipoDeduccion);

        --- USUARIOS
        INSERT INTO dbo.Usuario (Id, Username, PasswordHash, Tipo)
        SELECT 
            T.Node.value('@Id', 'INT'),
            T.Node.value('@Username', 'VARCHAR(50)'),
            T.Node.value('@PasswordHash', 'VARCHAR(100)'),
            T.Node.value('@Tipo', 'INT')
        FROM @inXmlData.nodes('/Datos/Usuarios/Usuario') AS T(Node)
        WHERE T.Node.value('@Id', 'INT') NOT IN (SELECT Id FROM dbo.Usuario);

        --- ERRORES
        INSERT INTO Error (Codigo, Descripcion)
        SELECT 
            T.Node.value('@Codigo', 'INT'),
            T.Node.value('@Descripcion', 'VARCHAR(255)')
        FROM @inXmlData.nodes('/Datos/Error/error') AS T(Node)
        WHERE T.Node.value('@Codigo', 'INT') NOT IN (SELECT dbo.Error.Codigo FROM dbo.Error);

        COMMIT TRANSACTION;

        SELECT 1 AS Codigo, 'Carga de xml ejecutada con éxito' AS Mensaje;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        INSERT INTO dbo.DBError (UserName, Number, State, Severity, Line, [Procedure], Message)
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
    --- Variables para la inserción
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
    -- Validar Contraseña
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


-------------------------------------------------------------------------------------------

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


------------------------------------------------------------------------------
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


    -- solo números (cédula)
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

CREATE OR ALTER PROCEDURE sp_ControlTiempoYPlanilla
    @pFechaActual DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdMesActual INT = NULL;
    DECLARE @IdSemanaActual INT = NULL;
    DECLARE @InicioMes DATE = DATEFROMPARTS(YEAR(@pFechaActual), MONTH(@pFechaActual), 1);
    DECLARE @FinMes DATE = EOMONTH(@pFechaActual);
    DECLARE @JuevesDelMes INT;

    -- =================================================================
    -- 1. CONTROL DE MES PLANILLA
    -- =================================================================
    SELECT TOP 1 @IdMesActual = Id FROM dbo.MesPlanilla WHERE @pFechaActual BETWEEN FechaInicio AND FechaFin;

    IF @IdMesActual IS NULL
    BEGIN
        -- REGLA DE CIERRE: Antes de abrir el nuevo, cerramos el mes anterior
        UPDATE dbo.MesPlanilla SET EsCerrado = 1 WHERE EsCerrado = 0;

        INSERT INTO dbo.MesPlanilla (FechaInicio, FechaFin, EsCerrado)
        VALUES (@InicioMes, @FinMes, 0);
        
        SET @IdMesActual = SCOPE_IDENTITY();
    END;

    -- =================================================================
    -- 2. CONTROL DE SEMANA PLANILLA
    -- =================================================================
    SELECT TOP 1 @IdSemanaActual = Id FROM dbo.SemanaPlanilla WHERE @pFechaActual BETWEEN FechaInicio AND FechaFin;

    IF @IdSemanaActual IS NULL
    BEGIN
        -- REGLA DE CIERRE: Antes de abrir la nueva semana, cerramos la anterior
        UPDATE dbo.SemanaPlanilla SET EsCerrado = 1 WHERE EsCerrado = 0;

        SET @JuevesDelMes = dbo.fn_ContarJuevesEnMes(@InicioMes, @FinMes);

        INSERT INTO dbo.SemanaPlanilla (IdMesPlanilla, FechaInicio, FechaFin, CantidadJuevesMes, EsCerrado)
        VALUES (@IdMesActual, @pFechaActual, DATEADD(DAY, 6, @pFechaActual), @JuevesDelMes, 0);
    END;
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

CREATE OR ALTER PROCEDURE sp_DesasociarDeduccionXML
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

CREATE OR ALTER PROCEDURE sp_CargarAsistenciasXML
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
    DECLARE @HorasCalculadas DECIMAL(5,2);
    DECLARE @vFechaPura DATE; -- <-- Nueva variable para la columna obligatoria

    -- 2. Volcar los nodos <MarcaAsistencia> a la tabla en memoria
    INSERT INTO @AsistenciasAProcesar (ValorDocumentoIdentidad, HoraEntrada, HoraSalida)
    SELECT
        T.Node.value('@ValorDocumentoIdentidad', 'VARCHAR(50)'),
        T.Node.value('@HoraEntrada', 'DATETIME'),
        T.Node.value('@HoraSalida', 'DATETIME')
    FROM @inXmlData.nodes('/FechaOperacion/MarcaAsistencia') AS T(Node);

    SELECT @MaxIterador = COUNT(*) FROM @AsistenciasAProcesar;

    -- 3. Iterar registro por registro
    WHILE @Iterador <= @MaxIterador
    BEGIN
        SELECT 
            @vCedula = ValorDocumentoIdentidad,
            @vEntrada = HoraEntrada,
            @vSalida = HoraSalida
        FROM @AsistenciasAProcesar
        WHERE Secuencia = @Iterador;

        -- Extraemos solo la FECHA (sin horas) para alimentar tu columna mandatoria
        SET @vFechaPura = CAST(@vEntrada AS DATE);

        -- Mapear el ID del empleado y la semana activa de planilla
        SELECT @IdEmpleadoActual = Id FROM dbo.Empleado WHERE ValorDocumentoIdentidad = @vCedula AND EsActivo = 1;
        SELECT @IdSemanaActual = Id FROM dbo.SemanaPlanilla WHERE @vFechaPura BETWEEN FechaInicio AND FechaFin;

        -- 4. VALIDACIONES CRÍTICAS
        IF @IdEmpleadoActual IS NULL
        BEGIN
            DECLARE @ErrEmpleado VARCHAR(150) = CONCAT('Error en Asistencia: El empleado con cédula ', @vCedula, ' no existe o está inactivo.');
            RAISERROR(@ErrEmpleado, 16, 1);
            RETURN;
        END

        IF @IdSemanaActual IS NULL
        BEGIN
            DECLARE @ErrSemana VARCHAR(150) = CONCAT('Error en Asistencia: No hay una semana de planilla abierta para la fecha ', CAST(@vFechaPura AS VARCHAR(10)));
            RAISERROR(@ErrSemana, 16, 1);
            RETURN;
        END

        -- 5. INSERCIÓN CORREGIDA: Agregamos la columna 'Fecha' que pide tu tabla
        INSERT INTO dbo.Asistencia (IdEmpleado, IdSemanaPlanilla, Fecha, HoraEntrada, HoraSalida)
        VALUES (@IdEmpleadoActual, @IdSemanaActual, @vFechaPura, @vEntrada, @vSalida);

        -- 6. Cálculo para la bitácora JSON (R07)
        SET @HorasCalculadas = DATEDIFF(MINUTE, @vEntrada, @vSalida) / 60.0;

        DECLARE @JsonBitacora VARCHAR(MAX) = (
            SELECT 
                @IdEmpleadoActual AS [Asistencia.IdEmpleado], 
                @IdSemanaActual AS [Asistencia.IdSemanaPlanilla],
                @vFechaPura AS [Asistencia.Fecha],
                @vEntrada AS [Asistencia.Entrada], 
                @vSalida AS [Asistencia.Salida],
                @HorasCalculadas AS [Asistencia.HorasCalculadas]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        INSERT INTO dbo.BitacoraEvento (idTipoEvento, Descripcion, IdPostByUser, PostInIP, PostTime)
        VALUES (8, @JsonBitacora, 1, '127.0.0.1', GETDATE());

        SET @Iterador = @Iterador + 1;
    END;
END;
---------------------------------
CREATE OR ALTER FUNCTION dbo.fn_ObtenerLimiteHorasJornada (
    @pNombreJornada VARCHAR(50)
)
RETURNS INT
AS
BEGIN
    RETURN CASE 
        WHEN @pNombreJornada = 'Diurno' THEN 8
        WHEN @pNombreJornada = 'Vespertino' THEN 7
        WHEN @pNombreJornada = 'Nocturno' THEN 6
        ELSE 8 -- Por defecto
    END;
END;

----------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_CierreSemanalPlanilla
    @pFechaActual DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdSemanaActual INT;
    
    -- 1. Identificar la semana abierta que se va a cerrar hoy jueves
    SELECT TOP 1 @IdSemanaActual = Id 
    FROM dbo.SemanaPlanilla 
    WHERE @pFechaActual BETWEEN FechaInicio AND FechaFin AND EsCerrado = 0;

    IF @IdSemanaActual IS NULL RETURN;

    -- 2. Tabla variable para procesar los totales de cada empleado en esta semana
    DECLARE @CalculoEmpleados TABLE (
        IdEmpleado INT,
        IdTipoJornada INT,
        HorasOrdinarias DECIMAL(5,2),
        HorasExtrasNormales DECIMAL(5,2),
        HorasExtrasDobles DECIMAL(5,2),
        MontoHorasOrdinarias DECIMAL(12,2),
        MontoHorasExtrasNormales DECIMAL(12,2),
        MontoHorasExtrasDobles DECIMAL(12,2),
        SalarioBruto DECIMAL(12,2),
        DeduccionCCSS DECIMAL(12,2)
    );

    -- 3. Agrupación matemática y cálculo directo del Salario Bruto y CCSS
    INSERT INTO @CalculoEmpleados (
        IdEmpleado, IdTipoJornada, HorasOrdinarias, HorasExtrasNormales, HorasExtrasDobles, 
        MontoHorasOrdinarias, MontoHorasExtrasNormales, MontoHorasExtrasDobles, SalarioBruto, DeduccionCCSS
    )
    SELECT 
        E.Id AS IdEmpleado,
        CJE.IdTipoJornada AS IdTipoJornada,
        
        -- HORAS ORDINARIAS
        SUM(CASE 
            WHEN F.Fecha IS NULL AND (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) <= dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) THEN (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0)
            WHEN F.Fecha IS NULL AND (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) > dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) THEN dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre)
            ELSE 0
        END) AS HorasOrdinarias,
        
        -- HORAS EXTRAS NORMALES
        SUM(CASE 
            WHEN F.Fecha IS NULL AND (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) > dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) THEN (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) - dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre)
            ELSE 0
        END) AS HorasExtrasNormales,

        -- HORAS EXTRAS DOBLES (Feriados)
        SUM(CASE 
            WHEN F.Fecha IS NOT NULL THEN (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0)
            ELSE 0
        END) AS HorasExtrasDobles,
        
        -- MONTO ORDINARIO, EXTRA Y FERIADO (Basado en SalarioxHora)
        SUM(CASE 
            WHEN F.Fecha IS NULL AND (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) <= dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) THEN (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0)
            WHEN F.Fecha IS NULL AND (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) > dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) THEN dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre)
            ELSE 0
        END) * P.SalarioxHora AS MontoHorasOrdinarias,
        
        SUM(CASE 
            WHEN F.Fecha IS NULL AND (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) > dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) THEN (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) - dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre)
            ELSE 0
        END) * P.SalarioxHora * 1.5 AS MontoHorasExtrasNormales,

        SUM(CASE 
            WHEN F.Fecha IS NOT NULL THEN (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0)
            ELSE 0
        END) * P.SalarioxHora * 2.0 AS MontoHorasExtrasDobles,

        -- SALARIO BRUTO TOTAL
        (SUM(CASE WHEN F.Fecha IS NULL AND (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) <= dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) THEN (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) WHEN F.Fecha IS NULL AND (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) > dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) THEN dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) ELSE 0 END) * P.SalarioxHora) +
        (SUM(CASE WHEN F.Fecha IS NULL AND (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) > dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) THEN (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) - dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) ELSE 0 END) * P.SalarioxHora * 1.5) +
        (SUM(CASE WHEN F.Fecha IS NOT NULL THEN (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) ELSE 0 END) * P.SalarioxHora * 2.0) AS SalarioBruto,

        -- DEDUCCIÓN CCSS (10.67%)
        ((SUM(CASE WHEN F.Fecha IS NULL AND (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) <= dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) THEN (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) WHEN F.Fecha IS NULL AND (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) > dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) THEN dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) ELSE 0 END) * P.SalarioxHora) +
        (SUM(CASE WHEN F.Fecha IS NULL AND (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) > dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) THEN (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) - dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) ELSE 0 END) * P.SalarioxHora * 1.5) +
        (SUM(CASE WHEN F.Fecha IS NOT NULL THEN (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) ELSE 0 END) * P.SalarioxHora * 2.0)) * 0.1067 AS DeduccionCCSS

    FROM dbo.Asistencia A
    INNER JOIN dbo.Empleado E ON A.IdEmpleado = E.Id
    INNER JOIN dbo.Puesto P ON E.IdPuesto = P.Id
    INNER JOIN dbo.CalendarioJornadaEmpleado CJE ON E.Id = CJE.IdEmpleado AND CJE.IdSemanaPlanilla = @IdSemanaActual
    INNER JOIN dbo.TipoJornada TJ ON CJE.IdTipoJornada = TJ.Id
    LEFT JOIN dbo.Feriado F ON CAST(A.HoraEntrada AS DATE) = F.Fecha
    WHERE A.IdSemanaPlanilla = @IdSemanaActual
    GROUP BY E.Id, CJE.IdTipoJornada, P.SalarioxHora;


    -- =================================================================
    -- 4. INSERCIÓN MASIVA EN TABLA DE DEDUCCIONES SEMANALES
    -- =================================================================
    
    -- A. CCSS Obligatoria
    INSERT INTO dbo.DeduccionSemanalXEmpleado (IdEmpleado, IdSemanaPlanilla, Detalle, Monto, IdTipoDeduccion)
    SELECT IdEmpleado, @IdSemanaActual, 'CCSS Deducción Obligatoria (10.67%)', DeduccionCCSS, 1
    FROM @CalculoEmpleados;

    -- B. Deducciones Voluntarias
    INSERT INTO dbo.DeduccionSemanalXEmpleado (IdEmpleado, IdSemanaPlanilla, Detalle, Monto, IdTipoDeduccion)
    SELECT 
        C.IdEmpleado, 
        @IdSemanaActual, 
        'Deducción Voluntaria',
        CASE WHEN DXE.PorcentajeOMonto > 1.00 THEN DXE.PorcentajeOMonto ELSE C.SalarioBruto * DXE.PorcentajeOMonto END,
        DXE.IdTipoDeduccion
    FROM @CalculoEmpleados C
    INNER JOIN dbo.DeduccionXEmpleado DXE ON C.IdEmpleado = DXE.IdEmpleado AND DXE.EsActiva = 1;


    -- =================================================================
    -- 5. INSERCIÓN MASIVA EN LA PLANILLA SEMANAL FINAL
    -- =================================================================
    INSERT INTO dbo.PlanillaSemXEmpleado (
        IdEmpleado, IdSemanaPlanilla, SalarioBruto, TotalDeducciones, SalarioNeto, 
        HorasOrdinarias, HorasExtrasNormales, HorasExtrasDobles, IdTipoJornada
    )
    SELECT 
        C.IdEmpleado,
        @IdSemanaActual,
        C.SalarioBruto,
        C.DeduccionCCSS + ISNULL(DV.MontoVoluntario, 0) AS TotalDeducciones,
        C.SalarioBruto - (C.DeduccionCCSS + ISNULL(DV.MontoVoluntario, 0)) AS SalarioNeto,
        C.HorasOrdinarias,
        C.HorasExtrasNormales,
        C.HorasExtrasDobles,
        C.IdTipoJornada
    FROM @CalculoEmpleados C
    LEFT JOIN (
        SELECT 
            C2.IdEmpleado,
            SUM(CASE WHEN DXE.PorcentajeOMonto > 1.00 THEN DXE.PorcentajeOMonto ELSE C2.SalarioBruto * DXE.PorcentajeOMonto END) AS MontoVoluntario
        FROM @CalculoEmpleados C2
        INNER JOIN dbo.DeduccionXEmpleado DXE ON C2.IdEmpleado = DXE.IdEmpleado AND DXE.EsActiva = 1
        GROUP BY C2.IdEmpleado -- <-- Eliminado el ';' que rompía la sintaxis aquí
    ) DV ON C.IdEmpleado = DV.IdEmpleado;

END;

-----------------------------------
CREATE OR ALTER PROCEDURE dbo.sp_CierreMensualPlanilla
    @pFechaActual DATE -- Se mantiene por compatibilidad, pero la lógica ahora es 100% relacional
AS
BEGIN
    SET NOCOUNT ON;

    -- =================================================================
    -- 1. CONSOLIDAR PLANILLA MENSUAL (Basado en la Planilla Semanal)
    -- =================================================================
    -- El truco está en agrupar por SP.IdMesPlanilla. Así, si hay datos de la semana 
    -- que pertenecen al Mes 1 y otros al Mes 2, se calcularán ambos por separado.
    INSERT INTO dbo.PlanillaMesXEmpleado (IdEmpleado, IdMesPlanilla, SalarioBrutoMensual, DeduccionesMensuales, SalarioNetoMensual)
    SELECT 
        PSE.IdEmpleado,
        SP.IdMesPlanilla, -- <--- Tomamos el ID del mes directamente de la semana
        SUM(PSE.SalarioBruto) AS SalarioBrutoMensual,
        SUM(PSE.TotalDeducciones) AS DeduccionesMensuales,
        SUM(PSE.SalarioNeto) AS SalarioNetoMensual
    FROM dbo.PlanillaSemXEmpleado PSE
    INNER JOIN dbo.SemanaPlanilla SP ON PSE.IdSemanaPlanilla = SP.Id
    WHERE NOT EXISTS (
        -- Evitamos duplicados por si el SP se ejecuta dos veces
        SELECT 1 
        FROM dbo.PlanillaMesXEmpleado PME 
        WHERE PME.IdEmpleado = PSE.IdEmpleado AND PME.IdMesPlanilla = SP.IdMesPlanilla
    )
    GROUP BY PSE.IdEmpleado, SP.IdMesPlanilla;


    -- =================================================================
    -- 2. CONSOLIDAR DEDUCCIONES X EMPLEADO X MES (Basado en la Semanal)
    -- =================================================================
    -- Hacemos exactamente lo mismo: sumamos los rebajos semanales agrupando por 
    -- el mes correspondiente de la semana, respetando tu restricción UNIQUE.
    INSERT INTO dbo.DeduccionesXEmpleadoXMes (IdEmpleado, IdMesPlanilla, IdTipoDeduccion, MontoAcumulado)
    SELECT 
        DSE.IdEmpleado,
        SP.IdMesPlanilla, -- <--- El mes real al que pertenece el rebajo semanal
        DSE.IdTipoDeduccion, 
        SUM(DSE.Monto) AS MontoAcumulado
    FROM dbo.DeduccionSemanalXEmpleado DSE
    INNER JOIN dbo.SemanaPlanilla SP ON DSE.IdSemanaPlanilla = SP.Id
    WHERE DSE.IdTipoDeduccion IS NOT NULL
      AND NOT EXISTS (
          -- Evitamos violar el UNIQUE (IdEmpleado, IdMesPlanilla, IdTipoDeduccion)
          SELECT 1 
          FROM dbo.DeduccionesXEmpleadoXMes DXM 
          WHERE DXM.IdEmpleado = DSE.IdEmpleado 
            AND DXM.IdMesPlanilla = SP.IdMesPlanilla 
            AND DXM.IdTipoDeduccion = DSE.IdTipoDeduccion
      )
    GROUP BY DSE.IdEmpleado, SP.IdMesPlanilla, DSE.IdTipoDeduccion;


    -- =================================================================
    -- 3. MOTOR DE VACACIONES
    -- =================================================================
    -- Acumula los 1.25 días a los empleados que registraron actividad en el mes
    UPDATE E
    SET E.SaldoVacaciones = ISNULL(E.SaldoVacaciones, 0) + 1.25
    FROM dbo.Empleado E
    WHERE E.EsActivo = 1
      AND E.Id IN (
          SELECT DISTINCT IdEmpleado 
          FROM dbo.PlanillaMesXEmpleado
      );


    -- =================================================================
    -- 4. MARCAR MESES COMO CERRADOS
    -- =================================================================
    -- Por orden, cerramos los meses que ya tienen datos procesados en la planilla mensual
    UPDATE MP
    SET MP.EsCerrado = 1
    FROM dbo.MesPlanilla MP
    WHERE MP.EsCerrado = 0
      AND EXISTS (
          SELECT 1 
          FROM dbo.PlanillaMesXEmpleado PME 
          WHERE PME.IdMesPlanilla = MP.Id
      );

END;
----------------------------------
CREATE OR ALTER PROCEDURE sp_ProcesarOperacionesXML
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
        -- Validamos que no sea el día inicial de la simulación consultando si ya existen asistencias previas
            IF EXISTS (SELECT 1 FROM dbo.Asistencia)
                    BEGIN
                        -- 1. Ejecutamos los cálculos y rebajos semanales
                        EXEC dbo.sp_CierreSemanalPlanilla @pFechaActual = @FechaActual;

                        -- 2. Evaluamos si el mes calendario también se acabó hoy para consolidar el mes y subir vacaciones
                        -- (Si el próximo día de simulación cambia de mes, ejecutamos el cierre mensual)
                        IF MONTH(@FechaActual) <> MONTH(DATEADD(DAY, 1, @FechaActual))
                        BEGIN
                            EXEC dbo.sp_CierreMensualPlanilla @pFechaActual = @FechaActual;
                        END
                    END
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


SELECT * FROM Empleado
EXEC sp_ConsultarTodoSemanalEmpleado 186
CREATE OR ALTER PROCEDURE dbo.sp_ConsultarTodoSemanalEmpleado
    @pIdEmpleado INT
AS
BEGIN
    SET NOCOUNT ON;

    -- =================================================================
    -- RESULTADO 1: Listado de Planillas Semanales
    -- =================================================================
    SELECT 
        PSE.Id AS IdPlanillaSemanal,
        PSE.IdSemanaPlanilla,
        SP.FechaInicio,
        SP.FechaFin,
        PSE.SalarioBruto,
        PSE.TotalDeducciones,
        PSE.SalarioNeto,
        PSE.HorasOrdinarias,
        PSE.HorasExtrasNormales,
        PSE.HorasExtrasDobles,
        PSE.IdTipoJornada
    FROM dbo.PlanillaSemXEmpleado PSE
    INNER JOIN dbo.SemanaPlanilla SP ON PSE.IdSemanaPlanilla = SP.Id
    WHERE PSE.IdEmpleado = @pIdEmpleado
    ORDER BY SP.FechaInicio DESC;

    -- =================================================================
    -- RESULTADO 2: Detalle de Deducciones Semanales
    -- =================================================================
    SELECT 
        DSE.IdSemanaPlanilla,
        DSE.IdTipoDeduccion,
        DSE.Detalle AS NombreDeduccion,
        CASE 
            WHEN DSE.IdTipoDeduccion = 1 THEN 10.67
            ELSE ISNULL(DXE.PorcentajeOMonto * 100, 0) 
        END AS PorcentajeAplicado,
        DSE.Monto
    FROM dbo.DeduccionSemanalXEmpleado DSE
    LEFT JOIN dbo.DeduccionXEmpleado DXE ON DSE.IdEmpleado = DXE.IdEmpleado AND DSE.IdTipoDeduccion = DXE.IdTipoDeduccion
    WHERE DSE.IdEmpleado = @pIdEmpleado;

    -- =================================================================
    -- RESULTADO 3: Desglose Diario de Asistencias y Rubros en Colones
    -- =================================================================
    DECLARE @SalarioHora DECIMAL(10,2);
    SELECT @SalarioHora = P.SalarioxHora 
    FROM dbo.Empleado E 
    INNER JOIN dbo.Puesto P ON E.IdPuesto = P.Id 
    WHERE E.Id = @pIdEmpleado;

    SELECT 
        A.IdSemanaPlanilla,
        CAST(A.HoraEntrada AS DATE) AS Fecha,
        CONVERT(VARCHAR(5), A.HoraEntrada, 108) AS HoraEntrada,
        CONVERT(VARCHAR(5), A.HoraSalida, 108) AS HoraSalida,
        
        -- Cálculo de Horas Ordinarias y su Monto
        CASE WHEN F.Fecha IS NULL AND (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) <= dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) THEN (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0)
             WHEN F.Fecha IS NULL AND (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) > dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) THEN dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) ELSE 0 END AS HorasOrdinarias,
        (CASE WHEN F.Fecha IS NULL AND (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) <= dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) THEN (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0)
              WHEN F.Fecha IS NULL AND (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) > dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) THEN dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) ELSE 0 END) * @SalarioHora AS MontoOrdinario,

        -- Cálculo de Horas Extras Normales y su Monto
        CASE WHEN F.Fecha IS NULL AND (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) > dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) THEN (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) - dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) ELSE 0 END AS HorasExtrasNormales,
        (CASE WHEN F.Fecha IS NULL AND (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) > dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) THEN (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) - dbo.fn_ObtenerLimiteHorasJornada(TJ.Nombre) ELSE 0 END) * @SalarioHora * 1.5 AS MontoExtraNormal,

        -- Cálculo de Horas Feriadas (Dobles) y su Monto
        CASE WHEN F.Fecha IS NOT NULL THEN (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) ELSE 0 END AS HorasExtrasDobles,
        (CASE WHEN F.Fecha IS NOT NULL THEN (DATEDIFF(MINUTE, A.HoraEntrada, A.HoraSalida) / 60.0) ELSE 0 END) * @SalarioHora * 2.0 AS MontoExtraDoble

    FROM dbo.Asistencia A
    INNER JOIN dbo.SemanaPlanilla SP ON A.IdSemanaPlanilla = SP.Id
    INNER JOIN dbo.CalendarioJornadaEmpleado CJE ON A.IdEmpleado = CJE.IdEmpleado AND CJE.IdSemanaPlanilla = SP.Id
    INNER JOIN dbo.TipoJornada TJ ON CJE.IdTipoJornada = TJ.Id
    LEFT JOIN dbo.Feriado F ON CAST(A.HoraEntrada AS DATE) = F.Fecha
    WHERE A.IdEmpleado = @pIdEmpleado
    ORDER BY A.HoraEntrada ASC;
END;


EXEC sp_ConsultarTodoMensualEmpleado 186
CREATE OR ALTER PROCEDURE dbo.sp_ConsultarTodoMensualEmpleado
    @pIdEmpleado INT
AS
BEGIN
    SET NOCOUNT ON;

    -- =================================================================
    -- RESULTADO 1: Listado de Planillas Mensuales
    -- =================================================================
    SELECT 
        PME.Id AS IdPlanillaMensual,
        PME.IdMesPlanilla,
        UPPER(DATENAME(MONTH, MP.FechaInicio)) + ' ' + CAST(YEAR(MP.FechaInicio) AS VARCHAR(4)) AS MesNombre,
        MP.FechaInicio,
        MP.FechaFin,
        PME.SalarioBrutoMensual,
        PME.DeduccionesMensuales,
        PME.SalarioNetoMensual
    FROM dbo.PlanillaMesXEmpleado PME
    INNER JOIN dbo.MesPlanilla MP ON PME.IdMesPlanilla = MP.Id
    WHERE PME.IdEmpleado = @pIdEmpleado
    ORDER BY MP.FechaInicio DESC;

    -- =================================================================
    -- RESULTADO 2: Acumulado de Deducciones Mensuales por Categoría
    -- =================================================================
    SELECT 
        DXM.IdMesPlanilla,
        DXM.IdTipoDeduccion,
        TD.Nombre AS NombreDeduccion,
        CASE 
            WHEN TD.Id = 1 THEN 10.67
            ELSE ISNULL((SELECT TOP 1 DXE.PorcentajeOMonto * 100 FROM dbo.DeduccionXEmpleado DXE WHERE DXE.IdEmpleado = @pIdEmpleado AND DXE.IdTipoDeduccion = TD.Id), 0)
        END AS PorcentajeAplicado,
        DXM.MontoAcumulado
    FROM dbo.DeduccionesXEmpleadoXMes DXM
    INNER JOIN dbo.TipoDeduccion TD ON DXM.IdTipoDeduccion = TD.Id
    WHERE DXM.IdEmpleado = @pIdEmpleado;
END;