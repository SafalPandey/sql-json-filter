DROP PROCEDURE IF EXISTS dbo.apply_filter;
GO

/*
 * Procedure to filter any table based on JSON params in SQL
 */
CREATE PROCEDURE dbo.apply_filter (
  @table NVARCHAR(255),
  @params NVARCHAR(MAX),
  @conjunction NVARCHAR(3) = 'AND'
)
AS
BEGIN

  DECLARE @columns TABLE (
    [name] NVARCHAR(255)
  );

  --
  -- Step 1: Get the column list
  --
  INSERT INTO @columns
  SELECT
    column_name
  FROM INFORMATION_SCHEMA.columns
  WHERE TABLE_NAME = @table;

  DECLARE @param_table TABLE (
    filter_key VARCHAR(255),
    filter_value NVARCHAR(MAX)
  );

  --
  -- Step 2: Parse the supplied JSON parameter
  --
  INSERT INTO @param_table (filter_key, filter_value)
  SELECT
    [key] AS filter_key,
    [value] AS filter_value
  FROM OPENJSON(@params);

  DECLARE @invalid_keys NVARCHAR(MAX) = (
    SELECT
      STRING_AGG([name], ', ')
    FROM (
      SELECT [filter_key] AS [name] FROM @param_table
      EXCEPT
      SELECT [name] FROM @columns
    ) x
  );

  --
  -- Step 3: Error handling for invalid columns in JSON
  --
  IF (@invalid_keys <> '')
  BEGIN
    DECLARE @e VARCHAR(MAX) = CONCAT(
      'The source table does not have some filter key(s) that exist in the param: ',
      @invalid_keys
    );

    THROW 51000, @e, 1;
  END

  --
  -- Step 4: Generate dynamic SQL statement
  --
  DECLARE @sql NVARCHAR(MAX) =
  N'SELECT ' + (
    --
    -- Append comma separated string of column names in @table
    --
    SELECT STRING_AGG([name], ',') FROM @columns
  )
  + N' FROM ' + @table + ' s
  WHERE ' + (
    --
    -- Generate and add the where clause based on
    -- @param and @conjunction
    --
    SELECT
      STRING_AGG(
        ' s.' + [filter_key] + ' = ''' + [filter_value] + ''' ',
        @conjunction
      )
    FROM @param_table
  );

  -- Show the generated SQL query
  PRINT @sql;

  -- Execute the generated SQL query to get the filtered result set
  EXEC sp_executesql @sql;
END
