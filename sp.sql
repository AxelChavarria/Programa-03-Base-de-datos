ALTER PROCEDURE sp_CargarEmpleadoXML
    @inXmlData XML
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;


        -- USUARIOS
        INSERT INTO Usuario (Id,Username,PasswordHash,Tipo)
        SELECT
            ISNULL((SELECT MAX(Id) FROM Usuario), 0)
            + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
            T.Node.value('@Username', 'VARCHAR(50)'),
            T.Node.value('@Password', 'VARCHAR(100)'),
            T.Node.value('@TipoUsuario', 'INT')
        FROM @inXmlData.nodes('/FechaOperacion/InsertarEmpleado') AS T(Node);
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM Usuario U
            WHERE U.Username = T.Node.value('@Username','VARCHAR(50)')
        );

        --- EMPLEADOS 
        INSERT INTO Empleado (IdPuesto, ValorDocumentoIdentidad, Nombre, FechaContratacion, SaldoVacaciones, EsActivo, IdUsuario)
        SELECT
            P.IdPuesto,
            T.Node.value('@ValorDocumentoIdentidad', 'VARCHAR(50)'),
            T.Node.value('@Nombre', 'VARCHAR(100)'),
            T.Node.value('@FechaContratacion', 'DATE'),
            0,
            1,
            U.Id
        FROM @inXmlData.nodes('/FechaOperacion/InsertarEmpleado') AS T(Node)

        INNER JOIN Puesto P
            ON P.Nombre = T.Node.value('@Puesto','VARCHAR(100)')

        INNER JOIN Usuario U
            ON U.Username = T.Node.value('@Username','VARCHAR(50)');

        WHERE NOT EXISTS
        (
            SELECT 1
            FROM Empleado E
            WHERE E.ValorDocumentoIdentidad =
                T.Node.value('@ValorDocumentoIdentidad','VARCHAR(50)')
        );

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