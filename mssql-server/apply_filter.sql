DROP PROCEDURE IF EXISTS dbo.apply_filter;
GO

CREATE PROCEDURE dbo.apply_filter (
  @table NVARCHAR(255),
  @params NVARCHAR(max),
  @conjunction NVARCHAR(3) = 'AND'
  )
AS
BEGIN

  DECLARE @columns TABLE (
    [name] NVARCHAR(255)
  );

  INSERT INTO @columns
  SELECT
    column_name
  FROM INFORMATION_SCHEMA.columns
  WHERE TABLE_NAME = @table;

  DECLARE @param_table TABLE (
    filter_key VARCHAR(255),
    filter_value NVARCHAR(MAX)
  );

  INSERT INTO @param_table (filter_key, filter_value)
  SELECT
    [key] AS filter_key,
    [value] AS filter_value
  FROM OPENJSON(@params);

  DECLARE @non_existent_columns NVARCHAR(MAX) = (
    SELECT
      STRING_AGG([name], ',')
    FROM (
      SELECT [filter_key] AS [name] FROM @param_table
      EXCEPT
      SELECT [name] FROM @columns
    ) x
  );

  IF (@non_existent_columns <> '')
  BEGIN
    DECLARE @e VARCHAR(MAX) = CONCAT(
      'The source table does not have some filter key(s) that exist in the param: ',
      @non_existent_columns
    );

    THROW 51000, @e, 1;
  END

  DECLARE @sql NVARCHAR(MAX) = N'SELECT ' + (
    SELECT STRING_AGG([name], ',') FROM @columns
  ) + N' FROM ' + @table + ' s
  WHERE 1 = 1 AND ' + (
    SELECT  STRING_AGG(' s.' + [filter_key] + ' = ''' + [filter_value] + ''' ', @conjunction)
    FROM @param_table
  );

  PRINT @sql;

  EXEC sp_executesql @sql;
END
